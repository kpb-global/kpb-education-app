// ─────────────────────────────────────────────────────────────────────────────
// De la déclaration au chemin d'entrée. Table fermée, qui REFUSE.
//
// LE PIÈGE QUE CE FICHIER ÉVITE
//
// La vitrine pose deux questions avec le MÊME menu — niveau courant, niveau
// visé — et ce menu tient en six mots : terminale, bac, licence, master,
// doctorat, autre. « Licence » y veut dire « je suis au niveau licence », ce
// qui ne dit pas si l'étudiant entre en L1, continue en L3, ou sort avec son
// diplôme en poche.
//
// Pris seul, `targetLevel = licence` est donc ambigu, et l'ambiguïté n'est pas
// bénigne : entrer en L1 se demande par DAP blanche avant le 15 décembre,
// continuer en L2 se demande par la procédure Études en France sur un autre
// calendrier. Se tromper de chemin, c'est envoyer un étudiant vers une
// échéance qui n'est pas la sienne.
//
// C'est le COUPLE qui lève l'ambiguïté, et seulement lui. La table ci-dessous
// n'énumère donc pas des niveaux mais des couples, et elle n'en interprète
// aucun qui n'y figure pas : un couple absent rend un motif, jamais un chemin
// « le plus probable ». Le dépôt a déjà ce réflexe pour les familles
// Parcoursup et les domaines — une table qui devine se trompe en silence,
// une table qui refuse se corrige.
// ─────────────────────────────────────────────────────────────────────────────
import type { EefEntryPath, EefShortlistBlocked } from './eef-shortlist.types';

/// Les valeurs que la feuille de déclaration peut produire
/// (`eef_interest_sheet.dart`). `unspecified` n'est pas dans la liste : le
/// client n'envoie simplement rien dans ce cas.
const KNOWN_LEVELS = new Set([
  'terminale',
  'bac',
  'licence',
  'master',
  'doctorat',
  'autre',
]);

/**
 * Les couples (niveau courant, niveau visé) qu'on accepte d'interpréter.
 *
 * Lecture ligne à ligne, parce que chacune est une décision :
 *
 *   terminale|licence, bac|licence   entrée post-bac : L1, BUT, DEUST, PASS.
 *   terminale|master, bac|master     REFUSÉ. Un master ne se demande pas
 *                                    depuis le lycée ; servir les 3 112
 *                                    masters à un élève de terminale serait
 *                                    une liste qu'il ne peut pas utiliser.
 *   licence|licence                  continuation : L2, L3. C'est le cas où
 *                                    le couple fait tout le travail — même
 *                                    niveau visé que la ligne du dessus,
 *                                    chemin entièrement différent.
 *   licence|master                   le cas le plus courant de la procédure.
 *   master|master                    un second master, ou une réorientation
 *                                    de mention : la même liste convient.
 *   master|licence                   REFUSÉ, faute de savoir ce qui est
 *                                    demandé : reprendre une L1 ? une L3 ?
 *                                    Les deux listes n'ont aucune ligne en
 *                                    commun, et un mauvais choix envoie vers
 *                                    la mauvaise échéance.
 *   *|doctorat                       le catalogue ne porte aucun doctorat.
 *                                    Traité à part, pour dire « pas encore
 *                                    couvert » plutôt que de rendre une liste
 *                                    vide qui ressemblerait à un échec.
 *   *|autre, autre|*                 REFUSÉ : « autre » ne désigne rien qu'on
 *                                    puisse rattacher à un cycle.
 */
const PATH_BY_DECLARATION: Readonly<Record<string, EefEntryPath>> = {
  'terminale|licence': 'post_bac',
  'bac|licence': 'post_bac',
  'licence|licence': 'licence_continuation',
  'licence|master': 'master',
  'master|master': 'master',
};

/// Les niveaux visés que le catalogue ne couvre pas encore. Distinguer ce cas
/// d'un couple illisible change ce que l'écran doit dire : ici il n'y a rien à
/// corriger dans la déclaration, c'est le catalogue qui s'arrête au master.
const LEVELS_ABSENT_FROM_CATALOG = new Set(['doctorat']);

export interface EefDeclaration {
  readonly currentLevel: string | null;
  readonly targetLevel: string | null;
  readonly fieldIds: readonly string[];
}

export type EefPathResolution =
  | { readonly path: EefEntryPath; readonly blocked: null }
  | { readonly path: null; readonly blocked: EefShortlistBlocked };

function normalizeLevel(value: string | null | undefined): string | null {
  const trimmed = (value ?? '').trim().toLowerCase();
  if (trimmed === '' || !KNOWN_LEVELS.has(trimmed)) return null;
  return trimmed;
}

/**
 * Le chemin d'entrée, ou le motif pour lequel il n'y en a pas.
 *
 * `declaration === null` veut dire qu'aucune ligne n'existe pour ce profil :
 * l'étudiant n'a jamais déclaré son intérêt. C'est le premier écran, pas une
 * anomalie.
 */
export function resolveEefPath(
  declaration: EefDeclaration | null,
): EefPathResolution {
  if (!declaration) return { path: null, blocked: 'no_declaration' };

  const current = normalizeLevel(declaration.currentLevel);
  const target = normalizeLevel(declaration.targetLevel);

  // Le niveau visé se teste EN PREMIER, et le doctorat avant l'absence du
  // niveau courant : un doctorant qui n'a pas renseigné son niveau actuel doit
  // lire « pas encore couvert », pas « complète ta déclaration » — ce dernier
  // message lui ferait remplir un champ qui ne changerait rien.
  if (target === null) return { path: null, blocked: 'target_level_missing' };
  if (LEVELS_ABSENT_FROM_CATALOG.has(target)) {
    return { path: null, blocked: 'level_not_in_catalog' };
  }
  if (current === null) return { path: null, blocked: 'current_level_missing' };

  const path = PATH_BY_DECLARATION[`${current}|${target}`];
  if (!path) return { path: null, blocked: 'declaration_unmappable' };
  return { path, blocked: null };
}
