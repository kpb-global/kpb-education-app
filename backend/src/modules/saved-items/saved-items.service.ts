import {
  Injectable,
  NotFoundException,
  ServiceUnavailableException,
} from '@nestjs/common';

import { PrismaService } from '../prisma/prisma.service';
import { CreateSavedItemDto } from './dto/create-saved-item.dto';

@Injectable()
export class SavedItemsService {
  constructor(private readonly prismaService: PrismaService) {}

  private assertDb() {
    if (!this.prismaService.isEnabled) {
      throw new ServiceUnavailableException(
        'Database is not configured. Set DATABASE_URL.',
      );
    }
  }

  async findAll(userId = 'demo-user') {
    this.assertDb();
    const items = await this.prismaService.execute((prisma) =>
      prisma.savedItem.findMany({
        where: { userId },
        orderBy: { createdAt: 'desc' },
      }),
    );
    return (items ?? []).map((item) => ({
      id: item.id,
      userId: item.userId,
      type: item.itemType,
      itemId: item.itemId,
      createdAt: item.createdAt.toISOString(),
    }));
  }

  async create(input: CreateSavedItemDto, userId = 'demo-user') {
    this.assertDb();
    const created = await this.prismaService.execute(async (prisma) => {
      const existing = await prisma.savedItem.findUnique({
        where: {
          userId_itemType_itemId: {
            userId,
            itemType: input.type,
            itemId: input.itemId,
          },
        },
      });
      if (existing) return existing;
      return prisma.savedItem.create({
        data: { userId, itemType: input.type, itemId: input.itemId },
      });
    });
    if (!created) {
      throw new ServiceUnavailableException('Failed to persist saved item.');
    }
    return {
      id: created.id,
      userId: created.userId,
      type: created.itemType,
      itemId: created.itemId,
      createdAt: created.createdAt.toISOString(),
    };
  }

  async remove(id: string) {
    this.assertDb();
    try {
      const deleted = await this.prismaService.execute((prisma) =>
        prisma.savedItem.delete({ where: { id } }),
      );
      if (!deleted) {
        throw new NotFoundException(`Saved item ${id} not found.`);
      }
      return {
        id: deleted.id,
        userId: deleted.userId,
        type: deleted.itemType,
        itemId: deleted.itemId,
        createdAt: deleted.createdAt.toISOString(),
      };
    } catch (error) {
      if (
        error &&
        typeof error === 'object' &&
        'code' in error &&
        (error as { code: string }).code === 'P2025'
      ) {
        throw new NotFoundException(`Saved item ${id} not found.`);
      }
      throw error;
    }
  }
}
