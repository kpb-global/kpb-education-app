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
    KPB_EEF_ENABLED: process.env.KPB_EEF_ENABLED,
    KPB_EEF_TEASER_ENABLED: process.env.KPB_EEF_TEASER_ENABLED,
    KPB_EEF_CAMPAIGN_OPENS_AT: process.env.KPB_EEF_CAMPAIGN_OPENS_AT,
    KPB_EEF_CAMPAIGN_CLOSES_AT: process.env.KPB_EEF_CAMPAIGN_CLOSES_AT,
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

  // The force-update screen is not dismissible and its only button is disabled
  // when the URL is empty or dead. So the fallback — what production serves
  // whenever KPB_ANDROID_STORE_URL / KPB_IOS_STORE_URL are unset — must point at
  // the listings that are actually published, not at a package that 404s.
  it('falls back to the store listings that are actually published', () => {
    const config = new AppConfigController().getAppConfig();
    expect(config.androidStoreUrl).toContain('id=com.karatou.android');
    expect(config.iosStoreUrl).toContain('id1128659292');
  });

  it('defaults to a non-blocking minVersion when unset', () => {
    delete process.env.KPB_MIN_APP_VERSION;
    const config = new AppConfigController().getAppConfig();
    expect(config.minVersion).toBe('0.0.0');
    expect(config.features).toEqual({
      competitionReadiness: false,
      successLab: false,
      aiDiagnostic: false,
      outcomeEvidence: false,
      publicImpactStats: false,
      eefTeaser: false,
      eef: false,
    });
    expect(config.eefCampaign).toEqual({ opensAt: null, closesAt: null });
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

  // Le jour du lancement, l'exploitation ne bascule QU'UNE variable. Si le
  // teaser pouvait rester allumé à côté de l'espace réel, l'app afficherait
  // « en préparation » et l'espace vivant en même temps — et personne ne le
  // verrait depuis un tableau de bord.
  it('retires the EEF teaser as soon as the real space opens', () => {
    process.env.KPB_EEF_TEASER_ENABLED = 'true';
    process.env.KPB_EEF_ENABLED = 'true';

    const config = new AppConfigController().getAppConfig();

    expect(config.features.eef).toBe(true);
    expect(config.features.eefTeaser).toBe(false);
  });

  it('serves the EEF teaser while the real space is still closed', () => {
    process.env.KPB_EEF_TEASER_ENABLED = 'true';

    const config = new AppConfigController().getAppConfig();

    expect(config.features.eefTeaser).toBe(true);
    expect(config.features.eef).toBe(false);
  });

  // Une faute de frappe dans une variable de déploiement ne doit pas faire
  // annoncer « Invalid Date », ni — pire — faire retomber sur maintenant, ce
  // qui annoncerait une campagne s'ouvrant à l'instant où l'écran s'ouvre.
  it('serves null rather than a guess for an unparseable campaign date', () => {
    process.env.KPB_EEF_CAMPAIGN_OPENS_AT = 'pas-une-date';
    process.env.KPB_EEF_CAMPAIGN_CLOSES_AT = '   ';

    const config = new AppConfigController().getAppConfig();

    expect(config.eefCampaign).toEqual({ opensAt: null, closesAt: null });
  });

  it('normalizes configured campaign dates to ISO instants', () => {
    process.env.KPB_EEF_CAMPAIGN_OPENS_AT = ' 2026-08-26T00:00:00Z ';
    process.env.KPB_EEF_CAMPAIGN_CLOSES_AT = '2026-12-15T23:59:00Z';

    const config = new AppConfigController().getAppConfig();

    expect(config.eefCampaign.opensAt).toBe('2026-08-26T00:00:00.000Z');
    expect(config.eefCampaign.closesAt).toBe('2026-12-15T23:59:00.000Z');
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
