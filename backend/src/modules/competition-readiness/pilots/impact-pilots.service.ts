import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { PilotStatus, Prisma, type ImpactPilot } from '@prisma/client';

import type { AdminSessionUser } from '../../auth/auth.service';
import { PrismaService } from '../../prisma/prisma.service';
import {
  databaseUnavailable,
  idempotencyInProgress,
  idempotencyPayloadMismatch,
  versionConflict,
} from '../common/competition-readiness.errors';
import { DomainEventOutboxService } from '../common/domain-event-outbox.service';
import {
  IdempotencyPayloadMismatchError,
  IdempotencyService,
  IdempotencyStorageUnavailableError,
} from '../common/idempotency.service';
import {
  ADMIN_IMPACT_CAPABILITIES,
  AdminImpactAccessService,
} from '../admin/admin-impact-access.service';
import type {
  CreateExperimentAssignmentDto,
  CreateImpactCohortDto,
  CreateImpactPilotDto,
  CreatePilotAssessmentDto,
  EnrolImpactCohortMemberDto,
  ListImpactPilotsDto,
  UpdateImpactPilotDto,
  WithdrawImpactCohortMemberDto,
} from '../admin/dto/impact-pilot.dto';

const PILOT_CHANGE_FIELDS = new Set([
  'name',
  'hypothesis',
  'countryCodes',
  'targetPopulation',
  'primaryMetrics',
  'guardrailMetrics',
  'status',
  'recruitmentStartsAt',
  'startsAt',
  'endsAt',
  'protocolVersion',
  'partnerAgreementIds',
]);

type PilotAgreement = {
  id: string;
  status: string;
  isCurrent: boolean;
  canRecruitPilot: boolean;
  canShareAggregateData: boolean;
  purposeCodes: string[];
  countryCodes: string[];
  startsAt: Date | null;
  endsAt: Date | null;
};

@Injectable()
export class ImpactPilotsService {
  constructor(
    private readonly prismaService: PrismaService,
    private readonly access: AdminImpactAccessService,
    private readonly idempotency: IdempotencyService,
    private readonly outbox: DomainEventOutboxService,
  ) {}

  async list(actor: AdminSessionUser, query: ListImpactPilotsDto) {
    this.assertDb();
    const listCapability =
      actor.role === 'commercial'
        ? ADMIN_IMPACT_CAPABILITIES.recruitPilotParticipants
        : ADMIN_IMPACT_CAPABILITIES.viewPilotAggregates;
    const scope = await this.access.listScope(actor, listCapability);
    const resourceFilters: Prisma.ImpactPilotWhereInput[] = [];
    for (const resource of scope.resources ?? [{}]) {
      if (resource.partnerIds || resource.agreementIds) continue;
      resourceFilters.push({
        ...(resource.pilotIds ? { id: { in: resource.pilotIds } } : {}),
        ...(resource.cohortIds
          ? { cohorts: { some: { id: { in: resource.cohortIds } } } }
          : {}),
      });
    }
    const rows = await this.prismaService.execute((prisma) =>
      prisma.impactPilot.findMany({
        where: {
          ...(query.status ? { status: { in: query.status } } : {}),
          ...(query.countryCode
            ? { countryCodes: { has: query.countryCode.toUpperCase() } }
            : {}),
          ...(scope.countryCodes
            ? { countryCodes: { hasSome: scope.countryCodes } }
            : {}),
          ...(scope.resources ? { OR: resourceFilters } : {}),
        },
        orderBy: [{ updatedAt: 'desc' }, { id: 'desc' }],
        ...(query.cursor ? { cursor: { id: query.cursor }, skip: 1 } : {}),
        take: query.limit + 1,
        include: {
          cohorts: {
            select: {
              id: true,
              memberships: {
                select: {
                  status: true,
                  consentReceipt: { select: { revokedAt: true } },
                },
              },
            },
          },
        },
      }),
    );
    if (!rows) throw databaseUnavailable();
    const visibleRows = rows.filter((row) =>
      this.access.pilotCovered(scope, {
        ...row,
        cohortIds: row.cohorts.map((cohort) => cohort.id),
      }),
    );
    const hasMore = rows.length > query.limit;
    const items = visibleRows.slice(0, query.limit);
    return {
      items: items.map((pilot) => this.serialize(pilot)),
      nextCursor: hasMore ? items.at(-1)?.id ?? null : null,
    };
  }

