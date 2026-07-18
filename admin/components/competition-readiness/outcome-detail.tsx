'use client';

import { useTranslations } from 'next-intl';
import { useCallback, useEffect, useState } from 'react';

import {
  getOutcome,
  requestOutcomeEvidenceAccess,
  verifyOutcome,
  type EvidenceVerificationStatus,
  type OutcomeDetail,
  type OutcomeEvidenceSummary,
  type OutcomeType,
  type SecureEvidenceAccess,
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
  Skeleton,
  Textarea,
} from '../ui';
import { EndpointUnavailableState } from './endpoint-state';
import {
  formatDateTime,
  getApiErrorStatus,
  isEndpointUnavailable,
  verificationStatusVariant,
} from './readiness-utils';
import styles from './readiness.module.css';

type VerificationTarget = Extract<
  EvidenceVerificationStatus,
  'pending' | 'verified' | 'needs_information' | 'rejected'
>;

function formatMinorCurrency(
  rawAmount: string | null | undefined,
  currency: string | null | undefined,
  locale: 'fr' | 'en',
): string | null {
  if (!rawAmount || !currency || !/^-?\d+$/.test(rawAmount)) return null;
  const normalizedCurrency = currency.trim().toUpperCase();
  if (!normalizedCurrency) return null;

  let fractionDigits = 2;
  try {
    fractionDigits = new Intl.NumberFormat(
      locale === 'fr' ? 'fr-FR' : 'en-GB',
      { style: 'currency', currency: normalizedCurrency },
    ).resolvedOptions().maximumFractionDigits ?? 2;
  } catch {
    return `${rawAmount} ${normalizedCurrency}`;
  }

  const negative = rawAmount.startsWith('-');
  const digits = negative ? rawAmount.slice(1) : rawAmount;
  const padded = digits.padStart(fractionDigits + 1, '0');
  const whole =
    fractionDigits === 0 ? padded : padded.slice(0, -fractionDigits);
  const fraction =
    fractionDigits === 0 ? '' : padded.slice(-fractionDigits);
  const decimalSeparator = locale === 'fr' ? ',' : '.';
  return `${negative ? '-' : ''}${whole}${fraction ? `${decimalSeparator}${fraction}` : ''} ${normalizedCurrency}`;
}

