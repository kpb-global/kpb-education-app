'use client';

import { useRouter } from 'next/navigation';
import { FormEvent, useEffect, useState } from 'react';

import { useAdminAuth } from '../../components/admin-auth-provider';
import { useLocale } from '../../components/locale-provider';

export default function LoginPage() {
  const router = useRouter();
  const { isReady, login, session } = useAdminAuth();
  const { t } = useLocale();
  const [email, setEmail] = useState('fatou@kpb.education');
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
      await login(email);
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
          'linear-gradient(145deg, #0F172A 0%, #122033 45%, #E2E8F0 160%)',
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
          boxShadow: '0 24px 60px rgba(15,23,42,0.28)',
        }}
      >
        <p style={{ marginTop: 0, color: '#F97316', fontWeight: 700 }}>
          KPB Operations
        </p>
        <h1 style={{ marginTop: 0, marginBottom: 8 }}>{t('login.title')}</h1>
        <p style={{ color: '#64748B', lineHeight: 1.6 }}>{t('login.subtitle')}</p>
        <form onSubmit={handleSubmit} style={{ display: 'grid', gap: 14 }}>
          <label style={{ display: 'grid', gap: 8 }}>
            <span style={{ fontWeight: 600 }}>{t('login.emailLabel')}</span>
            <input
              type="email"
              value={email}
              onChange={(event) => setEmail(event.target.value)}
              placeholder="fatou@kpb.education"
              style={{
                border: '1px solid #CBD5E1',
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
                background: '#FEF2F2',
                color: '#B91C1C',
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
              background: '#122033',
              color: '#fff',
              fontWeight: 700,
              cursor: isSubmitting ? 'wait' : 'pointer',
            }}
          >
            {isSubmitting ? t('login.loading') : t('login.submit')}
          </button>
        </form>
        <p style={{ marginBottom: 0, marginTop: 18, color: '#64748B' }}>
          Demo accounts already seeded in the backend include
          `fatou@kpb.education`, `amina@kpb.education`, and
          `moussa@kpb.education`.
        </p>
      </div>
    </main>
  );
}
