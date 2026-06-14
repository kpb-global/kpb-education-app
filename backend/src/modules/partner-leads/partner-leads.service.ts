import { Injectable } from '@nestjs/common';

import { PrismaService } from '../prisma/prisma.service';
import { CreatePartnerLeadDto } from './dto/create-partner-lead.dto';

@Injectable()
export class PartnerLeadsService {
  constructor(private readonly prismaService: PrismaService) {}

  private readonly leads: Array<Record<string, unknown>> = [];

  async findAll() {
    const items = await this.prismaService.execute((prisma) =>
      prisma.partnerLead.findMany({
        orderBy: { createdAt: 'desc' },
      }),
    );

    if (items) {
      return items.map((item) => ({
        id: item.id,
        organizationName: item.organizationName,
        contactName: item.contactName,
        email: item.email,
        phone: item.phone,
        country: item.country,
        notes: item.message,
        createdAt: item.createdAt.toISOString(),
        status: item.status,
      }));
    }

    return this.leads;
  }

  async create(input: CreatePartnerLeadDto) {
    const created = await this.prismaService.execute((prisma) =>
      prisma.partnerLead.create({
        data: {
          organizationName: input.organizationName,
          contactName: input.contactName,
          email: input.email,
          phone: input.phone ?? null,
          country: input.country ?? null,
          message: input.notes ?? null,
          status: 'new',
        },
      }),
    );

    if (created) {
      return {
        id: created.id,
        organizationName: created.organizationName,
        contactName: created.contactName,
        email: created.email,
        phone: created.phone,
        country: created.country,
        notes: created.message,
        createdAt: created.createdAt.toISOString(),
        status: created.status,
      };
    }

    const lead = {
      id: `partner-${Date.now()}`,
      organizationName: input.organizationName,
      contactName: input.contactName,
      email: input.email,
      phone: input.phone ?? null,
      country: input.country ?? null,
      notes: input.notes ?? null,
      createdAt: new Date().toISOString(),
      status: 'new',
    };

    this.leads.unshift(lead);
    return lead;
  }
}
