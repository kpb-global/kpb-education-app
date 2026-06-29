'use client';

import { useEffect, useState } from 'react';

import { useAdminAuth } from '../../components/admin-auth-provider';
import { DashboardShell } from '../../components/dashboard-shell';
import { Alert, Badge, Card } from '../../components/ui';
import { apiFetch } from '../../lib/api-client';
import { mutedTextStyle } from '../../lib/ui';

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
    <Card>
      <h3 style={{ marginTop: 0 }}>{title}</h3>
      <div style={{ display: 'grid', gap: 'var(--space-3)' }}>
        {rows.map((row) => (
          <div
            key={`${title}-${row.label}`}
            style={{
              borderTop: '1px solid var(--border)',
              paddingTop: 'var(--space-3)',
              display: 'grid',
              gap: 'var(--space-2)',
            }}
          >
            <strong>{row.label}</strong>
            <p style={{ margin: 0 }}>{row.value}</p>
            <span>
              <Badge variant="neutral">{row.secondary}</Badge>
            </span>
          </div>
        ))}
      </div>
    </Card>
  );
}

export default function ReportsPage() {
  const { session } = useAdminAuth();
  const [funnel, setFunnel] = useState<FunnelRow[]>([]);
  const [counselorPerformance, setCounselorPerformance] = useState<
    PerformanceRow[]
  >([]);
  const [campaignPerformance, setCampaignPerformance] = useState<
    PerformanceRow[]
  >([]);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  useEffect(() => {
    if (!session) {
      return;
    }
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
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [session]);

  return (
    <DashboardShell title="Reports">
      <div style={{ display: 'grid', gap: 'var(--space-5)' }}>
        {errorMessage ? <Alert variant="danger">{errorMessage}</Alert> : null}

        <Card>
          <h3 style={{ marginTop: 0 }}>Funnel</h3>
          <p style={mutedTextStyle}>
            Live pipeline view from lead capture to paid service conversion.
          </p>
          <div
            style={{
              display: 'grid',
              gap: 'var(--space-3)',
              gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))',
            }}
          >
            {funnel.map((row) => (
              <div
                key={row.label}
                style={{
                  borderTop: '1px solid var(--border)',
                  paddingTop: 'var(--space-3)',
                }}
              >
                <strong>{row.label}</strong>
                <p style={{ marginBottom: 0, fontSize: 'var(--text-2xl)' }}>
                  {row.value}
                </p>
              </div>
            ))}
          </div>
        </Card>

        <ReportSection title="Counselor performance" rows={counselorPerformance} />
        <ReportSection title="Notification campaigns" rows={campaignPerformance} />
      </div>
    </DashboardShell>
  );
}
