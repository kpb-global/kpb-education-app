import { randomUUID } from 'node:crypto';

import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma, type StudyReviewStatus } from '@prisma/client';

import { CaseType } from '../../../common/enums/case-type.enum';
import { InternalRole } from '../../../common/enums/internal-role.enum';
import { PrismaService } from '../../prisma/prisma.service';
import {
  CompetitionReadinessHttpException,
  databaseUnavailable,
  idempotencyInProgress,
  idempotencyPayloadMismatch,
  outboxEventConflict,
  versionConflict,
} from '../common/competition-readiness.errors';
import {
  DomainEventConflictError,
  DomainEventOutboxService,
  DomainEventOutboxUnavailableError,
} from '../common/domain-event-outbox.service';
import {
  IdempotencyPayloadMismatchError,
  IdempotencyService,
  IdempotencyStorageUnavailableError,
} from '../common/idempotency.service';
import type { ConvertReviewToCaseDto } from './dto/convert-review-to-case.dto';
import type { ListAdminReviewRequestsDto } from './dto/list-admin-review-requests.dto';
import type { TriageReviewRequestDto } from './dto/triage-review-request.dto';
import {
  AdminReviewAccessService,
  type AdminReviewActor,
  type ReviewProjection,
} from './admin-review-access.service';

const reviewSelect = {
  id: true,
  workspaceId: true,
  requestNumber: true,
  version: true,
  status: true,
  assignedCounsellorId: true,
  studentMessage: true,
  preferredContact: true,
  timezone: true,
  availability: true,
  triageSummary: true,
  missingItems: true,
  submittedAt: true,
  triagedAt: true,
  closedAt: true,
  resultingCaseId: true,
  resultingPurchaseId: true,
  createdAt: true,
  updatedAt: true,
  assignedCounsellor: { select: { id: true, fullName: true } },
  workspace: {
    select: {
      id: true,
      userId: true,
      status: true,
      version: true,
      scholarshipCycleId: true,
      scholarship: {
        select: {
          id: true,
          nameFr: true,
          countryId: true,
        },
      },
    },
  },
  artifactShares: {
    orderBy: { grantedAt: 'asc' as const },
    select: {
      id: true,
      artifactVersionId: true,
      grantedAt: true,
      revokedAt: true,
      consentReceipt: { select: { revokedAt: true } },
      artifactVersion: {
        select: {
          id: true,
          originalFileName: true,
          mimeType: true,
          processingStatus: true,
          deletedAt: true,
          artifact: { select: { kind: true } },
        },
      },
    },
  },
} satisfies Prisma.StudyReviewRequestSelect;

type ReviewRow = Prisma.StudyReviewRequestGetPayload<{
  select: typeof reviewSelect;
}>;

type Cursor = { createdAt: string; id: string };

const TRIAGE_TARGET_STATUS = {
  triage: 'triaged',
  assign: null,
  request_more_information: 'more_information_needed',
  recommend_autonomy: 'autonomy_recommended',
  decline: 'declined',
  close: 'closed',
} as const satisfies Record<
  TriageReviewRequestDto['action'],
  StudyReviewStatus | null
>;

const ALLOWED_TRIAGE_SOURCES: Record<
  TriageReviewRequestDto['action'],
  readonly StudyReviewStatus[]
> = {
  triage: ['submitted', 'more_information_needed'],
  assign: [
    'draft',
    'submitted',
    'triaged',
    'more_information_needed',
    'call_offered',
    'scheduled',
    'autonomy_recommended',
    'declined',
  ],
  request_more_information: ['submitted', 'triaged'],
  recommend_autonomy: ['triaged'],
  decline: ['triaged', 'call_offered'],
  close: ['autonomy_recommended', 'declined', 'converted_to_case'],
};

const CONVERTIBLE_STATUSES: readonly StudyReviewStatus[] = [
  'triaged',
  'call_offered',
  'scheduled',
];

