/**
 * Resolves the allowed CORS origins from `CORS_ORIGINS` (comma-separated).
 *
 * In production a missing/empty CORS_ORIGINS is a deployment error: silently
 * falling back to localhost would either block every real client or, worse,
 * ship a permissive default — so we fail loudly at boot instead. In dev the
 * localhost fallback keeps the default stack working with zero config.
 */
export function resolveCorsOrigins(): string[] {
  const origins = (process.env.CORS_ORIGINS ?? '')
    .split(',')
    .map((origin) => origin.trim())
    .filter(Boolean);

  if (origins.length > 0) {
    return origins;
  }

  if (process.env.NODE_ENV === 'production') {
    throw new Error(
      'CORS_ORIGINS must be set in production (comma-separated list of allowed origins).',
    );
  }

  return ['http://localhost:3000'];
}
