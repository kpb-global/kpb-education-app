import { Injectable } from '@nestjs/common';
import {
  Prisma,
  type ScholarshipWorkspaceStatus,
  type WorkspaceStepCategory,
} from '@prisma/client';

import { PrismaService } from '../../prisma/prisma.service';
import {
  CompetitionReadinessHttpException,
  databaseUnavailable,
  featureDisabled,
  idempotencyInProgress,
  idempotencyPayloadMismatch,
  outboxEventConflict,
  versionConflict,
  workspaceCycleMismatch,
  workspaceNotFound,
} from '../common/competition-readiness.errors';
import {
  DomainEventConflictError,
  DomainEventOutboxService,
  DomainEventOutboxUnavailableError,
} from '../common/domain-event-outbox.service';
import { FeatureAccessService } from '../common/feature-access.service';
import {
  IdempotencyPayloadMismatchError,
  type IdempotencyReservation,
  IdempotencyService,
  IdempotencyStorageUnavailableError,
} from '../common/idempotency.service';
import { CreateWorkspaceDto } from './dto/create-workspace.dto';
import { ListWorkspacesQueryDto } from './dto/list-workspaces-query.dto';
import { UpdateWorkspaceDto } from './dto/update-workspace.dto';
import { UpdateWorkspaceStepDto } from './dto/update-workspace-step.dto';
import { WorkspaceProgressService } from './workspace-progress.service';

const TEMPLATE_VERSION = 'success-lab-v1';

const workspaceInclude = {
  scholarship: {
    select: {
      id: true,
      nameFr: true,
      nameEn: true,
      countryNameFr: true,
      countryNameEn: true,
    },
  },
  scholarshipCycle: {
    select: {
      id: true,
      academicYear: true,
      status: true,
      dateConfidence: true,
      opensAt: true,
      closesAt: true,
      estimatedOpenAt: true,
      estimatedCloseAt: true,
    },
  },
  steps: {
    orderBy: [{ category: 'asc' as const }, { code: 'asc' as const }],
  },
} satisfies Prisma.ScholarshipWorkspaceInclude;

type WorkspaceWithDetails = Prisma.ScholarshipWorkspaceGetPayload<{
  include: typeof workspaceInclude;
}>;

type SourceApplicationStep = {
  id: string;
  stepNumber: number;
  titleFr: string;
  titleEn: string;
};

type StepSnapshotInput = {
  sourceStepId?: string;
  code: string;
  titleFr: string;
  titleEn: string;
  category: WorkspaceStepCategory;
  weight: number;
  isRequired: boolean;
  templateVersion: string;
};

export function buildWorkspaceStepSnapshots(
  applicationSteps: SourceApplicationStep[],
): StepSnapshotInput[] {
  const ordered = [...applicationSteps].sort(
    (left, right) => left.stepNumber - right.stepNumber,
  );
  const formSteps: StepSnapshotInput[] = [];

  if (ordered.length === 0) {
    formSteps.push({
      code: 'complete-application',
      titleFr: 'Compléter le formulaire et les essais',
      titleEn: 'Complete the form and essays',
      category: 'form_and_essays',
      weight: 25,
      isRequired: true,
      templateVersion: TEMPLATE_VERSION,
    });
  } else {
    const baseWeight = Math.floor(25 / ordered.length);
    const remainder = 25 % ordered.length;
    ordered.forEach((step, index) => {
      formSteps.push({
        sourceStepId: step.id,
        code: `application-step-${String(step.stepNumber).padStart(3, '0')}`,
        titleFr: step.titleFr,
        titleEn: step.titleEn,
        category: 'form_and_essays',
        weight: baseWeight + (index < remainder ? 1 : 0),
        isRequired: true,
        templateVersion: TEMPLATE_VERSION,
      });
    });
  }

  return [
    {
      code: 'profile-eligibility',
      titleFr: 'Vérifier mon profil et mon éligibilité',
      titleEn: 'Check my profile and eligibility',
      category: 'profile_eligibility',
      weight: 20,
      isRequired: true,
      templateVersion: TEMPLATE_VERSION,
    },
    {
      code: 'prepare-documents',
      titleFr: 'Préparer mes documents',
      titleEn: 'Prepare my documents',
      category: 'documents',
      weight: 40,
      isRequired: true,
      templateVersion: TEMPLATE_VERSION,
    },
    ...formSteps,
    {
      code: 'review-and-submit',
      titleFr: 'Relire et soumettre ma candidature',
      titleEn: 'Review and submit my application',
      category: 'review_and_submission',
      weight: 15,
      isRequired: true,
      templateVersion: TEMPLATE_VERSION,
    },
  ];
}

