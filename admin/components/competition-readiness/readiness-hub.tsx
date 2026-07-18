'use client';

import { useTranslations } from 'next-intl';
import { useRouter, useSearchParams } from 'next/navigation';
import { useCallback, useEffect } from 'react';

import { useAdminAuth } from '../admin-auth-provider';
import { DashboardShell } from '../dashboard-shell';
import { Alert, EmptyState } from '../ui';
import {
  getVisibleCompetitionReadinessTabs,
  resolveCompetitionReadinessTab,
  type CompetitionReadinessTab,
} from '../../lib/competition-readiness-tabs';
import { AiOperationsPanel } from './ai-operations-panel';
import { ImpactPilotsPanel } from './impact-pilots-panel';
import { ImpactReportingPanel } from './impact-reporting-panel';
import { OutcomeVerificationPanel } from './outcome-verification-panel';
import { PartnerAgreementsPanel } from './partner-agreements-panel';
import { ReadinessTabs } from './readiness-tabs';
import { ReviewRequestQueue } from './review-request-queue';
import styles from './readiness.module.css';

export function CompetitionReadinessHub() {
  const t = useTranslations('competitionReadiness');
  const { session } = useAdminAuth();
  const router = useRouter();
  const searchParams = useSearchParams();
  const role = session?.user.role;
  const visibleTabs = getVisibleCompetitionReadinessTabs(role);
  const requestedTab = searchParams.get('tab');
  const activeTab = resolveCompetitionReadinessTab(role, requestedTab);

  const replaceParams = useCallback(
    (changes: Readonly<Record<string, string | null>>) => {
      const next = new URLSearchParams(searchParams.toString());
      for (const [key, value] of Object.entries(changes)) {
        if (value === null || value === '') next.delete(key);
        else next.set(key, value);
      }
      const query = next.toString();
      router.replace(query ? `/competition-readiness?${query}` : '/competition-readiness');
    },
    [router, searchParams],
  );

  useEffect(() => {
    if (!session || !activeTab || requestedTab === activeTab) return;
    replaceParams({ tab: activeTab, selectedRequestId: null });
  }, [activeTab, replaceParams, requestedTab, session]);

  function selectTab(tab: CompetitionReadinessTab) {
    replaceParams({
      tab,
      selectedRequestId: null,
      selectedOutcomeType: null,
      selectedOutcomeId: null,
      selectedAgreementId: null,
      selectedPilotId: null,
    });
  }

  return (
    <DashboardShell title={t('title')} subtitle={t('subtitle')}>
      <div className={styles.hub}>
        {!session ? null : activeTab ? (
          <>
            <ReadinessTabs
              activeTab={activeTab}
              tabs={visibleTabs}
              onChange={selectTab}
            />
            <p className={styles.authorityNote}>{t('backendAuthority')}</p>
            {activeTab === 'requests' ? (
              <ReviewRequestQueue
                role={role}
                selectedRequestId={searchParams.get('selectedRequestId')}
                onSelectRequest={(id) =>
                  replaceParams({ selectedRequestId: id })
                }
              />
            ) : null}
            {activeTab === 'outcomes' ? (
              <OutcomeVerificationPanel
                role={role}
                selectedType={searchParams.get('selectedOutcomeType')}
                selectedId={searchParams.get('selectedOutcomeId')}
                onSelectOutcome={(type, id) =>
                  replaceParams({
                    selectedOutcomeType: type,
                    selectedOutcomeId: id,
                  })
                }
              />
            ) : null}
            {activeTab === 'partners' ? (
              <PartnerAgreementsPanel
                role={role}
                selectedAgreementId={searchParams.get('selectedAgreementId')}
                onSelectAgreement={(id) =>
                  replaceParams({ selectedAgreementId: id })
                }
              />
            ) : null}
            {activeTab === 'pilots' ? (
              <ImpactPilotsPanel
                role={role}
                selectedPilotId={searchParams.get('selectedPilotId')}
                onSelectPilot={(id) => replaceParams({ selectedPilotId: id })}
              />
            ) : null}
            {activeTab === 'impact' ? (
              <ImpactReportingPanel role={role} />
            ) : null}
            {activeTab === 'ai' ? <AiOperationsPanel role={role} /> : null}
          </>
        ) : (
          <Alert variant="warning">
            <EmptyState
              title={t('accessDeniedTitle')}
              description={t('accessDeniedDescription')}
            />
          </Alert>
        )}
      </div>
    </DashboardShell>
  );
}
