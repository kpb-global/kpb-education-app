import type { PrismaService } from '../../prisma/prisma.service';
import type { AdminReviewAccessService } from '../admin/admin-review-access.service';
import type { AdminReviewOperationsService } from '../admin/admin-review-operations.service';
import type { DomainEventOutboxService } from '../common/domain-event-outbox.service';
import type { FeatureAccessService } from '../common/feature-access.service';
import type { IdempotencyService } from '../common/idempotency.service';
import { StudyReviewSchedulingService } from './study-review-scheduling.service';

describe('StudyReviewSchedulingService', () => {
  const previousFlag = process.env.KPB_STUDY_REVIEW_ENABLED;
  const execute = jest.fn();
  const prisma = { isEnabled: true, execute } as unknown as PrismaService;
  const evaluate = jest.fn().mockResolvedValue({ allowed: true });
  const featureAccess = { evaluate } as unknown as FeatureAccessService;
  const reserve = jest.fn().mockResolvedValue(acquiredReservation());
  const complete = jest.fn();
  const idempotency = { reserve, complete } as unknown as IdempotencyService;
  const enqueue = jest.fn();
  const outbox = { enqueue } as unknown as DomainEventOutboxService;
  const adminAccess = {
    assertReviewFeatureEnabled: jest.fn(),
    assertCanReadDetail: jest.fn(),
    assertCanOfferSlots: jest.fn(),
    resolveCounsellor: jest.fn(),
  } as unknown as AdminReviewAccessService;
  const getDetail = jest.fn().mockResolvedValue({ id: 'review-1' });
  const adminReviews = { getDetail } as unknown as AdminReviewOperationsService;
  const service = new StudyReviewSchedulingService(
    prisma,
    featureAccess,
    idempotency,
    outbox,
    adminAccess,
    adminReviews,
  );
  const actor = {
    id: 'admin-1',
    email: 'admin@kpb.education',
    fullName: 'Admin KPB',
    role: 'admin',
  } as const;

  beforeEach(() => {
    jest.clearAllMocks();
    process.env.KPB_STUDY_REVIEW_ENABLED = 'true';
    evaluate.mockResolvedValue({ allowed: true });
    reserve.mockResolvedValue(acquiredReservation());
    getDetail.mockResolvedValue({ id: 'review-1', status: 'call_offered' });
  });

  afterAll(() => {
    if (previousFlag === undefined) delete process.env.KPB_STUDY_REVIEW_ENABLED;
    else process.env.KPB_STUDY_REVIEW_ENABLED = previousFlag;
  });

  it('offers only future slots owned by the assigned counselor and transitions atomically', async () => {
    const review = reviewFixture();
    const slot = slotFixture();
    const tx = offerTransaction(review, slot);
    execute.mockImplementation(async (operation: (db: unknown) => unknown) =>
      operation({
        studyReviewRequest: { findUnique: jest.fn().mockResolvedValue(review) },
        $transaction: async (callback: (value: unknown) => unknown) =>
          callback(tx),
      }),
    );

    const result = await service.offerSlots(
      actor,
      'review-1',
      {
        expectedVersion: 3,
        slotIds: ['slot-1'],
        expiresAt: new Date(Date.now() + 60 * 60 * 1000).toISOString(),
        reasonCode: 'review_call_required',
      },
      'offer-key-1',
      'request-1',
    );

    expect(result).toEqual({
      statusCode: 201,
      body: { id: 'review-1', status: 'call_offered' },
    });
    expect(tx.studyReviewRequest.updateMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          id: 'review-1',
          version: 3,
          status: 'triaged',
          assignedCounsellorId: 'counsellor-1',
        }),
        data: { status: 'call_offered', version: { increment: 1 } },
      }),
    );
    expect(enqueue).toHaveBeenCalledWith(
      expect.objectContaining({
        eventName: 'study_review.slot_offered',
        payload: expect.objectContaining({
          userId: 'student-1',
          workspaceId: 'workspace-1',
        }),
      }),
      tx,
    );
  });

  it('re-offers after every previous offer expired without leaving call_offered', async () => {
    const review = reviewFixture({ status: 'call_offered', version: 4 });
    const slot = slotFixture();
    const tx = offerTransaction(review, slot);
    tx.studyReviewSlotOffer.count.mockResolvedValue(0);
    execute.mockImplementation(async (operation: (db: unknown) => unknown) =>
      operation({
        studyReviewRequest: { findUnique: jest.fn().mockResolvedValue(review) },
        $transaction: async (callback: (value: unknown) => unknown) =>
          callback(tx),
      }),
    );

    await service.offerSlots(
      actor,
      'review-1',
      {
        expectedVersion: 4,
        slotIds: ['slot-1'],
        expiresAt: new Date(Date.now() + 60 * 60 * 1000).toISOString(),
        reasonCode: 'expired_slots_replaced',
      },
      'offer-key-2',
      'request-2',
    );

    expect(tx.studyReviewSlotOffer.updateMany).toHaveBeenCalledWith(
      expect.objectContaining({ data: { status: 'expired', selectedAt: null } }),
    );
    expect(tx.studyReviewRequest.updateMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({ status: 'call_offered', version: 4 }),
        data: { status: 'call_offered', version: { increment: 1 } },
      }),
    );
  });

  it('does not replace a still-active offer', async () => {
    const review = reviewFixture({ status: 'call_offered', version: 4 });
    const tx = offerTransaction(review, slotFixture());
    tx.studyReviewSlotOffer.count.mockResolvedValue(1);
    execute.mockImplementation(async (operation: (db: unknown) => unknown) =>
      operation({
        studyReviewRequest: { findUnique: jest.fn().mockResolvedValue(review) },
        $transaction: async (callback: (value: unknown) => unknown) =>
          callback(tx),
      }),
    );

    await expect(
      service.offerSlots(
        actor,
        'review-1',
        {
          expectedVersion: 4,
          slotIds: ['slot-1'],
          expiresAt: new Date(Date.now() + 60 * 60 * 1000).toISOString(),
          reasonCode: 'premature_replacement',
        },
        'offer-key-3',
        'request-3',
      ),
    ).rejects.toMatchObject({ status: 409 });
    expect(tx.studyReviewSlotOffer.upsert).not.toHaveBeenCalled();
  });

  it('offers replacement slots without clearing an existing scheduled review', async () => {
    const review = reviewFixture({ status: 'scheduled', version: 5 });
    const tx = offerTransaction(review, slotFixture({ id: 'slot-2' }));
    execute.mockImplementation(async (operation: (db: unknown) => unknown) =>
      operation({
        studyReviewRequest: { findUnique: jest.fn().mockResolvedValue(review) },
        $transaction: async (callback: (value: unknown) => unknown) =>
          callback(tx),
      }),
    );

    await service.offerSlots(
      actor,
      'review-1',
      {
        expectedVersion: 5,
        slotIds: ['slot-2'],
        expiresAt: new Date(Date.now() + 60 * 60 * 1000).toISOString(),
        reasonCode: 'reschedule_requested',
      },
      'offer-key-reschedule',
      'request-offer-reschedule',
    );

    expect(tx.studyReviewRequest.updateMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({ status: 'scheduled', version: 5 }),
        data: { status: 'scheduled', version: { increment: 1 } },
      }),
    );
  });

  it('never re-offers a slot offer already consumed by an appointment', async () => {
    const review = reviewFixture({ status: 'scheduled', version: 5 });
    const tx = offerTransaction(review, slotFixture());
    tx.appointment.count.mockResolvedValue(1);
    execute.mockImplementation(async (operation: (db: unknown) => unknown) =>
      operation({
        studyReviewRequest: { findUnique: jest.fn().mockResolvedValue(review) },
        $transaction: async (callback: (value: unknown) => unknown) =>
          callback(tx),
      }),
    );

    await expect(
      service.offerSlots(
        actor,
        'review-1',
        {
          expectedVersion: 5,
          slotIds: ['slot-1'],
          expiresAt: new Date(Date.now() + 60 * 60 * 1000).toISOString(),
          reasonCode: 'reschedule_requested',
        },
        'offer-key-consumed',
        'request-offer-consumed',
      ),
    ).rejects.toMatchObject({
      status: 409,
      response: expect.objectContaining({ code: 'SLOT_TAKEN' }),
    });
    expect(tx.studyReviewSlotOffer.upsert).not.toHaveBeenCalled();
  });

  it('rejects a slot that is not owned by the assigned counselor', async () => {
    const review = reviewFixture();
    const tx = offerTransaction(
      review,
      slotFixture({ counsellorId: 'counsellor-foreign' }),
    );
    execute.mockImplementation(async (operation: (db: unknown) => unknown) =>
      operation({
        studyReviewRequest: { findUnique: jest.fn().mockResolvedValue(review) },
        $transaction: async (callback: (value: unknown) => unknown) =>
          callback(tx),
      }),
    );

    await expect(
      service.offerSlots(
        actor,
        'review-1',
        {
          expectedVersion: 3,
          slotIds: ['slot-1'],
          expiresAt: new Date(Date.now() + 60 * 60 * 1000).toISOString(),
          reasonCode: 'invalid_assignment',
        },
        'offer-key-foreign',
        'request-foreign',
      ),
    ).rejects.toMatchObject({
      status: 409,
      response: expect.objectContaining({ code: 'SLOT_TAKEN' }),
    });
    expect(tx.studyReviewSlotOffer.upsert).not.toHaveBeenCalled();
  });

  it('returns only nonexpired offered capacity for the owning student', async () => {
    const now = Date.now();
    const findFirst = jest.fn().mockResolvedValue({
      id: 'review-1',
      version: 4,
      status: 'call_offered',
      timezone: 'Africa/Niamey',
      assignedCounsellorId: 'counsellor-1',
      slotOffers: [
        offerFixture({
          expiresAt: new Date(now + 60 * 60 * 1000),
          slot: slotFixture(),
        }),
        offerFixture({
          id: 'offer-full',
          expiresAt: new Date(now + 60 * 60 * 1000),
          slot: slotFixture({ id: 'slot-full', bookedCount: 1 }),
        }),
      ],
    });
    execute.mockImplementation(async (operation: (db: unknown) => unknown) =>
      operation({ studyReviewRequest: { findFirst } }),
    );

    const result = await service.listOfferedSlots('student-1', 'review-1');

    expect(result).toMatchObject({
      reviewRequestId: 'review-1',
      reviewRequestVersion: 4,
      timezone: 'Africa/Niamey',
      offers: [{ slotOfferId: 'offer-1', slotId: 'slot-1' }],
    });
    expect(findFirst).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { id: 'review-1', workspace: { userId: 'student-1' } },
      }),
    );
  });

  it('books the exact offered slot using one capacity CAS and the canonical slot timezone', async () => {
    const review = reviewFixture({ status: 'call_offered', version: 4 });
    const offer = offerFixture({ slot: slotFixture() });
    const appointment = appointmentFixture();
    const tx = bookingTransaction(review, offer, appointment);
    execute.mockImplementation(async (operation: (db: unknown) => unknown) =>
      operation({
        $transaction: async (callback: (value: unknown) => unknown) =>
          callback(tx),
      }),
    );

    const result = await service.book(
      'student-1',
      'review-1',
      {
        expectedVersion: 4,
        slotOfferId: 'offer-1',
        bookingKey: 'booking-1',
        timezone: 'Africa/Niamey',
      },
      'appointment-key-1',
      'request-1',
    );

    expect(result).toMatchObject({
      statusCode: 201,
      body: {
        appointment: {
          id: 'appointment-1',
          timezone: 'Africa/Niamey',
          status: 'scheduled',
        },
        reviewRequest: { id: 'review-1', version: 5, status: 'scheduled' },
      },
    });
    expect(tx.appointment.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          slotOfferId: 'offer-1',
          slotId: 'slot-1',
          counsellorId: 'counsellor-1',
          timezone: 'Africa/Niamey',
          bookingKey: 'booking-1',
        }),
      }),
    );
    expect(tx.$queryRaw).toHaveBeenCalledTimes(2);
    expect(enqueue).toHaveBeenCalledWith(
      expect.objectContaining({
        eventName: 'study_review.appointment_booked',
        payload: expect.objectContaining({
          userId: 'student-1',
          workspaceId: 'workspace-1',
        }),
      }),
      tx,
    );
  });

  it('rejects an arbitrary timezone before consuming capacity', async () => {
    const review = reviewFixture({ status: 'call_offered', version: 4 });
    const tx = bookingTransaction(review, offerFixture(), appointmentFixture());
    execute.mockImplementation(async (operation: (db: unknown) => unknown) =>
      operation({
        $transaction: async (callback: (value: unknown) => unknown) =>
          callback(tx),
      }),
    );

    await expect(
      service.book(
        'student-1',
        'review-1',
        {
          expectedVersion: 4,
          slotOfferId: 'offer-1',
          bookingKey: 'booking-1',
          timezone: 'Europe/Paris',
        },
        'appointment-key-1',
        'request-1',
      ),
    ).rejects.toMatchObject({ status: 400 });
    expect(tx.studyReviewRequest.updateMany).not.toHaveBeenCalled();
    expect(tx.$queryRaw).toHaveBeenCalledTimes(1);
  });

  it('rejects an expired offer without consuming capacity', async () => {
    const review = reviewFixture({ status: 'call_offered', version: 4 });
    const tx = bookingTransaction(
      review,
      offerFixture({ expiresAt: new Date(Date.now() - 1000) }),
      appointmentFixture(),
    );
    execute.mockImplementation(async (operation: (db: unknown) => unknown) =>
      operation({
        $transaction: async (callback: (value: unknown) => unknown) =>
          callback(tx),
      }),
    );

    await expect(
      service.book(
        'student-1',
        'review-1',
        {
          expectedVersion: 4,
          slotOfferId: 'offer-1',
          bookingKey: 'booking-1',
          timezone: 'Africa/Niamey',
        },
        'appointment-key-expired',
        'request-expired',
      ),
    ).rejects.toMatchObject({
      status: 409,
      response: expect.objectContaining({ code: 'SLOT_OFFER_EXPIRED' }),
    });
    expect(tx.$queryRaw).toHaveBeenCalledTimes(1);
    expect(tx.appointment.create).not.toHaveBeenCalled();
  });

  it('rejects an offer belonging to another review', async () => {
    const review = reviewFixture({ status: 'call_offered', version: 4 });
    const tx = bookingTransaction(
      review,
      offerFixture({ reviewRequestId: 'review-foreign' }),
      appointmentFixture(),
    );
    execute.mockImplementation(async (operation: (db: unknown) => unknown) =>
      operation({
        $transaction: async (callback: (value: unknown) => unknown) =>
          callback(tx),
      }),
    );

    await expect(
      service.book(
        'student-1',
        'review-1',
        {
          expectedVersion: 4,
          slotOfferId: 'offer-1',
          bookingKey: 'booking-1',
          timezone: 'Africa/Niamey',
        },
        'appointment-key-foreign',
        'request-foreign',
      ),
    ).rejects.toMatchObject({
      status: 404,
      response: expect.objectContaining({ code: 'NO_SLOT_OFFERED' }),
    });
    expect(tx.appointment.create).not.toHaveBeenCalled();
  });

  it('rejects reuse of a bookingKey with different scheduling data', async () => {
    const review = reviewFixture({ status: 'scheduled', version: 5 });
    const tx = bookingTransaction(review, offerFixture(), appointmentFixture());
    tx.appointment.findUnique.mockResolvedValue(
      appointmentFixture() as never,
    );
    execute.mockImplementation(async (operation: (db: unknown) => unknown) =>
      operation({
        $transaction: async (callback: (value: unknown) => unknown) =>
          callback(tx),
      }),
    );

    await expect(
      service.book(
        'student-1',
        'review-1',
        {
          expectedVersion: 4,
          slotOfferId: 'different-offer',
          bookingKey: 'booking-1',
          timezone: 'Africa/Niamey',
        },
        'appointment-key-mismatch',
        'request-mismatch',
      ),
    ).rejects.toMatchObject({
      status: 409,
      response: expect.objectContaining({
        code: 'IDEMPOTENCY_PAYLOAD_MISMATCH',
      }),
    });
    expect(tx.studyReviewRequest.updateMany).not.toHaveBeenCalled();
  });

  it('returns SLOT_TAKEN when the atomic capacity update loses the race', async () => {
    const review = reviewFixture({ status: 'call_offered', version: 4 });
    const tx = bookingTransaction(review, offerFixture(), appointmentFixture());
    tx.$queryRaw.mockReset().mockResolvedValueOnce([]).mockResolvedValueOnce([]);
    execute.mockImplementation(async (operation: (db: unknown) => unknown) =>
      operation({
        $transaction: async (callback: (value: unknown) => unknown) =>
          callback(tx),
      }),
    );

    await expect(
      service.book(
        'student-1',
        'review-1',
        {
          expectedVersion: 4,
          slotOfferId: 'offer-1',
          bookingKey: 'booking-1',
          timezone: 'Africa/Niamey',
        },
        'appointment-key-1',
        'request-1',
      ),
    ).rejects.toMatchObject({
      status: 409,
      response: expect.objectContaining({ code: 'SLOT_TAKEN' }),
    });
    expect(tx.appointment.create).not.toHaveBeenCalled();
  });

  it('replays a completed booking before checking a now-stale expectedVersion', async () => {
    const snapshot = {
      appointment: {
        id: 'appointment-1',
        reviewRequestId: 'review-1',
        slotOfferId: 'offer-1',
      },
      reviewRequest: { id: 'review-1', version: 5, status: 'scheduled' },
    };
    reserve.mockResolvedValueOnce({
      state: 'replay',
      recordId: 'idem-1',
      payloadHash: 'hash',
      responseCode: 201,
      responseSnapshot: snapshot,
      resourceType: 'Appointment',
      resourceId: 'appointment-1',
      resultingVersion: 5,
      expiresAt: new Date('2030-01-01T00:00:00.000Z'),
    });
    const tx = { $queryRaw: jest.fn() };
    execute.mockImplementation(async (operation: (db: unknown) => unknown) =>
      operation({
        $transaction: async (callback: (value: unknown) => unknown) =>
          callback(tx),
      }),
    );

    await expect(
      service.book(
        'student-1',
        'review-1',
        {
          expectedVersion: 4,
          slotOfferId: 'offer-1',
          bookingKey: 'booking-1',
          timezone: 'Africa/Niamey',
        },
        'appointment-key-1',
        'request-1',
      ),
    ).resolves.toEqual({ statusCode: 201, body: snapshot });
    expect(tx.$queryRaw).not.toHaveBeenCalled();
  });

  it('cancels an owned future appointment and releases its capacity once', async () => {
    const review = reviewFixture({ status: 'scheduled', version: 5 });
    const appointment = appointmentFixture();
    const tx = cancellationTransaction(review, appointment);
    execute.mockImplementation(async (operation: (db: unknown) => unknown) =>
      operation({
        $transaction: async (callback: (value: unknown) => unknown) =>
          callback(tx),
      }),
    );

    const result = await service.cancel(
      'student-1',
      'appointment-1',
      { expectedVersion: 5, reasonCode: 'student_request' },
      'cancel-key-1',
      'request-cancel-1',
    );

    expect(result).toMatchObject({
      statusCode: 200,
      body: {
        appointment: { id: 'appointment-1', status: 'cancelled' },
        reviewRequest: { id: 'review-1', version: 6, status: 'triaged' },
      },
    });
    expect(tx.studyReviewRequest.updateMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          id: 'review-1',
          version: 5,
          status: 'scheduled',
        }),
        data: { status: 'triaged', version: { increment: 1 } },
      }),
    );
    expect(tx.appointment.updateMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          id: 'appointment-1',
          userId: 'student-1',
          reviewRequestId: 'review-1',
        }),
        data: { status: 'cancelled' },
      }),
    );
    expect(tx.$queryRaw).toHaveBeenCalledTimes(3);
    expect(tx.studyReviewSlotOffer.updateMany).toHaveBeenCalledWith({
      where: { reviewRequestId: 'review-1', status: 'offered' },
      data: { status: 'withdrawn', selectedAt: null },
    });
    expect(enqueue).toHaveBeenCalledWith(
      expect.objectContaining({
        eventName: 'study_review.appointment_cancelled',
        payload: expect.objectContaining({
          appointmentId: 'appointment-1',
          slotId: 'slot-1',
          version: 6,
        }),
      }),
      tx,
    );
    expect(tx.adminAuditEvent.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          requestId: 'request-cancel-1',
          reasonCode: 'student_request',
        }),
      }),
    );
  });

  it('hides a foreign appointment during cancellation', async () => {
    const tx = { $queryRaw: jest.fn().mockResolvedValue([]) };
    execute.mockImplementation(async (operation: (db: unknown) => unknown) =>
      operation({
        $transaction: async (callback: (value: unknown) => unknown) =>
          callback(tx),
      }),
    );

    await expect(
      service.cancel(
        'student-2',
        'appointment-1',
        { expectedVersion: 5, reasonCode: 'student_request' },
        'cancel-key-idor',
        'request-cancel-idor',
      ),
    ).rejects.toMatchObject({
      status: 404,
      response: expect.objectContaining({ code: 'WORKSPACE_NOT_FOUND' }),
    });
    expect(tx.$queryRaw).toHaveBeenCalledTimes(1);
  });

  it('does not release capacity when cancellation loses the appointment CAS', async () => {
    const review = reviewFixture({ status: 'scheduled', version: 5 });
    const tx = cancellationTransaction(review, appointmentFixture());
    tx.appointment.updateMany.mockResolvedValue({ count: 0 });
    execute.mockImplementation(async (operation: (db: unknown) => unknown) =>
      operation({
        $transaction: async (callback: (value: unknown) => unknown) =>
          callback(tx),
      }),
    );

    await expect(
      service.cancel(
        'student-1',
        'appointment-1',
        { expectedVersion: 5, reasonCode: 'student_request' },
        'cancel-key-race',
        'request-cancel-race',
      ),
    ).rejects.toMatchObject({
      status: 409,
      response: expect.objectContaining({ code: 'REVIEW_REQUEST_NOT_TRIAGED' }),
    });
    expect(tx.$queryRaw).toHaveBeenCalledTimes(2);
    expect(tx.scholarshipWorkspace.update).not.toHaveBeenCalled();
    expect(enqueue).not.toHaveBeenCalled();
  });

  it('rejects cancellation after an appointment has started', async () => {
    const review = reviewFixture({ status: 'scheduled', version: 5 });
    const appointment = appointmentFixture({
      startsAt: new Date(Date.now() - 60 * 1000),
    });
    const tx = cancellationTransaction(review, appointment);
    execute.mockImplementation(async (operation: (db: unknown) => unknown) =>
      operation({
        $transaction: async (callback: (value: unknown) => unknown) =>
          callback(tx),
      }),
    );

    await expect(
      service.cancel(
        'student-1',
        'appointment-1',
        { expectedVersion: 5, reasonCode: 'student_request' },
        'cancel-key-past',
        'request-cancel-past',
      ),
    ).rejects.toMatchObject({ status: 400 });
    expect(tx.studyReviewRequest.updateMany).not.toHaveBeenCalled();
    expect(tx.appointment.updateMany).not.toHaveBeenCalled();
    expect(tx.$queryRaw).toHaveBeenCalledTimes(2);
  });

  it('replays a completed cancellation without releasing capacity again', async () => {
    const snapshot = {
      appointment: {
        id: 'appointment-1',
        reviewRequestId: 'review-1',
        slotOfferId: 'offer-1',
        status: 'cancelled',
      },
      reviewRequest: { id: 'review-1', version: 6, status: 'triaged' },
    };
    reserve.mockResolvedValueOnce({
      state: 'replay',
      recordId: 'idem-cancel',
      payloadHash: 'hash',
      responseCode: 200,
      responseSnapshot: snapshot,
      resourceType: 'Appointment',
      resourceId: 'appointment-1',
      resultingVersion: 6,
      expiresAt: new Date('2030-01-01T00:00:00.000Z'),
    });
    const tx = { $queryRaw: jest.fn() };
    execute.mockImplementation(async (operation: (db: unknown) => unknown) =>
      operation({
        $transaction: async (callback: (value: unknown) => unknown) =>
          callback(tx),
      }),
    );

    await expect(
      service.cancel(
        'student-1',
        'appointment-1',
        { expectedVersion: 5, reasonCode: 'student_request' },
        'cancel-key-replay',
        'request-cancel-replay',
      ),
    ).resolves.toEqual({ statusCode: 200, body: snapshot });
    expect(tx.$queryRaw).not.toHaveBeenCalled();
  });

  it('reschedules atomically, releasing the old slot before claiming the replacement', async () => {
    const review = reviewFixture({ status: 'scheduled', version: 5 });
    const appointment = appointmentFixture();
    const replacementSlot = slotFixture({ id: 'slot-2' });
    const replacementOffer = offerFixture({
      id: 'offer-2',
      slotId: 'slot-2',
      slot: replacementSlot,
    });
    const replacementAppointment = appointmentFixture({
      id: 'appointment-2',
      slotId: 'slot-2',
      slotOfferId: 'offer-2',
      bookingKey: 'booking-reschedule-1',
      startsAt: replacementSlot.startsAt,
      endsAt: replacementSlot.endsAt,
    });
    const tx = rescheduleTransaction(
      review,
      appointment,
      replacementOffer,
      replacementAppointment,
    );
    execute.mockImplementation(async (operation: (db: unknown) => unknown) =>
      operation({
        $transaction: async (callback: (value: unknown) => unknown) =>
          callback(tx),
      }),
    );

    const result = await service.reschedule(
      'student-1',
      'appointment-1',
      {
        expectedVersion: 5,
        slotOfferId: 'offer-2',
        bookingKey: 'booking-reschedule-1',
        timezone: 'Africa/Niamey',
        reasonCode: 'student_request',
      },
      'reschedule-key-1',
      'request-reschedule-1',
    );

    expect(result).toMatchObject({
      statusCode: 200,
      body: {
        previousAppointmentId: 'appointment-1',
        appointment: { id: 'appointment-2', slotId: 'slot-2' },
        reviewRequest: { id: 'review-1', version: 6, status: 'scheduled' },
      },
    });
    expect(tx.$queryRaw).toHaveBeenCalledTimes(4);
    expect(tx.appointment.updateMany).toHaveBeenCalledWith(
      expect.objectContaining({ data: { status: 'cancelled' } }),
    );
    expect(tx.appointment.updateMany.mock.invocationCallOrder[0]).toBeLessThan(
      tx.$queryRaw.mock.invocationCallOrder[2],
    );
    expect(tx.$queryRaw.mock.invocationCallOrder[2]).toBeLessThan(
      tx.$queryRaw.mock.invocationCallOrder[3],
    );
    expect(tx.appointment.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          slotId: 'slot-2',
          slotOfferId: 'offer-2',
          bookingKey: 'booking-reschedule-1',
        }),
      }),
    );
    expect(enqueue).toHaveBeenCalledWith(
      expect.objectContaining({
        eventName: 'study_review.appointment_rescheduled',
        payload: expect.objectContaining({
          previousAppointmentId: 'appointment-1',
          appointmentId: 'appointment-2',
          previousSlotId: 'slot-1',
          slotId: 'slot-2',
        }),
      }),
      tx,
    );
  });

  it('keeps the old appointment and capacity when replacement capacity loses the race', async () => {
    const review = reviewFixture({ status: 'scheduled', version: 5 });
    const replacementSlot = slotFixture({ id: 'slot-2' });
    const tx = rescheduleTransaction(
      review,
      appointmentFixture(),
      offerFixture({ id: 'offer-2', slotId: 'slot-2', slot: replacementSlot }),
      appointmentFixture({ id: 'appointment-2' }),
    );
    tx.$queryRaw
      .mockReset()
      .mockResolvedValueOnce([
        { id: 'appointment-1', reviewRequestId: 'review-1' },
      ])
      .mockResolvedValueOnce([])
      .mockResolvedValueOnce([{ id: 'slot-1' }])
      .mockResolvedValueOnce([]);
    execute.mockImplementation(async (operation: (db: unknown) => unknown) =>
      operation({
        $transaction: async (callback: (value: unknown) => unknown) =>
          callback(tx),
      }),
    );

    await expect(
      service.reschedule(
        'student-1',
        'appointment-1',
        {
          expectedVersion: 5,
          slotOfferId: 'offer-2',
          bookingKey: 'booking-reschedule-race',
          timezone: 'Africa/Niamey',
          reasonCode: 'student_request',
        },
        'reschedule-key-race',
        'request-reschedule-race',
      ),
    ).rejects.toMatchObject({
      status: 409,
      response: expect.objectContaining({ code: 'SLOT_TAKEN' }),
    });
    expect(tx.$queryRaw).toHaveBeenCalledTimes(4);
    expect(tx.appointment.updateMany).toHaveBeenCalledWith(
      expect.objectContaining({ data: { status: 'cancelled' } }),
    );
    expect(tx.appointment.create).not.toHaveBeenCalled();
    expect(enqueue).not.toHaveBeenCalled();
  });

  it('requires one hour of notice before rescheduling', async () => {
    const review = reviewFixture({ status: 'scheduled', version: 5 });
    const appointment = appointmentFixture({
      startsAt: new Date(Date.now() + 30 * 60 * 1000),
    });
    const replacementSlot = slotFixture({ id: 'slot-2' });
    const tx = rescheduleTransaction(
      review,
      appointment,
      offerFixture({ id: 'offer-2', slotId: 'slot-2', slot: replacementSlot }),
      appointmentFixture({ id: 'appointment-2' }),
    );
    execute.mockImplementation(async (operation: (db: unknown) => unknown) =>
      operation({
        $transaction: async (callback: (value: unknown) => unknown) =>
          callback(tx),
      }),
    );

    await expect(
      service.reschedule(
        'student-1',
        'appointment-1',
        {
          expectedVersion: 5,
          slotOfferId: 'offer-2',
          bookingKey: 'booking-reschedule-too-late',
          timezone: 'Africa/Niamey',
          reasonCode: 'student_request',
        },
        'reschedule-key-too-late',
        'request-reschedule-too-late',
      ),
    ).rejects.toMatchObject({ status: 400 });
    expect(tx.studyReviewSlotOffer.findUnique).not.toHaveBeenCalled();
    expect(tx.studyReviewRequest.updateMany).not.toHaveBeenCalled();
    expect(tx.appointment.updateMany).not.toHaveBeenCalled();
  });

  it('hides a foreign appointment during rescheduling', async () => {
    const tx = { $queryRaw: jest.fn().mockResolvedValue([]) };
    execute.mockImplementation(async (operation: (db: unknown) => unknown) =>
      operation({
        $transaction: async (callback: (value: unknown) => unknown) =>
          callback(tx),
      }),
    );

    await expect(
      service.reschedule(
        'student-2',
        'appointment-1',
        {
          expectedVersion: 5,
          slotOfferId: 'offer-2',
          bookingKey: 'booking-reschedule-idor',
          timezone: 'Africa/Niamey',
          reasonCode: 'student_request',
        },
        'reschedule-key-idor',
        'request-reschedule-idor',
      ),
    ).rejects.toMatchObject({
      status: 404,
      response: expect.objectContaining({ code: 'WORKSPACE_NOT_FOUND' }),
    });
    expect(tx.$queryRaw).toHaveBeenCalledTimes(1);
  });
});