@Injectable()
export class WorkspacesService {
  constructor(
    private readonly prismaService: PrismaService,
    private readonly progressService: WorkspaceProgressService,
    private readonly featureAccess: FeatureAccessService,
    private readonly idempotency: IdempotencyService,
    private readonly outbox: DomainEventOutboxService,
  ) {}

  private assertDb() {
    if (!this.prismaService.isEnabled) {
      throw databaseUnavailable();
    }
  }

  private async assertFeatureAccess(userId: string) {
    const decision = await this.featureAccess.evaluate({
      feature: 'success_lab',
      userId,
    });
    if (!decision.allowed) throw featureDisabled('success_lab');
  }

  async getAccess(userId: string) {
    const decision = await this.featureAccess.evaluate({
      feature: 'success_lab',
      userId,
    });

    if (!decision.allowed) {
      return {
        enabled: false,
        reasons: [decision.reason],
        limits: {
          maxActiveWorkspaces: 20,
          maxPageSize: 50,
        },
        features: {
          applicationArtifacts: {
            enabled: false,
            reasons: [decision.reason],
          },
          aiDiagnostic: { enabled: false, reasons: [decision.reason] },
          counsellorStudy: { enabled: false, reasons: [decision.reason] },
          outcomeEvidence: { enabled: false, reasons: [decision.reason] },
        },
      };
    }

    const aiDecision = await this.featureAccess.evaluate({
      feature: 'ai_diagnostic',
      userId,
    });
    const applicationArtifactsEnabled = this.envFeatureEnabled(
      'KPB_APPLICATION_ARTIFACTS_ENABLED',
    );
    const outcomeEvidenceDecision = await this.featureAccess.evaluate({
      feature: 'outcome_evidence',
      userId,
    });
    const counsellorStudyEnabled = this.envFeatureEnabled(
      'KPB_STUDY_REVIEW_ENABLED',
    ) && applicationArtifactsEnabled;

    return {
      enabled: true,
      reasons: [],
      limits: {
        maxActiveWorkspaces: 20,
        maxPageSize: 50,
      },
      features: {
        applicationArtifacts: {
          enabled: applicationArtifactsEnabled,
          reasons: applicationArtifactsEnabled ? [] : ['feature_disabled'],
        },
        aiDiagnostic: {
          enabled: aiDecision.allowed,
          available:
            aiDecision.allowed || aiDecision.reason === 'consent_required',
          requiresConsent:
            !aiDecision.allowed && aiDecision.reason === 'consent_required',
          reasons: aiDecision.allowed ? [] : [aiDecision.reason],
        },
        counsellorStudy: {
          enabled: counsellorStudyEnabled,
          reasons: counsellorStudyEnabled ? [] : ['feature_disabled'],
        },
        outcomeEvidence: {
          enabled: outcomeEvidenceDecision.allowed,
          available:
            outcomeEvidenceDecision.allowed ||
            outcomeEvidenceDecision.reason === 'consent_required',
          requiresConsent:
            !outcomeEvidenceDecision.allowed &&
            outcomeEvidenceDecision.reason === 'consent_required',
          reasons: outcomeEvidenceDecision.allowed
            ? []
            : [outcomeEvidenceDecision.reason],
        },
      },
    };
  }

