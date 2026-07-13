'use client';

import { CSSProperties, useEffect, useState } from 'react';

import { useAdminAuth } from '../../components/admin-auth-provider';
import { DashboardShell } from '../../components/dashboard-shell';
import { useLocale } from '../../components/locale-provider';
import { apiFetch } from '../../lib/api-client';
import {
  AdminTable,
  AdminTableRow,
  Alert,
  Badge,
  CellText,
  EmptyState,
} from '../../components/ui';

interface FunnelRow {
  key: string;
  value: number;
}

interface CounselorPerformanceRow {
  counselor: string;
  activeCases: number;
  avgResponseHours: number | null;
}

interface CampaignPerformanceRow {
  campaign: string;
  sent: number;
  delivered: number;
}

interface RevenueSkuRow {
  sku: string;
  packageName: string;
  category: string;
  purchasesCount: number;
  paidCount: number;
  pendingCount: number;
  recognizedRevenueXOF: number;
  pendingPipelineXOF: number;
}

interface RevenueDestinationRow {
  destinationId: string;
  purchasesCount: number;
  paidCount: number;
  pendingCount: number;
  recognizedRevenueXOF: number;
  pendingPipelineXOF: number;
}

interface ServiceRevenueResponse {
  bySku: RevenueSkuRow[];
  byDestination: RevenueDestinationRow[];
}

function formatFcfa(value: number) {
  return `${new Intl.NumberFormat('fr-FR').format(value)} FCFA`;
}

const cardStyle: CSSProperties = {
  background: 'var(--surface)',
  border: '1px solid var(--border)',
  borderRadius: 16,
  padding: 16,
};

const sectionTitleStyle: CSSProperties = {
  margin: 0,
  fontSize: 'var(--text-base)',
  fontWeight: 800,
  color: 'var(--ink)',
};

const sectionSubtitleStyle: CSSProperties = {
  margin: '4px 0 0',
  fontSize: 'var(--text-xs)',
  color: 'var(--text-muted)',
};

