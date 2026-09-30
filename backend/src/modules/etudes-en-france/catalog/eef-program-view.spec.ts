import type { Program } from '@prisma/client';

import { mapProgram } from '../../catalog/catalog.mapper';
import { mapEefInstitutionSummary, mapEefProgram } from './eef-program-view';
import type { PublishedInstitution } from './eef-published-institutions';

const institution: PublishedInstitution = {
  id: 'eef-univ-1',
  nameFr: 'Université de Rennes',
  nameEn: 'University of Rennes',
  acronym: 'UR',
  locationFr: 'Rennes, Bretagne',
  locationEn: 'Rennes, Brittany',
  institutionType: 'universite_publique',
  websiteUrl: 'https://www.univ-rennes.fr',
  logoUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/a/ab/Logo.svg/320px-Logo.svg.png',
  logoSourceUrl: 'https://commons.wikimedia.org/wiki/File:Logo.svg',
  logoLicence: 'CC0',
};

function program(over: Partial<Program> = {}): Program {
  return {
    id: 'eef-prog-1',
    institutionId: 'eef-univ-1',
    countryId: 'france',
    fieldId: 'd07',
    nameFr: 'L1 - Droit',
    nameEn: 'L1 - Droit',
    levelFr: 'Bac+3 — Licence',
    levelEn: 'Bac+3 — Bachelor',
    durationFr: '3 ans',
    durationEn: '3 years',
    tuitionFr: 'x',
    tuitionEn: 'x',
    languageFr: 'Français',
    languageEn: 'French',
    requirementsFr: [],
    requirementsEn: [],
    campusOfferings: null,
    minGpaRequired: null,
    tuitionMinEur: null,
    applicationDeadline: null,
    teachingLanguages: ['fr'],
    procedureType: 'dap_blanche',
    cycle: 'licence1',
    selectivity: 'non_selective',
    formationCode: '12345',
    campusCity: 'Rennes',
    frenchLevelRequired: null,
    applicationFeeEur: null,
    recommendedBachelors: [],
    recommendedFieldIds: [],
    admissionModes: ['Dossier'],
    searchText: 'l1 droit rennes',
    isActive: true,
    lastVerifiedAt: null,
    sourceUrl: 'https://www.parcoursup.gouv.fr/x',
    verifiedById: null,
    verifiedByName: null,
    createdAt: new Date(0),
    updatedAt: new Date(0),
    ...over,
  } as Program;
}

describe('mapEefProgram', () => {
  const byId = new Map([[institution.id, institution]]);

  it('reprend le corps de mapProgram tel quel, en ajoutant seulement', () => {
    const row = program();
    const mapped = mapEefProgram(row, byId);
    // Un client qui ne connaît que mapProgram continue de tout lire.
    expect(mapped).toMatchObject(mapProgram(row));
  });

  it('sert la procédure, le cycle et la sélectivité', () => {
    expect(mapEefProgram(program(), byId)).toMatchObject({
      procedureType: 'dap_blanche',
      cycle: 'licence1',
      selectivity: 'non_selective',
      campusCity: 'Rennes',
      formationCode: '12345',
      admissionModes: ['Dossier'],
      recommendedBachelors: [],
    });
  });

  it('nomme l’établissement, le situe et donne son logo AVEC sa licence', () => {
    const { institution: summary } = mapEefProgram(program(), byId);
    expect(summary).toMatchObject({
      id: 'eef-univ-1',
      name: { fr: 'Université de Rennes', en: 'University of Rennes' },
      acronym: 'UR',
      location: { fr: 'Rennes, Bretagne', en: 'Rennes, Brittany' },
      institutionType: 'universite_publique',
      logoSourceUrl: 'https://commons.wikimedia.org/wiki/File:Logo.svg',
      logoLicence: 'CC0',
    });
    // Le logo est servi à la largeur standard de Wikimedia (330 px), pas à celle
    // que l'import avait écrite.
    expect(summary!.logoUrl).toContain('330px');
  });

  it('ne sert ni la présentation, ni l’effectif, ni le code UAI', () => {
    const summary = mapEefInstitutionSummary(institution) as Record<string, unknown>;
    for (const key of ['overview', 'overviewFr', 'uaiCode', 'studyLevels', 'programIds']) {
      expect(summary).not.toHaveProperty(key);
    }
  });

  it('sert un établissement nul plutôt que de planter quand il manque', () => {
    expect(mapEefProgram(program(), new Map()).institution).toBeNull();
  });

  it('un établissement sans logo sert un logo nul, pas une URL fabriquée', () => {
    const bare = { ...institution, logoUrl: null, logoSourceUrl: null, logoLicence: null };
    const { institution: summary } = mapEefProgram(program(), new Map([[bare.id, bare]]));
    expect(summary).toMatchObject({ logoUrl: null, logoSourceUrl: null, logoLicence: null });
  });
});
