import { createHash } from 'node:crypto';

import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { Prisma, type ImpactPilot, type ImpactSnapshot } from '@prisma/client';

import type { AdminSessionUser } from '../../auth/auth.service';
import { PrismaService } from '../../prisma/prisma.service';
import {
  databaseUnavailable,
  idempotencyInProgress,
  idempotencyPayloadMismatch,
  versionConflict,
} from '../common/competition-readiness.errors';
import { DomainEventOutboxService } from '../common/domain-event-outbox.service';
import { hashCanonicalPayload, IdempotencyPayloadMismatchError, IdempotencyService, IdempotencyStorageUnavailableError } from '../common/idempotency.service';
import {
  ADMIN_IMPACT_CAPABILITIES,
  AdminImpactAccessService,
} from '../admin/admin-impact-access.service';
import type {
  CreateImpactDataRoomExportDto,
  FreezeImpactSnapshotDto,
  ImpactReportQueryDto,
} from '../admin/dto/impact-pilot.dto';

const MIN_PUBLIC_CELL_SIZE = 20;
const METHODOLOGY_VERSION = 'competition-readiness-impact-v1';
const GENERATOR_VERSION = process.env.KPB_BUILD_SHA?.trim() || 'development';

type Metric = {
  metricKey: string;
  metricVersion: number;
  label: string;
  value: number | null;
  numerator: number | null;
  denominator: number | null;
  sampleSize: number | null;
  coveragePercent: number | null;
  caveat: string | null;
};

const METRIC_DEFINITIONS = [
  { metricKey: 'pilot_participants', metricVersion: 1, label: 'Participants inscrits', source: 'ImpactCohortMembership' },
  { metricKey: 'verified_submissions', metricVersion: 1, label: 'Candidatures vérifiées', source: 'ApplicationSubmission.verificationStatus=verified' },
  { metricKey: 'verified_admissions', metricVersion: 1, label: 'Admissions vérifiées', source: 'ApplicationDecisionRecord.current+verified+admitted' },
  { metricKey: 'verified_funding_awards', metricVersion: 1, label: 'Financements vérifiés', source: 'FundingDecisionRecord.current+verified+full|partial' },
  { metricKey: 'consent_coverage_percent', metricVersion: 1, label: 'Couverture de consentement actif', source: 'ConsentReceipt.pilot_research non révoqué' },
] as const;

@Injectable()
export class ImpactSnapshotService {
  constructor(
    private readonly prismaService: PrismaService,
    private readonly access: AdminImpactAccessService,
    private readonly idempotency: IdempotencyService,
    private readonly outbox: DomainEventOutboxService,
  ) {}

  async listSnapshots(actor: AdminSessionUser, pilotId: string) {
    await this.requirePilot(actor, pilotId, ADMIN_IMPACT_CAPABILITIES.viewPilotAggregates);
    const rows = await this.prismaService.execute((prisma) =>
      prisma.impactSnapshot.findMany({
        where: { pilotId },
        orderBy: { snapshotVersion: 'desc' },
      }),
    );
    if (!rows) throw databaseUnavailable();
    return { items: rows.map((row) => this.serializeSnapshot(row)) };
  }

