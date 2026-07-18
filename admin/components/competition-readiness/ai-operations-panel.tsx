'use client';

import { useTranslations } from 'next-intl';
import { useEffect, useState } from 'react';

import {
  getAiUsage,
  type AiUsageResponse,
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
  Skeleton,
} from '../ui';
import { EndpointUnavailableState } from './endpoint-state';
import {
  formatDateTime,
  formatUsdMicros,
  isEndpointUnavailable,
} from './readiness-utils';
import styles from './readiness.module.css';

export function AiOperationsPanel({ role }: Readonly<{ role: string | undefined }>) {
  const t = useTranslations('competitionReadiness');
  const { locale } = useLocale();
  const [data, setData] = useState<AiUsageResponse | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<unknown>(null);
  const [reloadToken, setReloadToken] = useState(0);
  const canView = hasAdminCapability(role, AdminCapability.ViewAiOperations);

  useEffect(() => {
    if (!canView) {
      setLoading(false);
      return;
    }
    let cancelled = false;
    setLoading(true);
    setError(null);

    void getAiUsage({ limit: 20 })
      .then((response) => {
        if (!cancelled) setData(response);
      })
      .catch((nextError: unknown) => {
        if (!cancelled) {
          setData(null);
          setError(nextError);
        }
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });

    return () => {
      cancelled = true;
    };
  }, [canView, reloadToken]);

  if (!canView) {
    return <Alert variant="warning">{t('aiCapabilityRequired')}</Alert>;
  }

  if (error && isEndpointUnavailable(error)) {
    return (
      <div className={styles.stack}>
        <EndpointUnavailableState
          endpoint="GET /api/admin/competition-readiness/ai/usage"
          onRetry={() => setReloadToken((value) => value + 1)}
        />
        <section className={styles.readonlyControl}>
          <div>
            <h3 className={styles.panelTitle}>{t('killSwitchTitle')}</h3>
            <p className={styles.panelSubtitle}>{t('killSwitchUnavailable')}</p>
          </div>
          <Badge variant="neutral">{t('notExposed')}</Badge>
        </section>
      </div>
    );
  }

  const metricCards = [
    {
      label: 'aiEstimatedCost',
      value: data?.summary.estimatedCostMicrosUsd,
    },
    { label: 'aiBudget', value: data?.summary.budgetMicrosUsd },
    { label: 'aiReserved', value: data?.summary.reservedMicrosUsd },
    { label: 'aiSpent', value: data?.summary.spentMicrosUsd },
  ] as const;

  return (
    <div className={styles.stack}>
      <Alert variant="info">{t('aiReadOnlyNote')}</Alert>

      {error ? (
        <Alert variant="danger">
          <div className={styles.stack}>
            <span>{t('aiLoadError')}</span>
            <div>
              <Button variant="secondary" size="sm" onClick={() => setReloadToken((value) => value + 1)}>
                {t('retry')}
              </Button>
            </div>
          </div>
        </Alert>
      ) : null}

      <div className={styles.metrics}>
        {loading
          ? Array.from({ length: 4 }, (_, index) => (
              <div key={index} className={styles.metric}>
                <Skeleton height={16} width="55%" />
                <Skeleton height={30} width="80%" />
              </div>
            ))
          : metricCards.map((card) => (
              <article key={card.label} className={styles.metric}>
                <span className={styles.detailLabel}>{t(card.label)}</span>
                <p className={styles.metricValue}>
                  {formatUsdMicros(card.value, locale)}
                </p>
              </article>
            ))}
      </div>

      <section className={styles.readonlyControl}>
        <div>
          <h3 className={styles.panelTitle}>{t('killSwitchTitle')}</h3>
          <p className={styles.panelSubtitle}>{t('killSwitchUnavailable')}</p>
        </div>
        <Badge variant="neutral">{t('notExposed')}</Badge>
      </section>

      <AdminTable
        title={t('aiRecentAttempts')}
        columns={[
          t('colModel'),
          t('colOutcome'),
          t('colTokens'),
          t('colCost'),
          t('colCompleted'),
        ]}
        cols="1.2fr 0.9fr 0.8fr 0.9fr 1fr"
        footnote={t('aiAttemptsNote')}
      >
        {loading ? (
          Array.from({ length: 3 }, (_, index) => (
            <AdminTableRow key={index}>
              {Array.from({ length: 5 }, (__, cellIndex) => (
                <Skeleton key={cellIndex} height={18} />
              ))}
            </AdminTableRow>
          ))
        ) : data?.items.length ? (
          data.items.map((item) => (
            <AdminTableRow key={item.id}>
              <CellText primary={item.model} sub={item.provider} />
              <Badge variant={item.outcome === 'succeeded' ? 'success' : item.outcome === 'failed' ? 'danger' : 'neutral'}>
                {item.outcome}
              </Badge>
              <CellText
                primary={(item.inputTokens ?? 0) + (item.outputTokens ?? 0)}
                sub={t('tokensValue')}
                muted
              />
              <CellText primary={formatUsdMicros(item.estimatedCostMicrosUsd, locale)} muted />
              <CellText primary={formatDateTime(item.completedAt, locale)} muted />
            </AdminTableRow>
          ))
        ) : (
          <EmptyState title={t('aiAttemptsEmpty')} />
        )}
      </AdminTable>

      <section className={styles.panel}>
        <h3 className={styles.panelTitle}>{t('pendingAdminEndpointsTitle')}</h3>
        <ul className={styles.endpointList}>
          <li>GET /api/admin/competition-readiness/flags/:key</li>
          <li>PATCH /api/admin/competition-readiness/ai/budget</li>
          <li>PATCH /api/admin/competition-readiness/flags/:key</li>
        </ul>
      </section>
    </div>
  );
}
