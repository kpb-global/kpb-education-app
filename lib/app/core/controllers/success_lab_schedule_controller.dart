import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/success_lab.dart';
import '../repositories/success_lab_repository.dart';

enum SuccessLabSchedulePhase {
  initial,
  loading,
  ready,
  empty,
  waiting,
  booking,
  booked,
  noRequest,
  unavailable,
  offline,
  error,
}

/// Online-only controller for the slot-offer and appointment workflow.
///
/// Booking keys live only in this controller. They survive automatic and
/// explicit retries for one offer, but are never written to cache or outbox.
class SuccessLabScheduleController extends ChangeNotifier {
  SuccessLabScheduleController({
    required SuccessLabRepository repository,
    required this.workspaceId,
    String Function()? keyFactory,
  })  : _repository = repository,
        _keyFactory = keyFactory ?? _newKey;

  final SuccessLabRepository _repository;
  final String workspaceId;
  final String Function() _keyFactory;

  SuccessLabSchedulePhase phase = SuccessLabSchedulePhase.initial;
  SuccessLabStudyReviewRequest? request;
  SuccessLabStudyReviewSlotOffers? slotOffers;
  SuccessLabStudyReviewBookingResult? bookingResult;
  SuccessLabFailure? failure;
  String? selectedOfferId;

  String? _pendingOfferId;
  String? _bookingKey;
  String? _idempotencyKey;

  static String _newKey() => const Uuid().v4();

  List<SuccessLabStudyReviewSlotOffer> get offers =>
      slotOffers?.offers ?? const <SuccessLabStudyReviewSlotOffer>[];

  SuccessLabStudyReviewSlotOffer? get selectedOffer {
    final selected = selectedOfferId;
    if (selected == null) return null;
    for (final offer in offers) {
      if (offer.slotOfferId == selected) return offer;
    }
    return null;
  }

  Future<void> load() async {
    phase = SuccessLabSchedulePhase.loading;
    failure = null;
    notifyListeners();
    if (!_repository.canUseNetwork) {
      phase = SuccessLabSchedulePhase.offline;
      notifyListeners();
      return;
    }
    try {
      final access = await _repository.fetchAccess();
      if (!access.enabled || !access.counsellorStudyEnabled) {
        phase = SuccessLabSchedulePhase.unavailable;
        notifyListeners();
        return;
      }
      final active = await _repository.fetchActiveStudyReview(workspaceId);
      request = active;
      if (active == null) {
        phase = SuccessLabSchedulePhase.noRequest;
        notifyListeners();
        return;
      }
      if (active.status == SuccessLabStudyReviewStatus.scheduled) {
        phase = SuccessLabSchedulePhase.booked;
        notifyListeners();
        return;
      }
      if (!active.canChooseSlot) {
        phase = SuccessLabSchedulePhase.waiting;
        notifyListeners();
        return;
      }
      final refreshedOffers =
          await _repository.fetchStudyReviewSlotOffers(active.id);
      slotOffers = refreshedOffers;
      final selectedStillExists = refreshedOffers.offers.any(
        (offer) => offer.slotOfferId == selectedOfferId,
      );
      if (!selectedStillExists) selectedOfferId = null;
      phase = refreshedOffers.offers.isEmpty
          ? SuccessLabSchedulePhase.empty
          : SuccessLabSchedulePhase.ready;
    } catch (error) {
      failure = SuccessLabRepository.normalizeFailure(error);
      phase = failure!.kind == SuccessLabFailureKind.offline
          ? SuccessLabSchedulePhase.offline
          : failure!.kind == SuccessLabFailureKind.featureDisabled
              ? SuccessLabSchedulePhase.unavailable
              : SuccessLabSchedulePhase.error;
    }
    notifyListeners();
  }

  void selectOffer(String offerId) {
    if (!offers.any((offer) => offer.slotOfferId == offerId)) return;
    if (selectedOfferId == offerId) return;
    selectedOfferId = offerId;
    if (_pendingOfferId != offerId) {
      // Selecting another offer starts a distinct booking intent. Keys are
      // generated lazily when the student confirms the new choice.
      _pendingOfferId = null;
      _bookingKey = null;
      _idempotencyKey = null;
    }
    failure = null;
    notifyListeners();
  }

  Future<void> bookSelectedOffer() async {
    final offer = selectedOffer;
    final envelope = slotOffers;
    final active = request;
    if (offer == null || envelope == null || active == null) {
      failure = const SuccessLabFailure(
        kind: SuccessLabFailureKind.invalidPayload,
        code: 'NO_SLOT_OFFERED',
        retryable: false,
      );
      notifyListeners();
      return;
    }
    if (!_repository.canUseNetwork) {
      failure = const SuccessLabFailure(
        kind: SuccessLabFailureKind.offline,
        code: 'OFFLINE',
        retryable: true,
      );
      notifyListeners();
      return;
    }
    if (_pendingOfferId != offer.slotOfferId ||
        _bookingKey == null ||
        _idempotencyKey == null) {
      _pendingOfferId = offer.slotOfferId;
      _bookingKey = _keyFactory();
      _idempotencyKey = _keyFactory();
    }
    final stableBookingKey = _bookingKey!;
    final stableIdempotencyKey = _idempotencyKey!;
    phase = SuccessLabSchedulePhase.booking;
    failure = null;
    notifyListeners();
    try {
      final result = await _repository.bookStudyReviewAppointment(
        reviewRequestId: active.id,
        expectedVersion: envelope.reviewRequestVersion,
        slotOfferId: offer.slotOfferId,
        bookingKey: stableBookingKey,
        timezone: offer.timezone,
        idempotencyKey: stableIdempotencyKey,
      );
      if (!result.isServerConfirmed) {
        throw const SuccessLabFailure(
          kind: SuccessLabFailureKind.invalidPayload,
          code: 'APPOINTMENT_NOT_CONFIRMED',
          retryable: false,
        );
      }
      bookingResult = result;
      // A server-confirmed success is the only same-offer outcome that retires
      // these keys. A later workflow therefore cannot accidentally replay it.
      _pendingOfferId = null;
      _bookingKey = null;
      _idempotencyKey = null;
      phase = SuccessLabSchedulePhase.booked;
    } catch (error) {
      failure = SuccessLabRepository.normalizeFailure(error);
      // Keep both keys for an explicit retry of this same selection, even after
      // timeout or a terminal response. Selecting a different offer resets them.
      phase = SuccessLabSchedulePhase.ready;
    }
    notifyListeners();
  }
}
