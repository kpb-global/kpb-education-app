import type { PrismaService } from '../../prisma/prisma.service';
import type { DomainEventOutboxService } from '../common/domain-event-outbox.service';
import type { FeatureAccessService } from '../common/feature-access.service';
import type { IdempotencyService } from '../common/idempotency.service';
import { StudyReviewService } from './study-review.service';

describe('StudyReviewService', () => {
  const previousFlag = process.env.KPB_STUDY_REVIEW_ENABLED;
  const execute = jest.fn();
  const prisma = { isEnabled: true, execute } as unknown as PrismaService;
  const evaluate = jest
    .fn()
    .mockResolvedValue({ allowed: true, feature: 'success_lab' });
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
  const service = new StudyReviewService(
    prisma,
    featureAccess,
    idempotency,
    outbox,
  );

  beforeEach(() => {
    jest.clearAllMocks();
    process.env.KPB_STUDY_REVIEW_ENABLED = 'true';
    evaluate.mockResolvedValue({ allowed: true, feature: 'success_lab' });
    reserve.mockResolvedValue({
      state: 'acquired',
      recordId: 'idem-1',
      payloadHash: 'hash',
      expiresAt: new Date('2026-07-18T00:00:00.000Z'),
    });
  });

  afterAll(() => {
    if (previousFlag === undefined) delete process.env.KPB_STUDY_REVIEW_ENABLED;
    else process.env.KPB_STUDY_REVIEW_ENABLED = previousFlag;
  });

  it('fails closed before touching Prisma when the review flag is absent', async () => {
    delete process.env.KPB_STUDY_REVIEW_ENABLED;
    await expect(
      service.getOne('student-1', 'review-1'),
    ).rejects.toMatchObject({ status: 404 });
    expect(evaluate).not.toHaveBeenCalled();
    expect(execute).not.toHaveBeenCalled();
  });

  it('creates one submitted request with an explicit immutable version snapshot', async () => {
    const createReview = jest.fn().mockResolvedValue(reviewFixture());
    const tx = {
      scholarshipWorkspace: {
        findFirst: jest.fn().mockResolvedValue({
          id: 'workspace-1',
          status: 'preparing',
        }),
        update: jest.fn(),
      },
      studyReviewRequest: {
        findFirst: jest.fn().mockResolvedValueOnce(null).mockResolvedValueOnce(null),
        create: createReview,
      },
      consentReceipt: {
        findFirst: jest.fn().mockResolvedValue(adultConsentFixture()),
      },
      applicationArtifactVersion: {
        findMany: jest
          .fn()
          .mockResolvedValue([{ id: 'version-1' }, { id: 'version-2' }]),
      },
      $queryRaw: jest.fn(),
    };
    execute.mockImplementation(async (operation: (db: unknown) => unknown) =>
      operation({
        $transaction: async (callback: (value: unknown) => unknown) => callback(tx),
      }),
    );

    const result = await service.create(
      'student-1',
      'workspace-1',
      {
        artifactVersionIds: ['version-1', 'version-2'],
        consentReceiptId: 'consent-1',
        studentMessage: 'Merci de relire mon dossier.',
        preferredContact: 'in_app',
        timezone: 'Africa/Niamey',
        availability: { weekdays: ['monday'] },
      },
      'review-create-1',
    );

    expect(result.statusCode).toBe(201);
    expect(result.reviewRequest.sharedVersions).toHaveLength(2);
    expect(tx.scholarshipWorkspace.findFirst).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({ userId: 'student-1' }),
      }),
    );
    expect(tx.applicationArtifactVersion.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          id: { in: ['version-1', 'version-2'] },
          processingStatus: 'clean',
          artifact: { workspaceId: 'workspace-1' },
        }),
      }),
    );
    expect(createReview).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          workspaceId: 'workspace-1',
          status: 'submitted',
          artifactShares: {
            create: expect.arrayContaining([
              expect.objectContaining({
                artifactVersionId: 'version-1',
                consentReceiptId: 'consent-1',
                grantedByUserId: 'student-1',
              }),
            ]),
          },
        }),
      }),
    );
    expect(complete).toHaveBeenCalledWith(
      expect.objectContaining({ resourceType: 'StudyReviewRequest' }),
      tx,
    );
  });

  it('rejects a foreign or non-clean artifact version before creating a request', async () => {
    const createReview = jest.fn();
    const tx = {
      scholarshipWorkspace: {
        findFirst: jest.fn().mockResolvedValue({
          id: 'workspace-1',
          status: 'preparing',
        }),
      },
      studyReviewRequest: { findFirst: jest.fn().mockResolvedValue(null) },
      consentReceipt: {
        findFirst: jest.fn().mockResolvedValue(adultConsentFixture()),
      },
      applicationArtifactVersion: { findMany: jest.fn().mockResolvedValue([]) },
      $queryRaw: jest.fn(),
      create: createReview,
    };
    execute.mockImplementation(async (operation: (db: unknown) => unknown) =>
      operation({
        $transaction: async (callback: (value: unknown) => unknown) => callback(tx),
      }),
    );

    await expect(
      service.create(
        'student-1',
        'workspace-1',
        {
          artifactVersionIds: ['foreign-version'],
          consentReceiptId: 'consent-1',
        },
        'review-create-1',
      ),
    ).rejects.toMatchObject({ status: 422 });
    expect(createReview).not.toHaveBeenCalled();
  });

  it('requires verified guardian authorization before a minor shares artifacts', async () => {
    const createReview = jest.fn();
    const tx = {
      scholarshipWorkspace: {
        findFirst: jest.fn().mockResolvedValue({
          id: 'workspace-1',
          status: 'preparing',
        }),
      },
      studyReviewRequest: { findFirst: jest.fn().mockResolvedValue(null) },
      consentReceipt: {
        findFirst: jest.fn().mockResolvedValue({
          id: 'consent-1',
          user: { birthDate: new Date('2012-01-01T00:00:00.000Z') },
          guardianAuthorization: null,
        }),
      },
      applicationArtifactVersion: { findMany: jest.fn() },
      $queryRaw: jest.fn(),
      create: createReview,
    };
    execute.mockImplementation(async (operation: (db: unknown) => unknown) =>
      operation({
        $transaction: async (callback: (value: unknown) => unknown) => callback(tx),
      }),
    );

    await expect(
      service.create(
        'student-1',
        'workspace-1',
        {
          artifactVersionIds: ['version-1'],
          consentReceiptId: 'consent-1',
        },
        'review-create-minor',
      ),
    ).rejects.toMatchObject({
      status: 403,
      response: expect.objectContaining({ code: 'GUARDIAN_CONSENT_REQUIRED' }),
    });
    expect(tx.applicationArtifactVersion.findMany).not.toHaveBeenCalled();
    expect(createReview).not.toHaveBeenCalled();
  });

  it('rejects a second open request even when a new idempotency key is used', async () => {
    const tx = {
      scholarshipWorkspace: {
        findFirst: jest.fn().mockResolvedValue({
          id: 'workspace-1',
          status: 'review_requested',
        }),
      },
      studyReviewRequest: {
        findFirst: jest.fn().mockResolvedValue({ id: 'review-existing' }),
      },
      $queryRaw: jest.fn(),
    };
    execute.mockImplementation(async (operation: (db: unknown) => unknown) =>
      operation({
        $transaction: async (callback: (value: unknown) => unknown) => callback(tx),
      }),
    );

    await expect(
      service.create(
        'student-1',
        'workspace-1',
        {
          artifactVersionIds: ['version-1'],
          consentReceiptId: 'consent-1',
        },
        'different-key',
      ),
    ).rejects.toMatchObject({
      status: 409,
      response: expect.objectContaining({ code: 'REVIEW_REQUEST_ALREADY_OPEN' }),
    });
  });

  it('replays the original request without creating new shares', async () => {
    const snapshot = serializedReviewFixture();
    reserve.mockResolvedValueOnce({
      state: 'replay',
      recordId: 'idem-existing',
      payloadHash: 'hash',
      responseCode: 201,
      responseSnapshot: snapshot,
      resourceType: 'StudyReviewRequest',
      resourceId: 'review-1',
      resultingVersion: 1,
      expiresAt: new Date('2026-07-18T00:00:00.000Z'),
    });
    const tx = { scholarshipWorkspace: { findFirst: jest.fn() } };
    execute.mockImplementation(async (operation: (db: unknown) => unknown) =>
      operation({
        $transaction: async (callback: (value: unknown) => unknown) => callback(tx),
      }),
    );

    await expect(
      service.create(
        'student-1',
        'workspace-1',
        {
          artifactVersionIds: ['version-1'],
          consentReceiptId: 'consent-1',
        },
        'review-create-1',
      ),
    ).resolves.toEqual({ statusCode: 201, reviewRequest: snapshot });
    expect(tx.scholarshipWorkspace.findFirst).not.toHaveBeenCalled();
    expect(complete).not.toHaveBeenCalled();
  });

  it('reads a request only through its workspace owner relation', async () => {
    const findFirst = jest.fn().mockResolvedValue(reviewFixture());
    execute.mockImplementation(async (operation: (db: unknown) => unknown) =>
      operation({ studyReviewRequest: { findFirst } }),
    );

    await expect(service.getOne('student-1', 'review-1')).resolves.toMatchObject({
      id: 'review-1',
      sharedVersions: expect.any(Array),
    });
    expect(findFirst).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { id: 'review-1', workspace: { userId: 'student-1' } },
      }),
    );
  });

  it('returns the active request for an owned workspace with a stable next action', async () => {
    const workspaceFindFirst = jest.fn().mockResolvedValue({ id: 'workspace-1' });
    const reviewFindFirst = jest.fn().mockResolvedValue(
      reviewFixture({
        status: 'more_information_needed',
        missingItems: ['cv', 'motivation_letter'],
      }),
    );
    execute.mockImplementation(async (operation: (db: unknown) => unknown) =>
      operation({
        scholarshipWorkspace: { findFirst: workspaceFindFirst },
        studyReviewRequest: { findFirst: reviewFindFirst },
      }),
    );

    await expect(
      service.getActive('student-1', 'workspace-1'),
    ).resolves.toMatchObject({
      schemaVersion: 1,
      reviewRequest: {
        id: 'review-1',
        status: 'more_information_needed',
        missingItems: ['cv', 'motivation_letter'],
        nextAction: 'provide_more_information',
      },
    });
  });

  it('resubmits more information with CAS, exact clean shares and no PII in audit/outbox', async () => {
    const current = {
      id: 'review-1',
      workspaceId: 'workspace-1',
      version: 4,
      status: 'more_information_needed',
      workspace: { userId: 'student-1' },
    };
    const updatedReview = reviewFixture({ version: 5, status: 'submitted' });
    const tx = {
      $queryRaw: jest.fn(),
      studyReviewRequest: {
        findUnique: jest
          .fn()
          .mockResolvedValueOnce(current)
          .mockResolvedValueOnce(updatedReview),
        updateMany: jest.fn().mockResolvedValue({ count: 1 }),
      },
      consentReceipt: {
        findFirst: jest.fn().mockResolvedValue(adultConsentFixture()),
      },
      applicationArtifactVersion: {
        findMany: jest.fn().mockResolvedValue([{ id: 'version-2' }]),
      },
      studyReviewArtifactShare: {
        updateMany: jest.fn(),
        upsert: jest.fn(),
      },
      scholarshipWorkspace: { update: jest.fn() },
      adminAuditEvent: { create: jest.fn() },
    };
    execute.mockImplementation(async (operation: (db: unknown) => unknown) =>
      operation({
        $transaction: async (callback: (value: unknown) => unknown) =>
          callback(tx),
      }),
    );

    const result = await service.update(
      'student-1',
      'review-1',
      {
        expectedVersion: 4,
        studentMessage: 'private replacement message',
        artifactVersionIds: ['version-2'],
        consentReceiptId: 'consent-1',
      },
      'request-1',
    );

    expect(result).toMatchObject({
      id: 'review-1',
      version: 5,
      status: 'submitted',
      nextAction: 'wait_for_triage',
    });
    expect(tx.studyReviewRequest.updateMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { id: 'review-1', version: 4, status: 'more_information_needed' },
        data: expect.objectContaining({ status: 'submitted' }),
      }),
    );
    expect(tx.studyReviewArtifactShare.upsert).toHaveBeenCalledTimes(1);
    const audit = tx.adminAuditEvent.create.mock.calls[0][0].data;
    expect(JSON.stringify(audit)).not.toContain('private replacement message');
    expect(enqueue).toHaveBeenCalledWith(
      expect.objectContaining({ eventName: 'study_review.resubmitted' }),
      tx,
    );
  });

  it('rejects a stale completion before replacing shares', async () => {
    const tx = {
      $queryRaw: jest.fn(),
      studyReviewRequest: {
        findUnique: jest.fn().mockResolvedValue({
          id: 'review-1',
          workspaceId: 'workspace-1',
          version: 5,
          status: 'more_information_needed',
          workspace: { userId: 'student-1' },
        }),
      },
      studyReviewArtifactShare: { updateMany: jest.fn(), upsert: jest.fn() },
    };
    execute.mockImplementation(async (operation: (db: unknown) => unknown) =>
      operation({
        $transaction: async (callback: (value: unknown) => unknown) =>
          callback(tx),
      }),
    );

    await expect(
      service.update(
        'student-1',
        'review-1',
        { expectedVersion: 4 },
        'request-1',
      ),
    ).rejects.toMatchObject({
      status: 409,
      response: expect.objectContaining({ code: 'VERSION_CONFLICT' }),
    });
    expect(tx.studyReviewArtifactShare.updateMany).not.toHaveBeenCalled();
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
    assignedCounsellorId: null,
    studentMessage: 'Merci de relire mon dossier.',
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
    artifactShares: ['version-1', 'version-2'].map((id, index) => ({
      id: `share-${index + 1}`,
      artifactVersionId: id,
      consentReceiptId: 'consent-1',
      grantedAt: now,
      revokedAt: null,
      artifactVersion: {
        id,
        versionNumber: 1,
        originalFileName: `${id}.pdf`,
        mimeType: 'application/pdf',
        sizeBytes: 120,
        sha256: 'a'.repeat(64),
        processingStatus: 'clean',
        uploadedAt: now,
        artifact: {
          id: `artifact-${index + 1}`,
          kind: index === 0 ? 'cv' : 'motivation_letter',
          title: `Document ${index + 1}`,
          workspaceId: 'workspace-1',
        },
      },
    })),
    ...overrides,
  };
}

