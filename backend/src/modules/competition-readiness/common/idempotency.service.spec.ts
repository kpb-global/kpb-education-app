import { PrismaService } from '../../prisma/prisma.service';
import {
  hashCanonicalPayload,
  IdempotencyPayloadMismatchError,
  IdempotencyService,
  IdempotencyStorageUnavailableError,
} from './idempotency.service';

describe('IdempotencyService', () => {
  it('hashes equivalent JSON objects identically regardless of key order', () => {
    expect(hashCanonicalPayload({ b: 2, a: { y: 2, x: 1 } })).toBe(
      hashCanonicalPayload({ a: { x: 1, y: 2 }, b: 2 }),
    );
  });

  it('acquires a new scoped idempotency key', async () => {
    const upsert = jest.fn(async (args: { create: Record<string, unknown> }) =>
      idempotencyRecord({
        ...args.create,
        id: args.create.id as string,
        payloadHash: args.create.payloadHash as string,
        expiresAt: args.create.expiresAt as Date,
      }),
    );
    const service = makeService({ idempotencyRecord: { upsert } });

    const result = await service.reserve({
      actorType: 'student',
      actorId: 'user-1',
      operation: 'create-workspace',
      idempotencyKey: 'key-1',
      payload: { cycleId: 'cycle-1', scholarshipId: 'scholarship-1' },
      now: new Date('2026-07-16T12:00:00.000Z'),
    });

    expect(result.state).toBe('acquired');
    expect(upsert).toHaveBeenCalledWith(
      expect.objectContaining({
        where: {
          actorType_actorId_operation_idempotencyKey: {
            actorType: 'student',
            actorId: 'user-1',
            operation: 'create-workspace',
            idempotencyKey: 'key-1',
          },
        },
      }),
    );
  });

  it('returns the stored response for a completed retry', async () => {
    const payload = { scholarshipId: 'scholarship-1' };
    const service = makeService({
      idempotencyRecord: {
        upsert: jest.fn().mockResolvedValue(
          idempotencyRecord({
            id: 'existing',
            payloadHash: hashCanonicalPayload(payload),
            status: 'completed',
            responseCode: 201,
            responseSnapshot: { id: 'workspace-1' },
            resourceType: 'ScholarshipWorkspace',
            resourceId: 'workspace-1',
            resultingVersion: 1,
          }),
        ),
      },
    });

    const result = await service.reserve({
      actorType: 'student',
      actorId: 'user-1',
      operation: 'create-workspace',
      idempotencyKey: 'key-1',
      payload,
    });

    expect(result).toMatchObject({
      state: 'replay',
      responseCode: 201,
      responseSnapshot: { id: 'workspace-1' },
      resourceId: 'workspace-1',
    });
  });

  it('atomically reclaims a failed key with the same payload hash', async () => {
    const payload = { scholarshipId: 'scholarship-1' };
    const updateMany = jest.fn().mockResolvedValue({ count: 1 });
    const service = makeService({
      idempotencyRecord: {
        upsert: jest.fn().mockResolvedValue(
          idempotencyRecord({
            id: 'failed-record',
            payloadHash: hashCanonicalPayload(payload),
            status: 'failed',
            completedAt: new Date('2026-07-16T11:00:00.000Z'),
          }),
        ),
        updateMany,
      },
    });
    const now = new Date('2026-07-16T12:00:00.000Z');
    const expiresAt = new Date('2026-07-17T12:00:00.000Z');

    await expect(
      service.reserve({
        actorType: 'student',
        actorId: 'user-1',
        operation: 'create-workspace',
        idempotencyKey: 'key-1',
        payload,
        now,
        expiresAt,
      }),
    ).resolves.toEqual({
      state: 'acquired',
      recordId: 'failed-record',
      payloadHash: hashCanonicalPayload(payload),
      expiresAt,
    });
    expect(updateMany).toHaveBeenCalledWith({
      where: {
        id: 'failed-record',
        status: 'failed',
        payloadHash: hashCanonicalPayload(payload),
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
    });
  });

  it('keeps an existing in-progress key blocked for concurrent callers', async () => {
    const payload = { scholarshipId: 'scholarship-1' };
    const updateMany = jest.fn();
    const service = makeService({
      idempotencyRecord: {
        upsert: jest.fn().mockResolvedValue(
          idempotencyRecord({
            id: 'active-record',
            payloadHash: hashCanonicalPayload(payload),
            status: 'in_progress',
          }),
        ),
        updateMany,
      },
    });

    await expect(
      service.reserve({
        actorType: 'student',
        actorId: 'user-1',
        operation: 'create-workspace',
        idempotencyKey: 'key-1',
        payload,
      }),
    ).resolves.toMatchObject({
      state: 'in_progress',
      recordId: 'active-record',
    });
    expect(updateMany).not.toHaveBeenCalled();
  });

  it('rejects reuse of the same scoped key with a divergent payload hash', async () => {
    const service = makeService({
      idempotencyRecord: {
        upsert: jest.fn().mockResolvedValue(
          idempotencyRecord({
            id: 'existing',
            payloadHash: hashCanonicalPayload({ scholarshipId: 'first' }),
          }),
        ),
      },
    });

    await expect(
      service.reserve({
        actorType: 'student',
        actorId: 'user-1',
        operation: 'create-workspace',
        idempotencyKey: 'key-1',
        payload: { scholarshipId: 'second' },
      }),
    ).rejects.toBeInstanceOf(IdempotencyPayloadMismatchError);
  });

  it('persists a completed response snapshot', async () => {
    const update = jest
      .fn()
      .mockResolvedValue(idempotencyRecord({ status: 'completed' }));
    const service = makeService({ idempotencyRecord: { update } });

    await service.complete({
      recordId: 'record-1',
      responseCode: 201,
      responseSnapshot: { id: 'resource-1' },
      resourceType: 'Workspace',
      resourceId: 'resource-1',
      resultingVersion: 1,
      completedAt: new Date('2026-07-16T12:00:00.000Z'),
    });

    expect(update).toHaveBeenCalledWith({
      where: { id: 'record-1' },
      data: expect.objectContaining({
        status: 'completed',
        responseCode: 201,
        responseSnapshot: { id: 'resource-1' },
      }),
    });
  });

  it('fails closed when idempotency persistence is unavailable', async () => {
    const service = new IdempotencyService({
      isEnabled: false,
      execute: jest.fn(),
    } as unknown as PrismaService);

    await expect(
      service.reserve({
        actorType: 'student',
        actorId: 'user-1',
        operation: 'create-workspace',
        idempotencyKey: 'key-1',
        payload: {},
      }),
    ).rejects.toBeInstanceOf(IdempotencyStorageUnavailableError);
  });
});

function makeService(client: object): IdempotencyService {
  return new IdempotencyService({
    isEnabled: true,
    execute: jest.fn(async (operation: (db: object) => Promise<unknown>) =>
      operation(client),
    ),
  } as unknown as PrismaService);
}

function idempotencyRecord(overrides: Record<string, unknown> = {}) {
  return {
    id: 'record-1',
    actorType: 'student',
    actorId: 'user-1',
    operation: 'create-workspace',
    idempotencyKey: 'key-1',
    payloadHash: hashCanonicalPayload({}),
    status: 'in_progress',
    resourceType: null,
    resourceId: null,
    resultingVersion: null,
    responseCode: null,
    responseSnapshot: null,
    createdAt: new Date('2026-07-16T12:00:00.000Z'),
    completedAt: null,
    expiresAt: new Date('2026-07-17T12:00:00.000Z'),
    ...overrides,
  };
}
