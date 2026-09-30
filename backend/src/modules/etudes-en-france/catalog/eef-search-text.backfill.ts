// ─────────────────────────────────────────────────────────────────────────────
// Rattrapage du texte cherchable et du sigle sur les lignes déjà importées.
//
// Les colonnes `Program.searchText` et `Institution.acronym` ont été ajoutées
// APRÈS le premier import : les ~10 500 lignes en base les ont nulles. Tant
// qu'elles le sont, la recherche retombe sur la comparaison brute — elle ne
// trouve jamais moins qu'avant, mais elle ne trouve pas non plus « genie » pour
// « Génie civil ».
//
// Ce module ne fait que DÉCIDER. L'écriture est dans
// `scripts/backfill-eef-search-text.ts`, qui ne comble que les colonnes vides :
// il est rejouable, et il n'écrase jamais une valeur posée par l'import ou par
// quelqu'un.
// ─────────────────────────────────────────────────────────────────────────────
import { programSearchText } from './eef-search-text';
import type { EefCatalog } from './eef-catalog.types';

export interface ProgramSearchRow {
  readonly id: string;
  readonly nameFr: string;
  readonly campusCity: string | null;
}

export interface SearchTextEntry {
  readonly id: string;
  readonly searchText: string;
}

/// Le texte cherchable de chaque ligne, calculé à partir de la LIGNE ELLE-MÊME
/// (l'intitulé et la ville que la base sert), jamais du fichier du dépôt : une
/// ligne dont l'intitulé a été corrigé depuis l'import est cherchée sous son
/// intitulé d'aujourd'hui.
export function planSearchTextBackfill(
  rows: readonly ProgramSearchRow[],
): SearchTextEntry[] {
  return rows
    .map((row) => ({
      id: row.id,
      searchText: programSearchText(row.nameFr, row.campusCity),
    }))
    // Une ligne dont le texte normalisé serait vide (intitulé fait de
    // ponctuation) ne se trouverait par aucun mot : on la laisse nulle, ce qui
    // garde la comparaison brute.
    .filter((entry) => entry.searchText !== '');
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
