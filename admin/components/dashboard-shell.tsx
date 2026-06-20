'use client';

import Link from 'next/link';
import { usePathname, useRouter } from 'next/navigation';
import { useEffect } from 'react';

import { useAdminAuth } from './admin-auth-provider';
import { useLocale } from './locale-provider';

const NAV_LINKS = [
  { href: '/', labelKey: 'nav.overview' },
  { href: '/cases', labelKey: 'nav.cases' },
  { href: '/content', labelKey: 'nav.content' },
  { href: '/verification', labelKey: 'nav.verification' },
  { href: '/scholarships', labelKey: 'nav.scholarshipsModeration' },
  { href: '/community', labelKey: 'nav.community' },
  { href: '/notifications', labelKey: 'nav.notifications' },
  { href: '/users', labelKey: 'nav.users' },
  { href: '/reports', labelKey: 'nav.reports' },
];

export function DashboardShell({
  title,
  children,
}: Readonly<{
  title: string;
  children: React.ReactNode;
}>) {
  const pathname = usePathname();
  const router = useRouter();
  const { isReady, logout, session } = useAdminAuth();
  const { locale, setLocale, t } = useLocale();

  useEffect(() => {
    if (isReady && !session) {
      router.replace('/login');
    }
  }, [isReady, router, session]);

  if (!isReady || !session) {
    return (
      <div
        style={{
          minHeight: '100vh',
          display: 'grid',
          placeItems: 'center',
          background: '#F4F7FB',
          color: '#334155',
        }}
      >
        {t('shell.loading')}
      </div>
    );
  }

  return (
    <div style={{ display: 'grid', gridTemplateColumns: 'minmax(220px, 260px) 1fr', minHeight: '100vh' }}>
      <aside
        style={{
          background: '#122033',
          color: '#fff',
          padding: '32px 20px',
        }}
      >
        <h1 style={{ marginTop: 0 }}>{t('app.title')}</h1>
        <p style={{ opacity: 0.8, lineHeight: 1.6 }}>{t('app.tagline')}</p>
        <div
          style={{
            marginTop: 18,
            padding: 14,
            borderRadius: 16,
            background: 'rgba(255,255,255,0.08)',
          }}
        >
          <strong style={{ display: 'block' }}>{session.user.fullName}</strong>
          <span style={{ fontSize: 13, opacity: 0.82 }}>
            {session.user.role} • {session.user.email}
          </span>
        </div>
        <nav style={{ display: 'grid', gap: 12, marginTop: 28 }}>
          {NAV_LINKS.map((link) => (
            <Link
              key={link.href}
              href={link.href}
              style={{
                padding: '12px 14px',
                borderRadius: 14,
                background:
                  pathname === link.href
                    ? 'rgba(255,255,255,0.16)'
                    : 'rgba(255,255,255,0.06)',
              }}
            >
              {t(link.labelKey)}
            </Link>
          ))}
        </nav>
        <div style={{ marginTop: 24, display: 'flex', gap: 8 }}>
          <button
            type="button"
            onClick={() => setLocale('fr')}
            style={{
              flex: 1,
              padding: '8px 10px',
              borderRadius: 10,
              border: 'none',
              background:
                locale === 'fr' ? '#F97316' : 'rgba(255,255,255,0.10)',
              color: '#fff',
              cursor: 'pointer',
              fontWeight: 600,
            }}
          >
            FR
          </button>
          <button
            type="button"
            onClick={() => setLocale('en')}
            style={{
              flex: 1,
              padding: '8px 10px',
              borderRadius: 10,
              border: 'none',
              background:
                locale === 'en' ? '#F97316' : 'rgba(255,255,255,0.10)',
              color: '#fff',
              cursor: 'pointer',
              fontWeight: 600,
            }}
          >
            EN
          </button>
        </div>
        <button
          onClick={() => {
            logout();
            router.replace('/login');
          }}
          style={{
            marginTop: 20,
            width: '100%',
            border: 'none',
            borderRadius: 14,
            padding: '12px 14px',
            background: '#F97316',
            color: '#fff',
            cursor: 'pointer',
            fontWeight: 600,
          }}
        >
          {t('shell.logout')}
        </button>
      </aside>
      <main style={{ padding: 28, background: '#F4F7FB' }}>
        <h2 style={{ marginTop: 0, marginBottom: 8 }}>{title}</h2>
        <p style={{ marginTop: 0, color: '#64748b' }}>{t('shell.description')}</p>
        {children}
      </main>
    </div>
  );
}
