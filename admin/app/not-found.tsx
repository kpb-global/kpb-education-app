'use client';

import Link from 'next/link';

import { useLocale } from '../components/locale-provider';

export default function NotFound() {
  const { t } = useLocale();

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
        style={{
          maxWidth: 460,
          background: '#fff',
          borderRadius: 20,
          padding: 32,
          boxShadow: 'var(--shadow-sm)',
          textAlign: 'center',
        }}
      >
        <h1 style={{ marginTop: 0 }}>{t('errors.notFoundTitle')}</h1>
        <p style={{ color: '#475569', lineHeight: 1.6 }}>
          {t('errors.notFoundBody')}
        </p>
        <Link
          href="/"
          style={{
            display: 'inline-block',
            borderRadius: 14,
            padding: '12px 16px',
            background: 'var(--brand)',
            color: '#fff',
            fontWeight: 700,
          }}
        >
          {t('errors.backHome')}
        </Link>
      </div>
    </main>
  );
}
