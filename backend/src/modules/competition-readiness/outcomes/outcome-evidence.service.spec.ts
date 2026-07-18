import type { PrismaService } from '../../prisma/prisma.service';
import type { StorageService } from '../../storage/storage.service';
import type { DomainEventOutboxService } from '../common/domain-event-outbox.service';
import type { FeatureAccessService } from '../common/feature-access.service';
import type { IdempotencyService } from '../common/idempotency.service';
import { OutcomeEvidenceService } from './outcome-evidence.service';

describe('OutcomeEvidenceService', () => {
  const execute = jest.fn();
  const prisma = { isEnabled: true, execute } as unknown as PrismaService;
  const storage = {
    maxBytes: 10 * 1024 * 1024,
    save: jest.fn(),
    delete: jest.fn(),
  } as unknown as StorageService;
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
  const service = new OutcomeEvidenceService(
    prisma,
    storage,
    featureAccess,
    idempotency,
    outbox,
  );
  const createdAt = new Date('2026-07-17T10:00:00.000Z');

  beforeEach(() => {
    jest.clearAllMocks();
    delete process.env.KPB_OUTCOME_EVIDENCE_MAX_PENDING_PER_WORKSPACE;
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

  it('creates a bounded private upload intent and hides hash/storage metadata', async () => {
    const createEvidence = jest.fn().mockImplementation(({ data }) => ({
      id: 'evidence-1',
      workspaceId: 'workspace-1',
      kind: data.kind,
      originalFileName: data.originalFileName,
      mimeType: data.mimeType,
      sizeBytes: data.sizeBytes,
      processingStatus: 'pending_upload',
      version: 1,
      rejectionCode: null,
      uploadedAt: null,
      deletedAt: null,
      createdAt,
      updatedAt: createdAt,
    }));
    const tx = {
      scholarshipWorkspace: {
        findFirst: jest.fn().mockResolvedValue({ id: 'workspace-1' }),
      },
      $queryRaw: jest.fn(),
      outcomeEvidenceAsset: {
        count: jest.fn().mockResolvedValue(0),
        create: createEvidence,
      },
      consentReceipt: {
        findFirst: jest.fn().mockResolvedValue({ id: 'receipt-1' }),
      },
    };
    execute.mockImplementation(async (operation: (db: unknown) => unknown) =>
      operation({
        $transaction: async (callback: (value: unknown) => unknown) =>
          callback(tx),
      }),
    );

    const result = await service.initiateUpload(
      'student-1',
      'workspace-1',
      {
        kind: 'submission_confirmation',
        originalFileName: ' Confirmation.PDF ',
        mimeType: 'APPLICATION/PDF',
        sizeBytes: 120,
        sha256: 'A'.repeat(64),
        consentReceiptId: 'receipt-1',
      },
      'upload-key',
    );

    expect(result.statusCode).toBe(201);
    expect(createEvidence.mock.calls[0][0].data.sha256).toBe('a'.repeat(64));
    expect(createEvidence.mock.calls[0][0].data).toMatchObject({
      ownerUserId: 'student-1',
      workspaceId: 'workspace-1',
      consentReceiptId: 'receipt-1',
    });
    expect(JSON.stringify(result.intent)).not.toContain('sha256');
    expect(JSON.stringify(result.intent)).not.toContain('storageKey');
    expect(JSON.stringify(enqueue.mock.calls[0][0])).not.toContain('sha256');
  });

  it('returns replayed upload intents with HTTP 200', async () => {
    reserve.mockResolvedValue({
      state: 'replay',
      recordId: 'idem-1',
      payloadHash: 'hash',
      responseCode: 201,
      responseSnapshot: {
        uploadMode: 'multipart',
        uploadUrl:
          '/api/competition-readiness/outcome-evidence/evidence-1/complete',
        expiresAt: null,
        evidence: { id: 'evidence-1' },
      },
      resourceType: 'OutcomeEvidenceAsset',
      resourceId: 'evidence-1',
      resultingVersion: 1,
      expiresAt: new Date('2026-07-18T00:00:00.000Z'),
    });
    execute.mockImplementation(async (operation: (db: unknown) => unknown) =>
      operation({
        $transaction: async (callback: (value: unknown) => unknown) =>
          callback({}),
      }),
    );

    const result = await service.initiateUpload(
      'student-1',
      'workspace-1',
      {
        kind: 'submission_confirmation',
        originalFileName: 'confirmation.pdf',
        mimeType: 'application/pdf',
        sizeBytes: 120,
        sha256: 'a'.repeat(64),
        consentReceiptId: 'receipt-1',
      },
      'upload-key',
    );

    expect(result.statusCode).toBe(200);
    expect(enqueue).not.toHaveBeenCalled();
  });

  it('rate-limits pending intents under a locked workspace', async () => {
    const tx = {
      scholarshipWorkspace: {
        findFirst: jest.fn().mockResolvedValue({ id: 'workspace-1' }),
      },
      $queryRaw: jest.fn(),
      outcomeEvidenceAsset: { count: jest.fn().mockResolvedValue(20) },
    };
    execute.mockImplementation(async (operation: (db: unknown) => unknown) =>
      operation({
        $transaction: async (callback: (value: unknown) => unknown) =>
          callback(tx),
      }),
    );

    await expect(
      service.initiateUpload(
        'student-1',
        'workspace-1',
        {
          kind: 'submission_confirmation',
          originalFileName: 'confirmation.pdf',
          mimeType: 'application/pdf',
          sizeBytes: 120,
          sha256: 'a'.repeat(64),
          consentReceiptId: 'receipt-1',
        },
        'upload-key',
      ),
    ).rejects.toMatchObject({ status: 429 });
    expect(tx.$queryRaw).toHaveBeenCalled();
  });

  it('fails closed before DB access when the feature policy denies access', async () => {
    evaluate.mockResolvedValue({
      allowed: false,
      feature: 'outcome_evidence',
      reason: 'feature_disabled',
    });

    await expect(
      service.initiateUpload(
        'student-1',
        'workspace-1',
        {
          kind: 'submission_confirmation',
          originalFileName: 'confirmation.pdf',
          mimeType: 'application/pdf',
          sizeBytes: 120,
          sha256: 'a'.repeat(64),
          consentReceiptId: 'receipt-1',
        },
        'upload-key',
      ),
    ).rejects.toMatchObject({ status: 404 });
    expect(execute).not.toHaveBeenCalled();
  });
});
