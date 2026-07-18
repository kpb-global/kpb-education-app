import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

import '../config/app_config.dart';
import '../data/success_lab_api_codec.dart';
import '../models/success_lab.dart';
import '../services/connectivity_service.dart';
import '../services/success_lab_cache_service.dart';
import '../services/success_lab_outbox.dart';
import 'app_api_client.dart';

enum SuccessLabFailureKind {
  offline,
  forbidden,
  featureDisabled,
  conflict,
  notFound,
  invalidPayload,
  server,
  unknown,
}

class SuccessLabFailure implements Exception {
  const SuccessLabFailure({
    required this.kind,
    required this.code,
    required this.retryable,
    this.message,
  });

  final SuccessLabFailureKind kind;
  final String code;
  final bool retryable;
  final String? message;

  @override
  String toString() => 'SuccessLabFailure($code)';
}

class SuccessLabMutationResult {
  const SuccessLabMutationResult({
    this.workspace,
    this.failure,
    this.queued = false,
  });

  final SuccessLabWorkspace? workspace;
  final SuccessLabFailure? failure;
  final bool queued;

  bool get succeeded => workspace != null && failure == null;
}

class SuccessLabRetryResult {
  const SuccessLabRetryResult({
    required this.sent,
    required this.queued,
    required this.failed,
    this.latestWorkspace,
  });

  final int sent;
  final int queued;
  final int failed;
  final SuccessLabWorkspace? latestWorkspace;
}

/// Authenticated API/cache/outbox orchestration for Success Lab.
class SuccessLabRepository {
  SuccessLabRepository({
    required this.apiClient,
    required this.cache,
    required this.outbox,
    required this.userId,
    bool? remoteEnabled,
    bool Function()? isOnline,
    Future<void> Function(Duration)? delay,
    String Function()? mutationIdFactory,
    DateTime Function()? now,
  })  : remoteEnabled = remoteEnabled ?? AppConfig.enableRemoteSync,
        _isOnline = isOnline ?? (() => ConnectivityService.instance.isOnline),
        _delay = delay ?? Future<void>.delayed,
        _mutationIdFactory = mutationIdFactory ?? _newMutationId,
        _now = now ?? DateTime.now {
    if (userId.trim().isEmpty) {
      throw ArgumentError.value(userId, 'userId', 'Must not be empty.');
    }
  }

  factory SuccessLabRepository.standard({
    required AppApiClient apiClient,
    required String userId,
  }) {
    return SuccessLabRepository(
      apiClient: apiClient,
      cache: SuccessLabCacheService(userId: userId),
      outbox: SuccessLabOutbox(userId: userId),
      userId: userId,
    );
  }

  final AppApiClient apiClient;
  final SuccessLabCacheStore cache;
  final SuccessLabOutboxStore outbox;
  final String userId;
  final bool remoteEnabled;
  final bool Function() _isOnline;
  final Future<void> Function(Duration) _delay;
  final String Function() _mutationIdFactory;
  final DateTime Function() _now;

  static String _newMutationId() => const Uuid().v4();

  bool get canUseNetwork => remoteEnabled && _isOnline();

  Future<SuccessLabCachedValue<SuccessLabAccess>?> readCachedAccess() =>
      cache.readAccess();

  Future<SuccessLabCachedValue<SuccessLabWorkspacePage>?> readCachedPage({
    String? status,
  }) =>
      cache.readPage(status: status);

  Future<SuccessLabCachedValue<SuccessLabWorkspace>?> readCachedWorkspace(
    String workspaceId,
  ) =>
      cache.readWorkspace(workspaceId);

  Future<SuccessLabAccess> fetchAccess() async {
    _requireNetwork();
    try {
      final raw = await _withRetry(apiClient.getSuccessLabAccess);
      final access = SuccessLabApiCodec.accessFromApi(raw);
      await cache.writeAccess(access);
      return access;
    } catch (error) {
      throw normalizeFailure(error);
    }
  }

  Future<SuccessLabWorkspacePage> fetchPage({
    String? status,
    String? cursor,
    int limit = 20,
  }) async {
    _requireNetwork();
    try {
      final raw = await _withRetry(
        () => apiClient.listSuccessLabWorkspaces(
          status: status,
          cursor: cursor,
          limit: limit.clamp(1, 50),
        ),
      );
      final page = SuccessLabApiCodec.workspacePageFromApi(raw);
      if (cursor == null || cursor.isEmpty) {
        await cache.writePage(page, status: status);
      }
      return page;
    } catch (error) {
      throw normalizeFailure(error);
    }
  }

