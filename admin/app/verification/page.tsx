'use client';

import { useEffect, useState } from 'react';

import { DashboardShell } from '../../components/dashboard-shell';
import {
  fetchVerificationDue,
  VerificationPolicy,
  VerificationQueueItem,
} from '../../lib/catalog-api';
import { badgeStyle, mutedTextStyle, panelStyle } from '../../lib/ui';

function formatDate(value: string | null) {
  if (!value) return 'Never';
  return new Intl.DateTimeFormat('fr-FR', {
    day: '2-digit',
    month: 'short',
    year: 'numeric',
  }).format(new Date(value));
}

export default function VerificationPage() {
  const [items, setItems] = useState<VerificationQueueItem[]>([]);
  const [policies, setPolicies] = useState<VerificationPolicy[]>([]);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  useEffect(() => {
    void fetchVerificationDue()
      .then((response) => {
        setItems(response.items);
        setPolicies(response.policies);
        setErrorMessage(null);
      })
      .catch((error) =>
        setErrorMessage(
          error instanceof Error
            ? error.message
            : 'Unable to load verification queue.',
        ),
      );
  }, []);

  return (
    <DashboardShell title="Verification queue">
      <div style={{ display: 'grid', gap: 18 }}>
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
              <span style={badgeStyle}>{policy.cadenceDays} days</span>
              <h3 style={{ marginBottom: 8 }}>{policy.label}</h3>
              <p style={{ ...mutedTextStyle, margin: 0 }}>{policy.owner}</p>
            </div>
          ))}
        </div>

        <div style={panelStyle}>
          <div
            style={{
              display: 'flex',
              justifyContent: 'space-between',
              gap: 16,
              alignItems: 'center',
              marginBottom: 14,
            }}
          >
            <h3 style={{ margin: 0 }}>Rows due for review</h3>
            <span style={badgeStyle}>{items.length} open</span>
          </div>

          {items.length === 0 ? (
            <p style={mutedTextStyle}>No catalogue rows are due.</p>
          ) : (
            <div style={{ overflowX: 'auto' }}>
              <table
                style={{
                  width: '100%',
                  borderCollapse: 'collapse',
                  minWidth: 860,
                }}
              >
                <thead>
                  <tr style={{ textAlign: 'left', color: '#64748B' }}>
                    <th style={{ padding: '10px 8px' }}>Row</th>
                    <th style={{ padding: '10px 8px' }}>Category</th>
                    <th style={{ padding: '10px 8px' }}>Owner</th>
                    <th style={{ padding: '10px 8px' }}>Last check</th>
                    <th style={{ padding: '10px 8px' }}>Verifier</th>
                    <th style={{ padding: '10px 8px' }}>Source</th>
                  </tr>
                </thead>
                <tbody>
                  {items.map((item) => (
                    <tr key={`${item.entityType}:${item.id}`}>
                      <td style={{ borderTop: '1px solid #E2E8F0', padding: 8 }}>
                        <strong>{item.label}</strong>
                        <br />
                        <span style={mutedTextStyle}>
                          {item.entityType}
                          {item.context ? ` · ${item.context}` : ''}
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
                        {item.verifiedByName ?? 'Not recorded'}
                      </td>
                      <td style={{ borderTop: '1px solid #E2E8F0', padding: 8 }}>
                        {item.verificationSourceUrl ? (
                          <a href={item.verificationSourceUrl}>
                            Official source
                          </a>
                        ) : (
                          <span style={mutedTextStyle}>Missing</span>
                        )}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>
      </div>
    </DashboardShell>
  );
}
