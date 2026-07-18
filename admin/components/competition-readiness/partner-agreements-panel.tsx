'use client';

import { useTranslations } from 'next-intl';
import { useEffect, useState } from 'react';

import {
  createPartnerAgreement,
  listPartnerAgreements,
  updatePartnerAgreement,
  type CursorPage,
  type PartnerAgreementDraft,
  type PartnerAgreementItem,
  type PartnershipAgreementStatus,
  type PartnershipAgreementType,
  type UpdatePartnerAgreementInput,
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
import {
  agreementStatusVariant,
  makeIdempotencyKey,
  parseCodeList,
  parseCountryCodes,
  toUtcFormValue,
  toUtcIso,
} from './impact-admin-utils';
import {
  formatDateTime,
  getApiErrorStatus,
  isEndpointUnavailable,
} from './readiness-utils';
import styles from './readiness.module.css';

const AGREEMENT_STATUSES: readonly PartnershipAgreementStatus[] = [
  'draft',
  'prospect',
  'pending_signature',
  'signed',
  'active',
  'expired',
  'terminated',
];

const AGREEMENT_TYPES: readonly PartnershipAgreementType[] = [
  'letter_of_intent',
  'memorandum_of_understanding',
  'pilot',
  'data_sharing',
  'referral',
  'sponsorship',
  'other',
];

type AgreementForm = {
  agreementKey: string;
  partnerId: string;
  institutionId: string;
  status: PartnershipAgreementStatus;
  agreementType: PartnershipAgreementType;
  purposeCodes: string;
  countryCodes: string;
  signedAt: string;
  startsAt: string;
  endsAt: string;
  canRecruitPilot: boolean;
  canVerifySubmission: boolean;
  canVerifyDecision: boolean;
  canShareAggregateData: boolean;
  canPubliclyNamePartner: boolean;
  canUsePartnerLogo: boolean;
};

type AgreementRevisionForm = {
  status: PartnershipAgreementStatus;
  signedAt: string;
  startsAt: string;
  endsAt: string;
};

const EMPTY_FORM: AgreementForm = {
  agreementKey: '',
  partnerId: '',
  institutionId: '',
  status: 'draft',
  agreementType: 'pilot',
  purposeCodes: 'pilot_recruitment',
  countryCodes: '',
  signedAt: '',
  startsAt: '',
  endsAt: '',
  canRecruitPilot: false,
  canVerifySubmission: false,
  canVerifyDecision: false,
  canShareAggregateData: false,
  canPubliclyNamePartner: false,
  canUsePartnerLogo: false,
};

export function PartnerAgreementsPanel({
  role,
  selectedAgreementId,
  onSelectAgreement,
}: Readonly<{
  role: string | undefined;
  selectedAgreementId: string | null;
  onSelectAgreement: (id: string | null) => void;
}>) {
  const t = useTranslations('competitionReadiness');
  const { locale } = useLocale();
  const canManage = hasAdminCapability(
    role,
    AdminCapability.ManagePartnerAgreements,
  );
  const [statusFilter, setStatusFilter] = useState<PartnershipAgreementStatus | ''>('');
  const [countryFilter, setCountryFilter] = useState('');
  const [cursorStack, setCursorStack] = useState<string[]>([]);
  const [page, setPage] = useState<CursorPage<PartnerAgreementItem> | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<unknown>(null);
  const [reloadToken, setReloadToken] = useState(0);
  const [showCreate, setShowCreate] = useState(false);
  const [form, setForm] = useState<AgreementForm>(EMPTY_FORM);
  const [formError, setFormError] = useState<string | null>(null);
  const [revisionError, setRevisionError] = useState<string | null>(null);
  const [pendingCreate, setPendingCreate] = useState<PartnerAgreementDraft | null>(null);
  const [pendingRevision, setPendingRevision] = useState<UpdatePartnerAgreementInput | null>(null);
  const [pendingStatus, setPendingStatus] = useState<PartnershipAgreementStatus | null>(null);
  const [revisionForm, setRevisionForm] = useState<AgreementRevisionForm>({
    status: 'draft',
    signedAt: '',
    startsAt: '',
    endsAt: '',
  });
  const [mutating, setMutating] = useState(false);
  const [mutationNotice, setMutationNotice] = useState<{
    variant: 'success' | 'danger' | 'warning';
    message: string;
  } | null>(null);
  const cursor = cursorStack.at(-1);
  const selected = page?.items.find((item) => item.id === selectedAgreementId) ?? null;

  useEffect(() => {
    if (!selected) return;
    setRevisionForm({
      status: selected.status,
      signedAt: toUtcFormValue(selected.signedAt),
      startsAt: toUtcFormValue(selected.startsAt),
      endsAt: toUtcFormValue(selected.endsAt),
    });
  }, [selected]);

  useEffect(() => {
    if (!canManage) {
      setLoading(false);
      return;
    }
    let cancelled = false;
    setLoading(true);
    setError(null);
    const countryCode = /^[A-Z]{2}$/.test(countryFilter)
      ? countryFilter
      : undefined;

    void listPartnerAgreements({
      cursor,
      limit: 20,
      statuses: statusFilter ? [statusFilter] : undefined,
      countryCode,
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
  }, [canManage, countryFilter, cursor, reloadToken, statusFilter]);

  function refresh() {
    setReloadToken((value) => value + 1);
  }

  function updateForm<K extends keyof AgreementForm>(
    key: K,
    value: AgreementForm[K],
  ) {
    setForm((current) => ({ ...current, [key]: value }));
  }

  function prepareCreate() {
    const countries = parseCountryCodes(form.countryCodes);
    const purposes = parseCodeList(form.purposeCodes);
    const signedAt = form.signedAt ? toUtcIso(form.signedAt) : undefined;
    const startsAt = form.startsAt ? toUtcIso(form.startsAt) : undefined;
    const endsAt = form.endsAt ? toUtcIso(form.endsAt) : undefined;
    const invalidDate =
      (form.signedAt && !signedAt) ||
      (form.startsAt && !startsAt) ||
      (form.endsAt && !endsAt);
    if (
      !/^[a-z0-9][a-z0-9_.-]{2,119}$/.test(form.agreementKey.trim()) ||
      !form.partnerId.trim() ||
      !countries ||
      purposes.length === 0 ||
      invalidDate ||
      (startsAt && endsAt && Date.parse(endsAt) <= Date.parse(startsAt)) ||
      (form.status === 'active' && (!signedAt || !startsAt))
    ) {
      setFormError(t('impactFormValidationError'));
      return;
    }
    setFormError(null);
    setPendingCreate({
      agreementKey: form.agreementKey.trim(),
      partnerId: form.partnerId.trim(),
      institutionId: form.institutionId.trim() || null,
      status: form.status,
      agreementType: form.agreementType,
      purposeCodes: purposes,
      countryCodes: countries,
      canRecruitPilot: form.canRecruitPilot,
      canVerifySubmission: form.canVerifySubmission,
      canVerifyDecision: form.canVerifyDecision,
      canShareAggregateData: form.canShareAggregateData,
      canPubliclyNamePartner: form.canPubliclyNamePartner,
      canUsePartnerLogo: form.canUsePartnerLogo,
      signedAt: signedAt ?? null,
      startsAt: startsAt ?? null,
      endsAt: endsAt ?? null,
      reasonCode: 'partner_agreement_created',
    });
  }

  async function performCreate() {
    if (!pendingCreate) return;
    setMutating(true);
    setMutationNotice(null);
    try {
      const created = await createPartnerAgreement(
        pendingCreate,
        makeIdempotencyKey('partner-agreement'),
      );
      setPendingCreate(null);
      setForm(EMPTY_FORM);
      setShowCreate(false);
      setMutationNotice({ variant: 'success', message: t('agreementCreated') });
      setCursorStack([]);
      onSelectAgreement(created.id);
      refresh();
    } catch (nextError: unknown) {
      setPendingCreate(null);
      setMutationNotice({
        variant: isEndpointUnavailable(nextError) ? 'warning' : 'danger',
        message: mutationErrorMessage(nextError, t),
      });
    } finally {
      setMutating(false);
    }
  }

  async function performStatusUpdate() {
    if (!selected || !pendingStatus) return;
    setMutating(true);
    setMutationNotice(null);
    try {
      await updatePartnerAgreement(selected.id, {
        expectedVersion: selected.lockVersion,
        changes: { status: pendingStatus },
        reasonCode: `partner_agreement_${pendingStatus}`,
      }, makeIdempotencyKey('partner-agreement-update'));
      setPendingStatus(null);
      setMutationNotice({ variant: 'success', message: t('agreementUpdated') });
      refresh();
    } catch (nextError: unknown) {
      setPendingStatus(null);
      setMutationNotice({
        variant: isEndpointUnavailable(nextError) ? 'warning' : 'danger',
        message: mutationErrorMessage(nextError, t),
      });
      if (getApiErrorStatus(nextError) === 409) refresh();
    } finally {
      setMutating(false);
    }
  }

  function prepareRevision() {
    if (!selected) return;
    const signedAt = revisionForm.signedAt ? toUtcIso(revisionForm.signedAt) : null;
    const startsAt = revisionForm.startsAt ? toUtcIso(revisionForm.startsAt) : null;
    const endsAt = revisionForm.endsAt ? toUtcIso(revisionForm.endsAt) : null;
    if (
      (revisionForm.signedAt && !signedAt) ||
      (revisionForm.startsAt && !startsAt) ||
      (revisionForm.endsAt && !endsAt) ||
      (startsAt && endsAt && Date.parse(endsAt) <= Date.parse(startsAt)) ||
      (revisionForm.status === 'active' && (!signedAt || !startsAt))
    ) {
      setRevisionError(t('agreementRevisionValidationError'));
      return;
    }
    setRevisionError(null);
    setPendingRevision({
      expectedVersion: selected.lockVersion,
      changes: {
        status: revisionForm.status,
        signedAt,
        startsAt,
        endsAt,
      },
      reasonCode: 'partner_agreement_governance_updated',
    });
  }

  async function performRevision() {
    if (!selected || !pendingRevision) return;
    setMutating(true);
    setMutationNotice(null);
    try {
      await updatePartnerAgreement(
        selected.id,
        pendingRevision,
        makeIdempotencyKey('partner-agreement-revision'),
      );
      setPendingRevision(null);
      setMutationNotice({ variant: 'success', message: t('agreementUpdated') });
      refresh();
    } catch (nextError: unknown) {
      setPendingRevision(null);
      setMutationNotice({
        variant: isEndpointUnavailable(nextError) ? 'warning' : 'danger',
        message: mutationErrorMessage(nextError, t),
      });
      if (getApiErrorStatus(nextError) === 409) refresh();
    } finally {
      setMutating(false);
    }
  }

  if (!canManage) {
    return <Alert variant="warning">{t('agreementsCapabilityRequired')}</Alert>;
  }

  if (error && isEndpointUnavailable(error)) {
    return (
      <EndpointUnavailableState
        endpoint="GET /api/admin/competition-readiness/partner-agreements"
        onRetry={refresh}
      />
    );
  }

  return (
    <div className={styles.stack}>
      <div className={styles.filters}>
        <Field label={t('filterStatus')}>
          {({ id, invalid }) => (
            <Select
              id={id}
              invalid={invalid}
              value={statusFilter}
              onChange={(event) => {
                setStatusFilter(event.target.value as PartnershipAgreementStatus | '');
                setCursorStack([]);
                onSelectAgreement(null);
              }}
            >
              <option value="">{t('allStatuses')}</option>
              {AGREEMENT_STATUSES.map((status) => (
                <option key={status} value={status}>
                  {t(`agreementStatus_${status}`)}
                </option>
              ))}
            </Select>
          )}
        </Field>
        <Field label={t('filterCountry')}>
          {({ id, invalid }) => (
            <Input
              id={id}
              invalid={invalid}
              maxLength={2}
              value={countryFilter}
              onChange={(event) => {
                setCountryFilter(event.target.value.toUpperCase());
                setCursorStack([]);
              }}
              placeholder="NE"
            />
          )}
        </Field>
        <Button variant="secondary" onClick={refresh}>{t('refresh')}</Button>
        <Button onClick={() => setShowCreate((value) => !value)}>
          {showCreate ? t('closeCreationForm') : t('createAgreement')}
        </Button>
      </div>

      {mutationNotice ? (
        <Alert variant={mutationNotice.variant}>{mutationNotice.message}</Alert>
      ) : null}
      {error ? <Alert variant="danger">{t('agreementsLoadError')}</Alert> : null}

      {showCreate ? (
        <section className={styles.panel}>
          <div>
            <h3 className={styles.panelTitle}>{t('createAgreementTitle')}</h3>
            <p className={styles.panelSubtitle}>{t('createAgreementDescription')}</p>
          </div>
          {formError ? <Alert variant="danger">{formError}</Alert> : null}
          <div className={styles.formGrid}>
            <TextField label={t('agreementKeyLabel')} value={form.agreementKey} onChange={(value) => updateForm('agreementKey', value)} />
            <TextField label={t('partnerIdLabel')} value={form.partnerId} onChange={(value) => updateForm('partnerId', value)} />
            <TextField label={t('institutionIdLabel')} value={form.institutionId} onChange={(value) => updateForm('institutionId', value)} />
            <Field label={t('agreementTypeLabel')}>
              {({ id, invalid }) => (
                <Select id={id} invalid={invalid} value={form.agreementType} onChange={(event) => updateForm('agreementType', event.target.value as PartnershipAgreementType)}>
                  {AGREEMENT_TYPES.map((type) => <option key={type} value={type}>{t(`agreementType_${type}`)}</option>)}
                </Select>
              )}
            </Field>
            <Field label={t('agreementStatusLabel')}>
              {({ id, invalid }) => (
                <Select id={id} invalid={invalid} value={form.status} onChange={(event) => updateForm('status', event.target.value as PartnershipAgreementStatus)}>
                  {AGREEMENT_STATUSES.map((status) => <option key={status} value={status}>{t(`agreementStatus_${status}`)}</option>)}
                </Select>
              )}
            </Field>
            <TextField label={t('countryCodesLabel')} value={form.countryCodes} placeholder="NE, CI" onChange={(value) => updateForm('countryCodes', value)} />
            <TextField label={t('purposeCodesLabel')} value={form.purposeCodes} onChange={(value) => updateForm('purposeCodes', value)} />
            <DateField label={t('signedAtUtcLabel')} value={form.signedAt} onChange={(value) => updateForm('signedAt', value)} />
            <DateField label={t('startsAtUtcLabel')} value={form.startsAt} onChange={(value) => updateForm('startsAt', value)} />
            <DateField label={t('endsAtUtcLabel')} value={form.endsAt} onChange={(value) => updateForm('endsAt', value)} />
          </div>
          <div className={styles.checkGrid}>
            <Check label={t('canRecruitPilot')} checked={form.canRecruitPilot} onChange={(value) => updateForm('canRecruitPilot', value)} />
            <Check label={t('canVerifySubmission')} checked={form.canVerifySubmission} onChange={(value) => updateForm('canVerifySubmission', value)} />
            <Check label={t('canVerifyDecision')} checked={form.canVerifyDecision} onChange={(value) => updateForm('canVerifyDecision', value)} />
            <Check label={t('canShareAggregateData')} checked={form.canShareAggregateData} onChange={(value) => updateForm('canShareAggregateData', value)} />
            <Check label={t('canPubliclyNamePartner')} checked={form.canPubliclyNamePartner} onChange={(value) => updateForm('canPubliclyNamePartner', value)} />
            <Check label={t('canUsePartnerLogo')} checked={form.canUsePartnerLogo} onChange={(value) => updateForm('canUsePartnerLogo', value)} />
          </div>
          <div className={styles.actions}>
            <Button onClick={prepareCreate}>{t('reviewAndCreate')}</Button>
          </div>
        </section>
      ) : null}

      <div className={styles.splitLayout}>
        <div className={styles.stack}>
          <AdminTable
            title={t('agreementsTitle')}
            columns={[t('colPartner'), t('colAgreement'), t('colStatus'), t('colCountries'), t('colValidity')]}
            cols="1.2fr 1.2fr .8fr .8fr 1fr"
            footnote={t('agreementsTableNote')}
          >
            {loading ? (
              Array.from({ length: 4 }, (_, index) => (
                <AdminTableRow key={index}>
                  {Array.from({ length: 5 }, (__, cellIndex) => <Skeleton key={cellIndex} height={18} />)}
                </AdminTableRow>
              ))
            ) : page?.items.length ? (
              page.items.map((item) => (
                <AdminTableRow key={item.id} selected={item.id === selectedAgreementId} onSelect={() => onSelectAgreement(item.id)}>
                  <CellText primary={item.partnerName} sub={item.partnerId} />
                  <CellText primary={item.agreementKey} sub={`${t(`agreementType_${item.agreementType}`)} · v${item.revisionNumber}`} />
                  <Badge variant={agreementStatusVariant(item.status)}>{t(`agreementStatus_${item.status}`)}</Badge>
                  <CellText primary={item.countryCodes.join(', ') || '—'} />
                  <CellText primary={formatDateTime(item.startsAt, locale)} sub={formatDateTime(item.endsAt, locale)} muted />
                </AdminTableRow>
              ))
            ) : (
              <EmptyState title={t('agreementsEmptyTitle')} description={t('agreementsEmptyDescription')} />
            )}
          </AdminTable>
          <Pagination loading={loading} cursorStack={cursorStack} nextCursor={page?.nextCursor ?? null} onPrevious={() => setCursorStack((current) => current.slice(0, -1))} onNext={(nextCursor) => setCursorStack((current) => [...current, nextCursor])} t={t} />
        </div>

        <aside className={`${styles.panel} ${styles.panelSticky}`}>
          {selected ? (
            <>
              <div className={styles.panelHeader}>
                <div>
                  <h3 className={styles.panelTitle}>{selected.partnerName}</h3>
                  <p className={styles.panelSubtitle}>{selected.agreementKey} · {t('revisionNumber', { version: selected.revisionNumber })}</p>
                </div>
                <Badge variant={agreementStatusVariant(selected.status)}>{t(`agreementStatus_${selected.status}`)}</Badge>
              </div>
              <div className={styles.detailGrid}>
                <Detail label={t('agreementTypeLabel')} value={t(`agreementType_${selected.agreementType}`)} />
                <Detail label={t('countryCodesLabel')} value={selected.countryCodes.join(', ') || '—'} />
                <Detail label={t('signedAtLabel')} value={formatDateTime(selected.signedAt, locale)} />
                <Detail label={t('lastVerifiedAtLabel')} value={formatDateTime(selected.lastVerifiedAt, locale)} />
              </div>
              <div className={styles.checkGrid}>
                <CapabilityBadge label={t('canRecruitPilot')} enabled={selected.canRecruitPilot} />
                <CapabilityBadge label={t('canVerifySubmission')} enabled={selected.canVerifySubmission} />
                <CapabilityBadge label={t('canVerifyDecision')} enabled={selected.canVerifyDecision} />
                <CapabilityBadge label={t('canShareAggregateData')} enabled={selected.canShareAggregateData} />
                <CapabilityBadge label={t('canPubliclyNamePartner')} enabled={selected.canPubliclyNamePartner} />
                <CapabilityBadge label={t('canUsePartnerLogo')} enabled={selected.canUsePartnerLogo} />
              </div>
              <Alert variant="info">{t('immutableRevisionNote')}</Alert>
              <section className={styles.mutationBox}>
                <h4 className={styles.sectionTitle}>{t('agreementRevisionTitle')}</h4>
                <p className={styles.panelSubtitle}>{t('agreementRevisionDescription')}</p>
                {revisionError ? <Alert variant="danger">{revisionError}</Alert> : null}
                <Field label={t('agreementStatusLabel')}>
                  {({ id, invalid }) => (
                    <Select id={id} invalid={invalid} value={revisionForm.status} onChange={(event) => setRevisionForm((current) => ({ ...current, status: event.target.value as PartnershipAgreementStatus }))}>
                      {AGREEMENT_STATUSES.map((status) => <option key={status} value={status}>{t(`agreementStatus_${status}`)}</option>)}
                    </Select>
                  )}
                </Field>
                <div className={styles.formGrid}>
                  <DateField label={t('signedAtUtcLabel')} value={revisionForm.signedAt} onChange={(value) => setRevisionForm((current) => ({ ...current, signedAt: value }))} />
                  <DateField label={t('startsAtUtcLabel')} value={revisionForm.startsAt} onChange={(value) => setRevisionForm((current) => ({ ...current, startsAt: value }))} />
                  <DateField label={t('endsAtUtcLabel')} value={revisionForm.endsAt} onChange={(value) => setRevisionForm((current) => ({ ...current, endsAt: value }))} />
                </div>
                <div className={styles.actions}><Button size="sm" onClick={prepareRevision}>{t('reviewAgreementRevision')}</Button></div>
              </section>
              <div className={styles.actions}>
                {selected.status !== 'active' && selected.status !== 'terminated' ? (
                  <Button variant="success" onClick={() => setPendingStatus('active')}>{t('activateAgreement')}</Button>
                ) : null}
                {selected.status !== 'terminated' ? (
                  <Button variant="dangerOutline" onClick={() => setPendingStatus('terminated')}>{t('terminateAgreement')}</Button>
                ) : null}
              </div>
            </>
          ) : (
            <EmptyState title={t('selectAgreementTitle')} description={t('selectAgreementDescription')} />
          )}
        </aside>
      </div>

      <ConfirmDialog
        open={pendingCreate !== null}
        title={t('createAgreementConfirmTitle')}
        description={t('createAgreementConfirmDescription')}
        confirmLabel={t('confirmCreation')}
        cancelLabel={t('cancel')}
        loading={mutating}
        onCancel={() => setPendingCreate(null)}
        onConfirm={() => void performCreate()}
      />
      <ConfirmDialog
        open={pendingRevision !== null}
        title={t('agreementRevisionConfirmTitle')}
        description={t('agreementRevisionConfirmDescription')}
        confirmLabel={t('confirmAgreementRevision')}
        cancelLabel={t('cancel')}
        loading={mutating}
        onCancel={() => setPendingRevision(null)}
        onConfirm={() => void performRevision()}
      />
      <ConfirmDialog
        open={pendingStatus !== null}
        title={pendingStatus ? t(`agreementStatusConfirm_${pendingStatus}`) : ''}
        description={t('agreementStatusConfirmDescription')}
        confirmLabel={t('confirm')}
        cancelLabel={t('cancel')}
        variant={pendingStatus === 'terminated' ? 'danger' : 'primary'}
        loading={mutating}
        onCancel={() => setPendingStatus(null)}
        onConfirm={() => void performStatusUpdate()}
      />
    </div>
  );
}

function TextField({ label, value, placeholder, onChange }: Readonly<{ label: string; value: string; placeholder?: string; onChange: (value: string) => void }>) {
  return <Field label={label}>{({ id, invalid }) => <Input id={id} invalid={invalid} value={value} placeholder={placeholder} onChange={(event) => onChange(event.target.value)} />}</Field>;
}

function DateField({ label, value, onChange }: Readonly<{ label: string; value: string; onChange: (value: string) => void }>) {
  return <Field label={label}>{({ id, invalid }) => <Input id={id} invalid={invalid} type="datetime-local" value={value} onChange={(event) => onChange(event.target.value)} />}</Field>;
}

function Check({ label, checked, onChange }: Readonly<{ label: string; checked: boolean; onChange: (value: boolean) => void }>) {
  return <label className={styles.checkbox}><input type="checkbox" checked={checked} onChange={(event) => onChange(event.target.checked)} />{label}</label>;
}

function CapabilityBadge({ label, enabled }: Readonly<{ label: string; enabled: boolean }>) {
  return <div className={styles.capabilityLine}><span>{label}</span><Badge variant={enabled ? 'success' : 'neutral'}>{enabled ? '✓' : '—'}</Badge></div>;
}

function Detail({ label, value }: Readonly<{ label: string; value: string }>) {
  return <div className={styles.detailItem}><span className={styles.detailLabel}>{label}</span><p className={styles.detailValue}>{value}</p></div>;
}

function Pagination({ loading, cursorStack, nextCursor, onPrevious, onNext, t }: Readonly<{ loading: boolean; cursorStack: string[]; nextCursor: string | null; onPrevious: () => void; onNext: (cursor: string) => void; t: ReturnType<typeof useTranslations<'competitionReadiness'>> }>) {
  return <div className={styles.pagination}><span className={styles.paginationText}>{t('pageNumber', { page: cursorStack.length + 1 })}</span><div className={styles.paginationActions}><Button variant="secondary" size="sm" disabled={loading || cursorStack.length === 0} onClick={onPrevious}>{t('previous')}</Button><Button variant="secondary" size="sm" disabled={loading || !nextCursor} onClick={() => { if (nextCursor) onNext(nextCursor); }}>{t('next')}</Button></div></div>;
}

function mutationErrorMessage(error: unknown, t: ReturnType<typeof useTranslations<'competitionReadiness'>>): string {
  const status = getApiErrorStatus(error);
  if (status === 409) return t('actionConflict');
  if (status === 403) return t('actionForbidden');
  if (isEndpointUnavailable(error)) return t('actionEndpointUnavailable');
  return t('actionFailed');
}