  Future<SuccessLabWorkspace> fetchWorkspace(String workspaceId) async {
    _requireNetwork();
    try {
      final raw = await _withRetry(
        () => apiClient.getSuccessLabWorkspace(workspaceId),
      );
      final workspace = SuccessLabApiCodec.workspaceFromApi(raw);
      await cache.writeWorkspace(workspace);
      return workspace;
    } catch (error) {
      throw normalizeFailure(error);
    }
  }

  Future<SuccessLabWorkspace> createWorkspace({
    required String scholarshipId,
    required String cycleId,
    String? clientMutationId,
  }) async {
    _requireNetwork();
    final mutationId = clientMutationId ?? _mutationIdFactory();
    try {
      final raw = await _withRetry(
        () => apiClient.createSuccessLabWorkspace(
          scholarshipId: scholarshipId,
          cycleId: cycleId,
          idempotencyKey: mutationId,
        ),
      );
      final workspace = SuccessLabApiCodec.workspaceFromApi(raw);
      await cache.writeWorkspace(workspace);
      return workspace;
    } catch (error) {
      throw normalizeFailure(error);
    }
  }

  Future<SuccessLabAiNotice> fetchAiNotice({
    required String language,
  }) async {
    _requireNetwork();
    try {
      final raw = await _withRetry(
        () => apiClient.getSuccessLabAiNotice(language: language),
      );
      return SuccessLabApiCodec.aiNoticeFromApi(raw);
    } catch (error) {
      throw normalizeFailure(error);
    }
  }

  Future<void> grantAiConsent(SuccessLabAiNotice notice) async {
    _requireNetwork();
    try {
      await _withRetry(
        () => apiClient.grantSuccessLabAiConsent(
          languageCode: notice.languageCode,
          noticeVersion: notice.version,
        ),
      );
      await fetchAccess();
    } catch (error) {
      throw normalizeFailure(error);
    }
  }

  Future<SuccessLabDiagnosticEnvelope> fetchDiagnostic(
    String workspaceId,
  ) async {
    _requireNetwork();
    try {
      final raw = await _withRetry(
        () => apiClient.getSuccessLabDiagnostic(workspaceId),
      );
      return SuccessLabApiCodec.diagnosticEnvelopeFromApi(raw);
    } catch (error) {
      throw normalizeFailure(error);
    }
  }

  Future<SuccessLabDiagnostic> createDiagnostic({
    required String workspaceId,
    required String language,
    String? applicationExcerpt,
    String? clientMutationId,
  }) async {
    _requireNetwork();
    final mutationId = clientMutationId ?? _mutationIdFactory();
    try {
      final raw = await _withRetry(
        () => apiClient.createSuccessLabDiagnostic(
          workspaceId: workspaceId,
          language: language,
          idempotencyKey: mutationId,
          applicationExcerpt: applicationExcerpt,
        ),
      );
      return SuccessLabApiCodec.diagnosticFromApi(raw);
    } catch (error) {
      throw normalizeFailure(error);
    }
  }

  Future<SuccessLabAiNotice> fetchStudyReviewNotice({
    required String language,
  }) async {
    _requireNetwork();
    try {
      final raw = await _withRetry(
        () => apiClient.getSuccessLabStudyReviewNotice(language: language),
      );
      return SuccessLabApiCodec.aiNoticeFromApi(raw);
    } catch (error) {
      throw normalizeFailure(error);
    }
  }

  Future<String> grantStudyReviewConsent(SuccessLabAiNotice notice) async {
    _requireNetwork();
    try {
      final raw = await _withRetry(
        () => apiClient.grantSuccessLabStudyReviewConsent(
          languageCode: notice.languageCode,
          noticeVersion: notice.version,
        ),
      );
      final receiptId = raw['receiptId'];
      if (receiptId is! String || receiptId.trim().isEmpty) {
        throw const FormatException('Missing study-review consent receipt.');
      }
      return receiptId;
    } catch (error) {
      throw normalizeFailure(error);
    }
  }

  Future<List<SuccessLabArtifact>> fetchArtifacts(String workspaceId) async {
    _requireNetwork();
    try {
      final raw = await _withRetry(
        () => apiClient.listSuccessLabArtifacts(workspaceId),
      );
      return SuccessLabApiCodec.artifactsFromApi(raw);
    } catch (error) {
      throw normalizeFailure(error);
    }
  }

