import type { AdminSessionUser } from '../../auth/auth.service';
import type { PrismaService } from '../../prisma/prisma.service';
import type { DomainEventOutboxService } from '../common/domain-event-outbox.service';
import type { AdminOutcomesAccessService } from './admin-outcomes-access.service';
import { AdminOutcomesService } from './admin-outcomes.service';

describe('AdminOutcomesService verification', () => {
  const execute = jest.fn();
  const prisma = { isEnabled: true, execute } as unknown as PrismaService;
  const whereFor = jest.fn().mockResolvedValue({});
  const assertIndependentVerifier = jest.fn().mockResolvedValue(undefined);
  const access = {
    whereFor,
    assertIndependentVerifier,
  } as unknown as AdminOutcomesAccessService;
  const enqueue = jest.fn();
  const outbox = { enqueue } as unknown as DomainEventOutboxService;
  const service = new AdminOutcomesService(prisma, access, outbox);
  const actor: AdminSessionUser = {
    id: 'moderator-1',
    fullName: 'Moderator One',
    email: 'moderator@kpb.education',
    role: 'moderator',
    languageScope: ['fr'],
  };
  const date = new Date('2026-07-17T10:00:00.000Z');

  beforeEach(() => {
    jest.clearAllMocks();
    whereFor.mockResolvedValue({});
    assertIndependentVerifier.mockResolvedValue(undefined);
  });

  function evidence(overrides: Record<string, unknown> = {}) {
    return {
      id: 'evidence-1',
      workspaceId: 'workspace-1',
      kind: 'admission_decision',
      originalFileName: 'decision.pdf',
      mimeType: 'application/pdf',
      sizeBytes: 120,
      processingStatus: 'clean',
      version: 2,
      rejectionCode: null,
      uploadedAt: date,
      deletedAt: null,
      createdAt: date,
      consentReceipt: { revokedAt: null },
      ...overrides,
    };
  }

  function workspace() {
    return {
      id: 'workspace-1',
      version: 5,
      status: 'decision_received',
      user: {
        id: 'student-1',
        fullName: 'Student One',
        email: 'student@example.test',
      },
      scholarship: {
        id: 'scholarship-1',
        nameFr: 'Bourse',
        nameEn: 'Scholarship',
        countryId: 'country-1',
        countryNameFr: 'Niger',
        countryNameEn: 'Niger',
      },
    };
  }

  function admission(overrides: Record<string, unknown> = {}) {
    return {
      id: 'admission-1',
      workspaceId: 'workspace-1',
      supersedesId: null,
      version: 1,
      lockVersion: 3,
      isCurrent: true,
      issuedByName: 'University',
      admissionDecision: 'admitted',
      issuedAt: date,
      receivedAt: date,
      verificationStatus: 'pending',
      verificationNotes: null,
      verifiedAt: null,
      createdAt: date,
      updatedAt: date,
      evidence: evidence(),
      workspace: workspace(),
      ...overrides,
    };
  }

  it('keeps superseded decision history read-only', async () => {
    execute.mockImplementation(async (operation: (db: unknown) => unknown) =>
      operation({
        applicationDecisionRecord: {
          findFirst: jest.fn().mockResolvedValue(admission({ isCurrent: false })),
        },
      }),
    );

    await expect(
      service.verify(
        actor,
        'admission',
        'admission-1',
        { expectedVersion: 3, status: 'verified' },
        'request-1',
      ),
    ).rejects.toMatchObject({ status: 409 });
    expect(assertIndependentVerifier).not.toHaveBeenCalled();
  });

  it('returns VERSION_CONFLICT on a stale verification lock', async () => {
    const scoped = admission({ lockVersion: 4 });
    const tx = {
      $queryRaw: jest.fn(),
      applicationDecisionRecord: {
        findUnique: jest.fn().mockResolvedValue({
          workspaceId: 'workspace-1',
          lockVersion: 4,
          verificationStatus: 'pending',
          isCurrent: true,
        }),
      },
    };
    execute.mockImplementation(async (operation: (db: unknown) => unknown) =>
      operation({
        applicationDecisionRecord: {
          findFirst: jest.fn().mockResolvedValue(scoped),
        },
        $transaction: async (callback: (value: unknown) => unknown) =>
          callback(tx),
      }),
    );

    await expect(
      service.verify(
        actor,
        'admission',
        'admission-1',
        { expectedVersion: 3, status: 'verified' },
        'request-1',
      ),
    ).rejects.toMatchObject({
      status: 409,
      response: expect.objectContaining({ code: 'VERSION_CONFLICT' }),
    });
  });

  it('requires verified and rejected outcomes to reopen through pending', async () => {
    execute.mockImplementation(async (operation: (db: unknown) => unknown) =>
      operation({
        applicationDecisionRecord: {
          findFirst: jest.fn().mockResolvedValue(
            admission({
              verificationStatus: 'verified',
              verifiedAt: date,
            }),
          ),
        },
      }),
    );

    await expect(
      service.verify(
        actor,
        'admission',
        'admission-1',
        {
          expectedVersion: 3,
          status: 'rejected',
          reasonCode: 'invalid_document',
        },
        'request-1',
      ),
    ).rejects.toMatchObject({ status: 400 });
  });

  it('blocks verification when consent is revoked or evidence is unclean', async () => {
    execute.mockImplementation(async (operation: (db: unknown) => unknown) =>
      operation({
        applicationDecisionRecord: {
          findFirst: jest.fn().mockResolvedValue(
            admission({
              evidence: evidence({
                processingStatus: 'rejected',
                consentReceipt: { revokedAt: date },
              }),
            }),
          ),
        },
      }),
    );

    await expect(
      service.verify(
        actor,
        'admission',
        'admission-1',
        { expectedVersion: 3, status: 'verified' },
        'request-1',
      ),
    ).rejects.toMatchObject({ status: 422 });
  });

  it('writes only transition metadata to audit and a generic outbox payload', async () => {
    const before = admission();
    const after = admission({
      lockVersion: 4,
      verificationStatus: 'verified',
      verificationNotes: 'private verification note',
      verifiedAt: date,
    });
    const createAudit = jest.fn().mockResolvedValue({ id: 'audit-1' });
    const findUnique = jest
      .fn()
      .mockResolvedValueOnce({
        workspaceId: 'workspace-1',
        lockVersion: 3,
        verificationStatus: 'pending',
        isCurrent: true,
      })
      .mockResolvedValueOnce(after);
    const tx = {
      $queryRaw: jest.fn(),
      applicationDecisionRecord: {
        findUnique,
        updateMany: jest.fn().mockResolvedValue({ count: 1 }),
      },
      outcomeVerificationEvent: { create: jest.fn() },
      adminAuditEvent: { create: createAudit },
    };
    execute.mockImplementation(async (operation: (db: unknown) => unknown) =>
      operation({
        applicationDecisionRecord: {
          findFirst: jest.fn().mockResolvedValue(before),
        },
        outcomeEvidenceLink: {
          findMany: jest.fn().mockResolvedValue([]),
        },
        $transaction: async (callback: (value: unknown) => unknown) =>
          callback(tx),
      }),
    );

    const result = await service.verify(
      actor,
      'admission',
      'admission-1',
      {
        expectedVersion: 3,
        status: 'verified',
        notes: 'private verification note',
      },
      'request-1',
    );

    expect(result.outcome).toMatchObject({
      id: 'admission-1',
      lockVersion: 4,
      verificationStatus: 'verified',
    });
    const auditPayload = createAudit.mock.calls[0][0].data;
    expect(auditPayload.changes).toEqual({
      fromStatus: 'pending',
      toStatus: 'verified',
      notesProvided: true,
    });
    expect(JSON.stringify(auditPayload)).not.toContain(
      'private verification note',
    );
    expect(enqueue.mock.calls[0][0]).toMatchObject({
      eventName: 'application_decision_verified',
      payload: {
        workspaceId: 'workspace-1',
        outcomeType: 'admission',
        outcomeId: 'admission-1',
      },
    });
    expect(JSON.stringify(enqueue.mock.calls[0][0])).not.toContain('admitted');
    expect(JSON.stringify(enqueue.mock.calls[0][0])).not.toContain('private');
  });
});