  async create(
    actor: AdminSessionUser,
    input: CreateImpactPilotDto,
    idempotencyKey: string,
    requestId: string,
  ) {
    this.assertDb();
    const data = this.normalizeCreate(input);
    await this.access.assertPilot(
      actor,
      ADMIN_IMPACT_CAPABILITIES.managePilots,
      { id: '__new__', countryCodes: data.countryCodes },
    );
    this.validateWindow(data);
    try {
      const result = await this.prismaService.execute((prisma) =>
        prisma.$transaction(async (tx) => {
          const reservation = await this.idempotency.reserve(
            {
              actorType: 'admin',
              actorId: actor.id,
              operation: 'impact-pilot.create',
              idempotencyKey,
              payload: input,
            },
            tx,
          );
          if (reservation.state === 'replay') {
            return this.replay(reservation.responseSnapshot, reservation.responseCode);
          }
          if (reservation.state !== 'acquired') throw idempotencyInProgress();
          const agreements = await this.loadAgreements(tx, data.partnerAgreementIds);
          this.validatePilotState(data, agreements);
          const pilot = await tx.impactPilot.create({
            data: {
              code: data.code,
              name: data.name,
              hypothesis: data.hypothesis,
              countryCodes: data.countryCodes,
              targetPopulation: data.targetPopulation,
              primaryMetrics: data.primaryMetrics,
              guardrailMetrics: data.guardrailMetrics,
              status: data.status,
              recruitmentStartsAt: data.recruitmentStartsAt,
              startsAt: data.startsAt,
              endsAt: data.endsAt,
              protocolVersion: data.protocolVersion,
              ownerAdminId: actor.id,
              partnerAgreements: {
                create: agreements.map((agreement) => ({
                  agreementId: agreement.id,
                  countryCodes: intersection(data.countryCodes, agreement.countryCodes),
                  startsAt: later(data.recruitmentStartsAt, agreement.startsAt),
                  endsAt: earlier(data.endsAt, agreement.endsAt),
                  roleCodes: [
                    'pilot_recruitment',
                    ...(agreement.canShareAggregateData
                      ? ['aggregate_data']
                      : []),
                  ],
                })),
              },
            },
            include: { cohorts: { include: { memberships: true } } },
          });
          const body = this.serialize(pilot);
          await this.auditAndEmit(
            tx,
            actor,
            pilot,
            'impact_pilot.created',
            input.reasonCode,
            requestId,
          );
          await this.idempotency.complete(
            {
              recordId: reservation.recordId,
              responseCode: 201,
              responseSnapshot: body,
              resourceType: 'ImpactPilot',
              resourceId: pilot.id,
              resultingVersion: pilot.version,
            },
            tx,
          );
          return { statusCode: 201 as const, body };
        }),
      );
      if (!result) throw databaseUnavailable();
      return result;
    } catch (error) {
      this.translate(error);
    }
  }

  async update(
    actor: AdminSessionUser,
    pilotId: string,
    input: UpdateImpactPilotDto,
    idempotencyKey: string,
    requestId: string,
  ) {
    this.assertDb();
    try {
      const result = await this.prismaService.execute((prisma) =>
        prisma.$transaction(async (tx) => {
        const reservation = await this.idempotency.reserve(
          {
            actorType: 'admin',
            actorId: actor.id,
            operation: `impact-pilot.update:${pilotId}`,
            idempotencyKey,
            payload: input,
          },
          tx,
        );
        if (reservation.state === 'replay') {
          return this.replay(
            reservation.responseSnapshot,
            reservation.responseCode,
          );
        }
        if (reservation.state !== 'acquired') throw idempotencyInProgress();
        const current = await tx.impactPilot.findUnique({ where: { id: pilotId } });
        if (!current) throw new NotFoundException('Impact pilot not found.');
        await this.access.assertPilot(
          actor,
          ADMIN_IMPACT_CAPABILITIES.managePilots,
          current,
        );
        if (current.version !== input.expectedVersion) throw versionConflict(current.version);
        if (current.analysisLockedAt) {
          throw new BadRequestException('Analysis-locked pilot cannot be modified.');
        }
        const changes = this.normalizeChanges(input.changes);
        const agreementIds = changes.partnerAgreementIds;
        delete changes.partnerAgreementIds;
        const candidate = {
          ...current,
          ...changes,
        } as ImpactPilot & { partnerAgreementIds?: string[] };
        this.validateWindow(candidate);
        await this.access.assertPilot(
          actor,
          ADMIN_IMPACT_CAPABILITIES.managePilots,
          candidate,
        );
        const existingLinks = await tx.impactPilotPartnerAgreement.findMany({
          where: { pilotId },
          select: { agreementId: true },
        });
        const effectiveAgreementIds = agreementIds ?? existingLinks.map((link) => link.agreementId);
        const agreements = await this.loadAgreements(tx, effectiveAgreementIds);
        this.validatePilotState(candidate, agreements);
        const updated = await tx.impactPilot.updateMany({
          where: { id: pilotId, version: input.expectedVersion, analysisLockedAt: null },
          data: { ...changes, version: { increment: 1 } },
        });
        if (updated.count !== 1) throw versionConflict(input.expectedVersion);
        if (agreementIds) {
          await tx.impactPilotPartnerAgreement.deleteMany({ where: { pilotId } });
          await tx.impactPilotPartnerAgreement.createMany({
            data: agreements.map((agreement) => ({
              pilotId,
              agreementId: agreement.id,
              countryCodes: intersection(candidate.countryCodes, agreement.countryCodes),
              startsAt: later(candidate.recruitmentStartsAt, agreement.startsAt),
              endsAt: earlier(candidate.endsAt, agreement.endsAt),
              roleCodes: [
                'pilot_recruitment',
                ...(agreement.canShareAggregateData
                  ? ['aggregate_data']
                  : []),
              ],
            })),
          });
        }
        const pilot = await tx.impactPilot.findUniqueOrThrow({
          where: { id: pilotId },
          include: { cohorts: { include: { memberships: true } } },
        });
        await this.auditAndEmit(
          tx,
          actor,
          pilot,
          'impact_pilot.updated',
          input.reasonCode,
          requestId,
        );
        const body = this.serialize(pilot);
        await this.idempotency.complete(
          {
            recordId: reservation.recordId,
            responseCode: 200,
            responseSnapshot: body,
            resourceType: 'ImpactPilot',
            resourceId: pilot.id,
            resultingVersion: pilot.version,
          },
          tx,
        );
        return { statusCode: 200 as const, body };
        }),
      );
      if (!result) throw databaseUnavailable();
      return result;
    } catch (error) {
      this.translate(error);
    }
  }

