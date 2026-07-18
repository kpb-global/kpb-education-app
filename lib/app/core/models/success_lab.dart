/// Schema version shared by the first Success Lab workspace contract.
const int successLabWorkspaceSchemaVersionV1 = 1;

enum LabLoadPhase {
  initial,
  loading,
  cached,
  syncing,
  ready,
  empty,
  offline,
  forbidden,
  featureDisabled,
  error,
}

enum MutationPhase {
  idle,
  queuedOffline,
  sending,
  success,
  conflict,
  failed,
}

/// Lifecycle of a scholarship preparation workspace.
///
/// [unknown] is intentionally not a server value. It lets an older app render
/// a conservative state when the backend introduces a new lifecycle value.
enum SuccessLabWorkspaceStatus {
  started,
  preparing,
  readyForReview,
  reviewRequested,
  submitted,
  decisionReceived,
  archived,
  unknown,
}

enum SuccessLabWorkspaceStepStatus {
  notStarted,
  inProgress,
  completed,
  notApplicable,
  unknown,
}

enum SuccessLabWorkspaceStepCategory {
  profileEligibility,
  documents,
  formAndEssays,
  reviewAndSubmission,
  unknown,
}

enum SuccessLabCycleStatus {
  forecast,
  open,
  closed,
  suspended,
  unknown,
}

enum SuccessLabDateConfidence {
  estimated,
  confirmed,
  unknown,
}

/// Fail-closed feature access returned by `/competition-readiness/access`.
///
/// The current backend v1 returns only the global [enabled] decision. Optional
/// nested feature flags are additive: an older response therefore keeps the
/// diagnostic and counsellor-study actions disabled rather than guessing.
class SuccessLabAccess {
  const SuccessLabAccess({
    required this.enabled,
    this.reasons = const <String>[],
    this.maxActiveWorkspaces = 0,
    this.maxPageSize = 20,
    this.aiDiagnosticEnabled = false,
    this.aiDiagnosticAvailable = false,
    this.aiDiagnosticRequiresConsent = false,
    this.counsellorStudyEnabled = false,
    this.outcomeEvidenceEnabled = false,
    this.outcomeEvidenceAvailable = false,
    this.outcomeEvidenceRequiresConsent = false,
  });

  final bool enabled;
  final List<String> reasons;
  final int maxActiveWorkspaces;
  final int maxPageSize;
  final bool aiDiagnosticEnabled;
  final bool aiDiagnosticAvailable;
  final bool aiDiagnosticRequiresConsent;
  final bool counsellorStudyEnabled;
  final bool outcomeEvidenceEnabled;
  final bool outcomeEvidenceAvailable;
  final bool outcomeEvidenceRequiresConsent;
}

enum SuccessLabDiagnosticStatus {
  pending,
  running,
  succeeded,
  deterministicFallback,
  failed,
  blocked,
  unknown,
}

class SuccessLabDiagnosticResult {
  const SuccessLabDiagnosticResult({
    required this.strength,
    required this.priorityImprovement,
    required this.rationale,
    required this.nextAction,
    this.criterionReferences = const <String>[],
  });

  final String strength;
  final String priorityImprovement;
  final String rationale;
  final String nextAction;
  final List<String> criterionReferences;
}

class SuccessLabDiagnostic {
  const SuccessLabDiagnostic({
    required this.id,
    required this.workspaceId,
    required this.status,
    required this.statusWireValue,
    required this.stale,
    required this.promptVersion,
    this.generatedLanguage,
    this.result,
    this.fallbackReason,
    this.completedAt,
    this.reviewAvailable = false,
  });

  final String id;
  final String workspaceId;
  final SuccessLabDiagnosticStatus status;
  final String statusWireValue;
  final String? generatedLanguage;
  final SuccessLabDiagnosticResult? result;
  final bool stale;
  final String promptVersion;
  final String? fallbackReason;
  final DateTime? completedAt;
  final bool reviewAvailable;

  bool get isComplete =>
      status == SuccessLabDiagnosticStatus.succeeded ||
      status == SuccessLabDiagnosticStatus.deterministicFallback;
}

class SuccessLabDiagnosticEnvelope {
  const SuccessLabDiagnosticEnvelope({
    required this.entitlementAvailable,
    this.diagnostic,
  });

  final SuccessLabDiagnostic? diagnostic;
  final bool entitlementAvailable;
}

class SuccessLabAiNotice {
  const SuccessLabAiNotice({
    required this.version,
    required this.languageCode,
    required this.title,
    required this.body,
    required this.contentHash,
  });