  async freeze(
    actor: AdminSessionUser,
    pilotId: string,
    input: FreezeImpactSnapshotDto,
    idempotencyKey: string,
    requestId: string,
  ) {
    this.assertDb();
    const periodStart = new Date(input.periodStart);
    const periodEnd = new Date(input.periodEnd);
    const sourceWatermark = new Date(input.sourceWatermark);
    if (periodStart >= periodEnd || sourceWatermark < periodEnd || sourceWatermark > new Date()) {
      throw new BadRequestException('Snapshot period or source watermark is invalid.');
    }
    try {
      const result = await this.prismaService.execute((prisma) =>
        prisma.$transaction(async (tx) => {
          const reservation = await this.idempotency.reserve(
            {
              actorType: 'admin',
              actorId: actor.id,
              operation: `impact-snapshot.freeze:${pilotId}`,
              idempotencyKey,
              payload: input,
            },
            tx,
          );
          if (reservation.state === 'replay') return this.replay(reservation.responseSnapshot, reservation.responseCode);
          if (reservation.state !== 'acquired') throw idempotencyInProgress();

          await tx.$queryRaw(Prisma.sql`SELECT "id" FROM "ImpactPilot" WHERE "id" = ${pilotId} FOR UPDATE`);
          const pilot = await tx.impactPilot.findUnique({ where: { id: pilotId } });
          if (!pilot) throw new NotFoundException('Impact pilot not found.');
          await this.access.assertPilot(actor, ADMIN_IMPACT_CAPABILITIES.freezeImpactSnapshots, pilot);
          if (pilot.version !== input.expectedVersion) throw versionConflict(pilot.version);
          if (!['analysis', 'completed'].includes(pilot.status)) {
            throw new BadRequestException('Snapshots can be frozen only during analysis or after completion.');
          }
          if (
            !pilot.startsAt ||
            !pilot.endsAt ||
            periodStart < pilot.startsAt ||
            periodEnd > pilot.endsAt
          ) {
            throw new BadRequestException(
              'Snapshot period must be contained in the pilot window.',
            );
          }
          const metrics = await this.computeMetrics(tx, pilotId, periodStart, periodEnd, sourceWatermark);
          const latest = await tx.impactSnapshot.findFirst({
            where: { pilotId },
            orderBy: { snapshotVersion: 'desc' },
            select: { id: true, snapshotVersion: true },
          });
          const methodologyHash = hashCanonicalPayload({
            version: METHODOLOGY_VERSION,
            definitions: METRIC_DEFINITIONS,
          });
          const dataHash = hashCanonicalPayload({
            pilotId,
            periodStart,
            periodEnd,
            sourceWatermark,
            metrics,
          });
          const snapshot = await tx.impactSnapshot.create({
            data: {
              pilotId,
              snapshotVersion: (latest?.snapshotVersion ?? 0) + 1,
              correctionOfId: latest?.id ?? null,
              periodStart,
              periodEnd,
              metricDefinitions: METRIC_DEFINITIONS as unknown as Prisma.InputJsonArray,
              metrics: metrics as unknown as Prisma.InputJsonArray,
              sourceWatermark,
              methodologyVersion: METHODOLOGY_VERSION,
              methodologyHash,
              dataHash,
              generatedByVersion: GENERATOR_VERSION,
              generatedByAdminId: actor.id,
              isPublicSafe: metrics.every(
                (metric) => metric.sampleSize === null || metric.sampleSize >= MIN_PUBLIC_CELL_SIZE,
              ),
            },
          });
          if (!pilot.analysisLockedAt) {
            await tx.impactPilot.update({
              where: { id: pilot.id },
              data: { analysisLockedAt: new Date(), version: { increment: 1 } },
            });
          }
          const body = this.serializeSnapshot(snapshot);
          await this.auditAndEmit(tx, actor, snapshot, input.reasonCode, requestId);
          await this.idempotency.complete({
            recordId: reservation.recordId,
            responseCode: 201,
            responseSnapshot: body,
            resourceType: 'ImpactSnapshot',
            resourceId: snapshot.id,
            resultingVersion: snapshot.snapshotVersion,
          }, tx);
          return { statusCode: 201 as const, body };
        }),
      );
      if (!result) throw databaseUnavailable();
      return result;
    } catch (error) {
      this.translate(error);
    }
  }

  async report(actor: AdminSessionUser, query: ImpactReportQueryDto) {
    this.assertDb();
    if (query.periodStart && query.periodEnd && new Date(query.periodStart) >= new Date(query.periodEnd)) {
      throw new BadRequestException('Report period is invalid.');
    }
    if (!query.pilotId) {
      throw new BadRequestException('pilotId is required for a scoped impact report.');
    }
    await this.requirePilot(
      actor,
      query.pilotId,
      ADMIN_IMPACT_CAPABILITIES.viewPilotAggregates,
    );
    const snapshots = await this.prismaService.execute((prisma) =>
      prisma.impactSnapshot.findMany({
        where: {
          pilotId: query.pilotId,
          ...(query.periodStart ? { periodEnd: { gte: new Date(query.periodStart) } } : {}),
          ...(query.periodEnd ? { periodStart: { lte: new Date(query.periodEnd) } } : {}),
        },
        orderBy: [{ sourceWatermark: 'desc' }, { snapshotVersion: 'desc' }],
        take: 1,
      }),
    );
    if (!snapshots) throw databaseUnavailable();
    const snapshot = snapshots[0];
    if (!snapshot) {
      const now = new Date().toISOString();
      return { generatedAt: now, sourceWatermark: now, pilotId: query.pilotId, metrics: [] };
    }
    let metrics = parseMetrics(snapshot.metrics);
    if (query.metricKey?.length) {
      const selected = new Set(query.metricKey);
      metrics = metrics.filter((metric) => selected.has(metric.metricKey));
    }
    if (query.publicSafeOnly) metrics = metrics.map(suppressSmallCell);
    return {
      generatedAt: snapshot.generatedAt.toISOString(),
      sourceWatermark: snapshot.sourceWatermark.toISOString(),
      pilotId: snapshot.pilotId,
      metrics,
    };
  }

