import { loadEefCatalog } from './eef-catalog.loader';
import {
  EEF_HEALTH_CYCLE,
  healthAccessYearWhere,
  isHealthAccessYear,
} from './eef-health-access';

describe('isHealthAccessYear', () => {
  it('vrai pour une L.AS et un PASS', () => {
    expect(isHealthAccessYear({ cycle: 'sante', nameFr: 'L1 - Droit' })).toBe(true);
    expect(
      isHealthAccessYear({
        cycle: 'sante',
        nameFr: "L1 - Parcours d'Accès Spécifique Santé (PASS)",
      }),
    ).toBe(true);
  });

  it('faux pour un diplôme paramédical de la même famille', () => {
    expect(
      isHealthAccessYear({ cycle: 'sante', nameFr: "Certificat de capacité d'Orthophoniste" }),
    ).toBe(false);
    expect(isHealthAccessYear({ cycle: 'sante', nameFr: 'BTS - Opticien-Lunetier' })).toBe(false);
  });

  it('faux pour la même licence hors de la famille santé', () => {
    expect(isHealthAccessYear({ cycle: 'licence1', nameFr: 'L1 - Droit' })).toBe(false);
    expect(isHealthAccessYear({ cycle: null, nameFr: 'L1 - Droit' })).toBe(false);
  });

  it('la clause Prisma dit la même chose', () => {
    expect(healthAccessYearWhere()).toEqual({
      cycle: 'sante',
      nameFr: { startsWith: 'L1 - ' },
    });
  });
});

describe('le catalogue versionné', () => {
  // La définition repose sur l'intitulé : si l'import change sa façon d'écrire
  // les premières années, ce test le dit avant qu'une recherche « médecine » ne
  // rende plus rien.
  const programs = loadEefCatalog().universities.flatMap(
    (university) => university.programs,
  );
  const health = programs.filter((program) => program.cycle === EEF_HEALTH_CYCLE);
  const access = health.filter((program) => isHealthAccessYear(program));

  it('sépare la famille santé en 589 PASS et L.AS et 61 diplômes paramédicaux', () => {
    expect(health).toHaveLength(650);
    expect(access).toHaveLength(589);
  });

  it('compte tous les PASS parmi les accès santé', () => {
    const pass = health.filter((program) => program.nameFr.includes('(PASS)'));
    expect(pass).toHaveLength(205);
    expect(pass.every((program) => isHealthAccessYear(program))).toBe(true);
  });

  it('n’y range aucune formation hors de la famille santé', () => {
    expect(
      programs.filter(
        (program) => program.cycle !== EEF_HEALTH_CYCLE && isHealthAccessYear(program),
      ),
    ).toEqual([]);
  });
});