  final String version;
  final String languageCode;
  final String title;
  final String body;
  final String contentHash;
}

class SuccessLabArtifactVersion {
  const SuccessLabArtifactVersion({
    required this.id,
    required this.versionNumber,
    required this.originalFileName,
    required this.mimeType,
    required this.sizeBytes,
    required this.processingStatus,
  });

  final String id;
  final int versionNumber;
  final String originalFileName;
  final String mimeType;
  final int sizeBytes;
  final String processingStatus;

  bool get isClean => processingStatus == 'clean';
}

class SuccessLabArtifact {
  const SuccessLabArtifact({
    required this.id,
    required this.kind,
    required this.title,
    required this.versions,
    this.currentVersionId,
  });

  final String id;
  final String kind;
  final String title;
  final String? currentVersionId;
  final List<SuccessLabArtifactVersion> versions;

  SuccessLabArtifactVersion? get currentVersion {
    for (final version in versions) {
      if (version.id == currentVersionId && version.isClean) return version;
    }
    return null;
  }
}

/// Lifecycle returned by the counsellor-study API.
///
/// [unknown] is deliberately fail-closed: a newer server state remains
/// visible, but the app will not expose complement or booking mutations for it.
enum SuccessLabStudyReviewStatus {
  draft,
  submitted,
  triaged,
  moreInformationNeeded,
  callOffered,
  scheduled,
  convertedToCase,
  autonomyRecommended,
  declined,
  closed,
  unknown,
}

enum SuccessLabStudyReviewNextAction {
  completeRequest,
  waitForTriage,
  provideMoreInformation,
  waitForSlotOffer,
  chooseSlot,
  appointmentScheduled,
  caseCreated,
  continueAutonomously,
  none,
  unknown,
}

/// Minimal, display-safe view of an immutable artifact share.
///
/// The response also carries receipt and checksum data. Those are intentionally
/// discarded at the mobile boundary because the student UI does not need them
/// and review data must never enter the cache or offline outbox.
class SuccessLabStudyReviewSharedVersion {
  const SuccessLabStudyReviewSharedVersion({
    required this.shareId,
    required this.artifactVersionId,
    required this.artifactId,
    required this.artifactKind,
    required this.artifactTitle,
    required this.versionNumber,
    required this.originalFileName,
    required this.mimeType,
    required this.sizeBytes,
    required this.processingStatus,
    required this.grantedAt,
    this.revokedAt,
    this.uploadedAt,
  });

  final String shareId;
  final String artifactVersionId;
  final String artifactId;
  final String artifactKind;
  final String artifactTitle;
  final int versionNumber;
  final String originalFileName;
  final String mimeType;
  final int sizeBytes;
  final String processingStatus;
  final DateTime grantedAt;
  final DateTime? revokedAt;
  final DateTime? uploadedAt;
}

class SuccessLabStudyReviewRequest {
  const SuccessLabStudyReviewRequest({
    required this.id,
    required this.workspaceId,
    required this.status,
    required this.statusWireValue,
    required this.nextAction,
    required this.nextActionWireValue,
    required this.requestNumber,
    required this.version,
    required this.timezone,
    required this.missingItems,
    required this.sharedVersions,
    required this.createdAt,
    required this.updatedAt,
    this.studentMessage,
    this.preferredContact,
    this.availability,
    this.submittedAt,
    this.triagedAt,
    this.closedAt,
  });

  final String id;
  final String workspaceId;
  final SuccessLabStudyReviewStatus status;
  final String statusWireValue;
  final SuccessLabStudyReviewNextAction nextAction;
  final String nextActionWireValue;
  final int requestNumber;
  final int version;
  final String? studentMessage;
  final String? preferredContact;
  final String timezone;

  /// Opaque server JSON. It is kept only in memory and is never interpreted as
  /// a fixed list so additive backend availability formats remain compatible.
  final Map<String, Object?>? availability;
  final List<String> missingItems;
  final DateTime? submittedAt;
  final DateTime? triagedAt;
  final DateTime? closedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<SuccessLabStudyReviewSharedVersion> sharedVersions;

  List<SuccessLabStudyReviewSharedVersion> get activeSharedVersions =>
      List<SuccessLabStudyReviewSharedVersion>.unmodifiable(
        sharedVersions.where((share) => share.revokedAt == null),
      );

  List<String> get sharedVersionIds => List<String>.unmodifiable(
        activeSharedVersions.map((share) => share.artifactVersionId),
      );

  bool get canProvideMoreInformation =>
      status == SuccessLabStudyReviewStatus.moreInformationNeeded;

