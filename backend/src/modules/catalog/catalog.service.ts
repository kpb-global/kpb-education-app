import { Injectable } from '@nestjs/common';
import type { Prisma } from '@prisma/client';

import { PrismaService } from '../prisma/prisma.service';
import { mockCatalog } from '../../common/data/mock-catalog';
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

@Injectable()
export class CatalogService {
  constructor(private readonly prismaService: PrismaService) {}

  async getFields() {
    const items = await this.prismaService.tryExecute((prisma) =>
      prisma.field.findMany({ orderBy: { nameFr: 'asc' } }),
    );
    const rows = items ?? (mockCatalog.fields as Record<string, unknown>[]);
    return {
      items: Array.isArray(items)
        ? items.map(mapField)
        : rows,
    };
  }

  async getCountries() {
    const items = await this.prismaService.tryExecute((prisma) =>
      prisma.country.findMany({
        where: { isActive: true },
        orderBy: { displayOrder: 'asc' },
      }),
    );
    const rows = items ?? (mockCatalog.countries as Record<string, unknown>[]);
    return {
      items: Array.isArray(items)
        ? items.map(mapCountry)
        : rows,
    };
  }

  async getInstitutions(query: { countryId?: string; partnerOnly?: boolean } = {}) {
    const where: Prisma.InstitutionWhereInput = {};
    if (query.countryId) where.countryId = query.countryId;
    if (query.partnerOnly) where.isPartner = true;

    const items = await this.prismaService.tryExecute((prisma) =>
      prisma.institution.findMany({
        where,
        orderBy: { nameFr: 'asc' },
      }),
    );
    const rows =
      items ?? (mockCatalog.institutions as Record<string, unknown>[]);
    return {
      items: Array.isArray(items)
        ? items.map(mapInstitution)
        : rows,
      total: Array.isArray(items) ? items.length : rows.length,
    };
  }

  async getPrograms(query: ProgramCatalogQuery = {}) {
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

    const result = await this.prismaService.tryExecute((prisma) =>
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

    if (!result) {
      const fallback = mockCatalog.programs as Record<string, unknown>[];
      return { items: fallback, total: fallback.length, limit, offset };
    }

    const [items, total] = result;
    return {
      items: items.map(mapProgram),
      total,
      limit,
      offset,
    };
  }

  async getScholarships() {
    const items = await this.prismaService.tryExecute((prisma) =>
      prisma.scholarship.findMany({ orderBy: { nameFr: 'asc' } }),
    );
    const rows =
      items ?? (mockCatalog.scholarships as Record<string, unknown>[]);
    return {
      items: Array.isArray(items)
        ? items.map(mapScholarship)
        : rows,
    };
  }
}
