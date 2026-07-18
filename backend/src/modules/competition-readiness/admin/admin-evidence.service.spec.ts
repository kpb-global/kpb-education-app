import { Readable } from 'node:stream';

import { HttpStatus } from '@nestjs/common';

import { InternalRole } from '../../../common/enums/internal-role.enum';
import type { PrismaService } from '../../prisma/prisma.service';
import type { StorageService } from '../../storage/storage.service';
import { CompetitionReadinessHttpException } from '../common/competition-readiness.errors';
import { AdminEvidenceService } from './admin-evidence.service';
import {
  type AdminReviewActor,
  AdminReviewAccessService,
} from './admin-review-access.service';

describe('AdminEvidenceService', () => {
  const previousSecret = process.env.KPB_EVIDENCE_ACCESS_SECRET;
  const previousNodeEnv = process.env.NODE_ENV;
  const studyReviewArtifactShareFindMany = jest.fn();
  const studyReviewArtifactShareFindFirst = jest.fn();
  const adminAuditEventCreate = jest.fn();
  const database = {
    studyReviewArtifactShare: {
      findMany: studyReviewArtifactShareFindMany,
      findFirst: studyReviewArtifactShareFindFirst,
    },
    adminAuditEvent: { create: adminAuditEventCreate },
  };
  const execute = jest.fn(
    async (operation: (client: typeof database) => unknown) =>
      operation(database),
  );
  const prisma = { isEnabled: true, execute } as unknown as PrismaService;
  const getObject = jest.fn();
  const storage = { getObject } as unknown as StorageService;
  const assertReviewFeatureEnabled = jest.fn();
  const assertCanOpenEvidence = jest.fn();
  const access = {
    assertReviewFeatureEnabled,
    assertCanOpenEvidence,
  } as unknown as AdminReviewAccessService;
  const service = new AdminEvidenceService(prisma, storage, access);

  const counselor = actor('admin-counselor-1');
  const share = evidenceShare();
  const storedObject = {
    stream: Readable.from(Buffer.from('%PDF-evidence')),
    mimeType: 'application/pdf',
    sizeBytes: 13,
  };

  beforeEach(() => {
    jest.clearAllMocks();
    process.env.NODE_ENV = 'test';
    process.env.KPB_EVIDENCE_ACCESS_SECRET =
      'unit-test-evidence-secret-with-sufficient-entropy';
    studyReviewArtifactShareFindMany.mockResolvedValue([share]);
    studyReviewArtifactShareFindFirst.mockResolvedValue(share);
    adminAuditEventCreate.mockResolvedValue({ id: 'audit-1' });
    assertCanOpenEvidence.mockResolvedValue(undefined);
    getObject.mockResolvedValue(storedObject);
  });

  afterAll(() => {
    if (previousSecret === undefined) {
      delete process.env.KPB_EVIDENCE_ACCESS_SECRET;
    } else {
      process.env.KPB_EVIDENCE_ACCESS_SECRET = previousSecret;
    }
    if (previousNodeEnv === undefined) delete process.env.NODE_ENV;
    else process.env.NODE_ENV = previousNodeEnv;
  });

  it('refuses evidence issuance when the access policy identifies an unassigned counselor', async () => {
    assertCanOpenEvidence.mockRejectedValue(forbiddenScope());

    await expect(
      service.issueAccess(
        counselor,
        'version-1',
        'study_review_document',
        'request-1',
      ),
    ).rejects.toMatchObject({
      status: 403,
      response: expect.objectContaining({ code: 'FORBIDDEN_SCOPE' }),
    });

    expect(adminAuditEventCreate).not.toHaveBeenCalled();
    expect(getObject).not.toHaveBeenCalled();
  });

  it('requires an active share, active consent and a clean non-deleted stored version', async () => {
    studyReviewArtifactShareFindMany.mockResolvedValue([]);

    await expect(
      service.issueAccess(
        counselor,
        'version-1',
        'study_review_document',
        'request-1',
      ),
    ).rejects.toMatchObject({
      status: 403,
      response: expect.objectContaining({ code: 'FORBIDDEN_SCOPE' }),
    });

    expect(studyReviewArtifactShareFindMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: {
          artifactVersionId: 'version-1',
          revokedAt: null,
          consentReceipt: { revokedAt: null },
          artifactVersion: {
            processingStatus: 'clean',
            deletedAt: null,
            storageKey: { not: null },
          },
        },
      }),
    );
    expect(assertCanOpenEvidence).not.toHaveBeenCalled();
    expect(adminAuditEventCreate).not.toHaveBeenCalled();
  });

  it('persists the access audit before issuing a short-lived actor/version-bound ticket', async () => {
    const result = await service.issueAccess(
      counselor,
      'version-1',
      'study_review_document',
      'request-1',
    );

    expect(result).toMatchObject({
      accessUrl: expect.stringContaining(
        '/api/admin/competition-readiness/evidence/version-1/download?accessToken=',
      ),
      expiresAt: expect.any(String),
      cacheControl: 'no-store',
      auditEventId: 'audit-1',
    });
    expect(adminAuditEventCreate).toHaveBeenCalledWith({
      data: expect.objectContaining({
        actorAdminId: counselor.id,
        action: 'study_review.evidence_access_issued',
        purposeCode: 'study_review_document',
        entityType: 'ApplicationArtifactVersion',
        entityId: 'version-1',
        requestId: 'request-1',
        result: 'success',
        changes: expect.objectContaining({
          reviewRequestId: 'review-1',
          shareId: 'share-1',
        }),
      }),
      select: { id: true },
    });
    expect(getObject).not.toHaveBeenCalled();
  });

  it('fails closed instead of returning an access ticket when its audit cannot be persisted', async () => {
    adminAuditEventCreate.mockResolvedValue(null);

    await expect(
      service.issueAccess(
        counselor,
        'version-1',
        'study_review_document',
        'request-1',
      ),
    ).rejects.toMatchObject({
      status: 503,
      response: expect.objectContaining({ code: 'DATABASE_UNAVAILABLE' }),
    });

    expect(getObject).not.toHaveBeenCalled();
  });

  it('rejects a validly signed ticket when either its actor or version changes', async () => {
    const issued = await service.issueAccess(
      counselor,
      'version-1',
      'study_review_document',
      'request-1',
    );
    const accessToken = tokenFrom(issued.accessUrl);
    studyReviewArtifactShareFindFirst.mockClear();
    adminAuditEventCreate.mockClear();
    assertCanOpenEvidence.mockClear();
    getObject.mockClear();

    await expect(
      service.download(
        actor('another-admin'),
        'version-1',
        accessToken,
        'request-2',
      ),
    ).rejects.toMatchObject({
      status: 403,
      response: expect.objectContaining({ code: 'FORBIDDEN_SCOPE' }),
    });
    await expect(
      service.download(
        counselor,
        'version-2',
        accessToken,
        'request-3',
      ),
    ).rejects.toMatchObject({
      status: 403,
      response: expect.objectContaining({ code: 'FORBIDDEN_SCOPE' }),
    });

    expect(studyReviewArtifactShareFindFirst).not.toHaveBeenCalled();
    expect(assertCanOpenEvidence).not.toHaveBeenCalled();
    expect(getObject).not.toHaveBeenCalled();
    expect(adminAuditEventCreate).not.toHaveBeenCalled();
  });

  it('revalidates authorization, audits the download and never returns a storageKey', async () => {
    const issued = await service.issueAccess(
      counselor,
      'version-1',
      'study_review_document',
      'request-1',
    );
    const accessToken = tokenFrom(issued.accessUrl);
    studyReviewArtifactShareFindFirst.mockClear();
    adminAuditEventCreate.mockClear();
    assertCanOpenEvidence.mockClear();
    getObject.mockClear();
    adminAuditEventCreate.mockResolvedValue({ id: 'audit-download-1' });

    const result = await service.download(
      counselor,
      'version-1',
      accessToken,
      'request-download-1',
    );

    expect(studyReviewArtifactShareFindFirst).toHaveBeenCalledWith(
      expect.objectContaining({
        where: {
          id: 'share-1',
          artifactVersionId: 'version-1',
          revokedAt: null,
          consentReceipt: { revokedAt: null },
          artifactVersion: {
            processingStatus: 'clean',
            deletedAt: null,
            storageKey: { not: null },
          },
        },
      }),
    );
    expect(assertCanOpenEvidence).toHaveBeenCalledWith(
      counselor,
      share.reviewRequest,
    );
    expect(getObject).toHaveBeenCalledWith(share.artifactVersion.storageKey);
    expect(adminAuditEventCreate).toHaveBeenCalledWith({
      data: expect.objectContaining({
        actorAdminId: counselor.id,
        action: 'study_review.evidence_downloaded',
        purposeCode: 'study_review_document',
        entityId: 'version-1',
        requestId: 'request-download-1',
        changes: {
          reviewRequestId: 'review-1',
          shareId: 'share-1',
        },
      }),
      select: { id: true },
    });
    expect(result).toEqual({
      fileName: 'cv.pdf',
      mimeType: 'application/pdf',
      object: storedObject,
    });
    expect(result).not.toHaveProperty('storageKey');
    expect(result.object).not.toHaveProperty('storageKey');
  });
});

function actor(id: string): AdminReviewActor {
  return {
    id,
    email: `${id}@kpb.education`,
    fullName: id,
    role: InternalRole.Counselor,
  };
}

function evidenceShare() {
  return {
    id: 'share-1',
    reviewRequestId: 'review-1',
    artifactVersionId: 'version-1',
    reviewRequest: {
      id: 'review-1',
      assignedCounsellorId: 'counsellor-1',
      workspace: {
        scholarshipId: 'scholarship-1',
        scholarship: { id: 'scholarship-1', countryId: 'country-ne' },
      },
    },
    artifactVersion: {
      id: 'version-1',
      originalFileName: 'cv.pdf',
      mimeType: 'application/pdf',
      storageKey: '2026-07-17/123e4567-e89b-12d3-a456-426614174000.pdf',
    },
  };
}

function tokenFrom(accessUrl: string): string {
  const token = new URL(accessUrl, 'http://localhost').searchParams.get(
    'accessToken',
  );
  if (!token) throw new Error('Expected evidence access token.');
  return token;
}

function forbiddenScope() {
  return new CompetitionReadinessHttpException(
    'FORBIDDEN_SCOPE',
    HttpStatus.FORBIDDEN,
    'Evidence access is not authorized.',
  );
}