@Injectable()
export class AdminReviewOperationsService {
  constructor(
    private readonly prismaService: PrismaService,
    private readonly access: AdminReviewAccessService,
    private readonly idempotency: IdempotencyService,
    private readonly outbox: DomainEventOutboxService,
  ) {}

  async list(actor: AdminReviewActor, query: ListAdminReviewRequestsDto) {
    this.assertDb();
    this.access.assertReviewFeatureEnabled();
    const scope = await this.access.listScope(actor);
    const cursor = query.cursor ? this.decodeCursor(query.cursor) : null;
    const slaHours = this.slaHours();
    const overdueBefore = new Date(Date.now() - slaHours * 60 * 60 * 1000);

    const result = await this.prismaService.execute(async (prisma) => {
      const countryCandidates = query.countryCode
        ? await this.countryCandidates(prisma, query.countryCode)
        : null;
      const baseWhere: Prisma.StudyReviewRequestWhereInput = {
        AND: [
          scope.where,
          ...(query.status?.length ? [{ status: { in: query.status } }] : []),
          ...(query.assignedCounsellorId
            ? [{ assignedCounsellorId: query.assignedCounsellorId }]
            : []),
          ...(query.scholarshipId
            ? [{ workspace: { scholarshipId: query.scholarshipId } }]
            : []),
          ...(countryCandidates
            ? [
                {
                  workspace: {
                    scholarship: { countryId: { in: countryCandidates } },
                  },
                },
              ]
            : []),
          ...(query.overdueOnly
            ? [
                {
                  submittedAt: { lte: overdueBefore },
                  status: 'submitted' as const,
                },
              ]
            : []),
        ],
      };
      const pageWhere: Prisma.StudyReviewRequestWhereInput = cursor
        ? {
            AND: [
              baseWhere,
              {
                OR: [
                  { createdAt: { lt: new Date(cursor.createdAt) } },
                  {
                    createdAt: new Date(cursor.createdAt),
                    id: { lt: cursor.id },
                  },
                ],
              },
            ],
          }
        : baseWhere;
      const [rows, total] = await prisma.$transaction([
        prisma.studyReviewRequest.findMany({
          where: pageWhere,
          orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
          take: query.limit + 1,
          select: reviewSelect,
        }),
        prisma.studyReviewRequest.count({ where: baseWhere }),
      ]);
      const page = rows.slice(0, query.limit);
      const countryCodes = await this.countryCodeMap(
        prisma,
        page.map((row) => row.workspace.scholarship.countryId),
      );
      return {
        rows: page,
        total,
        countryCodes,
        hasMore: rows.length > query.limit,
      };
    });
    if (!result) throw databaseUnavailable();
    const last = result.rows.at(-1);
    return {
      items: result.rows.map((row) =>
        this.serializeListItem(row, scope.projection, result.countryCodes),
      ),
      nextCursor:
        result.hasMore && last
          ? this.encodeCursor({
              createdAt: last.createdAt.toISOString(),
              id: last.id,
            })
          : null,
      total: result.total,
    };
  }

  async getDetail(actor: AdminReviewActor, id: string) {
    this.assertDb();
    this.access.assertReviewFeatureEnabled();
    const review = await this.loadReview(id);
    if (!review) throw new NotFoundException('Review request not found.');
    const projection = await this.access.assertCanReadDetail(actor, review);
    let canOpenEvidence = false;
    try {
      await this.access.assertCanOpenEvidence(actor, review);
      canOpenEvidence = true;
    } catch (error) {
      if (!this.isForbiddenScope(error)) throw error;
    }
    return this.serializeDetail(review, projection, canOpenEvidence);
  }

