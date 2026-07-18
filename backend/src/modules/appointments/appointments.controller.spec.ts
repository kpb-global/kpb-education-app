import type { Response } from 'express';

import type { StudyReviewSchedulingService } from '../competition-readiness/reviews/study-review-scheduling.service';
import { AppointmentsController } from './appointments.controller';
import type { AppointmentsService } from './appointments.service';

describe('AppointmentsController study review mutations', () => {
  const appointments = {} as AppointmentsService;
  const cancel = jest.fn();
  const reschedule = jest.fn();
  const scheduling = { cancel, reschedule } as unknown as StudyReviewSchedulingService;
  const controller = new AppointmentsController(appointments, scheduling);
  const status = jest.fn();
  const setHeader = jest.fn();
  const response = { status, setHeader } as unknown as Response;

  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('routes an owned cancellation with idempotency and request correlation', async () => {
    const body = {
      appointment: { id: 'appointment-1', status: 'cancelled' },
      reviewRequest: { id: 'review-1', version: 6, status: 'triaged' },
    };
    cancel.mockResolvedValue({ statusCode: 200, body });

    await expect(
      controller.cancelStudyReviewAppointment(
        'appointment-1',
        { expectedVersion: 5, reasonCode: 'student_request' },
        '  cancel-key-1  ',
        {
          studentUser: { id: 'student-1' },
          headers: { 'x-request-id': 'request-cancel-1' },
        },
        response,
      ),
    ).resolves.toEqual(body);

    expect(cancel).toHaveBeenCalledWith(
      'student-1',
      'appointment-1',
      { expectedVersion: 5, reasonCode: 'student_request' },
      'cancel-key-1',
      'request-cancel-1',
    );
    expect(setHeader).toHaveBeenCalledWith(
      'Cache-Control',
      'private, no-store',
    );
    expect(setHeader).toHaveBeenCalledWith(
      'X-Request-Id',
      'request-cancel-1',
    );
    expect(status).toHaveBeenCalledWith(200);
  });

  it('routes a reschedule and returns the replacement appointment', async () => {
    const input = {
      expectedVersion: 5,
      slotOfferId: 'offer-2',
      bookingKey: 'booking-reschedule-1',
      timezone: 'Africa/Niamey',
      reasonCode: 'student_request',
    };
    const body = {
      previousAppointmentId: 'appointment-1',
      appointment: { id: 'appointment-2', status: 'scheduled' },
      reviewRequest: { id: 'review-1', version: 6, status: 'scheduled' },
    };
    reschedule.mockResolvedValue({ statusCode: 200, body });

    await expect(
      controller.rescheduleStudyReviewAppointment(
        'appointment-1',
        input,
        'reschedule-key-1',
        {
          studentUser: { id: 'student-1' },
          headers: { 'x-request-id': 'request-reschedule-1' },
        },
        response,
      ),
    ).resolves.toEqual(body);
    expect(reschedule).toHaveBeenCalledWith(
      'student-1',
      'appointment-1',
      input,
      'reschedule-key-1',
      'request-reschedule-1',
    );
    expect(status).toHaveBeenCalledWith(200);
  });

  it('rejects a missing idempotency key before calling the service', async () => {
    await expect(
      controller.cancelStudyReviewAppointment(
        'appointment-1',
        { expectedVersion: 5, reasonCode: 'student_request' },
        undefined,
        { studentUser: { id: 'student-1' }, headers: {} },
        response,
      ),
    ).rejects.toMatchObject({
      status: 400,
      response: expect.objectContaining({ code: 'IDEMPOTENCY_KEY_REQUIRED' }),
    });
    expect(cancel).not.toHaveBeenCalled();
  });
});