function acquiredReservation() {
  return {
    state: 'acquired',
    recordId: 'idem-1',
    payloadHash: 'hash',
    expiresAt: new Date('2030-01-01T00:00:00.000Z'),
  };
}

function reviewFixture(overrides: Record<string, unknown> = {}) {
  return {
    id: 'review-1',
    version: 3,
    status: 'triaged',
    assignedCounsellorId: 'counsellor-1',
    preferredContact: 'in_app',
    timezone: 'Africa/Niamey',
    workspace: {
      id: 'workspace-1',
      userId: 'student-1',
      scholarshipId: 'scholarship-1',
      scholarship: { id: 'scholarship-1', countryId: 'country-ne' },
    },
    ...overrides,
  };
}

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

function offerFixture(overrides: Record<string, unknown> = {}) {
  return {
    id: 'offer-1',
    reviewRequestId: 'review-1',
    slotId: 'slot-1',
    offeredAt: new Date(),
    expiresAt: new Date(Date.now() + 60 * 60 * 1000),
    status: 'offered',
    selectedAt: null,
    createdAt: new Date(),
    appointment: null,
    slot: slotFixture(),
    ...overrides,
  };
}

function appointmentFixture(overrides: Record<string, unknown> = {}) {
  const slot = slotFixture();
  return {
    id: 'appointment-1',
    userId: 'student-1',
    caseId: null,
    title: 'Study review call',
    goal: 'Review scholarship application',
    startsAt: slot.startsAt,
    endsAt: slot.endsAt,
    status: 'scheduled',
    contactMethod: 'in_app',
    notes: null,
    counsellorId: 'counsellor-1',
    reviewRequestId: 'review-1',
    slotId: 'slot-1',
    slotOfferId: 'offer-1',
    timezone: 'Africa/Niamey',
    bookingKey: 'booking-1',
    createdAt: new Date(),
    updatedAt: new Date(),
    ...overrides,
  };
}