  private envFeatureEnabled(key: string): boolean {
    return process.env[key]?.trim().toLowerCase() === 'true';
  }

  async list(userId: string, query: ListWorkspacesQueryDto) {
    this.assertDb();
    await this.assertFeatureAccess(userId);
    const limit = query.limit ?? 20;
    const rows = await this.prismaService.execute((prisma) =>
      prisma.scholarshipWorkspace.findMany({
        where: {
          userId,
          ...(query.status ? { status: query.status } : {}),
        },
        ...(query.cursor ? { cursor: { id: query.cursor }, skip: 1 } : {}),
        take: limit + 1,
        orderBy: [{ lastActivityAt: 'desc' }, { id: 'desc' }],
        include: workspaceInclude,
      }),
    );
    const found = rows ?? [];
    const hasMore = found.length > limit;
    const page = hasMore ? found.slice(0, limit) : found;

    return {
      items: page.map((workspace) => this.serialize(workspace, false)),
      nextCursor: hasMore ? (page.at(-1)?.id ?? null) : null,
    };
  }

  async create(
    userId: string,
    input: CreateWorkspaceDto,
    idempotencyKey: string,
  ) {
    this.assertDb();
    await this.assertFeatureAccess(userId);

    try {
      const result = await this.prismaService.execute((prisma) =>
        prisma.$transaction(async (tx) => {
          const reservation = await this.idempotency.reserve(
            {
              actorType: 'student',
              actorId: userId,
              operation: 'workspace.create',
              idempotencyKey,
              payload: input,
            },
            tx,
          );
          if (reservation.state === 'replay') {
            return {
              created: reservation.responseCode === 201,
              statusCode: reservation.responseCode === 201 ? 201 : 200,
              workspace: this.replayWorkspace(reservation),
            };
          }
          if (reservation.state !== 'acquired') throw idempotencyInProgress();

          const existing = await tx.scholarshipWorkspace.findUnique({
            where: {
              userId_scholarshipId_scholarshipCycleId: {
                userId,
                scholarshipId: input.scholarshipId,
                scholarshipCycleId: input.cycleId,
              },
            },
            include: workspaceInclude,
          });
          if (existing) {
            const workspace = this.serialize(existing, true);
            await this.idempotency.complete(
              {
                recordId: reservation.recordId,
                responseCode: 200,
                responseSnapshot: workspace as unknown as Prisma.InputJsonValue,
                resourceType: 'ScholarshipWorkspace',
                resourceId: workspace.id,
                resultingVersion: workspace.version,
              },
              tx,
            );
            return { created: false, statusCode: 200, workspace };
          }

          const cycle = await tx.scholarshipCycle.findFirst({
            where: {
              id: input.cycleId,
              scholarshipId: input.scholarshipId,
              status: { in: ['forecast', 'open'] },
              scholarship: {
                isActive: true,
                moderationStatus: 'approved',
              },
            },
            include: {
              scholarship: {
                include: {
                  applicationSteps: { orderBy: { stepNumber: 'asc' } },
                },
              },
            },
          });
          if (!cycle) throw workspaceCycleMismatch();

          const workspace = await tx.scholarshipWorkspace.create({
            data: {
              userId,
              scholarshipId: input.scholarshipId,
              scholarshipCycleId: input.cycleId,
              steps: {
                create: buildWorkspaceStepSnapshots(
                  cycle.scholarship.applicationSteps,
                ),
              },
            },
            include: workspaceInclude,
          });
          await this.outbox.enqueue(
            {
              eventId: `workspace.created:${workspace.id}`,
              eventName: 'workspace.created',
              aggregateType: 'ScholarshipWorkspace',
              aggregateId: workspace.id,
              occurredAt: workspace.createdAt,
              payload: {
                workspaceId: workspace.id,
                scholarshipId: workspace.scholarshipId,
                cycleId: workspace.scholarshipCycleId,
              },
            },
            tx,
          );
          const serialized = this.serialize(workspace, true);
          await this.idempotency.complete(
            {
              recordId: reservation.recordId,
              responseCode: 201,
              responseSnapshot: serialized as unknown as Prisma.InputJsonValue,
              resourceType: 'ScholarshipWorkspace',
              resourceId: workspace.id,
              resultingVersion: workspace.version,
            },
            tx,
          );
          return {
            created: true,
            statusCode: 201,
            workspace: serialized,
          };
        }),
      );
      if (!result) throw databaseUnavailable();
      return result;
    } catch (error) {
      if (
        error instanceof Prisma.PrismaClientKnownRequestError &&
        error.code === 'P2002'
      ) {
        const existing = await this.findOwnedByCycle(userId, input);
        if (existing) {
          return {
            created: false,
            statusCode: 200,
            workspace: this.serialize(existing, true),
          };
        }
      }
      this.translateInfrastructureError(error);
    }
  }

