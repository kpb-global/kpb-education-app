'use client';

import { useCallback, useEffect, useState } from 'react';

import { useAdminAuth } from '../../components/admin-auth-provider';
import { DashboardShell } from '../../components/dashboard-shell';
import { fetchVerificationDue } from '../../lib/catalog-api';
import type {
  VerificationPolicy,
  VerificationQueueItem,
} from '../../lib/catalog-api';
import { apiFetch } from '../../lib/api-client';
import {
  badgeStyle,
  buttonStyle,
  inputStyle,
  mutedTextStyle,
  panelStyle,
} from '../../lib/ui';

const resetButtonStyle = {
  ...buttonStyle,
  background: 'var(--surface-2)',
  color: 'var(--text)',
};

function formatDate(value: string | null) {
  if (!value) return 'Jamais';
  return new Intl.DateTimeFormat('fr-FR', {
    day: '2-digit',
    month: 'short',
    year: 'numeric',
  }).format(new Date(value));
}

export default function VerificationPage() {
  const { session } = useAdminAuth();
  const [items, setItems] = useState<VerificationQueueItem[]>([]);
  const [policies, setPolicies] = useState<VerificationPolicy[]>([]);
  const [sourceInputs, setSourceInputs] = useState<Record<string, string>>({});
  const [pendingKey, setPendingKey] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [statusMessage, setStatusMessage] = useState<string | null>(null);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

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
        error instanceof Error
          ? error.message
          : 'Impossible de charger la file de verification.',
      );
    } finally {
      setLoading(false);
    }
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
          ? 'Entree marquee comme verifiee.'
          : 'Verification reinitialisee.',
      );
    } catch (error) {
      setErrorMessage(
        error instanceof Error
          ? error.message
          : 'Impossible de mettre a jour la verification.',
      );
    } finally {
      setPendingKey(null);
    }
  }

  return (
    <DashboardShell title="Verification catalogue">
      <div style={{ display: 'grid', gap: 18 }}>
        {statusMessage ? (
          <div style={{ ...panelStyle, background: '#ECFDF5', color: '#166534' }}>
            {statusMessage}
          </div>
        ) : null}
        {errorMessage ? (
          <div style={{ ...panelStyle, background: '#FEF2F2', color: '#B91C1C' }}>
            {errorMessage}
          </div>
        ) : null}

        <div
          style={{
            display: 'grid',
            gap: 14,
            gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))',
          }}
        >
          {policies.map((policy) => (
            <div key={policy.key} style={panelStyle}>
              <span style={badgeStyle}>{policy.cadenceDays} jours</span>
              <h3 style={{ marginBottom: 8 }}>{policy.label}</h3>
              <p style={{ ...mutedTextStyle, margin: 0 }}>{policy.owner}</p>
            </div>
          ))}
        </div>

        <section style={panelStyle}>
          <div
            style={{
              display: 'flex',
              justifyContent: 'space-between',
              gap: 16,
              alignItems: 'center',
              marginBottom: 14,
            }}
          >
            <h3 style={{ margin: 0 }}>Lignes a revoir</h3>
            <span style={badgeStyle}>{items.length} ouvertes</span>
          </div>

          {loading ? (
            <p style={mutedTextStyle}>Chargement...</p>
          ) : items.length === 0 ? (
            <p style={mutedTextStyle}>Aucune ligne catalogue a revoir.</p>
          ) : (
            <div style={{ overflowX: 'auto' }}>
              <table
                style={{
                  width: '100%',
                  borderCollapse: 'collapse',
                  minWidth: 980,
                }}
              >
                <thead>
                  <tr style={{ textAlign: 'left', color: '#64748B' }}>
                    <th style={{ padding: '10px 8px' }}>Ligne</th>
                    <th style={{ padding: '10px 8px' }}>Categorie</th>
                    <th style={{ padding: '10px 8px' }}>Responsable</th>
                    <th style={{ padding: '10px 8px' }}>Dernier check</th>
                    <th style={{ padding: '10px 8px' }}>Verifie par</th>
                    <th style={{ padding: '10px 8px' }}>Source</th>
                    <th style={{ padding: '10px 8px' }}>Action</th>
                  </tr>
                </thead>
                <tbody>
                  {items.map((item) => {
                    const key = `${item.entityType}:${item.id}`;
                    const isPending = pendingKey === key;
                    return (
                      <tr key={key}>
                        <td style={{ borderTop: '1px solid #E2E8F0', padding: 8 }}>
                          <strong>{item.label}</strong>
                          <br />
                          <span style={mutedTextStyle}>
                            {item.entityType}
                            {item.context ? ` / ${item.context}` : ''}
                          </span>
                        </td>
                        <td style={{ borderTop: '1px solid #E2E8F0', padding: 8 }}>
                          {item.categoryLabel}
                        </td>
                        <td style={{ borderTop: '1px solid #E2E8F0', padding: 8 }}>
                          {item.owner}
                        </td>
                        <td style={{ borderTop: '1px solid #E2E8F0', padding: 8 }}>
                          {formatDate(item.lastVerifiedAt)}
                        </td>
                        <td style={{ borderTop: '1px solid #E2E8F0', padding: 8 }}>
                          {item.verifiedByName ?? 'Non renseigne'}
                        </td>
                        <td style={{ borderTop: '1px solid #E2E8F0', padding: 8 }}>
                          <input
                            value={sourceInputs[key] ?? ''}
                            onChange={(event) =>
                              setSourceInputs((current) => ({
                                ...current,
                                [key]: event.target.value,
                              }))
                            }
                            placeholder="https://source-officielle.example"
                            style={{ ...inputStyle, minWidth: 260 }}
                          />
                        </td>
                        <td style={{ borderTop: '1px solid #E2E8F0', padding: 8 }}>
                          <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
                            <button
                              type="button"
                              onClick={() => verifyItem(item, true)}
                              disabled={isPending}
                              style={{
                                ...buttonStyle,
                                opacity: isPending ? 0.6 : 1,
                              }}
                            >
                              Valider
                            </button>
                            <button
                              type="button"
                              onClick={() => verifyItem(item, false)}
                              disabled={isPending}
                              style={{
                                ...resetButtonStyle,
                                opacity: isPending ? 0.6 : 1,
                              }}
                            >
                              Reset
                            </button>
                          </div>
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          )}
        </section>
      </div>
    </DashboardShell>
  );
}