function offerTransaction(review: any, slot: any) {
  return {
    $queryRaw: jest.fn(),
    studyReviewRequest: {
      findUnique: jest.fn().mockResolvedValue(review),
      updateMany: jest.fn().mockResolvedValue({ count: 1 }),
    },
    counsellorAvailabilitySlot: {
      findMany: jest.fn().mockResolvedValue([slot]),
    },
    appointment: { count: jest.fn().mockResolvedValue(0) },
    studyReviewSlotOffer: {
      count: jest.fn(),
      updateMany: jest.fn(),
      upsert: jest.fn().mockResolvedValue({
        id: 'offer-1',
        expiresAt: new Date(Date.now() + 60 * 60 * 1000),
      }),
    },
    adminAuditEvent: { create: jest.fn() },
  };
}

function bookingTransaction(review: any, offer: any, appointment: any) {
  return {
    $queryRaw: jest.fn().mockResolvedValueOnce([]).mockResolvedValueOnce([{ id: 'slot-1' }]),
    studyReviewRequest: {
      findUnique: jest.fn().mockResolvedValue(review),
      updateMany: jest.fn().mockResolvedValue({ count: 1 }),
    },
    appointment: {
      findUnique: jest.fn().mockResolvedValue(null),
      create: jest.fn().mockResolvedValue(appointment),
    },
    studyReviewSlotOffer: {
      findUnique: jest.fn().mockResolvedValue(offer),
      updateMany: jest.fn().mockResolvedValue({ count: 1 }),
    },
    scholarshipWorkspace: { update: jest.fn() },
    adminAuditEvent: { create: jest.fn() },
  };
}

