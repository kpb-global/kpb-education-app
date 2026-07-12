'use client';

import { CSSProperties, useEffect, useState } from 'react';
import Link from 'next/link';

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

interface DashboardActivation {
  weeklyQualifiedLeads: Array<{ weekStart: string; count: number }>;
  urgent: {
    awaitingDocuments: number;
    verificationDue: number;
    moderationQueue: number;
  };
}

interface FunnelResponse {
  items: Array<{ key: string; value: number }>;
}

// WhatsApp brand green — the handoff's North-Star chart color.
const WA_GREEN = '#25D366';

const FUNNEL_COLORS = [
  'var(--brand)',
  'var(--sky)',
  'var(--success-fg)',
  'var(--warning-fg)',
];

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
  const { t, locale } = useLocale();
  const [overview, setOverview] = useState<OverviewMetrics | null>(null);
  const [activation, setActivation] = useState<DashboardActivation | null>(
    null,
  );
  const [funnel, setFunnel] = useState<FunnelResponse | null>(null);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  useEffect(() => {
    if (!session) {
      return;
    }
    let cancelled = false;
    void Promise.all([
      apiFetch<OverviewMetrics>('/admin/reports/overview'),
      apiFetch<DashboardActivation>('/admin/reports/dashboard-activation'),
      apiFetch<FunnelResponse>('/admin/reports/funnel'),
    ])
      .then(([overviewResponse, activationResponse, funnelResponse]) => {
        if (cancelled) return;
        setOverview(overviewResponse);
        setActivation(activationResponse);
        setFunnel(funnelResponse);
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

  const weeks = activation?.weeklyQualifiedLeads ?? [];
  const maxWeekly = Math.max(1, ...weeks.map((week) => week.count));
  const funnelItems = funnel?.items ?? [];
  const funnelBase = Math.max(1, funnelItems[0]?.value ?? 0);
  const urgent = activation?.urgent;
  const urgentRows = urgent
    ? [
        {
          key: 'awaitingDocs',
          count: urgent.awaitingDocuments,
          href: '/cases',
          color: 'var(--warning-fg)',
          icon: 'doc',
        },
        {
          key: 'verificationDue',
          count: urgent.verificationDue,
          href: '/verification',
          color: 'var(--info-fg)',
          icon: 'timer',
        },
        {
          key: 'moderationQueue',
          count: urgent.moderationQueue,
          href: '/community',
          color: 'var(--danger-fg)',
          icon: 'star',
        },
      ].filter((row) => row.count > 0)
    : [];

  function weekLabel(weekStart: string) {
    return new Intl.DateTimeFormat(locale === 'fr' ? 'fr-FR' : 'en-GB', {
      day: '2-digit',
      month: '2-digit',
    }).format(new Date(`${weekStart}T00:00:00Z`));
  }

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
    <DashboardShell title={t('overview.title')} subtitle={t('overview.subtitle')}>
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
          {/* North-Star weekly bar chart (handoff, US-041). */}
          <div style={{ ...cardStyle, display: 'grid', gap: 14 }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
              <h3
                style={{
                  margin: 0,
                  flex: 1,
                  fontSize: 13.5,
                  fontWeight: 800,
                  color: 'var(--ink)',
                }}
              >
                {t('overview.northStarTitle')}
              </h3>
              <span
                aria-hidden="true"
                style={{
                  width: 9,
                  height: 9,
                  borderRadius: 3,
                  background: WA_GREEN,
                }}
              />
              <span
                style={{
                  fontSize: 10,
                  fontWeight: 700,
                  color: 'var(--text-muted)',
                }}
              >
                {t('overview.northStarLegend')}
              </span>
            </div>
            <div
              style={{
                display: 'flex',
                alignItems: 'flex-end',
                gap: 10,
                height: 150,
              }}
            >
              {weeks.map((week) => (
                <div
                  key={week.weekStart}
                  style={{
                    flex: 1,
                    height: '100%',
                    display: 'flex',
                    flexDirection: 'column',
                    alignItems: 'center',
                    justifyContent: 'flex-end',
                    gap: 5,
                  }}
                >
                  <span
                    style={{
                      fontSize: 9,
                      fontWeight: 800,
                      color:
                        week.count > 0 ? 'var(--ink)' : 'var(--text-faint)',
                    }}
                  >
                    {week.count}
                  </span>
                  <div
                    style={{
                      width: '100%',
                      maxWidth: 30,
                      height: `${Math.max(
                        3,
                        Math.round((week.count / maxWeekly) * 100),
                      )}%`,
                      borderRadius: '7px 7px 3px 3px',
                      background: week.count > 0 ? WA_GREEN : 'var(--border)',
                    }}
                  />
                  <span
                    style={{
                      fontSize: 9,
                      fontWeight: 700,
                      color: 'var(--text-faint)',
                    }}
                  >
                    {weekLabel(week.weekStart)}
                  </span>
                </div>
              ))}
              {weeks.length === 0 ? (
                <p
                  style={{
                    margin: 'auto',
                    fontSize: 'var(--text-sm)',
                    color: 'var(--text-faint)',
                  }}
                >
                  …
                </p>
              ) : null}
            </div>
            <p
              style={{
                margin: 0,
                fontSize: 10,
                lineHeight: 1.4,
                color: 'var(--text-faint)',
              }}
            >
              {t('overview.northStarHint')}
            </p>
          </div>

          {/* Activation funnel as labeled progress bars (handoff). */}
          <div style={{ ...cardStyle, display: 'grid', gap: 11 }}>
            <h3
              style={{
                margin: 0,
                fontSize: 13.5,
                fontWeight: 800,
                color: 'var(--ink)',
              }}
            >
              {t('overview.funnelTitle')}
            </h3>
            {funnelItems.map((item, index) => (
              <div key={item.key} style={{ display: 'grid', gap: 4 }}>
                <div style={{ display: 'flex', alignItems: 'baseline' }}>
                  <span
                    style={{
                      flex: 1,
                      fontSize: 11.5,
                      fontWeight: 700,
                      color: 'var(--ink)',
                    }}
                  >
                    {t(`reports.funnelStage_${item.key}`)}
                  </span>
                  <span
                    style={{
                      fontSize: 10.5,
                      fontWeight: 800,
                      color: 'var(--text-muted)',
                    }}
                  >
                    {item.value}
                  </span>
                </div>
                <div
                  style={{
                    height: 6,
                    borderRadius: 100,
                    background: 'var(--border-soft)',
                    overflow: 'hidden',
                  }}
                >
                  <div
                    style={{
                      width: `${Math.min(
                        100,
                        Math.round((item.value / funnelBase) * 100),
                      )}%`,
                      height: '100%',
                      borderRadius: 100,
                      background: FUNNEL_COLORS[index % FUNNEL_COLORS.length],
                    }}
                  />
                </div>
              </div>
            ))}
            {funnelItems.length === 0 ? (
              <p
                style={{
                  margin: 0,
                  fontSize: 'var(--text-sm)',
                  color: 'var(--text-faint)',
                }}
              >
                …
              </p>
            ) : null}
            <p
              style={{
                margin: 0,
                fontSize: 10,
                lineHeight: 1.4,
                color: 'var(--text-faint)',
              }}
            >
              {t('overview.funnelHint')}
            </p>
          </div>
        </div>

        {/* "Action immédiate requise" — real urgent counters with CTAs. */}
        <div style={{ ...cardStyle, display: 'grid', gap: 12 }}>
          <h3
            style={{
              margin: 0,
              fontSize: 13.5,
              fontWeight: 800,
              color: 'var(--ink)',
            }}
          >
            {t('overview.urgentTitle')}
          </h3>
          {urgentRows.map((row) => (
            <div
              key={row.key}
              style={{
                display: 'flex',
                alignItems: 'center',
                gap: 12,
                background: 'var(--bg)',
                border: '1px solid var(--border-soft)',
                borderRadius: 12,
                padding: '11px 14px',
              }}
            >
              <KpiIcon name={row.icon} color={row.color} />
              <span
                style={{
                  flex: 1,
                  fontSize: 12,
                  fontWeight: 700,
                  color: 'var(--ink)',
                }}
              >
                {row.count} {t(`overview.urgent_${row.key}`)}
              </span>
              <Link
                href={row.href}
                style={{
                  padding: '7px 13px',
                  borderRadius: 100,
                  background: 'var(--brand)',
                  color: '#fff',
                  fontSize: 10.5,
                  fontWeight: 800,
                  textDecoration: 'none',
                }}
              >
                {t('overview.urgentCta')}
              </Link>
            </div>
          ))}
          {urgent && urgentRows.length === 0 ? (
            <p
              style={{
                margin: 0,
                fontSize: 'var(--text-sm)',
                color: 'var(--text-muted)',
              }}
            >
              {t('overview.urgentEmpty')}
            </p>
          ) : null}
          {!urgent ? (
            <p
              style={{
                margin: 0,
                fontSize: 'var(--text-sm)',
                color: 'var(--text-faint)',
              }}
            >
              …
            </p>
          ) : null}
        </div>
      </div>
    </DashboardShell>
  );
}