  async triage(
    actor: AdminReviewActor,
    id: string,
    input: TriageReviewRequestDto,
    requestId: string,
  ) {
    this.assertDb();
    this.access.assertReviewFeatureEnabled();
    const actorCounsellorId = this.access.isCounselor(actor)
      ? (await this.access.resolveCounsellor(actor)).id
      : null;

    const result = await this.prismaService.execute((prisma) =>
      prisma.$transaction(async (tx) => {
        await tx.$queryRaw(
          Prisma.sql`SELECT "id" FROM "StudyReviewRequest" WHERE "id" = ${id} FOR UPDATE`,
        );
        const current = await tx.studyReviewRequest.findUnique({
          where: { id },
          select: reviewSelect,
        });
        if (!current) throw new NotFoundException('Review request not found.');
        await this.access.assertCanReadDetail(actor, current);
        if (input.action === 'assign') {
          await this.access.assertCanAssign(
            actor,
            current,
            input.assignedCounsellorId ?? null,
          );
        } else {
          await this.access.assertCanTriage(actor, current);
          if (input.assignedCounsellorId !== undefined) {
            await this.access.assertCanAssign(
              actor,
              current,
              input.assignedCounsellorId,
            );
          }
        }
        this.assertTriageActor(actor, actorCounsellorId, current);
        if (current.version !== input.expectedVersion) {
          throw versionConflict(current.version);
        }
        this.assertTriageInput(actor, current, input);

        let targetCounsellor = current.assignedCounsellor;
        if (input.assignedCounsellorId !== undefined) {
          targetCounsellor = input.assignedCounsellorId
            ? await tx.counsellor.findFirst({
                where: { id: input.assignedCounsellorId, isActive: true },
                select: { id: true, fullName: true },
              })
            : null;
          if (input.assignedCounsellorId && !targetCounsellor) {
            throw new BadRequestException('Assigned counsellor is not active.');
          }
        }

        const targetStatus =
          TRIAGE_TARGET_STATUS[input.action] ?? current.status;
        if (targetStatus === 'triaged' && !targetCounsellor) {
          throw new BadRequestException(
            'A review must be assigned before it can be triaged.',
          );
        }
        const nextVersion = current.version + 1;
        const updated = await tx.studyReviewRequest.updateMany({
          where: { id, version: input.expectedVersion },
          data: {
            version: { increment: 1 },
            status: targetStatus,
            ...(input.assignedCounsellorId !== undefined
              ? { assignedCounsellorId: input.assignedCounsellorId }
              : {}),
            ...(input.triageSummary !== undefined
              ? { triageSummary: input.triageSummary.trim() || null }
              : {}),
            ...(input.missingItems !== undefined
              ? { missingItems: input.missingItems }
              : {}),
            ...(targetStatus === 'triaged' && !current.triagedAt
              ? { triagedAt: new Date() }
              : {}),
            ...(targetStatus === 'closed' ? { closedAt: new Date() } : {}),
          },
        });
        if (updated.count !== 1) throw versionConflict(current.version);

        if (targetStatus === 'more_information_needed') {
          await tx.scholarshipWorkspace.update({
            where: { id: current.workspaceId },
            data: {
              status: 'preparing',
              version: { increment: 1 },
              lastActivityAt: new Date(),
            },
          });
        }
        await tx.adminAuditEvent.create({
          data: {
            actorAdminId: actor.id,
            action: `study_review.${input.action}`,
            purposeCode: 'study_review_triage',
            entityType: 'StudyReviewRequest',
            entityId: id,
            requestId,
            reasonCode: input.reasonCode,
            result: 'success',
            changes: {
              fromStatus: current.status,
              toStatus: targetStatus,
              fromAssignedCounsellorId: current.assignedCounsellorId,
              toAssignedCounsellorId: targetCounsellor?.id ?? null,
              previousVersion: current.version,
              nextVersion,
              triageSummaryChanged: input.triageSummary !== undefined,
              missingItemsCount: input.missingItems?.length ?? 0,
            },
          },
        });
        await this.outbox.enqueue(
          {
            eventId: `study_review.${input.action}:${id}:${nextVersion}`,
            eventName: `study_review.${input.action}`,
            aggregateType: 'StudyReviewRequest',
            aggregateId: id,
            payload: {
              reviewRequestId: id,
              workspaceId: current.workspaceId,
              status: targetStatus,
              assignedCounsellorId: targetCounsellor?.id ?? null,
              version: nextVersion,
            },
          },
          tx,
        );
        return true;
      }),
    );
    if (!result) throw databaseUnavailable();
    return this.getDetail(actor, id);
  }