  async listCohorts(actor: AdminSessionUser, pilotId: string) {
    const isRecruiter = actor.role === 'commercial';
    const pilot = await this.requirePilot(
      actor,
      pilotId,
      isRecruiter
        ? ADMIN_IMPACT_CAPABILITIES.recruitPilotParticipants
        : ADMIN_IMPACT_CAPABILITIES.viewPilotAggregates,
    );
    const rows = await this.prismaService.execute((prisma) =>
      prisma.impactCohort.findMany({
        where: { pilotId: pilot.id },
        orderBy: [{ code: 'asc' }, { id: 'asc' }],
        include: { _count: { select: { memberships: true } } },
      }),
    );
    if (!rows) throw databaseUnavailable();
    return {
      items: rows.map((row) => ({
        id: row.id,
        pilotId: row.pilotId,
        code: row.code,
        version: row.version,
        label: row.label,
        cohortType: row.cohortType,
        ...(isRecruiter ? {} : { participantCount: row._count.memberships }),
        createdAt: row.createdAt.toISOString(),
      })),
    };
  }

  async createCohort(
    actor: AdminSessionUser,
    pilotId: string,
    input: CreateImpactCohortDto,
    idempotencyKey: string,
    requestId: string,
  ) {
    const pilot = await this.requirePilot(actor, pilotId, ADMIN_IMPACT_CAPABILITIES.managePilots);
    this.assertPilotMutable(pilot);
    assertResearchPayload(input.inclusionRules, 'inclusionRules');
    assertResearchPayload(input.exclusionRules, 'exclusionRules');
    return this.createIdempotently(
      actor,
      `impact-cohort.create:${pilotId}`,
      idempotencyKey,
      input,
      'ImpactCohort',
      async (tx) => {
        const cohort = await tx.impactCohort.create({
          data: {
            pilotId,
            code: input.code.trim().toLowerCase(),
            label: input.label.trim(),
            cohortType: input.cohortType.trim().toLowerCase(),
            inclusionRules: input.inclusionRules as Prisma.InputJsonObject,
            exclusionRules: input.exclusionRules as Prisma.InputJsonObject,
          },
        });
        await this.audit(tx, actor, 'impact_cohort.created', 'ImpactCohort', cohort.id, input.reasonCode, requestId, { pilotId });
        return {
          resourceId: cohort.id,
          resultingVersion: cohort.version,
          body: {
            ...cohort,
            createdAt: cohort.createdAt.toISOString(),
            updatedAt: cohort.updatedAt.toISOString(),
          },
        };
      },
    );
  }

