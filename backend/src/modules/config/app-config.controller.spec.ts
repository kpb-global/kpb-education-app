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
    KPB_EEF_SUSPENDED_COUNTRIES: process.env.KPB_EEF_SUSPENDED_COUNTRIES,
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
    expect(config.eefCampaign).toEqual({
      opensAt: null,
      closesAt: null,
      suspendedCountries: [],
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

    expect(config.eefCampaign.opensAt).toBeNull();
    expect(config.eefCampaign.closesAt).toBeNull();
  });

  // Le Niger : la source officielle de l'ambassade dit que le traitement des
  // dossiers d'étudiants nigériens est impossible. Annoncer une ouverture leur
  // ferait engager une démarche que l'État français déclare inopérante. La
  // liste est SERVIE pour qu'une réouverture n'attende pas un passage au store.
  it('serves the suspended-country list, trimmed and de-duplicated', () => {
    process.env.KPB_EEF_SUSPENDED_COUNTRIES = ' Niger , NE ,, Niger ';

    const config = new AppConfigController().getAppConfig();

    expect(config.eefCampaign.suspendedCountries).toEqual(['Niger', 'NE']);
  });

  // PAS de mise en majuscules, contrairement aux codes pays du Success Lab : la
  // liste est comparée à un `countryOfResidence` qui porte un nom français. La
  // normalisation est le travail du client, qui sait ce qu'il compare.
  it('keeps the operator spelling on the wire', () => {
    process.env.KPB_EEF_SUSPENDED_COUNTRIES = "Côte d'Ivoire";

    const config = new AppConfigController().getAppConfig();

    expect(config.eefCampaign.suspendedCountries).toEqual(["Côte d'Ivoire"]);
  });

  // ## Le fil porte des JOURS, pas des instants
  //
  // Ce bloc remplace un test intitulé « normalizes configured campaign dates to
  // ISO instants », qui figeait exactement la faute : la normalisation en
  // instant était le défaut, et un test la déclarait contrat.
  //
  // Une date de campagne est une date d'HORLOGE MURALE. Servir un instant le
  // laisse reprojeter dans le fuseau du lecteur, et « le 1er octobre » devient
  // « le 30 septembre » pour une partie du public — ou pour la totalité, selon
  // ce que l'exploitation a tapé.
  describe('la fenêtre de campagne est servie en jours d\'horloge murale', () => {
    // LE test. Ces quatre écritures désignent des instants différents et le
    // MÊME jour administratif ; le fil doit porter « 2026-10-01 » pour les
    // quatre. La troisième est le cas de production : l'heure de Paris, réflexe
    // naturel pour une procédure française, faisait servir
    // « 2026-09-30T22:00:00.000Z » — donc le 30 septembre pour TOUT LE MONDE,
    // Dakar, Bamako, Abidjan, Niamey et Douala compris.
    it.each([
      '2026-10-01',
      '2026-10-01T00:00:00Z',
      '2026-10-01T00:00:00+02:00',
      '2026-10-01T23:30:00-05:00',
    ])('« %s » est servi « 2026-10-01 »', (written) => {
      process.env.KPB_EEF_CAMPAIGN_OPENS_AT = ` ${written} `;

      const config = new AppConfigController().getAppConfig();

      expect(config.eefCampaign.opensAt).toBe('2026-10-01');
    });

    it('ne laisse aucune heure sur le fil', () => {
      // Une heure survivante réintroduirait la possibilité d'un décalage dès
      // qu'un lecteur — client mobile d'aujourd'hui ou d'ailleurs — la parserait
      // en instant.
      process.env.KPB_EEF_CAMPAIGN_OPENS_AT = '2026-10-01T00:00:00Z';
      process.env.KPB_EEF_CAMPAIGN_CLOSES_AT = '2026-12-15T23:59:00Z';

      const config = new AppConfigController().getAppConfig();

      expect(config.eefCampaign.opensAt).toBe('2026-10-01');
      expect(config.eefCampaign.closesAt).toBe('2026-12-15');
      for (const served of [
        config.eefCampaign.opensAt,
        config.eefCampaign.closesAt,
      ]) {
        expect(served).toMatch(/^\d{4}-\d{2}-\d{2}$/);
      }
    });

    // `new Date(Date.UTC(2026, 12, 1))` vaut janvier 2027 et un 30 février
    // devient le 2 mars : servir une date normalisée, c'est servir une date que
    // personne n'a écrite, indistinguable d'une information pour qui la lit.
    it.each([
      '2026-13-01',
      '2026-02-30',
      '2026-00-10',
      '2026-10-32',
      '26-10-01',
      '2026-1-5',
      'demain',
    ])('« %s » ne produit aucune date', (written) => {
      process.env.KPB_EEF_CAMPAIGN_OPENS_AT = written;

      const config = new AppConfigController().getAppConfig();

      expect(config.eefCampaign.opensAt).toBeNull();
    });
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
