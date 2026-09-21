import { admissionGuidance } from './eef-catalog.copy';
import {
  cohortFromParcoursupRow,
  logoFromCommons,
} from './eef-catalog.admission';
import type { EefProgramRecord } from './eef-catalog.types';

const PROGRAM: EefProgramRecord = {
  id: 'eef-prog-1',
  institutionId: 'eef-univ-1',
  nameFr: 'L1 - Droit',
  level: 'Bachelor',
  cycle: 'licence1',
  fieldId: 'd07',
  fieldIsFallback: false,
  durationYears: 3,
  campusCity: 'Paris',
  procedureType: 'dap_blanche',
  selectivity: 'non_selective',
  formationCode: '47270',
  tracks: [],
  recommendedBachelors: [],
  admissionModes: [],
  dataset: 'parcoursup',
  sourceUrl: 'https://dossierappel.parcoursup.fr/x',
};

describe('cohortFromParcoursupRow', () => {
  it('accepte une ligne dont les mentions retombent sur les admis', () => {
    const cohort = cohortFromParcoursupRow({
      cod_aff_form: '47270',
      acc_neobac: 12,
      acc_sansmention: 6,
      acc_ab: 3,
      acc_b: 2,
      acc_tb: 1,
      acc_tbf: 0,
      taux_acces_ens: 36,
      ran_grp1: 43,
    });
    expect(cohort?.admittedNeobac).toBe(12);
    expect(cohort?.accessRatePct).toBe(36);
    expect(cohort?.lastCalledRank).toBe(43);
    expect(cohort?.session).toBe('2025');
  });

  it('écarte une ligne qui ne somme pas', () => {
    expect(
      cohortFromParcoursupRow({
        cod_aff_form: '1',
        acc_neobac: 10,
        acc_sansmention: 1,
        acc_ab: 1,
        acc_b: 1,
        acc_tb: 1,
        acc_tbf: 1,
      }),
    ).toBeNull();
  });
});

describe('admissionGuidance', () => {
  it('ne cite aucun seuil quand aucune statistique n’est jointe', () => {
    const text = admissionGuidance(PROGRAM).fr;
    expect(text).toContain('Aucune moyenne minimale');
    expect(text).not.toMatch(/\d{2}\/20/);
  });

  it('cite le plancher de la mention la plus fréquente, pas un seuil officiel', () => {
    const text = admissionGuidance({
      ...PROGRAM,
      admissionCohort: {
        session: '2025',
        sourceUrl:
          'https://data.enseignementsup-recherche.gouv.fr/explore/dataset/fr-esr-parcoursup/',
        admittedNeobac: 100,
        sansMention: 10,
        assezBien: 20,
        bien: 50,
        tresBien: 15,
        tresBienFelicitations: 5,
        accessRatePct: 40,
        lastCalledRank: 80,
      },
    }).fr;
    expect(text).toContain('Aucune moyenne minimale');
    expect(text).toContain('mention Bien');
    expect(text).toContain('14/20');
    expect(text).toContain("Ce n'est pas un seuil");
    expect(text).toContain('40 %');
  });

  it('ne tire pas d’objectif d’un effectif trop petit', () => {
    const text = admissionGuidance({
      ...PROGRAM,
      admissionCohort: {
        session: '2025',
        sourceUrl:
          'https://data.enseignementsup-recherche.gouv.fr/explore/dataset/fr-esr-parcoursup/',
        admittedNeobac: 4,
        sansMention: 0,
        assezBien: 0,
        bien: 4,
        tresBien: 0,
        tresBienFelicitations: 0,
        accessRatePct: null,
        lastCalledRank: null,
      },
    }).fr;
    expect(text).toContain('trop petit');
    expect(text).not.toMatch(/\d{2}\/20/);
  });
});

describe('logoFromCommons', () => {
  const base = {
    wikidataId: 'Q42',
    fileUrl: 'https://upload.wikimedia.org/wikipedia/commons/a/a.png',
    filePage: 'https://commons.wikimedia.org/wiki/File:A.png',
    restrictions: '',
  };

  it('garde un logo en domaine public et note la marque', () => {
    const logo = logoFromCommons({
      ...base,
      licence: 'Public domain',
      restrictions: 'trademarked',
    });
    expect(logo?.trademarked).toBe(true);
    expect(logo?.licence).toBe('Public domain');
  });

  it('refuse un logo sous copyright', () => {
    expect(
      logoFromCommons({ ...base, licence: 'Copyrighted', restrictions: '' }),
    ).toBeNull();
  });
});
