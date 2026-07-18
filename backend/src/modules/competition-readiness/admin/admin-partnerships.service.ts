import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import {
  PartnershipAgreementStatus,
  PartnershipAgreementType,
  Prisma,
  type PartnerAgreement,
} from '@prisma/client';

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
} from './admin-impact-access.service';
import type {
  CreatePartnerAgreementDto,
  CreatePartnerAgreementEvidenceDto,
  ListPartnerAgreementsDto,
  UpdatePartnerAgreementDto,
} from './dto/partner-agreement.dto';

const agreementInclude = {
  partner: { select: { nameFr: true, nameEn: true } },
} satisfies Prisma.PartnerAgreementInclude;

type AgreementWithPartner = Prisma.PartnerAgreementGetPayload<{
  include: typeof agreementInclude;
}>;

const MATERIAL_FIELDS = new Set([
  'partnerId',
  'institutionId',
  'status',
  'agreementType',
  'purposeCodes',
  'countryCodes',
  'canRecruitPilot',
  'canVerifySubmission',
  'canVerifyDecision',
  'canShareAggregateData',
  'canPubliclyNamePartner',
  'canUsePartnerLogo',
  'dataProtectionScope',
  'safeguardingScope',
  'signedAt',
  'startsAt',
  'endsAt',
]);

@Injectable()
export class AdminPartnershipsService {
  constructor(
    private readonly prismaService: PrismaService,
    private readonly access: AdminImpactAccessService,
    private readonly idempotency: IdempotencyService,
    private readonly outbox: DomainEventOutboxService,
  ) {}

