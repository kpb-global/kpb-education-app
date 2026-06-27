'use client';

import { useEffect, useState } from 'react';

import { useAdminAuth } from '../../components/admin-auth-provider';
import { DashboardShell } from '../../components/dashboard-shell';
import {
  Alert,
  Badge,
  BadgeVariant,
  Button,
  Card,
  ConfirmDialog,
  EmptyState,
} from '../../components/ui';
import { apiFetch } from '../../lib/api-client';
import { mutedTextStyle } from '../../lib/ui';

type ModerationStatus = 'pending' | 'approved' | 'rejected';

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

const STATUS_FILTERS: { value: ModerationStatus; label: string }[] = [
  { value: 'pending', label: 'En attente' },
  { value: 'approved', label: 'Approuvées' },
  { value: 'rejected', label: 'Rejetées' },
];

const STATUS_VARIANT: Record<ModerationStatus, BadgeVariant> = {
  pending: 'warning',
  approved: 'success',
  rejected: 'danger',
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
  const [rejecting, setRejecting] = useState<ScholarshipEntry | null>(null);
  const [statusMessage, setStatusMessage] = useState<string | null>(null);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

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
        action === 'approve' ? 'Bourse approuvée.' : 'Bourse rejetée.',
      );
      setRejecting(null);
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

  function renderActions(entry: ScholarshipEntry) {
    const isPending = pendingId === entry.id;
    return (
      <div style={{ display: 'flex', gap: 'var(--space-2)', flexWrap: 'wrap' }}>
        {entry.moderationStatus !== 'approved' ? (
          <Button
            size="sm"
            loading={isPending}
            onClick={() => moderate(entry, 'approve')}
          >
            Approuver
          </Button>
        ) : null}
        {entry.moderationStatus !== 'rejected' ? (
          <Button
            size="sm"
            variant="danger"
            disabled={isPending}
            onClick={() => setRejecting(entry)}
          >
            Rejeter
          </Button>
        ) : null}
      </div>
    );
  }

  function renderEntry(entry: ScholarshipEntry) {
    return (
      <div
        key={entry.id}
        style={{
          borderTop: '1px solid var(--border)',
          paddingTop: 'var(--space-3)',
          display: 'grid',
          gap: 'var(--space-2)',
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
          <Badge variant={STATUS_VARIANT[entry.moderationStatus]}>
            {statusLabels[entry.moderationStatus]}
          </Badge>
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
              <Badge key={tag} variant="neutral">
                {tag}
              </Badge>
            ))}
          </div>
        ) : null}
        {renderActions(entry)}
      </div>
    );
  }

  return (
    <DashboardShell title="Modération des bourses">
      <div style={{ display: 'grid', gap: 'var(--space-5)' }}>
        {statusMessage ? <Alert variant="success">{statusMessage}</Alert> : null}
        {errorMessage ? <Alert variant="danger">{errorMessage}</Alert> : null}

        <Card style={{ display: 'grid', gap: 'var(--space-4)' }}>
          <div
            style={{
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'space-between',
              gap: 12,
              flexWrap: 'wrap',
            }}
          >
            <div style={{ display: 'flex', gap: 'var(--space-2)', flexWrap: 'wrap' }}>
              {STATUS_FILTERS.map((filter) => (
                <Button
                  key={filter.value}
                  size="sm"
                  variant={filter.value === statusFilter ? 'primary' : 'secondary'}
                  onClick={() => changeFilter(filter.value)}
                >
                  {filter.label}
                </Button>
              ))}
            </div>
            <Button loading={refreshing} onClick={refreshFeed}>
              Rafraîchir le flux
            </Button>
          </div>

          {loading ? (
            <p style={mutedTextStyle}>Chargement des bourses…</p>
          ) : items.length === 0 ? (
            <EmptyState
              title="Aucune bourse à modérer"
              description="Aucune bourse ne correspond à ce filtre pour le moment."
            />
          ) : (
            <div style={{ display: 'grid', gap: 'var(--space-3)' }}>
              {items.map((entry) => renderEntry(entry))}
            </div>
          )}
        </Card>
      </div>

      <ConfirmDialog
        open={rejecting !== null}
        title="Rejeter cette bourse ?"
        description={
          rejecting
            ? `« ${rejecting.nameFr} » ne sera plus visible par les étudiants.`
            : undefined
        }
        confirmLabel="Rejeter"
        cancelLabel="Annuler"
        variant="danger"
        loading={rejecting !== null && pendingId === rejecting.id}
        onConfirm={() => {
          if (rejecting) void moderate(rejecting, 'reject');
        }}
        onCancel={() => setRejecting(null)}
      />
    </DashboardShell>
  );
}
