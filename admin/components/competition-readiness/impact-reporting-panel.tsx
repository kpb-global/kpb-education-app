'use client';

import { useTranslations } from 'next-intl';
import { useEffect, useState } from 'react';

import {
  createImpactDataRoomExport,
  freezeImpactSnapshot,
  getCompetitionReadinessReport,
  listImpactDataRoomExports,
  listImpactPilots,
  listImpactSnapshots,
  type CompetitionReadinessReport,
  type CreateImpactDataRoomExportInput,
  type ImpactDataRoomExportReceipt,
  type ImpactDataRoomFormat,
  type ImpactPilotItem,
  type ImpactSnapshotResponse,
} from '../../lib/competition-readiness-api';
import {
  AdminCapability,
  hasAdminCapability,
} from '../../lib/admin-capabilities';
import { useLocale } from '../locale-provider';
import {
  AdminTable,
  AdminTableRow,
  Alert,
  Badge,
  Button,
  CellText,
  ConfirmDialog,
  EmptyState,
  Field,
  Input,
  Select,
  Skeleton,
} from '../ui';
import { EndpointUnavailableState } from './endpoint-state';
import { makeIdempotencyKey, toUtcIso } from './impact-admin-utils';
import {
  formatDateTime,
  getApiErrorStatus,
  isEndpointUnavailable,
} from './readiness-utils';
import styles from './readiness.module.css';

type SnapshotForm = {
  periodStart: string;
  periodEnd: string;
  sourceWatermark: string;
};

type ExportForm = {
  snapshotId: string;
  purposeCode: string;
  format: ImpactDataRoomFormat;
  expiresAt: string;
};

const EMPTY_SNAPSHOT_FORM: SnapshotForm = {
  periodStart: '',
  periodEnd: '',
  sourceWatermark: '',
};

const EMPTY_EXPORT_FORM: ExportForm = {
  snapshotId: '',
  purposeCode: 'competition_due_diligence',
  format: 'json',
  expiresAt: '',
};

