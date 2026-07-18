import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/success_lab.dart';
import '../repositories/success_lab_repository.dart';

enum SuccessLabOutcomePhase {
  initial,
  loading,
  ready,
  grantingConsent,
  uploading,
  submittingAdmission,
  submittingFunding,
  attachingEvidence,
  success,
  offline,
  unavailable,
  error,
}

/// Online-only controller for institution decisions declared by the student.
/// Admission, funding and KPB verification stay independent at every layer.
class SuccessLabOutcomeController extends ChangeNotifier {
  SuccessLabOutcomeController({
    required SuccessLabRepository repository,
    required this.workspaceId,
    String Function()? keyFactory,
  })  : _repository = repository,
        _keyFactory = keyFactory ?? _newKey;

  final SuccessLabRepository _repository;
  final String workspaceId;
  final String Function() _keyFactory;

  SuccessLabOutcomePhase phase = SuccessLabOutcomePhase.initial;
  SuccessLabDecisionHistory history = const SuccessLabDecisionHistory(
    admissions: <SuccessLabAdmissionDecisionRecord>[],
    funding: <SuccessLabFundingDecisionRecord>[],
    workspaceVersion: 0,
  );
  SuccessLabAiNotice? consentNotice;
  SuccessLabFailure? failure;
  bool consentAccepted = false;
  double uploadProgress = 0;

  String? admissionFilePath;
  String? admissionFileName;
  String? fundingFilePath;
  String? fundingFileName;

  String? _consentReceiptId;
  SuccessLabOutcomeEvidence? _admissionEvidence;
  SuccessLabOutcomeEvidence? _fundingEvidence;
  String? _admissionUploadKey;
  String? _admissionMutationKey;
  String? _admissionMutationFingerprint;
  SuccessLabOutcomeEvidenceKind? _admissionUploadedKind;
  String? _fundingUploadKey;
  String? _fundingMutationKey;
  String? _fundingMutationFingerprint;
  SuccessLabOutcomeEvidenceKind? _fundingUploadedKind;
  final Map<String, String> _complementKeys = <String, String>{};

  static String _newKey() => const Uuid().v4();

  bool get isBusy => switch (phase) {
        SuccessLabOutcomePhase.grantingConsent ||
        SuccessLabOutcomePhase.uploading ||
        SuccessLabOutcomePhase.submittingAdmission ||
        SuccessLabOutcomePhase.submittingFunding ||
        SuccessLabOutcomePhase.attachingEvidence =>
          true,
        _ => false,
      };

  Future<void> load({String language = 'fr'}) async {
    phase = SuccessLabOutcomePhase.loading;
    failure = null;
    notifyListeners();
    if (!_repository.canUseNetwork) {
      phase = SuccessLabOutcomePhase.offline;
      notifyListeners();
      return;
    }
    try {
      final access = await _repository.fetchAccess();
      if (!access.enabled ||
          !(access.outcomeEvidenceEnabled ||
              access.outcomeEvidenceAvailable ||
              access.outcomeEvidenceRequiresConsent)) {
        phase = SuccessLabOutcomePhase.unavailable;
        notifyListeners();
        return;
      }
      history = await _repository.fetchDecisions(workspaceId);
      consentNotice = await _repository.fetchOutcomeEvidenceConsentNotice(
        workspaceId: workspaceId,
        language: language == 'en' ? 'en' : 'fr',
      );
      phase = SuccessLabOutcomePhase.ready;
    } catch (error) {
      failure = SuccessLabRepository.normalizeFailure(error);
      phase = _phaseForFailure(failure!);
    }
    notifyListeners();
  }

  void setConsentAccepted(bool value) {
    if (isBusy) return;
    consentAccepted = value;
    if (!value) _consentReceiptId = null;
    failure = null;
    notifyListeners();
  }

