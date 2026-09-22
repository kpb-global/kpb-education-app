import * as fs from 'node:fs';
import * as path from 'node:path';

import {
  admissionLineOf,
  planInstitutionLogoBackfill,
  planProgramRequirementsBackfill,
  procedureLineOf,
} from './eef-catalog.backfill';
import { planEefImport, type PlannedInstitution, type PlannedProgram } from './eef-catalog.importer';
import type {
  EefCatalog,
  EefInstitutionRecord,
  EefProgramRecord,
} from './eef-catalog.types';

const SCRIPT = fs.readFileSync(
  path.join(__dirname, '../../../../scripts/backfill-eef-enrichment.ts'),
  'utf8',
);
const CODE = SCRIPT.replace(/\/\*[\s\S]*?\*\//g, '').replace(/\/\/.*$/gm, '');

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
  logo: {
    url: 'https://upload.wikimedia.org/wikipedia/commons/a/ab/Logo.svg',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:Logo.svg',
    licence: 'CC BY-SA 4.0',
    wikidataId: 'Q123',
    trademarked: false,
  },
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
  admissionCohort: {
    session: '2025',
    admittedNeobac: 120,
    sansMention: 10,
    assezBien: 20,
    bien: 70,
    tresBien: 15,
    tresBienFelicitations: 5,
    accessRatePct: 42,
    lastCalledRank: 80,
    sourceUrl: 'https://data.enseignementsup-recherche.gouv.fr/explore/dataset/fr-esr-parcoursup/',
  },
};

const CATALOG: EefCatalog = {
  manifest: {
    catalogVersion: '1.2.0',
    generatedAt: '2026-09-21T00:00:00.000Z',
    countryId: 'france',
    institutionCount: 1,
    programCount: 1,
    sources: [],
  },
  universities: [{ institution: INSTITUTION, programs: [LICENCE] }],
};

const plannedInstitution: PlannedInstitution = planEefImport(
  CATALOG,
  'france',
).institutions[0];
const plannedProgram: PlannedProgram = planEefImport(CATALOG, 'france').programs[0];

function v1Requirements(
  planned: readonly string[],
  lang: 'fr' | 'en',
): string[] {
  const procedure = procedureLineOf(planned, lang);
  if (procedure == null) return [];
  const start = planned.indexOf(procedure);
  return planned
    .slice(start)
    .filter(
      (line) =>
        lang === 'fr'
          ? !line.includes('Aucune moyenne minimale officielle')
          : !line.includes('No official minimum grade'),
    );
}

const v1RequirementsFr = v1Requirements(plannedProgram.requirementsFr, 'fr');
const v1RequirementsEn = v1Requirements(plannedProgram.requirementsEn, 'en');

describe('planInstitutionLogoBackfill', () => {
  it('écrit le triple logo seulement si les trois colonnes sont encore nulles', () => {
    const plan = planInstitutionLogoBackfill(plannedInstitution, {
      id: plannedInstitution.id,
      logoUrl: null,
      logoSourceUrl: null,
      logoLicence: null,
    });
    expect(plan.write).toEqual({
      logoUrl: plannedInstitution.logoUrl,
      logoSourceUrl: INSTITUTION.logo?.sourceUrl,
      logoLicence: INSTITUTION.logo?.licence,
    });
    expect(plan.write?.logoUrl).toContain('/thumb/');
    expect(plan.write?.logoUrl).toMatch(/\.png$/);
  });

  it('n’écrase pas un logo déjà saisi, même incomplet', () => {
    const plan = planInstitutionLogoBackfill(plannedInstitution, {
      id: plannedInstitution.id,
      logoUrl: 'https://cdn.example/custom.png',
      logoSourceUrl: null,
      logoLicence: null,
    });
    expect(plan.write).toBeNull();
    expect(plan.keptReason).toBe('logo_partially_set');
  });

  it('ne comble pas un établissement sans fichier libre', () => {
    const bare: PlannedInstitution = { ...plannedInstitution, logoUrl: null, logoSourceUrl: null, logoLicence: null };
    const plan = planInstitutionLogoBackfill(bare, {
      id: bare.id,
      logoUrl: null,
      logoSourceUrl: null,
      logoLicence: null,
    });
    expect(plan.write).toBeNull();
    expect(plan.keptReason).toBe('no_reusable_logo');
  });

  it('laisse à import le soin de créer une ligne absente', () => {
    expect(
      planInstitutionLogoBackfill(plannedInstitution, null).keptReason,
    ).toBe('absent');
  });
});

