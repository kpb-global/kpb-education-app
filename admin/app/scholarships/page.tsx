'use client';

import { CSSProperties, useEffect, useMemo, useState } from 'react';

import { useAdminAuth } from '../../components/admin-auth-provider';
import { DashboardShell } from '../../components/dashboard-shell';
import { useLocale } from '../../components/locale-provider';
import { apiFetch } from '../../lib/api-client';
import {
  AdminTable,
  AdminTableRow,
  Alert,
  Badge,
  Button,
  CellText,
  EmptyState,
  Field,
  Input,
  Select,
  Textarea,
} from '../../components/ui';
import type { BadgeVariant } from '../../components/ui';
import { ScholarshipContentEditor } from '../../components/scholarships/ScholarshipContentEditor';
import { ScholarshipVideosEditor } from '../../components/scholarships/ScholarshipVideosEditor';
import type {
  ApplicationRequirement,
  ModerationStatus,
  ScholarshipEntry,
  ScholarshipStepEntry,
} from '../../components/scholarships/types';

interface StepDraft {
  stepNumber: string;
  titleFr: string;
  titleEn: string;
  descriptionFr: string;
  descriptionEn: string;
  estimatedDurationDays: string;
}

const EMPTY_STEP_DRAFT: StepDraft = {
  stepNumber: '',
  titleFr: '',
  titleEn: '',
  descriptionFr: '',
  descriptionEn: '',
  estimatedDurationDays: '',
};

interface ActivationDraft {
  academicYear: string;
  estimatedOpenAt: string;
  estimatedCloseAt: string;
  opensAt: string;
  closesAt: string;
  sourceUrl: string;
}

function defaultActivationDraft(entry: ScholarshipEntry): ActivationDraft {
  const year = new Date().getFullYear();
  return {
    academicYear: entry.currentCycle?.academicYear ?? `${year}-${year + 1}`,
    estimatedOpenAt: entry.currentCycle?.estimatedOpenAt?.slice(0, 10) ?? '',
    estimatedCloseAt: entry.currentCycle?.estimatedCloseAt?.slice(0, 10) ?? '',
    opensAt: entry.currentCycle?.opensAt?.slice(0, 10) ?? '',
    closesAt:
      entry.currentCycle?.closesAt?.slice(0, 10) ??
      entry.deadlineAt?.slice(0, 10) ??
      '',
    sourceUrl: entry.sourceUrl ?? '',
  };
}

interface ModerationResponse {
  items: ScholarshipEntry[];
}

interface RefreshSummary {
  processed?: number;
  created?: number;
  updated?: number;
  [key: string]: unknown;
}

const STATUS_VALUES: ModerationStatus[] = ['pending', 'approved', 'rejected'];

const STATUS_VARIANT: Record<ModerationStatus, BadgeVariant> = {
  pending: 'warning',
  approved: 'success',
  rejected: 'danger',
};

const panelCardStyle: CSSProperties = {
  background: 'var(--surface)',
  border: '1px solid var(--border)',
  borderRadius: 16,
  padding: 16,
};

const panelTitleStyle: CSSProperties = {
  margin: 0,
  fontSize: 'var(--text-base)',
  fontWeight: 800,
  color: 'var(--ink)',
};

const metaLabelStyle: CSSProperties = {
  fontSize: 9.5,
  fontWeight: 800,
  letterSpacing: '0.06em',
  textTransform: 'uppercase',
  color: 'var(--text-faint)',
};

function formatDeadline(iso: string | null): string {
  if (!iso) {
    return '—';
  }
  const date = new Date(iso);
  if (Number.isNaN(date.getTime())) {
    return '—';
  }
  const day = String(date.getDate()).padStart(2, '0');
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const year = date.getFullYear();
  return `${day}/${month}/${year}`;
}