  void selectAdmissionEvidence({required String path, required String name}) {
    if (isBusy || path.trim().isEmpty || name.trim().isEmpty) return;
    admissionFilePath = path;
    admissionFileName = name;
    _admissionEvidence = null;
    _admissionUploadKey = null;
    _admissionMutationKey = null;
    _admissionMutationFingerprint = null;
    failure = null;
    notifyListeners();
  }

  void selectFundingEvidence({required String path, required String name}) {
    if (isBusy || path.trim().isEmpty || name.trim().isEmpty) return;
    fundingFilePath = path;
    fundingFileName = name;
    _fundingEvidence = null;
    _fundingUploadKey = null;
    _fundingMutationKey = null;
    _fundingMutationFingerprint = null;
    failure = null;
    notifyListeners();
  }

  Future<void> declareAdmission({
    required String issuedByName,
    required SuccessLabAdmissionDecision decision,
    required DateTime receivedAt,
    DateTime? issuedAt,
  }) async {
    final filePath = admissionFilePath;
    if (!_validateEvidenceIntent(filePath)) return;
    try {
      _consentReceiptId ??= await _grantConsent();
      phase = SuccessLabOutcomePhase.uploading;
      uploadProgress = 0;
      notifyListeners();
      final evidenceKind = _admissionEvidenceKind(decision);
      if (_admissionUploadedKind != evidenceKind) {
        _admissionEvidence = null;
        _admissionUploadKey = null;
        _admissionUploadedKind = evidenceKind;
      }
      _admissionUploadKey ??= _keyFactory();
      _admissionEvidence ??= await _repository.uploadOutcomeEvidence(
        workspaceId: workspaceId,
        kind: evidenceKind,
        filePath: filePath!,
        consentReceiptId: _consentReceiptId!,
        idempotencyKey: _admissionUploadKey!,
        onProgress: _setUploadProgress,
      );
      phase = SuccessLabOutcomePhase.submittingAdmission;
      notifyListeners();
      final fingerprint = <String>[
        history.workspaceVersion.toString(),
        issuedByName.trim(),
        decision.name,
        receivedAt.toUtc().toIso8601String(),
        issuedAt?.toUtc().toIso8601String() ?? '',
        _admissionEvidence!.id,
      ].join('|');
      if (_admissionMutationFingerprint != fingerprint) {
        _admissionMutationFingerprint = fingerprint;
        _admissionMutationKey = _keyFactory();
      }
      final result = await _repository.createAdmissionDecision(
        workspaceId: workspaceId,
        expectedWorkspaceVersion: history.workspaceVersion,
        issuedByName: issuedByName,
        decision: decision,
        receivedAt: receivedAt,
        issuedAt: issuedAt,
        evidenceId: _admissionEvidence!.id,
        idempotencyKey: _admissionMutationKey!,
      );
      history = SuccessLabDecisionHistory(
        admissions: <SuccessLabAdmissionDecisionRecord>[
          result.decision,
          if (history.currentAdmission != null)
            _asHistorical(history.currentAdmission!),
          ...history.admissions.where(
            (item) => item.id != history.currentAdmission?.id,
          ),
        ],
        funding: history.funding,
        workspaceVersion: result.workspace.version,
      );
      _clearAdmissionIntent();
      phase = SuccessLabOutcomePhase.success;
    } catch (error) {
      failure = SuccessLabRepository.normalizeFailure(error);
      if (failure!.kind == SuccessLabFailureKind.conflict) {
        _admissionMutationKey = null;
        _admissionMutationFingerprint = null;
        await _refreshHistory();
      }
      phase = _phaseForFailure(failure!);
    }
    notifyListeners();
  }

