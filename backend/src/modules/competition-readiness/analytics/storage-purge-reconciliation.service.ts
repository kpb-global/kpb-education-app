import { Injectable, Logger } from '@nestjs/common';
import { Interval } from '@nestjs/schedule';
import { Prisma } from '@prisma/client';

import { PrismaService } from '../../prisma/prisma.service';
import { DomainEventOutboxService } from '../common/domain-event-outbox.service';

const RECONCILIATION_INTERVAL_MS = 60_000;
const ABANDONED_UPLOAD_TTL_MS = 24 * 60 * 60 * 1_000;

interface ArtifactPurgeCandidate {
  id: string;
  artifactId: string;
  workspaceId: string;
  storageKey: string;
  reasonProvided: boolean;
}

interface OutcomeEvidencePurgeCandidate {
  id: string;
  workspaceId: string;
  storageKey: string;
}

/**
 * Repairs the narrow crash window where a soft-deleted storage row exists but
 * its purge event does not. Deterministic event IDs make concurrent replicas
 * harmless. Hard-deleted rows cannot be reconstructed without a storage
 * inventory and are deliberately outside this conservative reconciler.
 */
@Injectable()
export class StoragePurgeReconciliationService {
  private readonly logger = new Logger(StoragePurgeReconciliationService.name);
  private running = false;

  constructor(
    private readonly prisma: PrismaService,
    private readonly outbox: DomainEventOutboxService,
  ) {}

  @Interval(RECONCILIATION_INTERVAL_MS)
  async reconcile(): Promise<void> {
    if (this.running || !this.prisma.isEnabled) return;
    this.running = true;
    try {
      await this.expireAbandonedPendingUploads();
      await this.reconcileOnce();
    } catch {
      this.logger.error('Storage purge reconciliation failed.');
    } finally {
      this.running = false;
    }
  }

  /**
   * Conservatively expires only multipart intents that never reached upload.
   * Clean/rejected/non-current versions are intentionally outside this job
   * until a validated country-specific retention policy exists.
   */
  async expireAbandonedPendingUploads(
    now = new Date(),
    limit = 50,
  ): Promise<number> {
    if (!this.prisma.isEnabled) return 0;
    const boundedLimit = Math.min(200, Math.max(1, Math.floor(limit)));
    const cutoff = new Date(now.getTime() - ABANDONED_UPLOAD_TTL_MS);
    const expired = await this.prisma.execute((prisma) =>
      prisma.$transaction(async (tx) => {
        const [artifacts, evidence] = await Promise.all([
          tx.applicationArtifactVersion.findMany({
            where: {
              processingStatus: 'pending_upload',
              deletedAt: null,
              createdAt: { lt: cutoff },
            },
            orderBy: [{ createdAt: 'asc' }, { id: 'asc' }],
            take: boundedLimit,
            select: {
              id: true,
              artifactId: true,
              storageKey: true,
              artifact: { select: { workspaceId: true } },
            },
          }),
          tx.outcomeEvidenceAsset.findMany({
            where: {
              processingStatus: 'pending_upload',
              deletedAt: null,
              createdAt: { lt: cutoff },
            },
            orderBy: [{ createdAt: 'asc' }, { id: 'asc' }],
            take: boundedLimit,
            select: {
              id: true,
              workspaceId: true,
              storageKey: true,
            },
          }),
        ]);

        let count = 0;
        for (const candidate of artifacts) {
          const claimed = await tx.applicationArtifactVersion.updateMany({
            where: {
              id: candidate.id,
              processingStatus: 'pending_upload',
              deletedAt: null,
              createdAt: { lt: cutoff },
            },
            data: {
              processingStatus: 'deleted',
              deletedAt: now,
              rejectionCode: 'upload_expired',
            },
          });
          if (claimed.count !== 1) continue;
          await this.outbox.enqueue(
            {
              eventId: `artifact.version.deleted:${candidate.id}`,
              eventName: 'artifact.version.deleted',
              aggregateType: 'ApplicationArtifactVersion',
              aggregateId: candidate.id,
              occurredAt: now,
              payload: {
                workspaceId: candidate.artifact.workspaceId,
                artifactId: candidate.artifactId,
                versionId: candidate.id,
                storageKey: candidate.storageKey,
                reasonProvided: false,
                retentionExpired: true,
              },
            },
            tx,
          );
          count += 1;
        }

        for (const candidate of evidence) {
          const claimed = await tx.outcomeEvidenceAsset.updateMany({
            where: {
              id: candidate.id,
              processingStatus: 'pending_upload',
              deletedAt: null,
              createdAt: { lt: cutoff },
            },
            data: {
              processingStatus: 'deleted',
              deletedAt: now,
              rejectionCode: 'upload_expired',
              version: { increment: 1 },
            },
          });
          if (claimed.count !== 1) continue;
          await this.outbox.enqueue(
            {
              eventId: `outcome_evidence.deleted:${candidate.id}`,
              eventName: 'outcome_evidence.deleted',
              aggregateType: 'OutcomeEvidenceAsset',
              aggregateId: candidate.id,
              occurredAt: now,
              payload: {
                workspaceId: candidate.workspaceId,
                evidenceId: candidate.id,
                storageKey: candidate.storageKey,
                retentionExpired: true,
              },
            },
            tx,
          );
          count += 1;
        }
        return count;
      }),
    );
    return expired ?? 0;
  }

