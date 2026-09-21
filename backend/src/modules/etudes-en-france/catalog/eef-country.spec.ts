import {
  FranceCountryResolutionError,
  resolveFranceCountryId,
} from './eef-country';

describe('resolveFranceCountryId', () => {
  it('reconnaît le code alpha-3 du référentiel M5', () => {
    // Régression : la première version ne cherchait que « FR », alors que le
    // semeur écrit « FRA ». Sur une base normalement semée, l'import refusait
    // de démarrer et la recherche répondait 503 à TOUTES les requêtes.
    expect(
      resolveFranceCountryId([
        { id: 'fra', code: 'FRA' },
        { id: 'mar', code: 'MAR' },
      ]),
    ).toBe('fra');
  });

  it('reconnaît aussi l’alpha-2 d’une base plus ancienne', () => {
    expect(resolveFranceCountryId([{ id: 'france', code: 'FR' }])).toBe('france');
  });

  it('ignore la casse et les espaces', () => {
    expect(resolveFranceCountryId([{ id: 'fra', code: ' fra ' }])).toBe('fra');
  });

  it('refuse quand la France est absente', () => {
    expect(() => resolveFranceCountryId([{ id: 'mar', code: 'MAR' }])).toThrow(
      FranceCountryResolutionError,
    );
    expect(() => resolveFranceCountryId([])).toThrow(FranceCountryResolutionError);
  });

  it('refuse plutôt que de départager deux France', () => {
    // Les départager au hasard rattacherait la moitié des formations à un pays
    // que personne ne filtre.
    expect(() =>
      resolveFranceCountryId([
        { id: 'fra', code: 'FRA' },
        { id: 'france', code: 'FR' },
      ]),
    ).toThrow(/Plusieurs pays actifs/);
  });
});
