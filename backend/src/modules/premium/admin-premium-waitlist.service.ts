import { Injectable, ServiceUnavailableException } from '@nestjs/common';

import { PrismaService } from '../prisma/prisma.service';
// `minorityOf` est IMPORTÉE plutôt que recopiée. La règle « une date absente
// vaut inconnu, pas majeur » a une raison écrite là-bas, et deux copies auraient
// divergé le jour où l'une des deux est corrigée.
import { minorityOf } from '../etudes-en-france/admin-eef-interest.service';

const USER_SELECT = {
  fullName: true,
  email: true,
  phone: true,
  whatsApp: true,
  countryOfResidence: true,
  // Lue pour en dériver un SEUL booléen, jamais rendue : la personne qui
  // décroche a besoin de savoir qu'elle parle à un mineur, pas de connaître sa
  // date de naissance.
  birthDate: true,
} as const;

/** Fenêtres du résumé, en jours. */
const RECENT_WINDOWS = [7, 30] as const;

/**
 * Back-office de la liste d'attente Premium.
 *
 * Séparé du service étudiant parce qu'il lit les données d'AUTRES utilisateurs :
 * le mélanger aurait placé une lecture large derrière un garde conçu pour « le
 * profil appelant ».
 *
 * Il ne sait ni encaisser, ni facturer, ni marquer quiconque comme client. Il
 * compte et il liste.
 */
@Injectable()
export class AdminPremiumWaitlistService {
  constructor(private readonly prismaService: PrismaService) {}

  private assertDb() {
    if (!this.prismaService.isEnabled) {
      throw new ServiceUnavailableException(
        'Database is not configured. Set DATABASE_URL.',
      );
    }
  }

  /**
   * Le total, et le rythme des inscriptions récentes.
   *
   * Un total seul ne dit pas si l'intérêt monte ou s'est arrêté il y a trois
   * mois — or c'est cette pente qui décide d'un lancement, pas le cumul. Les
   * deux fenêtres sont calculées côté serveur à partir d'une seule et même
   * horloge : les dériver côté écran aurait fait dépendre le chiffre du fuseau
   * du poste de back-office.
   */
  async getSummary(now: Date = new Date()): Promise<{
    total: number;
    last7Days: number;
    last30Days: number;
  }> {
    this.assertDb();

    const since = (days: number) =>
      new Date(now.getTime() - days * 24 * 60 * 60 * 1000);

    const counts = await this.prismaService.execute(async (prisma) => {
      const [total, last7Days, last30Days] = await Promise.all([
        prisma.premiumWaitlistEntry.count(),
        ...RECENT_WINDOWS.map((days) =>
          prisma.premiumWaitlistEntry.count({
            where: { createdAt: { gte: since(days) } },
          }),
        ),
      ]);
      return { total, last7Days, last30Days };
    });

    if (!counts) {
      throw new ServiceUnavailableException('Failed to read waitlist counts.');
    }
    return counts;
  }

  /** La liste paginée, la plus récente d'abord. */
  async list(params: { take: number; skip: number }) {
    this.assertDb();

    const rows = await this.prismaService.execute((prisma) =>
      prisma.premiumWaitlistEntry.findMany({
        orderBy: { createdAt: 'desc' },
        take: params.take,
        skip: params.skip,
        include: { user: { select: USER_SELECT } },
      }),
    );

    if (!rows) {
      throw new ServiceUnavailableException('Failed to read the waitlist.');
    }
    return { items: rows.map((row) => this.project(row)) };
  }

  /**
   * Remplace `user.birthDate` par `minority`.
   *
   * Projeté ici plutôt que masqué côté écran : une donnée qui ne quitte pas le
   * serveur ne peut pas fuir par une réponse qu'on oublie de filtrer.
   */
  private project(row: Record<string, unknown>) {
    const user = (row.user ?? {}) as Record<string, unknown>;
    const { birthDate, ...safeUser } = user;
    return {
      ...row,
      user: { ...safeUser, minority: minorityOf(birthDate as Date | null) },
    };
  }
}
