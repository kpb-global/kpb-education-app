import {
  Injectable,
  NotFoundException,
  ServiceUnavailableException,
} from '@nestjs/common';

import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class UserNotificationsService {
  constructor(private readonly prismaService: PrismaService) {}

  private assertDb() {
    if (!this.prismaService.isEnabled) {
      throw new ServiceUnavailableException(
        'Database is not configured. Set DATABASE_URL.',
      );
    }
  }

  async list(userId: string, lang: 'fr' | 'en') {
    this.assertDb();
    const rows = await this.prismaService.execute((prisma) =>
      prisma.userNotification.findMany({
        where: { userId },
        orderBy: { createdAt: 'desc' },
        take: 100,
      }),
    );
    const items = (rows ?? []).map((row) => ({
      id: row.id,
      kind: row.kind,
      scholarshipId: row.scholarshipId,
      title: lang === 'fr' ? row.titleFr : row.titleEn,
      body: lang === 'fr' ? row.bodyFr : row.bodyEn,
      route: row.route,
      data: row.data,
      readAt: row.readAt?.toISOString() ?? null,
      createdAt: row.createdAt.toISOString(),
    }));
    return {
      items,
      unreadCount: items.filter((item) => item.readAt == null).length,
    };
  }

  async markRead(userId: string, id: string) {
    this.assertDb();
    const result = await this.prismaService.execute((prisma) =>
      prisma.userNotification.updateMany({
        where: { id, userId },
        data: { readAt: new Date() },
      }),
    );
    if (!result?.count) {
      throw new NotFoundException(`Notification ${id} not found.`);
    }
    return { id, read: true };
  }

  async markAllRead(userId: string) {
    this.assertDb();
    const result = await this.prismaService.execute((prisma) =>
      prisma.userNotification.updateMany({
        where: { userId, readAt: null },
        data: { readAt: new Date() },
      }),
    );
    return { updated: result?.count ?? 0 };
  }
}
