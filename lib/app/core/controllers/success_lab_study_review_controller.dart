import 'package:flutter/foundation.dart';

import '../models/success_lab.dart';
import '../repositories/success_lab_repository.dart';

enum SuccessLabStudyReviewPhase {
  initial,
  loading,
  ready,
  uploading,
  submitting,
  complementing,
  submitted,
  tracking,
  unavailable,
  offline,
  error,
}

class SuccessLabStudyReviewController extends ChangeNotifier {
  SuccessLabStudyReviewController({
    required SuccessLabRepository repository,
    required this.workspaceId,
    required this.language,
  }) : _repository = repository;

  final SuccessLabRepository _repository;
  final String workspaceId;
  final String language;

  SuccessLabStudyReviewPhase phase = SuccessLabStudyReviewPhase.initial;
  SuccessLabAiNotice? notice;
  List<SuccessLabArtifact> artifacts = const <SuccessLabArtifact>[];
  Set<String> selectedVersionIds = <String>{};
  SuccessLabStudyReviewRequest? request;
  SuccessLabFailure? failure;
  double uploadProgress = 0;
  String? _consentReceiptId;
  String? _consentNoticeContentHash;
  final Set<String> deletingVersionIds = <String>{};

  bool isDeletingVersion(String versionId) =>
      deletingVersionIds.contains(versionId);
  bool get canDeleteVersions =>
      phase == SuccessLabStudyReviewPhase.ready && _repository.canUseNetwork;
  bool get isComplementMode =>
      request?.status == SuccessLabStudyReviewStatus.moreInformationNeeded;
  bool get canUploadDocument =>
      phase == SuccessLabStudyReviewPhase.ready ||
      (phase == SuccessLabStudyReviewPhase.tracking && isComplementMode);
  Set<String> get newComplementVersionIds {
    final shared = request?.sharedVersionIds.toSet() ?? <String>{};
    return selectedVersionIds.difference(shared);
  }

  Future<void> load() async {
    phase = SuccessLabStudyReviewPhase.loading;
    failure = null;
    notifyListeners();
    if (!_repository.canUseNetwork) {
      phase = SuccessLabStudyReviewPhase.offline;
      notifyListeners();
      return;
    }
    try {
      final access = await _repository.fetchAccess();
      if (!access.enabled || !access.counsellorStudyEnabled) {
        phase = SuccessLabStudyReviewPhase.unavailable;
      } else {
        final active = await _repository.fetchActiveStudyReview(workspaceId);
        request = active;
        if (active != null && !active.canProvideMoreInformation) {
          notice = null;
          artifacts = const <SuccessLabArtifact>[];
          selectedVersionIds.clear();
          phase = SuccessLabStudyReviewPhase.tracking;
          notifyListeners();
          return;
        }
        final values = await Future.wait<Object>([
          _repository.fetchStudyReviewNotice(language: language),
          _repository.fetchArtifacts(workspaceId),
        ]);
        final refreshedNotice = values[0] as SuccessLabAiNotice;
        if (_consentNoticeContentHash != null &&
            _consentNoticeContentHash != refreshedNotice.contentHash) {
          _consentReceiptId = null;
          _consentNoticeContentHash = null;
        }
        notice = refreshedNotice;
        artifacts = values[1] as List<SuccessLabArtifact>;
        final cleanVersionIds = artifacts
            .expand((artifact) => artifact.versions)
            .where((version) => version.isClean)
            .map((version) => version.id)
            .toSet();
        selectedVersionIds = active == null
            ? artifacts
                .map((artifact) => artifact.currentVersion?.id)
                .whereType<String>()
                .toSet()
            : active.sharedVersionIds.where(cleanVersionIds.contains).toSet();
        phase = active == null
            ? SuccessLabStudyReviewPhase.ready
            : SuccessLabStudyReviewPhase.tracking;
      }
    } catch (error) {
      _setFailure(error);
    }
    notifyListeners();
  }

  void toggleVersion(String versionId, bool selected) {
    if (selected) {
      selectedVersionIds.add(versionId);
    } else {
      selectedVersionIds.remove(versionId);
    }
    notifyListeners();
  }

