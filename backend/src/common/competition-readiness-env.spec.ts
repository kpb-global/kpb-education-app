import { validateCompetitionReadinessEnvironment } from './competition-readiness-env';

const secret = 's'.repeat(32);

function productionEnv(
  overrides: Record<string, string | undefined> = {},
): Record<string, string | undefined> {
  return {
    NODE_ENV: 'production',
    KPB_COMPETITION_READINESS_ENABLED: 'false',
    KPB_SUCCESS_LAB_ENABLED: 'false',
    KPB_APPLICATION_ARTIFACTS_ENABLED: 'false',
    KPB_STUDY_REVIEW_ENABLED: 'false',
    KPB_AI_DIAGNOSTIC_ENABLED: 'false',
    KPB_OUTCOME_EVIDENCE_ENABLED: 'false',
    KPB_IMPACT_PUBLIC_STATS_ENABLED: 'false',
    KPB_SUCCESS_LAB_ROLLOUT_PERCENT: '0',
    ...overrides,
  };
}

describe('validateCompetitionReadinessEnvironment', () => {
  it('accepts the fail-closed all-off production configuration', () => {
    expect(() =>
      validateCompetitionReadinessEnvironment(productionEnv()),
    ).not.toThrow();
  });

  it('rejects a child flag when the global feature is disabled', () => {
    expect(() =>
      validateCompetitionReadinessEnvironment(
        productionEnv({ KPB_SUCCESS_LAB_ENABLED: 'true' }),
      ),
    ).toThrow('KPB_SUCCESS_LAB_ENABLED cannot be enabled');
  });

  it('requires an immutable release identity when the platform is enabled', () => {
    expect(() =>
      validateCompetitionReadinessEnvironment(
        productionEnv({ KPB_COMPETITION_READINESS_ENABLED: 'true' }),
      ),
    ).toThrow('KPB_BUILD_SHA');
  });

  it('rejects an invalid partial rollout before boot', () => {
    expect(() =>
      validateCompetitionReadinessEnvironment(
        productionEnv({
          KPB_COMPETITION_READINESS_ENABLED: 'true',
          KPB_BUILD_SHA: 'a4ef6391422e19d99433b28717c2730d7518dbb7',
          KPB_SUCCESS_LAB_ENABLED: 'true',
          KPB_SUCCESS_LAB_ROLLOUT_PERCENT: '20',
          KPB_SUCCESS_LAB_PILOT_COUNTRIES: 'NE,SEN',
          KPB_FEATURE_ROLLOUT_SECRET: secret,
          KPB_ANALYTICS_ACTOR_SECRET: secret,
        }),
      ),
    ).toThrow('KPB_SUCCESS_LAB_PILOT_COUNTRIES');
  });

  it('rejects an invalid AI budget before boot', () => {
    expect(() =>
      validateCompetitionReadinessEnvironment(
        productionEnv({
          KPB_AI_DIAGNOSTIC_MONTHLY_BUDGET_MICROS_USD: '-1',
        }),
      ),
    ).toThrow('KPB_AI_DIAGNOSTIC_MONTHLY_BUDGET_MICROS_USD');
  });

  it('rejects contradictory outbox retry settings before boot', () => {
    expect(() =>
      validateCompetitionReadinessEnvironment(
        productionEnv({
          KPB_OUTBOX_RETRY_BASE_MS: '6000',
          KPB_OUTBOX_RETRY_CAP_MS: '5000',
        }),
      ),
    ).toThrow('KPB_OUTBOX_RETRY_CAP_MS');
  });

  it('rejects out-of-range outbox worker settings before boot', () => {
    expect(() =>
      validateCompetitionReadinessEnvironment(
        productionEnv({ KPB_OUTBOX_MAX_ATTEMPTS: '0' }),
      ),
    ).toThrow('KPB_OUTBOX_MAX_ATTEMPTS');
  });

  it('requires rollout hashing material for a partial rollout', () => {
    expect(() =>
      validateCompetitionReadinessEnvironment(
        productionEnv({
          KPB_COMPETITION_READINESS_ENABLED: 'true',
          KPB_BUILD_SHA: 'a4ef6391422e19d99433b28717c2730d7518dbb7',
          KPB_SUCCESS_LAB_ENABLED: 'true',
          KPB_SUCCESS_LAB_ROLLOUT_PERCENT: '20',
          KPB_SUCCESS_LAB_PILOT_COUNTRIES: 'NE,SN',
          KPB_ANALYTICS_ACTOR_SECRET: secret,
        }),
      ),
    ).toThrow('KPB_FEATURE_ROLLOUT_SECRET');
  });

  it('requires a pseudonymous analytics secret for any active rollout', () => {
    expect(() =>
      validateCompetitionReadinessEnvironment(
        productionEnv({
          KPB_COMPETITION_READINESS_ENABLED: 'true',
          KPB_BUILD_SHA: 'a4ef6391422e19d99433b28717c2730d7518dbb7',
          KPB_SUCCESS_LAB_ENABLED: 'true',
          KPB_SUCCESS_LAB_ROLLOUT_PERCENT: '100',
          KPB_SUCCESS_LAB_PILOT_COUNTRIES: 'NE,SN',
        }),
      ),
    ).toThrow('KPB_ANALYTICS_ACTOR_SECRET');
  });

  it('requires evidence and reference secrets for outcome evidence', () => {
    expect(() =>
      validateCompetitionReadinessEnvironment(
        productionEnv({
          KPB_COMPETITION_READINESS_ENABLED: 'true',
          KPB_BUILD_SHA: 'a4ef6391422e19d99433b28717c2730d7518dbb7',
          KPB_SUCCESS_LAB_ENABLED: 'true',
          KPB_APPLICATION_ARTIFACTS_ENABLED: 'true',
          KPB_OUTCOME_EVIDENCE_ENABLED: 'true',
          CLAMAV_HOST: 'clamav',
        }),
      ),
    ).toThrow('KPB_EVIDENCE_ACCESS_SECRET');

    expect(() =>
      validateCompetitionReadinessEnvironment(
        productionEnv({
          KPB_COMPETITION_READINESS_ENABLED: 'true',
          KPB_BUILD_SHA: 'a4ef6391422e19d99433b28717c2730d7518dbb7',
          KPB_SUCCESS_LAB_ENABLED: 'true',
          KPB_APPLICATION_ARTIFACTS_ENABLED: 'true',
          KPB_OUTCOME_EVIDENCE_ENABLED: 'true',
          KPB_EVIDENCE_ACCESS_SECRET: secret,
          CLAMAV_HOST: 'clamav',
        }),
      ),
    ).toThrow('KPB_OUTCOME_REFERENCE_HMAC_SECRET');
  });

  it('accepts a fully configured allowlisted rollout', () => {
    expect(() =>
      validateCompetitionReadinessEnvironment(
        productionEnv({
          KPB_COMPETITION_READINESS_ENABLED: 'true',
          KPB_BUILD_SHA: 'a4ef6391422e19d99433b28717c2730d7518dbb7',
          KPB_SUCCESS_LAB_ENABLED: 'true',
          KPB_APPLICATION_ARTIFACTS_ENABLED: 'true',
          KPB_STUDY_REVIEW_ENABLED: 'true',
          KPB_OUTCOME_EVIDENCE_ENABLED: 'true',
          KPB_SUCCESS_LAB_ROLLOUT_PERCENT: '10',
          KPB_SUCCESS_LAB_PILOT_COUNTRIES: 'NE,SN,CI',
          KPB_FEATURE_ROLLOUT_SECRET: 'r'.repeat(32),
          KPB_ANALYTICS_ACTOR_SECRET: 'a'.repeat(32),
          KPB_EVIDENCE_ACCESS_SECRET: 'e'.repeat(32),
          KPB_OUTCOME_REFERENCE_HMAC_SECRET: 'h'.repeat(32),
          CLAMAV_HOST: 'clamav',
        }),
      ),
    ).not.toThrow();
  });

  it('rejects reused Competition Readiness secrets', () => {
    expect(() =>
      validateCompetitionReadinessEnvironment(
        productionEnv({
          KPB_COMPETITION_READINESS_ENABLED: 'true',
          KPB_BUILD_SHA: 'a4ef6391422e19d99433b28717c2730d7518dbb7',
          KPB_SUCCESS_LAB_ENABLED: 'true',
          KPB_APPLICATION_ARTIFACTS_ENABLED: 'true',
          KPB_STUDY_REVIEW_ENABLED: 'true',
          KPB_SUCCESS_LAB_ROLLOUT_PERCENT: '100',
          KPB_SUCCESS_LAB_PILOT_COUNTRIES: 'NE',
          KPB_ANALYTICS_ACTOR_SECRET: secret,
          KPB_EVIDENCE_ACCESS_SECRET: secret,
          CLAMAV_HOST: 'clamav',
        }),
      ),
    ).toThrow('must use distinct values');
  });

  it('does not enforce production-only settings in development', () => {
    expect(() =>
      validateCompetitionReadinessEnvironment({ NODE_ENV: 'development' }),
    ).not.toThrow();
  });
});
