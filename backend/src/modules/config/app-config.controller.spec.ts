import { AppConfigController } from './app-config.controller';

describe('AppConfigController', () => {
  const previousEnv = {
    KPB_MIN_APP_VERSION: process.env.KPB_MIN_APP_VERSION,
    KPB_ANDROID_STORE_URL: process.env.KPB_ANDROID_STORE_URL,
    KPB_IOS_STORE_URL: process.env.KPB_IOS_STORE_URL,
    KPB_COMPETITION_READINESS_ENABLED:
      process.env.KPB_COMPETITION_READINESS_ENABLED,
    KPB_SUCCESS_LAB_ENABLED: process.env.KPB_SUCCESS_LAB_ENABLED,
    KPB_AI_DIAGNOSTIC_ENABLED: process.env.KPB_AI_DIAGNOSTIC_ENABLED,
    KPB_AI_DIAGNOSTIC_KILL_SWITCH:
      process.env.KPB_AI_DIAGNOSTIC_KILL_SWITCH,
    KPB_OUTCOME_EVIDENCE_ENABLED:
      process.env.KPB_OUTCOME_EVIDENCE_ENABLED,
    KPB_IMPACT_PUBLIC_STATS_ENABLED:
      process.env.KPB_IMPACT_PUBLIC_STATS_ENABLED,
    KPB_SUCCESS_LAB_PILOT_COUNTRIES:
      process.env.KPB_SUCCESS_LAB_PILOT_COUNTRIES,
    KPB_SUCCESS_LAB_ROLLOUT_PERCENT:
      process.env.KPB_SUCCESS_LAB_ROLLOUT_PERCENT,
    KPB_FEATURE_ROLLOUT_SECRET: process.env.KPB_FEATURE_ROLLOUT_SECRET,
  };

  beforeEach(() => {
    for (const key of Object.keys(previousEnv)) {
      delete process.env[key];
    }
  });

  afterEach(() => {
    for (const [key, value] of Object.entries(previousEnv)) {
      if (value === undefined) {
        delete process.env[key];
      } else {
        process.env[key] = value;
      }
    }
  });

  it('defaults to a non-blocking minVersion when unset', () => {
    delete process.env.KPB_MIN_APP_VERSION;
    const config = new AppConfigController().getAppConfig();
    expect(config.minVersion).toBe('0.0.0');
    expect(config.androidStoreUrl).toContain('com.kpbeducation.app');
    expect(config.features).toEqual({
      competitionReadiness: false,
      successLab: false,
      aiDiagnostic: false,
      outcomeEvidence: false,
      publicImpactStats: false,
    });
    expect(config.successLabRollout).toEqual({
      countryCodes: [],
      percent: 0,
    });
  });

  it('returns the configured minVersion and store URLs, trimmed', () => {
    process.env.KPB_MIN_APP_VERSION = ' 1.2.0 ';
    process.env.KPB_ANDROID_STORE_URL = 'https://play.example/app ';
    process.env.KPB_IOS_STORE_URL = ' https://apps.example/app';
    const config = new AppConfigController().getAppConfig();
    expect(config).toMatchObject({
      minVersion: '1.2.0',
      androidStoreUrl: 'https://play.example/app',
      iosStoreUrl: 'https://apps.example/app',
    });
  });

  it('keeps nested capabilities fail-closed and never exposes rollout secrets', () => {
    process.env.KPB_COMPETITION_READINESS_ENABLED = 'true';
    process.env.KPB_SUCCESS_LAB_ENABLED = 'true';
    process.env.KPB_AI_DIAGNOSTIC_ENABLED = 'true';
    process.env.KPB_AI_DIAGNOSTIC_KILL_SWITCH = 'false';
    process.env.KPB_OUTCOME_EVIDENCE_ENABLED = 'true';
    process.env.KPB_SUCCESS_LAB_PILOT_COUNTRIES = ' ne, SN,ci ';
    process.env.KPB_SUCCESS_LAB_ROLLOUT_PERCENT = '140';
    process.env.KPB_FEATURE_ROLLOUT_SECRET = 'must-not-leak';

    const config = new AppConfigController().getAppConfig();

    expect(config.features).toMatchObject({
      competitionReadiness: true,
      successLab: true,
      aiDiagnostic: true,
      outcomeEvidence: true,
    });
    expect(config.successLabRollout).toEqual({
      countryCodes: ['NE', 'SN', 'CI'],
      percent: 100,
    });
    expect(JSON.stringify(config)).not.toContain('must-not-leak');
  });

  it('cannot expose a child capability while the parent gate is disabled', () => {
    process.env.KPB_COMPETITION_READINESS_ENABLED = 'false';
    process.env.KPB_SUCCESS_LAB_ENABLED = 'true';
    process.env.KPB_AI_DIAGNOSTIC_ENABLED = 'true';
    process.env.KPB_AI_DIAGNOSTIC_KILL_SWITCH = 'false';
    process.env.KPB_OUTCOME_EVIDENCE_ENABLED = 'true';

    const config = new AppConfigController().getAppConfig();

    expect(config.features.successLab).toBe(false);
    expect(config.features.aiDiagnostic).toBe(false);
    expect(config.features.outcomeEvidence).toBe(false);
  });
});
