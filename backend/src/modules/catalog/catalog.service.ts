import { Injectable, Logger } from '@nestjs/common';
import type { Prisma, PrismaClient } from '@prisma/client';

import { PrismaService } from '../prisma/prisma.service';
import { mockCatalog } from '../../common/data/mock-catalog';
import { publicScholarshipWhere } from '../../common/public-scholarship-where';
import {
  CATALOG_SOURCE_DATABASE,
  CATALOG_SOURCE_MOCK,
  catalogUnavailable,
  isMockCatalogFallbackAllowed,
  type CatalogSource,
} from './catalog-degraded-mode';
import {
  mapCountry,
  mapField,
  mapInstitution,
  mapProgram,
  mapScholarship,
} from './catalog.mapper';

export type ProgramCatalogQuery = {
  q?: string;
  fieldId?: string;
  countryId?: string;
  institutionId?: string;
  limit?: number;
  offset?: number;
};

/** Every `/catalog/*` list response carries the provenance of its rows. */
export type CatalogListResponse<T> = {
  items: T[];
  source: CatalogSource;
};

@Injectable()
export class CatalogService {
  private readonly logger = new Logger(CatalogService.name);

  constructor(private readonly prismaService: PrismaService) {}

  async getFields(): Promise<CatalogListResponse<unknown>> {
    const rows = await this.readOrDegrade('fields', (prisma) =>
      prisma.field.findMany({ orderBy: { nameFr: 'asc' } }),
    );
    if (rows === null) return this.mockResponse(mockCatalog.fields);
    return { items: rows.map(mapField), source: CATALOG_SOURCE_DATABASE };
  }

  async getCountries(): Promise<CatalogListResponse<unknown>> {
    const rows = await this.readOrDegrade('countries', (prisma) =>
      prisma.country.findMany({
        where: { isActive: true },
        orderBy: { displayOrder: 'asc' },
      }),
    );
    if (rows === null) return this.mockResponse(mockCatalog.countries);
    return { items: rows.map(mapCountry), source: CATALOG_SOURCE_DATABASE };
  }

  async getInstitutions(
    query: { countryId?: string; partnerOnly?: boolean } = {},
  ): Promise<CatalogListResponse<unknown> & { total: number }> {
    const where: Prisma.InstitutionWhereInput = {};
    if (query.countryId) where.countryId = query.countryId;
    if (query.partnerOnly) where.isPartner = true;

    const rows = await this.readOrDegrade('institutions', (prisma) =>
      prisma.institution.findMany({
        where,
        orderBy: { nameFr: 'asc' },
      }),
    );
    if (rows === null) {
      const fallback = this.mockResponse(mockCatalog.institutions);
      return { ...fallback, total: fallback.items.length };
    }
    return {
      items: rows.map(mapInstitution),
      total: rows.length,
      source: CATALOG_SOURCE_DATABASE,
    };
  }

  async getPrograms(
    query: ProgramCatalogQuery = {},
  ): Promise<
    CatalogListResponse<unknown> & {
      total: number;
      limit: number;
      offset: number;
    }
  > {
    const where: Prisma.ProgramWhereInput = {};
    if (query.fieldId) where.fieldId = query.fieldId;
    if (query.countryId) where.countryId = query.countryId;
    if (query.institutionId) where.institutionId = query.institutionId;
    if (query.q?.trim()) {
      where.OR = [
        { nameFr: { contains: query.q.trim(), mode: 'insensitive' } },
        { nameEn: { contains: query.q.trim(), mode: 'insensitive' } },
        { levelFr: { contains: query.q.trim(), mode: 'insensitive' } },
      ];
    }

    const limit = Math.min(Math.max(query.limit ?? 1000, 1), 1000);
    const offset = Math.max(query.offset ?? 0, 0);

    const result = await this.readOrDegrade('programs', (prisma) =>
      prisma.$transaction([
        prisma.program.findMany({
          where,
          orderBy: { nameFr: 'asc' },
          take: limit,
          skip: offset,
        }),
        prisma.program.count({ where }),
      ]),
    );

    if (result === null) {
      const fallback = this.mockResponse(mockCatalog.programs);
      return {
        ...fallback,
        total: fallback.items.length,
        limit,
        offset,
      };
    }

    const [items, total] = result;
    return {
      items: items.map(mapProgram),
      total,
      limit,
      offset,
      source: CATALOG_SOURCE_DATABASE,
    };
  }

