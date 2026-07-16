import {
  Injectable,
  NotFoundException,
  ServiceUnavailableException,
} from '@nestjs/common';

import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class ScholarshipAlertsService {
  constructor(private readonly prismaService: PrismaService) {}

  private assertDb() {
    if (!this.prismaService.isEnabled) {
      throw new ServiceUnavailableException(
        'Database is not configured. Set DATABASE_URL.',
      );
    }
  }

  async list(userId: string) {
    this.assertDb();
    const rows = await this.prismaService.execute((prisma) =>
      prisma.scholarshipAlertSubscription.findMany({
        where: { userId },
        select: {
          id: true,
          scholarshipId: true,
          pushEnabled: true,
          inAppEnabled: true,
          createdAt: true,
        },
        orderBy: { createdAt: 'desc' },
      }),
    );
    return {
      items: (rows ?? []).map((row) => ({
        ...row,
        createdAt: row.createdAt.toISOString(),
      })),
    };
  }

  async subscribe(userId: string, scholarshipId: string) {
    this.assertDb();
    const result = await this.prismaService.execute(async (prisma) => {
      const scholarship = await prisma.scholarship.findFirst({
        where: {
          id: scholarshipId,
          moderationStatus: 'approved',
          isActive: true,
        },
        select: { id: true },
      });
      if (!scholarship) return null;
      return prisma.scholarshipAlertSubscription.upsert({
        where: { userId_scholarshipId: { userId, scholarshipId } },
        create: { userId, scholarshipId },
        update: { pushEnabled: true, inAppEnabled: true },
      });
    });
    if (!result) {
      throw new NotFoundException(`Scholarship ${scholarshipId} not found.`);
    }
    return { scholarshipId, subscribed: true };
  }

  async unsubscribe(userId: string, scholarshipId: string) {
    this.assertDb();
    await this.prismaService.execute((prisma) =>
      prisma.scholarshipAlertSubscription.deleteMany({
        where: { userId, scholarshipId },
      }),
    );
    return { scholarshipId, subscribed: false };
  }
}
