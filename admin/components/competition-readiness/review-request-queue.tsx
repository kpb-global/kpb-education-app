'use client';

import { useTranslations } from 'next-intl';
import { useRouter, useSearchParams } from 'next/navigation';
import { FormEvent, useEffect, useMemo, useState } from 'react';

import {
  listReviewRequests,
  type CursorPage,
  type ReviewRequestListItem,
  type StudyReviewStatus,
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
  Input,
  Select,
  Skeleton,
} from '../ui';
import { EndpointUnavailableState } from './endpoint-state';
import { ReviewRequestDetailPanel } from './review-request-detail';
import {
  formatDateTime,
  isEndpointUnavailable,
  normalizeCountryCode,
  reviewStatusVariant,
} from './readiness-utils';
import styles from './readiness.module.css';

const REVIEW_STATUSES: readonly StudyReviewStatus[] = [
  'submitted',
  'triaged',
  'more_information_needed',
  'call_offered',
  'scheduled',
  'autonomy_recommended',
  'converted_to_case',
  'declined',
  'closed',
];

function isReviewStatus(value: string | null): value is StudyReviewStatus {
  return REVIEW_STATUSES.includes(value as StudyReviewStatus);
}

export function ReviewRequestQueue({
  role,
  selectedRequestId,
  onSelectRequest,
}: Readonly<{
  role: string | undefined;
  selectedRequestId: string | null;
  onSelectRequest: (id: string | null) => void;
}>) {
  const t = useTranslations('competitionReadiness');
  const { locale } = useLocale();
  const router = useRouter();
  const searchParams = useSearchParams();
  const statusParam = searchParams.get('reviewStatus');
  const status = isReviewStatus(statusParam) ? statusParam : '';
  const countryCode = normalizeCountryCode(
    searchParams.get('reviewCountry') ?? '',
  );
  const overdueOnly = searchParams.get('reviewOverdue') === 'true';
  const [countryInput, setCountryInput] = useState(countryCode);
  const [cursorStack, setCursorStack] = useState<string[]>([]);
  const [page, setPage] = useState<CursorPage<ReviewRequestListItem> | null>(
    null,
  );
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<unknown>(null);
  const [reloadToken, setReloadToken] = useState(0);
  const cursor = cursorStack.at(-1);
  const canOpenDetail = hasAdminCapability(
    role,
    AdminCapability.ViewReviewRequestMetadata,
  );
  const canOpenAssignedDetail = hasAdminCapability(
    role,
    AdminCapability.ViewAssignedReviewRequests,
  );

  const querySignature = `${status}|${countryCode}|${overdueOnly}`;

  useEffect(() => {
    setCountryInput(countryCode);
    setCursorStack([]);
  }, [countryCode, querySignature]);

  useEffect(() => {
    let cancelled = false;
    setLoading(true);
    setError(null);

    void listReviewRequests({
      cursor,
      limit: 20,
      statuses: status ? [status] : undefined,
      countryCode: countryCode || undefined,
      overdueOnly,
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
  }, [countryCode, cursor, overdueOnly, reloadToken, status]);

  const replaceFilters = useMemo(
    () =>
      (changes: Readonly<Record<string, string | null>>) => {
        const next = new URLSearchParams(searchParams.toString());
        for (const [key, value] of Object.entries(changes)) {
          if (!value) next.delete(key);
          else next.set(key, value);
        }
        next.delete('selectedRequestId');
        router.replace(`/competition-readiness?${next.toString()}`);
      },
    [router, searchParams],
  );

  function applyCountry(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    replaceFilters({
      reviewCountry: normalizeCountryCode(countryInput) || null,
    });
  }

  function refresh() {
    setReloadToken((value) => value + 1);
  }

  if (error && isEndpointUnavailable(error)) {
    return (
      <EndpointUnavailableState
        endpoint="GET /api/admin/competition-readiness/review-requests"
        onRetry={refresh}
      />
    );
  }

  return (
    <div className={styles.splitLayout}>
      <div className={styles.stack}>
        <form className={styles.filters} onSubmit={applyCountry}>
          <Field label={t('filterStatus')}>
            {({ id, invalid }) => (
              <Select
                id={id}
                invalid={invalid}
                value={status}
                onChange={(event) =>
                  replaceFilters({
                    reviewStatus: event.target.value || null,
                  })
                }
              >
                <option value="">{t('allStatuses')}</option>
                {REVIEW_STATUSES.map((value) => (
                  <option key={value} value={value}>
                    {t(`reviewStatus_${value}`)}
                  </option>
                ))}
              </Select>
            )}
          </Field>
          <Field label={t('filterCountry')}>
            {({ id, invalid }) => (
              <Input
                id={id}
                invalid={invalid}
                value={countryInput}
                maxLength={3}
                placeholder="NE"
                onChange={(event) => setCountryInput(event.target.value)}
              />
            )}
          </Field>
          <label className={styles.checkbox}>
            <input
              type="checkbox"
              checked={overdueOnly}
              onChange={(event) =>
                replaceFilters({
                  reviewOverdue: event.target.checked ? 'true' : null,
                })
              }
            />
            {t('overdueOnly')}
          </label>
          <Button type="submit" variant="secondary">
            {t('applyFilters')}
          </Button>
        </form>

        {error ? (
          <Alert variant="danger">
            <div className={styles.stack}>
              <span>{t('requestsLoadError')}</span>
              <div>
                <Button variant="secondary" size="sm" onClick={refresh}>
                  {t('retry')}
                </Button>
              </div>
            </div>
          </Alert>
        ) : null}

        <AdminTable
          title={t('requestsTitle')}
          columns={[
            t('colScholarship'),
            t('colStatus'),
            t('colAdvisor'),
            t('colSla'),
            t('colUpdated'),
          ]}
          cols="1.6fr 0.9fr 1.1fr 0.8fr 1fr"
          footnote={
            canOpenAssignedDetail
              ? t('requestsTableNote')
              : t('metadataOnlyNote')
          }
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
                key={item.id}
                selected={selectedRequestId === item.id}
                onSelect={
                  canOpenDetail ? () => onSelectRequest(item.id) : undefined
                }
              >
                <CellText
                  primary={item.scholarship.title}
                  sub={`${item.scholarship.id} · ${item.scholarship.cycleId}`}
                />
                <Badge variant={reviewStatusVariant(item.status)}>
                  {t(`reviewStatus_${item.status}`)}
                </Badge>
                <CellText
                  primary={
                    item.assignedCounsellorName ?? t('unassignedAdvisor')
                  }
                  muted={!item.assignedCounsellorName}
                />
                <CellText
                  primary={
                    item.slaBreached ? t('slaBreached') : t('slaOnTrack')
                  }
                  sub={formatDateTime(item.slaDueAt, locale)}
                  muted={!item.slaBreached}
                />
                <CellText
                  primary={formatDateTime(item.updatedAt, locale)}
                  muted
                />
              </AdminTableRow>
            ))
          ) : (
            <EmptyState
              title={t('requestsEmptyTitle')}
              description={t('requestsEmptyDescription')}
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
              onClick={() =>
                setCursorStack((current) => current.slice(0, -1))
              }
            >
              {t('previous')}
            </Button>
            <Button
              variant="secondary"
              size="sm"
              disabled={loading || !page?.nextCursor}
              onClick={() => {
                if (page?.nextCursor) {
                  setCursorStack((current) => [
                    ...current,
                    page.nextCursor as string,
                  ]);
                }
              }}
            >
              {t('next')}
            </Button>
            <Button variant="ghost" size="sm" onClick={refresh}>
              {t('refresh')}
            </Button>
          </div>
        </div>
      </div>

      {canOpenDetail ? (
        selectedRequestId ? (
          <ReviewRequestDetailPanel
            requestId={selectedRequestId}
            role={role}
            onClose={() => onSelectRequest(null)}
            onUpdated={refresh}
          />
        ) : (
          <aside className={`${styles.panel} ${styles.panelSticky}`}>
            <EmptyState
              title={t('selectRequestTitle')}
              description={t('selectRequestDescription')}
            />
          </aside>
        )
      ) : (
        <aside className={`${styles.panel} ${styles.panelSticky}`}>
          <EmptyState
            title={t('metadataOnlyTitle')}
            description={t('metadataOnlyDescription')}
          />
        </aside>
      )}
    </div>
  );
}
