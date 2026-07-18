'use client';

import { apiFetch } from './api-client';

const BASE_PATH = '/admin/competition-readiness';

export type IsoDateTime = string;
export type JsonPrimitive = boolean | number | string | null;
export type JsonValue =
  | JsonPrimitive
  | readonly JsonValue[]
  | { readonly [key: string]: JsonValue };

export type StudyReviewStatus =
  | 'draft'
  | 'submitted'
  | 'triaged'
  | 'more_information_needed'
  | 'call_offered'
  | 'scheduled'
  | 'converted_to_case'
  | 'autonomy_recommended'
  | 'declined'
  | 'closed';

export type EvidenceVerificationStatus =
  | 'self_reported'
  | 'pending'
  | 'verified'
  | 'needs_information'
  | 'rejected';

export type OutcomeType = 'submission' | 'admission' | 'funding';

export type PartnershipAgreementStatus =
  | 'draft'
  | 'prospect'
  | 'pending_signature'
  | 'signed'
  | 'active'
  | 'expired'
  | 'terminated';

export type PartnershipAgreementType =
  | 'letter_of_intent'
  | 'memorandum_of_understanding'
  | 'pilot'
  | 'data_sharing'
  | 'referral'
  | 'sponsorship'
  | 'other';

export type PilotStatus =
  | 'draft'
  | 'recruiting'
  | 'active'
  | 'analysis'
  | 'completed'
  | 'archived';

export interface CursorPage<T> {
  items: T[];
  nextCursor: string | null;
  total?: number;
}

export interface PageQuery {
  cursor?: string;
  limit?: number;
}

export interface AdminAuditSummary {
  id: string;
  action: string;
  result: string;
  actorDisplayName: string | null;
  reasonCode: string | null;
  occurredAt: IsoDateTime;
}

export interface ScholarshipReference {
  id: string;
  cycleId: string;
  title: string;
  countryCodes: string[];
}

export interface ReviewRequestListItem {
  id: string;
  workspaceId: string;
  requestNumber: number;
  version: number;
  status: StudyReviewStatus;
  submittedAt: IsoDateTime | null;
  updatedAt: IsoDateTime;
  assignedCounsellorId: string | null;
  assignedCounsellorName: string | null;
  scholarship: ScholarshipReference;
  slaDueAt: IsoDateTime | null;
  slaBreached: boolean;
  projection: 'metadata' | 'assigned' | 'full';
}

export interface SharedReviewArtifact {
  artifactVersionId: string;
  kind: string;
  originalFileName: string;
  mimeType: string;
  processingStatus: string;
  sharedAt: IsoDateTime;
  revokedAt: IsoDateTime | null;
  canOpen: boolean;
}

export interface ReviewRequestDetail extends ReviewRequestListItem {
  timezone: string | null;
  studentMessage: string | null;
  preferredContact: string | null;
  availability: JsonValue | null;
  triageSummary: string | null;
  missingItems: JsonValue | null;
  artifacts: SharedReviewArtifact[];
  audit: AdminAuditSummary[];
}

export interface ReviewRequestQuery extends PageQuery {
  statuses?: readonly StudyReviewStatus[];
  assignedCounsellorId?: string;
  scholarshipId?: string;
  countryCode?: string;
  overdueOnly?: boolean;
}

export interface TriageReviewRequestInput {
  expectedVersion: number;
  action:
    | 'triage'
    | 'assign'
    | 'request_more_information'
    | 'recommend_autonomy'
    | 'decline'
    | 'close';
  assignedCounsellorId?: string | null;
  triageSummary?: string;
  missingItems?: readonly string[];
  reasonCode: string;
}

export interface OfferReviewSlotsInput {
  expectedVersion: number;
  slotIds: readonly string[];
  expiresAt: IsoDateTime;
  reasonCode: string;
}

export interface ActiveCounsellor {
  id: string;
  fullName: string;
  countryCode: string | null;
  isActive: boolean;
}

export type AvailabilitySlotStatus =
  | 'available'
  | 'blocked'
  | 'exhausted'
  | 'cancelled';