function cancellationTransaction(review: any, appointment: any) {
  return {
    $queryRaw: jest
      .fn()
      .mockResolvedValueOnce([
        { id: appointment.id, reviewRequestId: appointment.reviewRequestId },
      ])
      .mockResolvedValueOnce([])
      .mockResolvedValueOnce([{ id: appointment.slotId }]),
    studyReviewRequest: {
      findUnique: jest.fn().mockResolvedValue(review),
      updateMany: jest.fn().mockResolvedValue({ count: 1 }),
    },
    appointment: {
      findUnique: jest
        .fn()
        .mockResolvedValueOnce(appointment)
        .mockResolvedValueOnce({ ...appointment, status: 'cancelled' }),
      updateMany: jest.fn().mockResolvedValue({ count: 1 }),
    },
    studyReviewSlotOffer: {
      updateMany: jest.fn().mockResolvedValue({ count: 1 }),
    },
    scholarshipWorkspace: { update: jest.fn() },
    adminAuditEvent: { create: jest.fn() },
  };
}

function rescheduleTransaction(
  review: any,
  appointment: any,
  replacementOffer: any,
  replacementAppointment: any,
) {
  return {
    $queryRaw: jest
      .fn()
      .mockResolvedValueOnce([
        { id: appointment.id, reviewRequestId: appointment.reviewRequestId },
      ])
      .mockResolvedValueOnce([])
      .mockResolvedValueOnce([{ id: appointment.slotId }])
      .mockResolvedValueOnce([{ id: replacementOffer.slotId }]),
    studyReviewRequest: {
      findUnique: jest.fn().mockResolvedValue(review),
      updateMany: jest.fn().mockResolvedValue({ count: 1 }),
    },
    appointment: {
      findUnique: jest.fn().mockImplementation(({ where }: any) =>
        Promise.resolve(where.id === appointment.id ? appointment : null),
      ),
      updateMany: jest.fn().mockResolvedValue({ count: 1 }),
      create: jest.fn().mockResolvedValue(replacementAppointment),
    },
    studyReviewSlotOffer: {
      findUnique: jest.fn().mockResolvedValue(replacementOffer),
      updateMany: jest.fn().mockResolvedValue({ count: 1 }),
    },
    scholarshipWorkspace: { update: jest.fn() },
    adminAuditEvent: { create: jest.fn() },
  };
}
