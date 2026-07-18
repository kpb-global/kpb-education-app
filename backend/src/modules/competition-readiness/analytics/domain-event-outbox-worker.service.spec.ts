import { Readable } from 'node:stream';

import type { DomainEventOutbox } from '@prisma/client';

import { PrismaService } from '../../prisma/prisma.service';
import { StorageService } from '../../storage/storage.service';
import { DomainEventOutboxService } from '../common/domain-event-outbox.service';
import { DomainEventAnalyticsProjectorService } from './domain-event-analytics-projector.service';
import {
  calculateRetryDelayMs,
  DomainEventOutboxWorkerService,
} from './domain-event-outbox-worker.service';

describe('DomainEventOutboxWorkerService', () => {
  beforeEach(() => {
    delete process.env.KPB_OUTBOX_BATCH_SIZE;
    delete process.env.KPB_OUTBOX_LEASE_MS;
    delete process.env.KPB_OUTBOX_MAX_ATTEMPTS;
    delete process.env.KPB_OUTBOX_RETRY_BASE_MS;
    delete process.env.KPB_OUTBOX_RETRY_CAP_MS;
  });

  it('projects and completes an owned claim in one transaction', async () => {
    const event = outboxEvent();
    const harness = makeHarness([event]);
    const now = new Date('2026-07-16T12:00:00.000Z');

    await expect(harness.worker.runOnce(now)).resolves.toBe(1);

    expect(harness.project).toHaveBeenCalledWith(event, harness.tx);
    expect(harness.markClaimProcessed).toHaveBeenCalledWith(
      expect.objectContaining({
        eventId: event.eventId,
        processedAt: now,
        workerId: expect.any(String),
      }),
      harness.tx,
    );
    expect(harness.scheduleClaimRetry).not.toHaveBeenCalled();
  });

  it('deletes and verifies a storage object before completing the event', async () => {
    const storageKey =
      '2026-07-16/123e4567-e89b-12d3-a456-426614174000.pdf';
    const event = outboxEvent({
      eventName: 'artifact.version.deleted',
      payload: { storageKey, workspaceId: 'workspace-1' },
    });
    const harness = makeHarness([event]);

    await harness.worker.runOnce(
      new Date('2026-07-16T12:00:00.000Z'),
    );

    expect(harness.deleteObject).toHaveBeenCalledWith(storageKey);
    expect(harness.getObject).toHaveBeenCalledWith(storageKey);
    expect(harness.markClaimProcessed).toHaveBeenCalledTimes(1);
  });

  it('retries with exponential backoff when the projection fails', async () => {
    const event = outboxEvent({ attemptCount: 2 });
    const harness = makeHarness([event]);
    harness.project.mockRejectedValueOnce(
      Object.assign(new Error('temporary'), { code: 'PROVIDER_TIMEOUT' }),
    );
    const now = new Date('2026-07-16T12:00:00.000Z');

    await harness.worker.runOnce(now);

    expect(harness.scheduleClaimRetry).toHaveBeenCalledWith({
      eventId: event.eventId,
      workerId: expect.any(String),
      errorCode: 'PROVIDER_TIMEOUT',
      nextAttemptAt: new Date(now.getTime() + 20_000),
    });
    expect(harness.deadLetterClaim).not.toHaveBeenCalled();
  });

  it('dead-letters an invalid purge key without retrying it', async () => {
    const event = outboxEvent({
      eventName: 'artifact.version.deleted',
      payload: { storageKey: '../../secrets.env' },
    });
    const harness = makeHarness([event]);
    const now = new Date('2026-07-16T12:00:00.000Z');

    await harness.worker.runOnce(now);

    expect(harness.deadLetterClaim).toHaveBeenCalledWith({
      eventId: event.eventId,
      workerId: expect.any(String),
      errorCode: 'INVALID_STORAGE_PURGE_KEY',
      deadLetteredAt: now,
    });
    expect(harness.deleteObject).not.toHaveBeenCalled();
    expect(harness.scheduleClaimRetry).not.toHaveBeenCalled();
  });

  it('dead-letters a transient failure after the configured attempt limit', async () => {
    const event = outboxEvent({ attemptCount: 7 });
    const harness = makeHarness([event]);
    harness.project.mockRejectedValueOnce(new Error('temporary'));

    await harness.worker.runOnce(
      new Date('2026-07-16T12:00:00.000Z'),
    );

    expect(harness.deadLetterClaim).toHaveBeenCalledWith(
      expect.objectContaining({ errorCode: 'OUTBOX_HANDLER_FAILED' }),
    );
    expect(harness.scheduleClaimRetry).not.toHaveBeenCalled();
  });

  it('does not persist arbitrary error codes that can contain secrets', async () => {
    const event = outboxEvent();
    const harness = makeHarness([event]);
    harness.project.mockRejectedValueOnce(
      Object.assign(new Error('private'), { code: 'SECRETACCESSTOKEN123' }),
    );

    await harness.worker.runOnce(
      new Date('2026-07-16T12:00:00.000Z'),
    );

    expect(harness.scheduleClaimRetry).toHaveBeenCalledWith(
      expect.objectContaining({ errorCode: 'OUTBOX_HANDLER_FAILED' }),
    );
    expect(JSON.stringify(harness.scheduleClaimRetry.mock.calls)).not.toContain(
      'SECRETACCESSTOKEN123',
    );
  });

  it('retries when best-effort deletion leaves the object in storage', async () => {
    const storageKey =
      '2026-07-16/123e4567-e89b-12d3-a456-426614174000.pdf';
    const event = outboxEvent({
      eventName: 'artifact.version.deleted',
      payload: { storageKey },
    });
    const harness = makeHarness([event]);
    const stream = Readable.from(Buffer.from('still present'));
    const destroy = jest.spyOn(stream, 'destroy');
    harness.getObject.mockResolvedValueOnce({
      stream,
      mimeType: 'application/pdf',
    });

    await harness.worker.runOnce(
      new Date('2026-07-16T12:00:00.000Z'),
    );

    expect(destroy).toHaveBeenCalled();
    expect(harness.scheduleClaimRetry).toHaveBeenCalledWith(
      expect.objectContaining({ errorCode: 'STORAGE_PURGE_INCOMPLETE' }),
    );
    expect(harness.markClaimProcessed).not.toHaveBeenCalled();
  });
});