  Future<SuccessLabArtifactVersion> uploadArtifact({
    required String workspaceId,
    required String kind,
    required String title,
    required String filePath,
    void Function(int sent, int total)? onProgress,
  }) async {
    _requireNetwork();
    final file = File(filePath);
    if (!await file.exists()) {
      throw const SuccessLabFailure(
        kind: SuccessLabFailureKind.invalidPayload,
        code: 'FILE_NOT_FOUND',
        retryable: false,
      );
    }
    final fileName = file.uri.pathSegments.last;
    final mimeType = _artifactMimeType(fileName);
    if (mimeType == null) {
      throw const SuccessLabFailure(
        kind: SuccessLabFailureKind.invalidPayload,
        code: 'ARTIFACT_KIND_NOT_ALLOWED',
        retryable: false,
      );
    }
    final sizeBytes = await file.length();
    if (sizeBytes <= 0 || sizeBytes > 10 * 1024 * 1024) {
      throw const SuccessLabFailure(
        kind: SuccessLabFailureKind.invalidPayload,
        code: 'ARTIFACT_TOO_LARGE',
        retryable: false,
      );
    }
    final digest = await sha256.bind(file.openRead()).first;
    final idempotencyKey = _mutationIdFactory();
    try {
      final intent = await _withRetry(
        () => apiClient.createSuccessLabArtifactUploadIntent(
          workspaceId: workspaceId,
          kind: kind,
          title: title,
          originalFileName: fileName,
          mimeType: mimeType,
          sizeBytes: sizeBytes,
          sha256: digest.toString(),
          idempotencyKey: idempotencyKey,
        ),
      );
      final version = intent['version'];
      if (version is! Map || version['id'] is! String) {
        throw const FormatException('Invalid artifact upload intent.');
      }
      final versionId = version['id'] as String;
      await _withRetry(
        () => apiClient.completeSuccessLabArtifactUpload(
          versionId: versionId,
          filePath: filePath,
          fileName: fileName,
          onProgress: onProgress,
        ),
      );
      final artifacts = await fetchArtifacts(workspaceId);
      for (final artifact in artifacts) {
        for (final candidate in artifact.versions) {
          if (candidate.id == versionId && candidate.isClean) return candidate;
        }
      }
      throw const FormatException('Uploaded artifact is not clean.');
    } catch (error) {
      throw normalizeFailure(error);
    }
  }

  /// Deletes only the explicitly selected version. The backend refuses a
  /// version that is already shared with an open counsellor review.
  Future<void> deleteArtifactVersion({
    required String versionId,
    required String reason,
  }) async {
    _requireNetwork();
    if (versionId.trim().isEmpty || reason.trim().isEmpty) {
      throw const SuccessLabFailure(
        kind: SuccessLabFailureKind.invalidPayload,
        code: 'INVALID_PAYLOAD',
        retryable: false,
      );
    }
    try {
      await _withRetry(
        () => apiClient.deleteSuccessLabArtifactVersion(
          versionId: versionId,
          reason: reason.trim(),
        ),
      );
    } catch (error) {
      throw normalizeFailure(error);
    }
  }

  Future<SuccessLabStudyReviewRequest> createStudyReview({
    required String workspaceId,
    required List<String> artifactVersionIds,
    required String consentReceiptId,
    String? studentMessage,
  }) async {
    _requireNetwork();
    if (artifactVersionIds.isEmpty) {
      throw const SuccessLabFailure(
        kind: SuccessLabFailureKind.invalidPayload,
        code: 'EVIDENCE_REJECTED',
        retryable: false,
      );
    }
    final idempotencyKey = _mutationIdFactory();
    try {
      final raw = await _withRetry(
        () => apiClient.createSuccessLabStudyReview(
          workspaceId: workspaceId,
          artifactVersionIds: artifactVersionIds,
          consentReceiptId: consentReceiptId,
          idempotencyKey: idempotencyKey,
          studentMessage: studentMessage,
        ),
      );
      return SuccessLabApiCodec.studyReviewFromApi(raw);
    } catch (error) {
      throw normalizeFailure(error);
    }
  }

  /// Fetches the server-owned active request so the workflow resumes after an
  /// app restart without persisting private review data on the device.
  Future<SuccessLabStudyReviewRequest?> fetchActiveStudyReview(
    String workspaceId,
  ) async {
    _requireNetwork();
    try {
      final raw = await _withRetry(
        () => apiClient.getActiveSuccessLabStudyReview(workspaceId),
      );
      return SuccessLabApiCodec.activeStudyReviewFromApi(raw);
    } catch (error) {
      throw normalizeFailure(error);
    }
  }

  Future<SuccessLabStudyReviewRequest> fetchStudyReview(
    String reviewRequestId,
  ) async {
    _requireNetwork();
    try {
      final raw = await _withRetry(
        () => apiClient.getSuccessLabStudyReview(reviewRequestId),
      );
      return SuccessLabApiCodec.studyReviewFromApi(raw);
    } catch (error) {
      throw normalizeFailure(error);
    }
  }

