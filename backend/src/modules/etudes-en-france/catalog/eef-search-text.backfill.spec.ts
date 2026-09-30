import { planAcronymBackfill, planSearchTextBackfill } from './eef-search-text.backfill';
import type { EefCatalog, EefInstitutionRecord } from './eef-catalog.types';

describe('planSearchTextBackfill', () => {
  it('calcule le texte de la ligne elle-même : intitulé et ville servis par la base', () => {
    expect(
      planSearchTextBackfill([
        { id: 'p1', nameFr: 'Master — Génie civil', campusCity: 'Besançon' },
        { id: 'p2', nameFr: 'L1 - Droit', campusCity: null },
      ]),
    ).toEqual([
      { id: 'p1', searchText: 'master genie civil besancon' },
      { id: 'p2', searchText: 'l1 droit' },
    ]);
  });

  it('laisse nulle une ligne dont le texte serait vide', () => {
    expect(
      planSearchTextBackfill([{ id: 'p1', nameFr: ' - ', campusCity: null }]),
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