describe('calculateRetryDelayMs', () => {
  it('caps exponential retry delays', () => {
    expect(calculateRetryDelayMs(0, 5_000, 60_000)).toBe(5_000);
    expect(calculateRetryDelayMs(3, 5_000, 60_000)).toBe(40_000);
    expect(calculateRetryDelayMs(20, 5_000, 60_000)).toBe(60_000);
  });
});

function makeHarness(events: DomainEventOutbox[]) {
  const tx = {};
  const claimBatch = jest.fn().mockResolvedValue(events);
  const markClaimProcessed = jest.fn().mockResolvedValue(true);
  const scheduleClaimRetry = jest.fn().mockResolvedValue(true);
  const deadLetterClaim = jest.fn().mockResolvedValue(true);
  const project = jest.fn().mockResolvedValue(undefined);
  const deleteObject = jest.fn().mockResolvedValue(undefined);
  const getObject = jest.fn().mockResolvedValue(null);
  const prisma = {
    isEnabled: true,
    execute: jest.fn(async (operation: (client: object) => Promise<unknown>) =>
      operation({
        $transaction: (callback: (client: object) => Promise<unknown>) =>
          callback(tx),
      }),
    ),
  } as unknown as PrismaService;
  const outbox = {
    claimBatch,
    markClaimProcessed,
    scheduleClaimRetry,
    deadLetterClaim,
  } as unknown as DomainEventOutboxService;
  const projector = { project } as unknown as DomainEventAnalyticsProjectorService;
  const storage = {
    delete: deleteObject,
    getObject,
  } as unknown as StorageService;

  return {
    worker: new DomainEventOutboxWorkerService(
      prisma,
      outbox,
      projector,
      storage,
    ),
    tx,
    claimBatch,
    markClaimProcessed,
    scheduleClaimRetry,
    deadLetterClaim,
    project,
    deleteObject,
    getObject,
  };
}

function outboxEvent(
  overrides: Partial<DomainEventOutbox> = {},
): DomainEventOutbox {
  return {
    id: 'outbox-1',
    eventId: 'event-1',
    eventName: 'workspace.created',
    schemaVersion: 1,
    aggregateType: 'ScholarshipWorkspace',
    aggregateId: 'workspace-1',
    payload: { workspaceId: 'workspace-1' },
    occurredAt: new Date('2026-07-16T12:00:00.000Z'),
    status: 'processing',
    attemptCount: 0,
    nextAttemptAt: new Date('2026-07-16T12:00:00.000Z'),
    lockedAt: new Date('2026-07-16T12:00:00.000Z'),
    lockedBy: 'worker-1',
    leaseExpiresAt: new Date('2026-07-16T12:05:00.000Z'),
    lastErrorCode: null,
    processedAt: null,
    deadLetteredAt: null,
    createdAt: new Date('2026-07-16T12:00:00.000Z'),
    ...overrides,
  };
}
