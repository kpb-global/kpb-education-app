import type { PrismaService } from '../../prisma/prisma.service';
import { CompetitionReadinessHttpException } from '../common/competition-readiness.errors';
import type { DomainEventOutboxService } from '../common/domain-event-outbox.service';
import type { IdempotencyService } from '../common/idempotency.service';
import type { AdminReviewAccessService } from './admin-review-access.service';
import { AdminReviewOperationsService } from './admin-review-operations.service';

describe('AdminReviewOperationsService', () => {
  const previousFlag = process.env.KPB_STUDY_REVIEW_ENABLED;
  const execute = jest.fn();
  const prisma = { isEnabled: true, execute } as unknown as PrismaService;
  const access = {
    assertReviewFeatureEnabled: jest.fn(),
    listScope: jest.fn(),
    assertCanReadDetail: jest.fn().mockResolvedValue('full'),
    assertCanOpenEvidence: jest.fn(),
    assertCanTriage: jest.fn(),
    assertCanAssign: jest.fn(),
    assertCanConvert: jest.fn(),
    isCounselor: jest.fn().mockReturnValue(false),
    isPlatformAdmin: jest.fn().mockReturnValue(true),
    resolveCounsellor: jest.fn(),
  } as unknown as AdminReviewAccessService;
  const reserve = jest.fn();
  const complete = jest.fn();
  const idempotency = { reserve, complete } as unknown as IdempotencyService;
  const enqueue = jest.fn();
  const outbox = { enqueue } as unknown as DomainEventOutboxService;
  const service = new AdminReviewOperationsService(
    prisma,
    access,
    idempotency,
    outbox,
  );
  const actor = {
    id: 'admin-1',
    fullName: 'Admin KPB',
    email: 'admin@kpb.test',
    role: 'admin',
  };

  beforeEach(() => {
    jest.clearAllMocks();
    process.env.KPB_STUDY_REVIEW_ENABLED = 'true';
    (access.assertCanReadDetail as jest.Mock).mockResolvedValue('full');
    (access.isCounselor as jest.Mock).mockReturnValue(false);
    (access.isPlatformAdmin as jest.Mock).mockReturnValue(true);
  });

  afterAll(() => {
    if (previousFlag === undefined) delete process.env.KPB_STUDY_REVIEW_ENABLED;
    else process.env.KPB_STUDY_REVIEW_ENABLED = previousFlag;
  });

  it('returns commercial metadata without student messages or artifacts', async () => {
    const row = reviewFixture();
    (access.listScope as jest.Mock).mockResolvedValue({
      where: { status: { in: ['triaged'] } },
      projection: 'metadata',
      counsellorId: null,
    });
    execute.mockImplementation(async (operation: (db: unknown) => unknown) =>
      operation({
        studyReviewRequest: {
          findMany: jest.fn().mockResolvedValue([row]),
          count: jest.fn().mockResolvedValue(1),
        },
        country: {
          findMany: jest.fn().mockResolvedValue([{ id: 'niger', code: 'NE' }]),
        },
        $transaction: (operations: Promise<unknown>[]) =>
          Promise.all(operations),
      }),
    );

    const result = await service.list(
      { ...actor, role: 'commercial' },
      { limit: 20 },
    );

    expect(result.items[0]).toMatchObject({
      id: 'review-1',
      projection: 'metadata',
      scholarship: { countryCodes: ['NE'] },
    });
    expect(JSON.stringify(result)).not.toContain('private student message');
    expect(JSON.stringify(result)).not.toContain('artifactVersionId');
  });

  it('returns a redacted direct detail projection to an authorized commercial', async () => {
    const row = reviewFixture({ status: 'triaged' });
    (access.assertCanReadDetail as jest.Mock).mockResolvedValue('metadata');
    (access.assertCanOpenEvidence as jest.Mock).mockRejectedValue(
      new CompetitionReadinessHttpException(
        'FORBIDDEN_SCOPE',
        403,
        'Evidence is private.',
      ),
    );
    execute
      .mockImplementationOnce(
        async (operation: (db: unknown) => unknown) =>
          operation({
            studyReviewRequest: {
              findUnique: jest.fn().mockResolvedValue(row),
            },
          }),
      )
      .mockImplementationOnce(
        async (operation: (db: unknown) => unknown) =>
          operation({
            country: {
              findMany: jest
                .fn()
                .mockResolvedValue([{ id: 'niger', code: 'NE' }]),
            },
          }),
      );

    const result = await service.getDetail(
      { ...actor, role: 'commercial' },
      'review-1',
    );

    expect(result).toMatchObject({
      id: 'review-1',
      status: 'triaged',
      projection: 'metadata',
      timezone: 'UTC',
      studentMessage: null,
      preferredContact: null,
      availability: null,
      triageSummary: null,
      missingItems: null,
      artifacts: [],
      audit: [],
    });
    expect(JSON.stringify(result)).not.toContain('private');
  });

  it('rejects a stale triage version before update, audit or outbox', async () => {
    const tx = {
      $queryRaw: jest.fn(),
      studyReviewRequest: {
        findUnique: jest.fn().mockResolvedValue(reviewFixture({ version: 2 })),
        updateMany: jest.fn(),
      },
      adminAuditEvent: { create: jest.fn() },
    };
    execute.mockImplementation(async (operation: (db: unknown) => unknown) =>
      operation({
        $transaction: async (callback: (value: unknown) => unknown) =>
          callback(tx),
      }),
    );

    await expect(
      service.triage(
        actor,
        'review-1',
        {
          expectedVersion: 1,
          action: 'triage',
          reasonCode: 'human_review_completed',
        },
        'request-1',
      ),
    ).rejects.toMatchObject({
      status: 409,
      response: expect.objectContaining({ code: 'VERSION_CONFLICT' }),
    });
    expect(tx.studyReviewRequest.updateMany).not.toHaveBeenCalled();
    expect(tx.adminAuditEvent.create).not.toHaveBeenCalled();
    expect(enqueue).not.toHaveBeenCalled();
  });

  it('writes triage, redacted audit metadata and outbox atomically', async () => {
    const current = reviewFixture();
    const updated = reviewFixture({
      version: 2,
      status: 'triaged',
      triagedAt: new Date('2026-07-17T11:00:00.000Z'),
    });
    const tx = {
      $queryRaw: jest.fn(),
      studyReviewRequest: {
        findUnique: jest.fn().mockResolvedValue(current),
        updateMany: jest.fn().mockResolvedValue({ count: 1 }),
      },
      counsellor: { findFirst: jest.fn() },
      scholarshipWorkspace: { update: jest.fn() },
      adminAuditEvent: { create: jest.fn() },
    };
    execute
      .mockImplementationOnce(
        async (operation: (db: unknown) => unknown) =>
          operation({
            $transaction: async (callback: (value: unknown) => unknown) =>
              callback(tx),
          }),
      )
      .mockImplementationOnce(
        async (operation: (db: unknown) => unknown) =>
          operation({
            studyReviewRequest: {
              findUnique: jest.fn().mockResolvedValue(updated),
            },
          }),
      )
      .mockImplementationOnce(
        async (operation: (db: unknown) => unknown) =>
          operation({
            adminAuditEvent: { findMany: jest.fn().mockResolvedValue([]) },
            adminUser: { findMany: jest.fn() },
            country: {
              findMany: jest
                .fn()
                .mockResolvedValue([{ id: 'niger', code: 'NE' }]),
            },
          }),
      );

    const result = await service.triage(
      actor,
      'review-1',
      {
        expectedVersion: 1,
        action: 'triage',
        triageSummary: 'private triage narrative',
        reasonCode: 'human_review_completed',
      },
      'request-1',
    );

    expect(result).toMatchObject({ id: 'review-1', status: 'triaged' });
    const auditData = tx.adminAuditEvent.create.mock.calls[0][0].data;
    expect(auditData).toMatchObject({
      requestId: 'request-1',
      reasonCode: 'human_review_completed',
      changes: expect.objectContaining({
        previousVersion: 1,
        nextVersion: 2,
        triageSummaryChanged: true,
      }),
    });
    expect(JSON.stringify(auditData.changes)).not.toContain(
      'private triage narrative',
    );
    expect(enqueue).toHaveBeenCalledWith(
      expect.objectContaining({ eventName: 'study_review.triage' }),
      tx,
    );
  });

  it('converts a triaged review once without creating a purchase or payment', async () => {
    const current = reviewFixture({
      version: 3,
      status: 'triaged',
      triagedAt: new Date('2026-07-17T10:00:00.000Z'),
    });
    reserve.mockResolvedValue({
      state: 'acquired',
      recordId: 'idem-1',
      payloadHash: 'hash',
      expiresAt: new Date('2026-07-18T00:00:00.000Z'),
    });
    const createCase = jest.fn().mockResolvedValue({
      id: 'case-1',
      seq: 42,
      createdAt: new Date('2026-07-17T10:30:00.000Z'),
    });
    const paymentCreate = jest.fn();
    const purchaseCreate = jest.fn();
    const tx = {
      $queryRaw: jest.fn(),
      studyReviewRequest: {
        findUnique: jest.fn().mockResolvedValue(current),
        updateMany: jest.fn().mockResolvedValue({ count: 1 }),
      },
      case: { create: createCase, update: jest.fn() },
      caseTimelineEvent: { create: jest.fn() },
      servicePurchase: { create: purchaseCreate },
      paymentIntent: { create: paymentCreate },
      adminAuditEvent: { create: jest.fn() },
    };
    execute.mockImplementation(async (operation: (db: unknown) => unknown) =>
      operation({
        $transaction: async (callback: (value: unknown) => unknown) =>
          callback(tx),
      }),
    );

    const result = await service.convertToCase(
      { ...actor, role: 'commercial' },
      'review-1',
      {
        expectedVersion: 3,
        reasonCode: 'review_triaged_for_case_conversion',
      },
      'convert-key-1',
      'request-2',
    );

    expect(result).toEqual({
      statusCode: 201,
      body: { caseId: 'case-1', purchaseId: null },
    });
    expect(createCase).toHaveBeenCalledTimes(1);
    expect(purchaseCreate).not.toHaveBeenCalled();
    expect(paymentCreate).not.toHaveBeenCalled();
    expect(complete).toHaveBeenCalledWith(
      expect.objectContaining({
        responseSnapshot: { caseId: 'case-1', purchaseId: null },
      }),
      tx,
    );
  });

  it('replays a completed conversion without touching Case', async () => {
    reserve.mockResolvedValue({
      state: 'replay',
      recordId: 'idem-1',
      payloadHash: 'hash',
      responseCode: 201,
      responseSnapshot: { caseId: 'case-1', purchaseId: null },
      resourceType: 'Case',
      resourceId: 'case-1',
      resultingVersion: 4,
      expiresAt: new Date('2026-07-18T00:00:00.000Z'),
    });
    const createCase = jest.fn();
    execute.mockImplementation(async (operation: (db: unknown) => unknown) =>
      operation({
        $transaction: async (callback: (value: unknown) => unknown) =>
          callback({ case: { create: createCase } }),
      }),
    );

    await expect(
      service.convertToCase(
        { ...actor, role: 'commercial' },
        'review-1',
        {
          expectedVersion: 3,
          reasonCode: 'review_triaged_for_case_conversion',
        },
        'convert-key-1',
        'request-2',
      ),
    ).resolves.toEqual({
      statusCode: 201,
      body: { caseId: 'case-1', purchaseId: null },
    });
    expect(createCase).not.toHaveBeenCalled();
  });

  it('returns the already linked Case for a different retry key', async () => {
    reserve.mockResolvedValue({
      state: 'acquired',
      recordId: 'idem-2',
      payloadHash: 'hash',
      expiresAt: new Date('2026-07-18T00:00:00.000Z'),
    });
    const createCase = jest.fn();
    const tx = {
      $queryRaw: jest.fn(),
      studyReviewRequest: {
        findUnique: jest.fn().mockResolvedValue(
          reviewFixture({
            version: 4,
            status: 'converted_to_case',
            resultingCaseId: 'case-1',
          }),
        ),
      },
      case: { create: createCase },
    };
    execute.mockImplementation(async (operation: (db: unknown) => unknown) =>
      operation({
        $transaction: async (callback: (value: unknown) => unknown) =>
          callback(tx),
      }),
    );

    await expect(
      service.convertToCase(
        { ...actor, role: 'commercial' },
        'review-1',
        {
          expectedVersion: 3,
          reasonCode: 'review_triaged_for_case_conversion',
        },
        'different-key',
        'request-3',
      ),
    ).resolves.toEqual({
      statusCode: 200,
      body: { caseId: 'case-1', purchaseId: null },
    });
    expect(createCase).not.toHaveBeenCalled();
  });
});

