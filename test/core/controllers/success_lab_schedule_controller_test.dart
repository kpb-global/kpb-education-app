import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:karatou/app/core/controllers/success_lab_schedule_controller.dart';
import 'package:karatou/app/core/models/success_lab.dart';
import 'package:karatou/app/core/repositories/success_lab_repository.dart';

class _MockSuccessLabRepository extends Mock implements SuccessLabRepository {}

const _access = SuccessLabAccess(
  enabled: true,
  counsellorStudyEnabled: true,
);

void main() {
  test(
      'manual timeout retry preserves both keys and another offer rotates them',
      () async {
    final repository = _MockSuccessLabRepository();
    final request = _callOfferedRequest();
    final offers = _offers();
    final generatedKeys = <String>[
      'booking-offer-1',
      'idempotency-offer-1',
      'booking-offer-2',
      'idempotency-offer-2',
    ];
    final bookingKeys = <String>[];
    final idempotencyKeys = <String>[];
    var bookingCalls = 0;

    when(() => repository.canUseNetwork).thenReturn(true);
    when(repository.fetchAccess).thenAnswer((_) async => _access);
    when(() => repository.fetchActiveStudyReview('workspace-1'))
        .thenAnswer((_) async => request);
    when(() => repository.fetchStudyReviewSlotOffers('review-1'))
        .thenAnswer((_) async => offers);
    when(
      () => repository.bookStudyReviewAppointment(
        reviewRequestId: any(named: 'reviewRequestId'),
        expectedVersion: any(named: 'expectedVersion'),
        slotOfferId: any(named: 'slotOfferId'),
        bookingKey: any(named: 'bookingKey'),
        timezone: any(named: 'timezone'),
        idempotencyKey: any(named: 'idempotencyKey'),
      ),
    ).thenAnswer((invocation) async {
      bookingCalls++;
      final bookingKey = invocation.namedArguments[#bookingKey]! as String;
      final idempotencyKey =
          invocation.namedArguments[#idempotencyKey]! as String;
      final offerId = invocation.namedArguments[#slotOfferId]! as String;
      bookingKeys.add(bookingKey);
      idempotencyKeys.add(idempotencyKey);
      if (bookingCalls == 1) {
        throw const SuccessLabFailure(
          kind: SuccessLabFailureKind.offline,
          code: 'NETWORK_UNAVAILABLE',
          retryable: true,
        );
      }
      return _booking(offerId);
    });
    final controller = SuccessLabScheduleController(
      repository: repository,
      workspaceId: 'workspace-1',
      keyFactory: () => generatedKeys.removeAt(0),
    );
    addTearDown(controller.dispose);

    await controller.load();
    controller.selectOffer('offer-1');
    await controller.bookSelectedOffer();
    expect(controller.phase, SuccessLabSchedulePhase.ready);
    await controller.bookSelectedOffer();

    expect(controller.phase, SuccessLabSchedulePhase.booked);
    expect(bookingKeys.take(2), <String>['booking-offer-1', 'booking-offer-1']);
    expect(
      idempotencyKeys.take(2),
      <String>['idempotency-offer-1', 'idempotency-offer-1'],
    );
    expect(generatedKeys, <String>['booking-offer-2', 'idempotency-offer-2']);

    // A different offer is a new user intent, so and only so do the keys turn.
    controller.selectOffer('offer-2');
    await controller.bookSelectedOffer();
    expect(bookingKeys.last, 'booking-offer-2');
    expect(idempotencyKeys.last, 'idempotency-offer-2');
    expect(generatedKeys, isEmpty);
  });

  test('scheduled server state resumes after restart without loading offers',
      () async {
    final repository = _MockSuccessLabRepository();
    when(() => repository.canUseNetwork).thenReturn(true);
    when(repository.fetchAccess).thenAnswer((_) async => _access);
    when(() => repository.fetchActiveStudyReview('workspace-1')).thenAnswer(
      (_) async => _callOfferedRequest(
        status: SuccessLabStudyReviewStatus.scheduled,
        nextAction: SuccessLabStudyReviewNextAction.appointmentScheduled,
      ),
    );
    final controller = SuccessLabScheduleController(
      repository: repository,
      workspaceId: 'workspace-1',
    );
    addTearDown(controller.dispose);

    await controller.load();

    expect(controller.phase, SuccessLabSchedulePhase.booked);
    verifyNever(() => repository.fetchStudyReviewSlotOffers(any()));
  });

  test('server-confirmed success retires keys before any later booking call',
      () async {
    final repository = _MockSuccessLabRepository();
    final seenBookingKeys = <String>[];
    final seenIdempotencyKeys = <String>[];
    final generated = <String>['booking-1', 'idem-1', 'booking-2', 'idem-2'];
    when(() => repository.canUseNetwork).thenReturn(true);
    when(repository.fetchAccess).thenAnswer((_) async => _access);
    when(() => repository.fetchActiveStudyReview('workspace-1'))
        .thenAnswer((_) async => _callOfferedRequest());
    when(() => repository.fetchStudyReviewSlotOffers('review-1'))
        .thenAnswer((_) async => _offers());
    when(
      () => repository.bookStudyReviewAppointment(
        reviewRequestId: any(named: 'reviewRequestId'),
        expectedVersion: any(named: 'expectedVersion'),
        slotOfferId: any(named: 'slotOfferId'),
        bookingKey: any(named: 'bookingKey'),
        timezone: any(named: 'timezone'),
        idempotencyKey: any(named: 'idempotencyKey'),
      ),
    ).thenAnswer((invocation) async {
      seenBookingKeys.add(invocation.namedArguments[#bookingKey]! as String);
      seenIdempotencyKeys
          .add(invocation.namedArguments[#idempotencyKey]! as String);
      return _booking(invocation.namedArguments[#slotOfferId]! as String);
    });
    final controller = SuccessLabScheduleController(
      repository: repository,
      workspaceId: 'workspace-1',
      keyFactory: () => generated.removeAt(0),
    );
    addTearDown(controller.dispose);

    await controller.load();
    controller.selectOffer('offer-1');
    await controller.bookSelectedOffer();
    await controller.bookSelectedOffer();

    expect(seenBookingKeys, <String>['booking-1', 'booking-2']);
    expect(seenIdempotencyKeys, <String>['idem-1', 'idem-2']);
  });
}

SuccessLabStudyReviewRequest _callOfferedRequest({
  SuccessLabStudyReviewStatus status = SuccessLabStudyReviewStatus.callOffered,
  SuccessLabStudyReviewNextAction nextAction =
      SuccessLabStudyReviewNextAction.chooseSlot,
}) {
  return SuccessLabStudyReviewRequest(
    id: 'review-1',
    workspaceId: 'workspace-1',
    status: status,
    statusWireValue: status == SuccessLabStudyReviewStatus.scheduled
        ? 'scheduled'
        : 'call_offered',
    nextAction: nextAction,
    nextActionWireValue:
        nextAction == SuccessLabStudyReviewNextAction.appointmentScheduled
            ? 'appointment_scheduled'
            : 'choose_slot',
    requestNumber: 1,
    version: 3,
    timezone: 'Africa/Niamey',
    missingItems: const <String>[],
    sharedVersions: const <SuccessLabStudyReviewSharedVersion>[],
    createdAt: DateTime.utc(2026, 7, 17),
    updatedAt: DateTime.utc(2026, 7, 18),
    submittedAt: DateTime.utc(2026, 7, 17),
  );
}

SuccessLabStudyReviewSlotOffers _offers() {
  return SuccessLabStudyReviewSlotOffers(
    reviewRequestId: 'review-1',
    reviewRequestVersion: 3,
    timezone: 'Africa/Niamey',
    offers: <SuccessLabStudyReviewSlotOffer>[
      SuccessLabStudyReviewSlotOffer(
        slotOfferId: 'offer-1',
        slotId: 'slot-1',
        startsAt: DateTime.utc(2026, 7, 20, 9),
        endsAt: DateTime.utc(2026, 7, 20, 9, 30),
        timezone: 'Africa/Niamey',
        expiresAt: DateTime.utc(2026, 7, 19, 9),
        counsellorName: 'Aïcha KPB',
      ),
      SuccessLabStudyReviewSlotOffer(
        slotOfferId: 'offer-2',
        slotId: 'slot-2',
        startsAt: DateTime.utc(2026, 7, 20, 10),
        endsAt: DateTime.utc(2026, 7, 20, 10, 30),
        timezone: 'Africa/Niamey',
        expiresAt: DateTime.utc(2026, 7, 19, 9),
        counsellorName: 'Aïcha KPB',
      ),
    ],
  );
}

SuccessLabStudyReviewBookingResult _booking(String offerId) {
  return SuccessLabStudyReviewBookingResult(
    appointment: SuccessLabStudyReviewAppointment(
      id: 'appointment-$offerId',
      reviewRequestId: 'review-1',
      slotOfferId: offerId,
      slotId: 'slot-$offerId',
      counsellorId: 'counsellor-1',
      startsAt: DateTime.utc(2026, 7, 20, 9),
      endsAt: DateTime.utc(2026, 7, 20, 9, 30),
      timezone: 'Africa/Niamey',
      status: 'scheduled',
      contactMethod: 'in_app',
      createdAt: DateTime.utc(2026, 7, 18),
    ),
    reviewRequestId: 'review-1',
    reviewRequestVersion: 4,
    reviewRequestStatus: SuccessLabStudyReviewStatus.scheduled,
  );
}