export function ImpactReportingPanel({ role }: Readonly<{ role: string | undefined }>) {
  const t = useTranslations('competitionReadiness');
  const { locale } = useLocale();
  const canView = hasAdminCapability(role, AdminCapability.ViewPilotAggregates);
  const canFreeze = hasAdminCapability(role, AdminCapability.FreezeImpactSnapshots);
  const [pilots, setPilots] = useState<ImpactPilotItem[]>([]);
  const [pilotId, setPilotId] = useState('');
  const [publicSafeOnly, setPublicSafeOnly] = useState(true);
  const [report, setReport] = useState<CompetitionReadinessReport | null>(null);
  const [snapshots, setSnapshots] = useState<ImpactSnapshotResponse[]>([]);
  const [dataRoomExports, setDataRoomExports] = useState<ImpactDataRoomExportReceipt[]>([]);
  const [loadingPilots, setLoadingPilots] = useState(true);
  const [loadingReport, setLoadingReport] = useState(false);
  const [loadingSnapshots, setLoadingSnapshots] = useState(false);
  const [loadingExports, setLoadingExports] = useState(false);
  const [pilotError, setPilotError] = useState<unknown>(null);
  const [reportError, setReportError] = useState<unknown>(null);
  const [snapshotError, setSnapshotError] = useState<unknown>(null);
  const [exportError, setExportError] = useState<unknown>(null);
  const [reloadToken, setReloadToken] = useState(0);
  const [snapshotForm, setSnapshotForm] = useState<SnapshotForm>(EMPTY_SNAPSHOT_FORM);
  const [exportForm, setExportForm] = useState<ExportForm>(EMPTY_EXPORT_FORM);
  const [formError, setFormError] = useState<string | null>(null);
  const [pendingSnapshot, setPendingSnapshot] = useState<{
    expectedVersion: number;
    periodStart: string;
    periodEnd: string;
    sourceWatermark: string;
    reasonCode: string;
  } | null>(null);
  const [pendingExport, setPendingExport] = useState<CreateImpactDataRoomExportInput | null>(null);
  const [exportReceipt, setExportReceipt] = useState<ImpactDataRoomExportReceipt | null>(null);
  const [mutating, setMutating] = useState(false);
  const [mutationNotice, setMutationNotice] = useState<{
    variant: 'success' | 'danger' | 'warning';
    message: string;
  } | null>(null);
  const selectedPilot = pilots.find((pilot) => pilot.id === pilotId) ?? null;

  useEffect(() => {
    if (!canView) {
      setLoadingPilots(false);
      return;
    }
    let cancelled = false;
    setLoadingPilots(true);
    setPilotError(null);
    void listImpactPilots({ limit: 100 })
      .then((response) => {
        if (cancelled) return;
        setPilots(response.items);
        setPilotId((current) => current || response.items[0]?.id || '');
      })
      .catch((nextError: unknown) => {
        if (!cancelled) {
          setPilots([]);
          setPilotError(nextError);
        }
      })
      .finally(() => {
        if (!cancelled) setLoadingPilots(false);
      });
    return () => {
      cancelled = true;
    };
  }, [canView, reloadToken]);

  useEffect(() => {
    if (!canView || !pilotId) {
      setReport(null);
      setSnapshots([]);
      setDataRoomExports([]);
      return;
    }
    let cancelled = false;
    setLoadingReport(true);
    setLoadingSnapshots(true);
    setLoadingExports(true);
    setReportError(null);
    setSnapshotError(null);
    setExportError(null);

    void getCompetitionReadinessReport({ pilotId, publicSafeOnly })
      .then((response) => {
        if (!cancelled) setReport(response);
      })
      .catch((nextError: unknown) => {
        if (!cancelled) {
          setReport(null);
          setReportError(nextError);
        }
      })
      .finally(() => {
        if (!cancelled) setLoadingReport(false);
      });

    void listImpactSnapshots(pilotId, { limit: 100, publicSafeOnly })
      .then((response) => {
        if (!cancelled) {
          setSnapshots(response.items);
          setExportForm((current) => ({
            ...current,
            snapshotId: response.items.some((item) => item.id === current.snapshotId)
              ? current.snapshotId
              : response.items[0]?.id ?? '',
          }));
        }
      })
      .catch((nextError: unknown) => {
        if (!cancelled) {
          setSnapshots([]);
          setSnapshotError(nextError);
        }
      })
      .finally(() => {
        if (!cancelled) setLoadingSnapshots(false);
      });

    void listImpactDataRoomExports({ pilotId })
      .then((response) => {
        if (!cancelled) setDataRoomExports(response.items);
      })
      .catch((nextError: unknown) => {
        if (!cancelled) {
          setDataRoomExports([]);
          setExportError(nextError);
        }
      })
      .finally(() => {
        if (!cancelled) setLoadingExports(false);
      });

    return () => {
      cancelled = true;
    };
  }, [canView, pilotId, publicSafeOnly, reloadToken]);

  function refresh() {
    setReloadToken((value) => value + 1);
  }

  function prepareSnapshot() {
    if (!selectedPilot) return;
    const periodStart = toUtcIso(snapshotForm.periodStart);
    const periodEnd = toUtcIso(snapshotForm.periodEnd);
    const sourceWatermark = toUtcIso(snapshotForm.sourceWatermark);
    if (
      !periodStart ||
      !periodEnd ||
      !sourceWatermark ||
      Date.parse(periodEnd) <= Date.parse(periodStart) ||
      Date.parse(sourceWatermark) < Date.parse(periodEnd) ||
      Date.parse(sourceWatermark) > Date.now()
    ) {
      setFormError(t('snapshotFormValidationError'));
      return;
    }
    setFormError(null);
    setPendingSnapshot({
      expectedVersion: selectedPilot.version,
      periodStart,
      periodEnd,
      sourceWatermark,
      reasonCode: 'impact_snapshot_frozen',
    });
  }

  function prepareExport() {
    const expiresAt = exportForm.expiresAt ? toUtcIso(exportForm.expiresAt) : undefined;
    if (
      !exportForm.snapshotId ||
      !/^[a-z0-9][a-z0-9_.-]{0,79}$/.test(exportForm.purposeCode.trim()) ||
      (exportForm.expiresAt && !expiresAt) ||
      (expiresAt && Date.parse(expiresAt) <= Date.now())
    ) {
      setFormError(t('dataRoomFormValidationError'));
      return;
    }
    setFormError(null);
    setPendingExport({
      snapshotId: exportForm.snapshotId,
      purposeCode: exportForm.purposeCode.trim(),
      format: exportForm.format,
      expiresAt: expiresAt ?? undefined,
      reasonCode: 'impact_data_room_export_created',
    });
  }

  async function performSnapshot() {
    if (!pilotId || !pendingSnapshot) return;
    setMutating(true);
    setMutationNotice(null);
    try {
      await freezeImpactSnapshot(
        pilotId,
        pendingSnapshot,
        makeIdempotencyKey('impact-snapshot'),
      );
      setPendingSnapshot(null);
      setSnapshotForm(EMPTY_SNAPSHOT_FORM);
      setMutationNotice({ variant: 'success', message: t('snapshotFrozen') });
      refresh();
    } catch (nextError: unknown) {
      setPendingSnapshot(null);
      setMutationNotice(errorNotice(nextError, t));
      if (getApiErrorStatus(nextError) === 409) refresh();
    } finally {
      setMutating(false);
    }
  }

  async function performExport() {
    if (!pendingExport) return;
    setMutating(true);
    setMutationNotice(null);
    try {
      const receipt = await createImpactDataRoomExport(
        pendingExport,
        makeIdempotencyKey('impact-data-room'),
      );
      setPendingExport(null);
      setExportReceipt(receipt);
      setMutationNotice({ variant: 'success', message: t('dataRoomExportCreated') });
      refresh();
    } catch (nextError: unknown) {
      setPendingExport(null);
      setMutationNotice(errorNotice(nextError, t));
    } finally {
      setMutating(false);
    }
  }

  if (!canView) return <Alert variant="warning">{t('impactCapabilityRequired')}</Alert>;
  if (pilotError && isEndpointUnavailable(pilotError)) {
    return <EndpointUnavailableState endpoint="GET /api/admin/competition-readiness/pilots" onRetry={refresh} />;
  }

  return <div className={styles.stack}>
    <Alert variant="info">{t('impactVerifiedOnlyNote')}</Alert>
    <div className={styles.filters}>
      <Field label={t('pilotFilterLabel')}>{({ id, invalid }) => <Select id={id} invalid={invalid} value={pilotId} disabled={loadingPilots} onChange={(event) => { setPilotId(event.target.value); setExportReceipt(null); }}><option value="">{t('selectPilotOption')}</option>{pilots.map((pilot) => <option key={pilot.id} value={pilot.id}>{pilot.name} ({pilot.code})</option>)}</Select>}</Field>
      <label className={styles.checkbox}><input type="checkbox" checked={publicSafeOnly} disabled={!canFreeze} onChange={(event) => setPublicSafeOnly(event.target.checked)} />{t('publicSafeOnly')}</label>
      <span />
      <Button variant="secondary" onClick={refresh}>{t('refresh')}</Button>
    </div>
    {pilotError ? <Alert variant="danger">{t('pilotsLoadError')}</Alert> : null}
    {mutationNotice ? <Alert variant={mutationNotice.variant}>{mutationNotice.message}</Alert> : null}
    {!pilotId && !loadingPilots ? <EmptyState title={t('impactNoPilotTitle')} description={t('impactNoPilotDescription')} /> : null}

    {pilotId ? <>
      <div className={styles.metrics}>{loadingReport ? Array.from({ length: 4 }, (_, index) => <div key={index} className={styles.metric}><Skeleton height={18} /><Skeleton height={30} /></div>) : report?.metrics.slice(0, 4).map((metric) => <article key={`${metric.metricKey}:${metric.metricVersion}`} className={styles.metric}><span className={styles.detailLabel}>{metric.label}</span><p className={styles.metricValue}>{formatMetricValue(metric.value, locale)}</p><p className={styles.panelSubtitle}>{t('metricCoverage', { coverage: metric.coveragePercent ?? 0, sample: metric.sampleSize ?? 0 })}</p></article>)}</div>
      {reportError ? <Alert variant={isEndpointUnavailable(reportError) ? 'warning' : 'danger'}>{isEndpointUnavailable(reportError) ? t('reportsEndpointUnavailable') : t('reportsLoadError')}</Alert> : null}
      <AdminTable title={t('impactMetricsTitle')} columns={[t('colMetric'), t('colValue'), t('colNumerator'), t('colDenominator'), t('colCaveat')]} cols="1.4fr .7fr .7fr .7fr 1.4fr" footnote={report ? t('reportWatermark', { date: formatDateTime(report.sourceWatermark, locale) }) : undefined}>
        {loadingReport ? Array.from({ length: 4 }, (_, index) => <AdminTableRow key={index}>{Array.from({ length: 5 }, (__, cellIndex) => <Skeleton key={cellIndex} height={18} />)}</AdminTableRow>) : report?.metrics.length ? report.metrics.map((metric) => <AdminTableRow key={`${metric.metricKey}:${metric.metricVersion}`}><CellText primary={metric.label} sub={`${metric.metricKey} · v${metric.metricVersion}`} /><CellText primary={formatMetricValue(metric.value, locale)} /><CellText primary={metric.numerator ?? '—'} muted /><CellText primary={metric.denominator ?? '—'} muted /><CellText primary={metric.caveat || '—'} muted /></AdminTableRow>) : <EmptyState title={t('impactMetricsEmptyTitle')} description={t('impactMetricsEmptyDescription')} />}
      </AdminTable>

      <section className={styles.panel}>
        <div><h3 className={styles.panelTitle}>{t('snapshotsTitle')}</h3><p className={styles.panelSubtitle}>{t('snapshotsImmutableNote')}</p></div>
        {snapshotError ? <Alert variant={isEndpointUnavailable(snapshotError) ? 'warning' : 'danger'}>{isEndpointUnavailable(snapshotError) ? t('snapshotsEndpointUnavailable') : t('snapshotsLoadError')}</Alert> : null}
        {loadingSnapshots ? <Skeleton height={100} /> : snapshots.length ? <div className={styles.snapshotList}>{snapshots.map((snapshot) => <article key={snapshot.id} className={styles.snapshotItem}><div><strong>{t('snapshotVersion', { version: snapshot.snapshotVersion })}</strong><span>{formatDateTime(snapshot.periodStart, locale)} — {formatDateTime(snapshot.periodEnd, locale)}</span></div><Badge variant={snapshot.isPublicSafe ? 'success' : 'warning'}>{snapshot.isPublicSafe ? t('publicSafe') : t('restrictedAggregate')}</Badge></article>)}</div> : <EmptyState title={t('snapshotsEmptyTitle')} description={t('snapshotsEmptyDescription')} />}

        {canFreeze ? <div className={styles.mutationBox}><h4 className={styles.sectionTitle}>{t('freezeSnapshotTitle')}</h4><div className={styles.formGrid}><DateField label={t('periodStartUtcLabel')} value={snapshotForm.periodStart} onChange={(value) => setSnapshotForm((current) => ({ ...current, periodStart: value }))} /><DateField label={t('periodEndUtcLabel')} value={snapshotForm.periodEnd} onChange={(value) => setSnapshotForm((current) => ({ ...current, periodEnd: value }))} /><DateField label={t('sourceWatermarkUtcLabel')} value={snapshotForm.sourceWatermark} onChange={(value) => setSnapshotForm((current) => ({ ...current, sourceWatermark: value }))} /></div><div className={styles.actions}><Button onClick={prepareSnapshot}>{t('reviewSnapshotFreeze')}</Button></div></div> : null}
      </section>

      <section className={styles.panel}>
        <div><h3 className={styles.panelTitle}>{t('dataRoomTitle')}</h3><p className={styles.panelSubtitle}>{t('dataRoomPrivacyNote')}</p></div>
        {exportError ? <Alert variant={isEndpointUnavailable(exportError) ? 'warning' : 'danger'}>{isEndpointUnavailable(exportError) ? t('dataRoomEndpointUnavailable') : t('dataRoomLoadError')}</Alert> : null}
        {loadingExports ? <Skeleton height={90} /> : dataRoomExports.length ? <div className={styles.snapshotList}>{dataRoomExports.map((item) => <article key={item.id} className={styles.snapshotItem}><div><strong>{item.format.toUpperCase()} · {item.purposeCode}</strong><span>{t('dataRoomCreatedAt', { date: formatDateTime(item.createdAt, locale) })}</span></div><Badge variant={item.expiresAt && Date.parse(item.expiresAt) <= Date.now() ? 'neutral' : 'success'}>{item.expiresAt ? t('dataRoomExpiresAt', { date: formatDateTime(item.expiresAt, locale) }) : t('dataRoomNoExpiry')}</Badge></article>)}</div> : <EmptyState title={t('dataRoomEmptyTitle')} description={t('dataRoomEmptyDescription')} />}
        {canFreeze ? <>
        {formError ? <Alert variant="danger">{formError}</Alert> : null}
        <div className={styles.formGrid}>
          <Field label={t('snapshotLabel')}>{({ id, invalid }) => <Select id={id} invalid={invalid} value={exportForm.snapshotId} onChange={(event) => setExportForm((current) => ({ ...current, snapshotId: event.target.value }))}><option value="">{t('selectSnapshotOption')}</option>{snapshots.map((snapshot) => <option key={snapshot.id} value={snapshot.id}>{t('snapshotVersion', { version: snapshot.snapshotVersion })} · {formatDateTime(snapshot.periodEnd, locale)}</option>)}</Select>}</Field>
          <Field label={t('dataRoomFormatLabel')}>{({ id, invalid }) => <Select id={id} invalid={invalid} value={exportForm.format} onChange={(event) => setExportForm((current) => ({ ...current, format: event.target.value as ImpactDataRoomFormat }))}><option value="json">JSON</option><option value="csv">CSV</option><option value="zip">ZIP</option></Select>}</Field>
          <TextField label={t('purposeCodeLabel')} value={exportForm.purposeCode} onChange={(value) => setExportForm((current) => ({ ...current, purposeCode: value }))} />
          <DateField label={t('expiresAtUtcLabel')} value={exportForm.expiresAt} onChange={(value) => setExportForm((current) => ({ ...current, expiresAt: value }))} />
        </div>
        <div className={styles.actions}><Button disabled={snapshots.length === 0} onClick={prepareExport}>{t('reviewDataRoomExport')}</Button></div>
        {exportReceipt ? <Alert variant="success"><div className={styles.receipt}><strong>{t('dataRoomReceiptTitle')}</strong><span>{t('dataRoomReceiptDescription', { format: exportReceipt.format.toUpperCase(), date: formatDateTime(exportReceipt.expiresAt, locale) })}</span><code>{t('dataRoomReceiptHash', { hash: exportReceipt.sha256 })}</code></div></Alert> : null}
        </> : <Alert variant="info">{t('dataRoomReadOnlyNote')}</Alert>}
      </section>
    </> : null}

    <ConfirmDialog open={pendingSnapshot !== null} title={t('freezeSnapshotConfirmTitle')} description={t('freezeSnapshotConfirmDescription')} confirmLabel={t('confirmSnapshotFreeze')} cancelLabel={t('cancel')} loading={mutating} onCancel={() => setPendingSnapshot(null)} onConfirm={() => void performSnapshot()} />
    <ConfirmDialog open={pendingExport !== null} title={t('dataRoomExportConfirmTitle')} description={t('dataRoomExportConfirmDescription')} confirmLabel={t('confirmDataRoomExport')} cancelLabel={t('cancel')} loading={mutating} onCancel={() => setPendingExport(null)} onConfirm={() => void performExport()} />
  </div>;
}

