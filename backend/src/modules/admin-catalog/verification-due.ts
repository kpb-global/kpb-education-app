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
 * publiées : leur revue est le flux de PUBLICATION, avec son propre outil, pas
 * la cadence. Les compter ici rendrait la page admin inutilisable (un champ de
 * saisie par ligne — cette page sert aussi à revérifier les bourses) et ferait
 * annoncer chaque matin à l'alerte de 07 h « SLA breach : 10 5xx never
 * verified », jusqu'à ce que personne ne la lise plus.
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