  async listDataRoomExports(
    actor: AdminSessionUser,
    query: { pilotId?: string; snapshotId?: string },
  ) {
    this.assertDb();
    if (!query.pilotId) {
      throw new BadRequestException(
        'pilotId is required when listing data-room exports.',
      );
    }
    await this.requirePilot(
      actor,
      query.pilotId,
      ADMIN_IMPACT_CAPABILITIES.viewPilotAggregates,
    );
    const rows = await this.prismaService.execute((prisma) =>
      prisma.impactDataRoomExport.findMany({
        where: {
          pilotId: query.pilotId,
          ...(query.snapshotId ? { snapshotId: query.snapshotId } : {}),
        },
        orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
        take: 100,
      }),
    );
    if (!rows) throw databaseUnavailable();
    return { items: rows.map(serializeExport) };
  }

  async createDataRoomExport(
    actor: AdminSessionUser,
    input: CreateImpactDataRoomExportDto,
    idempotencyKey: string,
    requestId: string,
  ) {
    this.assertDb();
    const expiresAt = input.expiresAt ? new Date(input.expiresAt) : null;
    if (expiresAt && expiresAt <= new Date()) throw new BadRequestException('Export expiry must be in the future.');
    try {
      const result = await this.prismaService.execute((prisma) =>
        prisma.$transaction(async (tx) => {
          const reservation = await this.idempotency.reserve({
            actorType: 'admin', actorId: actor.id, operation: 'impact-data-room.export', idempotencyKey, payload: input,
          }, tx);
          if (reservation.state === 'replay') return this.replay(reservation.responseSnapshot, reservation.responseCode);
          if (reservation.state !== 'acquired') throw idempotencyInProgress();
          const snapshot = await tx.impactSnapshot.findUnique({ where: { id: input.snapshotId } });
          if (!snapshot) throw new NotFoundException('Impact snapshot not found.');
          const pilot = await tx.impactPilot.findUniqueOrThrow({ where: { id: snapshot.pilotId } });
          await this.access.assertPilot(actor, ADMIN_IMPACT_CAPABILITIES.freezeImpactSnapshots, pilot);
          const links = await tx.impactPilotPartnerAgreement.findMany({ where: { pilotId: pilot.id }, include: { agreement: true } });
          this.assertDataSharingAgreement(links, pilot, new Date());
          const metrics = parseMetrics(snapshot.metrics).map(suppressSmallCell);
          const manifest = {
            schemaVersion: 1,
            pilotCode: pilot.code,
            snapshotVersion: snapshot.snapshotVersion,
            periodStart: snapshot.periodStart.toISOString(),
            periodEnd: snapshot.periodEnd.toISOString(),
            sourceWatermark: snapshot.sourceWatermark.toISOString(),
            methodologyVersion: snapshot.methodologyVersion,
            methodologyHash: snapshot.methodologyHash,
            dataHash: snapshot.dataHash,
            suppressionThreshold: MIN_PUBLIC_CELL_SIZE,
            metrics,
          } satisfies Prisma.InputJsonObject;
          assertNoPii(manifest);
          const sha256 = createHash('sha256').update(stableStringify(manifest)).digest('hex');
          const row = await tx.impactDataRoomExport.create({
            data: {
              pilotId: pilot.id,
              snapshotId: snapshot.id,
              requestedByAdminId: actor.id,
              purposeCode: input.purposeCode,
              format: input.format,
              manifest,
              sha256,
              expiresAt,
            },
          });
          const body = serializeExport(row);
          await tx.adminAuditEvent.create({ data: { actorAdminId: actor.id, action: 'impact_data_room.export_created', purposeCode: input.purposeCode, entityType: 'ImpactDataRoomExport', entityId: row.id, requestId, reasonCode: input.reasonCode, result: 'success', changes: { pilotId: pilot.id, snapshotId: snapshot.id, sha256, format: input.format } } });
          await this.outbox.enqueue({ eventId: `impact_data_room.export_created:${row.id}`, eventName: 'impact_data_room.export_created', aggregateType: 'ImpactDataRoomExport', aggregateId: row.id, payload: { pilotId: pilot.id, snapshotId: snapshot.id, sha256 } }, tx);
          await this.idempotency.complete({ recordId: reservation.recordId, responseCode: 201, responseSnapshot: body, resourceType: 'ImpactDataRoomExport', resourceId: row.id }, tx);
          return { statusCode: 201 as const, body };
        }),
      );
      if (!result) throw databaseUnavailable();
      return result;
    } catch (error) {
      this.translate(error);
    }
  }

