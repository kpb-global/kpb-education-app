import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/success_lab.dart';
import '../repositories/success_lab_repository.dart';

enum SuccessLabSubmissionPhase {
  initial,
  loading,
  ready,
  grantingConsent,
  uploading,
  submitting,
  attachingEvidence,
  success,
  offline,
  unavailable,
  error,
}

/// Volatile, online-only submission workflow. File paths, consent receipts,
/// evidence identifiers and idempotency keys never enter cache or outbox.
class SuccessLabSubmissionController extends ChangeNotifier {
  SuccessLabSubmissionController({
    required SuccessLabRepository repository,
    required this.workspaceId,
    String Function()? keyFactory,
  })  : _repository = repository,
        _keyFactory = keyFactory ?? _newKey;

  final SuccessLabRepository _repository;
  final String workspaceId;
  final String Function() _keyFactory;

  SuccessLabSubmissionPhase phase = SuccessLabSubmissionPhase.initial;
  List<SuccessLabApplicationSubmission> submissions =
      const <SuccessLabApplicationSubmission>[];
  SuccessLabAiNotice? consentNotice;
  SuccessLabFailure? failure;
  int workspaceVersion = 0;
  String? selectedFilePath;
  String? selectedFileName;
  bool consentAccepted = false;
  double uploadProgress = 0;
  SuccessLabApplicationSubmission? confirmedSubmission;

  String? _consentReceiptId;
  SuccessLabOutcomeEvidence? _evidence;
  String? _evidenceIdempotencyKey;
  String? _submissionIdempotencyKey;
  String? _submissionFingerprint;
  final Map<String, String> _complementKeys = <String, String>{};

  static String _newKey() => const Uuid().v4();

  bool get isBusy => switch (phase) {
        SuccessLabSubmissionPhase.grantingConsent ||
        SuccessLabSubmissionPhase.uploading ||
        SuccessLabSubmissionPhase.submitting ||
        SuccessLabSubmissionPhase.attachingEvidence =>
          true,
        _ => false,
      };

  Future<void> load({String language = 'fr'}) async {
    phase = SuccessLabSubmissionPhase.loading;
    failure = null;
    notifyListeners();
    if (!_repository.canUseNetwork) {
      phase = SuccessLabSubmissionPhase.offline;
      notifyListeners();
      return;
    }
    try {
      final access = await _repository.fetchAccess();
      if (!access.enabled ||
          !(access.outcomeEvidenceEnabled ||
              access.outcomeEvidenceAvailable ||
              access.outcomeEvidenceRequiresConsent)) {
        phase = SuccessLabSubmissionPhase.unavailable;
        notifyListeners();
        return;
      }
      final workspace = await _repository.fetchWorkspace(workspaceId);
      final history = await _repository.fetchSubmissions(workspaceId);
      final notice = await _repository.fetchOutcomeEvidenceConsentNotice(
        workspaceId: workspaceId,
        language: language == 'en' ? 'en' : 'fr',
      );
      workspaceVersion = workspace.version;
      submissions = history.items;
      consentNotice = notice;
      phase = SuccessLabSubmissionPhase.ready;
    } catch (error) {
      failure = SuccessLabRepository.normalizeFailure(error);
      phase = _phaseForFailure(failure!);
    }
    notifyListeners();
  }

  void selectEvidenceFile({required String path, required String name}) {
    if (isBusy || path.trim().isEmpty || name.trim().isEmpty) return;
    selectedFilePath = path;
    selectedFileName = name;
    _evidence = null;
    _evidenceIdempotencyKey = null;
    _submissionIdempotencyKey = null;
    _submissionFingerprint = null;
    uploadProgress = 0;
    failure = null;
    notifyListeners();
  }

  void setConsentAccepted(bool value) {
    if (isBusy) return;
    consentAccepted = value;
    if (!value) _consentReceiptId = null;
    failure = null;
    notifyListeners();
  }

  Future<void> declareSubmission({
    required DateTime submittedAt,
    String? submissionChannel,
    String? applicationReference,
  }) async {
    if (!_validateReadyForEvidence()) return;
    final notice = consentNotice!;
    final filePath = selectedFilePath!;
    try {
      _consentReceiptId ??= await _grantConsent(notice);
      phase = SuccessLabSubmissionPhase.uploading;
      uploadProgress = 0;
      notifyListeners();
      _evidenceIdempotencyKey ??= _keyFactory();
      _evidence ??= await _repository.uploadOutcomeEvidence(
        workspaceId: workspaceId,
        kind: SuccessLabOutcomeEvidenceKind.submissionConfirmation,
        filePath: filePath,
        consentReceiptId: _consentReceiptId!,
        idempotencyKey: _evidenceIdempotencyKey!,
        onProgress: _setUploadProgress,
      );
      phase = SuccessLabSubmissionPhase.submitting;
      notifyListeners();
      final fingerprint = <String>[
        workspaceVersion.toString(),
        submittedAt.toUtc().toIso8601String(),
        submissionChannel?.trim() ?? '',
        applicationReference?.trim() ?? '',
        _evidence!.id,
      ].join('|');
      if (_submissionFingerprint != fingerprint) {
        _submissionFingerprint = fingerprint;
        _submissionIdempotencyKey = _keyFactory();
      }
      final result = await _repository.createSubmission(
        workspaceId: workspaceId,
        expectedWorkspaceVersion: workspaceVersion,
        submittedAt: submittedAt,
        submissionChannel: submissionChannel,
        applicationReference: applicationReference,
        evidenceId: _evidence!.id,
        idempotencyKey: _submissionIdempotencyKey!,
      );
      confirmedSubmission = result.submission;
      workspaceVersion = result.workspace.version;
      submissions = <SuccessLabApplicationSubmission>[
        result.submission,
        ...submissions.where((item) => item.id != result.submission.id),
      ];
      _clearPrivateIntent();
      phase = SuccessLabSubmissionPhase.success;
    } catch (error) {
      failure = SuccessLabRepository.normalizeFailure(error);
      if (failure!.kind == SuccessLabFailureKind.conflict) {
        // A CAS conflict is a new payload intent, not a transport retry.
        _submissionIdempotencyKey = null;
        _submissionFingerprint = null;
        await _refreshWorkspaceVersion();
      }
      phase = _phaseForFailure(failure!);
    }
    notifyListeners();
  }

