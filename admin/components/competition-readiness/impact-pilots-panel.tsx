'use client';

import { useTranslations } from 'next-intl';
import { useEffect, useState } from 'react';

import {
  createImpactCohort,
  createImpactPilot,
  listImpactCohorts,
  listImpactPilots,
  updateImpactPilot,
  type CursorPage,
  type ImpactCohortDraft,
  type ImpactCohortItem,
  type ImpactPilotDraft,
  type ImpactPilotItem,
  type PilotStatus,
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
  Textarea,
} from '../ui';
import { EndpointUnavailableState } from './endpoint-state';
import {
  makeIdempotencyKey,
  parseCodeList,
  parseCountryCodes,
  parseJsonObject,
  pilotStatusVariant,
  toUtcIso,
} from './impact-admin-utils';
import {
  formatDateTime,
  getApiErrorStatus,
  isEndpointUnavailable,
} from './readiness-utils';
import styles from './readiness.module.css';

const PILOT_STATUSES: readonly PilotStatus[] = [
  'draft',
  'recruiting',
  'active',
  'analysis',
  'completed',
  'archived',
];

type PilotForm = {
  code: string;
  name: string;
  hypothesis: string;
  countryCodes: string;
  targetPopulation: string;
  primaryMetrics: string;
  guardrailMetrics: string;
  protocolVersion: string;
  partnerAgreementIds: string;
  recruitmentStartsAt: string;
  startsAt: string;
  endsAt: string;
};

const EMPTY_PILOT_FORM: PilotForm = {
  code: '',
  name: '',
  hypothesis: '',
  countryCodes: '',
  targetPopulation: '{"studyLevels":["secondary","bachelor","master"]}',
  primaryMetrics: '{"keys":["verified_submission_rate"]}',
  guardrailMetrics: '{"keys":["consent_coverage_percent"]}',
  protocolVersion: '1.0',
  partnerAgreementIds: '',
  recruitmentStartsAt: '',
  startsAt: '',
  endsAt: '',
};

type CohortForm = {
  code: string;
  label: string;
  cohortType: string;
  inclusionRules: string;
  exclusionRules: string;
};

const EMPTY_COHORT_FORM: CohortForm = {
  code: '',
  label: '',
  cohortType: 'pilot',
  inclusionRules: '{}',
  exclusionRules: '{}',
};

