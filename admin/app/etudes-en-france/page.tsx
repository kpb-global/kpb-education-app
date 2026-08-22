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
  /**
   * Mineur, majeur, ou inconnu — et le troisième n'est PAS « majeur ».
   *
   * Le serveur dérive ce champ de `birthDate` et ne rend jamais la date
   * elle-même : la personne qui décroche a besoin de savoir à qui elle parle,
   * pas de connaître l'âge exact. `unknown` est fréquent et signifiant — un
   * profil créé à la première connexion Supabase n'a pas de date de naissance,
   * seul l'onboarding la pose.
   */
  minority: 'minor' | 'adult' | 'unknown';
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
  const [withdrawingId, setWithdrawingId] = useState<string | null>(null);
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
   * Retire une déclaration, à la demande de l'étudiant.
   *
   * L'équipe recevait ces demandes par e-mail ou WhatsApp — le texte de
   * consentement les y invite — et n'avait aucun moyen de les exécuter : les
   * seules issues étaient de supprimer le compte ENTIER ou de faire du SQL à la
   * main en production. Un droit qu'on ne peut pas exercer n'existe pas.
   *
   * Confirmation demandée : la ligne est supprimée, pas archivée, et un clic
   * accidentel sur un tableau dense n'aurait aucun retour possible.
   */
  async function withdraw(row: InterestRow) {
    const name = row.user?.fullName ?? row.userId;
    // Substitution à la main : le `t()` de ce dépôt ne prend pas de paramètres,
    // et en ajouter un pour une seule chaîne serait un détour.
    if (!window.confirm(t('eef.withdrawConfirm').replace('{name}', name))) {
      return;
    }

    setWithdrawingId(row.id);
    setErrorMessage(null);
    try {
      await apiFetch(`/admin/etudes-en-france/interest/${row.id}`, {
        method: 'DELETE',
      });
      // On recharge plutôt que de retirer la ligne localement : les compteurs de
      // tête viennent du serveur, et les laisser périmés ferait douter de la
      // suppression qu'on vient d'exécuter.
      await load(skip);
    } catch (error) {
      setErrorMessage(
        error instanceof Error ? error.message : t('eef.withdrawError'),
      );
    } finally {
      setWithdrawingId(null);
    }
  }

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
              cols="0.7fr 1fr 1.3fr 0.8fr 0.9fr 0.6fr 0.6fr 0.6fr"
              columns={[
                t('eef.colDate'),
                t('eef.colName'),
                t('eef.colContact'),
                t('eef.colCountry'),
                t('eef.colLevels'),
                t('eef.colPremium'),
                t('eef.colMinor'),
                t('eef.colActions'),
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
                  {/*
                    La colonne « mineur », visible AVANT l'appel.
                    Sans elle, la personne qui décroche ne pouvait pas
                    distinguer un élève de terminale de 16 ans d'un doctorant de
                    30 ans. « inconnu » est en `warning` et non en `neutral` :
                    c'est une invitation à vérifier, pas une absence
                    d'information.
                  */}
                  <div>
                    {row.user?.minority === 'minor' ? (
                      <Badge variant="warning">{t('eef.minorYes')}</Badge>
                    ) : row.user?.minority === 'adult' ? (
                      <Badge variant="neutral">{t('eef.minorNo')}</Badge>
                    ) : (
                      <Badge variant="warning">{t('eef.minorUnknown')}</Badge>
                    )}
                  </div>
                  <div>
                    <button
                      type="button"
                      onClick={() => withdraw(row)}
                      disabled={withdrawingId === row.id}
                      className="text-xs text-red-600 underline disabled:opacity-50"
                    >
                      {t('eef.withdraw')}
                    </button>
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