  async enrol(
    actor: AdminSessionUser,
    pilotId: string,
    cohortId: string,
    input: EnrolImpactCohortMemberDto,
    idempotencyKey: string,
    requestId: string,
  ) {
    const pilot = await this.requirePilot(
      actor,
      pilotId,
      ADMIN_IMPACT_CAPABILITIES.recruitPilotParticipants,
      cohortId,
    );
    this.validateEnrollmentWindow(pilot);
    return this.createIdempotently(
      actor,
      `impact-membership.enrol:${cohortId}`,
      idempotencyKey,
      input,
      'ImpactCohortMembership',
      async (tx) => {
        const lockedPilot = await tx.impactPilot.findUnique({
          where: { id: pilotId },
        });
        if (!lockedPilot) throw new NotFoundException('Impact pilot not found.');
        this.validateEnrollmentWindow(lockedPilot);
        const cohort = await tx.impactCohort.findFirst({ where: { id: cohortId, pilotId } });
        if (!cohort) throw new NotFoundException('Impact cohort not found.');
        const consent = await tx.consentReceipt.findFirst({
          where: {
            id: input.consentReceiptId,
            userId: input.userId,
            purpose: 'pilot_research',
            revokedAt: null,
            grantedAt: { lte: new Date() },
          },
          select: {
            id: true,
            grantedAt: true,
            notice: {
              select: {
                purpose: true,
                effectiveAt: true,
                retiredAt: true,
              },
            },
            guardianAuthorization: {
              select: {
                minorUserId: true,
                status: true,
                verifiedAt: true,
                expiresAt: true,
                revokedAt: true,
              },
            },
            user: {
              select: { birthDate: true, countryOfResidence: true },
            },
          },
        });
        this.assertActivePilotConsent(consent, input.userId, new Date());
        if (!consent) {
          throw new BadRequestException('Active pilot_research consent is required.');
        }
        const country = await tx.country.findFirst({
          where: {
            OR: [
              { id: consent.user.countryOfResidence },
              {
                code: {
                  equals: consent.user.countryOfResidence,
                  mode: 'insensitive',
                },
              },
              {
                nameFr: {
                  equals: consent.user.countryOfResidence,
                  mode: 'insensitive',
                },
              },
              {
                nameEn: {
                  equals: consent.user.countryOfResidence,
                  mode: 'insensitive',
                },
              },
            ],
          },
          select: { code: true },
        });
        const canonicalCountry = country?.code.toUpperCase();
        if (
          !canonicalCountry ||
          input.countryCodeLocked.toUpperCase() !== canonicalCountry ||
          !pilot.countryCodes.includes(canonicalCountry)
        ) {
          throw new BadRequestException(
            'Participant country must match the canonical profile and pilot scope.',
          );
        }
        if (input.workspaceId) {
          const workspace = await tx.scholarshipWorkspace.findFirst({
            where: { id: input.workspaceId, userId: input.userId },
            select: { id: true },
          });
          if (!workspace) throw new BadRequestException('Workspace does not belong to participant.');
        }
        const links = await tx.impactPilotPartnerAgreement.findMany({
          where: { pilotId },
          include: { agreement: true },
        });
        this.assertEnrollmentAgreement(
          links,
          pilot,
          canonicalCountry,
          new Date(),
        );
        assertResearchPayload(input.baselineSnapshot, 'baselineSnapshot');
        const membership = await tx.impactCohortMembership.create({
          data: {
            cohortId,
            userId: input.userId,
            workspaceId: input.workspaceId ?? null,
            consentReceiptId: input.consentReceiptId,
            countryCodeLocked: canonicalCountry,
            studyLevelLocked: input.studyLevelLocked?.trim() || null,
            genderCodeLocked: input.genderCodeLocked?.trim() || null,
            deviceClassLocked: input.deviceClassLocked?.trim() || null,
            connectivityLocked: input.connectivityLocked?.trim() || null,
            profileRubricVersion: input.profileRubricVersion.trim(),
            matchingAlgorithmVersion: input.matchingAlgorithmVersion?.trim() || null,
            baselineSnapshot: input.baselineSnapshot as Prisma.InputJsonObject,
          },
        });
        await this.audit(tx, actor, 'impact_cohort.member_enrolled', 'ImpactCohortMembership', membership.id, input.reasonCode, requestId, { pilotId, cohortId });
        return {
          resourceId: membership.id,
          resultingVersion: membership.version,
          body: this.serializeMembership(membership),
        };
      },
    );
  }

  async withdraw(
    actor: AdminSessionUser,
    pilotId: string,
    cohortId: string,
    membershipId: string,
    input: WithdrawImpactCohortMemberDto,
    idempotencyKey: string,
    requestId: string,
  ) {
    await this.requirePilot(actor, pilotId, ADMIN_IMPACT_CAPABILITIES.recruitPilotParticipants, cohortId);
    const now = new Date();
    try {
      const result = await this.prismaService.execute((prisma) =>
        prisma.$transaction(async (tx) => {
        const reservation = await this.idempotency.reserve(
          {
            actorType: 'admin',
            actorId: actor.id,
            operation: `impact-membership.withdraw:${membershipId}`,
            idempotencyKey,
            payload: input,
          },
          tx,
        );
        if (reservation.state === 'replay') {
          return this.replay(
            reservation.responseSnapshot,
            reservation.responseCode,
          );
        }
        if (reservation.state !== 'acquired') throw idempotencyInProgress();
        const current = await tx.impactCohortMembership.findFirst({
          where: { id: membershipId, cohortId, cohort: { pilotId } },
        });
        if (!current) throw new NotFoundException('Pilot membership not found.');
        if (current.version !== input.expectedVersion) throw versionConflict(current.version);
        if (current.status === 'withdrawn') {
          throw versionConflict(current.version);
        }
        const changed = await tx.impactCohortMembership.updateMany({
          where: { id: membershipId, version: input.expectedVersion },
          data: {
            status: 'withdrawn',
            withdrawnAt: now,
            exitReason: input.exitReason.trim(),
            version: { increment: 1 },
          },
        });
        if (changed.count !== 1) throw versionConflict(input.expectedVersion);
        await this.audit(tx, actor, 'impact_cohort.member_withdrawn', 'ImpactCohortMembership', membershipId, input.reasonCode, requestId, { pilotId, cohortId });
        const membership = await tx.impactCohortMembership.findUniqueOrThrow({ where: { id: membershipId } });
        const body = this.serializeMembership(membership);
        await this.idempotency.complete(
          {
            recordId: reservation.recordId,
            responseCode: 200,
            responseSnapshot: body,
            resourceType: 'ImpactCohortMembership',
            resourceId: membership.id,
            resultingVersion: membership.version,
          },
          tx,
        );
        return { statusCode: 200 as const, body };
        }),
      );
      if (!result) throw databaseUnavailable();
      return result;
    } catch (error) {
      this.translate(error);
    }
  }