  Future<void> declareFunding({
    required String issuedByName,
    required SuccessLabFundingDecision decision,
    required DateTime receivedAt,
    DateTime? issuedAt,
    String? fundingAmountMinor,
    String? fundingCurrency,
  }) async {
    final filePath = fundingFilePath;
    if (!_validateEvidenceIntent(filePath)) return;
    final hasAmount = fundingAmountMinor?.trim().isNotEmpty == true;
    final hasCurrency = fundingCurrency?.trim().isNotEmpty == true;
    final allowsAmount = decision == SuccessLabFundingDecision.full ||
        decision == SuccessLabFundingDecision.partial;
    if (hasAmount != hasCurrency ||
        (!allowsAmount && hasAmount) ||
        (hasAmount &&
            (!RegExp(r'^[1-9]\d*$').hasMatch(fundingAmountMinor!.trim()) ||
                !RegExp(r'^[A-Za-z]{3}$').hasMatch(fundingCurrency!.trim())))) {
      failure = const SuccessLabFailure(
        kind: SuccessLabFailureKind.invalidPayload,
        code: 'INVALID_FUNDING_AMOUNT',
        retryable: false,
      );
      notifyListeners();
      return;
    }
    try {
      _consentReceiptId ??= await _grantConsent();
      phase = SuccessLabOutcomePhase.uploading;
      uploadProgress = 0;
      notifyListeners();
      final evidenceKind = _fundingEvidenceKind(decision);
      if (_fundingUploadedKind != evidenceKind) {
        _fundingEvidence = null;
        _fundingUploadKey = null;
        _fundingUploadedKind = evidenceKind;
      }
      _fundingUploadKey ??= _keyFactory();
      _fundingEvidence ??= await _repository.uploadOutcomeEvidence(
        workspaceId: workspaceId,
        kind: evidenceKind,
        filePath: filePath!,
        consentReceiptId: _consentReceiptId!,
        idempotencyKey: _fundingUploadKey!,
        onProgress: _setUploadProgress,
      );
      phase = SuccessLabOutcomePhase.submittingFunding;
      notifyListeners();
      final fingerprint = <String>[
        history.workspaceVersion.toString(),
        history.currentAdmission?.id ?? '',
        issuedByName.trim(),
        decision.name,
        receivedAt.toUtc().toIso8601String(),
        issuedAt?.toUtc().toIso8601String() ?? '',
        fundingAmountMinor?.trim() ?? '',
        fundingCurrency?.trim().toUpperCase() ?? '',
        _fundingEvidence!.id,
      ].join('|');
      if (_fundingMutationFingerprint != fingerprint) {
        _fundingMutationFingerprint = fingerprint;
        _fundingMutationKey = _keyFactory();
      }
      final result = await _repository.createFundingDecision(
        workspaceId: workspaceId,
        expectedWorkspaceVersion: history.workspaceVersion,
        admissionDecisionId: history.currentAdmission?.id,
        issuedByName: issuedByName,
        decision: decision,
        receivedAt: receivedAt,
        issuedAt: issuedAt,
        fundingAmountMinor: hasAmount ? fundingAmountMinor!.trim() : null,
        fundingCurrency:
            hasCurrency ? fundingCurrency!.trim().toUpperCase() : null,
        evidenceId: _fundingEvidence!.id,
        idempotencyKey: _fundingMutationKey!,
      );
      history = SuccessLabDecisionHistory(
        admissions: history.admissions,
        funding: <SuccessLabFundingDecisionRecord>[
          result.decision,
          if (history.currentFunding != null)
            _asHistoricalFunding(history.currentFunding!),
          ...history.funding.where(
            (item) => item.id != history.currentFunding?.id,
          ),
        ],
        workspaceVersion: result.workspace.version,
      );
      _clearFundingIntent();
      phase = SuccessLabOutcomePhase.success;
    } catch (error) {
      failure = SuccessLabRepository.normalizeFailure(error);
      if (failure!.kind == SuccessLabFailureKind.conflict) {
        _fundingMutationKey = null;
        _fundingMutationFingerprint = null;
        await _refreshHistory();
      }
      phase = _phaseForFailure(failure!);
    }
    notifyListeners();
  }

