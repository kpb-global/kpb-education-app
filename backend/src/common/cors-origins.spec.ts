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
      ' https://admin.kpb-education.com , https://app.kpb-education.com ';
    expect(resolveCorsOrigins()).toEqual([
      'https://admin.kpb-education.com',
      'https://app.kpb-education.com',
    ]);
  });

  it('drops empty entries left by stray commas', () => {
    process.env.CORS_ORIGINS = 'https://admin.kpb-education.com,,';
    expect(resolveCorsOrigins()).toEqual(['https://admin.kpb-education.com']);
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