  async assignExperiment(
    actor: AdminSessionUser,
    pilotId: string,
    cohortId: string,
    membershipId: string,
    input: CreateExperimentAssignmentDto,
    idempotencyKey: string,
    requestId: string,
  ) {
    await this.requirePilot(actor, pilotId, ADMIN_IMPACT_CAPABILITIES.managePilots, cohortId);
    return this.createMembershipChild(actor, pilotId, cohortId, membershipId, 'experiment-assignment', input.reasonCode, idempotencyKey, input, requestId, async (tx) => {
      const assignment = await tx.experimentAssignment.create({
        data: {
          membershipId,
          experimentKey: input.experimentKey.trim(),
          experimentVersion: input.experimentVersion.trim(),
          armCode: input.armCode.trim(),
          assignmentSeedHash: input.assignmentSeedHash,
        },
      });
      return {
        entity: assignment,
        action: 'impact_experiment.assigned',
        body: {
          id: assignment.id,
          membershipId: assignment.membershipId,
          experimentKey: assignment.experimentKey,
          experimentVersion: assignment.experimentVersion,
          armCode: assignment.armCode,
          assignedAt: assignment.assignedAt.toISOString(),
        },
      };
    });
  }

  async assess(
    actor: AdminSessionUser,
    pilotId: string,
    cohortId: string,
    membershipId: string,
    input: CreatePilotAssessmentDto,
    idempotencyKey: string,
    requestId: string,
  ) {
    await this.requirePilot(actor, pilotId, ADMIN_IMPACT_CAPABILITIES.managePilots, cohortId);
    assertResearchPayload(input.answers, 'answers');
    if (input.score !== undefined && !Number.isFinite(input.score)) {
      throw new BadRequestException('Assessment score must be finite.');
    }
    return this.createMembershipChild(actor, pilotId, cohortId, membershipId, 'pilot-assessment', input.reasonCode, idempotencyKey, input, requestId, async (tx) => {
      const assessment = await tx.pilotAssessment.create({
        data: {
          membershipId,
          assessmentType: input.assessmentType.trim(),
          instrumentVersion: input.instrumentVersion.trim(),
          answers: input.answers as Prisma.InputJsonObject,
          score: input.score,
          administeredAt: input.administeredAt ? new Date(input.administeredAt) : undefined,
        },
      });
      return {
        entity: assessment,
        action: 'impact_assessment.recorded',
        body: {
          id: assessment.id,
          membershipId: assessment.membershipId,
          assessmentType: assessment.assessmentType,
          instrumentVersion: assessment.instrumentVersion,
          administeredAt: assessment.administeredAt.toISOString(),
        },
      };
    });
  }

  private async createMembershipChild<T extends { id: string }>(
    actor: AdminSessionUser,
    pilotId: string,
    cohortId: string,
    membershipId: string,
    recordType: string,
    reasonCode: string,
    idempotencyKey: string,
    payload: unknown,
    requestId: string,
    create: (
      tx: Prisma.TransactionClient,
    ) => Promise<{
      entity: T;
      action: string;
      body: Record<string, unknown>;
    }>,
  ) {
    return this.createIdempotently(
      actor,
      `impact-membership-child.create:${membershipId}:${recordType}`,
      idempotencyKey,
      payload,
      'PilotRecord',
      async (tx) => {
        const member = await tx.impactCohortMembership.findFirst({
          where: { id: membershipId, cohortId, cohort: { pilotId }, status: { not: 'withdrawn' } },
          select: { id: true },
        });
        if (!member) throw new NotFoundException('Active pilot membership not found.');
        const created = await create(tx);
        await this.audit(tx, actor, created.action, created.entity.constructor.name || 'PilotRecord', created.entity.id, reasonCode, requestId, { pilotId, cohortId, membershipId });
        return {
          resourceId: created.entity.id,
          body: created.body,
        };
      },
    );
  }

  private async createIdempotently(
    actor: AdminSessionUser,
    operation: string,
    idempotencyKey: string,
    payload: unknown,
    resourceType: string,
    create: (
      tx: Prisma.TransactionClient,
    ) => Promise<{
      resourceId: string;
      resultingVersion?: number;
      body: Record<string, unknown>;
    }>,
  ) {
    try {
      const result = await this.prismaService.execute((prisma) =>
        prisma.$transaction(async (tx) => {
          const reservation = await this.idempotency.reserve(
            {
              actorType: 'admin',
              actorId: actor.id,
              operation,
              idempotencyKey,
              payload,
            },
            tx,
          );
          if (reservation.state === 'replay') {
            return this.replay(
              reservation.responseSnapshot,
              reservation.responseCode,
            );
          }
          if (reservation.state !== 'acquired') throw idempotencyInProgress();
          const created = await create(tx);
          await this.idempotency.complete(
            {
              recordId: reservation.recordId,
              responseCode: 201,
              responseSnapshot: created.body as Prisma.InputJsonObject,
              resourceType,
              resourceId: created.resourceId,
              resultingVersion: created.resultingVersion,
            },
            tx,
          );
          return { statusCode: 201 as const, body: created.body };
        }),
      );
      if (!result) throw databaseUnavailable();
      return result;
    } catch (error) {
      this.translate(error);
    }
  }

