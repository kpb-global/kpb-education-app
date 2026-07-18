import { createHash, randomUUID } from 'node:crypto';

import { Injectable } from '@nestjs/common';
import type { IdempotencyRecord, Prisma } from '@prisma/client';

import { PrismaService } from '../../prisma/prisma.service';

const DEFAULT_IDEMPOTENCY_TTL_MS = 24 * 60 * 60 * 1000;

export type IdempotencyPrismaClient = Pick<
  Prisma.TransactionClient,
  'idempotencyRecord'
>;

export interface ReserveIdempotencyInput {
  actorType: string;
  actorId: string;
  operation: string;
  idempotencyKey: string;
  payload: unknown;
  now?: Date;
  expiresAt?: Date;
}

export type IdempotencyReservation =
  | {
      state: 'acquired';
      recordId: string;
      payloadHash: string;
      expiresAt: Date;
    }
  | {
      state: 'in_progress' | 'failed';
      recordId: string;
      payloadHash: string;
      expiresAt: Date;
    }
  | {
      state: 'replay';
      recordId: string;
      payloadHash: string;
      responseCode: number | null;
      responseSnapshot: Prisma.JsonValue | null;
      resourceType: string | null;
      resourceId: string | null;
      resultingVersion: number | null;
      expiresAt: Date;
    };

export interface CompleteIdempotencyInput {
  recordId: string;
  responseCode: number;
  responseSnapshot?: Prisma.InputJsonValue;
  resourceType?: string;
  resourceId?: string;
  resultingVersion?: number;
  completedAt?: Date;
}

/** @internal Boundary adapters must map this to a frozen public API code. */
export class IdempotencyPayloadMismatchError extends Error {
  readonly code = 'IDEMPOTENCY_PAYLOAD_MISMATCH' as const;

  constructor() {
    super('Idempotency key was reused with a different payload.');
    this.name = IdempotencyPayloadMismatchError.name;
  }
}

/** @internal This storage failure is intentionally not an HTTP exception. */
export class IdempotencyStorageUnavailableError extends Error {
  readonly code = 'IDEMPOTENCY_STORAGE_UNAVAILABLE' as const;

  constructor() {
    super('Idempotency storage is unavailable.');
    this.name = IdempotencyStorageUnavailableError.name;
  }
}

class InvalidIdempotencyInputError extends Error {}

function canonicalJson(value: unknown, ancestors = new Set<object>()): string {
  if (value === null) return 'null';
  if (typeof value === 'string' || typeof value === 'boolean') {
    return JSON.stringify(value);
  }
  if (typeof value === 'number') {
    if (!Number.isFinite(value)) {
      throw new InvalidIdempotencyInputError(
        'Idempotency payload must contain finite numbers.',
      );
    }
    return JSON.stringify(Object.is(value, -0) ? 0 : value);
  }
  if (typeof value === 'bigint') {
    return `{"$bigint":${JSON.stringify(value.toString())}}`;
  }
  if (value instanceof Date) {
    if (Number.isNaN(value.getTime())) {
      throw new InvalidIdempotencyInputError(
        'Idempotency payload contains an invalid date.',
      );
    }
    return `{"$date":${JSON.stringify(value.toISOString())}}`;
  }
  if (Array.isArray(value)) {
    if (ancestors.has(value)) {
      throw new InvalidIdempotencyInputError(
        'Idempotency payload must not be circular.',
      );
    }
    const nextAncestors = new Set(ancestors).add(value);
    return `[${value
      .map((entry) =>
        entry === undefined ||
        typeof entry === 'function' ||
        typeof entry === 'symbol'
          ? 'null'
          : canonicalJson(entry, nextAncestors),
      )
      .join(',')}]`;
  }
  if (typeof value === 'object') {
    if (ancestors.has(value)) {
      throw new InvalidIdempotencyInputError(
        'Idempotency payload must not be circular.',
      );
    }
    const prototype = Object.getPrototypeOf(value);
    if (prototype !== Object.prototype && prototype !== null) {
      throw new InvalidIdempotencyInputError(
        'Idempotency payload must contain plain JSON objects.',
      );
    }
    const nextAncestors = new Set(ancestors).add(value);
    const entries = Object.entries(value as Record<string, unknown>)
      .filter(
        ([, entry]) =>
          entry !== undefined &&
          typeof entry !== 'function' &&
          typeof entry !== 'symbol',
      )
      .sort(([left], [right]) => (left < right ? -1 : left > right ? 1 : 0));
    return `{${entries
      .map(
        ([key, entry]) =>
          `${JSON.stringify(key)}:${canonicalJson(entry, nextAncestors)}`,
      )
      .join(',')}}`;
  }
  throw new InvalidIdempotencyInputError(
    'Idempotency payload is not JSON serializable.',
  );
}