  async convertToCase(
    actor: AdminReviewActor,
    id: string,
    input: ConvertReviewToCaseDto,
    idempotencyKey: string,
    requestId: string,
  ) {
    this.assertDb();
    this.access.assertReviewFeatureEnabled();
    if (input.serviceOfferId) {
      throw new BadRequestException(
        'A service offer cannot be attached during case conversion.',
      );
    }
    try {
      const result = await this.prismaService.execute((prisma) =>
        prisma.$transaction(async (tx) => {
          const reservation = await this.idempotency.reserve(
            {
              actorType: 'admin',
              actorId: actor.id,
              operation: `study_review.convert_to_case:${id}`,
              idempotencyKey,
              payload: input,
            },
            tx,
          );
          if (reservation.state === 'replay') {
            return this.deserializeConversionReplay(
              reservation.responseSnapshot,
              reservation.responseCode,
            );
          }
          if (reservation.state !== 'acquired') throw idempotencyInProgress();

          await tx.$queryRaw(
            Prisma.sql`SELECT "id" FROM "StudyReviewRequest" WHERE "id" = ${id} FOR UPDATE`,
          );
          const current = await tx.studyReviewRequest.findUnique({
            where: { id },
            select: reviewSelect,
          });
          if (!current) throw new NotFoundException('Review request not found.');
          await this.access.assertCanConvert(actor, current);

          if (current.resultingCaseId) {
            const response = {
              caseId: current.resultingCaseId,
              purchaseId: current.resultingPurchaseId,
            };
            await this.idempotency.complete(
              {
                recordId: reservation.recordId,
                responseCode: 200,
                responseSnapshot: response,
                resourceType: 'Case',
                resourceId: current.resultingCaseId,
                resultingVersion: current.version,
              },
              tx,
            );
            return { statusCode: 200, body: response };
          }
          if (current.version !== input.expectedVersion) {
            throw versionConflict(current.version);
          }
          if (
            !current.triagedAt ||
            !CONVERTIBLE_STATUSES.includes(current.status)
          ) {
            throw new CompetitionReadinessHttpException(
              'REVIEW_REQUEST_NOT_TRIAGED',
              409,
              'Review request must be triaged before case conversion.',
            );
          }

          const createdCase = await tx.case.create({
            data: {
              referenceCode: `PENDING-${randomUUID()}`,
              userId: current.workspace.userId,
              type: input.caseType ?? CaseType.ScholarshipSupport,
              status: current.assignedCounsellorId
                ? 'counselor_assigned'
                : 'under_review',
              title: `Accompagnement - ${current.workspace.scholarship.nameFr}`,
              description:
                'Dossier créé après étude humaine de la demande de bourse.',
              contextLabel: current.workspace.scholarship.nameFr,
              nextStepTitle: 'Dossier en cours de prise en charge',
              nextStepDescription:
                'L’équipe KPB poursuit l’accompagnement après l’étude initiale.',
              source: 'competition_readiness_review',
              requestedCountryId: current.workspace.scholarship.countryId,
              preferredContactMethod: current.preferredContact ?? 'in_app',
              counsellorId: current.assignedCounsellorId,
              assignedAdvisorName: current.assignedCounsellor?.fullName,
            },
            select: { id: true, seq: true, createdAt: true },
          });
          const referenceCode = `KPB-${createdCase.createdAt.getUTCFullYear()}-${String(createdCase.seq).padStart(3, '0')}`;
          await tx.case.update({
            where: { id: createdCase.id },
            data: { referenceCode },
          });
          await tx.caseTimelineEvent.create({
            data: {
              caseId: createdCase.id,
              status: current.assignedCounsellorId
                ? 'counselor_assigned'
                : 'under_review',
              title: 'Dossier créé après étude',
              description:
                'La demande d’étude a été convertie en dossier d’accompagnement.',
            },
          });
          const nextVersion = current.version + 1;
          const linked = await tx.studyReviewRequest.updateMany({
            where: {
              id,
              version: input.expectedVersion,
              resultingCaseId: null,
            },
            data: {
              resultingCaseId: createdCase.id,
              status: 'converted_to_case',
              version: { increment: 1 },
            },
          });
          if (linked.count !== 1) throw versionConflict(current.version);

          await tx.adminAuditEvent.create({
            data: {
              actorAdminId: actor.id,
              action: 'study_review.convert_to_case',
              purposeCode: 'case_conversion_after_review',
              entityType: 'StudyReviewRequest',
              entityId: id,
              requestId,
              reasonCode: input.reasonCode,
              result: 'success',
              changes: {
                caseId: createdCase.id,
                fromStatus: current.status,
                toStatus: 'converted_to_case',
                previousVersion: current.version,
                nextVersion,
                purchaseCreated: false,
              },
            },
          });
          await this.outbox.enqueue(
            {
              eventId: `study_review.converted_to_case:${id}:${createdCase.id}`,
              eventName: 'study_review.converted_to_case',
              aggregateType: 'StudyReviewRequest',
              aggregateId: id,
              payload: {
                reviewRequestId: id,
                workspaceId: current.workspaceId,
                caseId: createdCase.id,
                version: nextVersion,
              },
            },
            tx,
          );
          const response = { caseId: createdCase.id, purchaseId: null };
          await this.idempotency.complete(
            {
              recordId: reservation.recordId,
              responseCode: 201,
              responseSnapshot: response,
              resourceType: 'Case',
              resourceId: createdCase.id,
              resultingVersion: nextVersion,
            },
            tx,
          );
          return { statusCode: 201, body: response };
        }),
      );
      if (!result) throw databaseUnavailable();
      return result;
    } catch (error) {
      this.translateInfrastructureError(error);
    }
  }