  Future<void> attachEvidence({
    required String outcomeType,
    required String outcomeId,
    required int lockVersion,
    required SuccessLabOutcomeEvidenceKind kind,
    required String filePath,
    required SuccessLabEvidenceVerificationStatus verificationStatus,
  }) async {
    if (verificationStatus !=
        SuccessLabEvidenceVerificationStatus.needsInformation) {
      failure = const SuccessLabFailure(
        kind: SuccessLabFailureKind.conflict,
        code: 'OUTCOME_COMPLEMENT_NOT_REQUESTED',
        retryable: false,
      );
      notifyListeners();
      return;
    }
    if (!_validateEvidenceIntent(filePath)) return;
    final intent = '$outcomeType:$outcomeId:$filePath';
    try {
      _consentReceiptId ??= await _grantConsent();
      phase = SuccessLabOutcomePhase.uploading;
      notifyListeners();
      final evidence = await _repository.uploadOutcomeEvidence(
        workspaceId: workspaceId,
        kind: kind,
        filePath: filePath,
        consentReceiptId: _consentReceiptId!,
        idempotencyKey: _complementKeys.putIfAbsent(
          'upload:$intent',
          _keyFactory,
        ),
        onProgress: _setUploadProgress,
      );
      phase = SuccessLabOutcomePhase.attachingEvidence;
      notifyListeners();
      await _repository.attachOutcomeEvidence(
        outcomeType: outcomeType,
        outcomeId: outcomeId,
        expectedVersion: lockVersion,
        evidenceId: evidence.id,
        idempotencyKey: _complementKeys.putIfAbsent(
          'attach:$intent',
          _keyFactory,
        ),
      );
      _complementKeys.remove('upload:$intent');
      _complementKeys.remove('attach:$intent');
      await _refreshHistory();
      phase = SuccessLabOutcomePhase.ready;
    } catch (error) {
      failure = SuccessLabRepository.normalizeFailure(error);
      phase = _phaseForFailure(failure!);
    }
    notifyListeners();
  }

  Future<String> _grantConsent() async {
    phase = SuccessLabOutcomePhase.grantingConsent;
    notifyListeners();
    return _repository.grantOutcomeEvidenceConsent(
      workspaceId: workspaceId,
      notice: consentNotice!,
    );
  }