export function hashCanonicalPayload(payload: unknown): string {
  return createHash('sha256').update(canonicalJson(payload)).digest('hex');
}

@Injectable()
export class IdempotencyService {
  constructor(private readonly prisma: PrismaService) {}

  async reserve(
    input: ReserveIdempotencyInput,
    client?: IdempotencyPrismaClient,
  ): Promise<IdempotencyReservation> {
    const now = input.now ?? new Date();
    const expiresAt =
      input.expiresAt ?? new Date(now.getTime() + DEFAULT_IDEMPOTENCY_TTL_MS);
    if (expiresAt <= now) {
      throw new InvalidIdempotencyInputError(
        'Idempotency expiry must be in the future.',
      );
    }

    const payloadHash = hashCanonicalPayload(input.payload);
    const candidateId = randomUUID();
    const record = await this.runRequired(client, (db) =>
      db.idempotencyRecord.upsert({
        where: {
          actorType_actorId_operation_idempotencyKey: {
            actorType: input.actorType,
            actorId: input.actorId,
            operation: input.operation,
            idempotencyKey: input.idempotencyKey,
          },
        },
        create: {
          id: candidateId,
          actorType: input.actorType,
          actorId: input.actorId,
          operation: input.operation,
          idempotencyKey: input.idempotencyKey,
          payloadHash,
          expiresAt,
        },
        update: {},
      }),
    );

    if (record.payloadHash !== payloadHash) {
      throw new IdempotencyPayloadMismatchError();
    }

    if (record.id === candidateId) {
      return {
        state: 'acquired',
        recordId: record.id,
        payloadHash,
        expiresAt: record.expiresAt,
      };
    }
    if (record.status === 'completed') {
      return this.replay(record);
    }
    if (record.status === 'failed') {
      const reclaimed = await this.runRequired(client, (db) =>
        db.idempotencyRecord.updateMany({
          where: {
            id: record.id,
            status: 'failed',
            payloadHash,
          },
          data: {
            status: 'in_progress',
            resourceType: null,
            resourceId: null,
            resultingVersion: null,
            responseCode: null,
            completedAt: null,
            expiresAt,
          },
        }),
      );
      if (reclaimed.count === 1) {
        return {
          state: 'acquired',
          recordId: record.id,
          payloadHash,
          expiresAt,
        };
      }

      // Another caller won the compare-and-set and owns the retry attempt.
      return {
        state: 'in_progress',
        recordId: record.id,
        payloadHash,
        expiresAt: record.expiresAt,
      };
    }
    return {
      state: 'in_progress',
      recordId: record.id,
      payloadHash,
      expiresAt: record.expiresAt,
    };
  }

  async complete(
    input: CompleteIdempotencyInput,
    client?: IdempotencyPrismaClient,
  ): Promise<IdempotencyRecord> {
    return this.runRequired(client, (db) =>
      db.idempotencyRecord.update({
        where: { id: input.recordId },
        data: {
          status: 'completed',
          responseCode: input.responseCode,
          ...(input.responseSnapshot !== undefined
            ? { responseSnapshot: input.responseSnapshot }
            : {}),
          resourceType: input.resourceType,
          resourceId: input.resourceId,
          resultingVersion: input.resultingVersion,
          completedAt: input.completedAt ?? new Date(),
        },
      }),
    );
  }

  async markFailed(
    recordId: string,
    client?: IdempotencyPrismaClient,
  ): Promise<IdempotencyRecord> {
    return this.runRequired(client, (db) =>
      db.idempotencyRecord.update({
        where: { id: recordId },
        data: { status: 'failed', completedAt: new Date() },
      }),
    );
  }

  private replay(record: IdempotencyRecord): IdempotencyReservation {
    return {
      state: 'replay',
      recordId: record.id,
      payloadHash: record.payloadHash,
      responseCode: record.responseCode,
      responseSnapshot: record.responseSnapshot,
      resourceType: record.resourceType,
      resourceId: record.resourceId,
      resultingVersion: record.resultingVersion,
      expiresAt: record.expiresAt,
    };
  }

  private async runRequired<T extends object>(
    client: IdempotencyPrismaClient | undefined,
    operation: (db: IdempotencyPrismaClient) => Promise<T>,
  ): Promise<T> {
    if (client) return operation(client);
    if (!this.prisma.isEnabled) throw this.databaseUnavailable();

    const result = await this.prisma.execute((db) => operation(db));
    if (result === null) throw this.databaseUnavailable();
    return result;
  }

  private databaseUnavailable(): IdempotencyStorageUnavailableError {
    return new IdempotencyStorageUnavailableError();
  }
}
