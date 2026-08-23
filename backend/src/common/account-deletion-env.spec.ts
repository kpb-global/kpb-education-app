import { validateAccountDeletionEnvironment } from './account-deletion-env';

const serviceKey = `sb_secret_${'s'.repeat(32)}`;

function legacyJwt(role: string): string {
  const encode = (value: unknown) =>
    Buffer.from(JSON.stringify(value)).toString('base64url');
  return `${encode({ alg: 'HS256', typ: 'JWT' })}.${encode({ role })}.test-signature`;
}

describe('validateAccountDeletionEnvironment', () => {
  it('does not require Supabase admin credentials outside production', () => {
    expect(() =>
      validateAccountDeletionEnvironment({ NODE_ENV: 'test' }),
    ).not.toThrow();
  });

  it('requires a valid Supabase URL in production', () => {
    expect(() =>
      validateAccountDeletionEnvironment({
        NODE_ENV: 'production',
        SUPABASE_SERVICE_ROLE_KEY: serviceKey,
      }),
    ).toThrow('SUPABASE_URL');

    expect(() =>
      validateAccountDeletionEnvironment({
        NODE_ENV: 'production',
        SUPABASE_URL: 'http://project.supabase.co',
        SUPABASE_SERVICE_ROLE_KEY: serviceKey,
      }),
    ).toThrow('HTTPS');
  });

  it('requires a server-only Supabase admin key in production', () => {
    expect(() =>
      validateAccountDeletionEnvironment({
        NODE_ENV: 'production',
        SUPABASE_URL: 'https://project.supabase.co',
      }),
    ).toThrow('SUPABASE_SERVICE_ROLE_KEY');

    expect(() =>
      validateAccountDeletionEnvironment({
        NODE_ENV: 'production',
        SUPABASE_URL: 'https://project.supabase.co',
        SUPABASE_SERVICE_ROLE_KEY: `sb_publishable_${'p'.repeat(32)}`,
      }),
    ).toThrow('server-only');

    expect(() =>
      validateAccountDeletionEnvironment({
        NODE_ENV: 'production',
        SUPABASE_URL: 'https://project.supabase.co',
        SUPABASE_SERVICE_ROLE_KEY: `sb_anon_${'a'.repeat(32)}`,
      }),
    ).toThrow('server-only');
  });

  it('rejects a legacy anon JWT even when it is long enough', () => {
    expect(() =>
      validateAccountDeletionEnvironment({
        NODE_ENV: 'production',
        SUPABASE_URL: 'https://project.supabase.co',
        SUPABASE_SERVICE_ROLE_KEY: legacyJwt('anon'),
      }),
    ).toThrow('server-only');
  });

  it('rejects malformed and unsupported opaque key values', () => {
    for (const invalidKey of [
      'x'.repeat(64),
      `not-json.${Buffer.from('{').toString('base64url')}.signature`,
      legacyJwt('authenticated'),
    ]) {
      expect(() =>
        validateAccountDeletionEnvironment({
          NODE_ENV: 'production',
          SUPABASE_URL: 'https://project.supabase.co',
          SUPABASE_SERVICE_ROLE_KEY: invalidKey,
        }),
      ).toThrow('server-only');
    }
  });

  it('accepts a modern Supabase server secret key', () => {
    expect(() =>
      validateAccountDeletionEnvironment({
        NODE_ENV: 'production',
        SUPABASE_URL: 'https://project.supabase.co',
        SUPABASE_SERVICE_ROLE_KEY: serviceKey,
      }),
    ).not.toThrow();
  });

  it('accepts a legacy JWT only when its role is service_role', () => {
    expect(() =>
      validateAccountDeletionEnvironment({
        NODE_ENV: 'production',
        SUPABASE_URL: 'https://project.supabase.co',
        SUPABASE_SERVICE_ROLE_KEY: legacyJwt('service_role'),
      }),
    ).not.toThrow();
  });
});
