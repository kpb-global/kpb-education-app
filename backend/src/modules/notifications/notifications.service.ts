import {
  Injectable,
  NotFoundException,
  ServiceUnavailableException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';

import { NotificationCampaignStatus } from '../../common/enums/notification-campaign-status.enum';
import { CasesService } from '../cases/cases.service';
import { PrismaService } from '../prisma/prisma.service';
import { CampaignExecutorService } from './campaign-executor.service';

interface TemplateTitle {
  fr: string;
  en: string;
}

@Injectable()
export class NotificationsService {
  constructor(
    private readonly casesService: CasesService,
    private readonly prismaService: PrismaService,
    private readonly campaignExecutor: CampaignExecutorService,
  ) {}

  private assertDb() {
    if (!this.prismaService.isEnabled) {
      throw new ServiceUnavailableException(
        'Database is not configured. Set DATABASE_URL.',
      );
    }
  }

  async listTemplates() {
    this.assertDb();
    const items =
      (await this.prismaService.execute((prisma) =>
        prisma.notificationTemplate.findMany({ orderBy: { createdAt: 'desc' } }),
      )) ?? [];
    return {
      items: items.map((item) => ({
        id: item.id,
        name: item.name,
        title: { fr: item.titleFr, en: item.titleEn },
        body: { fr: item.bodyFr, en: item.bodyEn },
        channels: item.channels,
        isCritical: item.isCritical,
      })),
    };
  }

  async createTemplate(input: Record<string, unknown>) {
    this.assertDb();
    const name = (input['name'] as string | undefined) ?? 'New template';
    const title =
      (input['title'] as TemplateTitle | undefined) ??
      { fr: 'Nouveau template', en: 'New template' };
    const body = (input['body'] as TemplateTitle | undefined) ?? { fr: '', en: '' };
    const channels = (input['channels'] as string[] | undefined) ?? ['push'];
    const isCritical = (input['isCritical'] as boolean | undefined) ?? false;

    const created = await this.prismaService.execute((prisma) =>
      prisma.notificationTemplate.create({
        data: {
          name,
          titleFr: title.fr,
          titleEn: title.en,
          bodyFr: body.fr,
          bodyEn: body.en,
          channels: channels as ('push' | 'in_app' | 'email')[],
          isCritical,
        },
      }),
    );
    if (!created) {
      throw new ServiceUnavailableException('Failed to create template.');
    }
    return {
      id: created.id,
      name: created.name,
      title: { fr: created.titleFr, en: created.titleEn },
      body: { fr: created.bodyFr, en: created.bodyEn },
      channels: created.channels,
      isCritical: created.isCritical,
    };
  }

  async updateTemplate(id: string, input: Record<string, unknown>) {
    this.assertDb();
    try {
      const updated = await this.prismaService.execute((prisma) =>
        prisma.notificationTemplate.update({
          where: { id },
          data: {
            ...(input['name'] ? { name: input['name'] as string } : {}),
            ...(input['title']
              ? {
                  titleFr: (input['title'] as TemplateTitle).fr,
                  titleEn: (input['title'] as TemplateTitle).en,
                }
              : {}),
            ...(input['body']
              ? {
                  bodyFr: (input['body'] as TemplateTitle).fr,
                  bodyEn: (input['body'] as TemplateTitle).en,
                }
              : {}),
            ...(input['channels']
              ? { channels: input['channels'] as ('push' | 'in_app' | 'email')[] }
              : {}),
            ...(input['isCritical'] !== undefined
              ? { isCritical: input['isCritical'] as boolean }
              : {}),
          },
        }),
      );
      if (!updated) {
        throw new NotFoundException(`Notification template ${id} not found.`);
      }
      return {
        id: updated.id,
        name: updated.name,
        title: { fr: updated.titleFr, en: updated.titleEn },
        body: { fr: updated.bodyFr, en: updated.bodyEn },
        channels: updated.channels,
        isCritical: updated.isCritical,
      };
    } catch (error) {
      if (
        error &&
        typeof error === 'object' &&
        'code' in error &&
        (error as { code: string }).code === 'P2025'
      ) {
        throw new NotFoundException(`Notification template ${id} not found.`);
      }
      throw error;
    }
  }

  async listCampaigns() {
    this.assertDb();
    const items =
      (await this.prismaService.execute((prisma) =>
        prisma.notificationCampaign.findMany({ orderBy: { createdAt: 'desc' } }),
      )) ?? [];
    return {
      items: items.map((item) => ({
        id: item.id,
        name: item.name,
        templateId: item.templateId,
        audienceType: item.audienceType,
        filters: item.filters as Record<string, unknown>,
        channels: item.channels,
        scheduledFor: item.scheduledFor?.toISOString() ?? null,
        status: item.status,
        linkedCaseId: item.linkedCaseId,
      })),
    };
  }

  async createCampaign(input: Record<string, unknown>) {
    this.assertDb();
    const name = (input['name'] as string | undefined) ?? 'New campaign';
    const templateId = (input['templateId'] as string | null | undefined) ?? null;
    const audienceType =
      (input['audienceType'] as string | undefined) ?? 'all_students';
    const filters =
      (input['filters'] as Record<string, unknown> | undefined) ?? {};
    const channels = (input['channels'] as string[] | undefined) ?? ['push'];
    const scheduledFor =
      (input['scheduledFor'] as string | null | undefined) ?? null;
    const linkedCaseId =
      (input['linkedCaseId'] as string | null | undefined) ?? null;
    const initialStatus = scheduledFor
      ? NotificationCampaignStatus.Scheduled
      : NotificationCampaignStatus.Sending;

    const created = await this.prismaService.execute((prisma) =>
      prisma.notificationCampaign.create({
        data: {
          name,
          templateId,
          audienceType,
          filters: filters as Prisma.InputJsonValue,
          channels: channels as ('push' | 'in_app' | 'email')[],
          scheduledFor: scheduledFor ? new Date(scheduledFor) : null,
          status: initialStatus,
          linkedCaseId,
        },
      }),
    );
    if (!created) {
      throw new ServiceUnavailableException('Failed to create campaign.');
    }

    if (!scheduledFor) {
      await this.campaignExecutor.execute(created.id).catch(() => undefined);
    }

    if (linkedCaseId) {
      await this.casesService
        .createNotificationTimelineEvent(
          linkedCaseId,
          'Notification sent',
          `A ${audienceType} campaign was triggered from the operations dashboard.`,
        )
        .catch(() => undefined);
    }

    const refreshed = await this.prismaService.execute((prisma) =>
      prisma.notificationCampaign.findUnique({ where: { id: created.id } }),
    );
    const final = refreshed ?? created;
    return {
      id: final.id,
      name: final.name,
      templateId: final.templateId,
      audienceType: final.audienceType,
      filters: final.filters,
      channels: final.channels,
      scheduledFor: final.scheduledFor?.toISOString() ?? null,
      status: final.status,
      linkedCaseId: final.linkedCaseId,
    };
  }

  async listDeliveries(campaignId: string) {
    this.assertDb();
    const items =
      (await this.prismaService.execute((prisma) =>
        prisma.notificationDelivery.findMany({
          where: { campaignId },
          orderBy: { createdAt: 'desc' },
        }),
      )) ?? [];
    return {
      items: items.map((item) => ({
        id: item.id,
        campaignId: item.campaignId,
        recipientId: item.recipientId,
        recipientName: item.recipientName,
        channel: item.channel,
        status: item.status,
        deliveredAt: item.deliveredAt?.toISOString() ?? null,
      })),
    };
  }

  async campaignStats(campaignId: string) {
    this.assertDb();
    const groups = await this.prismaService.execute((prisma) =>
      prisma.notificationDelivery.groupBy({
        by: ['channel', 'status'],
        where: { campaignId },
        _count: { _all: true },
      }),
    );

    const byChannel: Record<
      string,
      { sent: number; delivered: number; failed: number; total: number }
    > = {};

    for (const group of groups ?? []) {
      const ch = group.channel as string;
      if (!byChannel[ch]) {
        byChannel[ch] = { sent: 0, delivered: 0, failed: 0, total: 0 };
      }
      const count = group._count._all;
      byChannel[ch].total += count;
      if (group.status === 'delivered') byChannel[ch].delivered += count;
      else if (group.status === 'queued' || group.status === 'sent')
        byChannel[ch].sent += count;
      else if (group.status === 'failed') byChannel[ch].failed += count;
    }

    const totalDeliveries = Object.values(byChannel).reduce(
      (sum, ch) => sum + ch.total,
      0,
    );
    const totalDelivered = Object.values(byChannel).reduce(
      (sum, ch) => sum + ch.delivered,
      0,
    );

    return {
      campaignId,
      byChannel,
      totals: {
        sent: totalDeliveries,
        delivered: totalDelivered,
        failed: Object.values(byChannel).reduce((s, c) => s + c.failed, 0),
        deliveryRate:
          totalDeliveries > 0
            ? Math.round((totalDelivered / totalDeliveries) * 100)
            : 0,
      },
    };
  }
}
