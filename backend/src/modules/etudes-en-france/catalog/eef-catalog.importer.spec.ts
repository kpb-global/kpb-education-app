import {
  importEefCatalog,
  planEefImport,
  type EefCatalogWriter,
  type PlannedInstitution,
  type PlannedProgram,
} from './eef-catalog.importer';
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

const LICENCE: EefProgramRecord = {
  id: 'eef-prog-licence',
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

const MASTER: EefProgramRecord = {
  ...LICENCE,
  id: 'eef-prog-master',
  nameFr: 'Science politique',
  level: 'Master',
  cycle: 'master',
  durationYears: 2,
  procedureType: 'eef',
  selectivity: 'selective',
  formationCode: '1702353J',
  tracks: ['Théorie politique'],
  recommendedBachelors: ['Droit'],
  admissionModes: ['Dossier'],
  dataset: 'trouver-mon-master',
  sourceUrl: 'https://formations.univ-rennes.fr/master-science-politique',
};

const CATALOG: EefCatalog = {
  manifest: {
    catalogVersion: '1.0.0',
    generatedAt: '2026-09-20T00:00:00.000Z',
    countryId: 'france',
    institutionCount: 1,
    programCount: 2,
    sources: [],
  },
  universities: [{ institution: INSTITUTION, programs: [LICENCE, MASTER] }],
};

describe('planEefImport', () => {
  const plan = planEefImport(CATALOG, 'france');

  it('rattache tout au pays passé en paramètre, jamais à un id écrit en dur', () => {
    // `countryId` n'est pas une clé étrangère : écrire le mauvais produirait
    // des lignes orphelines qu'aucun filtre ne montrerait.
    for (const row of [...plan.institutions, ...plan.programs]) {
      expect(row.countryId).toBe('france');
    }
    expect(planEefImport(CATALOG, 'fra').programs[0].countryId).toBe('fra');
  });

  it('crée des lignes INACTIVES, établissements compris', () => {
    // À 10 000 lignes la relecture intégrale n'arrivera jamais ; ce qui doit
    // arriver, c'est que rien ne s'affiche tant que personne n'a relu.
    //
    // L'établissement compte autant que ses formations : sa fiche est une
    // affirmation (présentation, effectif daté) et son `programIds` renvoie
    // vers des lignes non relues. Le publier, c'est les publier.
    expect(plan.programs.every((row) => row.isActive === false)).toBe(true);
    expect(plan.institutions.every((row) => row.isActive === false)).toBe(true);
  });

  it('n’invente ni prix, ni niveau de français, ni frais de dossier', () => {
    for (const row of plan.programs) {
      expect(row.tuitionMinEur).toBeNull();
      expect(row.frenchLevelRequired).toBeNull();
      expect(row.applicationFeeEur).toBeNull();
      expect(row.tuitionFr).toContain('droits');
      expect(row.tuitionFr.toLowerCase()).toContain('vérifie');
    }
  });

  it('préfixe une mention de master, laisse la filière Parcoursup telle quelle', () => {
    const [licence, master] = plan.programs;
    expect(licence.nameFr).toBe('L1 - Droit');
    expect(master.nameFr).toBe('Master — Science politique');
  });

  it('écrit des exigences d’admission qui nomment la bonne procédure', () => {
    const [licence, master] = plan.programs;
    expect(licence.requirementsFr[0]).toContain('L1 - Droit');
    expect(licence.requirementsFr.join(' ')).toContain('dossier blanc');
    expect(licence.requirementsFr.join(' ')).toContain('TCF DAP');
    expect(licence.requirementsFr.join(' ')).toContain('Aucune moyenne minimale');
    expect(licence.requirementsFr.join(' ')).not.toMatch(/\d{2}\/20/);
    expect(master.requirementsFr[0]).toContain('Science politique');
    expect(master.requirementsFr.join(' ')).toContain('Études en France');
    expect(master.requirementsFr.join(' ')).toContain('Licence ou diplôme équivalent');
    expect(master.requirementsFr.join(' ')).toContain('Licences conseillées');
    expect(master.requirementsFr.join(' ')).not.toMatch(/\d{2}\/20/);
    expect(master.requirementsEn).toHaveLength(master.requirementsFr.length);
  });

  it('ne liste sur l’établissement que les niveaux réellement présents', () => {
    expect(plan.institutions[0].studyLevels).toEqual(['Bachelor', 'Master']);
    const bachelorOnly = planEefImport(
      {
        ...CATALOG,
        universities: [{ institution: INSTITUTION, programs: [LICENCE] }],
      },
      'france',
    );
    expect(bachelorOnly.institutions[0].studyLevels).toEqual(['Bachelor']);
  });

  it('laisse les périodes de rentrée vides', () => {
    // Les dates de campagne varient par pays et par procédure : elles sont
    // servies par /config/app, jamais figées dans une ligne de catalogue.
    expect(plan.institutions[0].intakePeriods).toEqual([]);
  });

  it('remplit chaque champ bilingue des deux côtés', () => {
    const institution = plan.institutions[0];
    expect(institution.overviewFr).not.toBe('');
    expect(institution.overviewEn).not.toBe('');
    expect(institution.overviewFr).toContain('34 926'.replace(/ /g, ' '));
    expect(institution.overviewEn).toContain('34,926');
    for (const row of plan.programs) {
      for (const key of ['nameEn', 'levelEn', 'durationEn', 'tuitionEn', 'languageEn'] as const) {
        expect(row[key]).not.toBe('');
      }
    }
  });
});

class RecordingWriter implements EefCatalogWriter {
  readonly institutions: PlannedInstitution[] = [];
  readonly programs: PlannedProgram[] = [];
  constructor(private readonly existing: ReadonlySet<string>) {}

  async createInstitutionIfAbsent(row: PlannedInstitution) {
    if (this.existing.has(row.id)) return 'existing' as const;
    this.institutions.push(row);
    return 'created' as const;
  }

  async createProgramIfAbsent(row: PlannedProgram) {
    if (this.existing.has(row.id)) return 'existing' as const;
    this.programs.push(row);
    return 'created' as const;
  }
}

describe('importEefCatalog', () => {
  it('crée ce qui manque et compte ce qu’il n’a PAS réaligné', () => {
    // Le nom du compteur compte : « sauté » se lit « rien à faire » alors
    // qu'il veut dire « potentiellement périmé ».
    const writer = new RecordingWriter(new Set(['eef-prog-master']));
    return importEefCatalog(planEefImport(CATALOG, 'france'), writer).then(
      (summary) => {
        expect(summary).toEqual({
          catalogVersion: '1.0.0',
          institutionsAttempted: 1,
          institutionsCreated: 1,
          institutionsExistingNotUpdated: 0,
          programsAttempted: 2,
          programsCreated: 1,
          programsExistingNotUpdated: 1,
        });
        expect(writer.programs.map((row) => row.id)).toEqual(['eef-prog-licence']);
      },
    );
  });

  it('n’écrit rien quand tout existe déjà', async () => {
    const writer = new RecordingWriter(
      new Set(['eef-univ-0353074b', 'eef-prog-licence', 'eef-prog-master']),
    );
    const summary = await importEefCatalog(
      planEefImport(CATALOG, 'france'),
      writer,
    );
    expect(summary.institutionsCreated).toBe(0);
    expect(summary.programsCreated).toBe(0);
    expect(writer.institutions).toEqual([]);
  });
});
