'use client';

import { useEffect, useState } from 'react';

import { DashboardShell } from '../components/dashboard-shell';
import { apiFetch } from '../lib/api-client';
import { mutedTextStyle, panelStyle } from '../lib/ui';

interface OverviewMetrics {
  activeCases: number;
  awaitingDocuments: number;
  submittedThisWeek: number;
  premiumConversions: number;
  counselorResponseSlaHours: number;
}

export default function OverviewPage() {
  const [overview, setOverview] = useState<OverviewMetrics | null>(null);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  useEffect(() => {
    void apiFetch<OverviewMetrics>('/admin/reports/overview')
      .then((response) => {
        setOverview(response);
        setErrorMessage(null);
      })
      .catch((error) =>
        setErrorMessage(
          error instanceof Error ? error.message : 'Unable to load overview.',
        ),
      );
  }, []);

  return (
    <DashboardShell title="Overview">
      <div style={{ display: 'grid', gap: 18 }}>
        {errorMessage ? (
          <div style={{ ...panelStyle, background: '#FEF2F2', color: '#B91C1C' }}>
            {errorMessage}
          </div>
        ) : null}
        <div
          style={{
            display: 'grid',
            gap: 16,
            gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))',
          }}
        >
          {[
            ['Active cases', String(overview?.activeCases ?? '...')],
            ['Awaiting docs', String(overview?.awaitingDocuments ?? '...')],
          [
              'Submitted this week',
              String(overview?.submittedThisWeek ?? '...'),
            ],
            [
              'Premium conversions',
              String(overview?.premiumConversions ?? '...'),
            ],
            [
              'Counselor response SLA',
              overview
                ? `${overview.counselorResponseSlaHours.toFixed(1)}h`
                : '...',
            ],
          ].map(([label, value]) => (
            <div key={label} style={panelStyle}>
              <p style={{ margin: 0, color: '#64748b' }}>{label}</p>
              <h3 style={{ marginBottom: 0, fontSize: 28 }}>{value}</h3>
            </div>
          ))}
        </div>
        <div
          style={{
            display: 'grid',
            gap: 16,
            gridTemplateColumns: '1.2fr 1fr',
          }}
        >
          <div style={panelStyle}>
            <h3 style={{ marginTop: 0 }}>Operational focus this week</h3>
            <ul style={{ marginBottom: 0, lineHeight: 1.8 }}>
              <li>Unify all serious student requests under My Cases.</li>
              <li>Launch support offers and destination coverage by market.</li>
              <li>Segment reminder campaigns for missing documents.</li>
              <li>Track counselor response times and conversion to premium support.</li>
            </ul>
          </div>
          <div style={panelStyle}>
            <h3 style={{ marginTop: 0 }}>Team permissions</h3>
            <p style={mutedTextStyle}>
              Admins manage platform operations, counselors move cases forward,
              commercials own follow-up, and content/moderation roles keep the
              student-facing surfaces fresh and safe.
            </p>
          </div>
        </div>
      </div>
    </DashboardShell>
  );
}