export interface AvailabilitySlot {
  id: string;
  counsellorId: string;
  counsellorName: string;
  startsAt: IsoDateTime;
  endsAt: IsoDateTime;
  timezone: string;
  capacity: number;
  bookedCount: number;
  remainingCapacity: number;
  status: AvailabilitySlotStatus;
  version: number;
  createdAt: IsoDateTime;
  updatedAt: IsoDateTime;
}

export interface AvailabilitySlotQuery {
  counsellorId?: string;
  from?: IsoDateTime;
  to?: IsoDateTime;
  status?: AvailabilitySlotStatus;
  limit?: number;
}

export interface CreateAvailabilitySlotInput {
  counsellorId?: string;
  startsAt: IsoDateTime;
  endsAt: IsoDateTime;
  timezone: string;
  capacity?: number;
  reasonCode: string;
}

export interface CancelAvailabilitySlotInput {
  expectedVersion: number;
  reasonCode: string;
}

export interface ConvertReviewToCaseInput {
  expectedVersion: number;
  caseType?: string;
  serviceOfferId?: string;
  reasonCode: string;
}

export interface OutcomeListItem {
  type: OutcomeType;
  id: string;
  workspaceId: string;
  version: number;
  lockVersion: number;
  isCurrent: boolean;
  verificationStatus: EvidenceVerificationStatus;
  reportedAt: IsoDateTime;
  student: {
    id: string;
    fullName: string;
  };
  scholarship: OutcomeScholarshipReference;
}

export interface OutcomeScholarshipReference {
  id: string;
  nameFr: string;
  nameEn: string;
  countryId: string;
  countryNameFr: string;
  countryNameEn: string;
}

export interface OutcomeEvidenceSummary {
  id: string;
  workspaceId: string;
  kind: string;
  originalFileName: string;
  mimeType: string;
  sizeBytes: number;
  processingStatus: string;
  version: number;
  isPrimary: boolean;
  consentActive: boolean;
  uploadedAt: IsoDateTime | null;
  accessPath: string;
}

export interface OutcomeDetail {
  type: OutcomeType;
  id: string;
  workspaceId: string;
  version: number;
  lockVersion: number;
  isCurrent?: boolean;
  supersedesId?: string | null;
  verificationNotes: string | null;
  verificationStatus: EvidenceVerificationStatus;
  verifiedAt: IsoDateTime | null;
  createdAt: IsoDateTime;
  updatedAt: IsoDateTime;
  submittedAt?: IsoDateTime;
  submissionChannel?: string | null;
  hasApplicationReference?: boolean;
  issuedByName?: string;
  admissionDecision?: string;
  fundingDecision?: string;
  fundingAmountMinor?: string | null;
  fundingCurrency?: string | null;
  issuedAt?: IsoDateTime | null;
  receivedAt?: IsoDateTime;
  admissionDecisionId?: string | null;
  workspace: {
    id: string;
    version: number;
    status: string;
    user: {
      id: string;
      fullName: string;
      email: string;
    };
    scholarship: OutcomeScholarshipReference;
  };
  evidence: OutcomeEvidenceSummary[];
}

export interface OutcomeDetailResponse {
  outcome: OutcomeDetail;
  evidence: OutcomeEvidenceSummary[];
}

export interface OutcomeQuery extends PageQuery {
  type?: OutcomeType;
  verificationStatus?: EvidenceVerificationStatus;
  countryCode?: string;
}

export interface VerifyOutcomeInput {
  expectedVersion: number;
  status: Extract<
    EvidenceVerificationStatus,
    'pending' | 'verified' | 'needs_information' | 'rejected'
  >;
  reasonCode?: string;
  notes?: string;
}

export interface SecureEvidenceAccess {
  accessUrl: string;
  expiresAt: IsoDateTime;
  cacheControl: 'no-store';
  auditEventId: string;
}

export interface AiUsageQuery extends PageQuery {
  from?: IsoDateTime;
  to?: IsoDateTime;
  outcome?: string;
  provider?: string;
  model?: string;
}

