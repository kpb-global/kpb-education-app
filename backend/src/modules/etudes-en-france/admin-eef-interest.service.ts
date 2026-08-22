import { Injectable, ServiceUnavailableException } from '@nestjs/common';

import { PrismaService } from '../prisma/prisma.service';
import {
  buildEefInterestCsv,
  EefInterestCsvRow,
} from './eef-interest-csv';

/**
 * Plafond de l'export. Une liste d'intérêt de vitrine se compte en milliers,
 * pas en millions, et une requête non bornée sur une table qui grossit finit
 * par tenir la connexion pendant que l'admin croit que la page est cassée.
 */
const EXPORT_LIMIT = 20000;

const USER_SELECT = {
  fullName: true,
  email: true,
  phone: true,
  whatsApp: true,
  countryOfResidence: true,
  // `birthDate` est lue pour en dériver un SEUL booléen, et n'est jamais rendue.
  // Voir [minorityOf] : la personne qui décroche le téléphone a besoin de savoir
  // qu'elle parle à un mineur, pas de connaître sa date de naissance.
  birthDate: true,
} as const;

/**
 * Mineur, majeur, ou inconnu — et le troisième cas n'est PAS « majeur ».
 *
 * ## Pourquoi trois états et non un booléen
 *
 * Parce que `birthDate` est nullable en pratique : l'auto-création de profil à
 * la première connexion Supabase ne la pose pas, seul l'onboarding le fait. Un
 * booléen aurait donc écrasé « on ne sait pas » sur « majeur », et c'est
 * exactement le sens d'échec qu'il ne faut pas ici.
 *
 * `AiConsentService` fait délibérément l'inverse — une date absente y vaut
 * majeur — et c'est cohérent là-bas : il s'agit d'autoriser un traitement, et
 * bloquer tout le monde faute de date serait une panne. Ici il s'agit d'informer
 * un humain avant un appel commercial, et « inconnu » est une information utile
 * qu'un « non » effacerait.
 *
 * L'âge est calculé sur les jours calendaires, anniversaire inclus : un
 * `(now - birth) / 365.25` aurait basculé quelqu'un un ou deux jours trop tôt.
 */
export type Minority = 'minor' | 'adult' | 'unknown';

export function minorityOf(
  birthDate: Date | null | undefined,
  now: Date = new Date(),
): Minority {
  if (!birthDate) return 'unknown';
  const birth = new Date(birthDate);
  if (Number.isNaN(birth.getTime())) return 'unknown';

  let age = now.getUTCFullYear() - birth.getUTCFullYear();
  const monthDelta = now.getUTCMonth() - birth.getUTCMonth();
  if (monthDelta < 0 || (monthDelta === 0 && now.getUTCDate() < birth.getUTCDate())) {
    age -= 1;
  }
  // Une date future ou absurde est une donnée abîmée, pas un nouveau-né : on ne
  // prétend pas savoir.
  if (age < 0 || age > 130) return 'unknown';
  return age < 18 ? 'minor' : 'adult';
}

/**
 * Côté back-office : lire la liste d'intérêt et l'exporter.
 *
 * Ce service existe pour la raison écrite dans le plan : sans sortie
 * exploitable, la liste n'existe que dans Postgres et personne ne rappelle
 * personne. Il est séparé du service étudiant parce qu'il lit des données
 * d'AUTRES utilisateurs — le mélanger aurait mis une lecture large derrière un
 * garde conçu pour « le profil appelant ».
 */
@Injectable()
export class AdminEefInterestService {
  constructor(private readonly prismaService: PrismaService) {}

  private assertDb() {
    if (!this.prismaService.isEnabled) {
      throw new ServiceUnavailableException(
        'Database is not configured. Set DATABASE_URL.',
      );
    }
  }

