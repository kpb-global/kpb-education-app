import { useTranslations } from 'next-intl';

import type { CompetitionReadinessTab } from '../../lib/competition-readiness-tabs';
import styles from './readiness.module.css';

export function ReadinessTabs({
  activeTab,
  tabs,
  onChange,
}: Readonly<{
  activeTab: CompetitionReadinessTab;
  tabs: readonly CompetitionReadinessTab[];
  onChange: (tab: CompetitionReadinessTab) => void;
}>) {
  const t = useTranslations('competitionReadiness');

  return (
    <div className={styles.tabs} role="tablist" aria-label={t('tabsLabel')}>
      {tabs.map((tab) => (
        <button
          key={tab}
          type="button"
          role="tab"
          aria-selected={activeTab === tab}
          className={`${styles.tab} ${
            activeTab === tab ? styles.tabActive : ''
          }`}
          onClick={() => onChange(tab)}
        >
          {t(`tab_${tab}`)}
        </button>
      ))}
    </div>
  );
}