  /// Complements an already-triaged request. This intentionally bypasses the
  /// offline outbox: messages and document references are private, and PATCH
  /// is CAS-protected rather than idempotency-key protected.
  Future<SuccessLabStudyReviewRequest> submitStudyReviewComplement({
    required SuccessLabStudyReviewRequest reviewRequest,
    String? studentMessage,
    List<String> artifactVersionIds = const <String>[],
    String? consentReceiptId,
  }) async {
    _requireNetwork();
    if (!reviewRequest.canProvideMoreInformation) {
      throw const SuccessLabFailure(
        kind: SuccessLabFailureKind.conflict,
        code: 'REVIEW_REQUEST_NOT_TRIAGED',
        retryable: false,
      );
    }
    final message = studentMessage?.trim();
    if ((message == null || message.isEmpty) && artifactVersionIds.isEmpty) {
      throw const SuccessLabFailure(
        kind: SuccessLabFailureKind.invalidPayload,
        code: 'INVALID_PAYLOAD',
        retryable: false,
      );
    }
    if (artifactVersionIds.isNotEmpty &&
        (consentReceiptId == null || consentReceiptId.trim().isEmpty)) {
      throw const SuccessLabFailure(
        kind: SuccessLabFailureKind.forbidden,
        code: 'ADVISOR_DOCUMENT_SHARE_CONSENT_REQUIRED',
        retryable: false,
      );
    }
    try {
      final raw = await apiClient.updateSuccessLabStudyReview(
        reviewRequestId: reviewRequest.id,
        expectedVersion: reviewRequest.version,
        studentMessage: message,
        artifactVersionIds:
            artifactVersionIds.isEmpty ? null : artifactVersionIds,
        consentReceiptId: artifactVersionIds.isEmpty ? null : consentReceiptId,
      );
      return SuccessLabApiCodec.studyReviewFromApi(raw);
    } catch (error) {
      throw normalizeFailure(error);
    }
  }

  Future<SuccessLabStudyReviewSlotOffers> fetchStudyReviewSlotOffers(
    String reviewRequestId,
  ) async {
    _requireNetwork();
    try {
      final raw = await _withRetry(
        () => apiClient.listSuccessLabStudyReviewSlotOffers(reviewRequestId),
      );
      final envelope = SuccessLabApiCodec.studyReviewSlotOffersFromApi(raw);
      if (envelope.reviewRequestId != reviewRequestId) {
        throw const FormatException('Slot offers belong to another request.');
      }
      final now = _now().toUtc();
      return SuccessLabStudyReviewSlotOffers(
        reviewRequestId: envelope.reviewRequestId,
        reviewRequestVersion: envelope.reviewRequestVersion,
        timezone: envelope.timezone,
        offers: List<SuccessLabStudyReviewSlotOffer>.unmodifiable(
          envelope.offers.where((offer) => offer.isBookableAt(now)),
        ),
      );
    } catch (error) {
      throw normalizeFailure(error);
    }
  }

  /// Books online only. Both keys are created by the volatile controller and
  /// reused unchanged by every transport retry; neither enters cache/outbox.
  Future<SuccessLabStudyReviewBookingResult> bookStudyReviewAppointment({
    required String reviewRequestId,
    required int expectedVersion,
    required String slotOfferId,
    required String bookingKey,
    required String timezone,
    required String idempotencyKey,
  }) async {
    _requireNetwork();
    if (<String>[
      reviewRequestId,
      slotOfferId,
      bookingKey,
      timezone,
      idempotencyKey,
    ].any((value) => value.trim().isEmpty)) {
      throw const SuccessLabFailure(
        kind: SuccessLabFailureKind.invalidPayload,
        code: 'INVALID_PAYLOAD',
        retryable: false,
      );
    }
    try {
      final raw = await _withRetry(
        () => apiClient.bookSuccessLabStudyReviewAppointment(
          reviewRequestId: reviewRequestId,
          expectedVersion: expectedVersion,
          slotOfferId: slotOfferId,
          bookingKey: bookingKey,
          timezone: timezone,
          idempotencyKey: idempotencyKey,
        ),
      );
      final result = SuccessLabApiCodec.studyReviewBookingFromApi(raw);
      if (!result.isServerConfirmed ||
          result.reviewRequestId != reviewRequestId ||
          result.appointment.reviewRequestId != reviewRequestId ||
          result.appointment.slotOfferId != slotOfferId) {
        throw const FormatException(
          'Appointment was not confirmed by the server.',
        );
      }
      return result;
    } catch (error) {
      throw normalizeFailure(error);
    }
  }

  Future<SuccessLabSubmissionHistory> fetchSubmissions(
    String workspaceId,
  ) async {
    _requireNetwork();
    try {
      final raw = await _withRetry(
        () => apiClient.listSuccessLabSubmissions(workspaceId),
      );
      return SuccessLabApiCodec.submissionHistoryFromApi(raw);
    } catch (error) {
      throw normalizeFailure(error);
    }
  }