  private async requirePilot(
    actor: AdminSessionUser,
    pilotId: string,
    capability: (typeof ADMIN_IMPACT_CAPABILITIES)[keyof typeof ADMIN_IMPACT_CAPABILITIES],
    cohortId?: string,
  ) {
    this.assertDb();
    const pilot = await this.prismaService.execute((prisma) =>
      prisma.impactPilot.findUnique({ where: { id: pilotId } }),
    );
    if (!pilot) throw new NotFoundException('Impact pilot not found.');
    await this.access.assertPilot(actor, capability, pilot, cohortId);
    return pilot;
  }

  private normalizeCreate(input: CreateImpactPilotDto) {
    return {
      code: input.code.trim().toLowerCase(),
      name: input.name.trim(),
      hypothesis: input.hypothesis.trim(),
      countryCodes: countries(input.countryCodes),
      targetPopulation: input.targetPopulation as Prisma.InputJsonObject,
      primaryMetrics: input.primaryMetrics as Prisma.InputJsonObject,
      guardrailMetrics: input.guardrailMetrics as Prisma.InputJsonObject,
      status: input.status,
      recruitmentStartsAt: dateOrNull(input.recruitmentStartsAt),
      startsAt: dateOrNull(input.startsAt),
      endsAt: dateOrNull(input.endsAt),
      protocolVersion: input.protocolVersion.trim(),
      partnerAgreementIds: uniqueStrings(input.partnerAgreementIds ?? []),
    };
  }

  private normalizeChanges(changes: Record<string, unknown>) {
    const keys = Object.keys(changes);
    if (keys.length === 0 || keys.some((key) => !PILOT_CHANGE_FIELDS.has(key))) {
      throw new BadRequestException('Pilot changes contain unsupported fields.');
    }
    const result: Record<string, unknown> & { partnerAgreementIds?: string[] } = { ...changes };
    if ('countryCodes' in result) result.countryCodes = countries(stringArray(result.countryCodes));
    if ('partnerAgreementIds' in result) result.partnerAgreementIds = uniqueStrings(stringArray(result.partnerAgreementIds));
    for (const field of ['recruitmentStartsAt', 'startsAt', 'endsAt'] as const) {
      if (field in result) result[field] = dateOrNull(result[field]);
    }
    for (const field of ['name', 'hypothesis', 'protocolVersion'] as const) {
      if (field in result) {
        if (typeof result[field] !== 'string' || !result[field].trim()) throw new BadRequestException(`${field} is invalid.`);
        result[field] = result[field].trim();
      }
    }
    if ('status' in result && !Object.values(PilotStatus).includes(result.status as PilotStatus)) {
      throw new BadRequestException('Pilot status is invalid.');
    }
    for (const field of ['targetPopulation', 'primaryMetrics', 'guardrailMetrics']) {
      if (!(field in result)) continue;
      const value = result[field];
      if (!value || Array.isArray(value) || typeof value !== 'object') {
        throw new BadRequestException(`${field} must be a JSON object.`);
      }
    }
    return result;
  }

  private validateWindow(pilot: Pick<ImpactPilot, 'status' | 'recruitmentStartsAt' | 'startsAt' | 'endsAt'>) {
    if (pilot.startsAt && pilot.endsAt && pilot.endsAt <= pilot.startsAt) {
      throw new BadRequestException('Pilot end must follow its start.');
    }
    if (pilot.recruitmentStartsAt && pilot.startsAt && pilot.recruitmentStartsAt > pilot.startsAt) {
      throw new BadRequestException('Recruitment must start no later than the pilot.');
    }
    if (
      ([
        PilotStatus.recruiting,
        PilotStatus.active,
        PilotStatus.analysis,
        PilotStatus.completed,
      ] as PilotStatus[]).includes(pilot.status) &&
      (!pilot.recruitmentStartsAt || !pilot.startsAt || !pilot.endsAt)
    ) {
      throw new BadRequestException('Operational pilot statuses require a complete window.');
    }
  }

  private validatePilotState(
    pilot: Pick<ImpactPilot, 'status' | 'countryCodes' | 'recruitmentStartsAt' | 'startsAt' | 'endsAt'>,
    agreements: PilotAgreement[],
  ) {
    if (([PilotStatus.recruiting, PilotStatus.active] as PilotStatus[]).includes(pilot.status)) {
      this.assertRecruitingAgreement(agreements, pilot, new Date());
    }
  }

  private assertRecruitingAgreement(
    agreements: PilotAgreement[],
    pilot: Pick<ImpactPilot, 'countryCodes' | 'recruitmentStartsAt' | 'endsAt'>,
    now: Date,
  ) {
    const validAgreements = agreements.filter(
      (agreement) =>
        agreement.isCurrent &&
        agreement.status === 'active' &&
        agreement.canRecruitPilot &&
        agreement.purposeCodes.includes('pilot_research') &&
        (!agreement.startsAt || agreement.startsAt <= now) &&
        (!agreement.endsAt || agreement.endsAt > now) &&
        (!pilot.recruitmentStartsAt || !agreement.endsAt || agreement.endsAt > pilot.recruitmentStartsAt) &&
        (!pilot.endsAt || !agreement.startsAt || agreement.startsAt < pilot.endsAt),
    );
    const hasCoverageForEveryPilotCountry =
      pilot.countryCodes.length > 0 &&
      pilot.countryCodes.every((countryCode) =>
        validAgreements.some(
          (agreement) =>
            agreement.countryCodes.length === 0 ||
            agreement.countryCodes.includes(countryCode),
        ),
      );
    if (!hasCoverageForEveryPilotCountry) {
      throw new BadRequestException('Pilot requires an active recruitment agreement covering its window and countries.');
    }
  }

