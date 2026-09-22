// ─────────────────────────────────────────────────────────────────────────────
// Résoudre « la France » en base, à un seul endroit.
//
// POURQUOI CE FICHIER EXISTE
//
// `Country.id` n'est pas stable d'un semeur à l'autre — `fra` côté M5, `france`
// côté héritage (que le semeur M5 désactive), et les fiches partenaires
// écrivent encore `fra`. `Institution.countryId` n'étant pas une clé étrangère,
// écrire le mauvais identifiant produit des lignes orphelines qu'aucun filtre
// ne montre : le pire mode de panne, celui qui ne lève rien.
//
// On résout donc par le CODE. Mais le code non plus n'est pas ce qu'on croit :
// le référentiel M5 est en ISO 3166-1 **alpha-3** — `FRA`, `DEU`, `USA` — alors
// que la première version de cette résolution ne cherchait que `FR`. Sur une
// base normalement semée, elle ne trouvait donc RIEN : l'import refusait de
// démarrer et la recherche répondait 503 à toutes les requêtes.
//
// D'où cette fonction, partagée par l'import et par la recherche. La règle
// existait en double, et c'est exactement pour cela que le bug existait en
// double.
// ─────────────────────────────────────────────────────────────────────────────

/// Alpha-2 et alpha-3 sont acceptés : le référentiel M5 écrit `FRA`, et rien
/// n'interdit à une base plus ancienne d'avoir gardé `FR`.
export const FRANCE_COUNTRY_CODES = ['FR', 'FRA'] as const;

export interface CountryCodeRow {
  readonly id: string;
  readonly code: string;
}

export class FranceCountryResolutionError extends Error {}

/**
 * L'identifiant de la France parmi des pays ACTIFS.
 *
 * Refuse plutôt que de choisir : zéro correspondance veut dire que le
 * catalogue n'a nulle part où se rattacher, et plusieurs veut dire que deux
 * fiches France coexistent — les départager au hasard rattacherait la moitié
 * des formations à un pays que personne ne filtre.
 */
export function resolveFranceCountryId(
  activeCountries: readonly CountryCodeRow[],
): string {
  const codes = new Set<string>(FRANCE_COUNTRY_CODES);
  const matches = activeCountries.filter((country) =>
    codes.has((country.code ?? '').trim().toUpperCase()),
  );
  if (matches.length === 0) {
    throw new FranceCountryResolutionError(
      `Aucun pays actif de code ${FRANCE_COUNTRY_CODES.join(' ou ')} en base : `
      + "le catalogue n'a nulle part où se rattacher. Exécuter le semeur des "
      + "pays (npm run seed:countries-m5) avant l'import.",
    );
  }
  if (matches.length > 1) {
    throw new FranceCountryResolutionError(
      `Plusieurs pays actifs désignent la France : ${matches
        .map((country) => `${country.id} (${country.code})`)
        .join(', ')}. Trancher en base avant de réimporter.`,
    );
  }
  return matches[0].id;
}