  Future<SuccessLabDecisionHistory> fetchDecisions(String workspaceId) async {
    _requireNetwork();
    try {
      final raw = await _withRetry(
        () => apiClient.listSuccessLabDecisions(workspaceId),
      );
      return SuccessLabApiCodec.decisionHistoryFromApi(raw);
    } catch (error) {
      throw normalizeFailure(error);
    }
  }

  Future<SuccessLabAiNotice> fetchOutcomeEvidenceConsentNotice({
    required String workspaceId,
    required String language,
  }) async {
    _requireNetwork();
    try {
      final raw = await _withRetry(
        () => apiClient.getSuccessLabOutcomeConsentNotice(
          workspaceId: workspaceId,
          language: language,
        ),
      );
      return SuccessLabApiCodec.aiNoticeFromApi(raw);
    } catch (error) {
      throw normalizeFailure(error);
    }
  }

  Future<String> grantOutcomeEvidenceConsent({
    required String workspaceId,
    required SuccessLabAiNotice notice,
  }) async {
    _requireNetwork();
    try {
      final raw = await _withRetry(
        () => apiClient.grantSuccessLabOutcomeConsent(
          workspaceId: workspaceId,
          languageCode: notice.languageCode,
          noticeVersion: notice.version,
        ),
      );
      final receiptId = raw['receiptId'];
      if (receiptId is! String || receiptId.trim().isEmpty) {
        throw const FormatException('Missing outcome consent receipt.');
      }
      return receiptId.trim();
    } catch (error) {
      throw normalizeFailure(error);
    }
  }

  /// Outcome files and identifiers are handled in memory only. This flow is
  /// deliberately online-only and never touches the Success Lab cache/outbox.
  Future<SuccessLabOutcomeEvidence> uploadOutcomeEvidence({
    required String workspaceId,
    required SuccessLabOutcomeEvidenceKind kind,
    required String filePath,
    required String consentReceiptId,
    required String idempotencyKey,
    void Function(int sent, int total)? onProgress,
  }) async {
    _requireNetwork();
    if (consentReceiptId.trim().isEmpty || idempotencyKey.trim().isEmpty) {
      throw const SuccessLabFailure(
        kind: SuccessLabFailureKind.forbidden,
        code: 'OUTCOME_EVIDENCE_CONSENT_REQUIRED',
        retryable: false,
      );
    }
    final file = File(filePath);
    if (!await file.exists()) {
      throw const SuccessLabFailure(
        kind: SuccessLabFailureKind.invalidPayload,
        code: 'FILE_NOT_FOUND',
        retryable: false,
      );
    }
    final fileName = file.uri.pathSegments.last;
    final mimeType = _artifactMimeType(fileName);
    if (mimeType == null) {
      throw const SuccessLabFailure(
        kind: SuccessLabFailureKind.invalidPayload,
        code: 'ARTIFACT_KIND_NOT_ALLOWED',
        retryable: false,
      );
    }
    final sizeBytes = await file.length();
    if (sizeBytes <= 0 || sizeBytes > 10 * 1024 * 1024) {
      throw const SuccessLabFailure(
        kind: SuccessLabFailureKind.invalidPayload,
        code: 'ARTIFACT_TOO_LARGE',
        retryable: false,
      );
    }
    final digest = await sha256.bind(file.openRead()).first;
    try {
      final intent = await _withRetry(
        () => apiClient.createSuccessLabOutcomeEvidenceUploadIntent(
          workspaceId: workspaceId,
          kind: SuccessLabApiCodec.encodeOutcomeEvidenceKind(kind),
          originalFileName: fileName,
          mimeType: mimeType,
          sizeBytes: sizeBytes,
          sha256: digest.toString(),
          consentReceiptId: consentReceiptId,
          idempotencyKey: idempotencyKey,
        ),
      );
      final rawEvidence = intent['evidence'] ?? intent['asset'] ?? intent;
      final evidence = SuccessLabApiCodec.outcomeEvidenceFromApi(rawEvidence);
      if (evidence.workspaceId != workspaceId) {
        throw const FormatException('Evidence belongs to another workspace.');
      }
      final completeRaw = await _withRetry(
        () => apiClient.completeSuccessLabOutcomeEvidenceUpload(
          evidenceId: evidence.id,
          filePath: filePath,
          fileName: fileName,
          onProgress: onProgress,
        ),
      );
      final completed = SuccessLabApiCodec.outcomeEvidenceFromApi(
        completeRaw['evidence'] ?? completeRaw['asset'] ?? completeRaw,
      );
      if (completed.id != evidence.id || completed.workspaceId != workspaceId) {
        throw const FormatException(
            'Completed evidence does not match intent.');
      }
      if (!completed.isClean) {
        throw const SuccessLabFailure(
          kind: SuccessLabFailureKind.conflict,
          code: 'EVIDENCE_SCAN_PENDING',
          retryable: true,
        );
      }
      return completed;
    } catch (error) {
      throw normalizeFailure(error);
    }
  }