  /** Public for deterministic operational probes and focused unit tests. */
  async reconcileOnce(limit = 50): Promise<number> {
    const boundedLimit = Math.min(200, Math.max(1, Math.floor(limit)));
    const candidates = await this.prisma.execute(async (prisma) => {
      const [artifacts, evidence] = await Promise.all([
        prisma.$queryRaw<ArtifactPurgeCandidate[]>(Prisma.sql`
          SELECT
            version."id",
            version."artifactId" AS "artifactId",
            artifact."workspaceId" AS "workspaceId",
            version."storageKey" AS "storageKey",
            COALESCE(
              version."rejectionCode" = 'user_deleted',
              false
            ) AS "reasonProvided"
          FROM "ApplicationArtifactVersion" AS version
          INNER JOIN "ApplicationArtifact" AS artifact
            ON artifact."id" = version."artifactId"
          WHERE version."deletedAt" IS NOT NULL
            AND version."storageKey" IS NOT NULL
            AND NOT EXISTS (
              SELECT 1
              FROM "DomainEventOutbox" AS event
              WHERE event."eventId" =
                'artifact.version.deleted:' || version."id"
            )
          ORDER BY version."deletedAt" ASC, version."id" ASC
          LIMIT ${boundedLimit}
        `),
        prisma.$queryRaw<OutcomeEvidencePurgeCandidate[]>(Prisma.sql`
          SELECT
            evidence."id",
            evidence."workspaceId" AS "workspaceId",
            evidence."storageKey" AS "storageKey"
          FROM "OutcomeEvidenceAsset" AS evidence
          WHERE evidence."deletedAt" IS NOT NULL
            AND evidence."storageKey" IS NOT NULL
            AND NOT EXISTS (
              SELECT 1
              FROM "DomainEventOutbox" AS event
              WHERE event."eventId" =
                'outcome_evidence.deleted:' || evidence."id"
            )
          ORDER BY evidence."deletedAt" ASC, evidence."id" ASC
          LIMIT ${boundedLimit}
        `),
      ]);
      return { artifacts, evidence };
    });
    if (!candidates) return 0;

    for (const candidate of candidates.artifacts) {
      await this.outbox.enqueue({
        eventId: `artifact.version.deleted:${candidate.id}`,
        eventName: 'artifact.version.deleted',
        aggregateType: 'ApplicationArtifactVersion',
        aggregateId: candidate.id,
        payload: {
          workspaceId: candidate.workspaceId,
          artifactId: candidate.artifactId,
          versionId: candidate.id,
          storageKey: candidate.storageKey,
          reasonProvided: candidate.reasonProvided,
          reconciled: true,
        },
      });
    }

    for (const candidate of candidates.evidence) {
      await this.outbox.enqueue({
        eventId: `outcome_evidence.deleted:${candidate.id}`,
        eventName: 'outcome_evidence.deleted',
        aggregateType: 'OutcomeEvidenceAsset',
        aggregateId: candidate.id,
        payload: {
          workspaceId: candidate.workspaceId,
          evidenceId: candidate.id,
          storageKey: candidate.storageKey,
          reconciled: true,
        },
      });
    }

    return candidates.artifacts.length + candidates.evidence.length;
  }
}
