'use client';

import { CSSProperties, useCallback, useEffect, useState } from 'react';

import { useAdminAuth } from '../../components/admin-auth-provider';
import { DashboardShell } from '../../components/dashboard-shell';
import { useLocale } from '../../components/locale-provider';
import { fetchVerificationDue } from '../../lib/catalog-api';
import type {
  VerificationPolicy,
  VerificationQueueItem,
} from '../../lib/catalog-api';
import { apiFetch } from '../../lib/api-client';
import {
  AdminTable,
  AdminTableRow,
  Alert,
  Badge,
  Button,
  CellText,
  EmptyState,
  Input,
} from '../../components/ui';

const policyCardStyle: CSSProperties = {
  background: 'var(--surface)',
  border: '1px solid var(--border)',
  borderRadius: 16,
  padding: 16,
  display: 'grid',
  gap: 8,
  justifyItems: 'start',
};

export default function VerificationPage() {
  const { session } = useAdminAuth();
  const { t, locale } = useLocale();
  const [items, setItems] = useState<VerificationQueueItem[]>([]);
  const [policies, setPolicies] = useState<VerificationPolicy[]>([]);
  const [sourceInputs, setSourceInputs] = useState<Record<string, string>>({});
  const [pendingKey, setPendingKey] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [statusMessage, setStatusMessage] = useState<string | null>(null);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  function formatDate(value: string | null) {
    if (!value) return t('verification.never');
    return new Intl.DateTimeFormat(locale === 'fr' ? 'fr-FR' : 'en-GB', {
      day: '2-digit',
      month: 'short',
      year: 'numeric',
    }).format(new Date(value));
  }

  const loadQueue = useCallback(async () => {
    setLoading(true);
    setErrorMessage(null);
    try {
      const response = await fetchVerificationDue();
      setItems(response.items);
      setPolicies(response.policies);
      setSourceInputs(
        Object.fromEntries(
          response.items.map((item) => [
            `${item.entityType}:${item.id}`,
            item.sourceUrl ?? '',
          ]),
        ),
      );
    } catch (error) {
      setErrorMessage(
        error instanceof Error ? error.message : t('verification.loadError'),
      );
    } finally {
      setLoading(false);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  useEffect(() => {
    if (!session) {
      return;
    }
    void loadQueue();
  }, [loadQueue, session]);

  async function verifyItem(item: VerificationQueueItem, verified: boolean) {
    const key = `${item.entityType}:${item.id}`;
    const sourceUrl = (sourceInputs[key] ?? '').trim();
    setPendingKey(key);
    setStatusMessage(null);
    setErrorMessage(null);
    try {
      const updated = await apiFetch<{
        lastVerifiedAt: string | null;
        verifiedByName: string | null;
        sourceUrl: string | null;
      }>('/admin/catalog/verify', {
        method: 'POST',
        body: {
          entity: item.entityType,
          id: item.id,
          verified,
          sourceUrl: verified && sourceUrl ? sourceUrl : undefined,
        },
      });

      if (verified) {
        setItems((current) =>
          current.filter(
            (entry) =>
              entry.id !== item.id || entry.entityType !== item.entityType,
          ),
        );
      } else {
        setItems((current) =>
          current.map((entry) =>
            entry.id === item.id && entry.entityType === item.entityType
              ? {
                  ...entry,
                  lastVerifiedAt: updated?.lastVerifiedAt ?? null,
                  verifiedByName: updated?.verifiedByName ?? null,
                  sourceUrl: updated?.sourceUrl ?? null,
                }
              : entry,
          ),
        );
      }

      setSourceInputs((current) => ({
        ...current,
        [key]: updated?.sourceUrl ?? '',
      }));
      setStatusMessage(
        verified
          ? t('verification.verifiedSuccess')
          : t('verification.resetSuccess'),
      );
    } catch (error) {
      setErrorMessage(
        error instanceof Error ? error.message : t('verification.updateError'),
      );
    } finally {
      setPendingKey(null);
    }
  }

  return (
    <DashboardShell title={t('verification.title')} subtitle={t('verification.subtitle')}>
      <div style={{ display: 'grid', gap: 14 }}>
        {statusMessage ? <Alert variant="success">{statusMessage}</Alert> : null}
        {errorMessage ? <Alert variant="danger">{errorMessage}</Alert> : null}

        <div
          style={{
            display: 'grid',
            gap: 12,
            gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))',
          }}
        >
          {policies.map((policy) => (
            <section key={policy.key} style={policyCardStyle} aria-label={policy.label}>
              <Badge variant="brand">
                {policy.cadenceDays} {t('verification.daysSuffix')}
              </Badge>
              <h3
                style={{
                  margin: 0,
                  fontSize: 'var(--text-base)',
                  fontWeight: 800,
                  color: 'var(--ink)',
                }}
              >
                {policy.label}
              </h3>
              <p style={{ margin: 0, fontSize: 'var(--text-xs)', color: 'var(--text-muted)' }}>
                {policy.owner}
              </p>
            </section>
          ))}
        </div>

        <AdminTable
          title={`${t('verification.queueTitle')} — ${items.length} ${t('verification.openSuffix')}`}
          columns={[
            t('verification.colItem'),
            t('verification.colCategory'),
            t('verification.colLastCheck'),
            t('verification.colVerifiedBy'),
            t('verification.colSource'),
            t('verification.colActions'),
          ]}
          cols="1.5fr 0.9fr 0.8fr 0.9fr 1.6fr 1.1fr"
          footnote={t('verification.tableNote')}
        >
          {loading ? (
            <EmptyState title={t('verification.loading')} />
          ) : items.length === 0 ? (
            <EmptyState title={t('verification.empty')} />
          ) : (
            items.map((item) => {
              const key = `${item.entityType}:${item.id}`;
              const isPending = pendingKey === key;
              return (
                <AdminTableRow key={key}>
                  <CellText
                    primary={item.label}
                    sub={`${item.entityType}${item.context ? ` / ${item.context}` : ''}`}
                  />
                  <CellText primary={item.categoryLabel} sub={item.owner} muted />
                  <CellText primary={formatDate(item.lastVerifiedAt)} muted />
                  <CellText
                    primary={item.verifiedByName ?? t('verification.notProvided')}
                    muted={!item.verifiedByName}
                  />
                  <Input
                    value={sourceInputs[key] ?? ''}
                    onChange={(event) =>
                      setSourceInputs((current) => ({
                        ...current,
                        [key]: event.target.value,
                      }))
                    }
                    placeholder={t('verification.sourcePlaceholder')}
                    aria-label={t('verification.colSource')}
                    style={{ padding: '8px 10px', fontSize: 'var(--text-sm)' }}
                  />
                  <div style={{ display: 'flex', gap: 6 }}>
                    <Button
                      size="sm"
                      variant="success"
                      loading={isPending}
                      onClick={() => verifyItem(item, true)}
                    >
                      {t('verification.validateCta')}
                    </Button>
                    <Button
                      size="sm"
                      variant="dangerOutline"
                      disabled={isPending}
                      onClick={() => verifyItem(item, false)}
                    >
                      {t('verification.resetCta')}
                    </Button>
                  </div>
                </AdminTableRow>
              );
            })
          )}
        </AdminTable>
      </div>
    </DashboardShell>
  );
}