  async getOne(userId: string, workspaceId: string) {
    this.assertDb();
    await this.assertFeatureAccess(userId);
    const workspace = await this.findOwned(userId, workspaceId);
    if (!workspace) throw workspaceNotFound();
    return this.serialize(workspace, true);
  }

  async updateLifecycle(
    userId: string,
    workspaceId: string,
    input: UpdateWorkspaceDto,
  ) {
    this.assertDb();
    await this.assertFeatureAccess(userId);
    try {
      const updated = await this.prismaService.execute((prisma) =>
        prisma.$transaction(async (tx) => {
          const current = await tx.scholarshipWorkspace.findFirst({
            where: { id: workspaceId, userId },
            include: workspaceInclude,
          });
          if (!current) throw workspaceNotFound();
          if (current.version !== input.expectedVersion) {
            throw versionConflict(current.version);
          }

          let nextStatus: ScholarshipWorkspaceStatus;
          let archivedAt: Date | null;
          if (input.action === 'archive') {
            if (current.status === 'archived') return current;
            nextStatus = 'archived';
            archivedAt = new Date();
          } else {
            if (
              current.status !== 'archived' ||
              !['forecast', 'open'].includes(current.scholarshipCycle.status)
            ) {
              throw workspaceCycleMismatch();
            }
            nextStatus = this.progressService.deriveStatus(
              'started',
              current.readinessPercent,
              current.steps.some((step) => step.status !== 'not_started'),
            );
            archivedAt = null;
          }

          const mutation = await tx.scholarshipWorkspace.updateMany({
            where: { id: workspaceId, userId, version: input.expectedVersion },
            data: {
              status: nextStatus,
              archivedAt,
              lastActivityAt: new Date(),
              version: { increment: 1 },
            },
          });
          if (mutation.count !== 1) {
            const latest = await tx.scholarshipWorkspace.findUnique({
              where: { id: workspaceId },
              select: { version: true },
            });
            throw versionConflict(latest?.version ?? input.expectedVersion);
          }
          await this.outbox.enqueue(
            {
              eventId: `workspace.lifecycle:${workspaceId}:${input.expectedVersion + 1}`,
              eventName:
                input.action === 'archive'
                  ? 'workspace.archived'
                  : 'workspace.reopened',
              aggregateType: 'ScholarshipWorkspace',
              aggregateId: workspaceId,
              occurredAt: new Date(),
              payload: { workspaceId, version: input.expectedVersion + 1 },
            },
            tx,
          );
          const result = await tx.scholarshipWorkspace.findUnique({
            where: { id: workspaceId },
            include: workspaceInclude,
          });
          if (!result) throw workspaceNotFound();
          return result;
        }),
      );
      if (!updated) throw databaseUnavailable();
      return this.serialize(updated, true);
    } catch (error) {
      this.translateInfrastructureError(error);
    }
  }