  Future<SuccessLabSubmissionMutation> createSubmission({
    required String workspaceId,
    required int expectedWorkspaceVersion,
    required DateTime submittedAt,
    required String idempotencyKey,
    String? submissionChannel,
    String? applicationReference,
    String? evidenceId,
  }) async {
    _requireNetwork();
    _requireOutcomeMutation(idempotencyKey, evidenceId);
    try {
      final raw = await _withRetry(
        () => apiClient.createSuccessLabSubmission(
          workspaceId: workspaceId,
          expectedWorkspaceVersion: expectedWorkspaceVersion,
          submittedAt: submittedAt,
          submissionChannel: submissionChannel,
          applicationReference: applicationReference,
          evidenceId: evidenceId,
          idempotencyKey: idempotencyKey,
        ),
      );
      final submission = SuccessLabApiCodec.applicationSubmissionFromApi(
        raw['submission'],
      );
      final workspace = SuccessLabApiCodec.workspaceMutationSummaryFromApi(
        raw['workspace'],
      );
      if (submission.workspaceId != workspaceId ||
          workspace.id != workspaceId) {
        throw const FormatException('Submission belongs to another workspace.');
      }
      return SuccessLabSubmissionMutation(
        submission: submission,
        workspace: workspace,
      );
    } catch (error) {
      throw normalizeFailure(error);
    }
  }

  Future<SuccessLabAdmissionMutation> createAdmissionDecision({
    required String workspaceId,
    required int expectedWorkspaceVersion,
    required String issuedByName,
    required SuccessLabAdmissionDecision decision,
    required DateTime receivedAt,
    required String idempotencyKey,
    DateTime? issuedAt,
    String? evidenceId,
  }) async {
    _requireNetwork();
    _requireOutcomeMutation(idempotencyKey, evidenceId);
    try {
      final raw = await _withRetry(
        () => apiClient.createSuccessLabAdmissionDecision(
          workspaceId: workspaceId,
          expectedWorkspaceVersion: expectedWorkspaceVersion,
          issuedByName: issuedByName,
          admissionDecision:
              SuccessLabApiCodec.encodeAdmissionDecision(decision),
          receivedAt: receivedAt,
          issuedAt: issuedAt,
          evidenceId: evidenceId,
          idempotencyKey: idempotencyKey,
        ),
      );
      final record = SuccessLabApiCodec.admissionDecisionFromApi(
        raw['decision'],
      );
      final workspace = SuccessLabApiCodec.workspaceMutationSummaryFromApi(
        raw['workspace'],
      );
      if (record.workspaceId != workspaceId ||
          workspace.id != workspaceId ||
          !record.isCurrent) {
        throw const FormatException(
          'Admission decision was not server-confirmed as current.',
        );
      }
      return SuccessLabAdmissionMutation(
        decision: record,
        workspace: workspace,
      );
    } catch (error) {
      throw normalizeFailure(error);
    }
  }

  Future<SuccessLabFundingMutation> createFundingDecision({
    required String workspaceId,
    required int expectedWorkspaceVersion,
    required String issuedByName,
    required SuccessLabFundingDecision decision,
    required DateTime receivedAt,
    required String idempotencyKey,
    DateTime? issuedAt,
    String? evidenceId,
    String? admissionDecisionId,
    String? fundingAmountMinor,
    String? fundingCurrency,
  }) async {
    _requireNetwork();
    _requireOutcomeMutation(idempotencyKey, evidenceId);
    try {
      final raw = await _withRetry(
        () => apiClient.createSuccessLabFundingDecision(
          workspaceId: workspaceId,
          expectedWorkspaceVersion: expectedWorkspaceVersion,
          issuedByName: issuedByName,
          fundingDecision: SuccessLabApiCodec.encodeFundingDecision(decision),
          receivedAt: receivedAt,
          issuedAt: issuedAt,
          evidenceId: evidenceId,
          admissionDecisionId: admissionDecisionId,
          fundingAmountMinor: fundingAmountMinor,
          fundingCurrency: fundingCurrency,
          idempotencyKey: idempotencyKey,
        ),
      );
      final record = SuccessLabApiCodec.fundingDecisionFromApi(
        raw['decision'],
      );
      final workspace = SuccessLabApiCodec.workspaceMutationSummaryFromApi(
        raw['workspace'],
      );
      if (record.workspaceId != workspaceId ||
          workspace.id != workspaceId ||
          !record.isCurrent) {
        throw const FormatException(
          'Funding decision was not server-confirmed as current.',
        );
      }
      return SuccessLabFundingMutation(
        decision: record,
        workspace: workspace,
      );
    } catch (error) {
      throw normalizeFailure(error);
    }
  }

