'use client';

import { useEffect } from 'react';

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
    // TODO: forward to error monitoring (e.g. Sentry) once configured.
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
          boxShadow: '0 12px 32px rgba(18,32,51,0.06)',
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
            background: '#004AAD',
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
