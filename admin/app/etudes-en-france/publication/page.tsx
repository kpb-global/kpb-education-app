'use client';

import { useCallback, useEffect, useState } from 'react';

import { useAdminAuth } from '../../../components/admin-auth-provider';
import { DashboardShell } from '../../../components/dashboard-shell';
import { useLocale } from '../../../components/locale-provider';
import {
  AdminTable,
  AdminTableRow,
  Alert,
  Badge,
  Button,
  CellText,
  ConfirmDialog,
  EmptyState,
} from '../../../components/ui';
import { AdminCapability, hasAdminCapability } from '../../../lib/admin-capabilities';
import { apiFetch } from '../../../lib/api-client';
import {
  applyBody,
  canApply,
  genericSourceCount,
  plannedCount,
  readableApiError,
  refusalMessageKey,
  simulationBody,
  type EefInstitutionRow,
  type EefPublicationOverview,
  type PublicationAction,
  type PublicationPlan,
  type RefusedProgram,
  type UnpublicationPlan,
} from '../../../lib/eef-publication';

const BASE = '/admin/etudes-en-france/publication/institutions';
/** Les refus détaillés à l'écran : le reste est compté, pas listé. */
const REFUSED_SHOWN = 15;

interface Selected {
  row: EefInstitutionRow;
  action: PublicationAction;
  plan: PublicationPlan | UnpublicationPlan;
}

/**
 * Publier, ou retirer, un établissement de l'import « Études en France ».
 *
 * Publier rend visibles, à un étudiant sans compte, des fiches que personne n'avait
 * relues : l'écran ne fait donc JAMAIS écrire d'un seul geste. Le clic sur
 * « Simuler » lit le plan du serveur ; l'écriture demande une confirmation qui
 * répète le nombre de formations, et le serveur refuse si ce nombre n'est plus
 * celui de la base. Le relecteur inscrit est le compte connecté — l'écran le dit
 * avant de demander confirmation.
 */
