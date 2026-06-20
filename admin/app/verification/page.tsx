'use client';

import { useEffect, useState } from 'react';

import { useAdminAuth } from '../../components/admin-auth-provider';
import { DashboardShell } from '../../components/dashboard-shell';
import { apiFetch } from '../../lib/api-client';
import {
  badgeStyle,
  buttonStyle,
  inputStyle,
  mutedTextStyle,
  panelStyle,
} from '../../lib/ui';

interface CatalogEntry {
  id: string;
  name: { fr: string; en: string };
  lastVerifiedAt: string | null;
  sourceUrl: string | null;
}

interface ProgramsResponse {
  items: CatalogEntry[];
  total: number;
}

type Entity = 'country' | 'program';

const verifiedBadgeStyle = {
  ...badgeStyle,
  background: '#ECFDF5',
  color: '#166534',
};

const pendingBadgeStyle = {
  ...badgeStyle,
  background: '#FEF3C7',
  color: '#92400E',
};

const resetButtonStyle = {
  ...buttonStyle,
  background: '#E2E8F0',
  color: '#122033',
};

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
  const [loading, setLoading] = useState(true);
  const [statusMessage, setStatusMessage] = useState<string | null>(null);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  async function loadCatalog() {
    setLoading(true);
    setErrorMessage(null);
    try {
      const [countriesResponse, programsResponse] = await Promise.all([
        apiFetch<CatalogEntry[]>('/catalog/countries'),
        apiFetch<ProgramsResponse>('/catalog/programs?limit=1000'),
      ]);
      setCountries(countriesResponse);
      setPrograms(programsResponse.items);
      const initialSources: Record<string, string> = {};
      for (const country of countriesResponse) {
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
          <strong>{entry.name.fr}</strong>
          <span style={verified ? verifiedBadgeStyle : pendingBadgeStyle}>
            {verified
              ? `Vérifié le ${formatVerifiedDate(entry.lastVerifiedAt as string)}`
              : 'À confirmer'}
          </span>
        </div>
        <input
          value={sourceInputs[key] ?? ''}
          onChange={(event) =>
            setSourceInputs((current) => ({
              ...current,
              [key]: event.target.value,
            }))
          }
          placeholder="https://source-officielle.example"
          style={inputStyle}
        />
        <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
          <button
            type="button"
            onClick={() => verifyEntry(entity, entry, true)}
            disabled={isPending}
            style={{ ...buttonStyle, opacity: isPending ? 0.6 : 1 }}
          >
            Marquer vérifié
          </button>
          <button
            type="button"
            onClick={() => verifyEntry(entity, entry, false)}
            disabled={isPending}
            style={{ ...resetButtonStyle, opacity: isPending ? 0.6 : 1 }}
          >
            Réinitialiser
          </button>
        </div>
      </div>
    );
  }

  return (
    <DashboardShell title="Vérification catalogue">
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

        {loading ? (
          <div style={panelStyle}>Chargement du catalogue…</div>
        ) : (
          <>
            <section style={{ ...panelStyle, display: 'grid', gap: 16 }}>
              <div>
                <h3 style={{ marginTop: 0 }}>Pays</h3>
                <p style={mutedTextStyle}>
                  Confirmez les pays du catalogue et renseignez la source
                  officielle pour le signal de confiance.
                </p>
              </div>
              <div style={{ display: 'grid', gap: 12 }}>
                {countries.length === 0 ? (
                  <p style={mutedTextStyle}>Aucun pays à vérifier.</p>
                ) : (
                  countries.map((country) => renderEntry('country', country))
                )}
              </div>
            </section>

            <section style={{ ...panelStyle, display: 'grid', gap: 16 }}>
              <div>
                <h3 style={{ marginTop: 0 }}>Formations</h3>
                <p style={mutedTextStyle}>
                  Confirmez les formations du catalogue et renseignez la source
                  officielle pour le signal de confiance.
                </p>
              </div>
              <div style={{ display: 'grid', gap: 12 }}>
                {programs.length === 0 ? (
                  <p style={mutedTextStyle}>Aucune formation à vérifier.</p>
                ) : (
                  programs.map((program) => renderEntry('program', program))
                )}
              </div>
            </section>
          </>
        )}
      </div>
    </DashboardShell>
  );
}