  async updateStep(
    userId: string,
    workspaceId: string,
    stepId: string,
    input: UpdateWorkspaceStepDto,
  ) {
    this.assertDb();
    await this.assertFeatureAccess(userId);
    const reason = input.notApplicableReason?.trim() || null;
    if (input.status === 'not_applicable' && !reason) {
      throw new CompetitionReadinessHttpException(
        'PROFILE_INCOMPLETE',
        422,
        'A reason is required for a non-applicable step.',
        { field: 'notApplicableReason' },
      );
    }

    try {
      const updated = await this.prismaService.execute((prisma) =>
        prisma.$transaction(async (tx) => {
          const reservation = await this.idempotency.reserve(
            {
              actorType: 'student',
              actorId: userId,
              operation: 'workspace.step.update',
              idempotencyKey: input.clientMutationId,
              payload: { workspaceId, stepId, ...input },
            },
            tx,
          );
          if (reservation.state === 'replay') {
            return this.replayWorkspace(reservation);
          }
          if (reservation.state !== 'acquired') throw idempotencyInProgress();

          const current = await tx.scholarshipWorkspace.findFirst({
            where: { id: workspaceId, userId },
            include: workspaceInclude,
          });
          if (!current) throw workspaceNotFound();
          if (current.version !== input.expectedVersion) {
            throw versionConflict(current.version);
          }
          const target = current.steps.find((step) => step.id === stepId);
          if (!target) throw workspaceNotFound();

          const completedAt = input.status === 'completed' ? new Date() : null;
          await tx.scholarshipWorkspaceStep.update({
            where: { id: stepId },
            data: {
              status: input.status,
              notApplicableReason:
                input.status === 'not_applicable' ? reason : null,
              completedAt,
            },
          });
          const nextSteps = current.steps.map((step) =>
            step.id === stepId
              ? {
                  ...step,
                  status: input.status,
                  notApplicableReason:
                    input.status === 'not_applicable' ? reason : null,
                  completedAt,
                }
              : step,
          );
          const progress = this.progressService.calculate(nextSteps);
          const nextStatus = this.progressService.deriveStatus(
            current.status,
            progress.readinessPercent,
            nextSteps.some((step) => step.status !== 'not_started'),
          );
          const mutation = await tx.scholarshipWorkspace.updateMany({
            where: { id: workspaceId, userId, version: input.expectedVersion },
            data: {
              readinessPercent: progress.readinessPercent,
              status: nextStatus,
              lastActivityAt: new Date(),
              version: { increment: 1 },
            },
          });
          if (mutation.count !== 1) {
            const latest = await tx.scholarshipWorkspace.findUnique({
              where: { id: workspaceId },
              select: { version: true },
            });
            throw versionConflict(latest?.version ?? input.expectedVersion);
          }
          await this.outbox.enqueue(
            {
              eventId: `workspace.step:${userId}:${input.clientMutationId}`,
              eventName: 'workspace.step.updated',
              aggregateType: 'ScholarshipWorkspace',
              aggregateId: workspaceId,
              occurredAt: new Date(),
              payload: {
                workspaceId,
                stepId,
                status: input.status,
                version: input.expectedVersion + 1,
              },
            },
            tx,
          );
          const result = await tx.scholarshipWorkspace.findUnique({
            where: { id: workspaceId },
            include: workspaceInclude,
          });
          if (!result) throw workspaceNotFound();
          const serialized = this.serialize(result, true);
          await this.idempotency.complete(
            {
              recordId: reservation.recordId,
              responseCode: 200,
              responseSnapshot: serialized as unknown as Prisma.InputJsonValue,
              resourceType: 'ScholarshipWorkspace',
              resourceId: workspaceId,
              resultingVersion: serialized.version,
            },
            tx,
          );
          return serialized;
        }),
      );
      if (!updated) throw databaseUnavailable();
      return updated;
    } catch (error) {
      this.translateInfrastructureError(error);
    }
  }