  private validateEnrollmentWindow(pilot: ImpactPilot) {
    const now = new Date();
    if (
      pilot.status !== PilotStatus.active ||
      !pilot.startsAt ||
      pilot.startsAt > now ||
      !pilot.endsAt ||
      pilot.endsAt <= now
    ) {
      throw new BadRequestException('Enrollment is allowed only while the pilot is active.');
    }
  }

  private assertActivePilotConsent(
    consent:
      | {
          grantedAt: Date;
          notice: {
            purpose: string;
            effectiveAt: Date;
            retiredAt: Date | null;
          };
          guardianAuthorization: {
            minorUserId: string;
            status: string;
            verifiedAt: Date | null;
            expiresAt: Date | null;
            revokedAt: Date | null;
          } | null;
          user: { birthDate: Date | null; countryOfResidence: string };
        }
      | null,
    userId: string,
    now: Date,
  ) {
    if (
      !consent ||
      consent.notice.purpose !== 'pilot_research' ||
      consent.notice.effectiveAt > consent.grantedAt ||
      consent.notice.effectiveAt > now ||
      consent.notice.retiredAt !== null
    ) {
      throw new BadRequestException(
        'Active pilot_research consent under the current notice is required.',
      );
    }
    if (!consent.user.birthDate) {
      throw new BadRequestException(
        'Participant birth date is required before pilot enrollment.',
      );
    }
    const adultThreshold = new Date(
      Date.UTC(
        now.getUTCFullYear() - 18,
        now.getUTCMonth(),
        now.getUTCDate(),
      ),
    );
    if (consent.user.birthDate <= adultThreshold) return;
    const guardian = consent.guardianAuthorization;
    if (
      !guardian ||
      guardian.minorUserId !== userId ||
      guardian.status !== 'verified' ||
      !guardian.verifiedAt ||
      guardian.verifiedAt > now ||
      guardian.revokedAt !== null ||
      (guardian.expiresAt !== null && guardian.expiresAt <= now)
    ) {
      throw new BadRequestException(
        'A current verified guardian authorization is required for minors.',
      );
    }
  }

  private assertEnrollmentAgreement(
    links: Array<{
      roleCodes: string[];
      countryCodes: string[];
      startsAt: Date | null;
      endsAt: Date | null;
      agreement: PilotAgreement;
    }>,
    pilot: Pick<ImpactPilot, 'countryCodes' | 'recruitmentStartsAt' | 'endsAt'>,
    participantCountry: string,
    now: Date,
  ) {
    const valid = links.some((link) => {
      const agreement = link.agreement;
      return (
        link.roleCodes.includes('pilot_recruitment') &&
        (link.countryCodes.length === 0 ||
          link.countryCodes.includes(participantCountry)) &&
        (!link.startsAt || link.startsAt <= now) &&
        (!link.endsAt || link.endsAt > now) &&
        agreement.isCurrent &&
        agreement.status === 'active' &&
        agreement.canRecruitPilot &&
        agreement.purposeCodes.includes('pilot_research') &&
        (agreement.countryCodes.length === 0 ||
          agreement.countryCodes.includes(participantCountry)) &&
        (!agreement.startsAt || agreement.startsAt <= now) &&
        (!agreement.endsAt || agreement.endsAt > now) &&
        (!pilot.recruitmentStartsAt ||
          !agreement.endsAt ||
          agreement.endsAt > pilot.recruitmentStartsAt) &&
        (!pilot.endsAt ||
          !agreement.startsAt ||
          agreement.startsAt < pilot.endsAt)
      );
    });
    if (!valid) {
      throw new BadRequestException(
        'No active partner link authorizes recruitment in the participant country.',
      );
    }
  }

  private async loadAgreements(tx: Prisma.TransactionClient, ids: string[]) {
    if (ids.length === 0) return [];
    const agreements = await tx.partnerAgreement.findMany({ where: { id: { in: ids } } });
    if (agreements.length !== ids.length) throw new BadRequestException('Partner agreement not found.');
    return agreements;
  }

  private assertPilotMutable(pilot: ImpactPilot) {
    if (([PilotStatus.analysis, PilotStatus.completed, PilotStatus.archived] as PilotStatus[]).includes(pilot.status) || pilot.analysisLockedAt) {
      throw new BadRequestException('Pilot protocol is locked.');
    }
  }

  private serialize(pilot: ImpactPilot & { cohorts?: Array<{ memberships: Array<{ status: string; consentReceipt?: { revokedAt: Date | null } }> }> }) {
    const memberships = pilot.cohorts?.flatMap((cohort) => cohort.memberships) ?? [];
    const active = memberships.filter((member) => member.status !== 'withdrawn');
    const consented = active.filter((member) => !member.consentReceipt?.revokedAt).length;
    return {
      id: pilot.id,
      code: pilot.code,
      version: pilot.version,
      name: pilot.name,
      hypothesis: pilot.hypothesis,
      countryCodes: pilot.countryCodes,
      status: pilot.status,
      protocolVersion: pilot.protocolVersion,
      recruitmentStartsAt: iso(pilot.recruitmentStartsAt),
      startsAt: iso(pilot.startsAt),
      endsAt: iso(pilot.endsAt),
      analysisLockedAt: iso(pilot.analysisLockedAt),
      participantCount: active.length,
      consentCoveragePercent: active.length === 0 ? 0 : Math.round((consented / active.length) * 100),
    };
  }

