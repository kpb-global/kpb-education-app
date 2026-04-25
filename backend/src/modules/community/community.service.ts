import { Injectable, NotFoundException } from '@nestjs/common';

import { PublicationStatus } from '../../common/enums/publication-status.enum';
import { mockAdminData } from '../../common/data/mock-admin';
import { PrismaService } from '../prisma/prisma.service';

type ForumCategoryRecord = (typeof mockAdminData.forumCategories)[number];
type ForumTagRecord = (typeof mockAdminData.forumTags)[number];

@Injectable()
export class CommunityService {
  constructor(private readonly prismaService: PrismaService) {}

  private readonly forumCategories = [...mockAdminData.forumCategories];
  private readonly forumTags = [...mockAdminData.forumTags];
  private readonly moderationQueue = [...mockAdminData.moderationQueue];

  async listForumCategories() {
    const items = await this.prismaService.execute((prisma) =>
      prisma.forumCategory.findMany({
        orderBy: { displayOrder: 'asc' },
      }),
    );

    if (items) {
      return {
        items: items.map((item) => ({
          id: item.id,
          label: { fr: item.labelFr, en: item.labelEn },
          description: {
            fr: item.descriptionFr,
            en: item.descriptionEn,
          },
          displayOrder: item.displayOrder,
          status: item.status,
        })),
      };
    }

    return { items: this.forumCategories };
  }

  async createForumCategory(input: Record<string, unknown>) {
    const record: ForumCategoryRecord = {
      id: `forum-category-${Date.now()}`,
      label:
        (input['label'] as ForumCategoryRecord['label'] | undefined) ??
        { fr: 'Nouvelle catégorie', en: 'New category' },
      description:
        (input['description'] as ForumCategoryRecord['description'] | undefined) ??
        { fr: '', en: '' },
      displayOrder:
        (input['displayOrder'] as number | undefined) ??
        this.forumCategories.length + 1,
      status:
        (input['status'] as PublicationStatus | undefined) ??
        PublicationStatus.Draft,
    };
    const created = await this.prismaService.execute((prisma) =>
      prisma.forumCategory.create({
        data: {
          labelFr: record.label.fr,
          labelEn: record.label.en,
          descriptionFr: record.description.fr,
          descriptionEn: record.description.en,
          displayOrder: record.displayOrder,
          status: record.status,
        },
      }),
    );

    if (created) {
      return {
        id: created.id,
        label: { fr: created.labelFr, en: created.labelEn },
        description: {
          fr: created.descriptionFr,
          en: created.descriptionEn,
        },
        displayOrder: created.displayOrder,
        status: created.status,
      };
    }

    this.forumCategories.push(record);
    return record;
  }

  async updateForumCategory(id: string, input: Record<string, unknown>) {
    const updated = await this.prismaService.execute((prisma) =>
      prisma.forumCategory.update({
        where: { id },
        data: {
          ...(input['label']
            ? {
                labelFr: (input['label'] as ForumCategoryRecord['label']).fr,
                labelEn: (input['label'] as ForumCategoryRecord['label']).en,
              }
            : {}),
          ...(input['description']
            ? {
                descriptionFr:
                  (input['description'] as ForumCategoryRecord['description']).fr,
                descriptionEn:
                  (input['description'] as ForumCategoryRecord['description']).en,
              }
            : {}),
          ...(input['displayOrder'] !== undefined
            ? { displayOrder: input['displayOrder'] as number }
            : {}),
          ...(input['status']
            ? { status: input['status'] as PublicationStatus }
            : {}),
        },
      }),
    );

    if (updated) {
      return {
        id: updated.id,
        label: { fr: updated.labelFr, en: updated.labelEn },
        description: {
          fr: updated.descriptionFr,
          en: updated.descriptionEn,
        },
        displayOrder: updated.displayOrder,
        status: updated.status,
      };
    }

    const index = this.forumCategories.findIndex((item) => item.id === id);
    if (index < 0) {
      throw new NotFoundException(`Forum category ${id} not found.`);
    }
    this.forumCategories[index] = {
      ...this.forumCategories[index],
      ...input,
    } as ForumCategoryRecord;
    return this.forumCategories[index];
  }

