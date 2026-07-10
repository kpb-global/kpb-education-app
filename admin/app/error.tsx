'use client';

import { useEffect } from 'react';

import { reportError } from '../lib/error-reporting';
import { useLocale } from '../components/locale-provider';

export default function Error({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  const { t } = useLocale();

  useEffect(() => {
    // Forwarded to Sentry when NEXT_PUBLIC_SENTRY_DSN is set; no-op otherwise.
    reportError(error);
    console.error(error);
  }, [error]);

  return (
    <main
      style={{
        minHeight: '100vh',
        display: 'grid',
        placeItems: 'center',
        padding: 24,
        background: '#F4F7FB',
      }}
    >
      <div
        role="alert"
        style={{
          maxWidth: 460,
          background: '#fff',
          borderRadius: 20,
          padding: 32,
          boxShadow: 'var(--shadow-sm)',
          textAlign: 'center',
        }}
      >
        <h1 style={{ marginTop: 0 }}>{t('errors.title')}</h1>
        <p style={{ color: '#475569', lineHeight: 1.6 }}>{t('errors.body')}</p>
        <button
          type="button"
          onClick={reset}
          style={{
            border: 'none',
            borderRadius: 14,
            padding: '12px 16px',
            background: 'var(--brand)',
            color: '#fff',
            fontWeight: 700,
            cursor: 'pointer',
          }}
        >
          {t('errors.retry')}
        </button>
      </div>
    </main>
  );
}
