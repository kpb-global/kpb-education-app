/**
 * Config-driven error reporting for the admin error boundaries.
 *
 * When NEXT_PUBLIC_SENTRY_DSN is set, errors are forwarded to Sentry through
 * its public envelope API (no SDK dependency — the payload is small enough
 * that pulling in @sentry/nextjs just for two error boundaries isn't worth
 * the build footprint; swap the internals for the SDK if richer traces are
 * ever needed). When the DSN is unset, this is a silent no-op — the same
 * pattern the backend uses for OneSignal/Groq.
 */
const dsn = process.env.NEXT_PUBLIC_SENTRY_DSN ?? '';

type ParsedDsn = { origin: string; projectId: string; publicKey: string };

function parseDsn(value: string): ParsedDsn | null {
  try {
    // DSN shape: https://<publicKey>@<host>/<projectId>
    const url = new URL(value);
    const projectId = url.pathname.replace(/^\//, '');
    if (!url.username || !projectId) return null;
    return {
      origin: `${url.protocol}//${url.host}`,
      projectId,
      publicKey: url.username,
    };
  } catch {
    return null;
  }
}

export function reportError(error: Error & { digest?: string }): void {
  if (!dsn) return; // monitoring not configured — silent no-op

  try {
    const parsed = parseDsn(dsn);
    if (!parsed) return;

    const eventId = crypto.randomUUID().replace(/-/g, '');
    const event = {
      event_id: eventId,
      timestamp: new Date().toISOString(),
      platform: 'javascript',
      level: 'error',
      environment: process.env.NODE_ENV,
      exception: {
        values: [
          {
            type: error.name || 'Error',
            value: error.message || String(error),
          },
        ],
      },
      extra: {
        digest: error.digest ?? null,
        stack: error.stack ?? null,
      },
    };
    const envelope = [
      JSON.stringify({ event_id: eventId, sent_at: new Date().toISOString() }),
      JSON.stringify({ type: 'event' }),
      JSON.stringify(event),
    ].join('\n');

    void fetch(
      `${parsed.origin}/api/${parsed.projectId}/envelope/?sentry_key=${parsed.publicKey}&sentry_version=7`,
      { method: 'POST', body: envelope, keepalive: true },
    ).catch(() => undefined);
  } catch {
    // Monitoring must never break the error page itself.
  }
}