  Future<void> upload({
    required bool consentAccepted,
    String? acceptedNoticeContentHash,
    required String kind,
    required String title,
    required String filePath,
  }) async {
    if (!canUploadDocument) {
      failure = const SuccessLabFailure(
        kind: SuccessLabFailureKind.conflict,
        code: 'REVIEW_REQUEST_NOT_TRIAGED',
        retryable: false,
      );
      notifyListeners();
      return;
    }
    final returnToTracking = isComplementMode;
    if (!await _ensureConsent(
      consentAccepted,
      acceptedNoticeContentHash: acceptedNoticeContentHash,
    )) {
      return;
    }
    phase = SuccessLabStudyReviewPhase.uploading;
    uploadProgress = 0;
    failure = null;
    notifyListeners();
    try {
      final version = await _repository.uploadArtifact(
        workspaceId: workspaceId,
        kind: kind,
        title: title,
        filePath: filePath,
        onProgress: (sent, total) {
          uploadProgress = total <= 0 ? 0 : (sent / total).clamp(0, 1);
          notifyListeners();
        },
      );
      artifacts = await _repository.fetchArtifacts(workspaceId);
      selectedVersionIds.add(version.id);
      phase = returnToTracking
          ? SuccessLabStudyReviewPhase.tracking
          : SuccessLabStudyReviewPhase.ready;
    } catch (error) {
      failure = SuccessLabRepository.normalizeFailure(error);
      phase = returnToTracking
          ? SuccessLabStudyReviewPhase.tracking
          : failure!.kind == SuccessLabFailureKind.offline
              ? SuccessLabStudyReviewPhase.offline
              : SuccessLabStudyReviewPhase.error;
    }
    notifyListeners();
  }

  Future<void> submit({
    required bool consentAccepted,
    String? acceptedNoticeContentHash,
    String? studentMessage,
  }) async {
    if (request != null || phase != SuccessLabStudyReviewPhase.ready) {
      failure = const SuccessLabFailure(
        kind: SuccessLabFailureKind.conflict,
        code: 'REVIEW_REQUEST_ALREADY_OPEN',
        retryable: false,
      );
      notifyListeners();
      return;
    }
    if (selectedVersionIds.isEmpty) {
      failure = const SuccessLabFailure(
        kind: SuccessLabFailureKind.invalidPayload,
        code: 'EVIDENCE_REJECTED',
        retryable: false,
      );
      notifyListeners();
      return;
    }
    if (!await _ensureConsent(
      consentAccepted,
      acceptedNoticeContentHash: acceptedNoticeContentHash,
    )) {
      return;
    }
    phase = SuccessLabStudyReviewPhase.submitting;
    failure = null;
    notifyListeners();
    try {
      request = await _repository.createStudyReview(
        workspaceId: workspaceId,
        artifactVersionIds: selectedVersionIds.toList(growable: false),
        consentReceiptId: _consentReceiptId!,
        studentMessage: studentMessage,
      );
      phase = SuccessLabStudyReviewPhase.tracking;
    } catch (error) {
      final normalized = SuccessLabRepository.normalizeFailure(error);
      if (normalized.code == 'REVIEW_REQUEST_ALREADY_OPEN') {
        try {
          request = await _repository.fetchActiveStudyReview(workspaceId);
          if (request != null) {
            failure = null;
            phase = SuccessLabStudyReviewPhase.tracking;
          } else {
            failure = normalized;
            phase = SuccessLabStudyReviewPhase.error;
          }
        } catch (_) {
          failure = normalized;
          phase = SuccessLabStudyReviewPhase.error;
        }
      } else {
        _setFailure(normalized);
      }
    }
    notifyListeners();
  }