  async getScholarships(): Promise<CatalogListResponse<unknown>> {
    const rows = await this.readOrDegrade('scholarships', (prisma) =>
      prisma.scholarship.findMany({
        // Le commentaire qui vivait ici affirmait masquer les fiches expirées.
        // C'était faux : le `where` n'avait aucun filtre de date, et trois
        // bourses closes depuis 13 à 90 jours étaient servies comme
        // disponibles. La règle est maintenant partagée avec `/scholarships`,
        // en un seul endroit, pour qu'un commentaire ne puisse plus tenir lieu
        // de filtre.
        where: publicScholarshipWhere(),
        orderBy: { nameFr: 'asc' },
        // Les cycles voyagent avec la fiche pour que le client sache si
        // `deadlineAt` est une date CONFIRMÉE ou une PROJECTION. 20 des 31
        // fiches publiées ont un cycle `estimated` : sans cette information,
        // le calendrier d'échéances posait un jalon ferme — « J-146 » — sur
        // une date que personne n'a confirmée. L'onglet Bourses sait déjà se
        // taire dans ce cas ; ce endpoint doit donner au calendrier le moyen
        // d'en faire autant.
        include: { cycles: { orderBy: { academicYear: 'desc' }, take: 5 } },
      }),
    );
    if (rows === null) return this.mockResponse(mockCatalog.scholarships);
    return { items: rows.map(mapScholarship), source: CATALOG_SOURCE_DATABASE };
  }

  /**
   * Runs a read against Postgres and returns its rows, or `null` when the
   * caller should serve `mock-catalog.ts` fixtures instead.
   *
   * `null` is only ever returned outside production. In production a missing
   * or failing database throws 503 `CATALOG_UNAVAILABLE`, so a client can tell
   * "the catalog is empty" (200 with `items: []`) from "the catalog service is
   * down" (503) — and never receives a fixture dressed up as a real row.
   *
   * Note this uses `PrismaService.execute()`, not `tryExecute()`: `tryExecute`
   * downgrades every database error to a `warn` and swallows it, which is how
   * this incident stayed invisible in the logs.
   */
  private async readOrDegrade<T>(
    resource: string,
    operation: (prisma: PrismaClient) => Promise<T>,
  ): Promise<T | null> {
    if (!this.prismaService.isEnabled) {
      return this.degrade(resource, 'DATABASE_NOT_CONFIGURED');
    }
    try {
      const result = await this.prismaService.execute(operation);
      // `execute()` only returns null when no client is configured, which the
      // guard above already covered; treat it as a degradation regardless.
      if (result === null) {
        return this.degrade(resource, 'DATABASE_NOT_CONFIGURED');
      }
      return result;
    } catch {
      // PrismaService.execute() already logged the bounded, PII-free error code
      // at `error` level before rethrowing.
      return this.degrade(resource, 'DATABASE_ERROR');
    }
  }

  /** Decides what a database outage means for this process. Never silent. */
  private degrade(resource: string, reason: string): null {
    if (!isMockCatalogFallbackAllowed()) {
      this.logger.error(
        `Catalog "${resource}" is unavailable (${reason}). Refusing to serve ` +
          'mock-catalog fixtures; answering 503 CATALOG_UNAVAILABLE.',
      );
      throw catalogUnavailable(resource);
    }
    this.logger.warn(
      `Catalog "${resource}" is unavailable (${reason}). Serving mock-catalog ` +
        'fixtures tagged source="mock" (non-production only).',
    );
    return null;
  }

  private mockResponse(rows: unknown[]): CatalogListResponse<unknown> {
    return {
      items: rows as Record<string, unknown>[],
      source: CATALOG_SOURCE_MOCK,
    };
  }
}
