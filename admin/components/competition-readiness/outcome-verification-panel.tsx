'use client';

import { useTranslations } from 'next-intl';
import { useEffect, useState } from 'react';

import {
  listOutcomes,
  type CursorPage,
  type EvidenceVerificationStatus,
  type OutcomeListItem,
  type OutcomeType,
} from '../../lib/competition-readiness-api';
import {
  AdminCapability,
  hasAdminCapability,
} from '../../lib/admin-capabilities';
import { useLocale } from '../locale-provider';
import {
  AdminTable,
  AdminTableRow,
  Alert,
  Badge,
  Button,
  CellText,
  EmptyState,
  Field,
  Select,
  Skeleton,
} from '../ui';
import { EndpointUnavailableState } from './endpoint-state';
import { OutcomeDetailPanel } from './outcome-detail';
import {
  formatDateTime,
  isEndpointUnavailable,
  verificationStatusVariant,
} from './readiness-utils';
import styles from './readiness.module.css';

const OUTCOME_TYPES: readonly OutcomeType[] = [
  'submission',
  'admission',
  'funding',
];

const VERIFICATION_STATUSES: readonly EvidenceVerificationStatus[] = [
  'self_reported',
  'pending',
  'verified',
  'needs_information',
  'rejected',
];

function isOutcomeType(value: string | null): value is OutcomeType {
  return OUTCOME_TYPES.includes(value as OutcomeType);
}