  Future<void> attachOutcomeEvidence({
    required String outcomeType,
    required String outcomeId,
    required int expectedVersion,
    required String evidenceId,
    required String idempotencyKey,
  }) async {
    _requireNetwork();
    _requireOutcomeMutation(idempotencyKey, evidenceId);
    if (!const <String>{'submission', 'admission', 'funding'}
        .contains(outcomeType)) {
      throw const SuccessLabFailure(
        kind: SuccessLabFailureKind.invalidPayload,
        code: 'INVALID_OUTCOME_TYPE',
        retryable: false,
      );
    }
    try {
      await _withRetry(
        () => apiClient.attachSuccessLabOutcomeEvidence(
          outcomeType: outcomeType,
          outcomeId: outcomeId,
          expectedVersion: expectedVersion,
          evidenceId: evidenceId,
          idempotencyKey: idempotencyKey,
        ),
      );
    } catch (error) {
      throw normalizeFailure(error);
    }
  }

  void _requireOutcomeMutation(String idempotencyKey, String? evidenceId) {
    if (idempotencyKey.trim().isEmpty || evidenceId?.trim().isEmpty != false) {
      throw const SuccessLabFailure(
        kind: SuccessLabFailureKind.invalidPayload,
        code: 'OUTCOME_EVIDENCE_REQUIRED',
        retryable: false,
      );
    }
  }

