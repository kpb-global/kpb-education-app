'use client';

import { useCallback, useEffect, useState } from 'react';

import { useAdminAuth } from '../../components/admin-auth-provider';
import { DashboardShell } from '../../components/dashboard-shell';
import { useLocale } from '../../components/locale-provider';
import { apiFetch, apiFetchText } from '../../lib/api-client';
import {
  AdminTable,
  AdminTableRow,
  Alert,
  Badge,
  Button,
  CellText,
  EmptyState,
} from '../../components/ui';

interface InterestUser {
  fullName: string;
  email: string;
  phone: string;
  whatsApp: string | null;
  countryOfResidence: string;
}

interface InterestRow {
  id: string;
  userId: string;
  currentLevel: string | null;
  targetLevel: string | null;
  fieldIds: string[];
  wantsPremium: boolean;
  consentedAt: string;
  createdAt: string;
  user: InterestUser | null;
}

interface Summary {
  total: number;
  wantsPremium: number;
}

const PAGE_SIZE = 50;

/**
 * La liste d'intérêt « Études en France ».
 *
 * Elle existe pour la raison écrite dans le plan : sans sortie exploitable, la
 * liste ne quitte jamais Postgres et personne ne rappelle personne. La vitrine
 * pose UNE question — « est-ce que ça t'intéresse, et le payant aussi ? » — et
 * c'est cet écran qui rend la réponse actionnable.
 */
export default function EtudesEnFrancePage() {
  const { session } = useAdminAuth();
  const { t, locale } = useLocale();
  const [rows, setRows] = useState<InterestRow[]>([]);
  const [summary, setSummary] = useState<Summary | null>(null);
  const [skip, setSkip] = useState(0);
  const [loading, setLoading] = useState(true);
  const [exporting, setExporting] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  function formatDate(value: string) {
    return new Intl.DateTimeFormat(locale === 'fr' ? 'fr-FR' : 'en-GB', {
      day: '2-digit',
      month: 'short',
      year: 'numeric',
    }).format(new Date(value));
  }

  const load = useCallback(async (offset: number) => {
    setLoading(true);
    setErrorMessage(null);
    try {
      const [list, counts] = await Promise.all([
        apiFetch<{ items: InterestRow[] }>(
          `/admin/etudes-en-france/interest?take=${PAGE_SIZE}&skip=${offset}`,
        ),
        apiFetch<Summary>('/admin/etudes-en-france/interest/summary'),
      ]);
      setRows(list.items ?? []);
      setSummary(counts);
    } catch (error) {
      setErrorMessage(
        error instanceof Error ? error.message : t('eef.loadError'),
      );
    } finally {
      setLoading(false);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  useEffect(() => {
    if (!session) return;
    void load(skip);
  }, [load, session, skip]);

  /**
   * Télécharge le CSV.
   *
   * Le fichier passe par `apiFetchText` et non par un `<a href>` : la session
   * admin vit dans un cookie httpOnly, donc un lien nu fonctionnerait — mais un
   * 401 produirait un fichier `eef-interest.csv` contenant « Unauthorized »,
   * que quelqu'un ouvrirait dans Excel en concluant que personne ne s'est
   * déclaré. Ici l'échec s'affiche.
   */
  async function downloadCsv() {
    setExporting(true);
    setErrorMessage(null);
    try {
      const csv = await apiFetchText(
        '/admin/etudes-en-france/interest/export.csv',
      );
      const blob = new Blob([csv], { type: 'text/csv;charset=utf-8' });
      const url = URL.createObjectURL(blob);
      const link = document.createElement('a');
      link.href = url;
      link.download = 'eef-interest.csv';
      link.click();
      URL.revokeObjectURL(url);
    } catch (error) {
      setErrorMessage(
        error instanceof Error ? error.message : t('eef.exportError'),
      );
    } finally {
      setExporting(false);
    }
  }

  const premiumShare =
    summary && summary.total > 0
      ? Math.round((summary.wantsPremium / summary.total) * 100)
      : 0;

  return (
    <DashboardShell title={t('eef.title')} subtitle={t('eef.subtitle')}>
      <div style={{ display: 'grid', gap: 14 }}>
        {errorMessage ? <Alert variant="danger">{errorMessage}</Alert> : null}

        <div
          style={{
            display: 'flex',
            gap: 12,
            alignItems: 'center',
            flexWrap: 'wrap',
          }}
        >
          <Badge variant="neutral">
            {t('eef.total')}: {summary?.total ?? '—'}
          </Badge>
          <Badge variant="info">
            {t('eef.wantsPremium')}: {summary?.wantsPremium ?? '—'}
            {summary && summary.total > 0 ? ` (${premiumShare} %)` : ''}
          </Badge>
          <Button
            onClick={downloadCsv}
            disabled={exporting || (summary?.total ?? 0) === 0}
          >
            {exporting ? t('eef.exporting') : t('eef.export')}
          </Button>
        </div>

        {loading ? (
          <p style={{ margin: 0 }}>{t('eef.loading')}</p>
        ) : rows.length === 0 ? (
          // Une liste vide est un FAIT, pas une panne : la vitrine vient peut-
          // être d'être allumée. L'écran le dit ainsi.
          <EmptyState
            title={t('eef.emptyTitle')}
            description={t('eef.emptyBody')}
          />
        ) : (
          <>
            <AdminTable
              cols="0.7fr 1fr 1.4fr 0.8fr 1fr 0.6fr"
              columns={[
                t('eef.colDate'),
                t('eef.colName'),
                t('eef.colContact'),
                t('eef.colCountry'),
                t('eef.colLevels'),
                t('eef.colPremium'),
              ]}
            >
              {rows.map((row) => (
                <AdminTableRow key={row.id}>
                  <CellText primary={formatDate(row.createdAt)} />
                  <CellText primary={row.user?.fullName ?? '—'} />
                  <CellText
                    primary={row.user?.email ?? '—'}
                    sub={row.user?.whatsApp ?? row.user?.phone ?? undefined}
                  />
                  <CellText primary={row.user?.countryOfResidence ?? '—'} />
                  <CellText
                    primary={
                      [row.currentLevel, row.targetLevel]
                        .filter(Boolean)
                        .join(' → ') || '—'
                    }
                  />
                  <div>
                    {row.wantsPremium ? (
                      <Badge variant="success">{t('eef.yes')}</Badge>
                    ) : (
                      <Badge variant="neutral">{t('eef.no')}</Badge>
                    )}
                  </div>
                </AdminTableRow>
              ))}
            </AdminTable>

            <div style={{ display: 'flex', gap: 8 }}>
              <Button
                variant="secondary"
                disabled={skip === 0}
                onClick={() => setSkip(Math.max(0, skip - PAGE_SIZE))}
              >
                {t('eef.previous')}
              </Button>
              <Button
                variant="secondary"
                disabled={rows.length < PAGE_SIZE}
                onClick={() => setSkip(skip + PAGE_SIZE)}
              >
                {t('eef.next')}
              </Button>
            </div>
          </>
        )}
      </div>
    </DashboardShell>
  );
}
