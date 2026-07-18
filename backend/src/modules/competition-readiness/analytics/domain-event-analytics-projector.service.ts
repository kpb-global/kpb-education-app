import { Injectable } from '@nestjs/common';
import type { DomainEventOutbox, Prisma } from '@prisma/client';

export type AnalyticsProjectionPrismaClient = Pick<
  Prisma.TransactionClient,
  'analyticsEvent'
>;

const STRING_DIMENSIONS = [
  'pilotId',
  'cohortId',
  'countryCodeLocked',
  'scholarshipId',
  'cycleId',
  'workspaceId',
  'traceId',
] as const;

const SAFE_PROPERTY_KEYS = [
  'status',
  'version',
  'versionNumber',
  'requestNumber',
  'outcomeType',
  'reasonProvided',
  'capacity',
  'kind',
  'reconciled',
  'retentionExpired',
] as const;

/**
 * Projects operational outbox events into the analytics ledger. Only an
 * explicit allow-list is copied from payloads: user IDs, file names, storage
 * keys and free text must never enter AnalyticsEvent.properties.
 */
@Injectable()
export class DomainEventAnalyticsProjectorService {
  async project(
    event: DomainEventOutbox,
    client: AnalyticsProjectionPrismaClient,
  ): Promise<void> {
    const payload = asObject(event.payload);
    const dimensions = extractStringDimensions(payload);
    const properties = extractSafeProperties(payload, event.aggregateType);

    await client.analyticsEvent.upsert({
      where: { eventId: event.eventId },
      create: {
        eventId: event.eventId,
        idempotencyKey: `outbox:${event.eventId}:analytics-v1`,
        eventName: event.eventName,
        schemaVersion: event.schemaVersion,
        occurredAt: event.occurredAt,
        source: 'competition_readiness_outbox',
        actorKey: null,
        actorKeyVersion: null,
        pilotId: dimensions.pilotId,
        cohortId: dimensions.cohortId,
        countryCodeLocked: dimensions.countryCodeLocked,
        scholarshipId: dimensions.scholarshipId,
        cycleId: dimensions.cycleId,
        workspaceId:
          dimensions.workspaceId ??
          (event.aggregateType === 'ScholarshipWorkspace'
            ? event.aggregateId
            : null),
        properties,
        traceId: dimensions.traceId,
        isTest: payload.isTest === true,
      },
      update: {},
    });
  }
}

function asObject(value: Prisma.JsonValue): Record<string, Prisma.JsonValue> {
  if (!value || Array.isArray(value) || typeof value !== 'object') return {};
  return value as Record<string, Prisma.JsonValue>;
}

function extractStringDimensions(
  payload: Record<string, Prisma.JsonValue>,
): Partial<Record<(typeof STRING_DIMENSIONS)[number], string>> {
  const result: Partial<Record<(typeof STRING_DIMENSIONS)[number], string>> = {};
  for (const key of STRING_DIMENSIONS) {
    const value = payload[key];
    if (typeof value === 'string' && value.length > 0 && value.length <= 255) {
      result[key] = value;
    }
  }
  return result;
}

function extractSafeProperties(
  payload: Record<string, Prisma.JsonValue>,
  aggregateType: string,
): Prisma.InputJsonObject {
  const result: Record<string, Prisma.InputJsonValue> = { aggregateType };
  for (const key of SAFE_PROPERTY_KEYS) {
    const value = payload[key];
    if (
      typeof value === 'boolean' ||
      (typeof value === 'number' && Number.isFinite(value)) ||
      (typeof value === 'string' && value.length <= 100)
    ) {
      result[key] = value;
    }
  }
  return result;
}
