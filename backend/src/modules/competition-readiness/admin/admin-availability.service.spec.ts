import { Prisma } from '@prisma/client';

import type { PrismaService } from '../../prisma/prisma.service';
import { CompetitionReadinessHttpException } from '../common/competition-readiness.errors';
import type { DomainEventOutboxService } from '../common/domain-event-outbox.service';
import type { IdempotencyService } from '../common/idempotency.service';
import type { AdminReviewAccessService } from './admin-review-access.service';
import { AdminAvailabilityService } from './admin-availability.service';

describe('AdminAvailabilityService', () => {
  const execute = jest.fn();
  const prisma = { isEnabled: true, execute } as unknown as PrismaService;
  const access = {
    assertReviewFeatureEnabled: jest.fn(),
    assertCanManageCounsellor: jest.fn(),
    manageableCounsellorScope: jest.fn().mockResolvedValue({}),
    selectableCounsellorScope: jest.fn().mockResolvedValue({}),
    isPlatformAdmin: jest.fn().mockReturnValue(true),
    resolveCounsellor: jest.fn(),
  } as unknown as AdminReviewAccessService;
  const reserve = jest.fn().mockResolvedValue({
    state: 'acquired',
    recordId: 'idem-1',
    payloadHash: 'hash',
    expiresAt: new Date('2030-01-01T00:00:00.000Z'),
  });
  const complete = jest.fn();
  const idempotency = { reserve, complete } as unknown as IdempotencyService;
  const enqueue = jest.fn();
  const outbox = { enqueue } as unknown as DomainEventOutboxService;
  const service = new AdminAvailabilityService(
    prisma,
    access,
    idempotency,
    outbox,
  );
  const actor = {
    id: 'admin-1',
    email: 'admin@kpb.education',
    fullName: 'Admin KPB',
    role: 'admin',
  } as const;

  beforeEach(() => {
    jest.clearAllMocks();
    (access.isPlatformAdmin as jest.Mock).mockReturnValue(true);
    (access.manageableCounsellorScope as jest.Mock).mockResolvedValue({});
    (access.selectableCounsellorScope as jest.Mock).mockResolvedValue({});
    reserve.mockResolvedValue({
      state: 'acquired',
      recordId: 'idem-1',
      payloadHash: 'hash',
      expiresAt: new Date('2030-01-01T00:00:00.000Z'),
    });
  });

  it('creates an explicit future slot atomically with idempotency, audit and outbox', async () => {
    const slot = slotFixture();
    const tx = {
      counsellor: {
        findFirst: jest.fn().mockResolvedValue({
          id: 'counsellor-1',
          fullName: 'Awa',
        }),
      },
      counsellorAvailabilitySlot: {
        create: jest.fn().mockResolvedValue(slot),
      },
      adminAuditEvent: { create: jest.fn() },
    };
    execute.mockImplementation(async (operation: (db: unknown) => unknown) =>
      operation({
        $transaction: async (callback: (value: unknown) => unknown) =>
          callback(tx),
      }),
    );

    const result = await service.create(
      actor,
      {
        counsellorId: 'counsellor-1',
        startsAt: slot.startsAt.toISOString(),
        endsAt: slot.endsAt.toISOString(),
        timezone: 'Africa/Niamey',
        capacity: 1,
        reasonCode: 'weekly_availability',
      },
      'availability-1',
      'request-1',
    );

    expect(result).toMatchObject({ statusCode: 201, body: { id: 'slot-1' } });
    expect(tx.adminAuditEvent.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          requestId: 'request-1',
          reasonCode: 'weekly_availability',
        }),
      }),
    );
    expect(enqueue).toHaveBeenCalledWith(
      expect.objectContaining({ eventName: 'counsellor_availability.created' }),
      tx,
    );
    expect(complete).toHaveBeenCalledWith(
      expect.objectContaining({ responseCode: 201 }),
      tx,
    );
  });

  it('maps only the named PostgreSQL exclusion conflict to SLOT_TAKEN', async () => {
    execute.mockImplementation(async () => {
      throw new Prisma.PrismaClientUnknownRequestError(
        'ERROR 23P01: conflicting key violates exclusion constraint "CounsellorAvailabilitySlot_no_active_overlap"',
        { clientVersion: '6.6.0' },
      );
    });
    const startsAt = new Date(Date.now() + 60 * 60 * 1000);
    const endsAt = new Date(startsAt.getTime() + 30 * 60 * 1000);

    await expect(
      service.create(
        actor,
        {
          counsellorId: 'counsellor-1',
          startsAt: startsAt.toISOString(),
          endsAt: endsAt.toISOString(),
          timezone: 'UTC',
          capacity: 1,
          reasonCode: 'overlap_test',
        },
        'availability-overlap',
        'request-overlap',
      ),
    ).rejects.toMatchObject({
      status: 409,
      response: expect.objectContaining({ code: 'SLOT_TAKEN' }),
    });
  });

  it('replays availability creation without creating a second slot', async () => {
    const snapshot = {
      id: 'slot-1',
      counsellorId: 'counsellor-1',
      counsellorName: 'Awa',
      startsAt: new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString(),
      endsAt: new Date(Date.now() + 25 * 60 * 60 * 1000).toISOString(),
      timezone: 'Africa/Niamey',
      capacity: 1,
      bookedCount: 0,
      remainingCapacity: 1,
      status: 'available',
      version: 1,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    };
    reserve.mockResolvedValueOnce({
      state: 'replay',
      recordId: 'idem-1',
      payloadHash: 'hash',
      responseCode: 201,
      responseSnapshot: snapshot,
      resourceType: 'CounsellorAvailabilitySlot',
      resourceId: 'slot-1',
      resultingVersion: 1,
      expiresAt: new Date('2030-01-01T00:00:00.000Z'),
    });
    const tx = { counsellorAvailabilitySlot: { create: jest.fn() } };
    execute.mockImplementation(async (operation: (db: unknown) => unknown) =>
      operation({
        $transaction: async (callback: (value: unknown) => unknown) =>
          callback(tx),
      }),
    );

    await expect(
      service.create(
        actor,
        {
          counsellorId: 'counsellor-1',
          startsAt: snapshot.startsAt,
          endsAt: snapshot.endsAt,
          timezone: snapshot.timezone,
          capacity: 1,
          reasonCode: 'weekly_availability',
        },
        'availability-1',
        'request-1',
      ),
    ).resolves.toEqual({ statusCode: 201, body: snapshot });
    expect(tx.counsellorAvailabilitySlot.create).not.toHaveBeenCalled();
  });

  it('does not leak whether an out-of-scope slot exists during cancellation', async () => {
    execute.mockResolvedValueOnce({ counsellorId: 'counsellor-foreign' });
    (access.assertCanManageCounsellor as jest.Mock).mockRejectedValueOnce(
      new CompetitionReadinessHttpException(
        'FORBIDDEN_SCOPE',
        403,
        'Forbidden.',
      ),
    );

    await expect(
      service.cancel(
        actor,
        'slot-foreign',
        { expectedVersion: 1, reasonCode: 'cancelled' },
        'request-1',
      ),
    ).rejects.toMatchObject({ status: 404 });
    expect(execute).toHaveBeenCalledTimes(1);
  });

  it('refuses to cancel a slot that already has a booking', async () => {
    const current = slotFixture({ bookedCount: 1, capacity: 2 });
    execute
      .mockResolvedValueOnce({ counsellorId: 'counsellor-1' })
      .mockImplementationOnce(
        async (operation: (db: unknown) => unknown) =>
          operation({
            $transaction: async (callback: (value: unknown) => unknown) =>
              callback({
                $queryRaw: jest.fn(),
                counsellorAvailabilitySlot: {
                  findUnique: jest.fn().mockResolvedValue(current),
                  update: jest.fn(),
                },
              }),
          }),
      );

    await expect(
      service.cancel(
        actor,
        'slot-1',
        { expectedVersion: 1, reasonCode: 'cancelled' },
        'request-1',
      ),
    ).rejects.toMatchObject({
      status: 409,
      response: expect.objectContaining({ code: 'SLOT_TAKEN' }),
    });
  });

  it('treats cancellation of an already cancelled slot as idempotent', async () => {
    const cancelled = slotFixture({ status: 'cancelled', version: 2 });
    const tx = {
      $queryRaw: jest.fn(),
      counsellorAvailabilitySlot: {
        findUnique: jest.fn().mockResolvedValue(cancelled),
        update: jest.fn(),
      },
      studyReviewSlotOffer: { updateMany: jest.fn() },
      adminAuditEvent: { create: jest.fn() },
    };
    execute
      .mockResolvedValueOnce({ counsellorId: 'counsellor-1' })
      .mockImplementationOnce(
        async (operation: (db: unknown) => unknown) =>
          operation({
            $transaction: async (callback: (value: unknown) => unknown) =>
              callback(tx),
          }),
      );

    await expect(
      service.cancel(
        actor,
        'slot-1',
        { expectedVersion: 1, reasonCode: 'cancelled_again' },
        'request-2',
      ),
    ).resolves.toMatchObject({ id: 'slot-1', status: 'cancelled', version: 2 });
    expect(tx.counsellorAvailabilitySlot.update).not.toHaveBeenCalled();
    expect(tx.adminAuditEvent.create).not.toHaveBeenCalled();
  });

  it('returns only redacted manageable counselor selector fields', async () => {
    const findMany = jest.fn().mockResolvedValue([
      {
        id: 'counsellor-1',
        fullName: 'Awa',
        countryOfResidence: 'country-ne',
        isActive: true,
      },
    ]);
    execute.mockImplementation(async (operation: (db: unknown) => unknown) =>
      operation({
        counsellor: { findMany },
        country: {
          findMany: jest
            .fn()
            .mockResolvedValue([{ id: 'country-ne', code: 'NE' }]),
        },
      }),
    );

    await expect(
      service.listCounsellors(actor, true, 'review-1'),
    ).resolves.toEqual({
      items: [
        {
          id: 'counsellor-1',
          fullName: 'Awa',
          countryCode: 'NE',
          isActive: true,
        },
      ],
    });
    expect(access.selectableCounsellorScope).toHaveBeenCalledWith(
      actor,
      'review-1',
    );
    expect(JSON.stringify(findMany.mock.results)).not.toContain('email');
  });
});

function slotFixture(overrides: Record<string, unknown> = {}) {
  const startsAt = new Date(Date.now() + 24 * 60 * 60 * 1000);
  const endsAt = new Date(startsAt.getTime() + 30 * 60 * 1000);
  return {
    id: 'slot-1',
    counsellorId: 'counsellor-1',
    startsAt,
    endsAt,
    timezone: 'Africa/Niamey',
    capacity: 1,
    bookedCount: 0,
    status: 'available',
    version: 1,
    createdAt: new Date(),
    updatedAt: new Date(),
    counsellor: { fullName: 'Awa' },
    ...overrides,
  };
}
