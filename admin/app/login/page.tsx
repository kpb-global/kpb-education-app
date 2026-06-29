'use client';

import { useRouter } from 'next/navigation';
import { FormEvent, useEffect, useState } from 'react';

import { useAdminAuth } from '../../components/admin-auth-provider';
import { useLocale } from '../../components/locale-provider';
import { Alert, Button, Field, Input } from '../../components/ui';

export default function LoginPage() {
  const router = useRouter();
  const { isReady, login, session } = useAdminAuth();
  const { t } = useLocale();
  const [email, setEmail] = useState('');
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
          background: 'var(--surface)',
          borderRadius: 'var(--radius-lg)',
          padding: 32,
          boxShadow: 'var(--shadow-lg)',
        }}
      >
        <p style={{ marginTop: 0, color: 'var(--accent)', fontWeight: 700 }}>
          KPB Operations
        </p>
        <h1 style={{ marginTop: 0, marginBottom: 8 }}>{t('login.title')}</h1>
        <p style={{ color: 'var(--text-muted)', lineHeight: 1.6 }}>
          {t('login.subtitle')}
        </p>
        <form
          onSubmit={handleSubmit}
          style={{ display: 'grid', gap: 'var(--space-4)' }}
        >
          <Field label={t('login.emailLabel')}>
            {({ id }) => (
              <Input
                id={id}
                type="email"
                value={email}
                onChange={(event) => setEmail(event.target.value)}
                placeholder="fatou@kpb.education"
                autoComplete="email"
              />
            )}
          </Field>
          {error ? <Alert variant="danger">{error}</Alert> : null}
          <Button type="submit" loading={isSubmitting} block>
            {isSubmitting ? t('login.loading') : t('login.submit')}
          </Button>
        </form>
      </div>
    </main>
  );
}
