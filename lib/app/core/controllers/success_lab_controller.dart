import 'package:flutter/foundation.dart';

import '../models/success_lab.dart';
import '../repositories/success_lab_repository.dart';

class SuccessLabController extends ChangeNotifier {
  SuccessLabController({
    required SuccessLabRepository repository,
    required this.workspaceId,
  }) : _repository = repository;

  final SuccessLabRepository _repository;
  final String workspaceId;

  LabLoadPhase phase = LabLoadPhase.initial;
  SuccessLabAccess? access;
  SuccessLabWorkspace? workspace;
  SuccessLabFailure? failure;
  DateTime? cachedAt;

  final Map<String, MutationPhase> _stepMutationPhases =
      <String, MutationPhase>{};

  MutationPhase mutationPhaseFor(String stepId) =>
      _stepMutationPhases[stepId] ?? MutationPhase.idle;

  bool get canUseDiagnostic => access?.aiDiagnosticEnabled == true;
  bool get canOpenDiagnostic =>
      access?.aiDiagnosticEnabled == true ||
      access?.aiDiagnosticAvailable == true ||
      access?.aiDiagnosticRequiresConsent == true;
  bool get canRequestCounsellorStudy => access?.counsellorStudyEnabled == true;
  bool get canDeclareOutcomes =>
      access?.outcomeEvidenceEnabled == true ||
      access?.outcomeEvidenceAvailable == true ||
      access?.outcomeEvidenceRequiresConsent == true;

  Future<void> load() async {
    phase = LabLoadPhase.loading;
    failure = null;
    notifyListeners();

    final cachedAccess = await _repository.readCachedAccess();
    final cachedWorkspace = await _repository.readCachedWorkspace(workspaceId);
    access = cachedAccess?.value;
    if (cachedWorkspace != null) {
      workspace = cachedWorkspace.value;
      cachedAt = cachedWorkspace.syncedAt;
      phase = LabLoadPhase.cached;
      await _refreshPendingMutationPhases();
      notifyListeners();
    }

    if (!_repository.canUseNetwork) {
      phase = LabLoadPhase.offline;
      notifyListeners();
      return;
    }
    if (workspace != null) {
      phase = LabLoadPhase.syncing;
      notifyListeners();
    }

    try {
      final decision = await _repository.fetchAccess();
      access = decision;
      if (!decision.enabled) {
        workspace = null;
        phase = LabLoadPhase.featureDisabled;
        notifyListeners();
        return;
      }

      final retry = await _repository.retryPending(workspaceId: workspaceId);
      workspace = retry.latestWorkspace ??
          await _repository.fetchWorkspace(workspaceId);
      cachedAt = DateTime.now().toUtc();
      await _refreshPendingMutationPhases();
      phase = LabLoadPhase.ready;
    } catch (error) {
      failure = SuccessLabRepository.normalizeFailure(error);
      phase =
          workspace != null && failure!.kind == SuccessLabFailureKind.offline
              ? LabLoadPhase.offline
              : _phaseForFailure(failure!);
    }
    notifyListeners();
  }

  Future<void> setStepStatus(
    SuccessLabWorkspaceStep step,
    SuccessLabWorkspaceStepStatus status, {
    String? notApplicableReason,
  }) async {
    final current = workspace;
    if (current == null) return;
    _stepMutationPhases[step.id] = _repository.canUseNetwork
        ? MutationPhase.sending
        : MutationPhase.queuedOffline;
    notifyListeners();

    try {
      final result = await _repository.updateStep(
        workspace: current,
        step: step,
        status: status,
        notApplicableReason: notApplicableReason,
      );
      if (result.workspace != null) {
        workspace = result.workspace;
        _stepMutationPhases[step.id] = MutationPhase.success;
      } else if (result.queued) {
        _stepMutationPhases[step.id] = MutationPhase.queuedOffline;
      } else if (result.failure?.kind == SuccessLabFailureKind.conflict) {
        _stepMutationPhases[step.id] = MutationPhase.conflict;
      } else {
        _stepMutationPhases[step.id] = MutationPhase.failed;
      }
    } catch (error) {
      failure = SuccessLabRepository.normalizeFailure(error);
      _stepMutationPhases[step.id] = MutationPhase.failed;
    }
    notifyListeners();
  }

  Future<void> retryPending() async {
    final pending =
        await _repository.pendingMutations(workspaceId: workspaceId);
    for (final mutation in pending) {
      _stepMutationPhases[mutation.stepId] = MutationPhase.sending;
    }
    notifyListeners();

    final result = await _repository.retryPending(workspaceId: workspaceId);
    if (result.latestWorkspace != null) {
      workspace = result.latestWorkspace;
    } else if (result.sent > 0 && _repository.canUseNetwork) {
      try {
        workspace = await _repository.fetchWorkspace(workspaceId);
      } catch (_) {
        // Keep the last useful snapshot; pending phases remain explicit.
      }
    }
    await _refreshPendingMutationPhases();
    notifyListeners();
  }

  Future<void> _refreshPendingMutationPhases() async {
    final pending =
        await _repository.pendingMutations(workspaceId: workspaceId);
    _stepMutationPhases.removeWhere(
      (stepId, phase) =>
          phase == MutationPhase.queuedOffline ||
          phase == MutationPhase.failed ||
          phase == MutationPhase.conflict,
    );
    for (final mutation in pending) {
      _stepMutationPhases[mutation.stepId] = mutation.permanentlyFailed
          ? MutationPhase.failed
          : MutationPhase.queuedOffline;
    }
  }

  LabLoadPhase _phaseForFailure(SuccessLabFailure value) {
    switch (value.kind) {
      case SuccessLabFailureKind.offline:
        return LabLoadPhase.offline;
      case SuccessLabFailureKind.forbidden:
        return LabLoadPhase.forbidden;
      case SuccessLabFailureKind.featureDisabled:
        return LabLoadPhase.featureDisabled;
      case SuccessLabFailureKind.notFound:
      case SuccessLabFailureKind.conflict:
      case SuccessLabFailureKind.invalidPayload:
      case SuccessLabFailureKind.server:
      case SuccessLabFailureKind.unknown:
        return LabLoadPhase.error;
    }
  }
}