export interface AiUsageItem {
  id: string;
  diagnosticId: string | null;
  attemptNumber: number;
  provider: string;
  model: string;
  promptVersion: string;
  inputTokens: number | null;
  cachedInputTokens: number | null;
  outputTokens: number | null;
  estimatedCostMicrosUsd: string | null;
  outcome: string;
  errorCode: string | null;
  startedAt: IsoDateTime | null;
  completedAt: IsoDateTime | null;
}

export interface AiUsageResponse extends CursorPage<AiUsageItem> {
  summary: {
    requests: number;
    validSuccessRate: number;
    fallbackRate: number;
    errorRate: number;
    estimatedCostMicrosUsd: string;
    budgetMicrosUsd: string;
    reservedMicrosUsd: string;
    spentMicrosUsd: string;
  };
}

export interface UpdateAiBudgetInput {
  expectedVersion: number;
  periodKey: string;
  budgetMicrosUsd: string;
  warningThresholdPercent: number;
  reasonCode: string;
}

export interface AiBudgetResponse {
  periodKey: string;
  version: number;
  budgetMicrosUsd: string;
  reservedMicrosUsd: string;
  spentMicrosUsd: string;
  startsAt: IsoDateTime;
  endsAt: IsoDateTime;
}

export interface UpdateFeatureFlagInput {
  expectedVersion: number;
  enabled: boolean;
  rolloutPercent: number;
  reasonCode: string;
}

export interface FeatureFlagResponse {
  key: string;
  version: number;
  enabled: boolean;
  rolloutPercent: number;
  updatedAt: IsoDateTime;
}

export interface PartnerAgreementItem {
  id: string;
  agreementKey: string;
  revisionNumber: number;
  lockVersion: number;
  partnerId: string;
  partnerName: string;
  institutionId: string | null;
  status: PartnershipAgreementStatus;
  agreementType: PartnershipAgreementType;
  purposeCodes: string[];
  countryCodes: string[];
  canRecruitPilot: boolean;
  canVerifySubmission: boolean;
  canVerifyDecision: boolean;
  canShareAggregateData: boolean;
  canPubliclyNamePartner: boolean;
  canUsePartnerLogo: boolean;
  signedAt: IsoDateTime | null;
  startsAt: IsoDateTime | null;
  endsAt: IsoDateTime | null;
  lastVerifiedAt: IsoDateTime | null;
}

export interface PartnerAgreementQuery extends PageQuery {
  statuses?: readonly PartnershipAgreementStatus[];
  agreementTypes?: readonly PartnershipAgreementType[];
  partnerId?: string;
  countryCode?: string;
}

export interface PartnerAgreementDraft {
  agreementKey: string;
  partnerId: string;
  institutionId?: string | null;
  status: PartnershipAgreementStatus;
  agreementType: PartnershipAgreementType;
  purposeCodes: readonly string[];
  countryCodes: readonly string[];
  canRecruitPilot: boolean;
  canVerifySubmission: boolean;
  canVerifyDecision: boolean;
  canShareAggregateData: boolean;
  canPubliclyNamePartner: boolean;
  canUsePartnerLogo: boolean;
  dataProtectionScope?: JsonValue | null;
  safeguardingScope?: JsonValue | null;
  signedAt?: IsoDateTime | null;
  startsAt?: IsoDateTime | null;
  endsAt?: IsoDateTime | null;
  reasonCode: string;
}

export interface UpdatePartnerAgreementInput {
  expectedVersion: number;
  changes: Partial<
    Omit<PartnerAgreementDraft, 'agreementKey' | 'reasonCode'>
  >;
  reasonCode: string;
}

export interface ImpactPilotItem {
  id: string;
  code: string;
  version: number;
  name: string;
  hypothesis: string;
  countryCodes: string[];
  status: PilotStatus;
  protocolVersion: string;
  recruitmentStartsAt: IsoDateTime | null;
  startsAt: IsoDateTime | null;
  endsAt: IsoDateTime | null;
  analysisLockedAt: IsoDateTime | null;
  participantCount: number;
  consentCoveragePercent: number;
}