export default function EefPublicationPage() {
  const { session } = useAdminAuth();
  const { t, locale } = useLocale();
  const allowed = hasAdminCapability(
    session?.user.role,
    AdminCapability.PublishEefCatalog,
  );
  const reviewer = session?.user.fullName ?? session?.user.email ?? '';

  const [overview, setOverview] = useState<EefPublicationOverview | null>(null);
  const [loading, setLoading] = useState(true);
  const [busyId, setBusyId] = useState<string | null>(null);
  const [selected, setSelected] = useState<Selected | null>(null);
  const [confirming, setConfirming] = useState(false);
  const [writing, setWriting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      setOverview(await apiFetch<EefPublicationOverview>(BASE));
    } catch (failure) {
      setError(readableApiError(failure, t('eefPub.loadError')));
    } finally {
      setLoading(false);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  useEffect(() => {
    if (!session || !allowed) return;
    void load();
  }, [load, session, allowed]);

  async function simulate(row: EefInstitutionRow, action: PublicationAction) {
    setBusyId(row.id);
    setError(null);
    setNotice(null);
    setSelected(null);
    try {
      const response = await apiFetch<{
        plan: PublicationPlan | UnpublicationPlan;
      }>(`${BASE}/${encodeURIComponent(row.id)}/${action}`, {
        method: 'POST',
        body: simulationBody(),
      });
      setSelected({ row, action, plan: response.plan });
    } catch (failure) {
      setError(readableApiError(failure, t('eefPub.simulateError')));
    } finally {
      setBusyId(null);
    }
  }

  async function write() {
    if (!selected) return;
    setWriting(true);
    setError(null);
    try {
      await apiFetch(
        `${BASE}/${encodeURIComponent(selected.row.id)}/${selected.action}`,
        { method: 'POST', body: applyBody(selected.action, selected.plan) },
      );
      setNotice(
        (selected.action === 'publish'
          ? t('eefPub.publishedNotice')
          : t('eefPub.unpublishedNotice'))
          .replace('{n}', String(plannedCount(selected.action, selected.plan)))
          .replace('{name}', selected.row.name),
      );
      setSelected(null);
      await load();
    } catch (failure) {
      // 409 : la base a bougé depuis la simulation. Le plan affiché n'est plus
      // le bon ; on le retire plutôt que de laisser cliquer sur un chiffre périmé.
      setError(readableApiError(failure, t('eefPub.writeError')));
      setSelected(null);
      await load();
    } finally {
      setWriting(false);
      setConfirming(false);
    }
  }

  function formatDate(value: string | null) {
    if (!value) return '—';
    return new Intl.DateTimeFormat(locale === 'fr' ? 'fr-FR' : 'en-GB', {
      day: '2-digit',
      month: 'short',
      year: 'numeric',
    }).format(new Date(value));
  }

  if (!allowed) {
    return (
      <DashboardShell title={t('eefPub.title')} subtitle={t('eefPub.subtitle')}>
        <Alert variant="warning">{t('eefPub.forbidden')}</Alert>
      </DashboardShell>
    );
  }

  const refusedOf = (plan: PublicationPlan | UnpublicationPlan): RefusedProgram[] =>
    'programs' in plan ? plan.programs.refused : plan.refused;
  const institutionRefusals = (plan: PublicationPlan | UnpublicationPlan) =>
    'programs' in plan ? plan.institution.refusals : plan.refusals;

  const count = selected ? plannedCount(selected.action, selected.plan) : 0;
  const confirmTitle = selected
    ? (selected.action === 'publish'
        ? t('eefPub.confirmPublishTitle')
        : t('eefPub.confirmUnpublishTitle'))
        .replace('{n}', String(count))
        .replace('{name}', selected.row.name)
    : '';
  const confirmBody = selected
    ? selected.action === 'publish'
      ? t('eefPub.confirmPublishBody').replace('{reviewer}', reviewer)
      : t('eefPub.confirmUnpublishBody').replace(
          '{n}',
          String((selected.plan as UnpublicationPlan).savedByStudents),
        )
    : '';

  return (
    <DashboardShell title={t('eefPub.title')} subtitle={t('eefPub.subtitle')}>
      <div style={{ display: 'grid', gap: 14 }}>
        <Alert variant="info">{t('eefPub.publicWarning')}</Alert>
        {error ? <Alert variant="danger">{error}</Alert> : null}
        {notice ? <Alert variant="success">{notice}</Alert> : null}

        {overview ? (
          <div style={{ display: 'flex', gap: 12, flexWrap: 'wrap' }}>
            <Badge variant="neutral">
              {t('eefPub.totalInstitutions')}: {overview.totals.institutions}
            </Badge>
            <Badge variant="info">
              {t('eefPub.totalPublishedInstitutions')}:{' '}
              {overview.totals.institutionsPublished}
            </Badge>
            <Badge variant="warning">
              {t('eefPub.totalPending')}: {overview.totals.programsPending}
            </Badge>
            <Badge variant="success">
              {t('eefPub.totalPublished')}: {overview.totals.programsPublished}
            </Badge>
          </div>
        ) : null}

        {loading ? (
          <p style={{ margin: 0 }}>{t('eefPub.loading')}</p>
        ) : !overview || overview.institutions.length === 0 ? (
          <EmptyState
            title={t('eefPub.emptyTitle')}
            description={t('eefPub.emptyBody')}
          />
        ) : (
          <AdminTable
            cols="1.6fr 0.7fr 0.6fr 0.6fr 1fr 1.2fr"
            columns={[
              t('eefPub.colName'),
              t('eefPub.colStatus'),
              t('eefPub.colPending'),
              t('eefPub.colPublished'),
              t('eefPub.colReviewer'),
              t('eefPub.colActions'),
            ]}
          >
            {overview.institutions.map((row) => (
              <AdminTableRow key={row.id}>
                <CellText primary={row.name} sub={row.sourceUrl ?? t('eefPub.noSource')} />
                <div>
                  {row.isActive ? (
                    <Badge variant="success">{t('eefPub.statusPublished')}</Badge>
                  ) : (
                    <Badge variant="neutral">{t('eefPub.statusPending')}</Badge>
                  )}
                </div>
                <CellText primary={String(row.programsPending)} />
                <CellText primary={String(row.programsPublished)} />
                <CellText
                  primary={row.verifiedByName ?? '—'}
                  sub={formatDate(row.lastVerifiedAt)}
                />
                <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
                  <Button
                    size="sm"
                    variant="secondary"
                    disabled={busyId === row.id || row.programsPending === 0}
                    onClick={() => void simulate(row, 'publish')}
                  >
                    {t('eefPub.simulatePublish')}
                  </Button>
                  <Button
                    size="sm"
                    variant="dangerOutline"
                    disabled={busyId === row.id || row.programsPublished === 0}
                    onClick={() => void simulate(row, 'unpublish')}
                  >
                    {t('eefPub.simulateUnpublish')}
                  </Button>
                </div>
              </AdminTableRow>
            ))}
          </AdminTable>
        )}

        {selected ? (
          <section
            aria-label={t('eefPub.planTitle')}
            style={{ display: 'grid', gap: 10, border: '1px solid var(--border, #ddd)', borderRadius: 12, padding: 16 }}
          >
            <h2 style={{ margin: 0, fontSize: 16 }}>
              {(selected.action === 'publish'
                ? t('eefPub.planPublishTitle')
                : t('eefPub.planUnpublishTitle')
              ).replace('{name}', selected.row.name)}
            </h2>

            {institutionRefusals(selected.plan).map((code) => (
              <Alert key={code} variant="danger">
                {t(refusalMessageKey(code))}
              </Alert>
            ))}

            <p style={{ margin: 0 }}>
              <strong>{count}</strong>{' '}
              {selected.action === 'publish'
                ? t('eefPub.willPublish')
                : t('eefPub.willUnpublish')}
              {selected.action === 'publish' &&
              (selected.plan as PublicationPlan).institution.willActivate
                ? ` — ${t('eefPub.willActivate')}`
                : ''}
              {selected.action === 'unpublish' &&
              (selected.plan as UnpublicationPlan).deactivateInstitution
                ? ` — ${t('eefPub.willDeactivate')}`
                : ''}
            </p>

            {selected.action === 'unpublish' &&
            (selected.plan as UnpublicationPlan).savedByStudents > 0 ? (
              <Alert variant="warning">
                {t('eefPub.savedWarning').replace(
                  '{n}',
                  String((selected.plan as UnpublicationPlan).savedByStudents),
                )}
              </Alert>
            ) : null}

            {selected.action === 'publish' &&
            (selected.plan as PublicationPlan).nothingToDo ? (
              <Alert variant="warning">
                {t(
                  `eefPub.nothing.${(selected.plan as PublicationPlan).nothingToDo}`,
                )}
              </Alert>
            ) : null}

            {selected.action === 'publish' &&
            genericSourceCount(selected.plan as PublicationPlan) > 0 ? (
              <Alert variant="warning">
                {t('eefPub.genericSources')
                  .replace(
                    '{n}',
                    String(genericSourceCount(selected.plan as PublicationPlan)),
                  )
                  .replace(
                    '{portal}',
                    String(
                      (selected.plan as PublicationPlan).programs.genericSource
                        .ministryPortal,
                    ),
                  )
                  .replace(
                    '{dataset}',
                    String(
                      (selected.plan as PublicationPlan).programs.genericSource
                        .ministryDataset,
                    ),
                  )}
              </Alert>
            ) : null}

            {refusedOf(selected.plan).length > 0 ? (
              <div>
                <strong>
                  {t('eefPub.refusedTitle').replace(
                    '{n}',
                    String(refusedOf(selected.plan).length),
                  )}
                </strong>
                <ul style={{ margin: '6px 0 0', paddingLeft: 18 }}>
                  {refusedOf(selected.plan)
                    .slice(0, REFUSED_SHOWN)
                    .map((refused) => (
                      <li key={refused.id}>
                        {refused.nameFr ?? refused.id} —{' '}
                        {refused.reasons.map((code) => t(refusalMessageKey(code))).join(', ')}
                      </li>
                    ))}
                </ul>
                {refusedOf(selected.plan).length > REFUSED_SHOWN ? (
                  <p style={{ margin: '6px 0 0' }}>
                    {t('eefPub.refusedMore').replace(
                      '{n}',
                      String(refusedOf(selected.plan).length - REFUSED_SHOWN),
                    )}
                  </p>
                ) : null}
              </div>
            ) : null}

            <div style={{ display: 'flex', gap: 8 }}>
              <Button
                variant={selected.action === 'publish' ? 'primary' : 'danger'}
                disabled={!canApply(selected.action, selected.plan)}
                onClick={() => setConfirming(true)}
              >
                {(selected.action === 'publish'
                  ? t('eefPub.publishButton')
                  : t('eefPub.unpublishButton')
                ).replace('{n}', String(count))}
              </Button>
              <Button variant="secondary" onClick={() => setSelected(null)}>
                {t('eefPub.close')}
              </Button>
            </div>
          </section>
        ) : null}
      </div>

      <ConfirmDialog
        open={confirming && selected !== null}
        title={confirmTitle}
        description={confirmBody}
        confirmLabel={t('eefPub.confirm')}
        cancelLabel={t('eefPub.cancel')}
        variant={selected?.action === 'unpublish' ? 'danger' : 'primary'}
        loading={writing}
        onConfirm={() => void write()}
        onCancel={() => setConfirming(false)}
      />
    </DashboardShell>
  );
}
