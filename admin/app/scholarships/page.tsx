'use client';

import { useEffect, useState } from 'react';

import { useAdminAuth } from '../../components/admin-auth-provider';
import { DashboardShell } from '../../components/dashboard-shell';
import { apiFetch } from '../../lib/api-client';
import {
  badgeStyle,
  buttonStyle,
  inputStyle,
  labelStyle,
  mutedTextStyle,
  panelStyle,
  secondaryButtonStyle,
} from '../../lib/ui';

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

const requirementLabels: Record<ApplicationRequirement, string> = {
  automatic: 'Automatique (attribuée à l’admission)',
  separate_application: 'Candidature séparée requise',
};

interface ModerationResponse {
  items: ScholarshipEntry[];
}

interface RefreshSummary {
  processed?: number;
  created?: number;
  updated?: number;
  [key: string]: unknown;
}

const STATUS_FILTERS: { value: ModerationStatus; label: string }[] = [
  { value: 'pending', label: 'En attente' },
  { value: 'approved', label: 'Approuvées' },
  { value: 'rejected', label: 'Rejetées' },
];

const approveButtonStyle = {
  ...buttonStyle,
  background: '#16A34A',
};

const rejectButtonStyle = {
  ...buttonStyle,
  background: '#DC2626',
};

const chipStyle = {
  ...badgeStyle,
  background: '#E9EEF6',
  color: '#334155',
};

const statusBadgeStyles: Record<ModerationStatus, typeof badgeStyle> = {
  pending: { ...badgeStyle, background: '#FEF3C7', color: '#92400E' },
  approved: { ...badgeStyle, background: '#ECFDF5', color: '#166534' },
  rejected: { ...badgeStyle, background: '#FEF2F2', color: '#B91C1C' },
};

