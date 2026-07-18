export const COMPETITION_READINESS_SCHEMA_VERSION = 1 as const;

export const SCHOLARSHIP_WORKSPACE_STATUSES = [
  'started',
  'preparing',
  'ready_for_review',
  'review_requested',
  'submitted',
  'decision_received',
  'archived',
] as const;

export type ScholarshipWorkspaceStatus =
  (typeof SCHOLARSHIP_WORKSPACE_STATUSES)[number];

export const WORKSPACE_STEP_STATUSES = [
  'not_started',
  'in_progress',
  'completed',
  'not_applicable',
] as const;

export type WorkspaceStepStatus = (typeof WORKSPACE_STEP_STATUSES)[number];

export const WORKSPACE_STEP_CATEGORIES = [
  'profile_eligibility',
  'documents',
  'form_and_essays',
  'review_and_submission',
] as const;

export type WorkspaceStepCategory = (typeof WORKSPACE_STEP_CATEGORIES)[number];

export const APPLICATION_ARTIFACT_KINDS = [
  'cv',
  'motivation_letter',
  'essay',
  'recommendation_letter',
  'transcript',
  'diploma',
  'language_test',
  'passport',
  'portfolio',
  'other',
] as const;

export type ApplicationArtifactKind =
  (typeof APPLICATION_ARTIFACT_KINDS)[number];

export const OUTCOME_TYPES = ['submission', 'admission', 'funding'] as const;
export type OutcomeType = (typeof OUTCOME_TYPES)[number];

export const OUTCOME_EVIDENCE_KINDS = [
  'submission_confirmation',
  'admission_decision',
  'rejection_decision',
  'waitlist_decision',
  'funding_award',
  'funding_rejection',
  'enrollment_confirmation',
  'other',
] as const;

export const EVIDENCE_VERIFICATION_STATUSES = [
  'self_reported',
  'pending',
  'verified',
  'needs_information',
  'rejected',
] as const;

export const ADMISSION_DECISIONS = [
  'admitted',
  'rejected',
  'waitlisted',
  'deferred',
  'withdrawn',
] as const;

export const FUNDING_DECISIONS = [
  'full',
  'partial',
  'none',
  'pending',
  'not_applicable',
] as const;

export const COMPETITION_READINESS_ERROR_CODES = [
  'FEATURE_DISABLED',
  'PROFILE_INCOMPLETE',
  'WORKSPACE_NOT_FOUND',
  'WORKSPACE_CYCLE_MISMATCH',
  'VERSION_CONFLICT',
  'AI_CONSENT_REQUIRED',
  'GUARDIAN_CONSENT_REQUIRED',
  'DIAGNOSTIC_ALREADY_AVAILABLE',
  'AI_BUDGET_EXHAUSTED',
  'AI_TEMPORARILY_UNAVAILABLE',
  'ARTIFACT_KIND_NOT_ALLOWED',
  'ARTIFACT_TOO_LARGE',
  'EVIDENCE_SCAN_PENDING',
  'EVIDENCE_REJECTED',
  'REVIEW_REQUEST_ALREADY_OPEN',
  'REVIEW_REQUEST_NOT_TRIAGED',
  'NO_SLOT_OFFERED',
  'SLOT_OFFER_EXPIRED',
  'SLOT_TAKEN',
  'OUTCOME_EVIDENCE_REQUIRED',
  'OUTCOME_ALREADY_SUPERSEDED',
  'FORBIDDEN_SCOPE',
  'RATE_LIMITED',
  'IDEMPOTENCY_KEY_REQUIRED',
  'IDEMPOTENCY_PAYLOAD_MISMATCH',
  'IDEMPOTENCY_IN_PROGRESS',
  'DATABASE_UNAVAILABLE',
  'OUTBOX_EVENT_CONFLICT',
] as const;

export type CompetitionReadinessErrorCode =
  (typeof COMPETITION_READINESS_ERROR_CODES)[number];
