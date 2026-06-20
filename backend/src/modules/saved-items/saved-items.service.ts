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

  async findAll(userId: string) {
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

  async create(input: CreateSavedItemDto, userId: string) {
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

  async remove(id: string, userId: string) {
    this.assertDb();
    // Scope deletion to the owner: a missing item and another user's item
    // are both reported as not found (IDOR protection).
    const result = await this.prismaService.execute((prisma) =>
      prisma.savedItem.deleteMany({ where: { id, userId } }),
    );
    if (!result || result.count === 0) {
      throw new NotFoundException(`Saved item ${id} not found.`);
    }
    return { id };
  }
}