  bool get canChooseSlot =>
      status == SuccessLabStudyReviewStatus.callOffered &&
      nextAction == SuccessLabStudyReviewNextAction.chooseSlot;
}

class SuccessLabStudyReviewSlotOffer {
  const SuccessLabStudyReviewSlotOffer({
    required this.slotOfferId,
    required this.slotId,
    required this.startsAt,
    required this.endsAt,
    required this.timezone,
    required this.expiresAt,
    required this.counsellorName,
  });

  final String slotOfferId;
  final String slotId;
  final DateTime startsAt;
  final DateTime endsAt;
  final String timezone;
  final DateTime expiresAt;
  final String counsellorName;

  bool isBookableAt(DateTime now) {
    final utcNow = now.toUtc();
    return expiresAt.isAfter(utcNow) && startsAt.isAfter(utcNow);
  }
}

class SuccessLabStudyReviewSlotOffers {
  const SuccessLabStudyReviewSlotOffers({
    required this.reviewRequestId,
    required this.reviewRequestVersion,
    required this.timezone,
    required this.offers,
  });

  final String reviewRequestId;
  final int reviewRequestVersion;
  final String timezone;
  final List<SuccessLabStudyReviewSlotOffer> offers;
}

class SuccessLabStudyReviewAppointment {
  const SuccessLabStudyReviewAppointment({
    required this.id,
    required this.reviewRequestId,
    required this.slotOfferId,
    required this.slotId,
    required this.counsellorId,
    required this.startsAt,
    required this.endsAt,
    required this.timezone,
    required this.status,
    required this.contactMethod,
    required this.createdAt,
  });

  final String id;
  final String reviewRequestId;
  final String slotOfferId;
  final String slotId;
  final String counsellorId;
  final DateTime startsAt;
  final DateTime endsAt;
  final String timezone;
  final String status;
  final String contactMethod;
  final DateTime createdAt;
}

class SuccessLabStudyReviewBookingResult {
  const SuccessLabStudyReviewBookingResult({
    required this.appointment,
    required this.reviewRequestId,
    required this.reviewRequestVersion,
    required this.reviewRequestStatus,
  });

  final SuccessLabStudyReviewAppointment appointment;
  final String reviewRequestId;
  final int reviewRequestVersion;
  final SuccessLabStudyReviewStatus reviewRequestStatus;

  bool get isServerConfirmed =>
      appointment.id.isNotEmpty &&
      reviewRequestStatus == SuccessLabStudyReviewStatus.scheduled;
}

/// KPB's verification of student-declared evidence. This status never changes
/// the institution's decision and must always be rendered separately from it.
enum SuccessLabEvidenceVerificationStatus {
  selfReported,
  pending,
  verified,
  needsInformation,
  rejected,
  unknown,
}

enum SuccessLabOutcomeEvidenceKind {
  submissionConfirmation,
  admissionDecision,
  rejectionDecision,
  waitlistDecision,
  fundingAward,
  fundingRejection,
  enrollmentConfirmation,
  other,
  unknown,
}

enum SuccessLabAdmissionDecision {
  admitted,
  rejected,
  waitlisted,
  deferred,
  withdrawn,
  unknown,
}

enum SuccessLabFundingDecision {
  full,
  partial,
  none,
  pending,
  notApplicable,
  unknown,
}

/// Display-safe outcome evidence. Storage keys and SHA-256 values are
/// deliberately absent so they cannot leak into widget state or local caches.
class SuccessLabOutcomeEvidence {
  const SuccessLabOutcomeEvidence({
    required this.id,
    required this.workspaceId,
    required this.kind,
    required this.kindWireValue,
    required this.originalFileName,
    required this.mimeType,
    required this.sizeBytes,
    required this.processingStatus,
    required this.createdAt,
  });

  final String id;
  final String workspaceId;
  final SuccessLabOutcomeEvidenceKind kind;
  final String kindWireValue;
  final String originalFileName;
  final String mimeType;
  final int sizeBytes;
  final String processingStatus;
  final DateTime createdAt;

  bool get isClean => processingStatus == 'clean';
}

class SuccessLabApplicationSubmission {
  const SuccessLabApplicationSubmission({
    required this.id,
    required this.workspaceId,
    required this.version,
    required this.lockVersion,
    required this.submittedAt,
    required this.verificationStatus,
    required this.verificationStatusWireValue,
    required this.createdAt,
    required this.updatedAt,
    this.submissionChannel,
    this.hasApplicationReference = false,
    this.hasEvidence = false,
    this.verificationNotes,
    this.verifiedAt,
  });

  final String id;
  final String workspaceId;
  final int version;
  final int lockVersion;
  final DateTime submittedAt;
  final String? submissionChannel;