export function ImpactPilotsPanel({
  role,
  selectedPilotId,
  onSelectPilot,
}: Readonly<{
  role: string | undefined;
  selectedPilotId: string | null;
  onSelectPilot: (id: string | null) => void;
}>) {
  const t = useTranslations('competitionReadiness');
  const { locale } = useLocale();
  const canManage = hasAdminCapability(role, AdminCapability.ManagePilots);
  const canRecruit = hasAdminCapability(
    role,
    AdminCapability.RecruitPilotParticipants,
  );
  const canView = canManage || canRecruit;
  const [statusFilter, setStatusFilter] = useState<PilotStatus | ''>('');
  const [countryFilter, setCountryFilter] = useState('');
  const [page, setPage] = useState<CursorPage<ImpactPilotItem> | null>(null);
  const [cursorStack, setCursorStack] = useState<string[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<unknown>(null);
  const [reloadToken, setReloadToken] = useState(0);
  const [showCreate, setShowCreate] = useState(false);
  const [pilotForm, setPilotForm] = useState<PilotForm>(EMPTY_PILOT_FORM);
  const [cohortForm, setCohortForm] = useState<CohortForm>(EMPTY_COHORT_FORM);
  const [formError, setFormError] = useState<string | null>(null);
  const [cohortError, setCohortError] = useState<string | null>(null);
  const [pendingPilot, setPendingPilot] = useState<ImpactPilotDraft | null>(null);
  const [pendingCohort, setPendingCohort] = useState<ImpactCohortDraft | null>(null);
  const [pendingStatus, setPendingStatus] = useState<PilotStatus | null>(null);
  const [mutating, setMutating] = useState(false);
  const [mutationNotice, setMutationNotice] = useState<{
    variant: 'success' | 'danger' | 'warning';
    message: string;
  } | null>(null);
  const cursor = cursorStack.at(-1);
  const selected = page?.items.find((item) => item.id === selectedPilotId) ?? null;

  useEffect(() => {
    if (!canView) {
      setLoading(false);
      return;
    }
    let cancelled = false;
    setLoading(true);
    setError(null);
    void listImpactPilots({
      cursor,
      limit: 20,
      statuses: statusFilter ? [statusFilter] : undefined,
      countryCode: /^[A-Z]{2}$/.test(countryFilter) ? countryFilter : undefined,
    })
      .then((response) => {
        if (!cancelled) setPage(response);
      })
      .catch((nextError: unknown) => {
        if (!cancelled) {
          setPage(null);
          setError(nextError);
        }
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });
    return () => {
      cancelled = true;
    };
  }, [canView, countryFilter, cursor, reloadToken, statusFilter]);

  function refresh() {
    setReloadToken((value) => value + 1);
  }

  function updatePilotForm<K extends keyof PilotForm>(key: K, value: PilotForm[K]) {
    setPilotForm((current) => ({ ...current, [key]: value }));
  }

  function updateCohortForm<K extends keyof CohortForm>(key: K, value: CohortForm[K]) {
    setCohortForm((current) => ({ ...current, [key]: value }));
  }

  function preparePilotCreate() {
    const countries = parseCountryCodes(pilotForm.countryCodes);
    const targetPopulation = parseJsonObject(pilotForm.targetPopulation);
    const primaryMetrics = parseJsonObject(pilotForm.primaryMetrics);
    const guardrailMetrics = parseJsonObject(pilotForm.guardrailMetrics);
    const recruitmentStartsAt = pilotForm.recruitmentStartsAt ? toUtcIso(pilotForm.recruitmentStartsAt) : undefined;
    const startsAt = pilotForm.startsAt ? toUtcIso(pilotForm.startsAt) : undefined;
    const endsAt = pilotForm.endsAt ? toUtcIso(pilotForm.endsAt) : undefined;
    if (
      !/^[a-z0-9][a-z0-9_.-]{2,79}$/.test(pilotForm.code.trim()) ||
      !pilotForm.name.trim() ||
      !pilotForm.hypothesis.trim() ||
      !countries ||
      !targetPopulation ||
      !primaryMetrics ||
      !guardrailMetrics ||
      !/^[A-Za-z0-9][A-Za-z0-9_.-]{0,79}$/.test(pilotForm.protocolVersion.trim()) ||
      (pilotForm.recruitmentStartsAt && !recruitmentStartsAt) ||
      (pilotForm.startsAt && !startsAt) ||
      (pilotForm.endsAt && !endsAt) ||
      (startsAt && endsAt && Date.parse(endsAt) <= Date.parse(startsAt))
    ) {
      setFormError(t('impactFormValidationError'));
      return;
    }
    setFormError(null);
    setPendingPilot({
      code: pilotForm.code.trim(),
      name: pilotForm.name.trim(),
      hypothesis: pilotForm.hypothesis.trim(),
      countryCodes: countries,
      targetPopulation,
      primaryMetrics,
      guardrailMetrics,
      status: 'draft',
      recruitmentStartsAt: recruitmentStartsAt ?? null,
      startsAt: startsAt ?? null,
      endsAt: endsAt ?? null,
      protocolVersion: pilotForm.protocolVersion.trim(),
      partnerAgreementIds: parseCodeList(pilotForm.partnerAgreementIds),
      reasonCode: 'impact_pilot_created',
    });
  }

  function prepareCohortCreate() {
    if (!selected) return;
    const inclusionRules = parseJsonObject(cohortForm.inclusionRules);
    const exclusionRules = parseJsonObject(cohortForm.exclusionRules);
    if (
      !/^[a-z0-9][a-z0-9_.-]{1,79}$/.test(cohortForm.code.trim()) ||
      !cohortForm.label.trim() ||
      !/^[a-z0-9][a-z0-9_.-]{0,79}$/.test(cohortForm.cohortType.trim()) ||
      !inclusionRules ||
      !exclusionRules
    ) {
      setCohortError(t('impactFormValidationError'));
      return;
    }
    setCohortError(null);
    setPendingCohort({
      code: cohortForm.code.trim(),
      label: cohortForm.label.trim(),
      cohortType: cohortForm.cohortType.trim(),
      inclusionRules,
      exclusionRules,
      reasonCode: 'impact_cohort_created',
    });
  }

  async function performPilotCreate() {
    if (!pendingPilot) return;
    setMutating(true);
    setMutationNotice(null);
    try {
      const created = await createImpactPilot(
        pendingPilot,
        makeIdempotencyKey('impact-pilot'),
      );
      setPendingPilot(null);
      setPilotForm(EMPTY_PILOT_FORM);
      setShowCreate(false);
      setMutationNotice({ variant: 'success', message: t('pilotCreated') });
      setCursorStack([]);
      onSelectPilot(created.id);
      refresh();
    } catch (nextError: unknown) {
      setPendingPilot(null);
      setMutationNotice(errorNotice(nextError, t));
    } finally {
      setMutating(false);
    }
  }

  async function performCohortCreate() {
    if (!selected || !pendingCohort) return;
    setMutating(true);
    setMutationNotice(null);
    try {
      await createImpactCohort(
        selected.id,
        pendingCohort,
        makeIdempotencyKey('impact-cohort'),
      );
      setPendingCohort(null);
      setCohortForm(EMPTY_COHORT_FORM);
      setMutationNotice({ variant: 'success', message: t('cohortCreated') });
      refresh();
    } catch (nextError: unknown) {
      setPendingCohort(null);
      setMutationNotice(errorNotice(nextError, t));
    } finally {
      setMutating(false);
    }
  }

  async function performStatusUpdate() {
    if (!selected || !pendingStatus) return;
    setMutating(true);
    setMutationNotice(null);
    try {
      await updateImpactPilot(selected.id, {
        expectedVersion: selected.version,
        changes: { status: pendingStatus },
        reasonCode: `impact_pilot_${pendingStatus}`,
      }, makeIdempotencyKey('impact-pilot-update'));
      setPendingStatus(null);
      setMutationNotice({ variant: 'success', message: t('pilotUpdated') });
      refresh();
    } catch (nextError: unknown) {
      setPendingStatus(null);
      setMutationNotice(errorNotice(nextError, t));
      if (getApiErrorStatus(nextError) === 409) refresh();
    } finally {
      setMutating(false);
    }
  }

  if (!canView) return <Alert variant="warning">{t('pilotsCapabilityRequired')}</Alert>;
  if (error && isEndpointUnavailable(error)) {
    return <EndpointUnavailableState endpoint="GET /api/admin/competition-readiness/pilots" onRetry={refresh} />;
  }

  return (
    <div className={styles.stack}>
      <div className={styles.filters}>
        <Field label={t('filterStatus')}>{({ id, invalid }) => (
          <Select id={id} invalid={invalid} value={statusFilter} onChange={(event) => { setStatusFilter(event.target.value as PilotStatus | ''); setCursorStack([]); onSelectPilot(null); }}>
            <option value="">{t('allStatuses')}</option>
            {PILOT_STATUSES.map((status) => <option key={status} value={status}>{t(`pilotStatus_${status}`)}</option>)}
          </Select>
        )}</Field>
        <Field label={t('filterCountry')}>{({ id, invalid }) => <Input id={id} invalid={invalid} maxLength={2} value={countryFilter} placeholder="NE" onChange={(event) => { setCountryFilter(event.target.value.toUpperCase()); setCursorStack([]); }} />}</Field>
        <Button variant="secondary" onClick={refresh}>{t('refresh')}</Button>
        {canManage ? <Button onClick={() => setShowCreate((value) => !value)}>{showCreate ? t('closeCreationForm') : t('createPilot')}</Button> : <span />}
      </div>

      {mutationNotice ? <Alert variant={mutationNotice.variant}>{mutationNotice.message}</Alert> : null}
      {error ? <Alert variant="danger">{t('pilotsLoadError')}</Alert> : null}

      {showCreate && canManage ? (
        <section className={styles.panel}>
          <div><h3 className={styles.panelTitle}>{t('createPilotTitle')}</h3><p className={styles.panelSubtitle}>{t('createPilotDescription')}</p></div>
          {formError ? <Alert variant="danger">{formError}</Alert> : null}
          <div className={styles.formGrid}>
            <TextField label={t('pilotCodeLabel')} value={pilotForm.code} onChange={(value) => updatePilotForm('code', value)} />
            <TextField label={t('pilotNameLabel')} value={pilotForm.name} onChange={(value) => updatePilotForm('name', value)} />
            <TextField label={t('countryCodesLabel')} value={pilotForm.countryCodes} placeholder="NE, CI" onChange={(value) => updatePilotForm('countryCodes', value)} />
            <TextField label={t('protocolVersionLabel')} value={pilotForm.protocolVersion} onChange={(value) => updatePilotForm('protocolVersion', value)} />
            <TextField label={t('partnerAgreementIdsLabel')} value={pilotForm.partnerAgreementIds} onChange={(value) => updatePilotForm('partnerAgreementIds', value)} />
            <DateField label={t('recruitmentStartsAtUtcLabel')} value={pilotForm.recruitmentStartsAt} onChange={(value) => updatePilotForm('recruitmentStartsAt', value)} />
            <DateField label={t('startsAtUtcLabel')} value={pilotForm.startsAt} onChange={(value) => updatePilotForm('startsAt', value)} />
            <DateField label={t('endsAtUtcLabel')} value={pilotForm.endsAt} onChange={(value) => updatePilotForm('endsAt', value)} />
          </div>
          <Field label={t('hypothesisLabel')}>{({ id, invalid }) => <Textarea id={id} invalid={invalid} value={pilotForm.hypothesis} onChange={(event) => updatePilotForm('hypothesis', event.target.value)} />}</Field>
          <div className={styles.formGrid}>
            <JsonField label={t('targetPopulationLabel')} value={pilotForm.targetPopulation} onChange={(value) => updatePilotForm('targetPopulation', value)} />
            <JsonField label={t('primaryMetricsLabel')} value={pilotForm.primaryMetrics} onChange={(value) => updatePilotForm('primaryMetrics', value)} />
            <JsonField label={t('guardrailMetricsLabel')} value={pilotForm.guardrailMetrics} onChange={(value) => updatePilotForm('guardrailMetrics', value)} />
          </div>
          <Alert variant="info">{t('pilotAgreementRequirementNote')}</Alert>
          <div className={styles.actions}><Button onClick={preparePilotCreate}>{t('reviewAndCreate')}</Button></div>
        </section>
      ) : null}

      <div className={styles.splitLayout}>
        <div className={styles.stack}>
          <AdminTable title={t('pilotsTitle')} columns={[t('colPilot'), t('colStatus'), t('colCountries'), t('colParticipants'), t('colConsent')]} cols="1.4fr .8fr .8fr .8fr .8fr" footnote={t('pilotsTableNote')}>
            {loading ? Array.from({ length: 4 }, (_, index) => <AdminTableRow key={index}>{Array.from({ length: 5 }, (__, cellIndex) => <Skeleton key={cellIndex} height={18} />)}</AdminTableRow>) : page?.items.length ? page.items.map((item) => (
              <AdminTableRow key={item.id} selected={item.id === selectedPilotId} onSelect={() => onSelectPilot(item.id)}>
                <CellText primary={item.name} sub={`${item.code} · ${item.protocolVersion}`} />
                <Badge variant={pilotStatusVariant(item.status)}>{t(`pilotStatus_${item.status}`)}</Badge>
                <CellText primary={item.countryCodes.join(', ') || '—'} />
                <CellText primary={item.participantCount} muted />
                <CellText primary={`${item.consentCoveragePercent}%`} muted />
              </AdminTableRow>
            )) : <EmptyState title={t('pilotsEmptyTitle')} description={t('pilotsEmptyDescription')} />}
          </AdminTable>
          <div className={styles.pagination}><span className={styles.paginationText}>{t('pageNumber', { page: cursorStack.length + 1 })}</span><div className={styles.paginationActions}><Button variant="secondary" size="sm" disabled={loading || cursorStack.length === 0} onClick={() => setCursorStack((current) => current.slice(0, -1))}>{t('previous')}</Button><Button variant="secondary" size="sm" disabled={loading || !page?.nextCursor} onClick={() => { if (page?.nextCursor) setCursorStack((current) => [...current, page.nextCursor as string]); }}>{t('next')}</Button></div></div>
        </div>

        <aside className={`${styles.panel} ${styles.panelSticky}`}>
          {selected ? (
            <PilotDetail
              pilot={selected}
              locale={locale}
              canManage={canManage}
              cohortForm={cohortForm}
              cohortError={cohortError}
              reloadToken={reloadToken}
              onCohortFormChange={updateCohortForm}
              onPrepareCohort={prepareCohortCreate}
              onStatusChange={setPendingStatus}
            />
          ) : <EmptyState title={t('selectPilotTitle')} description={t('selectPilotDescription')} />}
        </aside>
      </div>

      <ConfirmDialog open={pendingPilot !== null} title={t('createPilotConfirmTitle')} description={t('createPilotConfirmDescription')} confirmLabel={t('confirmCreation')} cancelLabel={t('cancel')} loading={mutating} onCancel={() => setPendingPilot(null)} onConfirm={() => void performPilotCreate()} />
      <ConfirmDialog open={pendingCohort !== null} title={t('createCohortConfirmTitle')} description={t('createCohortConfirmDescription')} confirmLabel={t('confirmCreation')} cancelLabel={t('cancel')} loading={mutating} onCancel={() => setPendingCohort(null)} onConfirm={() => void performCohortCreate()} />
      <ConfirmDialog open={pendingStatus !== null} title={pendingStatus ? t(`pilotStatusConfirm_${pendingStatus}`) : ''} description={t('pilotStatusConfirmDescription')} confirmLabel={t('confirm')} cancelLabel={t('cancel')} loading={mutating} onCancel={() => setPendingStatus(null)} onConfirm={() => void performStatusUpdate()} />
    </div>
  );
}

function PilotDetail({ pilot, locale, canManage, cohortForm, cohortError, reloadToken, onCohortFormChange, onPrepareCohort, onStatusChange }: Readonly<{ pilot: ImpactPilotItem; locale: 'fr' | 'en'; canManage: boolean; cohortForm: CohortForm; cohortError: string | null; reloadToken: number; onCohortFormChange: <K extends keyof CohortForm>(key: K, value: CohortForm[K]) => void; onPrepareCohort: () => void; onStatusChange: (status: PilotStatus) => void }>) {
  const t = useTranslations('competitionReadiness');
  const [cohorts, setCohorts] = useState<ImpactCohortItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<unknown>(null);

  useEffect(() => {
    let cancelled = false;
    setLoading(true);
    setError(null);
    void listImpactCohorts(pilot.id, { limit: 100 })
      .then((response) => { if (!cancelled) setCohorts(response.items); })
      .catch((nextError: unknown) => { if (!cancelled) { setCohorts([]); setError(nextError); } })
      .finally(() => { if (!cancelled) setLoading(false); });
    return () => { cancelled = true; };
  }, [pilot.id, reloadToken]);

  return <>
    <div className={styles.panelHeader}><div><h3 className={styles.panelTitle}>{pilot.name}</h3><p className={styles.panelSubtitle}>{pilot.code} · {t('versionLabel')} {pilot.version}</p></div><Badge variant={pilotStatusVariant(pilot.status)}>{t(`pilotStatus_${pilot.status}`)}</Badge></div>
    <p className={styles.detailValue}>{pilot.hypothesis}</p>
    <div className={styles.detailGrid}><Detail label={t('protocolVersionLabel')} value={pilot.protocolVersion} /><Detail label={t('countryCodesLabel')} value={pilot.countryCodes.join(', ')} /><Detail label={t('startsAtLabel')} value={formatDateTime(pilot.startsAt, locale)} /><Detail label={t('endsAtLabel')} value={formatDateTime(pilot.endsAt, locale)} /></div>
    {canManage ? <div className={styles.actions}>{PILOT_STATUSES.filter((status) => status !== pilot.status).map((status) => <Button key={status} variant="secondary" size="sm" onClick={() => onStatusChange(status)}>{t(`setPilotStatus_${status}`)}</Button>)}</div> : null}
    <section className={styles.section}><div><h4 className={styles.sectionTitle}>{t('cohortsTitle')}</h4><p className={styles.panelSubtitle}>{t('cohortsPrivacyNote')}</p></div>
      {loading ? <Skeleton height={72} /> : error ? <Alert variant={isEndpointUnavailable(error) ? 'warning' : 'danger'}>{isEndpointUnavailable(error) ? t('cohortsEndpointUnavailable') : t('cohortsLoadError')}</Alert> : cohorts.length ? <ul className={styles.cohortList}>{cohorts.map((cohort) => <li key={cohort.id} className={styles.cohortItem}><div><strong>{cohort.label}</strong><span>{cohort.code} · {cohort.cohortType}</span></div><div className={styles.cohortMetrics}><Badge variant="info">{t('participantCount', { count: cohort.participantCount })}</Badge>{typeof cohort.consentCoveragePercent === 'number' ? <Badge variant={cohort.consentCoveragePercent === 100 ? 'success' : 'warning'}>{t('consentCoverage', { percent: cohort.consentCoveragePercent })}</Badge> : null}</div></li>)}</ul> : <EmptyState title={t('cohortsEmptyTitle')} description={t('cohortsEmptyDescription')} />}
    </section>
    {canManage ? <section className={styles.mutationBox}><h4 className={styles.sectionTitle}>{t('createCohortTitle')}</h4>{cohortError ? <Alert variant="danger">{cohortError}</Alert> : null}<div className={styles.formGrid}><TextField label={t('cohortCodeLabel')} value={cohortForm.code} onChange={(value) => onCohortFormChange('code', value)} /><TextField label={t('cohortLabelLabel')} value={cohortForm.label} onChange={(value) => onCohortFormChange('label', value)} /><TextField label={t('cohortTypeLabel')} value={cohortForm.cohortType} onChange={(value) => onCohortFormChange('cohortType', value)} /><JsonField label={t('inclusionRulesLabel')} value={cohortForm.inclusionRules} onChange={(value) => onCohortFormChange('inclusionRules', value)} /><JsonField label={t('exclusionRulesLabel')} value={cohortForm.exclusionRules} onChange={(value) => onCohortFormChange('exclusionRules', value)} /></div><div className={styles.actions}><Button size="sm" onClick={onPrepareCohort}>{t('reviewAndCreate')}</Button></div></section> : null}
  </>;
}

function TextField({ label, value, placeholder, onChange }: Readonly<{ label: string; value: string; placeholder?: string; onChange: (value: string) => void }>) { return <Field label={label}>{({ id, invalid }) => <Input id={id} invalid={invalid} value={value} placeholder={placeholder} onChange={(event) => onChange(event.target.value)} />}</Field>; }
function DateField({ label, value, onChange }: Readonly<{ label: string; value: string; onChange: (value: string) => void }>) { return <Field label={label}>{({ id, invalid }) => <Input id={id} invalid={invalid} type="datetime-local" value={value} onChange={(event) => onChange(event.target.value)} />}</Field>; }
function JsonField({ label, value, onChange }: Readonly<{ label: string; value: string; onChange: (value: string) => void }>) { return <Field label={label}>{({ id, invalid }) => <Textarea id={id} invalid={invalid} rows={4} spellCheck={false} value={value} onChange={(event) => onChange(event.target.value)} />}</Field>; }
function Detail({ label, value }: Readonly<{ label: string; value: string }>) { return <div className={styles.detailItem}><span className={styles.detailLabel}>{label}</span><p className={styles.detailValue}>{value || '—'}</p></div>; }

function errorNotice(error: unknown, t: ReturnType<typeof useTranslations<'competitionReadiness'>>): { variant: 'danger' | 'warning'; message: string } {
  const status = getApiErrorStatus(error);
  if (status === 409) return { variant: 'warning', message: t('actionConflict') };
  if (status === 403) return { variant: 'danger', message: t('actionForbidden') };
  if (isEndpointUnavailable(error)) return { variant: 'warning', message: t('actionEndpointUnavailable') };
  return { variant: 'danger', message: t('actionFailed') };
}