function reviewFixture(overrides: Record<string, unknown> = {}) {
  const now = new Date('2026-07-17T09:00:00.000Z');
  return {
    id: 'review-1',
    workspaceId: 'workspace-1',
    requestNumber: 1,
    version: 1,
    status: 'submitted',
    assignedCounsellorId: 'counsellor-1',
    studentMessage: 'private student message',
    preferredContact: 'in_app',
    timezone: 'Africa/Niamey',
    availability: { weekdays: ['monday'] },
    triageSummary: null,
    missingItems: null,
    submittedAt: now,
    triagedAt: null,
    closedAt: null,
    resultingCaseId: null,
    resultingPurchaseId: null,
    createdAt: now,
    updatedAt: now,
    assignedCounsellor: { id: 'counsellor-1', fullName: 'Counsellor One' },
    workspace: {
      id: 'workspace-1',
      userId: 'student-1',
      status: 'review_requested',
      version: 2,
      scholarshipCycleId: 'cycle-1',
      scholarship: {
        id: 'scholarship-1',
        nameFr: 'Bourse KPB',
        countryId: 'niger',
      },
    },
    artifactShares: [
      {
        id: 'share-1',
        artifactVersionId: 'version-1',
        grantedAt: now,
        revokedAt: null,
        consentReceipt: { revokedAt: null },
        artifactVersion: {
          id: 'version-1',
          originalFileName: 'cv.pdf',
          mimeType: 'application/pdf',
          processingStatus: 'clean',
          deletedAt: null,
          artifact: { kind: 'cv' },
        },
      },
    ],
    ...overrides,
  };
}
