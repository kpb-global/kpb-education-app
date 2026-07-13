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
} from '../../components/ui';
import type { BadgeVariant } from '../../components/ui';

type ModerationStatus = 'pending' | 'approved' | 'rejected';
type ApplicationRequirement = 'automatic' | 'separate_application';

interface ScholarshipStepEntry {
  id: string;
  stepNumber: number;
  titleFr: string;
  titleEn: string;
  descriptionFr: string;
  descriptionEn: string;
  estimatedDurationDays: number | null;
}

interface ScholarshipEntry {
  id: string;
  nameFr: string;
  nameEn: string;
  countryId: string;
  sourceUrl: string;
  applicationUrl: string;
  deadlineAt: string | null;
  moderationStatus: ModerationStatus;
  lastVerifiedAt: string | null;
  tags: string[];
  applicationRequirement: ApplicationRequirement;
  applicationSteps: ScholarshipStepEntry[];
}

interface StepDraft {
  stepNumber: string;
  titleFr: string;
  titleEn: string;
}

const EMPTY_STEP_DRAFT: StepDraft = { stepNumber: '', titleFr: '', titleEn: '' };

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

  async function moderate(entry: ScholarshipEntry, action: 'approve' | 'reject') {
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

  async function updateRequirement(entry: ScholarshipEntry, value: ApplicationRequirement) {
    if (value === entry.applicationRequirement) {
      return;
    }
    const previous = entry.applicationRequirement;
    setItems((current) =>
      current.map((item) =>
        item.id === entry.id ? { ...item, applicationRequirement: value } : item,
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
          item.id === entry.id ? { ...item, applicationRequirement: previous } : item,
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
      setStepDrafts((current) => ({ ...current, [entry.id]: EMPTY_STEP_DRAFT }));
    } catch (error) {
      setErrorMessage(
        error instanceof Error ? error.message : t('scholarships.stepAddError'),
      );
    } finally {
      setStepPendingId(null);
    }
  }

  async function removeStep(entry: ScholarshipEntry, step: ScholarshipStepEntry) {
    setStepPendingId(entry.id);
    setErrorMessage(null);
    try {
      await apiFetch(`/admin/catalog/scholarships/${entry.id}/steps/${step.id}`, {
        method: 'DELETE',
      });
      setItems((current) =>
        current.map((item) =>
          item.id === entry.id
            ? {
                ...item,
                applicationSteps: item.applicationSteps.filter((s) => s.id !== step.id),
              }
            : item,
        ),
      );
    } catch (error) {
      setErrorMessage(
        error instanceof Error ? error.message : t('scholarships.stepRemoveError'),
      );
    } finally {
      setStepPendingId(null);
    }
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
        <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', alignItems: 'flex-end' }}>
          <div style={{ width: 72 }}>
            <Field label={t('scholarships.stepNumberLabel')}>
              {({ id }) => (
                <Input
                  id={id}
                  type="number"
                  value={draft.stepNumber}
                  onChange={(e) => updateDraft(entry.id, { stepNumber: e.target.value })}
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
                  onChange={(e) => updateDraft(entry.id, { titleFr: e.target.value })}
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
                  onChange={(e) => updateDraft(entry.id, { titleEn: e.target.value })}
                />
              )}
            </Field>
          </div>
          <Button size="sm" variant="secondary" loading={busy} onClick={() => addStep(entry)}>
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
            <span style={metaLabelStyle}>{t('scholarships.deadlineLabel')}</span>
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
            <span style={{ fontSize: 'var(--text-sm)', color: 'var(--text-muted)' }}>
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

        <Field label={t('scholarships.requirementLabel')}>
          {({ id }) => (
            <Select
              id={id}
              value={entry.applicationRequirement}
              onChange={(e) =>
                updateRequirement(entry, e.target.value as ApplicationRequirement)
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
        {statusMessage ? <Alert variant="success">{statusMessage}</Alert> : null}
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
                  <CellText primary={String(entry.applicationSteps.length)} muted />
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
