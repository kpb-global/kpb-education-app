import { randomUUID } from 'node:crypto';

import {
  AccountType,
  ArtifactProcessingStatus,
  ConsentPurpose,
  OutcomeEvidenceKind,
  PrismaClient,
} from '@prisma/client';

import type { PrismaService } from '../../prisma/prisma.service';
import { DomainEventOutboxService } from '../common/domain-event-outbox.service';
import { StoragePurgeReconciliationService } from './storage-purge-reconciliation.service';

const describePostgres =
  process.env.KPB_RUN_POSTGRES_INTEGRATION === 'true' ? describe : describe.skip;

describePostgres('abandoned upload retention — PostgreSQL integration', () => {
  const prisma = new PrismaClient();
  const suffix = randomUUID();
  const ids = {
    user: `retention-user-${suffix}`,
    scholarship: `retention-scholarship-${suffix}`,
    cycle: `retention-cycle-${suffix}`,
    workspace: `retention-workspace-${suffix}`,
    notice: `retention-notice-${suffix}`,
    consent: `retention-consent-${suffix}`,
    artifact: `retention-artifact-${suffix}`,
    artifactExpired: `retention-artifact-expired-${suffix}`,
    artifactRecent: `retention-artifact-recent-${suffix}`,
    artifactClean: `retention-artifact-clean-${suffix}`,
    evidenceExpired: `retention-evidence-expired-${suffix}`,
    evidenceRecent: `retention-evidence-recent-${suffix}`,
    evidenceClean: `retention-evidence-clean-${suffix}`,
  };
  const prismaService = {
    isEnabled: true,
    execute: async <T>(operation: (client: PrismaClient) => Promise<T>) =>
      operation(prisma),
  } as PrismaService;

  beforeAll(async () => {
    const now = new Date();
    const expiredAt = new Date(now.getTime() - 25 * 60 * 60 * 1_000);
    await prisma.userProfile.create({
      data: {
        id: ids.user,
        accountType: AccountType.student,
        preferredLanguage: 'fr',
        fullName: 'Retention Integration Student',
        email: `retention-${suffix}@example.test`,
        phone: '+22790000000',
        countryOfResidence: 'Niger',
      },
    });
    await prisma.scholarship.create({
      data: {
        id: ids.scholarship,
        nameFr: 'Bourse test rétention',
        nameEn: 'Retention test scholarship',
        countryId: 'test',
        levelEligibleFr: 'Master',
        levelEligibleEn: 'Master',
        typeOfFundingFr: 'Complète',
        typeOfFundingEn: 'Full',
        deadlineLabelFr: 'Test',
        deadlineLabelEn: 'Test',
        keyRequirementsFr: [],
        keyRequirementsEn: [],
        relatedFieldIds: [],
        sourceKey: `retention-${suffix}`,
      },
    });
    await prisma.scholarshipCycle.create({
      data: {
        id: ids.cycle,
        scholarshipId: ids.scholarship,
        academicYear: `retention-${suffix}`,
      },
    });
    await prisma.consentNotice.create({
      data: {
        id: ids.notice,
        purpose: ConsentPurpose.outcome_evidence,
        version: `retention-${suffix}`,
        languageCode: 'fr',
        contentHash: 'a'.repeat(64),
        effectiveAt: new Date(now.getTime() - 60_000),
      },
    });
    await prisma.consentReceipt.create({
      data: {
        id: ids.consent,
        userId: ids.user,
        purpose: ConsentPurpose.outcome_evidence,
        noticeId: ids.notice,
        languageCode: 'fr',
        channel: 'integration_test',
        grantedAt: now,
      },
    });
    await prisma.scholarshipWorkspace.create({
      data: {
        id: ids.workspace,
        userId: ids.user,
        scholarshipId: ids.scholarship,
        scholarshipCycleId: ids.cycle,
      },
    });
    await prisma.applicationArtifact.create({
      data: {
        id: ids.artifact,
        workspaceId: ids.workspace,
        kind: 'cv',
        title: 'Retention CV',
      },
    });
    await prisma.applicationArtifactVersion.createMany({
      data: [
        {
          id: ids.artifactExpired,
          artifactId: ids.artifact,
          versionNumber: 1,
          originalFileName: 'expired.pdf',
          mimeType: 'application/pdf',
          sizeBytes: 12,
          sha256: 'b'.repeat(64),
          processingStatus: ArtifactProcessingStatus.pending_upload,
          createdAt: expiredAt,
        },
        {
          id: ids.artifactRecent,
          artifactId: ids.artifact,
          versionNumber: 2,
          originalFileName: 'recent.pdf',
          mimeType: 'application/pdf',
          sizeBytes: 12,
          sha256: 'c'.repeat(64),
          processingStatus: ArtifactProcessingStatus.pending_upload,
          createdAt: now,
        },
        {
          id: ids.artifactClean,
          artifactId: ids.artifact,
          versionNumber: 3,
          storageKey: `2026-07-18/${randomUUID()}.pdf`,
          originalFileName: 'clean.pdf',
          mimeType: 'application/pdf',
          sizeBytes: 12,
          sha256: 'd'.repeat(64),
          processingStatus: ArtifactProcessingStatus.clean,
          uploadedAt: expiredAt,
          createdAt: expiredAt,
        },
      ],
    });
    const outcomeBase = {
      workspaceId: ids.workspace,
      ownerUserId: ids.user,
      consentReceiptId: ids.consent,
      kind: OutcomeEvidenceKind.submission_confirmation,
      mimeType: 'application/pdf',
      sizeBytes: 12,
    };
    await prisma.outcomeEvidenceAsset.createMany({
      data: [
        {
          ...outcomeBase,
          id: ids.evidenceExpired,
          originalFileName: 'expired-outcome.pdf',
          sha256: 'e'.repeat(64),
          processingStatus: ArtifactProcessingStatus.pending_upload,
          createdAt: expiredAt,
        },
        {
          ...outcomeBase,
          id: ids.evidenceRecent,
          originalFileName: 'recent-outcome.pdf',
          sha256: 'f'.repeat(64),
          processingStatus: ArtifactProcessingStatus.pending_upload,
          createdAt: now,
        },
        {
          ...outcomeBase,
          id: ids.evidenceClean,
          storageKey: `2026-07-18/${randomUUID()}.pdf`,
          originalFileName: 'clean-outcome.pdf',
          sha256: '1'.repeat(64),
          processingStatus: ArtifactProcessingStatus.clean,
          uploadedAt: expiredAt,
          createdAt: expiredAt,
        },
      ],
    });
  });

  afterAll(async () => {
    const aggregateIds = [
      ids.artifactExpired,
      ids.artifactRecent,
      ids.artifactClean,
      ids.evidenceExpired,
      ids.evidenceRecent,
      ids.evidenceClean,
    ];
    await prisma.domainEventOutbox.deleteMany({
      where: { aggregateId: { in: aggregateIds } },
    });
    await prisma.outcomeEvidenceAsset.deleteMany({
      where: { workspaceId: ids.workspace },
    });
    await prisma.applicationArtifactVersion.deleteMany({
      where: { artifactId: ids.artifact },
    });
    await prisma.applicationArtifact.deleteMany({ where: { id: ids.artifact } });
    await prisma.scholarshipWorkspace.deleteMany({ where: { id: ids.workspace } });
    await prisma.consentReceipt.deleteMany({ where: { id: ids.consent } });
    await prisma.userProfile.deleteMany({ where: { id: ids.user } });
    await prisma.scholarship.deleteMany({ where: { id: ids.scholarship } });
    await prisma.consentNotice.deleteMany({ where: { id: ids.notice } });
    await prisma.$disconnect();
  });

  it('expires exactly old pending rows and remains idempotent', async () => {
    const service = new StoragePurgeReconciliationService(
      prismaService,
      new DomainEventOutboxService(prismaService),
    );
    const now = new Date();

    await expect(
      service.expireAbandonedPendingUploads(now, 20),
    ).resolves.toBe(2);
    await expect(
      service.expireAbandonedPendingUploads(now, 20),
    ).resolves.toBe(0);

    const [artifactExpired, artifactRecent, artifactClean] = await Promise.all([
      prisma.applicationArtifactVersion.findUniqueOrThrow({
        where: { id: ids.artifactExpired },
      }),
      prisma.applicationArtifactVersion.findUniqueOrThrow({
        where: { id: ids.artifactRecent },
      }),
      prisma.applicationArtifactVersion.findUniqueOrThrow({
        where: { id: ids.artifactClean },
      }),
    ]);
    expect(artifactExpired).toMatchObject({
      processingStatus: ArtifactProcessingStatus.deleted,
      rejectionCode: 'upload_expired',
    });
    expect(artifactExpired.deletedAt).not.toBeNull();
    expect(artifactRecent).toMatchObject({
      processingStatus: ArtifactProcessingStatus.pending_upload,
      deletedAt: null,
    });
    expect(artifactClean).toMatchObject({
      processingStatus: ArtifactProcessingStatus.clean,
      deletedAt: null,
    });

    const [evidenceExpired, evidenceRecent, evidenceClean] = await Promise.all([
      prisma.outcomeEvidenceAsset.findUniqueOrThrow({
        where: { id: ids.evidenceExpired },
      }),
      prisma.outcomeEvidenceAsset.findUniqueOrThrow({
        where: { id: ids.evidenceRecent },
      }),
      prisma.outcomeEvidenceAsset.findUniqueOrThrow({
        where: { id: ids.evidenceClean },
      }),
    ]);
    expect(evidenceExpired).toMatchObject({
      processingStatus: ArtifactProcessingStatus.deleted,
      rejectionCode: 'upload_expired',
      version: 2,
    });
    expect(evidenceRecent).toMatchObject({
      processingStatus: ArtifactProcessingStatus.pending_upload,
      deletedAt: null,
    });
    expect(evidenceClean).toMatchObject({
      processingStatus: ArtifactProcessingStatus.clean,
      deletedAt: null,
    });

    expect(
      await prisma.domainEventOutbox.count({
        where: {
          aggregateId: { in: [ids.artifactExpired, ids.evidenceExpired] },
        },
      }),
    ).toBe(2);
  });
});
