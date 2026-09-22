// ─────────────────────────────────────────────────────────────────────────────
// Les signaux d'admission publiés — la lecture, et son rattrapage.
//
// POURQUOI CE FICHIER EXISTE
//
// La shortlist doit classer deux formations par risque d'admission. Le seul
// classement que `selectivity` autorise est vide de sens : sur les 10 247
// lignes du catalogue, elle est CONSTANTE à l'intérieur d'un cycle — tous les
// masters, toutes les L2, toutes les L3, tous les BUT, tous les DEUST sont
// `selective`. Seule la L1 varie. Trier des masters là-dessus aurait rendu
// trois étages qui sont le même étage sous trois noms.
//
// Ce qui varie et qui est ATTESTÉ, ce sont deux listes que l'établissement
// publie lui-même : les licences conseillées à l'entrée, et la modalité de
// candidature. Le catalogue les portait déjà — en prose, dans
// `requirementsFr`. Une phrase se lit, elle ne se filtre pas.
//
// CE QUE CE FICHIER S'INTERDIT
//
// Décider à la place de l'établissement. Une mention qu'aucun mot-clé ne
// reconnaît n'est pas rangée « au plus proche » : elle n'entre pas dans
// `recommendedFieldIds`, et son libellé reste servi tel quel. Le repli par
// domaine de `resolveFieldId` est donc REFUSÉ ici — il sert à classer un
// intitulé de diplôme, pas à deviner à quelle famille appartient une licence
// que l'établissement a nommée.
// ─────────────────────────────────────────────────────────────────────────────
import { normalizeLabel, resolveFieldId } from './eef-catalog.normalize';
import type { EefCatalog } from './eef-catalog.types';

/**
 * Le libellé par lequel un établissement dit « n'importe quelle licence ».
 *
 * 302 masters le publient. Ce n'est pas une mention manquante ni un intitulé
 * mal saisi : c'est une information d'admission, et la plus favorable qui
 * soit. La traiter comme une mention non reconnue aurait jeté le seul cas où
 * la porte est explicitement ouverte à tout le monde.
 */
export const ANY_BACHELOR_LABEL = 'Toutes licences';

const ANY_BACHELOR_NORMALIZED = normalizeLabel(ANY_BACHELOR_LABEL);

/** `true` si l'établissement publie qu'il accepte toutes les licences. */
export function acceptsAnyBachelor(labels: readonly string[]): boolean {
  return labels.some(
    (label) => normalizeLabel(label) === ANY_BACHELOR_NORMALIZED,
  );
}

/**
 * Les domaines du catalogue auxquels appartiennent les licences conseillées.
 *
 * Sert de clé de requête : « les masters dont la porte d'entrée est ouverte à
 * mon domaine ». C'est la question intéressante, parce qu'elle n'est PAS celle
 * que le domaine du master lui-même sait poser — un master de management dont
 * les licences conseillées sont « Sciences de la vie » est une ouverture
 * réelle qu'aucun filtre par domaine du diplôme ne montrerait.
 *
 * Seuls les appariements par MOT-CLÉ comptent (`isFallback: false`). Le repli
 * par domaine classerait n'importe quelle chaîne dans une case, et une case
 * remplie par défaut se lit comme une case attestée.
 */
export function recommendedFieldIdsOf(labels: readonly string[]): string[] {
  const out = new Set<string>();
  for (const label of labels) {
    const resolved = resolveFieldId(label);
    if (resolved && !resolved.isFallback) out.add(resolved.fieldId);
  }
  // Trié : deux exécutions doivent produire le même tableau, sinon un
  // rattrapage rejoué réécrirait des lignes identiques sans le savoir.
  return [...out].sort();
}

export interface AdmissionSignalsEntry {
  readonly id: string;
  readonly recommendedBachelors: string[];
  readonly recommendedFieldIds: string[];
  readonly admissionModes: string[];
}

/**
 * Le plan de rattrapage : un jeu de signaux par formation qui en publie.
 *
 * Les formations sans licence conseillée NI modalité publiée sont omises — les
 * écrire reviendrait à remplacer un tableau vide par un tableau vide, donc à
 * compter comme « rattrapées » des lignes que rien ne distingue.
 */
export function planAdmissionSignalsBackfill(
  catalog: EefCatalog,
): AdmissionSignalsEntry[] {
  const entries: AdmissionSignalsEntry[] = [];
  for (const file of catalog.universities) {
    for (const program of file.programs) {
      const bachelors = [...program.recommendedBachelors];
      const modes = [...program.admissionModes];
      if (bachelors.length === 0 && modes.length === 0) continue;
      entries.push({
        id: program.id,
        recommendedBachelors: bachelors,
        recommendedFieldIds: recommendedFieldIdsOf(bachelors),
        admissionModes: modes,
      });
    }
  }
  return entries;
}

export interface AdmissionSignalsWriter {
  /**
   * Doit s'exécuter comme
   * `UPDATE … SET … WHERE id = ? AND cardinality("recommendedBachelors") = 0
   *  AND cardinality("admissionModes") = 0`,
   * et rendre le nombre de lignes touchées.
   *
   * Ne comble que les trous, comme le rattrapage du cycle : écrire par-dessus
   * des valeurs existantes ferait de ce script un second import, avec le
   * pouvoir d'écraser une correction d'administrateur sans aucun des
   * garde-fous de l'import. Il reste donc rejouable sans conséquence.
   *
   * La restriction s'exprime dans le `WHERE` et non en mémoire : entre la
   * lecture du plan et l'écriture, un import peut avoir renseigné la ligne.
   */
  fillIfEmpty(entry: AdmissionSignalsEntry): Promise<number>;
}

export interface AdmissionSignalsSummary {
  readonly attempted: number;
  readonly filled: number;
  /// Lignes non touchées : elles portaient déjà des signaux, ou elles
  /// n'existent pas en base. Un `UPDATE` ne sait pas les distinguer, et les
  /// deux cas veulent dire la même chose ici — rien à faire.
  readonly untouched: number;
}

export async function backfillEefAdmissionSignals(
  entries: readonly AdmissionSignalsEntry[],
  writer: AdmissionSignalsWriter,
): Promise<AdmissionSignalsSummary> {
  let filled = 0;
  for (const entry of entries) {
    filled += await writer.fillIfEmpty(entry);
  }
  return {
    attempted: entries.length,
    filled,
    untouched: entries.length - filled,
  };
}