function DateField({ label, value, onChange }: Readonly<{ label: string; value: string; onChange: (value: string) => void }>) { return <Field label={label}>{({ id, invalid }) => <Input id={id} invalid={invalid} type="datetime-local" value={value} onChange={(event) => onChange(event.target.value)} />}</Field>; }
function TextField({ label, value, onChange }: Readonly<{ label: string; value: string; onChange: (value: string) => void }>) { return <Field label={label}>{({ id, invalid }) => <Input id={id} invalid={invalid} value={value} onChange={(event) => onChange(event.target.value)} />}</Field>; }

function formatMetricValue(value: number | null, locale: 'fr' | 'en'): string {
  if (value === null || !Number.isFinite(value)) return '—';
  return new Intl.NumberFormat(locale === 'fr' ? 'fr-FR' : 'en-GB', { maximumFractionDigits: 2 }).format(value);
}

function errorNotice(error: unknown, t: ReturnType<typeof useTranslations<'competitionReadiness'>>): { variant: 'danger' | 'warning'; message: string } {
  const status = getApiErrorStatus(error);
  if (status === 409) return { variant: 'warning', message: t('actionConflict') };
  if (status === 403) return { variant: 'danger', message: t('actionForbidden') };
  if (isEndpointUnavailable(error)) return { variant: 'warning', message: t('actionEndpointUnavailable') };
  return { variant: 'danger', message: t('actionFailed') };
}
