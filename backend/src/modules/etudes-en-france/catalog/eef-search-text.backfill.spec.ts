import {
  planAcronymBackfill,
  planSearchTextBackfill,
  type ProgramSearchRow,
} from './eef-search-text.backfill';
import type { EefCatalog, EefInstitutionRecord } from './eef-catalog.types';

describe('planSearchTextBackfill', () => {
  const row = (over: Partial<ProgramSearchRow> = {}): ProgramSearchRow => ({
    id: 'p1',
    nameFr: 'Master — Génie civil',
    campusCity: 'Besançon',
    searchText: null,
    ...over,
  });

  it('comble un texte nul, calculé depuis la ligne elle-même', () => {
    expect(planSearchTextBackfill([row()])).toEqual([
      {
        id: 'p1',
        searchText: 'master genie civil besancon',
        previous: null,
        nameFr: 'Master — Génie civil',
        campusCity: 'Besançon',
      },
    ]);
  });

  it('tolère une ville absente', () => {
    const [entry] = planSearchTextBackfill([
      row({ id: 'p2', nameFr: 'L1 - Droit', campusCity: null }),
    ]);
    expect(entry.searchText).toBe('l1 droit');
  });

  // Le défaut relevé en revue : `searchText` est dérivé, et un intitulé renommé
  // sans que le texte suive rend des résultats FAUX — l'ancien mot trouve la
  // formation, le nouveau la manque. Le rattrapage le répare.
  it('répare un texte PÉRIMÉ : la ligne a été renommée, le texte est resté', () => {
    const [entry] = planSearchTextBackfill([
      row({ nameFr: 'Économie', campusCity: 'Rennes', searchText: 'droit rennes' }),
    ]);
    expect(entry).toMatchObject({
      searchText: 'economie rennes',
      previous: 'droit rennes',
      nameFr: 'Économie',
      campusCity: 'Rennes',
    });
  });

  it('ne touche pas une ligne déjà à jour : rejouer ne réécrit rien', () => {
    expect(
      planSearchTextBackfill([row({ searchText: 'master genie civil besancon' })]),
    ).toEqual([]);
  });

  it('garde la valeur lue, pour que l\'écriture soit une comparaison-échange', () => {
    const [entry] = planSearchTextBackfill([row({ searchText: 'ancien' })]);
    expect(entry.previous).toBe('ancien');
  });

  it('laisse une ligne dont le texte serait vide comme elle est', () => {
    expect(
      planSearchTextBackfill([row({ nameFr: ' - ', campusCity: null })]),
    ).toEqual([]);
    expect(
      planSearchTextBackfill([
        row({ nameFr: ' - ', campusCity: null, searchText: 'reste' }),
      ]),
    ).toEqual([]);
  });

  it('ne plante pas sur une liste vide', () => {
    expect(planSearchTextBackfill([])).toEqual([]);
  });
});

describe('planAcronymBackfill', () => {
  const institution = (over: Partial<EefInstitutionRecord>): EefInstitutionRecord => ({
    id: 'eef-univ-1',
    uai: '0000000A',
    nameFr: 'Université',
    nameEn: 'University',
    acronym: null,
    city: 'Rennes',
    department: 'Ille-et-Vilaine',
    region: 'Bretagne',
    websiteUrl: 'https://exemple.fr',
    typology: null,
    enrolment: null,
    sourceUrl: 'https://exemple.fr/source',
    ...over,
  } as EefInstitutionRecord);

  const catalog = (...institutions: EefInstitutionRecord[]): EefCatalog =>
    ({
      manifest: {} as never,
      universities: institutions.map((i) => ({ institution: i, programs: [] })),
    }) as EefCatalog;

  it('ne garde que les établissements qui publient un sigle', () => {
    expect(
      planAcronymBackfill(
        catalog(
          institution({ id: 'a', acronym: 'UPEC' }),
          institution({ id: 'b', acronym: null }),
          institution({ id: 'c', acronym: '   ' }),
        ),
      ),
    ).toEqual([{ id: 'a', acronym: 'UPEC' }]);
  });
});