  /// The raw application reference/hash and evidence identifier are never
  /// retained by the mobile model. Only their presence is exposed to the UI.
  final bool hasApplicationReference;
  final bool hasEvidence;
  final SuccessLabEvidenceVerificationStatus verificationStatus;
  final String verificationStatusWireValue;
  final String? verificationNotes;
  final DateTime? verifiedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class SuccessLabAdmissionDecisionRecord {
  const SuccessLabAdmissionDecisionRecord({
    required this.id,
    required this.workspaceId,
    required this.version,
    required this.lockVersion,
    required this.isCurrent,
    required this.issuedByName,
    required this.decision,
    required this.decisionWireValue,
    required this.receivedAt,
    required this.hasEvidence,
    required this.verificationStatus,
    required this.verificationStatusWireValue,
    required this.createdAt,
    required this.updatedAt,
    this.supersedesId,
    this.issuedAt,
    this.verificationNotes,
    this.verifiedAt,
  });

  final String id;
  final String workspaceId;
  final String? supersedesId;
  final int version;
  final int lockVersion;
  final bool isCurrent;
  final String issuedByName;
  final SuccessLabAdmissionDecision decision;
  final String decisionWireValue;
  final DateTime? issuedAt;
  final DateTime receivedAt;
  final bool hasEvidence;
  final SuccessLabEvidenceVerificationStatus verificationStatus;
  final String verificationStatusWireValue;
  final String? verificationNotes;
  final DateTime? verifiedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class SuccessLabFundingDecisionRecord {
  const SuccessLabFundingDecisionRecord({
    required this.id,
    required this.workspaceId,
    required this.version,
    required this.lockVersion,
    required this.isCurrent,
    required this.issuedByName,
    required this.decision,
    required this.decisionWireValue,
    required this.receivedAt,
    required this.hasEvidence,
    required this.verificationStatus,
    required this.verificationStatusWireValue,
    required this.createdAt,
    required this.updatedAt,
    this.admissionDecisionId,
    this.supersedesId,
    this.fundingAmountMinor,
    this.fundingCurrency,
    this.issuedAt,
    this.verificationNotes,
    this.verifiedAt,
  });

  final String id;
  final String workspaceId;
  final String? admissionDecisionId;
  final String? supersedesId;
  final int version;
  final int lockVersion;
  final bool isCurrent;
  final String issuedByName;
  final SuccessLabFundingDecision decision;
  final String decisionWireValue;

  /// Decimal string to preserve exact 64-bit backend amounts on Flutter web.
  final String? fundingAmountMinor;
  final String? fundingCurrency;
  final DateTime? issuedAt;
  final DateTime receivedAt;
  final bool hasEvidence;
  final SuccessLabEvidenceVerificationStatus verificationStatus;
  final String verificationStatusWireValue;
  final String? verificationNotes;
  final DateTime? verifiedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class SuccessLabSubmissionHistory {
  const SuccessLabSubmissionHistory({required this.items});

  final List<SuccessLabApplicationSubmission> items;
}

class SuccessLabDecisionHistory {
  const SuccessLabDecisionHistory({
    required this.admissions,
    required this.funding,
    required this.workspaceVersion,
  });

  final List<SuccessLabAdmissionDecisionRecord> admissions;
  final List<SuccessLabFundingDecisionRecord> funding;
  final int workspaceVersion;

  SuccessLabAdmissionDecisionRecord? get currentAdmission {
    for (final item in admissions) {
      if (item.isCurrent) return item;
    }
    return null;
  }

  SuccessLabFundingDecisionRecord? get currentFunding {
    for (final item in funding) {
      if (item.isCurrent) return item;
    }
    return null;
  }
}

class SuccessLabWorkspaceMutationSummary {
  const SuccessLabWorkspaceMutationSummary({
    required this.id,
    required this.status,
    required this.statusWireValue,
    required this.version,
  });

  final String id;
  final SuccessLabWorkspaceStatus status;
  final String statusWireValue;
  final int version;
}

class SuccessLabSubmissionMutation {
  const SuccessLabSubmissionMutation({
    required this.submission,
    required this.workspace,
  });

  final SuccessLabApplicationSubmission submission;
  final SuccessLabWorkspaceMutationSummary workspace;
}

class SuccessLabAdmissionMutation {
  const SuccessLabAdmissionMutation({
    required this.decision,
    required this.workspace,
  });

  final SuccessLabAdmissionDecisionRecord decision;
  final SuccessLabWorkspaceMutationSummary workspace;
}

class SuccessLabFundingMutation {
  const SuccessLabFundingMutation({
    required this.decision,
    required this.workspace,
  });

  final SuccessLabFundingDecisionRecord decision;
  final SuccessLabWorkspaceMutationSummary workspace;
}

/// Workspace snapshot returned by the competition-readiness API.
///
/// Nested scholarship/cycle/next-action fields are present on list summaries,
/// while [steps] and direct foreign keys are present on the full v1 snapshot.
class SuccessLabWorkspace {
  const SuccessLabWorkspace({
    required this.schemaVersion,
    required this.id,
    required this.scholarshipId,
    required this.scholarshipCycleId,
    required this.status,
    required this.statusWireValue,
    required this.version,
    required this.readinessPercent,
    this.userId,
    this.startedAt,
    this.lastActivityAt,
    this.submittedAt,
    this.decisionReceivedAt,
    this.archivedAt,
    this.steps = const <SuccessLabWorkspaceStep>[],
    this.scholarship,
    this.cycle,
    this.nextAction,
  });

  final int schemaVersion;
  final String id;
  final String? userId;
  final String scholarshipId;
  final String scholarshipCycleId;
  final SuccessLabWorkspaceStatus status;

  /// Exact API value, retained when [status] falls back to `unknown`.
  final String statusWireValue;
  final int version;

  /// Preparation progress, bounded to 0–100 by the codec. This is not an
  /// admission probability.
  final int readinessPercent;
  final DateTime? startedAt;
  final DateTime? lastActivityAt;
  final DateTime? submittedAt;
  final DateTime? decisionReceivedAt;
  final DateTime? archivedAt;
  final List<SuccessLabWorkspaceStep> steps;
  final SuccessLabScholarshipSummary? scholarship;
  final SuccessLabCycleSummary? cycle;
  final SuccessLabNextAction? nextAction;

  bool get hasUnknownEnumValues =>
      status == SuccessLabWorkspaceStatus.unknown ||
      cycle?.hasUnknownEnumValues == true ||
      steps.any((step) => step.hasUnknownEnumValues);
}

class SuccessLabWorkspaceStep {
  const SuccessLabWorkspaceStep({
    required this.id,
    required this.code,
    required this.titleFr,
    required this.titleEn,
    required this.category,
    required this.categoryWireValue,
    required this.weight,
    required this.isRequired,
    required this.templateVersion,
    required this.status,
    required this.statusWireValue,
    this.sourceStepId,
    this.notApplicableReason,
    this.completedAt,
  });

  final String id;
  final String? sourceStepId;
  final String code;
  final String titleFr;
  final String titleEn;
  final SuccessLabWorkspaceStepCategory category;
  final String categoryWireValue;
  final int weight;
  final bool isRequired;
  final String templateVersion;
  final SuccessLabWorkspaceStepStatus status;
  final String statusWireValue;
  final String? notApplicableReason;
  final DateTime? completedAt;

  bool get hasUnknownEnumValues =>
      category == SuccessLabWorkspaceStepCategory.unknown ||
      status == SuccessLabWorkspaceStepStatus.unknown;

  String titleForLanguage(String languageCode) =>
      languageCode.toLowerCase().startsWith('en') ? titleEn : titleFr;
}

class SuccessLabScholarshipSummary {
  const SuccessLabScholarshipSummary({
    required this.id,
    required this.name,
    required this.countryName,
  });

  final String id;
  final String name;
  final String countryName;
}

class SuccessLabCycleSummary {
  const SuccessLabCycleSummary({
    required this.id,
    required this.status,
    required this.statusWireValue,
    required this.dateConfidence,
    required this.dateConfidenceWireValue,
    this.opensAt,
    this.closesAt,
    this.estimatedOpenAt,
    this.estimatedCloseAt,
  });

  final String id;
  final SuccessLabCycleStatus status;
  final String statusWireValue;
  final SuccessLabDateConfidence dateConfidence;
  final String dateConfidenceWireValue;
  final DateTime? opensAt;
  final DateTime? closesAt;
  final DateTime? estimatedOpenAt;
  final DateTime? estimatedCloseAt;

  bool get hasUnknownEnumValues =>
      status == SuccessLabCycleStatus.unknown ||
      dateConfidence == SuccessLabDateConfidence.unknown;
}

class SuccessLabNextAction {
  const SuccessLabNextAction({
    required this.code,
    required this.label,
  });

  final String code;
  final String label;
}

class SuccessLabWorkspacePage {
  const SuccessLabWorkspacePage({
    required this.items,
    this.nextCursor,
  });

  final List<SuccessLabWorkspace> items;
  final String? nextCursor;
}