  private async computeMetrics(tx: Prisma.TransactionClient, pilotId: string, periodStart: Date, periodEnd: Date, sourceWatermark: Date): Promise<Metric[]> {
    const memberships = await tx.impactCohortMembership.findMany({
      where: {
        cohort: { pilotId },
        enrolledAt: { lte: periodEnd },
        status: { not: 'ineligible' },
        OR: [
          { withdrawnAt: null },
          { withdrawnAt: { gte: periodStart } },
        ],
      },
      select: {
        workspaceId: true,
        user: { select: { id: true, birthDate: true } },
        consentReceipt: {
          select: {
            grantedAt: true,
            revokedAt: true,
            purpose: true,
            notice: {
              select: { purpose: true, effectiveAt: true, retiredAt: true },
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
          },
        },
      },
    });
    const adultBirthDateThreshold = new Date(
      Date.UTC(
        sourceWatermark.getUTCFullYear() - 18,
        sourceWatermark.getUTCMonth(),
        sourceWatermark.getUTCDate(),
      ),
    );
    const eligibleMemberships = memberships.filter((row) => {
      const receipt = row.consentReceipt;
      const consentIsCurrent =
        receipt.purpose === 'pilot_research' &&
        receipt.grantedAt <= periodEnd &&
        (!receipt.revokedAt || receipt.revokedAt > sourceWatermark) &&
        receipt.notice.purpose === 'pilot_research' &&
        receipt.notice.effectiveAt <= receipt.grantedAt &&
        receipt.notice.effectiveAt <= sourceWatermark &&
        (!receipt.notice.retiredAt ||
          receipt.notice.retiredAt > sourceWatermark);
      if (!consentIsCurrent || !row.user.birthDate) return false;
      if (row.user.birthDate <= adultBirthDateThreshold) return true;
      const guardian = receipt.guardianAuthorization;
      return Boolean(
        guardian &&
          guardian.minorUserId === row.user.id &&
          guardian.status === 'verified' &&
          guardian.verifiedAt &&
          guardian.verifiedAt <= sourceWatermark &&
          (!guardian.revokedAt || guardian.revokedAt > sourceWatermark) &&
          (!guardian.expiresAt || guardian.expiresAt > sourceWatermark),
      );
    });
    const workspaceIds = Array.from(
      new Set(
        eligibleMemberships
          .map((row) => row.workspaceId)
          .filter((id): id is string => Boolean(id)),
      ),
    );
    const verifiedAt = { not: null as null, lte: sourceWatermark };
    const [submissions, admissions, funding] = workspaceIds.length === 0
      ? [0, 0, 0]
      : await Promise.all([
          tx.applicationSubmission
            .findMany({
              where: {
                workspaceId: { in: workspaceIds },
                submittedAt: { gte: periodStart, lte: periodEnd },
                verificationStatus: 'verified',
                verifiedAt,
              },
              distinct: ['workspaceId'],
              select: { workspaceId: true },
            })
            .then((rows) => rows.length),
          tx.applicationDecisionRecord.count({
            where: {
              workspaceId: { in: workspaceIds },
              receivedAt: { gte: periodStart, lte: periodEnd },
              verificationStatus: 'verified',
              verifiedAt,
              isCurrent: true,
              admissionDecision: 'admitted',
            },
          }),
          tx.fundingDecisionRecord.count({
            where: {
              workspaceId: { in: workspaceIds },
              receivedAt: { gte: periodStart, lte: periodEnd },
              verificationStatus: 'verified',
              verifiedAt,
              isCurrent: true,
              fundingDecision: { in: ['full', 'partial'] },
            },
          }),
        ]);
    const totalMemberships = memberships.length;
    const participantCount = eligibleMemberships.length;
    const coverage =
      totalMemberships === 0
        ? null
        : Math.round((participantCount / totalMemberships) * 10000) / 100;
    return [
      metric('pilot_participants', 'Participants inscrits', participantCount, participantCount, participantCount),
      metric('verified_submissions', 'Candidatures vérifiées', submissions, submissions, participantCount),
      metric('verified_admissions', 'Admissions vérifiées', admissions, admissions, participantCount),
      metric('verified_funding_awards', 'Financements vérifiés', funding, funding, participantCount),
      {
        ...metric(
          'consent_coverage_percent',
          'Couverture de consentement actif',
          coverage,
          participantCount,
          totalMemberships,
        ),
        coveragePercent: coverage,
      },
    ];
  }

  private async requirePilot(actor: AdminSessionUser, pilotId: string, capability: (typeof ADMIN_IMPACT_CAPABILITIES)[keyof typeof ADMIN_IMPACT_CAPABILITIES]) {
    this.assertDb();
    const pilot = await this.prismaService.execute((prisma) => prisma.impactPilot.findUnique({ where: { id: pilotId } }));
    if (!pilot) throw new NotFoundException('Impact pilot not found.');
    await this.access.assertPilot(actor, capability, pilot);
    return pilot;
  }

  private assertDataSharingAgreement(
    links: Array<{
      roleCodes: string[];
      countryCodes: string[];
      startsAt: Date | null;
      endsAt: Date | null;
      agreement: {
        isCurrent: boolean;
        status: string;
        canShareAggregateData: boolean;
        purposeCodes: string[];
        countryCodes: string[];
        startsAt: Date | null;
        endsAt: Date | null;
      };
    }>,
    pilot: Pick<ImpactPilot, 'countryCodes'>,
    now: Date,
  ) {
    const coversCountry = (countryCode: string) =>
      links.some((link) => {
        const agreement = link.agreement;
        return (
          link.roleCodes.includes('aggregate_data') &&
          (link.countryCodes.length === 0 ||
            link.countryCodes.includes(countryCode)) &&
          (!link.startsAt || link.startsAt <= now) &&
          (!link.endsAt || link.endsAt > now) &&
          agreement.isCurrent &&
          agreement.status === 'active' &&
          agreement.canShareAggregateData &&
          agreement.purposeCodes.includes('aggregate_impact') &&
          (agreement.countryCodes.length === 0 ||
            agreement.countryCodes.includes(countryCode)) &&
          (!agreement.startsAt || agreement.startsAt <= now) &&
          (!agreement.endsAt || agreement.endsAt > now)
        );
      });
    if (
      pilot.countryCodes.length === 0 ||
      !pilot.countryCodes.every(coversCountry)
    ) {
      throw new BadRequestException('Data-room export requires an active aggregate-data agreement.');
    }
  }

  private async auditAndEmit(tx: Prisma.TransactionClient, actor: AdminSessionUser, snapshot: ImpactSnapshot, reasonCode: string, requestId: string) {
    await tx.adminAuditEvent.create({ data: { actorAdminId: actor.id, action: 'impact_snapshot.frozen', purposeCode: 'aggregate_impact', entityType: 'ImpactSnapshot', entityId: snapshot.id, requestId, reasonCode, result: 'success', changes: { pilotId: snapshot.pilotId, snapshotVersion: snapshot.snapshotVersion, dataHash: snapshot.dataHash, sourceWatermark: snapshot.sourceWatermark.toISOString() } } });
    await this.outbox.enqueue({ eventId: `impact_snapshot.frozen:${snapshot.id}`, eventName: 'impact_snapshot.frozen', aggregateType: 'ImpactSnapshot', aggregateId: snapshot.id, payload: { pilotId: snapshot.pilotId, snapshotVersion: snapshot.snapshotVersion, dataHash: snapshot.dataHash } }, tx);
  }

  private serializeSnapshot(row: ImpactSnapshot) {
    return { id: row.id, pilotId: row.pilotId, snapshotVersion: row.snapshotVersion, periodStart: row.periodStart.toISOString(), periodEnd: row.periodEnd.toISOString(), sourceWatermark: row.sourceWatermark.toISOString(), isPublicSafe: row.isPublicSafe, generatedAt: row.generatedAt.toISOString() };
  }

  private replay(snapshot: Prisma.JsonValue | null, code: number | null) {
    if (!snapshot || Array.isArray(snapshot) || typeof snapshot !== 'object' || code !== 201) throw databaseUnavailable();
    return { statusCode: 201 as const, body: snapshot };
  }
  private assertDb() { if (!this.prismaService.isEnabled) throw databaseUnavailable(); }
  private translate(error: unknown): never {
    if (error instanceof IdempotencyPayloadMismatchError) throw idempotencyPayloadMismatch();
    if (error instanceof IdempotencyStorageUnavailableError) throw databaseUnavailable();
    if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002') throw new BadRequestException('Immutable snapshot or export already exists.');
    throw error;
  }
}

function metric(metricKey: string, label: string, value: number | null, numerator: number | null, denominator: number | null): Metric {
  return { metricKey, metricVersion: 1, label, value, numerator, denominator, sampleSize: denominator, coveragePercent: denominator && numerator !== null ? Math.round((numerator / denominator) * 10000) / 100 : null, caveat: null };
}
function parseMetrics(value: Prisma.JsonValue): Metric[] {
  if (!Array.isArray(value)) throw new BadRequestException('Snapshot metrics are invalid.');
  return value.filter((entry): entry is Prisma.JsonObject => Boolean(entry) && !Array.isArray(entry) && typeof entry === 'object').map((entry) => ({ metricKey: String(entry.metricKey), metricVersion: Number(entry.metricVersion), label: String(entry.label), value: numberOrNull(entry.value), numerator: numberOrNull(entry.numerator), denominator: numberOrNull(entry.denominator), sampleSize: numberOrNull(entry.sampleSize), coveragePercent: numberOrNull(entry.coveragePercent), caveat: typeof entry.caveat === 'string' ? entry.caveat : null }));
}
export function suppressSmallCell(metric: Metric): Metric {
  if (metric.sampleSize === null || metric.sampleSize >= MIN_PUBLIC_CELL_SIZE) return metric;
  return { ...metric, value: null, numerator: null, denominator: null, coveragePercent: null, caveat: `Suppressed: sample size below ${MIN_PUBLIC_CELL_SIZE}.` };
}
function numberOrNull(value: Prisma.JsonValue | undefined): number | null { return typeof value === 'number' && Number.isFinite(value) ? value : null; }
export function serializeExport(row: { id: string; pilotId: string; snapshotId: string; purposeCode: string; format: string; sha256: string; expiresAt: Date | null; createdAt: Date }) { return { id: row.id, pilotId: row.pilotId, snapshotId: row.snapshotId, purposeCode: row.purposeCode, format: row.format, sha256: row.sha256, available: false, expiresAt: row.expiresAt?.toISOString() ?? null, createdAt: row.createdAt.toISOString() }; }
function assertNoPii(value: unknown) {
  const forbidden = /(^|_)(user|email|phone|name|address|gender|device|connectivity|workspace|consent)(_|$)/i;
  const visit = (current: unknown): void => {
    if (Array.isArray(current)) return current.forEach(visit);
    if (!current || typeof current !== 'object') return;
    for (const [key, entry] of Object.entries(current)) {
      if (forbidden.test(key)) throw new BadRequestException('Data-room manifest contains a prohibited identifier.');
      visit(entry);
    }
  };
  visit(value);
}
function stableStringify(value: Prisma.InputJsonValue): string {
  if (value === null || typeof value !== 'object') return JSON.stringify(value);
  if (Array.isArray(value)) return `[${value.map(stableStringify).join(',')}]`;
  return `{${Object.entries(value).sort(([a], [b]) => a.localeCompare(b)).map(([key, entry]) => `${JSON.stringify(key)}:${stableStringify(entry)}`).join(',')}}`;
}
