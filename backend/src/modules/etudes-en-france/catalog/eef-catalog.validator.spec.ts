import {
  DEFAULT_EEF_GATES,
  validateEefCatalog,
} from './eef-catalog.validator';
import type {
  EefCatalog,
  EefInstitutionRecord,
  EefProgramRecord,
} from './eef-catalog.types';

const INSTITUTION: EefInstitutionRecord = {
  id: 'eef-univ-0353074b',
  uai: '0353074B',
  nameFr: 'Université de Rennes',
  nameEn: 'University of Rennes',
  acronym: null,
  city: 'Rennes',
  department: 'Ille-et-Vilaine',
  region: 'Bretagne',
  websiteUrl: 'https://www.univ-rennes.fr/',
  typology: 'Université scientifique et/ou médicale',
  enrolment: { count: 34926, year: 2024 },
  sourceUrl: 'https://data.enseignementsup-recherche.gouv.fr/explore/dataset/x/',
};

const PROGRAM: EefProgramRecord = {
  id: 'eef-prog-0000000000000001',
  institutionId: INSTITUTION.id,
  nameFr: 'L1 - Droit',
  level: 'Bachelor',
  cycle: 'licence1',
  fieldId: 'd07',
  fieldIsFallback: false,
  durationYears: 3,
  campusCity: 'Rennes',
  procedureType: 'dap_blanche',
  selectivity: 'non_selective',
  formationCode: '9307',
  tracks: [],
  recommendedBachelors: [],
  admissionModes: [],
  dataset: 'parcoursup',
  sourceUrl: 'https://dossierappel.parcoursup.fr/x?g_ta_cod=9307',
};

function catalogOf(
  programs: EefProgramRecord[],
  overrides: Partial<EefCatalog['manifest']> = {},
): EefCatalog {
  return {
    manifest: {
      catalogVersion: '1.0.0',
      generatedAt: '2026-09-20T00:00:00.000Z',
      countryId: 'france',
      institutionCount: 1,
      programCount: programs.length,
      sources: [
        {
          dataset: 'parcoursup',
          datasetId: 'fr-esr-cartographie_formations_parcoursup',
          portal: 'https://data.enseignementsup-recherche.gouv.fr',
          licence: 'Licence Ouverte v2.0 (Etalab)',
          query: 'annee=2026',
          vintage: '2026',
          fetchedAt: '2026-09-20T00:00:00.000Z',
          rowCount: programs.length,
        },
      ],
      ...overrides,
    },
    universities: [{ institution: INSTITUTION, programs }],
  };
}

// Portes ouvertes : ces tests jugent la QUALITÉ d'une ligne, pas le volume du
// catalogue réel. Les planchers de volume ont leurs propres cas ci-dessous.
const LOOSE = {
  ...DEFAULT_EEF_GATES,
  minInstitutions: 1,
  minPrograms: 1,
  minInstitutionsWithPrograms: 0,
};

describe('validateEefCatalog', () => {
  it('accepte un catalogue bien formé', () => {
    const result = validateEefCatalog(catalogOf([PROGRAM]), LOOSE);
    expect(result.errors).toEqual([]);
    expect(result.stats.programs).toBe(1);
  });

  it('refuse une formation sans fiche officielle HTTPS', () => {
    // Sans source, personne ne peut re-vérifier, donc personne ne le fera.
    for (const bad of ['', 'http://parcoursup.fr/x', 'https://', 'pas une url']) {
      const result = validateEefCatalog(
        catalogOf([{ ...PROGRAM, sourceUrl: bad }]),
        LOOSE,
      );
      expect(result.errors.join(' ')).toContain('fiche officielle');
    }
  });

  it('refuse deux formations sous le même identifiant', () => {
    // Un doublon d'id transforme « créer si absent » en « ne rien faire »,
    // silencieusement : la seconde ligne n'existerait jamais.
    const result = validateEefCatalog(
      catalogOf([PROGRAM, { ...PROGRAM, nameFr: 'L1 - Histoire' }]),
      LOOSE,
    );
    expect(result.errors.join(' ')).toContain('Formation en double');
  });

  it('refuse une formation rangée sous une autre université que la sienne', () => {
    const result = validateEefCatalog(
      catalogOf([{ ...PROGRAM, institutionId: 'eef-univ-autre' }]),
      LOOSE,
    );
    expect(result.errors.join(' ')).toContain('rattachée à');
  });

  it('refuse toute valeur hors référentiel', () => {
    const cases: [Partial<EefProgramRecord>, string][] = [
      [{ fieldId: 'd99' }, 'domaine hors référentiel'],
      [{ level: 'Licence' as never }, 'niveau hors référentiel'],
      [{ cycle: 'doctorat' as never }, 'cycle hors référentiel'],
      [{ procedureType: 'campusfrance' as never }, 'procédure hors référentiel'],
      [{ selectivity: 'peut-être' as never }, 'sélectivité hors référentiel'],
      [{ dataset: 'chatgpt' as never }, 'jeu de données inconnu'],
      [{ durationYears: 0 }, 'durée non entière'],
    ];
    for (const [patch, expected] of cases) {
      const result = validateEefCatalog(
        catalogOf([{ ...PROGRAM, ...patch }]),
        LOOSE,
      );
      expect(result.errors.join(' ')).toContain(expected);
    }
  });

  it('plafonne le classement par repli', () => {
    // Un taux de repli qui monte veut dire que la source a changé de
    // vocabulaire : le domaine ne veut plus rien dire, et il faut le savoir
    // avant l'étudiant.
    const fallbacks = Array.from({ length: 10 }, (_, index) => ({
      ...PROGRAM,
      id: `eef-prog-fallback-${index}`,
      fieldIsFallback: true,
    }));
    const result = validateEefCatalog(catalogOf(fallbacks), LOOSE);
    expect(result.stats.fallbackRatio).toBe(1);
    expect(result.errors.join(' ')).toContain('classés par repli');
  });

  it('refuse un manifeste qui ne compte pas ce qu’il y a dans les fichiers', () => {
    const result = validateEefCatalog(
      catalogOf([PROGRAM], { programCount: 4242 }),
      LOOSE,
    );
    expect(result.errors.join(' ')).toContain('4242 formations annoncées');
  });

  it('refuse une source sans licence déclarée', () => {
    const catalog = catalogOf([PROGRAM]);
    const result = validateEefCatalog(
      {
        ...catalog,
        manifest: {
          ...catalog.manifest,
          sources: [{ ...catalog.manifest.sources[0], licence: '' }],
        },
      },
      LOOSE,
    );
    expect(result.errors.join(' ')).toContain('licence non déclarée');
  });

  it('avertit sur un millésime ancien sans refuser le catalogue', () => {
    const catalog = catalogOf([PROGRAM]);
    const result = validateEefCatalog(
      {
        ...catalog,
        manifest: {
          ...catalog.manifest,
          sources: [{ ...catalog.manifest.sources[0], vintage: '2021' }],
        },
      },
      LOOSE,
    );
    expect(result.errors).toEqual([]);
    expect(result.warnings.join(' ')).toContain('millésime 2021');
  });

  it('refuse un catalogue qui a perdu son volume', () => {
    const result = validateEefCatalog(catalogOf([PROGRAM]), DEFAULT_EEF_GATES);
    expect(result.errors.join(' ')).toContain("Plancher d'établissements");
    expect(result.errors.join(' ')).toContain('Plancher de formations');
  });
});
