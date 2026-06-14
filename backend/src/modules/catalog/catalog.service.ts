import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { mockCatalog } from '../../common/data/mock-catalog';

@Injectable()
export class CatalogService {
  constructor(private readonly prismaService: PrismaService) {}

  async getFields() {
    const items = await this.prismaService.tryExecute((prisma) =>
      prisma.field.findMany(),
    );
    return { items: items ?? mockCatalog.fields };
  }

  async getCountries() {
    const items = await this.prismaService.tryExecute((prisma) =>
      prisma.country.findMany(),
    );
    return { items: items ?? mockCatalog.countries };
  }

  async getInstitutions() {
    const items = await this.prismaService.tryExecute((prisma) =>
      prisma.institution.findMany(),
    );
    return { items: items ?? mockCatalog.institutions };
  }

  async getPrograms() {
    const items = await this.prismaService.tryExecute((prisma) =>
      prisma.program.findMany(),
    );
    return { items: items ?? mockCatalog.programs };
  }

  async getScholarships() {
    const items = await this.prismaService.tryExecute((prisma) =>
      prisma.scholarship.findMany(),
    );
    return { items: items ?? mockCatalog.scholarships };
  }
}
