import type { Prisma } from '@prisma/client';

import {
  notPendingEefInstitution,
  notPendingEefProgram,
} from '../../common/eef-provenance';

const DAY_MS = 24 * 60 * 60 * 1000;

/**
 * « À revérifier » : jamais vérifié, ou vérifié il y a plus que la cadence.
 *
 * ## Une règle, un endroit
 *
 * Cette règle a longtemps existé en DEUX exemplaires — une méthode privée du
 * service admin (la file de revérification et le SLA de 07 h) et une fonction du
 * service de rapports (le compteur « Action immédiate requise » du tableau de
 * bord). Ils devaient rester identiques et rien ne le garantissait : quand
 * l'import EEF a appelé une correction, la revue n'a d'abord trouvé que le
 * premier ; le second aurait affiché « 10 600 à revérifier » dès l'import.
 *
 * ## Les lignes EEF en attente n'y ont pas leur place
 *
 * Une file de RE-vérification liste des fiches publiées dont la cadence est
 * échue. Les 10 500 lignes que l'import crée inactives n'ont jamais été
 * publiées : leur revue est le flux de PUBLICATION, qui demande un outil dédié
 * (À CONSTRUIRE — valider une ligne ici ne pose que le tampon de vérification,
 * jamais `isActive`), pas la cadence. Les compter ici rendrait la page admin
 * inutilisable (un champ de saisie par ligne — cette page sert aussi à
 * revérifier les bourses) et ferait annoncer chaque matin à l'alerte de 07 h
 * « SLA breach : 10 5xx never verified », jusqu'à ce que personne ne la lise
 * plus.
 *
 * Une ligne EEF PUBLIÉE y entre normalement : c'est exactement le cas où elle
 * doit être revérifiée à sa cadence.
 */
export function verificationDueWhere(cadenceDays: number, now: Date) {
  const cutoff = new Date(now.getTime() - cadenceDays * DAY_MS);
  return {
    OR: [{ lastVerifiedAt: null }, { lastVerifiedAt: { lt: cutoff } }],
  };
}

/** Les établissements à revérifier — sans ceux de l'import EEF en attente. */
export function institutionVerificationDueWhere(
  cadenceDays: number,
  now: Date,
): Prisma.InstitutionWhereInput {
  return {
    AND: [
      verificationDueWhere(cadenceDays, now),
      notPendingEefInstitution(),
    ],
  };
}

/** Les formations à revérifier — sans celles de l'import EEF en attente. */
export function programVerificationDueWhere(
  cadenceDays: number,
  now: Date,
): Prisma.ProgramWhereInput {
  return {
    AND: [verificationDueWhere(cadenceDays, now), notPendingEefProgram()],
  };
}

/**
 * Les pays à revérifier : ACTIFS, et échus.
 *
 * Ce prédicat et le suivant étaient recopiés dans les deux consommateurs (la
 * file admin et le compteur du tableau de bord). Identiques le jour où ils ont
 * été écrits, rien ne l'imposait : une copie qui perdait `isActive` aurait
 * compté des pays éteints dans le compteur sans que la file ne bouge. Les quatre
 * catégories vivent maintenant ici, et un consommateur ne peut plus en diverger.
 */
export function countryVerificationDueWhere(
  cadenceDays: number,
  now: Date,
): Prisma.CountryWhereInput {
  return { isActive: true, ...verificationDueWhere(cadenceDays, now) };
}

/** Les bourses à revérifier : actives, APPROUVÉES, et échues. */
export function scholarshipVerificationDueWhere(
  cadenceDays: number,
  now: Date,
): Prisma.ScholarshipWhereInput {
  return {
    isActive: true,
    moderationStatus: 'approved',
    ...verificationDueWhere(cadenceDays, now),
  };
}

// ─── L'ordre de la file, et ce que le plafond garde ──────────────────────────

/** Ce dont l'ordre et la coupe ont besoin d'un élément de la file. */
export interface VerificationQueueEntry {
  readonly entityType: string;
  readonly id: string;
  readonly category: string;
  readonly cadenceDays: number;
  readonly lastVerifiedAt: Date | null;
  readonly dueAt: Date | null;
}

/**
 * L'ordre TOTAL de la file : ce qui presse d'abord.
 *
 *   1. les fiches JAMAIS vérifiées, les plus PÉRISSABLES en tête (cadence la plus
 *      courte : une bourse à 30 jours avant une formation à 180) ;
 *   2. puis les vérifiées, par ÉCHÉANCE la plus ancienne. Pas par âge : une
 *      bourse vérifiée il y a 100 jours est en retard de 70 jours, une formation
 *      vérifiée il y a 181 jours l'est de UN — trier sur l'âge brut plaçait la
 *      seconde devant la première, et le plafond écartait la bourse.
 *
 * Le dernier départage est l'identifiant : sans lui, deux fiches à égalité (des
 * milliers de formations partagent leur nom, jusqu'à 476 identiques) s'échangent
 * d'un appel à l'autre et la page qu'on tronque change sous les doigts de
 * l'exploitant à chaque écriture.
 */
export function compareVerificationItems(
  a: VerificationQueueEntry,
  b: VerificationQueueEntry,
): number {
  const aNever = a.lastVerifiedAt == null;
  const bNever = b.lastVerifiedAt == null;
  if (aNever !== bNever) return aNever ? -1 : 1;
  if (aNever) {
    if (a.cadenceDays !== b.cadenceDays) return a.cadenceDays - b.cadenceDays;
  } else {
    const gap = (a.dueAt?.getTime() ?? 0) - (b.dueAt?.getTime() ?? 0);
    if (gap !== 0) return gap;
  }
  const aKey = `${a.entityType}:${a.id}`;
  const bKey = `${b.entityType}:${b.id}`;
  return aKey < bKey ? -1 : aKey > bKey ? 1 : 0;
}

/**
 * Ce que le plafond garde d'une file DÉJÀ triée : les plus urgents, mais sans
 * qu'une catégorie n'en chasse une autre.
 *
 * Tronquer en tête de liste seule est trompeur dès qu'une catégorie est
 * volumineuse. Deux universités publiées d'un coup, c'est plus de 800 formations
 * « jamais vérifiées » : elles passent toutes devant, et les bourses en retard —
 * la seule catégorie qui périme en 30 jours, et pour laquelle cette page sert
 * chaque mois — tombent hors des 500 lignes envoyées, sans qu'aucun avertissement
 * ne le dise pour elles (le compte total, lui, est juste).
 *
 * Chaque catégorie présente reçoit donc au moins `limite / nombre de catégories`
 * places, dans l'ordre ; ce qu'elle n'utilise pas retourne au pot commun, rempli
 * dans l'ordre global ; le résultat garde l'ordre global.
 */
export function capFairly<T extends { readonly category: string }>(
  sorted: readonly T[],
  limit: number,
): T[] {
  if (sorted.length <= limit) return [...sorted];

  const categories = new Set(sorted.map((item) => item.category));
  const reserve = Math.floor(limit / categories.size);
  const chosen = new Set<T>();
  const taken = new Map<string, number>();
  for (const item of sorted) {
    const count = taken.get(item.category) ?? 0;
    if (count < reserve) {
      chosen.add(item);
      taken.set(item.category, count + 1);
    }
  }
  for (const item of sorted) {
    if (chosen.size >= limit) break;
    chosen.add(item);
  }
  return sorted.filter((item) => chosen.has(item));
}