  bool _validateEvidenceIntent(String? filePath) {
    if (!_repository.canUseNetwork) {
      failure = const SuccessLabFailure(
        kind: SuccessLabFailureKind.offline,
        code: 'OFFLINE',
        retryable: true,
      );
      phase = SuccessLabOutcomePhase.offline;
    } else if (history.workspaceVersion < 1 || consentNotice == null) {
      failure = const SuccessLabFailure(
        kind: SuccessLabFailureKind.invalidPayload,
        code: 'INVALID_PAYLOAD',
        retryable: false,
      );
    } else if (!consentAccepted || filePath?.trim().isEmpty != false) {
      failure = const SuccessLabFailure(
        kind: SuccessLabFailureKind.forbidden,
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

  SuccessLabOutcomeEvidenceKind _admissionEvidenceKind(
    SuccessLabAdmissionDecision decision,
  ) {
    return switch (decision) {
      SuccessLabAdmissionDecision.admitted =>
        SuccessLabOutcomeEvidenceKind.admissionDecision,
      SuccessLabAdmissionDecision.rejected =>
        SuccessLabOutcomeEvidenceKind.rejectionDecision,
      SuccessLabAdmissionDecision.waitlisted =>
        SuccessLabOutcomeEvidenceKind.waitlistDecision,
      SuccessLabAdmissionDecision.deferred ||
      SuccessLabAdmissionDecision.withdrawn ||
      SuccessLabAdmissionDecision.unknown =>
        SuccessLabOutcomeEvidenceKind.other,
    };
  }

  SuccessLabOutcomeEvidenceKind _fundingEvidenceKind(
    SuccessLabFundingDecision decision,
  ) {
    return switch (decision) {
      SuccessLabFundingDecision.full ||
      SuccessLabFundingDecision.partial =>
        SuccessLabOutcomeEvidenceKind.fundingAward,
      SuccessLabFundingDecision.none =>
        SuccessLabOutcomeEvidenceKind.fundingRejection,
      SuccessLabFundingDecision.pending ||
      SuccessLabFundingDecision.notApplicable ||
      SuccessLabFundingDecision.unknown =>
        SuccessLabOutcomeEvidenceKind.other,
    };
  }

  Future<void> _refreshHistory() async {
    try {
      history = await _repository.fetchDecisions(workspaceId);
    } catch (_) {
      // Preserve the original mutation failure.
    }
  }

  void _setUploadProgress(int sent, int total) {
    uploadProgress = total <= 0 ? 0 : (sent / total).clamp(0, 1);
    notifyListeners();
  }

  SuccessLabOutcomePhase _phaseForFailure(SuccessLabFailure value) {
    return switch (value.kind) {
      SuccessLabFailureKind.offline => SuccessLabOutcomePhase.offline,
      SuccessLabFailureKind.featureDisabled ||
      SuccessLabFailureKind.forbidden ||
      SuccessLabFailureKind.notFound =>
        SuccessLabOutcomePhase.unavailable,
      _ => SuccessLabOutcomePhase.error,
    };
  }

  SuccessLabAdmissionDecisionRecord _asHistorical(
    SuccessLabAdmissionDecisionRecord value,
  ) {
    return SuccessLabAdmissionDecisionRecord(
      id: value.id,
      workspaceId: value.workspaceId,
      supersedesId: value.supersedesId,
      version: value.version,
      lockVersion: value.lockVersion,
      isCurrent: false,
      issuedByName: value.issuedByName,
      decision: value.decision,
      decisionWireValue: value.decisionWireValue,
      issuedAt: value.issuedAt,
      receivedAt: value.receivedAt,
      hasEvidence: value.hasEvidence,
      verificationStatus: value.verificationStatus,
      verificationStatusWireValue: value.verificationStatusWireValue,
      verificationNotes: value.verificationNotes,
      verifiedAt: value.verifiedAt,
      createdAt: value.createdAt,
      updatedAt: value.updatedAt,
    );
  }

  SuccessLabFundingDecisionRecord _asHistoricalFunding(
    SuccessLabFundingDecisionRecord value,
  ) {
    return SuccessLabFundingDecisionRecord(
      id: value.id,
      workspaceId: value.workspaceId,
      admissionDecisionId: value.admissionDecisionId,
      supersedesId: value.supersedesId,
      version: value.version,
      lockVersion: value.lockVersion,
      isCurrent: false,
      issuedByName: value.issuedByName,
      decision: value.decision,
      decisionWireValue: value.decisionWireValue,
      fundingAmountMinor: value.fundingAmountMinor,
      fundingCurrency: value.fundingCurrency,
      issuedAt: value.issuedAt,
      receivedAt: value.receivedAt,
      hasEvidence: value.hasEvidence,
      verificationStatus: value.verificationStatus,
      verificationStatusWireValue: value.verificationStatusWireValue,
      verificationNotes: value.verificationNotes,
      verifiedAt: value.verifiedAt,
      createdAt: value.createdAt,
      updatedAt: value.updatedAt,
    );
  }

  void _clearAdmissionIntent() {
    admissionFilePath = null;
    admissionFileName = null;
    _admissionEvidence = null;
    _admissionUploadKey = null;
    _admissionMutationKey = null;
    _admissionMutationFingerprint = null;
    _admissionUploadedKind = null;
    _clearSharedPrivateState();
  }

  void _clearFundingIntent() {
    fundingFilePath = null;
    fundingFileName = null;
    _fundingEvidence = null;
    _fundingUploadKey = null;
    _fundingMutationKey = null;
    _fundingMutationFingerprint = null;
    _fundingUploadedKind = null;
    _clearSharedPrivateState();
  }

  void _clearSharedPrivateState() {
    _consentReceiptId = null;
    consentAccepted = false;
    uploadProgress = 0;
  }
}
