import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/success_lab.dart';
import '../repositories/success_lab_repository.dart';

enum SuccessLabDiagnosticPhase {
  initial,
  loading,
  consentRequired,
  ready,
  running,
  completed,
  unavailable,
  offline,
  error,
}

class SuccessLabDiagnosticController extends ChangeNotifier {
  SuccessLabDiagnosticController({
    required SuccessLabRepository repository,
    required this.workspaceId,
    required this.language,
    Future<void> Function(Duration)? delay,
  })  : _repository = repository,
        _delay = delay ?? Future<void>.delayed;

  final SuccessLabRepository _repository;
  final String workspaceId;
  final String language;
  final Future<void> Function(Duration) _delay;

  SuccessLabDiagnosticPhase phase = SuccessLabDiagnosticPhase.initial;
  SuccessLabAccess? access;
  SuccessLabAiNotice? notice;
  SuccessLabDiagnostic? diagnostic;
  SuccessLabFailure? failure;

  bool get requiresConsent =>
      access?.aiDiagnosticRequiresConsent == true && notice != null;

  Future<void> load() async {
    phase = SuccessLabDiagnosticPhase.loading;
    failure = null;
    notifyListeners();
    if (!_repository.canUseNetwork) {
      phase = SuccessLabDiagnosticPhase.offline;
      notifyListeners();
      return;
    }

    try {
      access = await _repository.fetchAccess();
      final envelope = await _repository.fetchDiagnostic(workspaceId);
      diagnostic = envelope.diagnostic;
      if (diagnostic?.isComplete == true) {
        phase = SuccessLabDiagnosticPhase.completed;
      } else if (diagnostic?.status == SuccessLabDiagnosticStatus.running ||
          diagnostic?.status == SuccessLabDiagnosticStatus.pending) {
        phase = SuccessLabDiagnosticPhase.running;
        notifyListeners();
        await _pollRunning();
        return;
      } else if (access?.aiDiagnosticRequiresConsent == true) {
        notice = await _repository.fetchAiNotice(language: language);
        phase = SuccessLabDiagnosticPhase.consentRequired;
      } else if (access?.aiDiagnosticEnabled == true) {
        phase = SuccessLabDiagnosticPhase.ready;
      } else {
        phase = SuccessLabDiagnosticPhase.unavailable;
      }
    } catch (error) {
      failure = SuccessLabRepository.normalizeFailure(error);
      phase = failure!.kind == SuccessLabFailureKind.offline
          ? SuccessLabDiagnosticPhase.offline
          : SuccessLabDiagnosticPhase.error;
    }
    notifyListeners();
  }

  Future<void> start({
    required bool consentAccepted,
    String? acceptedNoticeContentHash,
    String? applicationExcerpt,
  }) async {
    if (phase == SuccessLabDiagnosticPhase.running) return;
    if (requiresConsent &&
        (!consentAccepted ||
            acceptedNoticeContentHash == null ||
            acceptedNoticeContentHash != notice!.contentHash)) {
      failure = const SuccessLabFailure(
        kind: SuccessLabFailureKind.forbidden,
        code: 'AI_CONSENT_REQUIRED',
        retryable: false,
      );
      notifyListeners();
      return;
    }
    phase = SuccessLabDiagnosticPhase.running;
    failure = null;
    notifyListeners();
    try {
      if (requiresConsent) {
        await _repository.grantAiConsent(notice!);
        access = await _repository.fetchAccess();
      }
      diagnostic = await _repository.createDiagnostic(
        workspaceId: workspaceId,
        language: language,
        applicationExcerpt: applicationExcerpt,
      );
      if (diagnostic!.isComplete) {
        phase = SuccessLabDiagnosticPhase.completed;
      } else {
        await _pollRunning();
        return;
      }
    } catch (error) {
      failure = SuccessLabRepository.normalizeFailure(error);
      phase = failure!.kind == SuccessLabFailureKind.offline
          ? SuccessLabDiagnosticPhase.offline
          : SuccessLabDiagnosticPhase.error;
    }
    notifyListeners();
  }

  Future<void> _pollRunning() async {
    for (var attempt = 0; attempt < 5; attempt++) {
      await _delay(const Duration(seconds: 2));
      try {
        final envelope = await _repository.fetchDiagnostic(workspaceId);
        diagnostic = envelope.diagnostic;
        if (diagnostic?.isComplete == true) {
          phase = SuccessLabDiagnosticPhase.completed;
          notifyListeners();
          return;
        }
        if (diagnostic?.status == SuccessLabDiagnosticStatus.failed ||
            diagnostic?.status == SuccessLabDiagnosticStatus.blocked) {
          phase = SuccessLabDiagnosticPhase.error;
          notifyListeners();
          return;
        }
      } catch (error) {
        failure = SuccessLabRepository.normalizeFailure(error);
        if (!failure!.retryable) {
          phase = SuccessLabDiagnosticPhase.error;
          notifyListeners();
          return;
        }
      }
    }
    phase = SuccessLabDiagnosticPhase.error;
    failure = const SuccessLabFailure(
      kind: SuccessLabFailureKind.server,
      code: 'AI_TEMPORARILY_UNAVAILABLE',
      retryable: true,
    );
    notifyListeners();
  }
}