export interface ImpactPilotQuery extends PageQuery {
  statuses?: readonly PilotStatus[];
  countryCode?: string;
}

export interface ImpactPilotDraft {
  code: string;
  name: string;
  hypothesis: string;
  countryCodes: readonly string[];
  targetPopulation: JsonValue;
  primaryMetrics: JsonValue;
  guardrailMetrics: JsonValue;
  status: PilotStatus;
  recruitmentStartsAt?: IsoDateTime | null;
  startsAt?: IsoDateTime | null;
  endsAt?: IsoDateTime | null;
  protocolVersion: string;
  partnerAgreementIds?: readonly string[];
  reasonCode: string;
}

export interface ImpactCohortItem {
  id: string;
  pilotId: string;
  code: string;
  version: number;
  label: string;
  cohortType: string;
  participantCount: number;
  activeParticipantCount?: number;
  consentCoveragePercent?: number;
  createdAt: IsoDateTime;
  updatedAt?: IsoDateTime;
}

export interface ImpactCohortDraft {
  code: string;
  label: string;
  cohortType: string;
  inclusionRules: JsonValue;
  exclusionRules: JsonValue;
  reasonCode: string;
}

export interface UpdateImpactPilotInput {
  expectedVersion: number;
  changes: Partial<Omit<ImpactPilotDraft, 'code' | 'reasonCode'>>;
  reasonCode: string;
}

export interface ImpactSnapshotResponse {
  id: string;
  pilotId: string;
  snapshotVersion: number;
  periodStart: IsoDateTime;
  periodEnd: IsoDateTime;
  sourceWatermark: IsoDateTime;
  isPublicSafe: boolean;
  generatedAt: IsoDateTime;
}

export interface ImpactSnapshotQuery extends PageQuery {
  publicSafeOnly?: boolean;
}

export interface FreezeImpactSnapshotInput {
  expectedVersion: number;
  periodStart: IsoDateTime;
  periodEnd: IsoDateTime;
  sourceWatermark: IsoDateTime;
  reasonCode: string;
}

export interface CompetitionReadinessReportQuery {
  pilotId?: string;
  metricKeys?: readonly string[];
  periodStart?: IsoDateTime;
  periodEnd?: IsoDateTime;
  publicSafeOnly?: boolean;
}

export interface CompetitionReadinessMetric {
  metricKey: string;
  metricVersion: number;
  label: string;
  value: number | null;
  numerator: number | null;
  denominator: number | null;
  sampleSize: number | null;
  coveragePercent: number | null;
  caveat: string | null;
}

export interface CompetitionReadinessReport {
  generatedAt: IsoDateTime;
  sourceWatermark: IsoDateTime;
  pilotId: string | null;
  metrics: CompetitionReadinessMetric[];
}

export type ImpactDataRoomFormat = 'json' | 'csv' | 'zip';

export interface CreateImpactDataRoomExportInput {
  snapshotId: string;
  purposeCode: string;
  format: ImpactDataRoomFormat;
  expiresAt?: IsoDateTime;
  reasonCode: string;
}

/**
 * Deliberately excludes storageKey, manifest contents and direct object URLs.
 * File access, when published, must use a separate short-lived audited route.
 */
export interface ImpactDataRoomExportReceipt {
  id: string;
  pilotId: string;
  snapshotId: string;
  format: ImpactDataRoomFormat;
  purposeCode: string;
  expiresAt: IsoDateTime | null;
  createdAt: IsoDateTime;
  sha256: string;
}

export interface ImpactDataRoomExportQuery {
  pilotId?: string;
  snapshotId?: string;
}

type QueryValue =
  | boolean
  | number
  | string
  | readonly string[]
  | null
  | undefined;

function segment(value: string): string {
  const trimmed = value.trim();
  if (!trimmed) {
    throw new Error('A non-empty resource identifier is required.');
  }
  return encodeURIComponent(trimmed);
}

