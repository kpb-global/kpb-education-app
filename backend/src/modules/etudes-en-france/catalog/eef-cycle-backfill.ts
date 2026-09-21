// ─────────────────────────────────────────────────────────────────────────────
// Le rattrapage du `cycle` sur les lignes déjà importées — la moitié pure.
//
// POURQUOI UN RATTRAPAGE EST NÉCESSAIRE
//
// La colonne `cycle` arrive APRÈS le premier import. Les lignes créées avant
// reçoivent donc `NULL`, et l'import ne les répare pas : il est « création
// seule » par principe, parce qu'un administrateur a pu corriger une fiche à
// la main et qu'un import ne doit pas écraser une correction humaine.
//
// Conséquence, si on ne fait rien : la facette « cycle » reste vide et
// `cycle=master` rend zéro résultat sur un catalogue plein. La colonne
// existerait sans que rien ne la remplisse — exactement le défaut que la
// mise en attente avait déjà eu (`isActive` écrit, jamais lu).
//
// POURQUOI PAS UNE MIGRATION SQL
//
// Une migration ne connaît pas le cycle d'une formation. Le dépôt, si : il est
// dans les 70 fichiers versionnés. Le rattrapage les relit donc et écrit ce
// que la collecte a déjà décidé, plutôt que de déduire un cycle en découpant
// `levelFr` — ce que cette colonne existe précisément pour éviter.
//
// POURQUOI SEULEMENT LES `NULL`
//
// Écrire par-dessus une valeur existante ferait de ce script un second import,
// avec le pouvoir d'écraser sans les garde-fous de l'import. Il ne comble que
// les trous, et il est donc rejouable sans conséquence.
// ─────────────────────────────────────────────────────────────────────────────
import type { EefCatalog } from './eef-catalog.types';

export interface CycleBackfillEntry {
  readonly id: string;
  readonly cycle: string;
}

/**
 * Le plan : un couple (identifiant, cycle) par formation du catalogue
 * versionné. C'est l'appelant qui restreint ensuite aux lignes dont le cycle
 * est `NULL` — la restriction doit s'exprimer dans le `WHERE`, seule forme
 * réellement atomique : entre la lecture du plan et l'écriture, un import peut
 * avoir renseigné la colonne.
 */
export function planCycleBackfill(catalog: EefCatalog): CycleBackfillEntry[] {
  const entries: CycleBackfillEntry[] = [];
  for (const file of catalog.universities) {
    for (const program of file.programs) {
      entries.push({ id: program.id, cycle: program.cycle });
    }
  }
  return entries;
}

export interface CycleBackfillWriter {
  /**
   * Doit s'exécuter comme `UPDATE … SET cycle = ? WHERE id = ? AND cycle IS
   * NULL`, et rendre le nombre de lignes touchées. Comparer en mémoire plutôt
   * que dans le `WHERE` rouvrirait la fenêtre que cette garantie ferme.
   */
  fillIfNull(entry: CycleBackfillEntry): Promise<number>;
}

export interface CycleBackfillSummary {
  readonly attempted: number;
  readonly filled: number;
  /// Lignes que le rattrapage n'a PAS touchées : soit elles portaient déjà un
  /// cycle, soit elles n'existent pas en base. Le compteur les nomme ensemble
  /// parce qu'un `UPDATE` ne sait pas les distinguer — et parce que les deux
  /// cas veulent dire la même chose ici : rien à faire.
  readonly untouched: number;
}

export async function backfillEefCycles(
  entries: readonly CycleBackfillEntry[],
  writer: CycleBackfillWriter,
): Promise<CycleBackfillSummary> {
  let filled = 0;
  for (const entry of entries) {
    filled += await writer.fillIfNull(entry);
  }
  return {
    attempted: entries.length,
    filled,
    untouched: entries.length - filled,
  };
}