export default function ScholarshipsPage() {
  const { session } = useAdminAuth();
  const { t } = useLocale();
  const [statusFilter, setStatusFilter] = useState<ModerationStatus>('pending');
  const [items, setItems] = useState<ScholarshipEntry[]>([]);
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [pendingId, setPendingId] = useState<string | null>(null);
  const [statusMessage, setStatusMessage] = useState<string | null>(null);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [stepDrafts, setStepDrafts] = useState<Record<string, StepDraft>>({});
  const [stepPendingId, setStepPendingId] = useState<string | null>(null);
  const [activationDrafts, setActivationDrafts] = useState<
    Record<string, ActivationDraft>
  >({});
  const [activationPendingId, setActivationPendingId] = useState<string | null>(
    null,
  );
  const [forecastPendingId, setForecastPendingId] = useState<string | null>(
    null,
  );

  const selected = useMemo(
    () => items.find((item) => item.id === selectedId) ?? null,
    [items, selectedId],
  );

  function statusLabel(status: ModerationStatus) {
    return t(`scholarships.status_${status}`);
  }

  function requirementLabel(value: ApplicationRequirement) {
    return value === 'automatic'
      ? t('scholarships.requirementAutomatic')
      : t('scholarships.requirementSeparate');
  }

  async function loadScholarships(status: ModerationStatus) {
    setLoading(true);
    setErrorMessage(null);
    try {
      const response = await apiFetch<ModerationResponse>(
        `/admin/scholarships/moderation?status=${status}`,
      );
      const nextItems = response?.items ?? [];
      setItems(nextItems);
      setSelectedId((current) =>
        current && nextItems.some((item) => item.id === current)
          ? current
          : (nextItems[0]?.id ?? null),
      );
    } catch (error) {
      setErrorMessage(
        error instanceof Error ? error.message : t('scholarships.loadError'),
      );
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    if (!session) {
      return;
    }
    void loadScholarships(statusFilter);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [session, statusFilter]);

  function changeFilter(next: ModerationStatus) {
    if (next === statusFilter) {
      return;
    }
    setStatusMessage(null);
    setErrorMessage(null);
    setStatusFilter(next);
  }

  async function refreshFeed() {
    setRefreshing(true);
    setStatusMessage(null);
    setErrorMessage(null);
    try {
      const summary = await apiFetch<RefreshSummary>(
        '/admin/scholarships/refresh',
        { method: 'POST' },
      );
      const processed =
        summary && typeof summary.processed === 'number'
          ? summary.processed
          : null;
      setStatusMessage(
        processed !== null
          ? `${t('scholarships.refreshSuccess')} ${processed} ${t('scholarships.processedSuffix')}`
          : t('scholarships.refreshSuccess'),
      );
      await loadScholarships(statusFilter);
    } catch (error) {
      setErrorMessage(
        error instanceof Error ? error.message : t('scholarships.refreshError'),
      );
    } finally {
      setRefreshing(false);
    }
  }

  async function moderate(
    entry: ScholarshipEntry,
    action: 'approve' | 'reject',
  ) {
    setPendingId(entry.id);
    setStatusMessage(null);
    setErrorMessage(null);
    try {
      await apiFetch(`/admin/scholarships/${entry.id}/${action}`, {
        method: 'POST',
      });
      // The row no longer matches the active filter, so drop it from the list.
      setItems((current) => current.filter((item) => item.id !== entry.id));
      setSelectedId((current) => (current === entry.id ? null : current));
      setStatusMessage(
        action === 'approve'
          ? t('scholarships.approveSuccess')
          : t('scholarships.rejectSuccess'),
      );
    } catch (error) {
      setErrorMessage(
        error instanceof Error ? error.message : t('scholarships.updateError'),
      );
    } finally {
      setPendingId(null);
    }
  }

  async function updateRequirement(
    entry: ScholarshipEntry,
    value: ApplicationRequirement,
  ) {
    if (value === entry.applicationRequirement) {
      return;
    }
    const previous = entry.applicationRequirement;
    setItems((current) =>
      current.map((item) =>
        item.id === entry.id
          ? { ...item, applicationRequirement: value }
          : item,
      ),
    );
    try {
      await apiFetch(`/admin/catalog/scholarships/${entry.id}`, {
        method: 'PATCH',
        body: { applicationRequirement: value },
      });
    } catch (error) {
      setItems((current) =>
        current.map((item) =>
          item.id === entry.id
            ? { ...item, applicationRequirement: previous }
            : item,
        ),
      );
      setErrorMessage(
        error instanceof Error
          ? error.message
          : t('scholarships.requirementError'),
      );
    }
  }

  function updateDraft(entryId: string, patch: Partial<StepDraft>) {
    setStepDrafts((current) => ({
      ...current,
      [entryId]: { ...EMPTY_STEP_DRAFT, ...current[entryId], ...patch },
    }));
  }

  function patchEntry(entryId: string, patch: Partial<ScholarshipEntry>) {
    setItems((current) =>
      current.map((item) =>
        item.id === entryId ? { ...item, ...patch } : item,
      ),
    );
  }

  async function addStep(entry: ScholarshipEntry) {
    const draft = stepDrafts[entry.id] ?? EMPTY_STEP_DRAFT;
    const stepNumber = Number(draft.stepNumber);
    if (!draft.titleFr.trim() || !Number.isFinite(stepNumber)) {
      setErrorMessage(t('scholarships.stepValidationError'));
      return;
    }
    setStepPendingId(entry.id);
    setErrorMessage(null);
    try {
      const created = await apiFetch<ScholarshipStepEntry>(
        `/admin/catalog/scholarships/${entry.id}/steps`,
        {
          method: 'POST',
          body: {
            stepNumber,
            titleFr: draft.titleFr.trim(),
            titleEn: draft.titleEn.trim() || undefined,
            descriptionFr: draft.descriptionFr.trim(),
            descriptionEn: draft.descriptionEn.trim(),
            estimatedDurationDays: draft.estimatedDurationDays.trim()
              ? Number(draft.estimatedDurationDays)
              : undefined,
          },
        },
      );
      setItems((current) =>
        current.map((item) =>
          item.id === entry.id
            ? {
                ...item,
                applicationSteps: [...item.applicationSteps, created].sort(
                  (a, b) => a.stepNumber - b.stepNumber,
                ),
              }
            : item,
        ),
      );
      setStepDrafts((current) => ({
        ...current,
        [entry.id]: EMPTY_STEP_DRAFT,
      }));
    } catch (error) {
      setErrorMessage(
        error instanceof Error ? error.message : t('scholarships.stepAddError'),
      );
    } finally {
      setStepPendingId(null);
    }
  }

  async function removeStep(
    entry: ScholarshipEntry,
    step: ScholarshipStepEntry,
  ) {
    setStepPendingId(entry.id);
    setErrorMessage(null);
    try {
      await apiFetch(
        `/admin/catalog/scholarships/${entry.id}/steps/${step.id}`,
        {
          method: 'DELETE',
        },
      );
      setItems((current) =>
        current.map((item) =>
          item.id === entry.id
            ? {
                ...item,
                applicationSteps: item.applicationSteps.filter(
                  (s) => s.id !== step.id,
                ),
              }
            : item,
        ),
      );
    } catch (error) {
      setErrorMessage(
        error instanceof Error
          ? error.message
          : t('scholarships.stepRemoveError'),
      );
    } finally {
      setStepPendingId(null);
    }
  }

  function updateActivationDraft(
    entry: ScholarshipEntry,
    patch: Partial<ActivationDraft>,
  ) {
    setActivationDrafts((current) => ({
      ...current,
      [entry.id]: {
        ...defaultActivationDraft(entry),
        ...current[entry.id],
        ...patch,
      },
    }));
  }

  async function activateScholarship(entry: ScholarshipEntry) {
    const draft = activationDrafts[entry.id] ?? defaultActivationDraft(entry);
    if (!draft.academicYear || !draft.opensAt || !draft.closesAt) {
      setErrorMessage(t('scholarships.activationValidationError'));
      return;
    }
    if (new Date(draft.closesAt) <= new Date(draft.opensAt)) {
      setErrorMessage(t('scholarships.activationDateError'));
      return;
    }

    setActivationPendingId(entry.id);
    setStatusMessage(null);
    setErrorMessage(null);
    try {
      await apiFetch(`/admin/scholarships/${entry.id}/activate`, {
        method: 'POST',
        body: {
          academicYear: draft.academicYear,
          opensAt: `${draft.opensAt}T00:00:00.000Z`,
          closesAt: `${draft.closesAt}T23:59:59.999Z`,
          dateConfidence: 'confirmed',
          sourceUrl: draft.sourceUrl || undefined,
        },
      });
      setItems((current) =>
        current.map((item) =>
          item.id === entry.id
            ? {
                ...item,
                deadlineAt: `${draft.closesAt}T23:59:59.999Z`,
                currentCycle: {
                  id: item.currentCycle?.id ?? '',
                  academicYear: draft.academicYear,
                  status: 'open',
                  dateConfidence: 'confirmed',
                  estimatedOpenAt: item.currentCycle?.estimatedOpenAt ?? null,
                  estimatedCloseAt: item.currentCycle?.estimatedCloseAt ?? null,
                  opensAt: `${draft.opensAt}T00:00:00.000Z`,
                  closesAt: `${draft.closesAt}T23:59:59.999Z`,
                },
              }
            : item,
        ),
      );
      setStatusMessage(t('scholarships.activationSuccess'));
    } catch (error) {
      setErrorMessage(
        error instanceof Error
          ? error.message
          : t('scholarships.activationError'),
      );
    } finally {
      setActivationPendingId(null);
    }
  }

  async function saveForecast(entry: ScholarshipEntry) {
    const draft = activationDrafts[entry.id] ?? defaultActivationDraft(entry);
    if (
      !draft.academicYear ||
      !draft.estimatedOpenAt ||
      !draft.estimatedCloseAt
    ) {
      setErrorMessage(t('scholarships.forecastValidationError'));
      return;
    }
    if (new Date(draft.estimatedCloseAt) <= new Date(draft.estimatedOpenAt)) {
      setErrorMessage(t('scholarships.activationDateError'));
      return;
    }

    setForecastPendingId(entry.id);
    setStatusMessage(null);
    setErrorMessage(null);
    try {
      await apiFetch(`/admin/scholarships/${entry.id}/forecast`, {
        method: 'POST',
        body: {
          academicYear: draft.academicYear,
          estimatedOpenAt: `${draft.estimatedOpenAt}T00:00:00.000Z`,
          estimatedCloseAt: `${draft.estimatedCloseAt}T23:59:59.999Z`,
          sourceUrl: draft.sourceUrl || undefined,
        },
      });
      setItems((current) =>
        current.map((item) =>
          item.id === entry.id
            ? {
                ...item,
                currentCycle: {
                  id: item.currentCycle?.id ?? '',
                  academicYear: draft.academicYear,
                  status:
                    item.currentCycle?.status === 'open' ? 'open' : 'forecast',
                  dateConfidence:
                    item.currentCycle?.status === 'open'
                      ? 'confirmed'
                      : 'estimated',
                  estimatedOpenAt: `${draft.estimatedOpenAt}T00:00:00.000Z`,
                  estimatedCloseAt: `${draft.estimatedCloseAt}T23:59:59.999Z`,
                  opensAt: item.currentCycle?.opensAt ?? null,
                  closesAt: item.currentCycle?.closesAt ?? null,
                },
              }
            : item,
        ),
      );
      setStatusMessage(t('scholarships.forecastSuccess'));
    } catch (error) {
      setErrorMessage(
        error instanceof Error
          ? error.message
          : t('scholarships.forecastError'),
      );
    } finally {
      setForecastPendingId(null);
    }
  }

  function renderActivationEditor(entry: ScholarshipEntry) {
    if (entry.moderationStatus !== 'approved') {
      return (
        <Alert variant="warning">
          {t('scholarships.activationApprovalHint')}
        </Alert>
      );
    }
    const draft = activationDrafts[entry.id] ?? defaultActivationDraft(entry);
    const busy = activationPendingId === entry.id;
    const forecastBusy = forecastPendingId === entry.id;
    return (
      <div
        style={{
          display: 'grid',
          gap: 10,
          padding: 14,
          borderRadius: 14,
          border: '1px solid var(--border)',
          background: 'var(--bg)',
        }}
      >
        <span style={metaLabelStyle}>{t('scholarships.activationTitle')}</span>
        <div
          style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8 }}
        >
          <Field label={t('scholarships.academicYearLabel')}>
            {({ id }) => (
              <Input
                id={id}
                value={draft.academicYear}
                onChange={(event) =>
                  updateActivationDraft(entry, {
                    academicYear: event.target.value,
                  })
                }
              />
            )}
          </Field>
          <Field label={t('scholarships.sourceLabel')}>
            {({ id }) => (
              <Input
                id={id}
                type="url"
                value={draft.sourceUrl}
                onChange={(event) =>
                  updateActivationDraft(entry, {
                    sourceUrl: event.target.value,
                  })
                }
              />
            )}
          </Field>
          <Field label={t('scholarships.estimatedOpenAtLabel')}>
            {({ id }) => (
              <Input
                id={id}
                type="date"
                value={draft.estimatedOpenAt}
                onChange={(event) =>
                  updateActivationDraft(entry, {
                    estimatedOpenAt: event.target.value,
                  })
                }
              />
            )}
          </Field>
          <Field label={t('scholarships.estimatedCloseAtLabel')}>
            {({ id }) => (
              <Input
                id={id}
                type="date"
                value={draft.estimatedCloseAt}
                onChange={(event) =>
                  updateActivationDraft(entry, {
                    estimatedCloseAt: event.target.value,
                  })
                }
              />
            )}
          </Field>
        </div>
        <Button
          variant="secondary"
          loading={forecastBusy}
          onClick={() => saveForecast(entry)}
        >
          {t('scholarships.saveForecastCta')}
        </Button>
        <span
          style={{ fontSize: 'var(--text-xs)', color: 'var(--text-muted)' }}
        >
          {t('scholarships.forecastHint')}
        </span>
        <div
          style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8 }}
        >
          <Field label={t('scholarships.opensAtLabel')}>
            {({ id }) => (
              <Input
                id={id}
                type="date"
                value={draft.opensAt}
                onChange={(event) =>
                  updateActivationDraft(entry, { opensAt: event.target.value })
                }
              />
            )}
          </Field>
          <Field label={t('scholarships.closesAtLabel')}>
            {({ id }) => (
              <Input
                id={id}
                type="date"
                value={draft.closesAt}
                onChange={(event) =>
                  updateActivationDraft(entry, { closesAt: event.target.value })
                }
              />
            )}
          </Field>
        </div>
        <Button
          variant="success"
          loading={busy}
          onClick={() => activateScholarship(entry)}
        >
          {t('scholarships.activateCta')}
        </Button>
        <span
          style={{ fontSize: 'var(--text-xs)', color: 'var(--text-muted)' }}
        >
          {t('scholarships.activationHint')}
        </span>
      </div>
    );
  }

  function renderStepsEditor(entry: ScholarshipEntry) {
    const draft = stepDrafts[entry.id] ?? EMPTY_STEP_DRAFT;
    const busy = stepPendingId === entry.id;

    return (
      <div style={{ display: 'grid', gap: 10 }}>
        <span style={metaLabelStyle}>
          {t('scholarships.stepsTitle')} ({entry.applicationSteps.length})
        </span>
        {entry.applicationSteps.map((step) => (
          <div
            key={step.id}
            style={{
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'space-between',
              gap: 12,
              background: 'var(--bg)',
              border: '1px solid var(--border-soft)',
              borderRadius: 12,
              padding: '8px 12px',
            }}
          >
            <span style={{ fontSize: 'var(--text-sm)' }}>
              <strong>{step.stepNumber}.</strong> {step.titleFr}
            </span>
            <Button
              size="sm"
              variant="dangerOutline"
              disabled={busy}
              onClick={() => removeStep(entry, step)}
            >
              {t('scholarships.removeStepCta')}
            </Button>
          </div>
        ))}
        <div
          style={{
            display: 'flex',
            gap: 8,
            flexWrap: 'wrap',
            alignItems: 'flex-end',
          }}
        >
          <div style={{ width: 72 }}>
            <Field label={t('scholarships.stepNumberLabel')}>
              {({ id }) => (
                <Input
                  id={id}
                  type="number"
                  value={draft.stepNumber}
                  onChange={(e) =>
                    updateDraft(entry.id, { stepNumber: e.target.value })
                  }
                />
              )}
            </Field>
          </div>
          <div style={{ flex: 1, minWidth: 140 }}>
            <Field label={t('scholarships.stepTitleFrLabel')}>
              {({ id }) => (
                <Input
                  id={id}
                  value={draft.titleFr}
                  onChange={(e) =>
                    updateDraft(entry.id, { titleFr: e.target.value })
                  }
                />
              )}
            </Field>
          </div>
          <div style={{ flex: 1, minWidth: 140 }}>
            <Field label={t('scholarships.stepTitleEnLabel')}>
              {({ id }) => (
                <Input
                  id={id}
                  value={draft.titleEn}
                  onChange={(e) =>
                    updateDraft(entry.id, { titleEn: e.target.value })
                  }
                />
              )}
            </Field>
          </div>
          <div style={{ flexBasis: '100%' }} />
          <div style={{ flex: 1, minWidth: 220 }}>
            <Field label={t('scholarships.stepDescriptionFrLabel')}>
              {({ id }) => (
                <Textarea
                  id={id}
                  rows={3}
                  value={draft.descriptionFr}
                  onChange={(e) =>
                    updateDraft(entry.id, { descriptionFr: e.target.value })
                  }
                />
              )}
            </Field>
          </div>
          <div style={{ flex: 1, minWidth: 220 }}>
            <Field label={t('scholarships.stepDescriptionEnLabel')}>
              {({ id }) => (
                <Textarea
                  id={id}
                  rows={3}
                  value={draft.descriptionEn}
                  onChange={(e) =>
                    updateDraft(entry.id, { descriptionEn: e.target.value })
                  }
                />
              )}
            </Field>
          </div>
          <div style={{ width: 150 }}>
            <Field label={t('scholarships.stepDurationLabel')}>
              {({ id }) => (
                <Input
                  id={id}
                  type="number"
                  min={0}
                  value={draft.estimatedDurationDays}
                  onChange={(e) =>
                    updateDraft(entry.id, {
                      estimatedDurationDays: e.target.value,
                    })
                  }
                />
              )}
            </Field>
          </div>
          <Button
            size="sm"
            variant="secondary"
            loading={busy}
            onClick={() => addStep(entry)}
          >
            {t('scholarships.addStepCta')}
          </Button>
        </div>
      </div>
    );
  }

  function renderDetail(entry: ScholarshipEntry) {
    const isPending = pendingId === entry.id;
    return (
      <section style={{ ...panelCardStyle, display: 'grid', gap: 14 }}>
        <div
          style={{
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            gap: 12,
            flexWrap: 'wrap',
          }}
        >
          <h3 style={panelTitleStyle}>{entry.nameFr}</h3>
          <Badge variant={STATUS_VARIANT[entry.moderationStatus]}>
            {statusLabel(entry.moderationStatus)}
          </Badge>
        </div>

        <div style={{ display: 'flex', gap: 24, flexWrap: 'wrap' }}>
          <div style={{ display: 'grid', gap: 2 }}>
            <span style={metaLabelStyle}>{t('scholarships.countryLabel')}</span>
            <span style={{ fontSize: 'var(--text-sm)', fontWeight: 700 }}>
              {entry.countryId || '—'}
            </span>
          </div>
          <div style={{ display: 'grid', gap: 2 }}>
            <span style={metaLabelStyle}>
              {t('scholarships.deadlineLabel')}
            </span>
            <span style={{ fontSize: 'var(--text-sm)', fontWeight: 700 }}>
              {formatDeadline(entry.deadlineAt)}
            </span>
          </div>
        </div>

        <div style={{ display: 'grid', gap: 2 }}>
          <span style={metaLabelStyle}>{t('scholarships.sourceLabel')}</span>
          {entry.sourceUrl ? (
            <a
              href={entry.sourceUrl}
              target="_blank"
              rel="noreferrer"
              style={{
                color: 'var(--brand)',
                wordBreak: 'break-all',
                fontSize: 'var(--text-sm)',
              }}
            >
              {entry.sourceUrl}
            </a>
          ) : (
            <span
              style={{ fontSize: 'var(--text-sm)', color: 'var(--text-muted)' }}
            >
              {t('scholarships.noSource')}
            </span>
          )}
        </div>

        {entry.tags.length > 0 ? (
          <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap' }}>
            {entry.tags.map((tag) => (
              <Badge key={tag} variant="neutral">
                {tag}
              </Badge>
            ))}
          </div>
        ) : null}

        <ScholarshipContentEditor
          entry={entry}
          onSaved={(patch) => patchEntry(entry.id, patch)}
        />

        <Field label={t('scholarships.requirementLabel')}>
          {({ id }) => (
            <Select
              id={id}
              value={entry.applicationRequirement}
              onChange={(e) =>
                updateRequirement(
                  entry,
                  e.target.value as ApplicationRequirement,
                )
              }
            >
              <option value="automatic">{requirementLabel('automatic')}</option>
              <option value="separate_application">
                {requirementLabel('separate_application')}
              </option>
            </Select>
          )}
        </Field>

        {renderStepsEditor(entry)}

        <ScholarshipVideosEditor
          entry={entry}
          onChanged={(videos) => patchEntry(entry.id, { videos })}
        />

        {renderActivationEditor(entry)}

        <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
          {entry.moderationStatus === 'pending' ||
          entry.moderationStatus === 'rejected' ? (
            <Button
              variant="success"
              loading={isPending}
              onClick={() => moderate(entry, 'approve')}
            >
              {t('scholarships.approveCta')}
            </Button>
          ) : null}
          {entry.moderationStatus === 'pending' ||
          entry.moderationStatus === 'approved' ? (
            <Button
              variant="dangerOutline"
              disabled={isPending}
              onClick={() => moderate(entry, 'reject')}
            >
              {t('scholarships.rejectCta')}
            </Button>
          ) : null}
        </div>
      </section>
    );
  }

  return (
    <DashboardShell title={t('scholarships.title')} subtitle={t('scholarships.subtitle')}>
      <div style={{ display: 'grid', gap: 14 }}>
        {statusMessage ? (
          <Alert variant="success">{statusMessage}</Alert>
        ) : null}
        {errorMessage ? <Alert variant="danger">{errorMessage}</Alert> : null}

        <div
          style={{
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            gap: 12,
            flexWrap: 'wrap',
          }}
        >
          <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
            {STATUS_VALUES.map((value) => (
              <Button
                key={value}
                size="sm"
                variant={value === statusFilter ? 'primary' : 'secondary'}
                onClick={() => changeFilter(value)}
              >
                {t(`scholarships.filter_${value}`)}
              </Button>
            ))}
          </div>
          <Button size="sm" loading={refreshing} onClick={refreshFeed}>
            {refreshing
              ? t('scholarships.refreshing')
              : t('scholarships.refreshCta')}
          </Button>
        </div>

        <div
          style={{
            display: 'grid',
            gap: 14,
            gridTemplateColumns: 'minmax(0, 1.1fr) minmax(0, 0.9fr)',
            alignItems: 'start',
          }}
        >
          <AdminTable
            aria-label={t('scholarships.title')}
            columns={[
              t('scholarships.colName'),
              t('scholarships.colDeadline'),
              t('scholarships.colSteps'),
              t('scholarships.colStatus'),
            ]}
            cols="1.6fr 0.8fr 0.6fr 0.8fr"
            footnote={t('scholarships.tableNote')}
          >
            {loading ? (
              <EmptyState title={t('scholarships.loading')} />
            ) : items.length === 0 ? (
              <EmptyState title={t('scholarships.empty')} />
            ) : (
              items.map((entry) => (
                <AdminTableRow
                  key={entry.id}
                  selected={selectedId === entry.id}
                  onSelect={() => setSelectedId(entry.id)}
                >
                  <CellText
                    primary={entry.nameFr}
                    sub={entry.countryId || undefined}
                  />
                  <CellText primary={formatDeadline(entry.deadlineAt)} muted />
                  <CellText
                    primary={String(entry.applicationSteps.length)}
                    muted
                  />
                  <div>
                    <Badge variant={STATUS_VARIANT[entry.moderationStatus]}>
                      {statusLabel(entry.moderationStatus)}
                    </Badge>
                  </div>
                </AdminTableRow>
              ))
            )}
          </AdminTable>

          {selected ? (
            renderDetail(selected)
          ) : (
            <section style={panelCardStyle}>
              <EmptyState title={t('scholarships.selectHint')} />
            </section>
          )}
        </div>
      </div>
    </DashboardShell>
  );
}