  Future<void> submitComplement({
    required bool consentAccepted,
    String? acceptedNoticeContentHash,
    String? studentMessage,
  }) async {
    final active = request;
    if (active == null || !active.canProvideMoreInformation) {
      failure = const SuccessLabFailure(
        kind: SuccessLabFailureKind.conflict,
        code: 'REVIEW_REQUEST_NOT_TRIAGED',
        retryable: false,
      );
      notifyListeners();
      return;
    }
    final message = studentMessage?.trim();
    final hasNewVersions = newComplementVersionIds.isNotEmpty;
    if ((message == null || message.isEmpty) && !hasNewVersions) {
      failure = const SuccessLabFailure(
        kind: SuccessLabFailureKind.invalidPayload,
        code: 'INVALID_PAYLOAD',
        retryable: false,
      );
      notifyListeners();
      return;
    }
    if (hasNewVersions &&
        !await _ensureConsent(
          consentAccepted,
          acceptedNoticeContentHash: acceptedNoticeContentHash,
        )) {
      return;
    }
    phase = SuccessLabStudyReviewPhase.complementing;
    failure = null;
    notifyListeners();
    try {
      request = await _repository.submitStudyReviewComplement(
        reviewRequest: active,
        studentMessage: message,
        // The backend treats artifactVersionIds as the full replacement set.
        // Include every still-clean existing share whenever a new version is
        // added, otherwise old shares would be silently revoked.
        artifactVersionIds: hasNewVersions
            ? selectedVersionIds.toList(growable: false)
            : const <String>[],
        consentReceiptId: hasNewVersions ? _consentReceiptId : null,
      );
      selectedVersionIds.clear();
      phase = SuccessLabStudyReviewPhase.tracking;
    } catch (error) {
      failure = SuccessLabRepository.normalizeFailure(error);
      if (failure!.retryable) {
        // PATCH is not replayed blindly. A detail read can prove that the
        // server accepted a response lost in transit.
        try {
          final refreshed = await _repository.fetchStudyReview(active.id);
          if (refreshed.version > active.version &&
              refreshed.status == SuccessLabStudyReviewStatus.submitted) {
            request = refreshed;
            selectedVersionIds.clear();
            failure = null;
          }
        } catch (_) {
          // Keep the original transport failure; the next explicit refresh
          // resumes from server truth.
        }
      }
      phase = SuccessLabStudyReviewPhase.tracking;
    }
    notifyListeners();
  }

  Future<void> deleteVersion(String versionId) async {
    if (deletingVersionIds.contains(versionId)) return;
    if (!_repository.canUseNetwork) {
      failure = const SuccessLabFailure(
        kind: SuccessLabFailureKind.offline,
        code: 'OFFLINE',
        retryable: true,
      );
      phase = SuccessLabStudyReviewPhase.offline;
      notifyListeners();
      return;
    }

    deletingVersionIds.add(versionId);
    failure = null;
    notifyListeners();
    try {
      await _repository.deleteArtifactVersion(
        versionId: versionId,
        reason: 'student_removed_before_review',
      );
      artifacts = await _repository.fetchArtifacts(workspaceId);
      final remainingCleanIds = artifacts
          .expand((artifact) => artifact.versions)
          .where((version) => version.isClean)
          .map((version) => version.id)
          .toSet();
      selectedVersionIds.retainAll(remainingCleanIds);
      phase = SuccessLabStudyReviewPhase.ready;
    } catch (error) {
      failure = SuccessLabRepository.normalizeFailure(error);
      if (failure!.code == 'FORBIDDEN_SCOPE') {
        // Keep the document list usable and explain that an open review owns
        // the immutable share. Never hide or auto-delete another version.
        phase = SuccessLabStudyReviewPhase.ready;
      } else {
        phase = failure!.kind == SuccessLabFailureKind.offline
            ? SuccessLabStudyReviewPhase.offline
            : SuccessLabStudyReviewPhase.error;
      }
    } finally {
      deletingVersionIds.remove(versionId);
      notifyListeners();
    }
  }

  Future<bool> _ensureConsent(
    bool accepted, {
    required String? acceptedNoticeContentHash,
  }) async {
    final currentNotice = notice;
    if (_consentReceiptId != null &&
        currentNotice != null &&
        _consentNoticeContentHash == currentNotice.contentHash) {
      return true;
    }
    if (!accepted ||
        currentNotice == null ||
        acceptedNoticeContentHash == null ||
        acceptedNoticeContentHash != currentNotice.contentHash) {
      failure = const SuccessLabFailure(
        kind: SuccessLabFailureKind.forbidden,
        code: 'ADVISOR_DOCUMENT_SHARE_CONSENT_REQUIRED',
        retryable: false,
      );
      notifyListeners();
      return false;
    }
    try {
      _consentReceiptId =
          await _repository.grantStudyReviewConsent(currentNotice);
      _consentNoticeContentHash = currentNotice.contentHash;
      return true;
    } catch (error) {
      _setFailure(error);
      notifyListeners();
      return false;
    }
  }

  void _setFailure(Object error) {
    failure = SuccessLabRepository.normalizeFailure(error);
    phase = failure!.kind == SuccessLabFailureKind.offline
        ? SuccessLabStudyReviewPhase.offline
        : SuccessLabStudyReviewPhase.error;
  }
}
