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
} as const;

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
    return { items: rows };
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

    return buildEefInterestCsv(rows as unknown as EefInterestCsvRow[]);
  }
}
