'use client';

import { useEffect, useState } from 'react';

import { useAdminAuth } from '../../components/admin-auth-provider';
import { DashboardShell } from '../../components/dashboard-shell';
import {
  Alert,
  Badge,
  Button,
  Card,
  ConfirmDialog,
  Field,
  Input,
} from '../../components/ui';
import { apiFetch } from '../../lib/api-client';
import { mutedTextStyle } from '../../lib/ui';

interface CatalogEntry {
  id: string;
  name: { fr: string; en: string };
  lastVerifiedAt: string | null;
  sourceUrl: string | null;
}

interface CatalogResponse {
  items: CatalogEntry[];
  total: number;
}

type Entity = 'country' | 'program';

function formatVerifiedDate(iso: string): string {
  const date = new Date(iso);
  const day = String(date.getDate()).padStart(2, '0');
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const year = date.getFullYear();
  return `${day}/${month}/${year}`;
}

export default function VerificationPage() {
  const { session } = useAdminAuth();
  const [countries, setCountries] = useState<CatalogEntry[]>([]);
  const [programs, setPrograms] = useState<CatalogEntry[]>([]);
  const [sourceInputs, setSourceInputs] = useState<Record<string, string>>({});
  const [pendingKey, setPendingKey] = useState<string | null>(null);
  const [resetting, setResetting] = useState<{
    entity: Entity;
    entry: CatalogEntry;
  } | null>(null);
  const [loading, setLoading] = useState(true);
  const [statusMessage, setStatusMessage] = useState<string | null>(null);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  async function loadCatalog() {
    setLoading(true);
    setErrorMessage(null);
    try {
      const [countriesResponse, programsResponse] = await Promise.all([
        apiFetch<CatalogResponse>('/catalog/countries'),
        apiFetch<CatalogResponse>('/catalog/programs?limit=1000'),
      ]);
      setCountries(countriesResponse.items);
      setPrograms(programsResponse.items);
      const initialSources: Record<string, string> = {};
      for (const country of countriesResponse.items) {
        initialSources[`country:${country.id}`] = country.sourceUrl ?? '';
      }
      for (const program of programsResponse.items) {
        initialSources[`program:${program.id}`] = program.sourceUrl ?? '';
      }
      setSourceInputs(initialSources);
    } catch (error) {
      setErrorMessage(
        error instanceof Error ? error.message : 'Unable to load catalog.',
      );
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    if (!session) {
      return;
    }
    void loadCatalog();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [session]);

  async function verifyEntry(
    entity: Entity,
    entry: CatalogEntry,
    verified: boolean,
  ) {
    const key = `${entity}:${entry.id}`;
    setPendingKey(key);
    setStatusMessage(null);
    setErrorMessage(null);

    const sourceUrl = (sourceInputs[key] ?? '').trim();

    try {
      const updated = await apiFetch<CatalogEntry>('/admin/catalog/verify', {
        method: 'POST',
        body: {
          entity,
          id: entry.id,
          verified,
          sourceUrl: verified && sourceUrl ? sourceUrl : undefined,
        },
      });

      const applyUpdate = (current: CatalogEntry[]) =>
        current.map((item) =>
          item.id === entry.id
            ? {
                ...item,
                lastVerifiedAt: updated?.lastVerifiedAt ?? null,
                sourceUrl: updated?.sourceUrl ?? null,
              }
            : item,
        );

      if (entity === 'country') {
        setCountries(applyUpdate);
      } else {
        setPrograms(applyUpdate);
      }

      setSourceInputs((current) => ({
        ...current,
        [key]: updated?.sourceUrl ?? '',
      }));

      setStatusMessage(
        verified
          ? 'Entrée marquée comme vérifiée.'
          : 'Vérification réinitialisée.',
      );
      if (!verified) {
        setResetting(null);
      }
    } catch (error) {
      setErrorMessage(
        error instanceof Error
          ? error.message
          : 'Unable to update verification.',
      );
    } finally {
      setPendingKey(null);
    }
  }

  function renderEntry(entity: Entity, entry: CatalogEntry) {
    const key = `${entity}:${entry.id}`;
    const isPending = pendingKey === key;
    const verified = Boolean(entry.lastVerifiedAt);

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
          <strong>{entry.name.fr}</strong>
          <Badge variant={verified ? 'success' : 'warning'}>
            {verified
              ? `Vérifié le ${formatVerifiedDate(entry.lastVerifiedAt as string)}`
              : 'À confirmer'}
          </Badge>
        </div>
        <Field label="Source officielle">
          {({ id }) => (
            <Input
              id={id}
              value={sourceInputs[key] ?? ''}
              onChange={(event) =>
                setSourceInputs((current) => ({
                  ...current,
                  [key]: event.target.value,
                }))
              }
              placeholder="https://source-officielle.example"
              inputMode="url"
            />
          )}
        </Field>
        <div style={{ display: 'flex', gap: 'var(--space-2)', flexWrap: 'wrap' }}>
          <Button
            size="sm"
            loading={isPending}
            onClick={() => verifyEntry(entity, entry, true)}
          >
            Marquer vérifié
          </Button>
          {verified ? (
            <Button
              size="sm"
              variant="secondary"
              disabled={isPending}
              onClick={() => setResetting({ entity, entry })}
            >
              Réinitialiser
            </Button>
          ) : null}
        </div>
      </div>
    );
  }

  return (
    <DashboardShell title="Vérification catalogue">
      <div style={{ display: 'grid', gap: 'var(--space-5)' }}>
        {statusMessage ? <Alert variant="success">{statusMessage}</Alert> : null}
        {errorMessage ? <Alert variant="danger">{errorMessage}</Alert> : null}

        {loading ? (
          <Card>Chargement du catalogue…</Card>
        ) : (
          <>
            <Card style={{ display: 'grid', gap: 'var(--space-4)' }}>
              <div>
                <h3 style={{ marginTop: 0 }}>Pays</h3>
                <p style={mutedTextStyle}>
                  Confirmez les pays du catalogue et renseignez la source
                  officielle pour le signal de confiance.
                </p>
              </div>
              <div style={{ display: 'grid', gap: 'var(--space-3)' }}>
                {countries.length === 0 ? (
                  <p style={mutedTextStyle}>Aucun pays à vérifier.</p>
                ) : (
                  countries.map((country) => renderEntry('country', country))
                )}
              </div>
            </Card>

            <Card style={{ display: 'grid', gap: 'var(--space-4)' }}>
              <div>
                <h3 style={{ marginTop: 0 }}>Formations</h3>
                <p style={mutedTextStyle}>
                  Confirmez les formations du catalogue et renseignez la source
                  officielle pour le signal de confiance.
                </p>
              </div>
              <div style={{ display: 'grid', gap: 'var(--space-3)' }}>
                {programs.length === 0 ? (
                  <p style={mutedTextStyle}>Aucune formation à vérifier.</p>
                ) : (
                  programs.map((program) => renderEntry('program', program))
                )}
              </div>
            </Card>
          </>
        )}
      </div>

      <ConfirmDialog
        open={resetting !== null}
        title="Réinitialiser la vérification ?"
        description={
          resetting
            ? `Le signal de confiance de « ${resetting.entry.name.fr} » (date et source) sera effacé.`
            : undefined
        }
        confirmLabel="Réinitialiser"
        cancelLabel="Annuler"
        variant="danger"
        loading={
          resetting !== null &&
          pendingKey === `${resetting.entity}:${resetting.entry.id}`
        }
        onConfirm={() => {
          if (resetting) void verifyEntry(resetting.entity, resetting.entry, false);
        }}
        onCancel={() => setResetting(null)}
      />
    </DashboardShell>
  );
}