export default function ReportsPage() {
  const { session } = useAdminAuth();
  const { t } = useLocale();
  const [funnel, setFunnel] = useState<FunnelRow[]>([]);
  const [counselorPerformance, setCounselorPerformance] = useState<
    CounselorPerformanceRow[]
  >([]);
  const [campaignPerformance, setCampaignPerformance] = useState<
    CampaignPerformanceRow[]
  >([]);
  const [serviceRevenue, setServiceRevenue] = useState<ServiceRevenueResponse>({
    bySku: [],
    byDestination: [],
  });
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
      apiFetch<ServiceRevenueResponse>('/admin/reports/service-revenue'),
    ])
      .then(
        ([
          funnelResponse,
          counselorResponse,
          campaignResponse,
          serviceRevenueResponse,
        ]) => {
          setFunnel(funnelResponse.items);
          setCounselorPerformance(counselorResponse.items);
          setCampaignPerformance(campaignResponse.items);
          setServiceRevenue(serviceRevenueResponse);
          setErrorMessage(null);
        },
      )
      .catch((error) =>
        setErrorMessage(
          error instanceof Error ? error.message : t('reports.loadError'),
        ),
      );
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [session]);

  return (
    <DashboardShell title={t('reports.title')} subtitle={t('reports.subtitle')}>
      <div style={{ display: 'grid', gap: 14 }}>
        {errorMessage ? <Alert variant="danger">{errorMessage}</Alert> : null}

        <section style={cardStyle} aria-label={t('reports.funnelTitle')}>
          <h3 style={sectionTitleStyle}>{t('reports.funnelTitle')}</h3>
          <p style={sectionSubtitleStyle}>{t('reports.funnelSubtitle')}</p>
          <div
            style={{
              display: 'grid',
              gap: 10,
              marginTop: 14,
              gridTemplateColumns: 'repeat(auto-fit, minmax(160px, 1fr))',
            }}
          >
            {funnel.map((row) => (
              <div
                key={row.key}
                style={{
                  background: 'var(--bg)',
                  border: '1px solid var(--border-soft)',
                  borderRadius: 12,
                  padding: '11px 12px',
                }}
              >
                <p
                  style={{
                    margin: 0,
                    fontSize: 9.5,
                    fontWeight: 800,
                    letterSpacing: '0.06em',
                    textTransform: 'uppercase',
                    color: 'var(--text-faint)',
                  }}
                >
                  {t(`reports.funnelStage_${row.key}`)}
                </p>
                <p
                  style={{
                    margin: '6px 0 0',
                    fontSize: 24,
                    fontWeight: 800,
                    letterSpacing: '-0.5px',
                    color: 'var(--ink)',
                    fontFamily: 'var(--font-jakarta, inherit)',
                  }}
                >
                  {row.value}
                </p>
              </div>
            ))}
          </div>
        </section>

        <AdminTable
          title={t('reports.counselorTitle')}
          columns={[
            t('reports.colCounselor'),
            t('reports.colActiveCases'),
            t('reports.colAvgResponse'),
          ]}
          cols="1.6fr 1fr 1fr"
        >
          {counselorPerformance.length === 0 ? (
            <EmptyState title={t('reports.empty')} />
          ) : (
            counselorPerformance.map((row) => (
              <AdminTableRow key={row.counselor}>
                <CellText primary={row.counselor} />
                <CellText
                  primary={row.activeCases}
                  sub={t('reports.activeCasesValue')}
                />
                <CellText
                  primary={
                    row.avgResponseHours === null
                      ? '—'
                      : `${row.avgResponseHours.toFixed(1)}h`
                  }
                  sub={t('reports.avgResponseValue')}
                />
              </AdminTableRow>
            ))
          )}
        </AdminTable>

        <AdminTable
          title={t('reports.campaignTitle')}
          columns={[
            t('reports.colCampaign'),
            t('reports.colSent'),
            t('reports.colDelivered'),
          ]}
          cols="1.6fr 1fr 1fr"
        >
          {campaignPerformance.length === 0 ? (
            <EmptyState title={t('reports.empty')} />
          ) : (
            campaignPerformance.map((row) => (
              <AdminTableRow key={row.campaign}>
                <CellText primary={row.campaign} />
                <CellText primary={row.sent} muted />
                <CellText primary={row.delivered} muted />
              </AdminTableRow>
            ))
          )}
        </AdminTable>

        <section style={cardStyle} aria-label={t('reports.revenueTitle')}>
          <h3 style={sectionTitleStyle}>{t('reports.revenueTitle')}</h3>
          <p style={sectionSubtitleStyle}>{t('reports.revenueSubtitle')}</p>
        </section>

        <AdminTable
          title={t('reports.bySkuTitle')}
          columns={[
            t('reports.colPackage'),
            t('reports.colCategory'),
            t('reports.colPaid'),
            t('reports.colRecognized'),
            t('reports.colPending'),
          ]}
          cols="1.5fr 0.9fr 0.8fr 1.1fr 1.1fr"
        >
          {serviceRevenue.bySku.length === 0 ? (
            <EmptyState title={t('reports.empty')} />
          ) : (
            serviceRevenue.bySku.map((row) => (
              <AdminTableRow key={row.sku}>
                <CellText primary={row.packageName} sub={row.sku} />
                <CellText primary={row.category} muted />
                <div>
                  <Badge
                    variant={
                      row.paidCount === row.purchasesCount ? 'success' : 'warning'
                    }
                  >
                    {row.paidCount} {t('reports.paidOf')} {row.purchasesCount}
                  </Badge>
                </div>
                <CellText primary={formatFcfa(row.recognizedRevenueXOF)} />
                <CellText primary={formatFcfa(row.pendingPipelineXOF)} muted />
              </AdminTableRow>
            ))
          )}
        </AdminTable>

        <AdminTable
          title={t('reports.byDestinationTitle')}
          columns={[
            t('reports.colDestination'),
            t('reports.colPaid'),
            t('reports.colRecognized'),
            t('reports.colPending'),
          ]}
          cols="1.4fr 0.9fr 1.1fr 1.1fr"
        >
          {serviceRevenue.byDestination.length === 0 ? (
            <EmptyState title={t('reports.empty')} />
          ) : (
            serviceRevenue.byDestination.map((row) => (
              <AdminTableRow key={row.destinationId}>
                <CellText primary={row.destinationId} />
                <div>
                  <Badge
                    variant={
                      row.paidCount === row.purchasesCount ? 'success' : 'warning'
                    }
                  >
                    {row.paidCount} {t('reports.paidOf')} {row.purchasesCount}
                  </Badge>
                </div>
                <CellText primary={formatFcfa(row.recognizedRevenueXOF)} />
                <CellText primary={formatFcfa(row.pendingPipelineXOF)} muted />
              </AdminTableRow>
            ))
          )}
        </AdminTable>
      </div>
    </DashboardShell>
  );
}
