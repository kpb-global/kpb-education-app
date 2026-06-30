'use client';

import { FormEvent, useCallback, useEffect, useState } from 'react';

import { DashboardShell } from '../../components/dashboard-shell';
import { apiFetch } from '../../lib/api-client';
import {
  badgeStyle,
  buttonStyle,
  inputStyle,
  labelStyle,
  mutedTextStyle,
  panelStyle,
  secondaryButtonStyle,
  textareaStyle,
} from '../../lib/ui';

const PURCHASE_STATUSES = [
  'pending_payment',
  'paid',
  'in_progress',
  'delivered',
  'cancelled',
  'refunded',
];

interface ServicePurchaseItem {
  id: string;
  status: string;
  amountXOF: number;
  source: string;
  internalNotes: string | null;
  createdAt: string;
  deliveredAt: string | null;
  package: {
    code: string;
    nameFr: string;
    category: string;
  };
  user: {
    fullName: string;
    email: string;
  };
  case: {
    id: string;
    referenceCode: string;
    requestedCountryId: string | null;
    source: string;
  } | null;
  paymentIntent: {
    provider: string;
    status: string;
  } | null;
}

interface PurchaseFormState {
  status: string;
  internalNotes: string;
}

function formatFcfa(value: number) {
  return new Intl.NumberFormat('fr-FR').format(value);
}

export default function ServiceSalesPage() {
  const [items, setItems] = useState<ServicePurchaseItem[]>([]);
  const [filter, setFilter] = useState('');
  const [forms, setForms] = useState<Record<string, PurchaseFormState>>({});
  const [statusMessage, setStatusMessage] = useState<string | null>(null);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  const loadPurchases = useCallback(async () => {
    setErrorMessage(null);
    try {
      const response = await apiFetch<{ items: ServicePurchaseItem[] }>(
        `/admin/service-packages/purchases/list${filter ? `?status=${filter}` : ''}`,
      );
      setItems(response.items);
      setForms(
        Object.fromEntries(
          response.items.map((item) => [
            item.id,
            {
              status: item.status,
              internalNotes: item.internalNotes ?? '',
            },
          ]),
        ),
      );
    } catch (error) {
      setErrorMessage(
        error instanceof Error
          ? error.message
          : 'Unable to load service purchases.',
      );
    }
  }, [filter]);

  useEffect(() => {
    void loadPurchases();
  }, [loadPurchases]);

  async function submitUpdate(
    event: FormEvent<HTMLFormElement>,
    purchaseId: string,
  ) {
    event.preventDefault();
    const form = forms[purchaseId];
    if (!form) return;

    setStatusMessage(null);
    setErrorMessage(null);
    try {
      await apiFetch(`/admin/service-packages/purchases/${purchaseId}`, {
        method: 'PATCH',
        body: {
          status: form.status,
          internalNotes: form.internalNotes || undefined,
        },
      });
      setStatusMessage('Service purchase updated.');
      await loadPurchases();
    } catch (error) {
      setErrorMessage(
        error instanceof Error
          ? error.message
          : 'Unable to update service purchase.',
      );
    }
  }

  return (
    <DashboardShell title="Service sales">
      <div style={{ display: 'grid', gap: 18 }}>
        {statusMessage ? (
          <div
            style={{ ...panelStyle, background: '#ECFDF5', color: '#166534' }}
          >
            {statusMessage}
          </div>
        ) : null}
        {errorMessage ? (
          <div
            style={{ ...panelStyle, background: '#FEF2F2', color: '#B91C1C' }}
          >
            {errorMessage}
          </div>
        ) : null}

        <section style={panelStyle}>
          <div
            style={{
              display: 'flex',
              gap: 12,
              justifyContent: 'space-between',
              alignItems: 'end',
            }}
          >
            <label style={{ ...labelStyle, maxWidth: 280 }}>
              Status
              <select
                value={filter}
                onChange={(event) => setFilter(event.target.value)}
                style={inputStyle}
              >
                <option value="">All purchases</option>
                {PURCHASE_STATUSES.map((status) => (
                  <option key={status} value={status}>
                    {status.replaceAll('_', ' ')}
                  </option>
                ))}
              </select>
            </label>
            <button
              type="button"
              onClick={() => void loadPurchases()}
              style={secondaryButtonStyle}
            >
              Refresh
            </button>
          </div>
        </section>

        <div style={{ display: 'grid', gap: 14 }}>
          {items.map((item) => {
            const form = forms[item.id] ?? {
              status: item.status,
              internalNotes: item.internalNotes ?? '',
            };

            return (
              <section key={item.id} style={panelStyle}>
                <div
                  style={{
                    display: 'grid',
                    gap: 16,
                    gridTemplateColumns: '1fr 320px',
                  }}
                >
                  <div>
                    <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
                      <span style={badgeStyle}>{item.status}</span>
                      <span style={badgeStyle}>{item.source}</span>
                      <span style={badgeStyle}>{item.package.code}</span>
                    </div>
                    <h3 style={{ marginBottom: 8 }}>{item.package.nameFr}</h3>
                    <p style={{ margin: '6px 0' }}>
                      {formatFcfa(item.amountXOF)} FCFA · {item.user.fullName}{' '}
                      · {item.user.email}
                    </p>
                    <p style={mutedTextStyle}>
                      Dossier:{' '}
                      {item.case
                        ? `${item.case.referenceCode} · ${item.case.requestedCountryId ?? 'destination inconnue'}`
                        : 'non rattaché'}
                    </p>
                    <p style={mutedTextStyle}>
                      Paiement:{' '}
                      {item.paymentIntent
                        ? `${item.paymentIntent.provider} · ${item.paymentIntent.status}`
                        : 'manuel / WhatsApp'}
                    </p>
                  </div>

                  <form
                    onSubmit={(event) => submitUpdate(event, item.id)}
                    style={{ display: 'grid', gap: 10 }}
                  >
                    <label style={labelStyle}>
                      Lifecycle
                      <select
                        value={form.status}
                        onChange={(event) =>
                          setForms((current) => ({
                            ...current,
                            [item.id]: {
                              ...form,
                              status: event.target.value,
                            },
                          }))
                        }
                        style={inputStyle}
                      >
                        {PURCHASE_STATUSES.map((status) => (
                          <option key={status} value={status}>
                            {status.replaceAll('_', ' ')}
                          </option>
                        ))}
                      </select>
                    </label>
                    <label style={labelStyle}>
                      Internal notes
                      <textarea
                        value={form.internalNotes}
                        onChange={(event) =>
                          setForms((current) => ({
                            ...current,
                            [item.id]: {
                              ...form,
                              internalNotes: event.target.value,
                            },
                          }))
                        }
                        style={textareaStyle}
                      />
                    </label>
                    <button type="submit" style={buttonStyle}>
                      Save lifecycle
                    </button>
                  </form>
                </div>
              </section>
            );
          })}
          {items.length === 0 ? (
            <section style={panelStyle}>No service purchases yet.</section>
          ) : null}
        </div>
      </div>
    </DashboardShell>
  );
}