  private serializeMembership(member: { id: string; cohortId: string; userId: string; workspaceId: string | null; version: number; status: string; enrolledAt: Date; withdrawnAt: Date | null }) {
    return {
      id: member.id,
      cohortId: member.cohortId,
      version: member.version,
      status: member.status,
      enrolledAt: member.enrolledAt.toISOString(),
      withdrawnAt: iso(member.withdrawnAt),
    };
  }

  private async auditAndEmit(tx: Prisma.TransactionClient, actor: AdminSessionUser, pilot: ImpactPilot, action: string, reasonCode: string, requestId: string) {
    await this.audit(tx, actor, action, 'ImpactPilot', pilot.id, reasonCode, requestId, { code: pilot.code, version: pilot.version, status: pilot.status });
    await this.outbox.enqueue({
      eventId: `${action}:${pilot.id}:${pilot.version}`,
      eventName: action,
      aggregateType: 'ImpactPilot',
      aggregateId: pilot.id,
      payload: { pilotId: pilot.id, code: pilot.code, version: pilot.version, status: pilot.status },
    }, tx);
  }

  private async audit(tx: Prisma.TransactionClient, actor: AdminSessionUser, action: string, entityType: string, entityId: string, reasonCode: string, requestId: string, changes: Prisma.InputJsonObject) {
    await tx.adminAuditEvent.create({ data: { actorAdminId: actor.id, action, purposeCode: 'pilot_research', entityType, entityId, requestId, reasonCode, result: 'success', changes } });
  }

  private replay(snapshot: Prisma.JsonValue | null, statusCode: number | null) {
    if (!snapshot || Array.isArray(snapshot) || typeof snapshot !== 'object' || ![200, 201].includes(statusCode ?? 0)) throw databaseUnavailable();
    return { statusCode: statusCode as 200 | 201, body: snapshot };
  }

  private assertDb() { if (!this.prismaService.isEnabled) throw databaseUnavailable(); }

  private translate(error: unknown): never {
    if (error instanceof IdempotencyPayloadMismatchError) throw idempotencyPayloadMismatch();
    if (error instanceof IdempotencyStorageUnavailableError) throw databaseUnavailable();
    if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002') throw new BadRequestException('Pilot code or immutable pilot record already exists.');
    throw error;
  }
}

function stringArray(value: unknown): string[] {
  if (!Array.isArray(value) || value.some((item) => typeof item !== 'string')) throw new BadRequestException('Expected an array of strings.');
  return value;
}
function uniqueStrings(values: string[]): string[] { return Array.from(new Set(values.map((value) => value.trim()).filter(Boolean))); }
function countries(values: string[]): string[] {
  const result = uniqueStrings(values.map((value) => value.toUpperCase()));
  if (result.length === 0) throw new BadRequestException('At least one country code is required.');
  if (result.some((value) => !/^[A-Z]{2}$/.test(value))) throw new BadRequestException('Country codes must be ISO-2.');
  return result;
}
function dateOrNull(value: unknown): Date | null {
  if (value === null || value === undefined || value === '') return null;
  const date = value instanceof Date ? value : new Date(String(value));
  if (Number.isNaN(date.getTime())) throw new BadRequestException('Invalid date.');
  return date;
}
function iso(value: Date | null): string | null { return value?.toISOString() ?? null; }
function intersection(left: string[], right: string[]): string[] { return right.length === 0 ? left : left.filter((value) => right.includes(value)); }
function later(left: Date | null, right: Date | null): Date | null { if (!left) return right; if (!right) return left; return left > right ? left : right; }
function earlier(left: Date | null, right: Date | null): Date | null { if (!left) return right; if (!right) return left; return left < right ? left : right; }
export function assertResearchPayload(
  value: Record<string, unknown>,
  label: string,
): void {
  let encoded: string;
  try {
    encoded = JSON.stringify(value);
  } catch {
    throw new BadRequestException(`${label} must be valid JSON.`);
  }
  if (Buffer.byteLength(encoded, 'utf8') > 32 * 1024) {
    throw new BadRequestException(`${label} exceeds the 32 KB limit.`);
  }
  const forbidden =
    /(^|_)(full_?name|email|phone|whats_?app|address|user_?id|birth_?date|guardian|storage_?key)(_|$)/i;
  const visit = (entry: unknown): void => {
    if (Array.isArray(entry)) {
      entry.forEach(visit);
      return;
    }
    if (!entry || typeof entry !== 'object') return;
    for (const [key, child] of Object.entries(entry)) {
      if (forbidden.test(key)) {
        throw new BadRequestException(
          `${label} contains a prohibited personal-data field.`,
        );
      }
      visit(child);
    }
  };
  visit(value);
}
