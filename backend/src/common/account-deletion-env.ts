type Environment = Record<string, string | undefined>;

const MINIMUM_SERVICE_KEY_BYTES = 32;

function isLegacyServiceRoleJwt(value: string): boolean {
  const segments = value.split('.');
  if (
    segments.length !== 3 ||
    segments.some(
      (segment) => !segment || !/^[A-Za-z0-9_-]+$/.test(segment),
    )
  ) {
    return false;
  }

  try {
    const header = JSON.parse(
      Buffer.from(segments[0], 'base64url').toString('utf8'),
    ) as unknown;
    const payload = JSON.parse(
      Buffer.from(segments[1], 'base64url').toString('utf8'),
    ) as unknown;
    return (
      typeof header === 'object' &&
      header !== null &&
      typeof (header as { alg?: unknown }).alg === 'string' &&
      typeof payload === 'object' &&
      payload !== null &&
      (payload as { role?: unknown }).role === 'service_role'
    );
  } catch {
    return false;
  }
}

function isSupabaseServerKey(value: string): boolean {
  if (Buffer.byteLength(value, 'utf8') < MINIMUM_SERVICE_KEY_BYTES) {
    return false;
  }
  if (value.startsWith('sb_secret_')) return true;
  if (
    value.startsWith('sb_publishable_') ||
    value.startsWith('sb_anon_')
  ) {
    return false;
  }
  return isLegacyServiceRoleJwt(value);
}

/**
 * Account deletion is a production invariant, not an optional integration.
 *
 * The API can delete its own Postgres rows without a Supabase admin key, but
 * that would leave the login identity alive. Fail during bootstrap instead of
 * accepting traffic in a configuration that cannot honour the store-facing
 * deletion promise. Development and tests keep the existing no-key ergonomics.
 */
export function validateAccountDeletionEnvironment(
  env: Environment = process.env,
): void {
  if (env.NODE_ENV !== 'production') return;

  const rawUrl = env.SUPABASE_URL?.trim() ?? '';
  let url: URL;
  try {
    url = new URL(rawUrl);
  } catch {
    throw new Error(
      'SUPABASE_URL must be a valid HTTPS URL in production so account deletion can remove the Auth identity.',
    );
  }
  if (url.protocol !== 'https:') {
    throw new Error(
      'SUPABASE_URL must be a valid HTTPS URL in production so account deletion can remove the Auth identity.',
    );
  }

  const serviceKey = env.SUPABASE_SERVICE_ROLE_KEY?.trim() ?? '';
  if (!isSupabaseServerKey(serviceKey)) {
    throw new Error(
      'SUPABASE_SERVICE_ROLE_KEY must contain a server-only Supabase service-role/secret key in production.',
    );
  }
}
