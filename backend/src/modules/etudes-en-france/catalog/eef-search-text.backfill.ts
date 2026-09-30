// ─────────────────────────────────────────────────────────────────────────────
// Rattrapage du texte cherchable et du sigle sur les lignes déjà importées.
//
// Les colonnes `Program.searchText` et `Institution.acronym` ont été ajoutées
// APRÈS le premier import : les ~10 500 lignes en base les ont nulles. Tant
// qu'elles le sont, la recherche retombe sur la comparaison brute — elle ne
// trouve jamais moins qu'avant, mais elle ne trouve pas non plus « genie » pour
// « Génie civil ».
//
// `searchText` est DÉRIVÉ de l'intitulé et de la ville : le recalculer est
// toujours correct, et un texte qui ne correspond plus à sa ligne (intitulé
// renommé par une voie qui ne le recalcule pas) rend des résultats FAUX — l'ancien
// mot trouve la formation, le nouveau la manque. Le rattrapage comble donc les
// vides ET répare les textes périmés.
//
// Ce module ne fait que DÉCIDER. L'écriture est dans
// `scripts/backfill-eef-search-text.ts`, qui ne remplace une valeur que si la
// ligne n'a pas bougé depuis la lecture (comparaison-échange, dans le `WHERE`) :
// il est rejouable, et il n'écrase jamais une modification concurrente. Les
// sigles, eux, ne viennent pas de la ligne mais du dépôt : ils ne comblent que
// les vides.
// ─────────────────────────────────────────────────────────────────────────────
import { programSearchText } from './eef-search-text';
import type { EefCatalog } from './eef-catalog.types';

export interface ProgramSearchRow {
  readonly id: string;
  readonly nameFr: string;
  readonly campusCity: string | null;
  /// Ce que la base porte aujourd'hui : nul (à combler) ou une valeur (à vérifier).
  readonly searchText: string | null;
}

export interface SearchTextEntry {
  readonly id: string;
  /// La valeur à écrire.
  readonly searchText: string;
  /// Ce qu'il y avait à la lecture, pour la comparaison-échange de l'écriture.
  readonly previous: string | null;
  readonly nameFr: string;
  readonly campusCity: string | null;
}

/// Les lignes dont le texte cherchable manque ou ne correspond plus à la ligne,
/// avec la valeur à écrire. Calculée à partir de la LIGNE ELLE-MÊME (l'intitulé et
/// la ville que la base sert), jamais du fichier du dépôt : une ligne dont
/// l'intitulé a été corrigé depuis l'import est cherchée sous son intitulé
/// d'aujourd'hui. Une ligne déjà à jour n'y figure pas : rejouer ne réécrit rien.
export function planSearchTextBackfill(
  rows: readonly ProgramSearchRow[],
): SearchTextEntry[] {
  return rows
    .map((row) => ({
      id: row.id,
      searchText: programSearchText(row.nameFr, row.campusCity),
      previous: row.searchText,
      nameFr: row.nameFr,
      campusCity: row.campusCity,
    }))
    // Une ligne dont le texte normalisé serait vide (intitulé fait de
    // ponctuation) ne se trouverait par aucun mot : on ne lui en écrit pas, ce
    // qui garde la comparaison brute.
    .filter((entry) => entry.searchText !== '')
    .filter((entry) => entry.searchText !== entry.previous);
}

export interface AcronymEntry {
  readonly id: string;
  readonly acronym: string;
}

/// Les sigles que le ministère publie, par identifiant d'établissement.
export function planAcronymBackfill(catalog: EefCatalog): AcronymEntry[] {
  return catalog.universities.flatMap(({ institution }) => {
    const acronym = institution.acronym?.trim();
    return acronym ? [{ id: institution.id, acronym }] : [];
  });
}