  private replayWorkspace(
    reservation: Extract<IdempotencyReservation, { state: 'replay' }>,
  ): ReturnType<WorkspacesService['serialize']> {
    const snapshot = reservation.responseSnapshot;
    if (
      snapshot === null ||
      Array.isArray(snapshot) ||
      typeof snapshot !== 'object' ||
      typeof snapshot.id !== 'string' ||
      typeof snapshot.version !== 'number'
    ) {
      throw databaseUnavailable();
    }
    return snapshot as unknown as ReturnType<WorkspacesService['serialize']>;
  }

  private translateInfrastructureError(error: unknown): never {
    if (error instanceof IdempotencyPayloadMismatchError) {
      throw idempotencyPayloadMismatch();
    }
    if (error instanceof IdempotencyStorageUnavailableError) {
      throw databaseUnavailable();
    }
    if (error instanceof DomainEventConflictError) {
      throw outboxEventConflict();
    }
    if (error instanceof DomainEventOutboxUnavailableError) {
      throw databaseUnavailable();
    }
    throw error;
  }

  private findOwned(userId: string, workspaceId: string) {
    return this.prismaService.execute((prisma) =>
      prisma.scholarshipWorkspace.findFirst({
        where: { id: workspaceId, userId },
        include: workspaceInclude,
      }),
    );
  }

  private findOwnedByCycle(userId: string, input: CreateWorkspaceDto) {
    return this.prismaService.execute((prisma) =>
      prisma.scholarshipWorkspace.findUnique({
        where: {
          userId_scholarshipId_scholarshipCycleId: {
            userId,
            scholarshipId: input.scholarshipId,
            scholarshipCycleId: input.cycleId,
          },
        },
        include: workspaceInclude,
      }),
    );
  }

  private serialize(workspace: WorkspaceWithDetails, includeSteps: boolean) {
    const progress = this.progressService.calculate(workspace.steps);
    return {
      schemaVersion: 1,
      id: workspace.id,
      status: workspace.status,
      version: workspace.version,
      readinessPercent: workspace.readinessPercent,
      scholarship: {
        ...workspace.scholarship,
        // v1 summary fields are localized to French for the primary market;
        // bilingual fields remain additive for newer clients.
        name: workspace.scholarship.nameFr,
        countryName: workspace.scholarship.countryNameFr,
      },
      cycle: {
        id: workspace.scholarshipCycle.id,
        academicYear: workspace.scholarshipCycle.academicYear,
        status: workspace.scholarshipCycle.status,
        dateConfidence: workspace.scholarshipCycle.dateConfidence,
        opensAt: workspace.scholarshipCycle.opensAt?.toISOString() ?? null,
        closesAt: workspace.scholarshipCycle.closesAt?.toISOString() ?? null,
        estimatedOpenAt:
          workspace.scholarshipCycle.estimatedOpenAt?.toISOString() ?? null,
        estimatedCloseAt:
          workspace.scholarshipCycle.estimatedCloseAt?.toISOString() ?? null,
      },
      nextAction: progress.nextAction
        ? {
            ...progress.nextAction,
            label: progress.nextAction.labelFr,
          }
        : null,
      startedAt: workspace.startedAt.toISOString(),
      lastActivityAt: workspace.lastActivityAt.toISOString(),
      submittedAt: workspace.submittedAt?.toISOString() ?? null,
      decisionReceivedAt: workspace.decisionReceivedAt?.toISOString() ?? null,
      archivedAt: workspace.archivedAt?.toISOString() ?? null,
      ...(includeSteps
        ? {
            steps: workspace.steps.map((step) => ({
              id: step.id,
              sourceStepId: step.sourceStepId,
              code: step.code,
              titleFr: step.titleFr,
              titleEn: step.titleEn,
              category: step.category,
              weight: step.weight,
              isRequired: step.isRequired,
              templateVersion: step.templateVersion,
              status: step.status,
              notApplicableReason: step.notApplicableReason,
              completedAt: step.completedAt?.toISOString() ?? null,
            })),
          }
        : {}),
    };
  }
}
