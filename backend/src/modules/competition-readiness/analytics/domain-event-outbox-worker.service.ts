import { randomUUID } from 'node:crypto';
import { hostname } from 'node:os';

import { Injectable, Logger } from '@nestjs/common';
import { Interval } from '@nestjs/schedule';
import type { DomainEventOutbox } from '@prisma/client';

import { PrismaService } from '../../prisma/prisma.service';
import {
  isSafeStorageKey,
  StorageService,
} from '../../storage/storage.service';
import { DomainEventOutboxService } from '../common/domain-event-outbox.service';
import { DomainEventAnalyticsProjectorService } from './domain-event-analytics-projector.service';

const POLL_INTERVAL_MS = 5_000;

export class PermanentOutboxHandlerError extends Error {
  constructor(readonly code: string) {
    super(code);
    this.name = PermanentOutboxHandlerError.name;
  }
}

class OutboxLeaseLostError extends Error {
  constructor() {
    super('OUTBOX_LEASE_LOST');
    this.name = OutboxLeaseLostError.name;
  }
}

class StoragePurgeIncompleteError extends Error {
  readonly code = 'STORAGE_PURGE_INCOMPLETE';

  constructor() {
    super('Storage object still exists after deletion.');
    this.name = StoragePurgeIncompleteError.name;
  }
}

class OutboxWorkerUnavailableError extends Error {
  readonly code = 'OUTBOX_STORAGE_UNAVAILABLE';

  constructor() {
    super('Durable outbox storage is unavailable.');
    this.name = OutboxWorkerUnavailableError.name;
  }
}

/**
 * Singleton Nest worker for the Competition Readiness outbox. Database leases
 * make the singleton guarantee hold per event even when several API replicas
 * run this provider at the same time.
 */
@Injectable()
export class DomainEventOutboxWorkerService {
  private readonly logger = new Logger(DomainEventOutboxWorkerService.name);
  private readonly workerId = `${hostname()}:${process.pid}:${randomUUID()}`;
  private readonly batchSize = readBoundedInteger(
    'KPB_OUTBOX_BATCH_SIZE',
    10,
    1,
    100,
  );
  private readonly leaseMs = readBoundedInteger(
    'KPB_OUTBOX_LEASE_MS',
    5 * 60_000,
    5_000,
    15 * 60_000,
  );
  private readonly maxAttempts = readBoundedInteger(
    'KPB_OUTBOX_MAX_ATTEMPTS',
    8,
    1,
    50,
  );
  private readonly retryBaseMs = readBoundedInteger(
    'KPB_OUTBOX_RETRY_BASE_MS',
    5_000,
    1_000,
    5 * 60_000,
  );
  private readonly retryCapMs = readBoundedInteger(
    'KPB_OUTBOX_RETRY_CAP_MS',
    60 * 60_000,
    5_000,
    24 * 60 * 60_000,
  );
  private polling = false;

  constructor(
    private readonly prisma: PrismaService,
    private readonly outbox: DomainEventOutboxService,
    private readonly projector: DomainEventAnalyticsProjectorService,
    private readonly storage: StorageService,
  ) {}

  @Interval(POLL_INTERVAL_MS)
  async poll(): Promise<void> {
    if (this.polling || !this.prisma.isEnabled) return;
    this.polling = true;
    try {
      await this.runOnce();
    } catch (error) {
      this.logger.error(`Outbox polling failed (${safeErrorCode(error)}).`);
    } finally {
      this.polling = false;
    }
  }

  /** Public for deterministic operational probes and focused unit tests. */
  async runOnce(now = new Date()): Promise<number> {
    const events = await this.outbox.claimBatch({
      workerId: this.workerId,
      batchSize: this.batchSize,
      leaseMs: this.leaseMs,
      now,
    });

    for (const event of events) {
      try {
        await this.processClaim(event, now);
      } catch (error) {
        this.logger.error(
          `Outbox event ${event.eventId} could not be finalized (${safeErrorCode(error)}).`,
        );
      }
    }
    return events.length;
  }

