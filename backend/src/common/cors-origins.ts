/**
 * Resolves the allowed CORS origins from `CORS_ORIGINS` (comma-separated).
 *
 * In production a missing/empty CORS_ORIGINS is a deployment error: silently
 * falling back to localhost would either block every real client or, worse,
 * ship a permissive default — so we fail loudly at boot instead. In dev the
 * localhost fallback keeps the default stack working with zero config.
 */
export function resolveCorsOrigins(): string[] {
  const configured = (process.env.CORS_ORIGINS ?? '')
    .split(',')
    .map((origin) => origin.trim())
    .filter(Boolean);

  if (configured.length > 0) {
    return [...new Set(configured.map(validateExactOrigin))];
  }

  if (process.env.NODE_ENV === 'production') {
    throw new Error(
      'CORS_ORIGINS must be set in production (comma-separated list of allowed origins).',
    );
  }

  return ['http://localhost:3000'];
}

function validateExactOrigin(value: string): string {
  if (value === '*' || value.toLowerCase() === 'null') {
    throw new Error('CORS_ORIGINS must contain exact trusted origins.');
  }

  let parsed: URL;
  try {
    parsed = new URL(value);
  } catch {
    throw new Error(`Invalid CORS origin: ${value}`);
  }

  const loopback =
    parsed.hostname === 'localhost' ||
    parsed.hostname === '127.0.0.1' ||
    parsed.hostname === '::1';
  if (parsed.protocol !== 'https:' && !(parsed.protocol === 'http:' && loopback)) {
    throw new Error('CORS origins must use HTTPS (HTTP is allowed only on loopback).');
  }
  if (
    parsed.username ||
    parsed.password ||
    parsed.pathname !== '/' ||
    parsed.search ||
    parsed.hash
  ) {
    throw new Error('CORS_ORIGINS entries must be origins without credentials, paths or query strings.');
  }

  return parsed.origin;
}
