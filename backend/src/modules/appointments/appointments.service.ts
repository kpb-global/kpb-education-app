import { Injectable, ServiceUnavailableException } from '@nestjs/common';

import { PrismaService } from '../prisma/prisma.service';
import { CreateAppointmentDto } from './dto/create-appointment.dto';

@Injectable()
export class AppointmentsService {
  constructor(private readonly prismaService: PrismaService) {}

  private assertDb() {
    if (!this.prismaService.isEnabled) {
      throw new ServiceUnavailableException(
        'Database is not configured. Set DATABASE_URL.',
      );
    }
  }

  async findAll() {
    this.assertDb();
    const items = await this.prismaService.execute((prisma) =>
      prisma.appointment.findMany({ orderBy: { createdAt: 'desc' } }),
    );
    return (items ?? []).map((item) => ({
      id: item.id,
      caseId: item.caseId,
      title: item.title,
      scheduledAt: item.startsAt.toISOString(),
      contactMethod: item.contactMethod,
      notes: item.notes ?? '',
    }));
  }

  async create(input: CreateAppointmentDto) {
    this.assertDb();
    const created = await this.prismaService.execute((prisma) =>
      prisma.appointment.create({
        data: {
          userId: 'demo-user',
          caseId: input.caseId ?? null,
          title: input.title,
          goal: input.title,
          startsAt: new Date(input.scheduledAt),
          status: 'scheduled',
          contactMethod: input.contactMethod ?? 'in_app',
          notes: input.notes ?? null,
        },
      }),
    );
    if (!created) {
      throw new ServiceUnavailableException('Failed to persist appointment.');
    }
    return {
      id: created.id,
      caseId: created.caseId,
      title: created.title,
      scheduledAt: created.startsAt.toISOString(),
      contactMethod: created.contactMethod,
      notes: created.notes ?? '',
    };
  }
}
