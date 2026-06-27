'use client';

import { ReactNode, useEffect, useState } from 'react';

import { useAdminAuth } from '../components/admin-auth-provider';
import { DashboardShell } from '../components/dashboard-shell';
import { Alert, Card, Skeleton, StatCard } from '../components/ui';
import { apiFetch } from '../lib/api-client';
import { mutedTextStyle } from '../lib/ui';

interface OverviewMetrics {
  activeCases: number;
  awaitingDocuments: number;
  submittedThisWeek: number;
  premiumConversions: number;
  counselorResponseSlaHours: number;
}

export default function OverviewPage() {
  const { session } = useAdminAuth();
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
          error instanceof Error ? error.message : 'Unable to load overview.',
        );
      });
    return () => {
      cancelled = true;
    };
  }, [session]);

  const loadingValue = <Skeleton width={72} height={26} />;
  const stats: { label: string; value: ReactNode }[] = [
    {
      label: 'Active cases',
      value: overview ? String(overview.activeCases) : loadingValue,
    },
    {
      label: 'Awaiting docs',
      value: overview ? String(overview.awaitingDocuments) : loadingValue,
    },
    {
      label: 'Submitted this week',
      value: overview ? String(overview.submittedThisWeek) : loadingValue,
    },
    {
      label: 'Premium conversions',
      value: overview ? String(overview.premiumConversions) : loadingValue,
    },
    {
      label: 'Counselor response SLA',
      value: overview
        ? `${overview.counselorResponseSlaHours.toFixed(1)}h`
        : loadingValue,
    },
  ];

  return (
    <DashboardShell title="Overview">
      <div style={{ display: 'grid', gap: 'var(--space-5)' }}>
        {errorMessage ? <Alert variant="danger">{errorMessage}</Alert> : null}
        <div
          style={{
            display: 'grid',
            gap: 'var(--space-4)',
            gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))',
          }}
        >
          {stats.map((stat) => (
            <StatCard key={stat.label} label={stat.label} value={stat.value} />
          ))}
        </div>
        <div
          style={{
            display: 'grid',
            gap: 'var(--space-4)',
            gridTemplateColumns: '1.2fr 1fr',
          }}
        >
          <Card>
            <h3 style={{ marginTop: 0 }}>Operational focus this week</h3>
            <ul style={{ marginBottom: 0, lineHeight: 1.8 }}>
              <li>Unify all serious student requests under My Cases.</li>
              <li>Launch support offers and destination coverage by market.</li>
              <li>Segment reminder campaigns for missing documents.</li>
              <li>
                Track counselor response times and conversion to premium support.
              </li>
            </ul>
          </Card>
          <Card>
            <h3 style={{ marginTop: 0 }}>Team permissions</h3>
            <p style={mutedTextStyle}>
              Admins manage platform operations, counselors move cases forward,
              commercials own follow-up, and content/moderation roles keep the
              student-facing surfaces fresh and safe.
            </p>
          </Card>
        </div>
      </div>
    </DashboardShell>
  );
}