  Future<void> attachEvidenceToSubmission({
    required SuccessLabApplicationSubmission submission,
    required String filePath,
  }) async {
    if (submission.verificationStatus !=
        SuccessLabEvidenceVerificationStatus.needsInformation) {
      failure = const SuccessLabFailure(
        kind: SuccessLabFailureKind.conflict,
        code: 'OUTCOME_COMPLEMENT_NOT_REQUESTED',
        retryable: false,
      );
      notifyListeners();
      return;
    }
    if (!consentAccepted ||
        consentNotice == null ||
        !_repository.canUseNetwork) {
      failure = const SuccessLabFailure(
        kind: SuccessLabFailureKind.forbidden,
        code: 'OUTCOME_EVIDENCE_REQUIRED',
        retryable: false,
      );
      notifyListeners();
      return;
    }
    final intentKey = 'submission:${submission.id}:$filePath';
    try {
      _consentReceiptId ??= await _grantConsent(consentNotice!);
      phase = SuccessLabSubmissionPhase.uploading;
      notifyListeners();
      final evidence = await _repository.uploadOutcomeEvidence(
        workspaceId: workspaceId,
        kind: SuccessLabOutcomeEvidenceKind.submissionConfirmation,
        filePath: filePath,
        consentReceiptId: _consentReceiptId!,
        idempotencyKey: _complementKeys.putIfAbsent(
          'upload:$intentKey',
          _keyFactory,
        ),
        onProgress: _setUploadProgress,
      );
      phase = SuccessLabSubmissionPhase.attachingEvidence;
      notifyListeners();
      await _repository.attachOutcomeEvidence(
        outcomeType: 'submission',
        outcomeId: submission.id,
        expectedVersion: submission.lockVersion,
        evidenceId: evidence.id,
        idempotencyKey: _complementKeys.putIfAbsent(
          'attach:$intentKey',
          _keyFactory,
        ),
      );
      _complementKeys.remove('upload:$intentKey');
      _complementKeys.remove('attach:$intentKey');
      final refreshed = await _repository.fetchSubmissions(workspaceId);
      submissions = refreshed.items;
      phase = SuccessLabSubmissionPhase.ready;
    } catch (error) {
      failure = SuccessLabRepository.normalizeFailure(error);
      phase = _phaseForFailure(failure!);
    }
    notifyListeners();
  }

  Future<String> _grantConsent(SuccessLabAiNotice notice) async {
    phase = SuccessLabSubmissionPhase.grantingConsent;
    notifyListeners();
    return _repository.grantOutcomeEvidenceConsent(
      workspaceId: workspaceId,
      notice: notice,
    );
  }

  bool _validateReadyForEvidence() {
    if (!_repository.canUseNetwork) {
      failure = const SuccessLabFailure(
        kind: SuccessLabFailureKind.offline,
        code: 'OFFLINE',
        retryable: true,
      );
      phase = SuccessLabSubmissionPhase.offline;
    } else if (workspaceVersion < 1 || consentNotice == null) {
      failure = const SuccessLabFailure(
        kind: SuccessLabFailureKind.invalidPayload,
        code: 'INVALID_PAYLOAD',
        retryable: false,
      );
    } else if (!consentAccepted) {
      failure = const SuccessLabFailure(
        kind: SuccessLabFailureKind.forbidden,
        code: 'OUTCOME_EVIDENCE_REQUIRED',
        retryable: false,
      );
    } else if (selectedFilePath?.trim().isEmpty != false) {
      failure = const SuccessLabFailure(
        kind: SuccessLabFailureKind.invalidPayload,
        code: 'OUTCOME_EVIDENCE_REQUIRED',
        retryable: false,
      );
    } else {
      failure = null;
      return true;
    }
    notifyListeners();
    return false;
  }

  void _setUploadProgress(int sent, int total) {
    uploadProgress = total <= 0 ? 0 : (sent / total).clamp(0, 1);
    notifyListeners();
  }

  Future<void> _refreshWorkspaceVersion() async {
    try {
      workspaceVersion =
          (await _repository.fetchWorkspace(workspaceId)).version;
    } catch (_) {
      // Preserve the original actionable failure.
    }
  }

  SuccessLabSubmissionPhase _phaseForFailure(SuccessLabFailure value) {
    return switch (value.kind) {
      SuccessLabFailureKind.offline => SuccessLabSubmissionPhase.offline,
      SuccessLabFailureKind.featureDisabled ||
      SuccessLabFailureKind.forbidden ||
      SuccessLabFailureKind.notFound =>
        SuccessLabSubmissionPhase.unavailable,
      _ => SuccessLabSubmissionPhase.error,
    };
  }

  void _clearPrivateIntent() {
    selectedFilePath = null;
    selectedFileName = null;
    _consentReceiptId = null;
    _evidence = null;
    _evidenceIdempotencyKey = null;
    _submissionIdempotencyKey = null;
    _submissionFingerprint = null;
    uploadProgress = 0;
    consentAccepted = false;
  }
}
