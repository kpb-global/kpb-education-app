import { resolveCorsOrigins } from './cors-origins';

describe('resolveCorsOrigins', () => {
  const previousEnv = {
    CORS_ORIGINS: process.env.CORS_ORIGINS,
    NODE_ENV: process.env.NODE_ENV,
  };

  afterEach(() => {
    if (previousEnv.CORS_ORIGINS === undefined) {
      delete process.env.CORS_ORIGINS;
    } else {
      process.env.CORS_ORIGINS = previousEnv.CORS_ORIGINS;
    }
    if (previousEnv.NODE_ENV === undefined) {
      delete process.env.NODE_ENV;
    } else {
      process.env.NODE_ENV = previousEnv.NODE_ENV;
    }
  });

  it('splits comma-separated origins and trims whitespace', () => {
    process.env.CORS_ORIGINS =
      ' https://admin.kpbeducation.cloud , https://app.kpbeducation.cloud ';
    expect(resolveCorsOrigins()).toEqual([
      'https://admin.kpbeducation.cloud',
      'https://app.kpbeducation.cloud',
    ]);
  });

  it('drops empty entries left by stray commas', () => {
    process.env.CORS_ORIGINS = 'https://admin.kpbeducation.cloud,,';
    expect(resolveCorsOrigins()).toEqual(['https://admin.kpbeducation.cloud']);
  });

  it('deduplicates and canonicalizes exact origins', () => {
    process.env.CORS_ORIGINS =
      'https://admin.kpbeducation.cloud/,https://admin.kpbeducation.cloud';
    expect(resolveCorsOrigins()).toEqual([
      'https://admin.kpbeducation.cloud',
    ]);
  });

  it.each([
    '*',
    'null',
    'https://user:password@admin.kpbeducation.cloud',
    'https://admin.kpbeducation.cloud/path',
    'https://admin.kpbeducation.cloud?token=secret',
    'http://admin.kpbeducation.cloud',
    'javascript:alert(1)',
  ])('rejects unsafe or non-origin production CORS entry %s', (origin) => {
    process.env.CORS_ORIGINS = origin;
    process.env.NODE_ENV = 'production';
    expect(() => resolveCorsOrigins()).toThrow();
  });

  it('allows an explicit HTTP loopback origin for local smoke tests', () => {
    process.env.CORS_ORIGINS = 'http://127.0.0.1:3000';
    process.env.NODE_ENV = 'production';
    expect(resolveCorsOrigins()).toEqual(['http://127.0.0.1:3000']);
  });

  it('falls back to localhost outside production', () => {
    delete process.env.CORS_ORIGINS;
    process.env.NODE_ENV = 'test';
    expect(resolveCorsOrigins()).toEqual(['http://localhost:3000']);
  });

  it('throws in production when CORS_ORIGINS is unset', () => {
    delete process.env.CORS_ORIGINS;
    process.env.NODE_ENV = 'production';
    expect(() => resolveCorsOrigins()).toThrow(/CORS_ORIGINS/);
  });

  it('throws in production when CORS_ORIGINS is blank', () => {
    process.env.CORS_ORIGINS = '  , ';
    process.env.NODE_ENV = 'production';
    expect(() => resolveCorsOrigins()).toThrow(/CORS_ORIGINS/);
  });
});
