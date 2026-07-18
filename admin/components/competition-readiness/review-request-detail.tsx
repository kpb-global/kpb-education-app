'use client';

import { useTranslations } from 'next-intl';
import { useCallback, useEffect, useState } from 'react';

import {
  convertReviewToCase,
  getReviewRequest,
  listActiveCounsellors,
  requestEvidenceAccess,
  triageReviewRequest,
  type ActiveCounsellor,
  type ReviewRequestDetail,
  type SecureEvidenceAccess,
  type TriageReviewRequestInput,
} from '../../lib/competition-readiness-api';
import {
  AdminCapability,
  hasAdminCapability,
} from '../../lib/admin-capabilities';
import { useLocale } from '../locale-provider';
import {
  Alert,
  Badge,
  Button,
  ConfirmDialog,
  EmptyState,
  Field,
  Select,
  Skeleton,
  Textarea,
} from '../ui';
import { EndpointUnavailableState } from './endpoint-state';
import { ReviewAvailabilityPanel } from './review-availability-panel';
import {
  formatDateTime,
  getApiErrorStatus,
  isEndpointUnavailable,
  reviewStatusVariant,
} from './readiness-utils';
import {
  canApplyReviewAction,
  canConvertReview,
  parseMissingItems,
  type ReviewMutationAction,
} from './review-actions';
import styles from './readiness.module.css';

function displayJson(value: ReviewRequestDetail['missingItems']): string {
  if (value === null) return '—';
  if (Array.isArray(value)) return value.map(String).join(', ') || '—';
  if (typeof value === 'string') return value;
  return JSON.stringify(value);
}

