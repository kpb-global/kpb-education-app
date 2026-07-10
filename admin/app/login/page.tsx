'use client';

import { useRouter } from 'next/navigation';
import { FormEvent, useEffect, useState } from 'react';

import { useAdminAuth } from '../../components/admin-auth-provider';
import { useLocale } from '../../components/locale-provider';

export default function LoginPage() {
  const router = useRouter();
  const { isReady, login, session } = useAdminAuth();
  const { t } = useLocale();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [isSubmitting, setIsSubmitting] = useState(false);

  useEffect(() => {
    if (isReady && session) {
      router.replace('/');
    }
  }, [isReady, router, session]);

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError(null);
    setIsSubmitting(true);

    try {
      await login(email, password);
      router.replace('/');
    } catch (submissionError) {
      setError(
        submissionError instanceof Error
          ? submissionError.message
          : t('login.error'),
      );
    } finally {
      setIsSubmitting(false);
    }
  }

  return (
    <main
      style={{
        minHeight: '100vh',
        display: 'grid',
        placeItems: 'center',
        background:
          'linear-gradient(145deg, var(--ink) 0%, #1e293b 45%, var(--border) 160%)',
        padding: 24,
      }}
    >
      <div
        style={{
          width: '100%',
          maxWidth: 460,
          background: '#fff',
          borderRadius: 28,
          padding: 32,
          boxShadow: 'var(--shadow-lg)',
        }}
      >
        <p
          style={{
            marginTop: 0,
            color: 'var(--brand)',
            fontWeight: 800,
            fontSize: 12,
            letterSpacing: '0.06em',
            textTransform: 'uppercase',
          }}
        >
          {t('login.eyebrow')}
        </p>
        <h1 style={{ marginTop: 0, marginBottom: 8 }}>{t('login.title')}</h1>
        <p style={{ color: 'var(--text-muted)', lineHeight: 1.6 }}>{t('login.subtitle')}</p>
        <form onSubmit={handleSubmit} style={{ display: 'grid', gap: 14 }}>
          <label style={{ display: 'grid', gap: 8 }}>
            <span style={{ fontWeight: 600 }}>{t('login.emailLabel')}</span>
            <input
              type="email"
              value={email}
              onChange={(event) => setEmail(event.target.value)}
              placeholder="you@karatoupostbac.com"
              style={{
                border: '1px solid var(--border)',
                borderRadius: 14,
                padding: '13px 14px',
                fontSize: 15,
              }}
            />
          </label>
          <label style={{ display: 'grid', gap: 8 }}>
            <span style={{ fontWeight: 600 }}>{t('login.passwordLabel')}</span>
            <input
              type="password"
              value={password}
              onChange={(event) => setPassword(event.target.value)}
              placeholder="••••••••"
              style={{
                border: '1px solid var(--border)',
                borderRadius: 14,
                padding: '13px 14px',
                fontSize: 15,
              }}
            />
          </label>
          {error ? (
            <div
              style={{
                borderRadius: 14,
                background: 'var(--danger-bg)',
                color: 'var(--danger-fg)',
                padding: '12px 14px',
              }}
            >
              {error}
            </div>
          ) : null}
          <button
            type="submit"
            disabled={isSubmitting}
            style={{
              border: 'none',
              borderRadius: 14,
              padding: '14px 16px',
              background: 'var(--brand)',
              color: '#fff',
              fontWeight: 700,
              cursor: isSubmitting ? 'wait' : 'pointer',
            }}
          >
            {isSubmitting ? t('login.loading') : t('login.submit')}
          </button>
        </form>
      </div>
    </main>
  );
}