function serializedReviewFixture() {
  const review = reviewFixture();
  return {
    id: review.id,
    workspaceId: review.workspaceId,
    requestNumber: review.requestNumber,
    version: review.version,
    status: review.status,
    studentMessage: review.studentMessage,
    preferredContact: review.preferredContact,
    timezone: review.timezone,
    availability: review.availability,
    missingItems: review.missingItems,
    nextAction: 'wait_for_triage',
    submittedAt: review.submittedAt.toISOString(),
    triagedAt: null,
    closedAt: null,
    createdAt: review.createdAt.toISOString(),
    updatedAt: review.updatedAt.toISOString(),
    sharedVersions: review.artifactShares.map((share) => ({
      shareId: share.id,
      artifactVersionId: share.artifactVersionId,
      consentReceiptId: share.consentReceiptId,
      grantedAt: share.grantedAt.toISOString(),
      revokedAt: null,
      artifact: {
        id: share.artifactVersion.artifact.id,
        kind: share.artifactVersion.artifact.kind,
        title: share.artifactVersion.artifact.title,
      },
      version: {
        id: share.artifactVersion.id,
        versionNumber: share.artifactVersion.versionNumber,
        originalFileName: share.artifactVersion.originalFileName,
        mimeType: share.artifactVersion.mimeType,
        sizeBytes: share.artifactVersion.sizeBytes,
        sha256: share.artifactVersion.sha256,
        processingStatus: share.artifactVersion.processingStatus,
        uploadedAt: share.artifactVersion.uploadedAt.toISOString(),
      },
    })),
  };
}

function adultConsentFixture() {
  return {
    id: 'consent-1',
    user: { birthDate: new Date('1990-01-01T00:00:00.000Z') },
    guardianAuthorization: null,
  };
}