export function OutcomeDetailPanel({
  type,
  outcomeId,
  role,
  onClose,
  onUpdated,
}: Readonly<{
  type: OutcomeType;
  outcomeId: string;
  role: string | undefined;
  onClose: () => void;
  onUpdated: () => void;
}>) {
  const t = useTranslations('competitionReadiness');
  const { locale } = useLocale();
  const [detail, setDetail] = useState<OutcomeDetail | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<unknown>(null);
  const [notes, setNotes] = useState('');
  const [target, setTarget] = useState<VerificationTarget | null>(null);
  const [pending, setPending] = useState(false);
  const [actionError, setActionError] = useState<string | null>(null);
  const [actionSuccess, setActionSuccess] = useState<string | null>(null);
  const [evidence, setEvidence] = useState<OutcomeEvidenceSummary[]>([]);
  const [evidenceAccess, setEvidenceAccess] = useState<
    Record<string, SecureEvidenceAccess>
  >({});
  const [evidencePendingId, setEvidencePendingId] = useState<string | null>(
    null,
  );
  const canVerify = hasAdminCapability(
    role,
    AdminCapability.VerifyOutcomes,
  );

  const loadDetail = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const response = await getOutcome(type, outcomeId);
      setDetail(response.outcome);
      setEvidence(response.evidence);
    } catch (nextError) {
      setDetail(null);
      setEvidence([]);
      setError(nextError);
    } finally {
      setLoading(false);
    }
  }, [outcomeId, type]);

  useEffect(() => {
    setNotes('');
    setEvidenceAccess({});
    void loadDetail();
  }, [loadDetail]);

  async function commitVerification() {
    if (!detail || !target || !canVerify) return;
    setPending(true);
    setActionError(null);
    setActionSuccess(null);
    try {
      const updated = await verifyOutcome(type, detail.id, {
        expectedVersion: detail.lockVersion,
        status: target,
        reasonCode: target === 'pending' ? undefined : `admin_${target}`,
        notes: notes.trim() || undefined,
      });
      setDetail(updated.outcome);
      setTarget(null);
      setNotes('');
      setActionSuccess(t('verificationSaved'));
      onUpdated();
    } catch (nextError) {
      const status = getApiErrorStatus(nextError);
      if (status === 409) {
        setActionError(t('verificationConflict'));
        await loadDetail();
      } else if (status === 403) {
        setActionError(t('outcomeForbidden'));
      } else {
        setActionError(
          isEndpointUnavailable(nextError)
            ? t('actionEndpointUnavailable')
            : t('verificationFailed'),
        );
      }
    } finally {
      setPending(false);
    }
  }

  async function generateEvidenceAccess(item: OutcomeEvidenceSummary) {
    setEvidencePendingId(item.id);
    setActionError(null);
    try {
      const access = await requestOutcomeEvidenceAccess(item.id);
      setEvidenceAccess((current) => ({ ...current, [item.id]: access }));
    } catch (nextError) {
      setActionError(
        getApiErrorStatus(nextError) === 403
          ? t('evidenceAccessForbidden')
          : isEndpointUnavailable(nextError)
            ? t('evidenceEndpointUnavailable')
            : t('evidenceAccessFailed'),
      );
    } finally {
      setEvidencePendingId(null);
    }
  }

  if (loading) {
    return (
      <aside className={`${styles.panel} ${styles.panelSticky}`} aria-busy="true">
        <Skeleton height={28} width="65%" />
        <Skeleton height={130} />
        <Skeleton height={180} />
      </aside>
    );
  }

  if (error && isEndpointUnavailable(error)) {
    return (
      <aside className={styles.panelSticky}>
        <EndpointUnavailableState
          endpoint="GET /api/admin/competition-readiness/outcomes/:type/:id"
          onRetry={() => void loadDetail()}
        />
      </aside>
    );
  }

  if (error || !detail) {
    return (
      <aside className={`${styles.panel} ${styles.panelSticky}`}>
        <EmptyState
          title={t('outcomeDetailErrorTitle')}
          description={t('outcomeDetailErrorDescription')}
          action={
            <Button variant="secondary" size="sm" onClick={() => void loadDetail()}>
              {t('retry')}
            </Button>
          }
        />
      </aside>
    );
  }

  const notesRequired = target === 'needs_information' || target === 'rejected';
  const scholarship = detail.workspace.scholarship;
  const isCurrent = detail.type === 'submission' || detail.isCurrent !== false;
  const mustReopen =
    detail.verificationStatus === 'verified' ||
    detail.verificationStatus === 'rejected';
  const reportedAt =
    detail.receivedAt ?? detail.submittedAt ?? detail.createdAt;
  const fundingAmount = formatMinorCurrency(
    detail.fundingAmountMinor,
    detail.fundingCurrency,
    locale,
  );
  const decision =
    detail.type === 'admission' && detail.admissionDecision
      ? t(`admissionDecision_${detail.admissionDecision}`)
      : detail.type === 'funding' && detail.fundingDecision
        ? t(`fundingDecision_${detail.fundingDecision}`)
        : detail.submissionChannel || t('submissionRecorded');

  return (
    <aside className={`${styles.panel} ${styles.panelSticky}`}>
      <div className={styles.panelHeader}>
        <div>
          <Badge variant={verificationStatusVariant(detail.verificationStatus)}>
            {t(`verificationStatus_${detail.verificationStatus}`)}
          </Badge>
          <h3 className={styles.panelTitle}>
            {locale === 'fr' ? scholarship.nameFr : scholarship.nameEn}
          </h3>
          <p className={styles.panelSubtitle}>{t(`outcomeType_${detail.type}`)}</p>
        </div>
        <button type="button" className={styles.iconButton} aria-label={t('closeDetail')} onClick={onClose}>
          ×
        </button>
      </div>

      {actionSuccess ? <Alert variant="success">{actionSuccess}</Alert> : null}
      {actionError ? <Alert variant="danger">{actionError}</Alert> : null}
      {!isCurrent ? (
        <Alert variant="warning">{t('historicalOutcomeReadOnly')}</Alert>
      ) : null}

      <div className={styles.detailGrid}>
        <div className={styles.detailItem}>
          <span className={styles.detailLabel}>{t('studentLabel')}</span>
          <p className={styles.detailValue}>{detail.workspace.user.fullName}</p>
        </div>
        <div className={styles.detailItem}>
          <span className={styles.detailLabel}>{t('decisionLabel')}</span>
          <p className={styles.detailValue}>{decision}</p>
        </div>
        {fundingAmount ? (
          <div className={styles.detailItem}>
            <span className={styles.detailLabel}>{t('fundingAmountLabel')}</span>
            <p className={styles.detailValue}>{fundingAmount}</p>
          </div>
        ) : null}
        <div className={styles.detailItem}>
          <span className={styles.detailLabel}>{t('issuerLabel')}</span>
          <p className={styles.detailValue}>{detail.issuedByName ?? t('notProvided')}</p>
        </div>
        <div className={styles.detailItem}>
          <span className={styles.detailLabel}>{t('reportedLabel')}</span>
          <p className={styles.detailValue}>{formatDateTime(reportedAt, locale)}</p>
        </div>
        <div className={styles.detailItem}>
          <span className={styles.detailLabel}>{t('verifiedAtLabel')}</span>
          <p className={styles.detailValue}>{formatDateTime(detail.verifiedAt, locale)}</p>
        </div>
      </div>

      <section className={styles.section}>
        <h4 className={styles.sectionTitle}>{t('evidenceTitle')}</h4>
        {evidence.length ? (
          <div className={styles.stack}>
            {evidence.map((item) => {
              const canOpen =
                item.processingStatus === 'clean' && item.consentActive;
              const access = evidenceAccess[item.id];
              return (
                <div key={item.id} className={styles.artifact}>
                  <div className={styles.artifactHeader}>
                    <span className={styles.artifactName}>
                      {item.originalFileName}
                    </span>
                    <Badge variant={canOpen ? 'success' : 'warning'}>
                      {item.isPrimary
                        ? t('evidencePrimary')
                        : t('evidenceSupplemental')}
                    </Badge>
                  </div>
                  <span className={styles.panelSubtitle}>{item.mimeType}</span>
                  {canOpen ? (
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
                        loading={evidencePendingId === item.id}
                        onClick={() => void generateEvidenceAccess(item)}
                      >
                        {t('generateSecureAccess')}
                      </Button>
                    )
                  ) : (
                    <span className={styles.panelSubtitle}>
                      {t('documentAccessRestricted')}
                    </span>
                  )}
                </div>
              );
            })}
          </div>
        ) : (
          <p className={styles.detailValue}>{t('noEvidence')}</p>
        )}
      </section>

      <Field label={t('verificationNotesLabel')}>
        {({ id, invalid }) => (
          <Textarea
            id={id}
            invalid={invalid}
            value={notes}
            placeholder={t('verificationNotesPlaceholder')}
            onChange={(event) => setNotes(event.target.value)}
          />
        )}
      </Field>

      {canVerify && isCurrent ? (
        <div className={styles.actions}>
          {mustReopen ? (
            <Button size="sm" onClick={() => setTarget('pending')}>
              {t('reopenVerificationAction')}
            </Button>
          ) : (
            <>
              <Button
                size="sm"
                disabled={detail.verificationStatus === 'verified'}
                onClick={() => setTarget('verified')}
              >
                {t('verifyAction')}
              </Button>
              <Button
                variant="secondary"
                size="sm"
                disabled={
                  !notes.trim() ||
                  detail.verificationStatus === 'needs_information'
                }
                onClick={() => setTarget('needs_information')}
              >
                {t('requestInformationAction')}
              </Button>
              <Button
                variant="dangerOutline"
                size="sm"
                disabled={!notes.trim()}
                onClick={() => setTarget('rejected')}
              >
                {t('rejectAction')}
              </Button>
            </>
          )}
        </div>
      ) : null}

      <p className={styles.authorityNote}>{t('verificationAuthorityNote')}</p>

      <ConfirmDialog
        open={target !== null}
        title={target ? t(`verificationConfirm_${target}`) : ''}
        description={t('verificationConfirmDescription')}
        confirmLabel={t('confirm')}
        cancelLabel={t('cancel')}
        variant={target === 'rejected' ? 'danger' : 'primary'}
        loading={pending}
        onConfirm={() => {
          if (!notesRequired || notes.trim()) void commitVerification();
        }}
        onCancel={() => setTarget(null)}
      />
    </aside>
  );
}
