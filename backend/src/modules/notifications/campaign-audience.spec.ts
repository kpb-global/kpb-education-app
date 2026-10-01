import {
  EEF_SUSPENDED_COUNTRIES_TOKEN,
  resolveExcludedCountries,
} from './campaign-audience';

describe('resolveExcludedCountries', () => {
  it('lit une liste, dédoublonnée et sans blancs', () => {
    expect(
      resolveExcludedCountries([' Niger ', 'NE', 'Niger', '', '  ']),
    ).toEqual(['Niger', 'NE']);
  });

  it('lit une chaîne séparée par des virgules', () => {
    expect(resolveExcludedCountries('Niger, NE ,Mali')).toEqual([
      'Niger',
      'NE',
      'Mali',
    ]);
  });

  it("ignore ce qui n'est pas du texte", () => {
    expect(resolveExcludedCountries([1, null, {}, 'Niger'])).toEqual(['Niger']);
    expect(resolveExcludedCountries(undefined)).toEqual([]);
    expect(resolveExcludedCountries(42)).toEqual([]);
    expect(resolveExcludedCountries({})).toEqual([]);
  });

  describe('le jeton « eef_suspended »', () => {
    it("suit la liste de l'exploitation — celle que /config/app sert", () => {
      const env = { KPB_EEF_SUSPENDED_COUNTRIES: 'Niger, NE' };
      expect(
        resolveExcludedCountries([EEF_SUSPENDED_COUNTRIES_TOKEN], env),
      ).toEqual(['Niger', 'NE']);
    });

    it("se combine avec d'autres pays, sans doublon", () => {
      const env = { KPB_EEF_SUSPENDED_COUNTRIES: 'Niger' };
      expect(
        resolveExcludedCountries(
          ['Mali', 'ÉEF_SUSPENDED', 'eef_suspended', 'Niger'],
          env,
        ),
      ).toEqual(['Mali', 'ÉEF_SUSPENDED', 'Niger']);
    });

    it('accepté en chaîne et quelle que soit la casse', () => {
      const env = { KPB_EEF_SUSPENDED_COUNTRIES: 'Niger' };
      expect(resolveExcludedCountries('EEF_Suspended', env)).toEqual(['Niger']);
    });

    // Liste de l'exploitation vide : le jeton n'exclut personne. Les audiences
    // qui l'exigent (`all_students_except_countries`) tombent alors à zéro
    // destinataire plutôt qu'à « tous » — voir l'exécuteur.
    it('ne produit rien quand la liste est vide', () => {
      expect(
        resolveExcludedCountries([EEF_SUSPENDED_COUNTRIES_TOKEN], {}),
      ).toEqual([]);
    });
  });
});
