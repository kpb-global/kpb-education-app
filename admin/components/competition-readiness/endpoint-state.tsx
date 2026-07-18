import { useTranslations } from 'next-intl';

import { Button } from '../ui';
import styles from './readiness.module.css';

export function EndpointUnavailableState({
  endpoint,
  onRetry,
}: Readonly<{
  endpoint: string;
  onRetry?: () => void;
}>) {
  const t = useTranslations('competitionReadiness');

  return (
    <section className={styles.endpointState} aria-live="polite">
      <div>
        <h3 className={styles.panelTitle}>{t('endpointUnavailableTitle')}</h3>
        <p className={styles.panelSubtitle}>
          {t('endpointUnavailableDescription')}
        </p>
      </div>
      <code className={styles.endpointCode}>{endpoint}</code>
      {onRetry ? (
        <div>
          <Button variant="secondary" size="sm" onClick={onRetry}>
            {t('retry')}
          </Button>
        </div>
      ) : null}
    </section>
  );
}
