'use client';

import { useEffect } from 'react';

import { reportError } from '../lib/error-reporting';

// global-error replaces the root layout entirely (it renders its own <html>/<body>)
// and therefore sits OUTSIDE the i18n + auth providers — so copy here is intentionally
// static English. This is the last-resort boundary for a crash in the root layout itself.
export default function GlobalError({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  useEffect(() => {
    // Forwarded to Sentry when NEXT_PUBLIC_SENTRY_DSN is set; no-op otherwise.
    reportError(error);
    console.error(error);
  }, [error]);

  return (
    <html lang="en">
      <body
        style={{
          margin: 0,
          fontFamily:
            'ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif',
          minHeight: '100vh',
          display: 'grid',
          placeItems: 'center',
          background: '#F4F7FB',
          color: '#122033',
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
          <h1 style={{ marginTop: 0 }}>Something went wrong</h1>
          <p style={{ color: '#475569', lineHeight: 1.6 }}>
            The admin workspace hit an unexpected error. Try again, or contact the
            platform team if it persists.
          </p>
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
            Try again
          </button>
        </div>
      </body>
    </html>
  );
}