describe('planProgramRequirementsBackfill', () => {
  const unverified = {
    id: plannedProgram.id,
    isActive: false,
    lastVerifiedAt: null,
    requirementsFr: v1RequirementsFr,
    requirementsEn: v1RequirementsEn,
  };

  it('réécrit les exigences d’une ligne 1.0 encore machine', () => {
    const plan = planProgramRequirementsBackfill(plannedProgram, unverified);
    expect(plan.writeFr).toEqual(plannedProgram.requirementsFr);
    expect(plan.writeEn).toEqual(plannedProgram.requirementsEn);
    expect(plan.writeFr?.[0]).toContain('L1 - Droit');
    expect(plan.writeFr?.join(' ')).toMatch(/14\/20/);
    expect(plan.writeFr?.join(' ')).toContain("Ce n'est pas un seuil d'admission");
  });

  it('ne touche pas une ligne publiée ou déjà vérifiée', () => {
    expect(
      planProgramRequirementsBackfill(plannedProgram, {
        ...unverified,
        isActive: true,
      }).writeFr,
    ).toBeNull();
    expect(
      planProgramRequirementsBackfill(plannedProgram, {
        ...unverified,
        lastVerifiedAt: new Date('2026-09-21T00:00:00.000Z'),
      }).keptReasonFr,
    ).toBe('verified_or_published');
  });

  it('ne touche pas une ligne dont la prose de procédure a été éditée', () => {
    const plan = planProgramRequirementsBackfill(plannedProgram, {
      ...unverified,
      requirementsFr: ['Dossier à déposer sur le site de la fac.'],
      requirementsEn: ['Apply on the school website.'],
    });
    expect(plan.writeFr).toBeNull();
    expect(plan.writeEn).toBeNull();
    expect(plan.keptReasonFr).toBe('requirements_no_longer_generated');
  });

  it('est idempotent une fois le repère posé', () => {
    const plan = planProgramRequirementsBackfill(plannedProgram, {
      ...unverified,
      requirementsFr: plannedProgram.requirementsFr,
      requirementsEn: plannedProgram.requirementsEn,
    });
    expect(plan.writeFr).toBeNull();
    expect(plan.writeEn).toBeNull();
    expect(plan.keptReasonFr).toBe('already_complete');
  });
});

describe('repères de phrases du plan', () => {
  it('trouve la procédure et le repère d’admission dans les exigences générées', () => {
    expect(procedureLineOf(plannedProgram.requirementsFr, 'fr')).toContain(
      'dossier blanc',
    );
    expect(admissionLineOf(plannedProgram.requirementsFr, 'fr')).toContain(
      'Aucune moyenne minimale officielle',
    );
    expect(procedureLineOf(plannedProgram.requirementsEn, 'en')).toContain(
      'white form',
    );
    expect(admissionLineOf(plannedProgram.requirementsEn, 'en')).toContain(
      'No official minimum grade',
    );
  });
});

describe('script backfill-eef-enrichment', () => {
  it('ne se déclare jamais vérifié et ne publie pas', () => {
    const writes = [...CODE.matchAll(/data:\s*\{([^}]*)\}/g)].map((m) => m[1]);
    expect(writes.length).toBeGreaterThan(0);
    for (const data of writes) {
      expect(data).not.toContain('lastVerifiedAt');
      expect(data).not.toContain('isActive');
    }
  });

  it('chaque écriture logo exige les trois colonnes encore nulles', () => {
    expect(CODE).toContain('logoUrl: null');
    expect(CODE).toContain('logoSourceUrl: null');
    expect(CODE).toContain('logoLicence: null');
  });

  it('chaque écriture d’exigences porte sa condition dans le WHERE', () => {
    expect(CODE).toContain('isActive: false');
    expect(CODE).toContain('lastVerifiedAt: null');
    expect(CODE).toContain('requirementsFr: { has: decision.procedureFr }');
    expect(CODE).toContain('requirementsEn: { has: decision.procedureEn }');
    expect(CODE).not.toMatch(/updateMany\(\{\s*where:\s*\{\s*id:[^,}]*\}\s*,/);
  });

  it('refuse d’écrire sans --dry-run ou --apply', () => {
    expect(CODE).toContain("dryRun === apply");
  });
});