  async listForumTags() {
    const items = await this.prismaService.execute((prisma) =>
      prisma.forumTopicTag.findMany({
        orderBy: { displayOrder: 'asc' },
      }),
    );

    if (items) {
      return {
        items: items.map((item) => ({
          id: item.id,
          label: { fr: item.labelFr, en: item.labelEn },
          description: {
            fr: item.descriptionFr,
            en: item.descriptionEn,
          },
          displayOrder: item.displayOrder,
          status: item.status,
        })),
      };
    }

    return { items: this.forumTags };
  }

  async createForumTag(input: Record<string, unknown>) {
    const record: ForumTagRecord = {
      id: `forum-tag-${Date.now()}`,
      label:
        (input['label'] as ForumTagRecord['label'] | undefined) ??
        { fr: 'Nouveau tag', en: 'New tag' },
      description:
        (input['description'] as ForumTagRecord['description'] | undefined) ??
        { fr: '', en: '' },
      displayOrder:
        (input['displayOrder'] as number | undefined) ??
        this.forumTags.length + 1,
      status:
        (input['status'] as PublicationStatus | undefined) ??
        PublicationStatus.Draft,
    };
    const created = await this.prismaService.execute((prisma) =>
      prisma.forumTopicTag.create({
        data: {
          labelFr: record.label.fr,
          labelEn: record.label.en,
          descriptionFr: record.description.fr,
          descriptionEn: record.description.en,
          displayOrder: record.displayOrder,
          status: record.status,
        },
      }),
    );

    if (created) {
      return {
        id: created.id,
        label: { fr: created.labelFr, en: created.labelEn },
        description: {
          fr: created.descriptionFr,
          en: created.descriptionEn,
        },
        displayOrder: created.displayOrder,
        status: created.status,
      };
    }

    this.forumTags.push(record);
    return record;
  }

  async updateForumTag(id: string, input: Record<string, unknown>) {
    const updated = await this.prismaService.execute((prisma) =>
      prisma.forumTopicTag.update({
        where: { id },
        data: {
          ...(input['label']
            ? {
                labelFr: (input['label'] as ForumTagRecord['label']).fr,
                labelEn: (input['label'] as ForumTagRecord['label']).en,
              }
            : {}),
          ...(input['description']
            ? {
                descriptionFr:
                  (input['description'] as ForumTagRecord['description']).fr,
                descriptionEn:
                  (input['description'] as ForumTagRecord['description']).en,
              }
            : {}),
          ...(input['displayOrder'] !== undefined
            ? { displayOrder: input['displayOrder'] as number }
            : {}),
          ...(input['status']
            ? { status: input['status'] as PublicationStatus }
            : {}),
        },
      }),
    );

    if (updated) {
      return {
        id: updated.id,
        label: { fr: updated.labelFr, en: updated.labelEn },
        description: {
          fr: updated.descriptionFr,
          en: updated.descriptionEn,
        },
        displayOrder: updated.displayOrder,
        status: updated.status,
      };
    }

    const index = this.forumTags.findIndex((item) => item.id === id);
    if (index < 0) {
      throw new NotFoundException(`Forum tag ${id} not found.`);
    }
    this.forumTags[index] = {
      ...this.forumTags[index],
      ...input,
    } as ForumTagRecord;
    return this.forumTags[index];
  }

  async listModerationQueue() {
    const items = await this.prismaService.execute((prisma) =>
      prisma.forumModerationAction.findMany({
        orderBy: { createdAt: 'desc' },
      }),
    );

    if (items) {
      return {
        items: items.map((item) => ({
          id: item.id,
          subject: item.reason,
          targetType: item.targetType,
          reportsCount: 1,
          suggestedAction: item.action,
        })),
      };
    }

    return { items: this.moderationQueue };
  }
}