const statusLabels: Record<ModerationStatus, string> = {
  pending: 'En attente',
  approved: 'Approuvée',
  rejected: 'Rejetée',
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
  const [statusFilter, setStatusFilter] = useState<ModerationStatus>('pending');
  const [items, setItems] = useState<ScholarshipEntry[]>([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [pendingId, setPendingId] = useState<string | null>(null);
  const [statusMessage, setStatusMessage] = useState<string | null>(null);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [expandedStepsId, setExpandedStepsId] = useState<string | null>(null);
  const [stepDrafts, setStepDrafts] = useState<Record<string, StepDraft>>({});
  const [stepPendingId, setStepPendingId] = useState<string | null>(null);

  async function loadScholarships(status: ModerationStatus) {
    setLoading(true);
    setErrorMessage(null);
    try {
      const response = await apiFetch<ModerationResponse>(
        `/admin/scholarships/moderation?status=${status}`,
      );
      setItems(response?.items ?? []);
    } catch (error) {
      setErrorMessage(
        error instanceof Error
          ? error.message
          : 'Impossible de charger les bourses.',
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
          ? `Flux rafraîchi — ${processed} bourse(s) traitée(s).`
          : 'Flux rafraîchi.',
      );
      await loadScholarships(statusFilter);
    } catch (error) {
      setErrorMessage(
        error instanceof Error
          ? error.message
          : 'Impossible de rafraîchir le flux.',
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
      setStatusMessage(
        action === 'approve'
          ? 'Bourse approuvée.'
          : 'Bourse rejetée.',
      );
    } catch (error) {
      setErrorMessage(
        error instanceof Error
          ? error.message
          : 'Impossible de mettre à jour la bourse.',
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
          : 'Impossible de mettre à jour le type de candidature.',
      );
    }
  }

  function toggleSteps(entryId: string) {
    setExpandedStepsId((current) => (current === entryId ? null : entryId));
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
      setErrorMessage('Numéro d’étape et titre (FR) requis.');
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
        error instanceof Error ? error.message : "Impossible d'ajouter l'étape.",
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
        error instanceof Error ? error.message : "Impossible de supprimer l'étape.",
      );
    } finally {
      setStepPendingId(null);
    }
  }

  function renderApplicationSteps(entry: ScholarshipEntry) {
    const expanded = expandedStepsId === entry.id;
    const draft = stepDrafts[entry.id] ?? EMPTY_STEP_DRAFT;
    const busy = stepPendingId === entry.id;

    return (
      <div style={{ display: 'grid', gap: 8 }}>
        <button
          type="button"
          onClick={() => toggleSteps(entry.id)}
          style={{ ...secondaryButtonStyle, justifySelf: 'start', padding: '6px 12px' }}
        >
          {expanded ? 'Masquer' : 'Étapes de candidature'} ({entry.applicationSteps.length})
        </button>
        {expanded ? (
          <div style={{ display: 'grid', gap: 10, paddingLeft: 12 }}>
            {entry.applicationSteps.map((step) => (
              <div
                key={step.id}
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'space-between',
                  gap: 12,
                }}
              >
                <span>
                  <strong>{step.stepNumber}.</strong> {step.titleFr}
                </span>
                <button
                  type="button"
                  onClick={() => removeStep(entry, step)}
                  disabled={busy}
                  style={{ ...rejectButtonStyle, opacity: busy ? 0.6 : 1, padding: '4px 10px' }}
                >
                  Retirer
                </button>
              </div>
            ))}
            <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', alignItems: 'flex-end' }}>
              <label style={{ display: 'grid', gap: 4 }}>
                <span style={labelStyle}>N°</span>
                <input
                  type="number"
                  value={draft.stepNumber}
                  onChange={(e) => updateDraft(entry.id, { stepNumber: e.target.value })}
                  style={{ ...inputStyle, width: 64 }}
                />
              </label>
              <label style={{ display: 'grid', gap: 4, flex: 1, minWidth: 160 }}>
                <span style={labelStyle}>Titre (FR)</span>
                <input
                  type="text"
                  value={draft.titleFr}
                  onChange={(e) => updateDraft(entry.id, { titleFr: e.target.value })}
                  style={inputStyle}
                />
              </label>
              <label style={{ display: 'grid', gap: 4, flex: 1, minWidth: 160 }}>
                <span style={labelStyle}>Titre (EN)</span>
                <input
                  type="text"
                  value={draft.titleEn}
                  onChange={(e) => updateDraft(entry.id, { titleEn: e.target.value })}
                  style={inputStyle}
                />
              </label>
              <button
                type="button"
                onClick={() => addStep(entry)}
                disabled={busy}
                style={{ ...buttonStyle, opacity: busy ? 0.6 : 1 }}
              >
                Ajouter
              </button>
            </div>
          </div>
        ) : null}
      </div>
    );
  }

  function renderActions(entry: ScholarshipEntry) {
    const isPending = pendingId === entry.id;
    const buttons: React.ReactNode[] = [];

    if (entry.moderationStatus === 'pending' || entry.moderationStatus === 'rejected') {
      buttons.push(
        <button
          key="approve"
          type="button"
          onClick={() => moderate(entry, 'approve')}
          disabled={isPending}
          style={{ ...approveButtonStyle, opacity: isPending ? 0.6 : 1 }}
        >
          Approuver
        </button>,
      );
    }

    if (entry.moderationStatus === 'pending' || entry.moderationStatus === 'approved') {
      buttons.push(
        <button
          key="reject"
          type="button"
          onClick={() => moderate(entry, 'reject')}
          disabled={isPending}
          style={{ ...rejectButtonStyle, opacity: isPending ? 0.6 : 1 }}
        >
          Rejeter
        </button>,
      );
    }

    return <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>{buttons}</div>;
  }

  function renderEntry(entry: ScholarshipEntry) {
    return (
      <div
        key={entry.id}
        style={{
          borderTop: '1px solid #E2E8F0',
          paddingTop: 12,
          display: 'grid',
          gap: 10,
        }}
      >
        <div
          style={{
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            gap: 12,
            flexWrap: 'wrap',
          }}
        >
          <strong>{entry.nameFr}</strong>
          <span style={statusBadgeStyles[entry.moderationStatus]}>
            {statusLabels[entry.moderationStatus]}
          </span>
        </div>
        <div style={{ ...mutedTextStyle, display: 'flex', gap: 16, flexWrap: 'wrap' }}>
          <span>Pays : {entry.countryId || '—'}</span>
          <span>Échéance : {formatDeadline(entry.deadlineAt)}</span>
        </div>
        {entry.sourceUrl ? (
          <a
            href={entry.sourceUrl}
            target="_blank"
            rel="noreferrer"
            style={{ color: 'var(--brand)', wordBreak: 'break-all' }}
          >
            {entry.sourceUrl}
          </a>
        ) : (
          <span style={mutedTextStyle}>Aucune source</span>
        )}
        {entry.tags.length > 0 ? (
          <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap' }}>
            {entry.tags.map((tag) => (
              <span key={tag} style={chipStyle}>
                {tag}
              </span>
            ))}
          </div>
        ) : null}
        <label style={{ display: 'grid', gap: 4, maxWidth: 320 }}>
          <span style={labelStyle}>Type de candidature</span>
          <select
            value={entry.applicationRequirement}
            onChange={(e) =>
              updateRequirement(entry, e.target.value as ApplicationRequirement)
            }
            style={inputStyle}
          >
            {(Object.keys(requirementLabels) as ApplicationRequirement[]).map((value) => (
              <option key={value} value={value}>
                {requirementLabels[value]}
              </option>
            ))}
          </select>
        </label>
        {renderApplicationSteps(entry)}
        {renderActions(entry)}
      </div>
    );
  }

  return (
    <DashboardShell title="Modération des bourses">
      <div style={{ display: 'grid', gap: 18 }}>
        {statusMessage ? (
          <div style={{ ...panelStyle, background: '#ECFDF5', color: '#166534' }}>
            {statusMessage}
          </div>
        ) : null}
        {errorMessage ? (
          <div style={{ ...panelStyle, background: '#FEF2F2', color: '#B91C1C' }}>
            {errorMessage}
          </div>
        ) : null}

        <section style={{ ...panelStyle, display: 'grid', gap: 16 }}>
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
              {STATUS_FILTERS.map((filter) => {
                const active = filter.value === statusFilter;
                return (
                  <button
                    key={filter.value}
                    type="button"
                    onClick={() => changeFilter(filter.value)}
                    style={{
                      ...(active ? buttonStyle : secondaryButtonStyle),
                      padding: '10px 14px',
                    }}
                  >
                    {filter.label}
                  </button>
                );
              })}
            </div>
            <button
              type="button"
              onClick={refreshFeed}
              disabled={refreshing}
              style={{ ...buttonStyle, opacity: refreshing ? 0.6 : 1 }}
            >
              {refreshing ? 'Rafraîchissement…' : 'Rafraîchir le flux'}
            </button>
          </div>

          {loading ? (
            <p style={mutedTextStyle}>Chargement des bourses…</p>
          ) : items.length === 0 ? (
            <p style={mutedTextStyle}>Aucune bourse à modérer</p>
          ) : (
            <div style={{ display: 'grid', gap: 12 }}>
              {items.map((entry) => renderEntry(entry))}
            </div>
          )}
        </section>
      </div>
    </DashboardShell>
  );
}
