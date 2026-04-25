'use client';

import { useEffect, useState } from 'react';

import { DashboardShell } from '../../components/dashboard-shell';
import { apiFetch } from '../../lib/api-client';
import { badgeStyle, mutedTextStyle, panelStyle } from '../../lib/ui';

interface FunnelRow {
  label: string;
  value: number;
}

interface PerformanceRow {
  label: string;
  value: string;
  secondary: string;
}

interface CounselorPerformanceRow {
  counselor: string;
  activeCases: number;
  avgResponseHours: number;
}

interface CampaignPerformanceRow {
  campaign: string;
  delivered: number;
  opened: number;
}

function ReportSection({
  title,
  rows,
}: Readonly<{ title: string; rows: PerformanceRow[] }>) {
  return (
    <section style={panelStyle}>
      <h3 style={{ marginTop: 0 }}>{title}</h3>
      <div style={{ display: 'grid', gap: 12 }}>
        {rows.map((row) => (
          <div key={`${title}-${row.label}`} style={{ borderTop: '1px solid #E2E8F0', paddingTop: 12 }}>
            <strong>{row.label}</strong>
            <p style={{ margin: '6px 0' }}>{row.value}</p>
            <span style={badgeStyle}>{row.secondary}</span>
          </div>
        ))}
      </div>
    </section>
  );
}

export default function ReportsPage() {
  const [funnel, setFunnel] = useState<FunnelRow[]>([]);
  const [counselorPerformance, setCounselorPerformance] = useState<
    PerformanceRow[]
  >([]);
  const [campaignPerformance, setCampaignPerformance] = useState<
    PerformanceRow[]
  >([]);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  useEffect(() => {
    void Promise.all([
      apiFetch<{ items: FunnelRow[] }>('/admin/reports/funnel'),
      apiFetch<{ items: CounselorPerformanceRow[] }>(
        '/admin/reports/counselor-performance',
      ),
      apiFetch<{ items: CampaignPerformanceRow[] }>(
        '/admin/reports/campaign-performance',
      ),
    ])
      .then(([funnelResponse, counselorResponse, campaignResponse]) => {
        setFunnel(funnelResponse.items);
        setCounselorPerformance(
          counselorResponse.items.map((row) => ({
            label: row.counselor,
            value: `${row.activeCases} active cases`,
            secondary: `${row.avgResponseHours.toFixed(1)}h average response`,
          })),
        );
        setCampaignPerformance(
          campaignResponse.items.map((row) => ({
            label: row.campaign,
            value: `${row.delivered} delivered`,
            secondary: `${row.opened} opened`,
          })),
        );
        setErrorMessage(null);
      })
      .catch((error) =>
        setErrorMessage(
          error instanceof Error ? error.message : 'Unable to load reports.',
        ),
      );
  }, []);

  return (
    <DashboardShell title="Reports">
      <div style={{ display: 'grid', gap: 18 }}>
        {errorMessage ? (
          <div style={{ ...panelStyle, background: '#FEF2F2', color: '#B91C1C' }}>
            {errorMessage}
          </div>
        ) : null}

        <section style={panelStyle}>
          <h3 style={{ marginTop: 0 }}>Funnel</h3>
          <p style={mutedTextStyle}>
            Live pipeline view from lead capture to paid service conversion.
          </p>
          <div
            style={{
              display: 'grid',
              gap: 12,
              gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))',
            }}
          >
            {funnel.map((row) => (
              <div key={row.label} style={{ borderTop: '1px solid #E2E8F0', paddingTop: 12 }}>
                <strong>{row.label}</strong>
                <p style={{ marginBottom: 0, fontSize: 26 }}>{row.value}</p>
              </div>
            ))}
          </div>
        </section>

        <ReportSection
          title="Counselor performance"
          rows={counselorPerformance}
        />
        <ReportSection
          title="Notification campaigns"
          rows={campaignPerformance}
        />
      </div>
    </DashboardShell>
  );
}