  private async loadReview(id: string): Promise<ReviewRow | null> {
    const review = await this.prismaService.execute((prisma) =>
      prisma.studyReviewRequest.findUnique({
        where: { id },
        select: reviewSelect,
      }),
    );
    return review ?? null;
  }

  private async serializeDetail(
    review: ReviewRow,
    projection: ReviewProjection,
    canOpenEvidence: boolean,
  ) {
    if (projection === 'metadata') {
      const countries = await this.prismaService.execute((prisma) =>
        this.countryCodeMap(prisma, [review.workspace.scholarship.countryId]),
      );
      if (!countries) throw databaseUnavailable();
      return {
        ...this.serializeListItem(review, projection, countries),
        timezone: 'UTC',
        studentMessage: null,
        preferredContact: null,
        availability: null,
        triageSummary: null,
        missingItems: null,
        artifacts: [],
        audit: [],
      };
    }
    const metadata = await this.prismaService.execute(async (prisma) => {
      const audits = await prisma.adminAuditEvent.findMany({
        where: { entityType: 'StudyReviewRequest', entityId: review.id },
        orderBy: { occurredAt: 'desc' },
        take: 50,
        select: {
          id: true,
          actorAdminId: true,
          action: true,
          result: true,
          reasonCode: true,
          occurredAt: true,
        },
      });
      const actorIds = audits
        .map((audit) => audit.actorAdminId)
        .filter((id): id is string => Boolean(id));
      const [admins, countries] = await Promise.all([
        actorIds.length
          ? prisma.adminUser.findMany({
              where: { id: { in: actorIds } },
              select: { id: true, fullName: true },
            })
          : Promise.resolve([]),
        this.countryCodeMap(prisma, [review.workspace.scholarship.countryId]),
      ]);
      return {
        audits,
        actorNames: new Map(admins.map((admin) => [admin.id, admin.fullName])),
        countries,
      };
    });
    if (!metadata) throw databaseUnavailable();
    return {
      ...this.serializeListItem(review, projection, metadata.countries),
      timezone: review.timezone,
      studentMessage: review.studentMessage,
      preferredContact: review.preferredContact,
      availability: review.availability,
      triageSummary: review.triageSummary,
      missingItems: review.missingItems,
      artifacts: review.artifactShares.map((share) => ({
        artifactVersionId: share.artifactVersionId,
        kind: share.artifactVersion.artifact.kind,
        originalFileName: share.artifactVersion.originalFileName,
        mimeType: share.artifactVersion.mimeType,
        processingStatus: share.artifactVersion.processingStatus,
        sharedAt: share.grantedAt.toISOString(),
        revokedAt: share.revokedAt?.toISOString() ?? null,
        canOpen:
          canOpenEvidence &&
          share.revokedAt === null &&
          share.consentReceipt.revokedAt === null &&
          share.artifactVersion.deletedAt === null &&
          share.artifactVersion.processingStatus === 'clean',
      })),
      audit: metadata.audits.map((audit) => ({
        id: audit.id,
        action: audit.action,
        result: audit.result,
        actorDisplayName: audit.actorAdminId
          ? metadata.actorNames.get(audit.actorAdminId) ?? null
          : null,
        reasonCode: audit.reasonCode,
        occurredAt: audit.occurredAt.toISOString(),
      })),
    };
  }