  async list(actor: AdminSessionUser, query: ListPartnerAgreementsDto) {
    this.assertDb();
    const scope = await this.access.listScope(
      actor,
      ADMIN_IMPACT_CAPABILITIES.managePartnerAgreements,
    );
    const resourceFilters: Prisma.PartnerAgreementWhereInput[] = [];
    for (const resource of scope.resources ?? [{}]) {
      if (resource.pilotIds || resource.cohortIds) continue;
      resourceFilters.push({
        ...(resource.partnerIds ? { partnerId: { in: resource.partnerIds } } : {}),
        ...(resource.agreementIds ? { id: { in: resource.agreementIds } } : {}),
      });
    }
    const rows = await this.prismaService.execute((prisma) =>
      prisma.partnerAgreement.findMany({
        where: {
          isCurrent: true,
          ...(query.status ? { status: { in: query.status } } : {}),
          ...(query.agreementType
            ? { agreementType: { in: query.agreementType } }
            : {}),
          ...(query.partnerId ? { partnerId: query.partnerId } : {}),
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
        include: agreementInclude,
      }),
    );
    if (!rows) throw databaseUnavailable();
    const visibleRows = rows.filter((row) =>
      this.access.agreementCovered(scope, row),
    );
    const hasMore = rows.length > query.limit;
    const items = visibleRows.slice(0, query.limit);
    return {
      items: items.map((row) => this.serialize(row)),
      nextCursor: hasMore ? items.at(-1)?.id ?? null : null,
    };
  }

  async create(
    actor: AdminSessionUser,
    input: CreatePartnerAgreementDto,
    idempotencyKey: string,
    requestId: string,
  ) {
    this.assertDb();
    const data = this.normalizeCreate(input);
    await this.access.assertAgreement(
      actor,
      ADMIN_IMPACT_CAPABILITIES.managePartnerAgreements,
      { id: '__new__', partnerId: data.partnerId, countryCodes: data.countryCodes },
    );
    this.validateAgreement(data);
    try {
      const result = await this.prismaService.execute((prisma) =>
        prisma.$transaction(async (tx) => {
          const reservation = await this.idempotency.reserve(
            {
              actorType: 'admin',
              actorId: actor.id,
              operation: 'partner-agreement.create',
              idempotencyKey,
              payload: input,
            },
            tx,
          );
          if (reservation.state === 'replay') {
            return this.replay(reservation.responseSnapshot, reservation.responseCode);
          }
          if (reservation.state !== 'acquired') throw idempotencyInProgress();
          const partner = await tx.partner.findFirst({
            where: { id: data.partnerId, isActive: true },
            select: { id: true },
          });
          if (!partner) throw new BadRequestException('Partner is not active.');
          if (data.institutionId) {
            const institution = await tx.institution.findUnique({
              where: { id: data.institutionId },
              select: { id: true },
            });
            if (!institution) throw new BadRequestException('Institution not found.');
          }
          const agreement = await tx.partnerAgreement.create({
            data: {
              ...data,
              agreementKey: input.agreementKey.trim().toLowerCase(),
              revisionNumber: 1,
              ownerAdminId: actor.id,
              lastVerifiedAt:
                data.status === PartnershipAgreementStatus.active
                  ? new Date()
                  : null,
            },
            include: agreementInclude,
          });
          const body = this.serialize(agreement);
          await this.auditAndEmit(
            tx,
            actor,
            agreement,
            'partner_agreement.created',
            input.reasonCode,
            requestId,
          );
          await this.idempotency.complete(
            {
              recordId: reservation.recordId,
              responseCode: 201,
              responseSnapshot: body,
              resourceType: 'PartnerAgreement',
              resourceId: agreement.id,
              resultingVersion: agreement.lockVersion,
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

  async revise(
    actor: AdminSessionUser,
    agreementId: string,
    input: UpdatePartnerAgreementDto,
    idempotencyKey: string,
    requestId: string,
  ) {
    this.assertDb();
    const result = await this.prismaService.execute((prisma) =>
      prisma.$transaction(async (tx) => {
        const reservation = await this.idempotency.reserve(
          {
            actorType: 'admin',
            actorId: actor.id,
            operation: `partner-agreement.revise:${agreementId}`,
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
        const current = await tx.partnerAgreement.findFirst({
          where: { id: agreementId, isCurrent: true },
          include: agreementInclude,
        });
        if (!current) throw new NotFoundException('Partner agreement not found.');
        await this.access.assertAgreement(
          actor,
          ADMIN_IMPACT_CAPABILITIES.managePartnerAgreements,
          current,
        );
        if (current.lockVersion !== input.expectedVersion) {
          throw versionConflict(current.lockVersion);
        }
        const changes = this.normalizeChanges(input.changes);
        const candidate = {
          ...this.mutable(current),
          ...changes,
        } as ReturnType<AdminPartnershipsService['normalizeCreate']>;
        this.validateAgreement(candidate);
        await this.access.assertAgreement(
          actor,
          ADMIN_IMPACT_CAPABILITIES.managePartnerAgreements,
          {
            id: current.id,
            partnerId: candidate.partnerId,
            countryCodes: candidate.countryCodes,
          },
        );
        const partner = await tx.partner.findFirst({
          where: { id: candidate.partnerId, isActive: true },
          select: { id: true },
        });
        if (!partner) throw new BadRequestException('Partner is not active.');
        if (candidate.institutionId) {
          const institution = await tx.institution.findUnique({
            where: { id: candidate.institutionId },
            select: { id: true },
          });
          if (!institution) {
            throw new BadRequestException('Institution not found.');
          }
        }
        const closed = await tx.partnerAgreement.updateMany({
          where: {
            id: current.id,
            isCurrent: true,
            lockVersion: input.expectedVersion,
          },
          data: { isCurrent: false },
        });
        if (closed.count !== 1) {
          const latest = await tx.partnerAgreement.findUnique({
            where: { id: agreementId },
            select: { lockVersion: true },
          });
          throw versionConflict(latest?.lockVersion ?? input.expectedVersion);
        }
        const revision = await tx.partnerAgreement.create({
          data: {
            ...candidate,
            agreementKey: current.agreementKey,
            revisionNumber: current.revisionNumber + 1,
            supersedesId: current.id,
            isCurrent: true,
            lockVersion: current.lockVersion + 1,
            ownerAdminId: actor.id,
            lastVerifiedAt:
              candidate.status === PartnershipAgreementStatus.active
                ? new Date()
                : current.lastVerifiedAt,
          },
          include: agreementInclude,
        });
        await this.auditAndEmit(
          tx,
          actor,
          revision,
          'partner_agreement.revised',
          input.reasonCode,
          requestId,
          { supersedesId: current.id },
        );
        const body = this.serialize(revision);
        await this.idempotency.complete(
          {
            recordId: reservation.recordId,
            responseCode: 200,
            responseSnapshot: body,
            resourceType: 'PartnerAgreement',
            resourceId: revision.id,
            resultingVersion: revision.lockVersion,
          },
          tx,
        );
        return { statusCode: 200 as const, body };
      }),
    );
    if (!result) throw databaseUnavailable();
    return result;
  }

  async addEvidence(
    actor: AdminSessionUser,
    agreementId: string,
    input: CreatePartnerAgreementEvidenceDto,
    idempotencyKey: string,
    requestId: string,
  ) {
    this.assertDb();
    if (input.storageKey) {
      throw new BadRequestException(
        'Direct storage keys are disabled until a dedicated agreement upload flow is available.',
      );
    }
    if (!input.externalUrl) {
      throw new BadRequestException('Evidence requires an HTTPS external URL.');
    }
    let evidenceUrl: URL;
    try {
      evidenceUrl = new URL(input.externalUrl);
    } catch {
      throw new BadRequestException('Evidence URL is invalid.');
    }
    if (evidenceUrl.protocol !== 'https:' || evidenceUrl.username || evidenceUrl.password) {
      throw new BadRequestException('Evidence URL must use HTTPS without credentials.');
    }
    try {
      const result = await this.prismaService.execute((prisma) =>
        prisma.$transaction(async (tx) => {
        const reservation = await this.idempotency.reserve(
          {
            actorType: 'admin',
            actorId: actor.id,
            operation: `partner-agreement.evidence.create:${agreementId}`,
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
        const agreement = await tx.partnerAgreement.findFirst({
          where: { id: agreementId, isCurrent: true },
        });
        if (!agreement) throw new NotFoundException('Partner agreement not found.');
        await this.access.assertAgreement(
          actor,
          ADMIN_IMPACT_CAPABILITIES.managePartnerAgreements,
          agreement,
        );
        if (input.verified && agreement.ownerAdminId === actor.id) {
          throw new BadRequestException(
            'Agreement evidence must be verified by a second authorized operator.',
          );
        }
        const evidence = await tx.partnerAgreementEvidence.create({
          data: {
            agreementId,
            kind: input.kind,
            storageKey: input.storageKey?.trim() || null,
            externalUrl: evidenceUrl.toString(),
            note: input.note?.trim() || null,
            verifiedById: input.verified ? actor.id : null,
            verifiedAt: input.verified ? new Date() : null,
          },
        });
        await tx.adminAuditEvent.create({
          data: {
            actorAdminId: actor.id,
            action: 'partner_agreement.evidence_added',
            purposeCode: 'partnership_governance',
            entityType: 'PartnerAgreementEvidence',
            entityId: evidence.id,
            requestId,
            reasonCode: input.reasonCode,
            result: 'success',
            changes: { agreementId, kind: input.kind, verified: Boolean(input.verified) },
          },
        });
        const body = {
          id: evidence.id,
          agreementId: evidence.agreementId,
          kind: evidence.kind,
          externalUrl: evidence.externalUrl,
          note: evidence.note,
          verifiedAt: evidence.verifiedAt?.toISOString() ?? null,
          createdAt: evidence.createdAt.toISOString(),
        };
        await this.idempotency.complete(
          {
            recordId: reservation.recordId,
            responseCode: 201,
            responseSnapshot: body,
            resourceType: 'PartnerAgreementEvidence',
            resourceId: evidence.id,
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

  private normalizeCreate(input: CreatePartnerAgreementDto) {
    return {
      partnerId: input.partnerId.trim(),
      institutionId: input.institutionId?.trim() || null,
      status: input.status,
      agreementType: input.agreementType,
      purposeCodes: cleanCodes(input.purposeCodes),
      countryCodes: countries(input.countryCodes),
      canRecruitPilot: input.canRecruitPilot,
      canVerifySubmission: input.canVerifySubmission,
      canVerifyDecision: input.canVerifyDecision,
      canShareAggregateData: input.canShareAggregateData,
      canPubliclyNamePartner: input.canPubliclyNamePartner,
      canUsePartnerLogo: input.canUsePartnerLogo,
      dataProtectionScope: jsonOrNull(input.dataProtectionScope),
      safeguardingScope: jsonOrNull(input.safeguardingScope),
      signedAt: dateOrNull(input.signedAt),
      startsAt: dateOrNull(input.startsAt),
      endsAt: dateOrNull(input.endsAt),
    };
  }

  private normalizeChanges(changes: Record<string, unknown>) {
    const keys = Object.keys(changes);
    if (keys.length === 0 || keys.some((key) => !MATERIAL_FIELDS.has(key))) {
      throw new BadRequestException('Agreement changes contain unsupported fields.');
    }
    const result: Record<string, unknown> = { ...changes };
    const booleanFields = [
      'canRecruitPilot',
      'canVerifySubmission',
      'canVerifyDecision',
      'canShareAggregateData',
      'canPubliclyNamePartner',
      'canUsePartnerLogo',
    ];
    for (const field of booleanFields) {
      if (field in result && typeof result[field] !== 'boolean') {
        throw new BadRequestException(`${field} must be boolean.`);
      }
    }
    if ('partnerId' in result) {
      if (typeof result.partnerId !== 'string' || !result.partnerId.trim()) {
        throw new BadRequestException('partnerId is invalid.');
      }
      result.partnerId = result.partnerId.trim();
    }
    if (
      'status' in result &&
      !Object.values(PartnershipAgreementStatus).includes(
        result.status as PartnershipAgreementStatus,
      )
    ) {
      throw new BadRequestException('Agreement status is invalid.');
    }
    if (
      'agreementType' in result &&
      !Object.values(PartnershipAgreementType).includes(
        result.agreementType as PartnershipAgreementType,
      )
    ) {
      throw new BadRequestException('Agreement type is invalid.');
    }
    if ('purposeCodes' in result) result.purposeCodes = cleanCodes(stringArray(result.purposeCodes));
    if ('countryCodes' in result) result.countryCodes = countries(stringArray(result.countryCodes));
    for (const field of ['signedAt', 'startsAt', 'endsAt'] as const) {
      if (field in result) result[field] = dateOrNull(result[field]);
    }
    if ('institutionId' in result) {
      if (result.institutionId !== null && typeof result.institutionId !== 'string') {
        throw new BadRequestException('institutionId is invalid.');
      }
      result.institutionId =
        typeof result.institutionId === 'string'
          ? result.institutionId.trim() || null
          : null;
    }
    for (const field of ['dataProtectionScope', 'safeguardingScope']) {
      if (!(field in result)) continue;
      const value = result[field];
      if (value !== null && (!value || Array.isArray(value) || typeof value !== 'object')) {
        throw new BadRequestException(`${field} must be a JSON object or null.`);
      }
      result[field] = value === null ? Prisma.JsonNull : value;
    }
    return result;
  }

  private validateAgreement(input: ReturnType<AdminPartnershipsService['normalizeCreate']>) {
    if (input.endsAt && input.startsAt && input.endsAt <= input.startsAt) {
      throw new BadRequestException('Agreement end must follow its start.');
    }
    if (input.canUsePartnerLogo && !input.canPubliclyNamePartner) {
      throw new BadRequestException('Logo use requires permission to name the partner.');
    }
    if (input.canRecruitPilot) {
      if (!input.purposeCodes.includes('pilot_research') || !input.safeguardingScope) {
        throw new BadRequestException(
          'Pilot recruitment requires pilot_research purpose and safeguarding clauses.',
        );
      }
    }
    if (input.canShareAggregateData) {
      if (!input.purposeCodes.includes('aggregate_impact') || !input.dataProtectionScope) {
        throw new BadRequestException(
          'Aggregate sharing requires aggregate_impact purpose and data-protection clauses.',
        );
      }
    }
    if (input.status === PartnershipAgreementStatus.active) {
      const now = new Date();
      if (!input.signedAt || !input.startsAt || input.startsAt > now) {
        throw new BadRequestException('Active agreement must be signed and already started.');
      }
      if (input.endsAt && input.endsAt <= now) {
        throw new BadRequestException('Expired agreement cannot be activated.');
      }
    }
  }

  private mutable(row: PartnerAgreement) {
    return {
      partnerId: row.partnerId,
      institutionId: row.institutionId,
      status: row.status,
      agreementType: row.agreementType,
      purposeCodes: row.purposeCodes,
      countryCodes: row.countryCodes,
      canRecruitPilot: row.canRecruitPilot,
      canVerifySubmission: row.canVerifySubmission,
      canVerifyDecision: row.canVerifyDecision,
      canShareAggregateData: row.canShareAggregateData,
      canPubliclyNamePartner: row.canPubliclyNamePartner,
      canUsePartnerLogo: row.canUsePartnerLogo,
      dataProtectionScope:
        row.dataProtectionScope === null
          ? Prisma.JsonNull
          : (row.dataProtectionScope as Prisma.InputJsonValue),
      safeguardingScope:
        row.safeguardingScope === null
          ? Prisma.JsonNull
          : (row.safeguardingScope as Prisma.InputJsonValue),
      signedAt: row.signedAt,
      startsAt: row.startsAt,
      endsAt: row.endsAt,
    };
  }

  private serialize(row: AgreementWithPartner) {
    return {
      id: row.id,
      agreementKey: row.agreementKey,
      revisionNumber: row.revisionNumber,
      lockVersion: row.lockVersion,
      partnerId: row.partnerId,
      partnerName: row.partner.nameFr || row.partner.nameEn,
      institutionId: row.institutionId,
      status: row.status,
      agreementType: row.agreementType,
      purposeCodes: row.purposeCodes,
      countryCodes: row.countryCodes,
      canRecruitPilot: row.canRecruitPilot,
      canVerifySubmission: row.canVerifySubmission,
      canVerifyDecision: row.canVerifyDecision,
      canShareAggregateData: row.canShareAggregateData,
      canPubliclyNamePartner: row.canPubliclyNamePartner,
      canUsePartnerLogo: row.canUsePartnerLogo,
      signedAt: iso(row.signedAt),
      startsAt: iso(row.startsAt),
      endsAt: iso(row.endsAt),
      lastVerifiedAt: iso(row.lastVerifiedAt),
    };
  }

  private async auditAndEmit(
    tx: Prisma.TransactionClient,
    actor: AdminSessionUser,
    agreement: PartnerAgreement,
    action: string,
    reasonCode: string,
    requestId: string,
    extra: Prisma.InputJsonObject = {},
  ) {
    await tx.adminAuditEvent.create({
      data: {
        actorAdminId: actor.id,
        action,
        purposeCode: 'partnership_governance',
        entityType: 'PartnerAgreement',
        entityId: agreement.id,
        requestId,
        reasonCode,
        result: 'success',
        changes: {
          agreementKey: agreement.agreementKey,
          revisionNumber: agreement.revisionNumber,
          status: agreement.status,
          ...extra,
        },
      },
    });
    await this.outbox.enqueue(
      {
        eventId: `${action}:${agreement.id}`,
        eventName: action,
        aggregateType: 'PartnerAgreement',
        aggregateId: agreement.id,
        payload: {
          agreementKey: agreement.agreementKey,
          revisionNumber: agreement.revisionNumber,
          status: agreement.status,
        },
      },
      tx,
    );
  }

  private replay(snapshot: Prisma.JsonValue | null, statusCode: number | null) {
    if (!snapshot || Array.isArray(snapshot) || typeof snapshot !== 'object' || ![200, 201].includes(statusCode ?? 0)) {
      throw databaseUnavailable();
    }
    return { statusCode: statusCode as 200 | 201, body: snapshot };
  }

  private assertDb() {
    if (!this.prismaService.isEnabled) throw databaseUnavailable();
  }

  private translate(error: unknown): never {
    if (error instanceof IdempotencyPayloadMismatchError) throw idempotencyPayloadMismatch();
    if (error instanceof IdempotencyStorageUnavailableError) throw databaseUnavailable();
    if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002') {
      throw new BadRequestException('Agreement key or evidence is already registered.');
    }
    throw error;
  }
}

function stringArray(value: unknown): string[] {
  if (!Array.isArray(value) || value.some((entry) => typeof entry !== 'string')) {
    throw new BadRequestException('Expected an array of strings.');
  }
  return value;
}

function cleanCodes(values: string[]): string[] {
  return Array.from(new Set(values.map((value) => value.trim().toLowerCase()))).filter(Boolean);
}

function countries(values: string[]): string[] {
  const result = Array.from(new Set(values.map((value) => value.trim().toUpperCase())));
  if (result.some((value) => !/^[A-Z]{2}$/.test(value))) {
    throw new BadRequestException('Country codes must be ISO-2.');
  }
  return result;
}

function dateOrNull(value: unknown): Date | null {
  if (value === null || value === undefined || value === '') return null;
  const date = value instanceof Date ? value : new Date(String(value));
  if (Number.isNaN(date.getTime())) throw new BadRequestException('Invalid date.');
  return date;
}

function jsonOrNull(value: Record<string, unknown> | null | undefined): Prisma.InputJsonValue | Prisma.NullableJsonNullValueInput | undefined {
  if (value === undefined) return undefined;
  return value === null ? Prisma.JsonNull : (value as Prisma.InputJsonObject);
}

function iso(value: Date | null): string | null {
  return value?.toISOString() ?? null;
}
