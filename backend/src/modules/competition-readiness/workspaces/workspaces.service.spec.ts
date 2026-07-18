import type { PrismaService } from '../../prisma/prisma.service';
import type { DomainEventOutboxService } from '../common/domain-event-outbox.service';
import type { FeatureAccessService } from '../common/feature-access.service';
import type { IdempotencyService } from '../common/idempotency.service';
import { WorkspaceProgressService } from './workspace-progress.service';
import {
  buildWorkspaceStepSnapshots,
  WorkspacesService,
} from './workspaces.service';

describe('WorkspacesService', () => {
  const previousFlags = {
    parent: process.env.KPB_COMPETITION_READINESS_ENABLED,
    lab: process.env.KPB_SUCCESS_LAB_ENABLED,
    artifacts: process.env.KPB_APPLICATION_ARTIFACTS_ENABLED,
    studyReview: process.env.KPB_STUDY_REVIEW_ENABLED,
  };
  const execute = jest.fn();
  const prismaService = {
    isEnabled: true,
    execute,
  } as unknown as PrismaService;
  const evaluateAccess = jest
    .fn()
    .mockResolvedValue({ allowed: true, feature: 'success_lab' });
  const featureAccess = {
    evaluate: evaluateAccess,
  } as unknown as FeatureAccessService;
  const reserveIdempotency = jest.fn().mockResolvedValue({
    state: 'acquired',
    recordId: 'idempotency-1',
    payloadHash: 'hash',
    expiresAt: new Date('2026-07-17T12:00:00.000Z'),
  });
  const completeIdempotency = jest.fn();
  const idempotency = {
    reserve: reserveIdempotency,
    complete: completeIdempotency,
  } as unknown as IdempotencyService;
  const outbox = {
    enqueue: jest.fn(),
  } as unknown as DomainEventOutboxService;
  const service = new WorkspacesService(
    prismaService,
    new WorkspaceProgressService(),
    featureAccess,
    idempotency,
    outbox,
  );
  const now = new Date('2026-07-16T12:00:00.000Z');
  const workspace = {
    id: 'workspace-1',
    userId: 'student-1',
    scholarshipId: 'scholarship-1',
    scholarshipCycleId: 'cycle-1',
    status: 'started',
    version: 1,
    readinessPercent: 0,
    startedAt: now,
    lastActivityAt: now,
    submittedAt: null,
    decisionReceivedAt: null,
    archivedAt: null,
    createdAt: now,
    updatedAt: now,
    scholarship: {
      id: 'scholarship-1',
      nameFr: 'Bourse test',
      nameEn: 'Test scholarship',
      countryNameFr: 'Niger',
      countryNameEn: 'Niger',
    },
    scholarshipCycle: {
      id: 'cycle-1',
      academicYear: '2026-2027',
      status: 'forecast',
      dateConfidence: 'estimated',
      opensAt: null,
      closesAt: null,
      estimatedOpenAt: now,
      estimatedCloseAt: now,
    },
    steps: [
      {
        id: 'step-1',
        workspaceId: 'workspace-1',
        sourceStepId: null,
        code: 'profile-eligibility',
        titleFr: 'Profil',
        titleEn: 'Profile',
        category: 'profile_eligibility',
        weight: 20,
        isRequired: true,
        templateVersion: 'success-lab-v1',
        status: 'not_started',
        notApplicableReason: null,
        completedAt: null,
        createdAt: now,
        updatedAt: now,
      },
    ],
  };

  beforeEach(() => {
    jest.clearAllMocks();
    evaluateAccess.mockResolvedValue({
      allowed: true,
      feature: 'success_lab',
    });
    reserveIdempotency.mockResolvedValue({
      state: 'acquired',
      recordId: 'idempotency-1',
      payloadHash: 'hash',
      expiresAt: new Date('2026-07-17T12:00:00.000Z'),
    });
    process.env.KPB_COMPETITION_READINESS_ENABLED = 'true';
    process.env.KPB_SUCCESS_LAB_ENABLED = 'true';
    process.env.KPB_APPLICATION_ARTIFACTS_ENABLED = 'false';
    process.env.KPB_STUDY_REVIEW_ENABLED = 'false';
  });

  afterAll(() => {
    if (previousFlags.parent === undefined) {
      delete process.env.KPB_COMPETITION_READINESS_ENABLED;
    } else {
      process.env.KPB_COMPETITION_READINESS_ENABLED = previousFlags.parent;
    }
    if (previousFlags.lab === undefined) {
      delete process.env.KPB_SUCCESS_LAB_ENABLED;
    } else {
      process.env.KPB_SUCCESS_LAB_ENABLED = previousFlags.lab;
    }
    if (previousFlags.artifacts === undefined) {
      delete process.env.KPB_APPLICATION_ARTIFACTS_ENABLED;
    } else {
      process.env.KPB_APPLICATION_ARTIFACTS_ENABLED = previousFlags.artifacts;
    }
    if (previousFlags.studyReview === undefined) {
      delete process.env.KPB_STUDY_REVIEW_ENABLED;
    } else {
      process.env.KPB_STUDY_REVIEW_ENABLED = previousFlags.studyReview;
    }
  });

  it('builds immutable step snapshots whose weights total 100', () => {
    const snapshots = buildWorkspaceStepSnapshots([
      { id: 'source-2', stepNumber: 2, titleFr: 'Deux', titleEn: 'Two' },
      { id: 'source-1', stepNumber: 1, titleFr: 'Un', titleEn: 'One' },
    ]);

    expect(snapshots.reduce((sum, step) => sum + step.weight, 0)).toBe(100);
    expect(snapshots.map((step) => step.code)).toEqual([
      'profile-eligibility',
      'prepare-documents',
      'application-step-001',
      'application-step-002',
      'review-and-submit',
    ]);
    expect(snapshots[2]).toMatchObject({
      sourceStepId: 'source-1',
      titleFr: 'Un',
      templateVersion: 'success-lab-v1',
    });
  });

  it('filters workspace detail lookup by both id and authenticated owner', async () => {
    const findFirst = jest.fn().mockResolvedValue(workspace);
    const client = { scholarshipWorkspace: { findFirst } };
    execute.mockImplementation(
      async (operation: (value: unknown) => Promise<unknown>) =>
        operation(client),
    );

    await expect(
      service.getOne('student-1', 'workspace-1'),
    ).resolves.toMatchObject({
      id: 'workspace-1',
      schemaVersion: 1,
    });
    expect(findFirst).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { id: 'workspace-1', userId: 'student-1' },
      }),
    );
  });

  it('returns the fail-closed access reason without querying workspaces', async () => {
    evaluateAccess.mockResolvedValueOnce({
      allowed: false,
      feature: 'success_lab',
      reason: 'country_not_eligible',
    });

    await expect(service.getAccess('student-1')).resolves.toEqual({
      enabled: false,
      reasons: ['country_not_eligible'],
      limits: { maxActiveWorkspaces: 20, maxPageSize: 50 },
      features: {
        applicationArtifacts: {
          enabled: false,
          reasons: ['country_not_eligible'],
        },
        aiDiagnostic: {
          enabled: false,
          reasons: ['country_not_eligible'],
        },
        counsellorStudy: {
          enabled: false,
          reasons: ['country_not_eligible'],
        },
        outcomeEvidence: {
          enabled: false,
          reasons: ['country_not_eligible'],
        },
      },
    });
    expect(execute).not.toHaveBeenCalled();
  });

  it('exposes each sensitive capability fail-closed in the access contract', async () => {
    evaluateAccess
      .mockResolvedValueOnce({ allowed: true, feature: 'success_lab' })
      .mockResolvedValueOnce({
        allowed: false,
        feature: 'ai_diagnostic',
        reason: 'consent_required',
      })
      .mockResolvedValueOnce({
        allowed: false,
        feature: 'outcome_evidence',
        reason: 'consent_required',
      });
    process.env.KPB_APPLICATION_ARTIFACTS_ENABLED = 'true';
    process.env.KPB_STUDY_REVIEW_ENABLED = 'false';

    await expect(service.getAccess('student-1')).resolves.toMatchObject({
      enabled: true,
      features: {
        applicationArtifacts: { enabled: true, reasons: [] },
        aiDiagnostic: {
          enabled: false,
          available: true,
          requiresConsent: true,
          reasons: ['consent_required'],
        },
        counsellorStudy: {
          enabled: false,
          reasons: ['feature_disabled'],
        },
        outcomeEvidence: {
          enabled: false,
          available: true,
          requiresConsent: true,
          reasons: ['consent_required'],
        },
      },
    });
  });

  it('replays a completed workspace creation without executing it twice', async () => {
    const snapshot = {
      schemaVersion: 1,
      id: 'workspace-replayed',
      version: 3,
    };
    reserveIdempotency.mockResolvedValueOnce({
      state: 'replay',
      recordId: 'idempotency-existing',
      payloadHash: 'hash',
      responseCode: 201,
      responseSnapshot: snapshot,
      resourceType: 'ScholarshipWorkspace',
      resourceId: 'workspace-replayed',
      resultingVersion: 3,
      expiresAt: new Date('2026-07-17T12:00:00.000Z'),
    });
    const tx = { scholarshipWorkspace: { findUnique: jest.fn() } };
    const client = {
      $transaction: jest.fn(
        async (operation: (value: unknown) => Promise<unknown>) =>
          operation(tx),
      ),
    };
    execute.mockImplementation(
      async (operation: (value: unknown) => Promise<unknown>) =>
        operation(client),
    );

    await expect(
      service.create(
        'student-1',
        { scholarshipId: 'scholarship-1', cycleId: 'cycle-1' },
        'create-1',
      ),
    ).resolves.toEqual({
      created: true,
      statusCode: 201,
      workspace: snapshot,
    });
    expect(tx.scholarshipWorkspace.findUnique).not.toHaveBeenCalled();
    expect(completeIdempotency).not.toHaveBeenCalled();
  });

  it('rejects a cycle that does not belong to an available scholarship', async () => {
    const tx = {
      scholarshipWorkspace: { findUnique: jest.fn().mockResolvedValue(null) },
      scholarshipCycle: { findFirst: jest.fn().mockResolvedValue(null) },
    };
    const client = {
      $transaction: jest.fn(
        async (operation: (value: unknown) => Promise<unknown>) =>
          operation(tx),
      ),
    };
    execute.mockImplementation(
      async (operation: (value: unknown) => Promise<unknown>) =>
        operation(client),
    );

    await expect(
      service.create(
        'student-1',
        {
          scholarshipId: 'scholarship-1',
          cycleId: 'foreign-cycle',
        },
        'create-1',
      ),
    ).rejects.toMatchObject({ status: 422 });
  });

  it('requires a reason before excluding a step from readiness', async () => {
    await expect(
      service.updateStep('student-1', 'workspace-1', 'step-1', {
        status: 'not_applicable',
        clientMutationId: 'mutation-1',
        expectedVersion: 1,
      }),
    ).rejects.toMatchObject({ status: 422 });
    expect(execute).not.toHaveBeenCalled();
  });
});