export function ReviewRequestDetailPanel({
  requestId,
  role,
  onClose,
  onUpdated,
}: Readonly<{
  requestId: string;
  role: string | undefined;
  onClose: () => void;
  onUpdated: () => void;
}>) {
  const t = useTranslations('competitionReadiness');
  const { locale } = useLocale();
  const [detail, setDetail] = useState<ReviewRequestDetail | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<unknown>(null);
  const [actionError, setActionError] = useState<string | null>(null);
  const [actionSuccess, setActionSuccess] = useState<string | null>(null);
  const [pendingAction, setPendingAction] = useState<string | null>(null);
  const [confirmConversion, setConfirmConversion] = useState(false);
  const [confirmTransition, setConfirmTransition] =
    useState<Extract<ReviewMutationAction, 'decline' | 'close'> | null>(null);
  const [counsellors, setCounsellors] = useState<ActiveCounsellor[]>([]);
  const [counsellorsLoading, setCounsellorsLoading] = useState(false);
  const [counsellorsError, setCounsellorsError] = useState<string | null>(null);
  const [assignedCounsellorId, setAssignedCounsellorId] = useState('');
  const [triageSummary, setTriageSummary] = useState('');
  const [missingItemsInput, setMissingItemsInput] = useState('');
  const [missingItemsError, setMissingItemsError] = useState<string | null>(null);
  const [evidenceAccess, setEvidenceAccess] = useState<
    Record<string, SecureEvidenceAccess>
  >({});

  const loadDetail = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const nextDetail = await getReviewRequest(requestId);
      setDetail(nextDetail);
      setAssignedCounsellorId(nextDetail.assignedCounsellorId ?? '');
      setTriageSummary(nextDetail.triageSummary ?? '');
      setMissingItemsInput(displayJson(nextDetail.missingItems).replace('—', ''));
    } catch (nextError) {
      setDetail(null);
      setError(nextError);
    } finally {
      setLoading(false);
    }
  }, [requestId]);

  useEffect(() => {
    void loadDetail();
  }, [loadDetail]);

  const canAssign = hasAdminCapability(
    role,
    AdminCapability.AssignReviewRequests,
  );
  const canManageAvailability =
    hasAdminCapability(role, AdminCapability.ManageOwnAvailability) ||
    hasAdminCapability(role, AdminCapability.ManageCounsellorAvailability);

  const loadCounsellors = useCallback(async () => {
    if (!canAssign) return;
    setCounsellorsLoading(true);
    setCounsellorsError(null);
    try {
      const response = await listActiveCounsellors(true, requestId);
      setCounsellors(response.items);
    } catch (nextError) {
      setCounsellors([]);
      setCounsellorsError(actionErrorMessage(nextError, t));
    } finally {
      setCounsellorsLoading(false);
    }
  }, [canAssign, requestId, t]);

  useEffect(() => {
    void loadCounsellors();
  }, [loadCounsellors]);

  const metadataOnly = detail?.projection === 'metadata';
  const canTriage =
    !metadataOnly &&
    hasAdminCapability(role, AdminCapability.TriageReviewRequests);
  const canConvert = hasAdminCapability(
    role,
    AdminCapability.ConvertReviewToCase,
  );
  const canOpenEvidence = hasAdminCapability(
    role,
    AdminCapability.ViewSharedReviewDocuments,
  );

  function acceptDetail(updated: ReviewRequestDetail) {
    setDetail(updated);
    setAssignedCounsellorId(updated.assignedCounsellorId ?? '');
    setTriageSummary(updated.triageSummary ?? '');
    setMissingItemsInput(displayJson(updated.missingItems).replace('—', ''));
  }

  async function applyTriage(
    action: TriageReviewRequestInput['action'],
    reasonCode: string,
    changes: Partial<TriageReviewRequestInput> = {},
  ) {
    if (!detail) return;
    setPendingAction(action);
    setActionError(null);
    setActionSuccess(null);
    try {
      const updated = await triageReviewRequest(detail.id, {
        expectedVersion: detail.version,
        action,
        reasonCode,
        ...changes,
      });
      acceptDetail(updated);
      setConfirmTransition(null);
      setActionSuccess(t('actionSaved'));
      onUpdated();
    } catch (nextError) {
      setActionError(actionErrorMessage(nextError, t));
      if (getApiErrorStatus(nextError) === 409) await loadDetail();
    } finally {
      setPendingAction(null);
    }
  }

  async function assignCounsellor() {
    await applyTriage('assign', 'review_assignment_updated', {
      assignedCounsellorId: assignedCounsellorId || null,
    });
  }

  async function requestMoreInformation() {
    const missingItems = parseMissingItems(missingItemsInput);
    if (!missingItems.length) {
      setMissingItemsError(t('missingItemsRequired'));
      return;
    }
    setMissingItemsError(null);
    await applyTriage(
      'request_more_information',
      'review_missing_information_requested',
      { missingItems },
    );
  }

  async function convertToCase() {
    if (!detail) return;
    setPendingAction('convert');
    setActionError(null);
    setActionSuccess(null);
    try {
      const result = await convertReviewToCase(
        detail.id,
        {
          expectedVersion: detail.version,
          reasonCode: 'review_triaged_for_case_conversion',
        },
        `review-to-case:${detail.id}:${globalThis.crypto.randomUUID()}`,
      );
      setConfirmConversion(false);
      setActionSuccess(t('caseConverted', { caseId: result.caseId }));
      await loadDetail();
      onUpdated();
    } catch (nextError) {
      setActionError(actionErrorMessage(nextError, t));
      if (getApiErrorStatus(nextError) === 409) await loadDetail();
    } finally {
      setPendingAction(null);
    }
  }

  async function generateEvidenceAccess(artifactVersionId: string) {
    setPendingAction(`evidence:${artifactVersionId}`);
    setActionError(null);
    try {
      const access = await requestEvidenceAccess(
        artifactVersionId,
        'study_review_document',
      );
      setEvidenceAccess((current) => ({
        ...current,
        [artifactVersionId]: access,
      }));
    } catch (nextError) {
      setActionError(
        isEndpointUnavailable(nextError)
          ? t('evidenceEndpointUnavailable')
          : t('evidenceAccessFailed'),
      );
    } finally {
      setPendingAction(null);
    }
  }

  if (loading) {
    return (
      <aside className={`${styles.panel} ${styles.panelSticky}`} aria-busy="true">
        <Skeleton height={28} width="65%" />
        <Skeleton height={110} />
        <Skeleton height={180} />
      </aside>
    );
  }

  if (error && isEndpointUnavailable(error)) {
    return (
      <aside className={styles.panelSticky}>
        <EndpointUnavailableState
          endpoint="GET /api/admin/competition-readiness/review-requests/:id"
          onRetry={() => void loadDetail()}
        />
      </aside>
    );
  }

  if (error || !detail) {
    return (
      <aside className={`${styles.panel} ${styles.panelSticky}`}>
        <EmptyState
          title={t('requestDetailErrorTitle')}
          description={t('requestDetailErrorDescription')}
          action={
            <Button variant="secondary" size="sm" onClick={() => void loadDetail()}>
              {t('retry')}
            </Button>
          }
        />
      </aside>
    );
  }

  return (
    <aside className={`${styles.panel} ${styles.panelSticky}`}>
      <div className={styles.panelHeader}>
        <div>
          <Badge variant={reviewStatusVariant(detail.status)}>
            {t(`reviewStatus_${detail.status}`)}
          </Badge>
          <h3 className={styles.panelTitle}>{detail.scholarship.title}</h3>
          <p className={styles.panelSubtitle}>
            {t('requestReference', { number: detail.requestNumber })}
          </p>
        </div>
        <button
          type="button"
          className={styles.iconButton}
          aria-label={t('closeDetail')}
          onClick={onClose}
        >
          ×
        </button>
      </div>

      {actionSuccess ? <Alert variant="success">{actionSuccess}</Alert> : null}
      {actionError ? <Alert variant="danger">{actionError}</Alert> : null}
      {counsellorsError ? (
        <Alert variant="danger">
          <div className={styles.inlineAlert}>
            <span>{counsellorsError}</span>
            <Button
              variant="secondary"
              size="sm"
              onClick={() => void loadCounsellors()}
            >
              {t('retry')}
            </Button>
          </div>
        </Alert>
      ) : null}

      <div className={styles.detailGrid}>
        <div className={styles.detailItem}>
          <span className={styles.detailLabel}>{t('advisorLabel')}</span>
          <p className={styles.detailValue}>
            {detail.assignedCounsellorName ?? t('unassignedAdvisor')}
          </p>
        </div>
        <div className={styles.detailItem}>
          <span className={styles.detailLabel}>{t('submittedLabel')}</span>
          <p className={styles.detailValue}>
            {formatDateTime(detail.submittedAt, locale)}
          </p>
        </div>
        {!metadataOnly ? (
          <div className={styles.detailItem}>
            <span className={styles.detailLabel}>{t('timezoneLabel')}</span>
            <p className={styles.detailValue}>
              {detail.timezone || t('notProvided')}
            </p>
          </div>
        ) : null}
        <div className={styles.detailItem}>
          <span className={styles.detailLabel}>{t('versionLabel')}</span>
          <p className={styles.detailValue}>v{detail.version}</p>
        </div>
      </div>

      {!metadataOnly &&
      canAssign &&
      canApplyReviewAction(detail.status, 'assign') ? (
        <section className={`${styles.section} ${styles.mutationBox}`}>
          <h4 className={styles.sectionTitle}>{t('assignmentTitle')}</h4>
          <p className={styles.panelSubtitle}>{t('assignmentDescription')}</p>
          <Field label={t('assignmentCounsellorLabel')}>
            {({ id, invalid }) => (
              <Select
                id={id}
                invalid={invalid}
                value={assignedCounsellorId}
                disabled={counsellorsLoading}
                onChange={(event) =>
                  setAssignedCounsellorId(event.target.value)
                }
              >
                <option value="">{t('unassignedAdvisor')}</option>
                {counsellors.map((counsellor) => (
                  <option key={counsellor.id} value={counsellor.id}>
                    {counsellor.fullName}
                    {counsellor.countryCode
                      ? ` · ${counsellor.countryCode}`
                      : ''}
                  </option>
                ))}
              </Select>
            )}
          </Field>
          <Button
            size="sm"
            loading={pendingAction === 'assign'}
            disabled={
              counsellorsLoading ||
              assignedCounsellorId === (detail.assignedCounsellorId ?? '')
            }
            onClick={() => void assignCounsellor()}
          >
            {t('saveAssignment')}
          </Button>
        </section>
      ) : null}

      {!metadataOnly ? (
        <section className={styles.section}>
          <h4 className={styles.sectionTitle}>{t('studentMessageTitle')}</h4>
          <p className={styles.detailValue}>
            {detail.studentMessage || t('notProvided')}
          </p>
        </section>
      ) : null}

      {!metadataOnly ? (
        <section className={styles.section}>
          <h4 className={styles.sectionTitle}>{t('triageTitle')}</h4>
          <p className={styles.detailValue}>
            {detail.triageSummary || t('notProvided')}
          </p>
          <p className={styles.detailValue}>
            <strong>{t('missingItemsLabel')}:</strong>{' '}
            {displayJson(detail.missingItems)}
          </p>
        </section>
      ) : null}

      {!metadataOnly ? <section className={styles.section}>
        <h4 className={styles.sectionTitle}>{t('sharedDocumentsTitle')}</h4>
        {detail.artifacts.length ? (
          <ul className={styles.artifactList}>
            {detail.artifacts.map((artifact) => {
              const access = evidenceAccess[artifact.artifactVersionId];
              return (
                <li key={artifact.artifactVersionId} className={styles.artifact}>
                  <div className={styles.artifactHeader}>
                    <span className={styles.artifactName}>
                      {artifact.originalFileName}
                    </span>
                    <Badge
                      variant={
                        artifact.processingStatus === 'clean'
                          ? 'success'
                          : 'warning'
                      }
                    >
                      {artifact.processingStatus}
                    </Badge>
                  </div>
                  <span className={styles.panelSubtitle}>{artifact.kind}</span>
                  {canOpenEvidence && artifact.canOpen ? (
                    access ? (
                      <a
                        className={styles.secureLink}
                        href={access.accessUrl}
                        target="_blank"
                        rel="noopener noreferrer"
                        referrerPolicy="no-referrer"
                      >
                        {t('openSecureDocument')}
                      </a>
                    ) : (
                      <Button
                        variant="secondary"
                        size="sm"
                        loading={
                          pendingAction ===
                          `evidence:${artifact.artifactVersionId}`
                        }
                        onClick={() =>
                          void generateEvidenceAccess(
                            artifact.artifactVersionId,
                          )
                        }
                      >
                        {t('generateSecureAccess')}
                      </Button>
                    )
                  ) : (
                    <span className={styles.panelSubtitle}>
                      {t('documentAccessRestricted')}
                    </span>
                  )}
                </li>
              );
            })}
          </ul>
        ) : (
          <p className={styles.detailValue}>{t('noSharedDocuments')}</p>
        )}
      </section> : null}

      {!metadataOnly && canTriage ? (
        <section className={`${styles.section} ${styles.mutationBox}`}>
          <h4 className={styles.sectionTitle}>{t('reviewActionsTitle')}</h4>
          {canApplyReviewAction(detail.status, 'triage') ? (
            <Field label={t('triageSummaryLabel')}>
              {({ id, invalid }) => (
                <Textarea
                  id={id}
                  invalid={invalid}
                  maxLength={2000}
                  value={triageSummary}
                  placeholder={t('triageSummaryPlaceholder')}
                  onChange={(event) => setTriageSummary(event.target.value)}
                />
              )}
            </Field>
          ) : null}
          {canApplyReviewAction(detail.status, 'request_more_information') ? (
            <Field
              label={t('missingItemsInputLabel')}
              error={missingItemsError ?? undefined}
            >
              {({ id, invalid }) => (
                <Textarea
                  id={id}
                  invalid={invalid}
                  maxLength={4000}
                  value={missingItemsInput}
                  placeholder={t('missingItemsPlaceholder')}
                  onChange={(event) => {
                    setMissingItemsInput(event.target.value);
                    setMissingItemsError(null);
                  }}
                />
              )}
            </Field>
          ) : null}
          {!detail.assignedCounsellorId &&
          canApplyReviewAction(detail.status, 'triage') ? (
            <Alert variant="warning">{t('assignmentRequiredForTriage')}</Alert>
          ) : null}
          <div className={styles.actions}>
            {canApplyReviewAction(detail.status, 'triage') ? (
              <Button
                size="sm"
                disabled={!detail.assignedCounsellorId}
                loading={pendingAction === 'triage'}
                onClick={() =>
                  void applyTriage('triage', 'review_triaged', {
                    triageSummary: triageSummary.trim() || undefined,
                  })
                }
              >
                {t('markTriaged')}
              </Button>
            ) : null}
            {canApplyReviewAction(
              detail.status,
              'request_more_information',
            ) ? (
              <Button
                variant="secondary"
                size="sm"
                loading={pendingAction === 'request_more_information'}
                onClick={() => void requestMoreInformation()}
              >
                {t('requestMoreInformation')}
              </Button>
            ) : null}
            {canApplyReviewAction(detail.status, 'recommend_autonomy') ? (
              <Button
                variant="secondary"
                size="sm"
                loading={pendingAction === 'recommend_autonomy'}
                onClick={() =>
                  void applyTriage(
                    'recommend_autonomy',
                    'autonomy_recommended_after_review',
                  )
                }
              >
                {t('recommendAutonomy')}
              </Button>
            ) : null}
            {canApplyReviewAction(detail.status, 'decline') ? (
              <Button
                variant="danger"
                size="sm"
                onClick={() => setConfirmTransition('decline')}
              >
                {t('declineReview')}
              </Button>
            ) : null}
            {canApplyReviewAction(detail.status, 'close') ? (
              <Button
                variant="danger"
                size="sm"
                onClick={() => setConfirmTransition('close')}
              >
                {t('closeReview')}
              </Button>
            ) : null}
          </div>
        </section>
      ) : null}

      {canConvert && canConvertReview(detail.status) ? (
        <section className={`${styles.section} ${styles.mutationBox}`}>
          <h4 className={styles.sectionTitle}>{t('commercialConversionTitle')}</h4>
          <p className={styles.panelSubtitle}>
            {metadataOnly
              ? t('commercialRedactedDescription')
              : t('conversionDescription')}
          </p>
          <Button
            variant="secondary"
            size="sm"
            onClick={() => setConfirmConversion(true)}
          >
            {t('convertToCase')}
          </Button>
        </section>
      ) : null}

      {!metadataOnly && canManageAvailability ? (
        <ReviewAvailabilityPanel
          detail={detail}
          role={role}
          onDetailUpdated={(updated) => {
            acceptDetail(updated);
            onUpdated();
          }}
        />
      ) : null}

      <p className={styles.authorityNote}>{t('actionAuthorityNote')}</p>

      <ConfirmDialog
        open={confirmConversion}
        title={t('convertConfirmTitle')}
        description={t('convertConfirmDescription')}
        confirmLabel={t('convertConfirmAction')}
        cancelLabel={t('cancel')}
        loading={pendingAction === 'convert'}
        onConfirm={() => void convertToCase()}
        onCancel={() => setConfirmConversion(false)}
      />
      <ConfirmDialog
        open={confirmTransition !== null}
        title={
          confirmTransition
            ? t(`transitionConfirmTitle_${confirmTransition}`)
            : ''
        }
        description={t('transitionConfirmDescription')}
        confirmLabel={
          confirmTransition === 'decline' ? t('declineReview') : t('closeReview')
        }
        cancelLabel={t('cancel')}
        variant="danger"
        loading={pendingAction === confirmTransition}
        onConfirm={() => {
          if (confirmTransition === 'decline') {
            void applyTriage('decline', 'review_declined_after_triage');
          } else if (confirmTransition === 'close') {
            void applyTriage('close', 'review_workflow_closed');
          }
        }}
        onCancel={() => setConfirmTransition(null)}
      />
    </aside>
  );
}

function actionErrorMessage(
  error: unknown,
  t: (key: string) => string,
): string {
  const status = getApiErrorStatus(error);
  if (status === 403) return t('actionForbidden');
  if (status === 409) return t('actionConflict');
  if (isEndpointUnavailable(error)) return t('actionEndpointUnavailable');
  return t('actionFailed');
}
