'use client';

import { useTranslations } from 'next-intl';

import { DashboardShell } from '../../components/dashboard-shell';
import { Alert, Button } from '../../components/ui';

export default function CompetitionReadinessError({
  reset,
}: Readonly<{
  error: Error & { digest?: string };
  reset: () => void;
}>) {
  const t = useTranslations('competitionReadiness');

  return (
    <DashboardShell title={t('title')} subtitle={t('subtitle')}>
      <Alert variant="danger">
        <p>{t('unexpectedError')}</p>
        <Button variant="secondary" size="sm" onClick={reset}>
          {t('retry')}
        </Button>
      </Alert>
    </DashboardShell>
  );
}