  String? _artifactMimeType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    if (lower.endsWith('.png')) return 'image/png';
    return null;
  }

  /// Persists first, then sends. A lost response or app termination therefore
  /// reuses the same `clientMutationId` and cannot apply the transition twice.
  Future<SuccessLabMutationResult> updateStep({
    required SuccessLabWorkspace workspace,
    required SuccessLabWorkspaceStep step,
    required SuccessLabWorkspaceStepStatus status,
    String? notApplicableReason,
  }) async {
    if (status == SuccessLabWorkspaceStepStatus.unknown) {
      throw ArgumentError.value(status, 'status', 'Cannot mutate unknown.');
    }
    final mutation = SuccessLabPendingMutation(
      clientMutationId: _mutationIdFactory(),
      userId: userId,
      action: SuccessLabMutationAction.updateStep,
      workspaceId: workspace.id,
      stepId: step.id,
      status: status,
      baseVersion: workspace.version,
      notApplicableReason: notApplicableReason,
      createdAt: DateTime.now().toUtc(),
    );
    await outbox.enqueue(mutation);
    if (!canUseNetwork) {
      return const SuccessLabMutationResult(queued: true);
    }
    return _flushOne(mutation);
  }

  Future<List<SuccessLabPendingMutation>> pendingMutations({
    String? workspaceId,
  }) =>
      outbox.pending(workspaceId: workspaceId);

  Future<SuccessLabRetryResult> retryPending({String? workspaceId}) async {
    final entries = await outbox.pending(workspaceId: workspaceId);
    if (!canUseNetwork) {
      return SuccessLabRetryResult(
        sent: 0,
        queued: entries.where((entry) => !entry.permanentlyFailed).length,
        failed: entries.where((entry) => entry.permanentlyFailed).length,
      );
    }

    var sent = 0;
    var queued = 0;
    var failed = 0;
    SuccessLabWorkspace? latest;
    for (final entry in entries) {
      if (entry.permanentlyFailed) {
        failed++;
        continue;
      }
      final result = await _flushOne(entry);
      if (result.succeeded) {
        sent++;
        latest = result.workspace;
      } else if (result.queued) {
        queued++;
      } else {
        failed++;
      }
    }
    return SuccessLabRetryResult(
      sent: sent,
      queued: queued,
      failed: failed,
      latestWorkspace: latest,
    );
  }

  Future<SuccessLabMutationResult> _flushOne(
    SuccessLabPendingMutation mutation,
  ) async {
    try {
      return await _sendMutation(mutation);
    } catch (error) {
      var failure = normalizeFailure(error);
      if (failure.kind == SuccessLabFailureKind.conflict) {
        final rebased = await _rebaseMutation(mutation);
        if (rebased != null) return rebased;
        failure = const SuccessLabFailure(
          kind: SuccessLabFailureKind.conflict,
          code: 'VERSION_CONFLICT',
          retryable: false,
        );
      }

      await outbox.markAttempt(
        mutation,
        errorCode: failure.code,
        permanentlyFailed: !failure.retryable,
      );
      return SuccessLabMutationResult(
        failure: failure,
        queued: failure.retryable,
      );
    }
  }

  Future<SuccessLabMutationResult> _sendMutation(
    SuccessLabPendingMutation mutation,
  ) async {
    final raw = await _withRetry(
      () => apiClient.updateSuccessLabWorkspaceStep(
        workspaceId: mutation.workspaceId,
        stepId: mutation.stepId,
        status: SuccessLabApiCodec.encodeWorkspaceStepStatus(mutation.status),
        clientMutationId: mutation.clientMutationId,
        expectedVersion: mutation.baseVersion,
        notApplicableReason: mutation.notApplicableReason,
      ),
    );
    final workspace = SuccessLabApiCodec.workspaceFromApi(raw);
    await cache.writeWorkspace(workspace);
    await outbox.remove(mutation.clientMutationId);
    return SuccessLabMutationResult(workspace: workspace);
  }

  Future<SuccessLabMutationResult?> _rebaseMutation(
    SuccessLabPendingMutation mutation,
  ) async {
    try {
      final latest = await fetchWorkspace(mutation.workspaceId);
      final step = latest.steps
          .where((candidate) => candidate.id == mutation.stepId)
          .firstOrNull;
      if (step == null) return null;
      if (step.status == mutation.status) {
        await outbox.remove(mutation.clientMutationId);
        return SuccessLabMutationResult(workspace: latest);
      }
      final rebased = mutation.copyWith(baseVersion: latest.version);
      await outbox.markAttempt(
        mutation,
        errorCode: 'VERSION_CONFLICT',
        rebasedVersion: latest.version,
      );
      return _sendMutation(rebased);
    } catch (_) {
      return null;
    }
  }

  void _requireNetwork() {
    if (!canUseNetwork) {
      throw const SuccessLabFailure(
        kind: SuccessLabFailureKind.offline,
        code: 'OFFLINE',
        retryable: true,
      );
    }
  }

  Future<T> _withRetry<T>(Future<T> Function() request) async {
    Object? lastError;
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        return await request();
      } catch (error) {
        lastError = error;
        final failure = normalizeFailure(error);
        if (!failure.retryable || attempt == 2) rethrow;
        await _delay(Duration(milliseconds: 160 * (1 << attempt)));
      }
    }
    throw lastError ?? StateError('Success Lab request failed.');
  }

  static SuccessLabFailure normalizeFailure(Object error) {
    if (error is SuccessLabFailure) return error;
    if (error is FormatException || error is TypeError) {
      return const SuccessLabFailure(
        kind: SuccessLabFailureKind.invalidPayload,
        code: 'INVALID_PAYLOAD',
        retryable: false,
      );
    }
    if (error is SocketException || error is TimeoutException) {
      return const SuccessLabFailure(
        kind: SuccessLabFailureKind.offline,
        code: 'NETWORK_UNAVAILABLE',
        retryable: true,
      );
    }
    if (error is DioException) {
      final status = error.response?.statusCode;
      final data = error.response?.data;
      final code = data is Map && data['code'] is String
          ? data['code'] as String
          : 'HTTP_${status ?? 0}';
      if (code == 'FEATURE_DISABLED') {
        return SuccessLabFailure(
          kind: SuccessLabFailureKind.featureDisabled,
          code: code,
          retryable: false,
        );
      }
      if (code == 'IDEMPOTENCY_IN_PROGRESS') {
        return SuccessLabFailure(
          kind: SuccessLabFailureKind.server,
          code: code,
          retryable: true,
        );
      }
      if (status == 401 || status == 403 || code == 'FORBIDDEN_SCOPE') {
        return SuccessLabFailure(
          kind: SuccessLabFailureKind.forbidden,
          code: code,
          retryable: false,
        );
      }
      if (status == 409 || code == 'VERSION_CONFLICT') {
        return SuccessLabFailure(
          kind: SuccessLabFailureKind.conflict,
          code: code,
          retryable: false,
        );
      }
      if (status == 404 || code == 'WORKSPACE_NOT_FOUND') {
        return SuccessLabFailure(
          kind: SuccessLabFailureKind.notFound,
          code: code,
          retryable: false,
        );
      }
      final transportFailure = switch (error.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout ||
        DioExceptionType.connectionError =>
          true,
        _ => false,
      };
      if (transportFailure) {
        return SuccessLabFailure(
          kind: SuccessLabFailureKind.offline,
          code: code,
          retryable: true,
        );
      }
      if (status == 429 || (status != null && status >= 500)) {
        return SuccessLabFailure(
          kind: SuccessLabFailureKind.server,
          code: code,
          retryable: true,
        );
      }
      return SuccessLabFailure(
        kind: SuccessLabFailureKind.server,
        code: code,
        retryable: false,
      );
    }
    return SuccessLabFailure(
      kind: SuccessLabFailureKind.unknown,
      code: error.runtimeType.toString(),
      retryable: false,
    );
  }
}