  private serializeListItem(
    review: ReviewRow,
    projection: ReviewProjection,
    countryCodes: Map<string, string>,
  ) {
    const slaDueAt = review.submittedAt
      ? new Date(
          review.submittedAt.getTime() + this.slaHours() * 60 * 60 * 1000,
        )
      : null;
    return {
      id: review.id,
      workspaceId: review.workspaceId,
      requestNumber: review.requestNumber,
      version: review.version,
      status: review.status,
      submittedAt: review.submittedAt?.toISOString() ?? null,
      updatedAt: review.updatedAt.toISOString(),
      assignedCounsellorId: review.assignedCounsellorId,
      assignedCounsellorName: review.assignedCounsellor?.fullName ?? null,
      scholarship: {
        id: review.workspace.scholarship.id,
        cycleId: review.workspace.scholarshipCycleId,
        title: review.workspace.scholarship.nameFr,
        countryCodes: [
          countryCodes.get(review.workspace.scholarship.countryId),
        ].filter((code): code is string => Boolean(code)),
      },
      slaDueAt: slaDueAt?.toISOString() ?? null,
      slaBreached:
        Boolean(slaDueAt && slaDueAt.getTime() < Date.now()) &&
        review.status === 'submitted',
      projection,
    };
  }

  private assertTriageActor(
    actor: AdminReviewActor,
    actorCounsellorId: string | null,
    review: ReviewRow,
  ) {
    if (this.access.isPlatformAdmin(actor)) return;
    if (
      actor.role !== InternalRole.Counselor ||
      !actorCounsellorId ||
      review.assignedCounsellorId !== actorCounsellorId
    ) {
      throw new CompetitionReadinessHttpException(
        'FORBIDDEN_SCOPE',
        403,
        'This operator cannot triage this request.',
      );
    }
  }

  private assertTriageInput(
    actor: AdminReviewActor,
    review: ReviewRow,
    input: TriageReviewRequestDto,
  ) {
    if (!ALLOWED_TRIAGE_SOURCES[input.action].includes(review.status)) {
      throw new CompetitionReadinessHttpException(
        'FORBIDDEN_SCOPE',
        409,
        'This triage transition is not allowed.',
      );
    }
    if (
      input.action === 'request_more_information' &&
      (!input.missingItems || input.missingItems.length === 0)
    ) {
      throw new BadRequestException(
        'missingItems is required when requesting more information.',
      );
    }
    if (input.action === 'assign' && !input.assignedCounsellorId) {
      throw new BadRequestException(
        'assignedCounsellorId is required for assignment.',
      );
    }
    if (
      !this.access.isPlatformAdmin(actor) &&
      (input.action === 'assign' || input.assignedCounsellorId !== undefined)
    ) {
      throw new CompetitionReadinessHttpException(
        'FORBIDDEN_SCOPE',
        403,
        'Only administrators may assign review requests.',
      );
    }
  }