  private async processClaim(
    event: DomainEventOutbox,
    now: Date,
  ): Promise<void> {
    try {
      await this.runIdempotentSideEffect(event);
      await this.projectAndComplete(event, now);
    } catch (error) {
      if (error instanceof OutboxLeaseLostError) {
        this.logger.warn(`Lease lost before finalizing ${event.eventId}.`);
        return;
      }

      const errorCode = safeErrorCode(error);
      const shouldDeadLetter =
        error instanceof PermanentOutboxHandlerError ||
        event.attemptCount + 1 >= this.maxAttempts;

      if (shouldDeadLetter) {
        await this.outbox.deadLetterClaim({
          eventId: event.eventId,
          workerId: this.workerId,
          errorCode,
          deadLetteredAt: now,
        });
        return;
      }

      const retryDelayMs = calculateRetryDelayMs(
        event.attemptCount,
        this.retryBaseMs,
        this.retryCapMs,
      );
      await this.outbox.scheduleClaimRetry({
        eventId: event.eventId,
        workerId: this.workerId,
        errorCode,
        nextAttemptAt: new Date(now.getTime() + retryDelayMs),
      });
    }
  }

  private async runIdempotentSideEffect(
    event: DomainEventOutbox,
  ): Promise<void> {
    if (
      event.eventName !== 'artifact.version.deleted' &&
      event.eventName !== 'outcome_evidence.deleted'
    ) {
      return;
    }

    const payload = event.payload;
    if (!payload || Array.isArray(payload) || typeof payload !== 'object') {
      throw new PermanentOutboxHandlerError('INVALID_STORAGE_PURGE_EVENT');
    }

    const storageKey = (payload as Record<string, unknown>).storageKey;
    if (storageKey === null || storageKey === undefined) return;
    if (typeof storageKey !== 'string' || !isSafeStorageKey(storageKey)) {
      throw new PermanentOutboxHandlerError('INVALID_STORAGE_PURGE_KEY');
    }

    await this.storage.delete(storageKey);
    const remainingObject = await this.storage.getObject(storageKey);
    if (remainingObject) {
      remainingObject.stream.destroy();
      throw new StoragePurgeIncompleteError();
    }
  }

  private async projectAndComplete(
    event: DomainEventOutbox,
    processedAt: Date,
  ): Promise<void> {
    const completed = await this.prisma.execute((prisma) =>
      prisma.$transaction(async (tx) => {
        await this.projector.project(event, tx);
        const ownsLease = await this.outbox.markClaimProcessed(
          {
            eventId: event.eventId,
            workerId: this.workerId,
            processedAt,
          },
          tx,
        );
        if (!ownsLease) throw new OutboxLeaseLostError();
        return true;
      }),
    );
    if (completed === null) {
      throw new OutboxWorkerUnavailableError();
    }
  }
}

export function calculateRetryDelayMs(
  priorAttemptCount: number,
  baseMs: number,
  capMs: number,
): number {
  const exponent = Math.min(30, Math.max(0, Math.floor(priorAttemptCount)));
  return Math.min(capMs, baseMs * 2 ** exponent);
}

function safeErrorCode(error: unknown): string {
  if (error instanceof PermanentOutboxHandlerError) return error.code;
  if (error instanceof StoragePurgeIncompleteError) return error.code;
  if (error instanceof OutboxWorkerUnavailableError) return error.code;
  if (!error || typeof error !== 'object' || !('code' in error)) {
    return 'OUTBOX_HANDLER_FAILED';
  }
  const candidate = (error as { code?: unknown }).code;
  if (typeof candidate !== 'string') return 'OUTBOX_HANDLER_FAILED';
  if (/^P\d{4}$/.test(candidate)) return candidate;
  return [
    'ECONNREFUSED',
    'ECONNRESET',
    'ENETUNREACH',
    'ENOTFOUND',
    'ETIMEDOUT',
    'OUTBOX_EVENT_CONFLICT',
    'OUTBOX_STORAGE_UNAVAILABLE',
    'PROVIDER_TIMEOUT',
  ].includes(candidate)
    ? candidate
    : 'OUTBOX_HANDLER_FAILED';
}

function readBoundedInteger(
  name: string,
  fallback: number,
  minimum: number,
  maximum: number,
): number {
  const parsed = Number.parseInt(process.env[name] ?? '', 10);
  if (!Number.isFinite(parsed)) return fallback;
  return Math.min(maximum, Math.max(minimum, parsed));
}
