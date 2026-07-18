import { PrismaService } from '../../prisma/prisma.service';
import {
  DomainEventConflictError,
  DomainEventOutboxService,
  DomainEventOutboxUnavailableError,
} from './domain-event-outbox.service';

describe('DomainEventOutboxService', () => {
  it('creates an event with the frozen schema version', async () => {
    const upsert = jest.fn(async (args: { create: Record<string, unknown> }) =>
      outboxEvent({
        ...args.create,
        id: args.create.id as string,
        eventId: args.create.eventId as string,
        payload: args.create.payload,
        occurredAt: args.create.occurredAt as Date,
      }),
    );
    const service = makeService({ domainEventOutbox: { upsert } });

    const result = await service.enqueue({
      eventId: 'event-1',
      eventName: 'workspace_started',
      aggregateType: 'ScholarshipWorkspace',
      aggregateId: 'workspace-1',
      payload: { workspaceId: 'workspace-1' },
      occurredAt: new Date('2026-07-16T12:00:00.000Z'),
    });

    expect(result.created).toBe(true);
    expect(upsert).toHaveBeenCalledWith(
      expect.objectContaining({
        create: expect.objectContaining({ schemaVersion: 1 }),
      }),
    );
  });

  it('reuses an existing identical event without mutating it', async () => {
    const service = makeService({
      domainEventOutbox: {
        upsert: jest.fn().mockResolvedValue(
          outboxEvent({
            id: 'existing',
            eventId: 'event-1',
            payload: { workspaceId: 'workspace-1' },
          }),
        ),
      },
    });

    const result = await service.enqueue({
      eventId: 'event-1',
      eventName: 'workspace_started',
      aggregateType: 'ScholarshipWorkspace',
      aggregateId: 'workspace-1',
      payload: { workspaceId: 'workspace-1' },
    });

    expect(result.created).toBe(false);
    expect(result.event.id).toBe('existing');
  });

  it('rejects reuse of an eventId with divergent payload', async () => {
    const service = makeService({
      domainEventOutbox: {
        upsert: jest.fn().mockResolvedValue(
          outboxEvent({
            id: 'existing',
            eventId: 'event-1',
            payload: { workspaceId: 'workspace-1' },
          }),
        ),
      },
    });

    await expect(
      service.enqueue({
        eventId: 'event-1',
        eventName: 'workspace_started',
        aggregateType: 'ScholarshipWorkspace',
        aggregateId: 'workspace-1',
        payload: { workspaceId: 'workspace-2' },
      }),
    ).rejects.toBeInstanceOf(DomainEventConflictError);
  });

  it('clears a worker lease when scheduling a retry', async () => {
    const update = jest.fn().mockResolvedValue(outboxEvent());
    const service = makeService({ domainEventOutbox: { update } });
    const nextAttemptAt = new Date('2026-07-16T12:05:00.000Z');

    await service.scheduleRetry({
      eventId: 'event-1',
      nextAttemptAt,
      errorCode: 'PROVIDER_TIMEOUT',
    });

    expect(update).toHaveBeenCalledWith({
      where: { eventId: 'event-1' },
      data: {
        status: 'pending',
        attemptCount: { increment: 1 },
        nextAttemptAt,
        lockedAt: null,
        lockedBy: null,
        leaseExpiresAt: null,
        lastErrorCode: 'PROVIDER_TIMEOUT',
      },
    });
  });

  it('claims a batch through one atomic PostgreSQL statement', async () => {
    const claimed = [
      outboxEvent({ status: 'processing', lockedBy: 'worker-1' }),
    ];
    const queryRaw = jest.fn().mockResolvedValue(claimed);
    const service = makeService({ domainEventOutbox: {}, $queryRaw: queryRaw });
    const now = new Date('2026-07-16T12:00:00.000Z');

    await expect(
      service.claimBatch({
        workerId: 'worker-1',
        batchSize: 25,
        leaseMs: 120_000,
        now,
      }),
    ).resolves.toEqual(claimed);

    expect(queryRaw).toHaveBeenCalledTimes(1);
    const statement = queryRaw.mock.calls[0][0] as { strings?: string[] };
    expect(statement.strings?.join(' ')).toContain('FOR UPDATE SKIP LOCKED');
    expect(statement.strings?.join(' ')).toContain(
      'UPDATE "DomainEventOutbox"',
    );
  });

  it('only finalizes a claim still owned by the same worker', async () => {
    const updateMany = jest.fn().mockResolvedValue({ count: 1 });
    const service = makeService({ domainEventOutbox: { updateMany } });
    const processedAt = new Date('2026-07-16T12:01:00.000Z');

    await expect(
      service.markClaimProcessed({
        eventId: 'event-1',
        workerId: 'worker-1',
        processedAt,
      }),
    ).resolves.toBe(true);

    expect(updateMany).toHaveBeenCalledWith({
      where: {
        eventId: 'event-1',
        status: 'processing',
        lockedBy: 'worker-1',
      },
      data: {
        status: 'processed',
        processedAt,
        lockedAt: null,
        lockedBy: null,
        leaseExpiresAt: null,
        lastErrorCode: null,
      },
    });
  });

  it('does not let a stale worker release a newer lease', async () => {
    const service = makeService({
      domainEventOutbox: {
        updateMany: jest.fn().mockResolvedValue({ count: 0 }),
      },
    });

    await expect(
      service.scheduleClaimRetry({
        eventId: 'event-1',
        workerId: 'stale-worker',
        nextAttemptAt: new Date('2026-07-16T12:05:00.000Z'),
        errorCode: 'PROVIDER_TIMEOUT',
      }),
    ).resolves.toBe(false);
  });

  it('fails closed when the durable outbox is unavailable', async () => {
    const service = new DomainEventOutboxService({
      isEnabled: false,
      execute: jest.fn(),
    } as unknown as PrismaService);

    await expect(
      service.enqueue({
        eventId: 'event-1',
        eventName: 'workspace_started',
        aggregateType: 'ScholarshipWorkspace',
        aggregateId: 'workspace-1',
        payload: {},
      }),
    ).rejects.toBeInstanceOf(DomainEventOutboxUnavailableError);
  });
});

function makeService(client: object): DomainEventOutboxService {
  return new DomainEventOutboxService({
    isEnabled: true,
    execute: jest.fn(async (operation: (db: object) => Promise<unknown>) =>
      operation(client),
    ),
  } as unknown as PrismaService);
}

function outboxEvent(overrides: Record<string, unknown> = {}) {
  return {
    id: 'outbox-1',
    eventId: 'event-1',
    eventName: 'workspace_started',
    schemaVersion: 1,
    aggregateType: 'ScholarshipWorkspace',
    aggregateId: 'workspace-1',
    payload: {},
    occurredAt: new Date('2026-07-16T12:00:00.000Z'),
    status: 'pending',
    attemptCount: 0,
    nextAttemptAt: new Date('2026-07-16T12:00:00.000Z'),
    lockedAt: null,
    lockedBy: null,
    leaseExpiresAt: null,
    lastErrorCode: null,
    processedAt: null,
    deadLetteredAt: null,
    createdAt: new Date('2026-07-16T12:00:00.000Z'),
    ...overrides,
  };
}