function withQuery(
  path: string,
  query: Readonly<Record<string, QueryValue>>,
): string {
  const params = new URLSearchParams();

  for (const [key, value] of Object.entries(query)) {
    if (value === null || value === undefined || value === '') continue;
    if (Array.isArray(value)) {
      for (const item of value) params.append(key, item);
      continue;
    }
    params.set(key, String(value));
  }

  const search = params.toString();
  return search ? `${path}?${search}` : path;
}

function idempotencyHeaders(key: string): Readonly<Record<string, string>> {
  const trimmed = key.trim();
  if (!trimmed) {
    throw new Error('An Idempotency-Key is required for this creation.');
  }
  return { 'Idempotency-Key': trimmed };
}

export function listReviewRequests(query: ReviewRequestQuery = {}) {
  return apiFetch<CursorPage<ReviewRequestListItem>>(
    withQuery(`${BASE_PATH}/review-requests`, {
      cursor: query.cursor,
      limit: query.limit,
      status: query.statuses,
      assignedCounsellorId: query.assignedCounsellorId,
      scholarshipId: query.scholarshipId,
      countryCode: query.countryCode,
      overdueOnly: query.overdueOnly,
    }),
  );
}

export function getReviewRequest(id: string) {
  return apiFetch<ReviewRequestDetail>(
    `${BASE_PATH}/review-requests/${segment(id)}`,
  );
}

export function triageReviewRequest(
  id: string,
  input: TriageReviewRequestInput,
) {
  return apiFetch<ReviewRequestDetail>(
    `${BASE_PATH}/review-requests/${segment(id)}/triage`,
    { method: 'PATCH', body: input },
  );
}

export function offerReviewSlots(
  id: string,
  input: OfferReviewSlotsInput,
  idempotencyKey: string,
) {
  return apiFetch<ReviewRequestDetail>(
    `${BASE_PATH}/review-requests/${segment(id)}/slot-offers`,
    {
      method: 'POST',
      body: input,
      headers: idempotencyHeaders(idempotencyKey),
    },
  );
}

export function listActiveCounsellors(
  activeOnly = true,
  reviewRequestId?: string,
) {
  return apiFetch<{ items: ActiveCounsellor[] }>(
    withQuery(`${BASE_PATH}/counsellors`, { activeOnly, reviewRequestId }),
  );
}

export function listAvailabilitySlots(query: AvailabilitySlotQuery = {}) {
  return apiFetch<{ items: AvailabilitySlot[] }>(
    withQuery(`${BASE_PATH}/availability-slots`, {
      counsellorId: query.counsellorId,
      from: query.from,
      to: query.to,
      status: query.status,
      limit: query.limit,
    }),
  );
}

export function createAvailabilitySlot(
  input: CreateAvailabilitySlotInput,
  idempotencyKey: string,
) {
  return apiFetch<AvailabilitySlot>(`${BASE_PATH}/availability-slots`, {
    method: 'POST',
    body: input,
    headers: idempotencyHeaders(idempotencyKey),
  });
}

export function cancelAvailabilitySlot(
  id: string,
  input: CancelAvailabilitySlotInput,
) {
  return apiFetch<AvailabilitySlot>(
    `${BASE_PATH}/availability-slots/${segment(id)}/cancel`,
    { method: 'PATCH', body: input },
  );
}

export function convertReviewToCase(
  id: string,
  input: ConvertReviewToCaseInput,
  idempotencyKey: string,
) {
  return apiFetch<{ caseId: string; purchaseId: string | null }>(
    `${BASE_PATH}/review-requests/${segment(id)}/convert-to-case`,
    {
      method: 'POST',
      body: input,
      headers: idempotencyHeaders(idempotencyKey),
    },
  );
}

export function listOutcomes(query: OutcomeQuery = {}) {
  return apiFetch<CursorPage<OutcomeListItem>>(
    withQuery(`${BASE_PATH}/outcomes`, {
      cursor: query.cursor,
      limit: query.limit,
      type: query.type,
      verificationStatus: query.verificationStatus,
      countryCode: query.countryCode,
    }),
  );
}

export function getOutcome(type: OutcomeType, id: string) {
  return apiFetch<OutcomeDetailResponse>(
    `${BASE_PATH}/outcomes/${segment(type)}/${segment(id)}`,
  );
}