export function OutcomeVerificationPanel({
  role,
  selectedType,
  selectedId,
  onSelectOutcome,
}: Readonly<{
  role: string | undefined;
  selectedType: string | null;
  selectedId: string | null;
  onSelectOutcome: (type: string | null, id: string | null) => void;
}>) {
  const t = useTranslations('competitionReadiness');
  const { locale } = useLocale();
  const [typeFilter, setTypeFilter] = useState<OutcomeType | ''>('');
  const [statusFilter, setStatusFilter] = useState<
    EvidenceVerificationStatus | ''
  >('');
  const [cursorStack, setCursorStack] = useState<string[]>([]);
  const [page, setPage] = useState<CursorPage<OutcomeListItem> | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<unknown>(null);
  const [reloadToken, setReloadToken] = useState(0);
  const cursor = cursorStack.at(-1);
  const canVerify = hasAdminCapability(
    role,
    AdminCapability.VerifyOutcomes,
  );
  const activeType = isOutcomeType(selectedType) ? selectedType : null;

  useEffect(() => {
    if (!canVerify) {
      setLoading(false);
      return;
    }
    let cancelled = false;
    setLoading(true);
    setError(null);

    void listOutcomes({
      cursor,
      limit: 20,
      type: typeFilter || undefined,
      verificationStatus: statusFilter || undefined,
    })
      .then((response) => {
        if (!cancelled) setPage(response);
      })
      .catch((nextError: unknown) => {
        if (!cancelled) {
          setPage(null);
          setError(nextError);
        }
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });

    return () => {
      cancelled = true;
    };
  }, [canVerify, cursor, reloadToken, statusFilter, typeFilter]);

  function refresh() {
    setReloadToken((value) => value + 1);
  }

  if (!canVerify) {
    return (
      <Alert variant="warning">
        {t('outcomeCapabilityRequired')}
      </Alert>
    );
  }

  if (error && isEndpointUnavailable(error)) {
    return (
      <EndpointUnavailableState
        endpoint="GET /api/admin/competition-readiness/outcomes"
        onRetry={refresh}
      />
    );
  }

  return (
    <div className={styles.splitLayout}>
      <div className={styles.stack}>
        <div className={styles.filters}>
          <Field label={t('filterOutcomeType')}>
            {({ id, invalid }) => (
              <Select
                id={id}
                invalid={invalid}
                value={typeFilter}
                onChange={(event) => {
                  setTypeFilter(event.target.value as OutcomeType | '');
                  setCursorStack([]);
                  onSelectOutcome(null, null);
                }}
              >
                <option value="">{t('allOutcomeTypes')}</option>
                {OUTCOME_TYPES.map((value) => (
                  <option key={value} value={value}>
                    {t(`outcomeType_${value}`)}
                  </option>
                ))}
              </Select>
            )}
          </Field>
          <Field label={t('filterVerificationStatus')}>
            {({ id, invalid }) => (
              <Select
                id={id}
                invalid={invalid}
                value={statusFilter}
                onChange={(event) => {
                  setStatusFilter(
                    event.target.value as EvidenceVerificationStatus | '',
                  );
                  setCursorStack([]);
                  onSelectOutcome(null, null);
                }}
              >
                <option value="">{t('allStatuses')}</option>
                {VERIFICATION_STATUSES.map((value) => (
                  <option key={value} value={value}>
                    {t(`verificationStatus_${value}`)}
                  </option>
                ))}
              </Select>
            )}
          </Field>
          <div />
          <Button variant="secondary" onClick={refresh}>
            {t('refresh')}
          </Button>
        </div>

        {error ? (
          <Alert variant="danger">{t('outcomesLoadError')}</Alert>
        ) : null}

        <AdminTable
          title={t('outcomesTitle')}
          columns={[
            t('colScholarship'),
            t('colStudent'),
            t('colOutcomeType'),
            t('colVerification'),
            t('colReported'),
          ]}
          cols="1.5fr 1fr 0.8fr 1fr 1fr"
          footnote={t('outcomesTableNote')}
        >
          {loading ? (
            Array.from({ length: 4 }, (_, index) => (
              <AdminTableRow key={index}>
                {Array.from({ length: 5 }, (__, cellIndex) => (
                  <Skeleton key={cellIndex} height={18} />
                ))}
              </AdminTableRow>
            ))
          ) : page?.items.length ? (
            page.items.map((item) => (
              <AdminTableRow
                key={`${item.type}:${item.id}`}
                selected={activeType === item.type && selectedId === item.id}
                onSelect={() => onSelectOutcome(item.type, item.id)}
              >
                <CellText
                  primary={
                    locale === 'fr'
                      ? item.scholarship.nameFr
                      : item.scholarship.nameEn
                  }
                  sub={
                    locale === 'fr'
                      ? item.scholarship.countryNameFr
                      : item.scholarship.countryNameEn
                  }
                />
                <CellText primary={item.student.fullName} />
                <CellText primary={t(`outcomeType_${item.type}`)} />
                <Badge variant={verificationStatusVariant(item.verificationStatus)}>
                  {t(`verificationStatus_${item.verificationStatus}`)}
                </Badge>
                <CellText primary={formatDateTime(item.reportedAt, locale)} muted />
              </AdminTableRow>
            ))
          ) : (
            <EmptyState
              title={t('outcomesEmptyTitle')}
              description={t('outcomesEmptyDescription')}
            />
          )}
        </AdminTable>

        <div className={styles.pagination}>
          <span className={styles.paginationText}>
            {t('pageNumber', { page: cursorStack.length + 1 })}
          </span>
          <div className={styles.paginationActions}>
            <Button
              variant="secondary"
              size="sm"
              disabled={loading || cursorStack.length === 0}
              onClick={() => setCursorStack((current) => current.slice(0, -1))}
            >
              {t('previous')}
            </Button>
            <Button
              variant="secondary"
              size="sm"
              disabled={loading || !page?.nextCursor}
              onClick={() => {
                if (page?.nextCursor) {
                  setCursorStack((current) => [...current, page.nextCursor as string]);
                }
              }}
            >
              {t('next')}
            </Button>
          </div>
        </div>
      </div>

      {activeType && selectedId ? (
        <OutcomeDetailPanel
          type={activeType}
          outcomeId={selectedId}
          role={role}
          onClose={() => onSelectOutcome(null, null)}
          onUpdated={refresh}
        />
      ) : (
        <aside className={`${styles.panel} ${styles.panelSticky}`}>
          <EmptyState
            title={t('selectOutcomeTitle')}
            description={t('selectOutcomeDescription')}
          />
        </aside>
      )}
    </div>
  );
}