  /** Compteurs de tête : total et part qui se déclare intéressée par le payant. */
  async getSummary(): Promise<{ total: number; wantsPremium: number }> {
    this.assertDb();

    const counts = await this.prismaService.execute(async (prisma) => {
      const [total, wantsPremium] = await Promise.all([
        prisma.eefInterest.count(),
        prisma.eefInterest.count({ where: { wantsPremium: true } }),
      ]);
      return { total, wantsPremium };
    });

    if (!counts) {
      throw new ServiceUnavailableException('Failed to read interest counts.');
    }
    return counts;
  }

  /** La liste paginée, la plus récente d'abord. */
  async list(params: { take: number; skip: number }) {
    this.assertDb();

    const rows = await this.prismaService.execute((prisma) =>
      prisma.eefInterest.findMany({
        orderBy: { createdAt: 'desc' },
        take: params.take,
        skip: params.skip,
        include: { user: { select: USER_SELECT } },
      }),
    );

    if (!rows) {
      throw new ServiceUnavailableException('Failed to read interest list.');
    }
    return { items: rows.map((row) => this.project(row)) };
  }

  /**
   * Remplace `user.birthDate` par `minority`.
   *
   * Le back-office a besoin de savoir qu'un prospect est mineur ; il n'a pas
   * besoin de sa date de naissance. Projeter ici plutôt que masquer côté écran :
   * une donnée qui ne quitte pas le serveur ne peut pas fuir par une réponse
   * qu'on oublie de filtrer.
   */
  private project(row: Record<string, unknown>) {
    const user = (row.user ?? {}) as Record<string, unknown>;
    const { birthDate, ...safeUser } = user;
    return {
      ...row,
      user: { ...safeUser, minority: minorityOf(birthDate as Date | null) },
    };
  }

  /** Le CSV complet, prêt à être renvoyé en pièce jointe. */
  async exportCsv(): Promise<string> {
    this.assertDb();

    const rows = await this.prismaService.execute((prisma) =>
      prisma.eefInterest.findMany({
        orderBy: { createdAt: 'desc' },
        take: EXPORT_LIMIT,
        include: { user: { select: USER_SELECT } },
      }),
    );

    if (!rows) {
      throw new ServiceUnavailableException('Failed to export interest list.');
    }

    // Le plafond ne se tait PLUS.
    //
    // `getSummary` compte sans plafond ; l'export était borné à EXPORT_LIMIT et
    // trié par date décroissante. À 25 000 déclarations, l'écran affichait
    // « 25000 » et le fichier contenait les 20 000 plus récentes : les 5 000
    // prospects les plus anciens disparaissaient sans un mot. Personne ne les
    // rappelait, et personne ne savait qu'ils existaient.
    //
    // Un plafond de ressource est légitime ; le taire ne l'est pas. On compte,
    // on compare, et on le dit dans le fichier lui-même — là où le lecteur est.
    const total = await this.prismaService.execute((prisma) =>
      prisma.eefInterest.count(),
    );
    const truncated =
      typeof total === 'number' && total > rows.length ? total : null;

    return buildEefInterestCsv(
      rows as unknown as EefInterestCsvRow[],
      { totalRows: truncated, limit: EXPORT_LIMIT },
    );
  }

  /**
   * Retire une déclaration, à la demande de l'étudiant.
   *
   * L'équipe reçoit ces demandes par e-mail ou WhatsApp — le texte de
   * consentement les y invite — et n'avait aucun outil pour les exécuter : les
   * seules issues étaient de supprimer le compte entier ou de faire du SQL à la
   * main en production.
   *
   * Idempotente, pour la même raison que côté étudiant : le résultat qui compte
   * est « cette personne n'est plus dans la liste ».
   */
  async withdraw(interestId: string): Promise<{ removed: number }> {
    this.assertDb();

    const result = await this.prismaService.execute((prisma) =>
      prisma.eefInterest.deleteMany({ where: { id: interestId } }),
    );

    if (!result) {
      throw new ServiceUnavailableException('Failed to withdraw interest.');
    }
    return { removed: result.count };
  }
}
