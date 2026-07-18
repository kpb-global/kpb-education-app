import { Readable } from 'node:stream';

import type { AdminSessionUser } from '../../auth/auth.service';
import type { PrismaService } from '../../prisma/prisma.service';
import type { StorageService } from '../../storage/storage.service';
import { AdminOutcomeEvidenceService } from './admin-outcome-evidence.service';
import type { AdminOutcomesAccessService } from './admin-outcomes-access.service';

describe('AdminOutcomeEvidenceService', () => {
  const execute = jest.fn();
  const prisma = { isEnabled: true, execute } as unknown as PrismaService;
  const getObject = jest.fn().mockResolvedValue({
    stream: Readable.from(Buffer.from('evidence')),
    mimeType: 'application/pdf',
    sizeBytes: 8,
  });
  const storage = { getObject } as unknown as StorageService;
  const assertEnvironment = jest.fn();
  const assertIndependentVerifier = jest.fn().mockResolvedValue(undefined);
  const whereFor = jest.fn().mockResolvedValue({});
  const access = {
    assertEnvironment,
    assertIndependentVerifier,
    whereFor,
  } as unknown as AdminOutcomesAccessService;
  const service = new AdminOutcomeEvidenceService(prisma, storage, access);
  const actor = (id: string): AdminSessionUser => ({
    id,
    fullName: id,
    email: `${id}@kpb.education`,
    role: 'moderator',
    languageScope: ['fr'],
  });

  const evidence = {
    id: 'evidence-1',
    workspaceId: 'workspace-1',
    originalFileName: 'decision.pdf',
    mimeType: 'application/pdf',
    storageKey: '2026-07-17/00000000-0000-4000-8000-000000000001.pdf',
    processingStatus: 'clean',
    deletedAt: null,
    consentReceipt: { revokedAt: null },
  };

  beforeEach(() => {
    jest.clearAllMocks();
    whereFor.mockResolvedValue({});
    assertIndependentVerifier.mockResolvedValue(undefined);
    getObject.mockResolvedValue({
      stream: Readable.from(Buffer.from('evidence')),
      mimeType: 'application/pdf',
      sizeBytes: 8,
    });
  });

  function mockAuthorized() {
    const auditCreate = jest.fn().mockResolvedValue({ id: 'audit-1' });
    execute.mockImplementation(async (operation: (db: unknown) => unknown) =>
      operation({
        outcomeEvidenceAsset: {
          findFirst: jest.fn().mockResolvedValue(evidence),
        },
        outcomeEvidenceLink: { findMany: jest.fn().mockResolvedValue([]) },
        applicationSubmission: {
          findFirst: jest.fn().mockResolvedValue({
            id: 'submission-1',
            workspaceId: 'workspace-1',
          }),
        },
        applicationDecisionRecord: {
          findFirst: jest.fn().mockResolvedValue(null),
        },
        fundingDecisionRecord: {
          findFirst: jest.fn().mockResolvedValue(null),
        },
        adminAuditEvent: { create: auditCreate },
      }),
    );
    return auditCreate;
  }

  it('issues an actor-bound, short-lived URL keyed by outcome evidenceId and audits it', async () => {
    const auditCreate = mockAuthorized();

    const result = await service.issueAccess(
      actor('moderator-1'),
      'evidence-1',
      'request-1',
    );

    expect(result.accessUrl).toContain('/outcome-evidence/evidence-1/download');
    expect(result.accessUrl).not.toContain('storageKey');
    expect(auditCreate).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          action: 'outcome.evidence_access_issued',
          entityType: 'OutcomeEvidenceAsset',
          entityId: 'evidence-1',
        }),
      }),
    );
    expect(JSON.stringify(auditCreate.mock.calls)).not.toContain(
      evidence.storageKey,
    );
  });

  it('rejects use of a valid token by a different actor', async () => {
    mockAuthorized();
    const issued = await service.issueAccess(
      actor('moderator-1'),
      'evidence-1',
      'request-1',
    );
    const token = new URL(`https://local${issued.accessUrl}`).searchParams.get(
      'accessToken',
    );

    await expect(
      service.download(
        actor('moderator-2'),
        'evidence-1',
        token!,
        'request-2',
      ),
    ).rejects.toMatchObject({ status: 403 });
    expect(getObject).not.toHaveBeenCalled();
  });

  it('rejects an expired token before reading storage', async () => {
    jest.useFakeTimers().setSystemTime(new Date('2026-07-17T10:00:00.000Z'));
    try {
      mockAuthorized();
      const issued = await service.issueAccess(
        actor('moderator-1'),
        'evidence-1',
        'request-1',
      );
      const token = new URL(
        `https://local${issued.accessUrl}`,
      ).searchParams.get('accessToken');
      jest.setSystemTime(new Date('2026-07-17T10:02:00.000Z'));

      await expect(
        service.download(
          actor('moderator-1'),
          'evidence-1',
          token!,
          'request-2',
        ),
      ).rejects.toMatchObject({ status: 403 });
      expect(getObject).not.toHaveBeenCalled();
    } finally {
      jest.useRealTimers();
    }
  });

  it('fails closed when consent is revoked or the file is not clean', async () => {
    execute.mockImplementation(async (operation: (db: unknown) => unknown) =>
      operation({
        outcomeEvidenceAsset: { findFirst: jest.fn().mockResolvedValue(null) },
      }),
    );

    await expect(
      service.issueAccess(
        actor('moderator-1'),
        'evidence-1',
        'request-1',
      ),
    ).rejects.toMatchObject({ status: 403 });
  });
});
