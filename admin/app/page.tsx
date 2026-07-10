'use client';

import { CSSProperties, useEffect, useState } from 'react';

import { useAdminAuth } from '../components/admin-auth-provider';
import { DashboardShell } from '../components/dashboard-shell';
import { useLocale } from '../components/locale-provider';
import { apiFetch } from '../lib/api-client';

interface OverviewMetrics {
  activeCases: number;
  awaitingDocuments: number;
  submittedThisWeek: number;
  paidServicePurchases: number;
  counselorResponseSlaHours: number | null;
}

const KPI_ICON_PATHS: Record<string, string> = {
  folder:
    'M3 7a2 2 0 0 1 2-2h4l2 2h8a2 2 0 0 1 2 2v9a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z',
  doc: 'M6 3h9l4 4v14H6zM14 3v5h5M9 12h7M9 16h7',
  trendUp: 'M3 17l6-6 4 4 8-8M15 7h6v6',
  star: 'M12 3l2.7 5.8 6.3.8-4.6 4.4 1.2 6.2-5.6-3.1-5.6 3.1 1.2-6.2L3 9.6l6.3-.8z',
  timer: 'M12 8v5l3 2M12 21a8 8 0 1 0 0-16 8 8 0 0 0 0 16zM9 2h6',
};

function KpiIcon({ name, color }: Readonly<{ name: string; color: string }>) {
  return (
    <svg
      width={16}
      height={16}
      viewBox="0 0 24 24"
      fill="none"
      stroke={color}
      strokeWidth={1.8}
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
    >
      <path d={KPI_ICON_PATHS[name]} />
    </svg>
  );
}

const cardStyle: CSSProperties = {
  background: 'var(--surface)',
  border: '1px solid var(--border)',
  borderRadius: 16,
  padding: 18,
};

export default function OverviewPage() {
  const { session } = useAdminAuth();
  const { t } = useLocale();
  const [overview, setOverview] = useState<OverviewMetrics | null>(null);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  useEffect(() => {
    if (!session) {
      return;
    }
    let cancelled = false;
    void apiFetch<OverviewMetrics>('/admin/reports/overview')
      .then((response) => {
        if (cancelled) return;
        setOverview(response);
        setErrorMessage(null);
      })
      .catch((error) => {
        if (cancelled) return;
        setErrorMessage(
          error instanceof Error ? error.message : t('overview.loadError'),
        );
      });
    return () => {
      cancelled = true;
    };
  }, [session, t]);

  let slaValue = '…';
  if (overview) {
    slaValue =
      overview.counselorResponseSlaHours === null
        ? '—'
        : `${overview.counselorResponseSlaHours.toFixed(1)}h`;
  }

  const kpis: Array<{
    key: string;
    value: string;
    icon: string;
    iconBg: string;
    iconColor: string;
  }> = [
    {
      key: 'activeCases',
      value: String(overview?.activeCases ?? '…'),
      icon: 'folder',
      iconBg: 'var(--info-bg)',
      iconColor: 'var(--info-fg)',
    },
    {
      key: 'awaitingDocs',
      value: String(overview?.awaitingDocuments ?? '…'),
      icon: 'doc',
      iconBg: 'var(--warning-bg)',
      iconColor: 'var(--warning-fg)',
    },
    {
      key: 'submittedThisWeek',
      value: String(overview?.submittedThisWeek ?? '…'),
      icon: 'trendUp',
      iconBg: 'var(--success-bg)',
      iconColor: 'var(--success-fg)',
    },
    {
      key: 'paidServices',
      value: String(overview?.paidServicePurchases ?? '…'),
      icon: 'star',
      iconBg: 'var(--brand-soft)',
      iconColor: 'var(--brand)',
    },
    {
      key: 'responseSla',
      value: slaValue,
      icon: 'timer',
      iconBg: 'var(--danger-bg)',
      iconColor: 'var(--danger-fg)',
    },
  ];

  return (
    <DashboardShell title={t('overview.title')}>
      <div style={{ display: 'grid', gap: 14 }}>
        {errorMessage ? (
          <div
            role="alert"
            style={{
              ...cardStyle,
              background: 'var(--danger-bg)',
              border: '1px solid var(--danger-bg)',
              color: 'var(--danger-fg)',
              fontWeight: 600,
            }}
          >
            {errorMessage}
          </div>
        ) : null}

        <div
          style={{
            display: 'grid',
            gap: 12,
            gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))',
          }}
        >
          {kpis.map((kpi) => (
            <div
              key={kpi.key}
              style={{
                ...cardStyle,
                padding: 16,
                display: 'flex',
                flexDirection: 'column',
                gap: 8,
              }}
            >
              <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                <div
                  style={{
                    width: 32,
                    height: 32,
                    borderRadius: 10,
                    background: kpi.iconBg,
                    display: 'grid',
                    placeItems: 'center',
                    flexShrink: 0,
                  }}
                >
                  <KpiIcon name={kpi.icon} color={kpi.iconColor} />
                </div>
                <p
                  style={{
                    margin: 0,
                    fontSize: 'var(--text-xs)',
                    fontWeight: 700,
                    color: 'var(--text-muted)',
                  }}
                >
                  {t(`overview.${kpi.key}`)}
                </p>
              </div>
              <p
                style={{
                  margin: 0,
                  fontSize: 26,
                  fontWeight: 800,
                  letterSpacing: '-0.5px',
                  color: 'var(--ink)',
                  fontFamily: 'var(--font-jakarta, inherit)',
                }}
              >
                {kpi.value}
              </p>
              <p
                style={{
                  margin: 0,
                  fontSize: 10.5,
                  lineHeight: 1.4,
                  color: 'var(--text-faint)',
                }}
              >
                {t(`overview.${kpi.key}Hint`)}
              </p>
            </div>
          ))}
        </div>

        <div
          style={{
            display: 'grid',
            gap: 12,
            gridTemplateColumns: 'repeat(auto-fit, minmax(320px, 1fr))',
          }}
        >
          <div style={cardStyle}>
            <h3
              style={{
                marginTop: 0,
                marginBottom: 10,
                fontSize: 'var(--text-base)',
                fontWeight: 800,
                color: 'var(--ink)',
              }}
            >
              {t('overview.focusTitle')}
            </h3>
            <ul
              style={{
                margin: 0,
                paddingLeft: 18,
                lineHeight: 1.9,
                fontSize: 'var(--text-sm)',
                color: 'var(--text-muted)',
              }}
            >
              <li>{t('overview.focusItem1')}</li>
              <li>{t('overview.focusItem2')}</li>
              <li>{t('overview.focusItem3')}</li>
              <li>{t('overview.focusItem4')}</li>
            </ul>
          </div>
          <div style={cardStyle}>
            <h3
              style={{
                marginTop: 0,
                marginBottom: 10,
                fontSize: 'var(--text-base)',
                fontWeight: 800,
                color: 'var(--ink)',
              }}
            >
              {t('overview.permTitle')}
            </h3>
            <p
              style={{
                margin: 0,
                lineHeight: 1.7,
                fontSize: 'var(--text-sm)',
                color: 'var(--text-muted)',
              }}
            >
              {t('overview.permBody')}
            </p>
          </div>
        </div>
      </div>
    </DashboardShell>
  );
}