  private async countryCandidates(
    prisma: Prisma.TransactionClient | Parameters<
      Parameters<PrismaService['execute']>[0]
    >[0],
    input: string,
  ): Promise<string[]> {
    const country = await prisma.country.findFirst({
      where: { code: { equals: input, mode: 'insensitive' } },
      select: { id: true, code: true },
    });
    return Array.from(
      new Set(
        [input, input.toLowerCase(), input.toUpperCase(), country?.id, country?.code]
          .filter((value): value is string => Boolean(value)),
      ),
    );
  }

  private async countryCodeMap(
    prisma: Prisma.TransactionClient | Parameters<
      Parameters<PrismaService['execute']>[0]
    >[0],
    ids: string[],
  ): Promise<Map<string, string>> {
    const candidates = Array.from(
      new Set(ids.flatMap((id) => [id, id.toLowerCase(), id.toUpperCase()])),
    );
    if (candidates.length === 0) return new Map();
    const countries = await prisma.country.findMany({
      where: { OR: [{ id: { in: candidates } }, { code: { in: candidates } }] },
      select: { id: true, code: true },
    });
    const result = new Map<string, string>();
    for (const country of countries) {
      result.set(country.id, country.code);
      result.set(country.code, country.code);
      result.set(country.code.toLowerCase(), country.code);
    }
    return result;
  }

  private encodeCursor(cursor: Cursor): string {
    return Buffer.from(JSON.stringify(cursor), 'utf8').toString('base64url');
  }

  private decodeCursor(value: string): Cursor {
    try {
      const parsed = JSON.parse(
        Buffer.from(value, 'base64url').toString('utf8'),
      ) as Partial<Cursor>;
      if (
        typeof parsed.createdAt !== 'string' ||
        Number.isNaN(new Date(parsed.createdAt).getTime()) ||
        typeof parsed.id !== 'string' ||
        !parsed.id
      ) {
        throw new Error('invalid cursor');
      }
      return { createdAt: parsed.createdAt, id: parsed.id };
    } catch {
      throw new BadRequestException('Invalid review request cursor.');
    }
  }

  private slaHours(): number {
    const parsed = Number(process.env.KPB_STUDY_REVIEW_SLA_HOURS ?? '48');
    return Number.isSafeInteger(parsed) && parsed >= 1 && parsed <= 720
      ? parsed
      : 48;
  }

  private deserializeConversionReplay(
    snapshot: Prisma.JsonValue | null,
    responseCode: number | null,
  ) {
    if (
      !snapshot ||
      Array.isArray(snapshot) ||
      typeof snapshot !== 'object' ||
      typeof snapshot.caseId !== 'string' ||
      ![200, 201].includes(responseCode ?? 0)
    ) {
      throw databaseUnavailable();
    }
    return {
      statusCode: responseCode as 200 | 201,
      body: {
        caseId: snapshot.caseId,
        purchaseId:
          typeof snapshot.purchaseId === 'string' ? snapshot.purchaseId : null,
      },
    };
  }

  private assertDb() {
    if (!this.prismaService.isEnabled) throw databaseUnavailable();
  }

  private isForbiddenScope(error: unknown): boolean {
    if (!(error instanceof CompetitionReadinessHttpException)) return false;
    const response = error.getResponse();
    return (
      typeof response === 'object' &&
      response !== null &&
      'code' in response &&
      response.code === 'FORBIDDEN_SCOPE'
    );
  }

  private translateInfrastructureError(error: unknown): never {
    if (error instanceof IdempotencyPayloadMismatchError) {
      throw idempotencyPayloadMismatch();
    }
    if (error instanceof IdempotencyStorageUnavailableError) {
      throw databaseUnavailable();
    }
    if (error instanceof DomainEventConflictError) throw outboxEventConflict();
    if (error instanceof DomainEventOutboxUnavailableError) {
      throw databaseUnavailable();
    }
    throw error;
  }
}
