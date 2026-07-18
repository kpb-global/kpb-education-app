import type { PrismaService } from '../../prisma/prisma.service';
import type { DomainEventOutboxService } from '../common/domain-event-outbox.service';
import type { FeatureAccessService } from '../common/feature-access.service';
import type { IdempotencyService } from '../common/idempotency.service';
import { OutcomesService } from './outcomes.service';

describe('OutcomesService', () => {
  const execute = jest.fn();
  const prisma = { isEnabled: true, execute } as unknown as PrismaService;
  const evaluate = jest.fn().mockResolvedValue({
    allowed: true,
    feature: 'outcome_evidence',
  });
  const featureAccess = { evaluate } as unknown as FeatureAccessService;
  const reserve = jest.fn().mockResolvedValue({
    state: 'acquired',
    recordId: 'idem-1',
    payloadHash: 'hash',
    expiresAt: new Date('2026-07-18T00:00:00.000Z'),
  });
  const complete = jest.fn();
  const idempotency = { reserve, complete } as unknown as IdempotencyService;
  const enqueue = jest.fn();
  const outbox = { enqueue } as unknown as DomainEventOutboxService;
  const service = new OutcomesService(
    prisma,
    featureAccess,
    idempotency,
    outbox,
  );

  beforeEach(() => {
    jest.clearAllMocks();
    process.env.NODE_ENV = 'test';
    evaluate.mockResolvedValue({
      allowed: true,
      feature: 'outcome_evidence',
    });
    reserve.mockResolvedValue({
      state: 'acquired',
      recordId: 'idem-1',
      payloadHash: 'hash',
      expiresAt: new Date('2026-07-18T00:00:00.000Z'),
    });
  });

  it('appends a submission under the owner lock and never exposes the raw reference', async () => {
    const createdAt = new Date('2026-07-17T09:00:00.000Z');
    const evidence = {
      id: 'evidence-1',
      workspaceId: 'workspace-1',
      kind: 'submission_confirmation',
      originalFileName: 'confirmation.pdf',
      mimeType: 'application/pdf',
      sizeBytes: 120,
      processingStatus: 'clean',
      version: 2,
      rejectionCode: null,
      uploadedAt: createdAt,
      createdAt,
    };
    const createSubmission = jest.fn().mockImplementation(({ data }) => ({
      id: 'submission-1',
      workspaceId: 'workspace-1',
      version: 1,
      lockVersion: 1,
      submittedAt: data.submittedAt,
      submissionChannel: data.submissionChannel,
      applicationRefHash: data.applicationRefHash,
      verificationStatus: 'self_reported',
      verificationNotes: null,
      verifiedAt: null,
      evidence,
      createdAt,
      updatedAt: createdAt,
    }));
    const findEvidence = jest.fn().mockResolvedValue({
      id: 'evidence-1',
      kind: 'submission_confirmation',
      processingStatus: 'clean',
      deletedAt: null,
      storageKey: 'private/key.pdf',
    });
    const tx = {
      $queryRaw: jest.fn().mockResolvedValue([
        { id: 'workspace-1', version: 3, status: 'preparing' },
      ]),
      outcomeEvidenceAsset: { findFirst: findEvidence },
      applicationSubmission: {
        findFirst: jest.fn().mockResolvedValue(null),
        create: createSubmission,
      },
      outcomeEvidenceLink: { create: jest.fn() },
      scholarshipWorkspace: {
        update: jest.fn().mockResolvedValue({
          id: 'workspace-1',
          status: 'submitted',
          version: 4,
        }),
      },
    };
    execute.mockImplementation(async (operation: (db: unknown) => unknown) =>
      operation({
        $transaction: async (callback: (value: unknown) => unknown) =>
          callback(tx),
      }),
    );

    const result = await service.createSubmission(
      'student-1',
      'workspace-1',
      {
        expectedWorkspaceVersion: 3,
        submittedAt: '2026-07-17T08:00:00.000Z',
        submissionChannel: 'official portal',
        applicationReference: '  ab 123  ',
        evidenceId: 'evidence-1',
      },
      'submission-key',
    );

    expect(result.statusCode).toBe(201);
    const createData = createSubmission.mock.calls[0][0].data;
    expect(createData.applicationRefHash).toMatch(/^[0-9a-f]{64}$/);
    expect(createData.applicationRefHash).not.toContain('AB 123');
    expect(JSON.stringify(result)).not.toContain('ab 123');
    expect(JSON.stringify(result)).not.toContain('applicationRefHash');
    expect(findEvidence.mock.calls[0][0].where).toMatchObject({
      id: 'evidence-1',
      workspaceId: 'workspace-1',
      ownerUserId: 'student-1',
    });
    expect(enqueue.mock.calls[0][0]).toMatchObject({
      eventName: 'application_submission_reported',
      payload: {
        workspaceId: 'workspace-1',
        outcomeType: 'submission',
        outcomeId: 'submission-1',
      },
    });
    expect(JSON.stringify(enqueue.mock.calls[0][0])).not.toContain('hash');
    expect(JSON.stringify(enqueue.mock.calls[0][0])).not.toContain('storage');
  });

  it('replays a completed create with HTTP 200 and no new domain write', async () => {
    reserve.mockResolvedValue({
      state: 'replay',
      recordId: 'idem-1',
      payloadHash: 'hash',
      responseCode: 201,
      responseSnapshot: {
        submission: { id: 'submission-1' },
        workspace: { id: 'workspace-1', version: 4 },
      },
      resourceType: 'ApplicationSubmission',
      resourceId: 'submission-1',
      resultingVersion: 1,
      expiresAt: new Date('2026-07-18T00:00:00.000Z'),
    });
    execute.mockImplementation(async (operation: (db: unknown) => unknown) =>
      operation({
        $transaction: async (callback: (value: unknown) => unknown) =>
          callback({}),
      }),
    );

    const result = await service.createSubmission(
      'student-1',
      'workspace-1',
      {
        expectedWorkspaceVersion: 3,
        submittedAt: '2026-07-17T08:00:00.000Z',
        evidenceId: 'evidence-1',
      },
      'submission-key',
    );

    expect(result.statusCode).toBe(200);
    expect(enqueue).not.toHaveBeenCalled();
    expect(complete).not.toHaveBeenCalled();
  });

  it('rejects incoherent funding amount/currency before opening a transaction', async () => {
    await expect(
      service.createFundingDecision(
        'student-1',
        'workspace-1',
        {
          expectedWorkspaceVersion: 3,
          issuedByName: 'Foundation',
          fundingDecision: 'none',
          fundingAmountMinor: '1000',
          fundingCurrency: 'XOF',
          receivedAt: '2026-07-17T08:00:00.000Z',
          evidenceId: 'evidence-1',
        },
        'funding-key',
      ),
    ).rejects.toMatchObject({ status: 400 });
    expect(execute).not.toHaveBeenCalled();
  });

  it('rejects future outcome dates before any mutation', async () => {
    await expect(
      service.createSubmission(
        'student-1',
        'workspace-1',
        {
          expectedWorkspaceVersion: 3,
          submittedAt: '2999-01-01T00:00:00.000Z',
          evidenceId: 'evidence-1',
        },
        'future-key',
      ),
    ).rejects.toMatchObject({ status: 400 });
    expect(execute).not.toHaveBeenCalled();
  });
});