export function verifyOutcome(
  type: OutcomeType,
  id: string,
  input: VerifyOutcomeInput,
) {
  return apiFetch<{ outcome: OutcomeDetail }>(
    `${BASE_PATH}/outcomes/${segment(type)}/${segment(id)}/verification`,
    { method: 'PATCH', body: input },
  );
}

export function requestOutcomeEvidenceAccess(evidenceId: string) {
  return apiFetch<SecureEvidenceAccess>(
    withQuery(
      `${BASE_PATH}/outcome-evidence/${segment(evidenceId)}/file`,
      { purposeCode: 'outcome_verification' },
    ),
  );
}

export function requestEvidenceAccess(versionId: string, purposeCode: string) {
  return apiFetch<SecureEvidenceAccess>(
    withQuery(`${BASE_PATH}/evidence/${segment(versionId)}/file`, {
      purposeCode,
    }),
  );
}

export function getAiUsage(query: AiUsageQuery = {}) {
  return apiFetch<AiUsageResponse>(
    withQuery(`${BASE_PATH}/ai/usage`, {
      cursor: query.cursor,
      limit: query.limit,
      from: query.from,
      to: query.to,
      outcome: query.outcome,
      provider: query.provider,
      model: query.model,
    }),
  );
}

export function updateAiBudget(input: UpdateAiBudgetInput) {
  return apiFetch<AiBudgetResponse>(`${BASE_PATH}/ai/budget`, {
    method: 'PATCH',
    body: input,
  });
}

export function updateFeatureFlag(
  key: string,
  input: UpdateFeatureFlagInput,
) {
  return apiFetch<FeatureFlagResponse>(
    `${BASE_PATH}/flags/${segment(key)}`,
    { method: 'PATCH', body: input },
  );
}

export function listPartnerAgreements(query: PartnerAgreementQuery = {}) {
  return apiFetch<CursorPage<PartnerAgreementItem>>(
    withQuery(`${BASE_PATH}/partner-agreements`, {
      cursor: query.cursor,
      limit: query.limit,
      status: query.statuses,
      agreementType: query.agreementTypes,
      partnerId: query.partnerId,
      countryCode: query.countryCode,
    }),
  );
}

export function createPartnerAgreement(
  input: PartnerAgreementDraft,
  idempotencyKey: string,
) {
  return apiFetch<PartnerAgreementItem>(`${BASE_PATH}/partner-agreements`, {
    method: 'POST',
    body: input,
    headers: idempotencyHeaders(idempotencyKey),
  });
}

export function updatePartnerAgreement(
  id: string,
  input: UpdatePartnerAgreementInput,
  idempotencyKey: string,
) {
  return apiFetch<PartnerAgreementItem>(
    `${BASE_PATH}/partner-agreements/${segment(id)}`,
    {
      method: 'PATCH',
      body: input,
      headers: idempotencyHeaders(idempotencyKey),
    },
  );
}

export function listImpactPilots(query: ImpactPilotQuery = {}) {
  return apiFetch<CursorPage<ImpactPilotItem>>(
    withQuery(`${BASE_PATH}/pilots`, {
      cursor: query.cursor,
      limit: query.limit,
      status: query.statuses,
      countryCode: query.countryCode,
    }),
  );
}

export function createImpactPilot(
  input: ImpactPilotDraft,
  idempotencyKey: string,
) {
  return apiFetch<ImpactPilotItem>(`${BASE_PATH}/pilots`, {
    method: 'POST',
    body: input,
    headers: idempotencyHeaders(idempotencyKey),
  });
}

export function updateImpactPilot(
  id: string,
  input: UpdateImpactPilotInput,
  idempotencyKey: string,
) {
  return apiFetch<ImpactPilotItem>(`${BASE_PATH}/pilots/${segment(id)}`, {
    method: 'PATCH',
    body: input,
    headers: idempotencyHeaders(idempotencyKey),
  });
}

