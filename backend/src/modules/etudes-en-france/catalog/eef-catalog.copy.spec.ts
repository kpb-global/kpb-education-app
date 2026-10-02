// La prose corrigée le 02/10/2026 (`docs/eef-dossier-relecture-procedures.md`,
// § « Réponses de recherche ») : ce que chaque correction doit dire, et surtout
// ce qu'elle ne doit plus dire.
import { programRequirements, programSummary } from './eef-catalog.copy';
import type { EefProgramRecord } from './eef-catalog.types';

const L1: EefProgramRecord = {
  id: 'eef-prog-1',
  institutionId: 'eef-univ-1',
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
  sourceUrl: 'https://dossierappel.parcoursup.fr/x',
};

const fr = (program: EefProgramRecord) =>
  programRequirements(program).map((line) => line.fr).join('\n');
const en = (program: EefProgramRecord) =>
  programRequirements(program).map((line) => line.en).join('\n');

describe('une L1 non sélective en DAP (point 5)', () => {
  it('ne dit plus que la capacité d’accueil est la seule limite', () => {
    // Faux pour un candidat DAP : l'université examine le dossier et peut le refuser.
    expect(fr(L1)).not.toContain("la capacité d'accueil est la limite");
    expect(fr(L1)).not.toContain("La capacité d'accueil limite les places");
    expect(en(L1)).not.toContain('intake capacity is the limit');
    expect(en(L1)).not.toContain('Intake capacity limits places');
  });

  it('dit que « non sélective » est la catégorie Parcoursup, et ce qui vaut en DAP', () => {
    expect(fr(L1)).toContain('Classée non sélective sur Parcoursup, pour les élèves de terminale française.');
    expect(fr(L1)).toContain("l'université examine ton dossier et peut le refuser");
    expect(fr(L1)).toContain("l'ouverture aux candidats DAP varient selon l'université");
    expect(en(L1)).toContain('the university reviews your file and may turn it down');
    expect(programSummary(L1).fr).toContain("en DAP, l'université examine ton dossier");
  });

  it('vaut pour PASS / L.AS comme pour toute L1, pas seulement pour la santé', () => {
    const pass: EefProgramRecord = { ...L1, cycle: 'sante', nameFr: 'L1 - Sciences de la vie' };
    expect(fr(pass)).toContain('Classée non sélective sur Parcoursup');
  });

  it('ne change pas la phrase d’une formation sélective', () => {
    const selective: EefProgramRecord = { ...L1, selectivity: 'selective' };
    expect(fr(selective)).toContain("Formation sélective : l'établissement arbitre entre les dossiers.");
    expect(fr(selective)).not.toContain('non sélective');
  });
});

describe('une formation hors procédure (point 6, et Sciences Po en 1re année)', () => {
  const engineering: EefProgramRecord = {
    ...L1,
    nameFr: "Formation d'ingénieur Bac + 5",
    cycle: 'ingenieur',
    level: 'Master',
    durationYears: 5,
    procedureType: 'hors_eef',
    selectivity: 'selective',
  };

  it('ne dit plus qu’elle « ne se demande pas par la procédure Études en France »', () => {
    expect(fr(engineering)).not.toContain('ne se demande pas par la procédure');
    expect(en(engineering)).not.toContain('is not part of the Études en France procedure');
  });

  it('renvoie vers l’établissement, et rappelle que le visa passe par Études en France', () => {
    expect(fr(engineering)).toContain("Admission propre à l'établissement (concours ou plateforme dédiée)");
    expect(fr(engineering)).toContain('le visa passe par Études en France (« Je suis déjà accepté »)');
    expect(fr(engineering)).toContain("admissions internationales de l'établissement");
    expect(en(engineering)).toContain('the visa goes through Études en France');
  });

  it('n’annonce aucun test de français : l’établissement le fixe', () => {
    expect(fr(engineering)).not.toContain('TCF DAP');
    expect(fr(engineering)).not.toContain('B2');
  });
});

describe('une formation sur Parcoursup (le DCG)', () => {
  const dcg: EefProgramRecord = {
    ...L1,
    nameFr: 'DCG - Diplôme de Comptabilité et de Gestion',
    fieldId: 'd02',
    procedureType: 'parcoursup',
    selectivity: 'selective',
  };

  it('ne la réserve plus aux résidents en France', () => {
    expect(fr(dcg)).not.toContain('candidats résidant en France');
    expect(en(dcg)).not.toContain('applicants residing in France');
    expect(fr(dcg)).toContain("Candidature sur Parcoursup, y compris depuis l'étranger");
    expect(fr(dcg)).toContain('ne passe pas par la demande');
    expect(en(dcg)).toContain('Apply on Parcoursup, including from abroad');
  });
});

describe('une CUPGE (procédure Études en France hors DAP)', () => {
  it('suit la phrase et le niveau de français de la procédure Études en France', () => {
    const cupge: EefProgramRecord = {
      ...L1,
      nameFr: 'CUPGE - Informatique',
      fieldId: 'd01',
      procedureType: 'eef',
      selectivity: 'selective',
    };
    expect(fr(cupge)).toContain('Candidature par la procédure « Études en France »');
    expect(fr(cupge)).toContain("Le niveau de français exigé est fixé par l'établissement");
    expect(fr(cupge)).not.toContain('Demande d\'admission préalable');
  });
});