export function listImpactCohorts(pilotId: string, query: PageQuery = {}) {
  return apiFetch<CursorPage<ImpactCohortItem>>(
    withQuery(`${BASE_PATH}/pilots/${segment(pilotId)}/cohorts`, {
      cursor: query.cursor,
      limit: query.limit,
    }),
  );
}

export function createImpactCohort(
  pilotId: string,
  input: ImpactCohortDraft,
  idempotencyKey: string,
) {
  return apiFetch<ImpactCohortItem>(
    `${BASE_PATH}/pilots/${segment(pilotId)}/cohorts`,
    {
      method: 'POST',
      body: input,
      headers: idempotencyHeaders(idempotencyKey),
    },
  );
}

export function listImpactSnapshots(
  pilotId: string,
  query: ImpactSnapshotQuery = {},
) {
  return apiFetch<CursorPage<ImpactSnapshotResponse>>(
    withQuery(`${BASE_PATH}/pilots/${segment(pilotId)}/snapshots`, {
      cursor: query.cursor,
      limit: query.limit,
      publicSafeOnly: query.publicSafeOnly,
    }),
  );
}

export function freezeImpactSnapshot(
  pilotId: string,
  input: FreezeImpactSnapshotInput,
  idempotencyKey: string,
) {
  return apiFetch<ImpactSnapshotResponse>(
    `${BASE_PATH}/pilots/${segment(pilotId)}/snapshots`,
    {
      method: 'POST',
      body: input,
      headers: idempotencyHeaders(idempotencyKey),
    },
  );
}

function projectDataRoomReceipt(
  value: ImpactDataRoomExportReceipt,
): ImpactDataRoomExportReceipt {
  return {
    id: value.id,
    pilotId: value.pilotId,
    snapshotId: value.snapshotId,
    format: value.format,
    purposeCode: value.purposeCode,
    expiresAt: value.expiresAt,
    createdAt: value.createdAt,
    sha256: value.sha256,
  };
}

export async function listImpactDataRoomExports(
  query: ImpactDataRoomExportQuery = {},
) {
  const response = await apiFetch<{ items: ImpactDataRoomExportReceipt[] }>(
    withQuery(`${BASE_PATH}/data-room-exports`, {
      pilotId: query.pilotId,
      snapshotId: query.snapshotId,
    }),
  );
  return { items: response.items.map(projectDataRoomReceipt) };
}

export async function createImpactDataRoomExport(
  input: CreateImpactDataRoomExportInput,
  idempotencyKey: string,
) {
  const response = await apiFetch<ImpactDataRoomExportReceipt>(
    `${BASE_PATH}/data-room-exports`,
    {
      method: 'POST',
      body: input,
      headers: idempotencyHeaders(idempotencyKey),
    },
  );
  return projectDataRoomReceipt(response);
}

export function getCompetitionReadinessReport(
  query: CompetitionReadinessReportQuery = {},
) {
  return apiFetch<CompetitionReadinessReport>(
    withQuery(`${BASE_PATH}/reports`, {
      pilotId: query.pilotId,
      metricKey: query.metricKeys,
      periodStart: query.periodStart,
      periodEnd: query.periodEnd,
      publicSafeOnly: query.publicSafeOnly,
    }),
  );
}

export const competitionReadinessApi = Object.freeze({
  listReviewRequests,
  getReviewRequest,
  triageReviewRequest,
  offerReviewSlots,
  listActiveCounsellors,
  listAvailabilitySlots,
  createAvailabilitySlot,
  cancelAvailabilitySlot,
  convertReviewToCase,
  listOutcomes,
  getOutcome,
  verifyOutcome,
  requestOutcomeEvidenceAccess,
  requestEvidenceAccess,
  getAiUsage,
  updateAiBudget,
  updateFeatureFlag,
  listPartnerAgreements,
  createPartnerAgreement,
  updatePartnerAgreement,
  listImpactPilots,
  createImpactPilot,
  updateImpactPilot,
  listImpactCohorts,
  createImpactCohort,
  listImpactSnapshots,
  freezeImpactSnapshot,
  listImpactDataRoomExports,
  createImpactDataRoomExport,
  getCompetitionReadinessReport,
});
