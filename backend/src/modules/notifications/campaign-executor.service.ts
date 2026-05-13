import { Injectable, Logger } from '@nestjs/common';
import { NotificationCampaignStatus } from '../../common/enums/notification-campaign-status.enum';
import { PrismaService } from '../prisma/prisma.service';
import { FirebasePushService } from './firebase-push.service';

interface ResolvedTemplate {
  titleFr: string;
  titleEn: string;
  bodyFr: string;
  bodyEn: string;
}

@Injectable()
export class CampaignExecutorService {
  private readonly logger = new Logger(CampaignExecutorService.name);

  constructor(
    private readonly prismaService: PrismaService,
    private readonly pushService: FirebasePushService,
  ) {}

  async execute(campaignId: string): Promise<{ enqueued: number }> {
    const campaign = await this.prismaService.execute((prisma) =>
      prisma.notificationCampaign.findUnique({ where: { id: campaignId } }),
    );
    if (!campaign) {
      this.logger.warn(`Campaign ${campaignId} not found for execution.`);
      return { enqueued: 0 };
    }

    const templateRow = campaign.templateId
      ? await this.prismaService.execute((prisma) =>
          prisma.notificationTemplate.findUnique({
            where: { id: campaign.templateId! },
          }),
        )
      : null;
    const template: ResolvedTemplate | null = templateRow
      ? {
          titleFr: templateRow.titleFr,
          titleEn: templateRow.titleEn,
          bodyFr: templateRow.bodyFr,
          bodyEn: templateRow.bodyEn,
        }
      : null;

    const recipients = await this.resolveRecipients(
      campaign.audienceType,
      (campaign.filters as Record<string, unknown>) ?? {},
    );
    if (recipients.length === 0) {
      await this.prismaService.execute((prisma) =>
        prisma.notificationCampaign.update({
          where: { id: campaignId },
          data: { status: NotificationCampaignStatus.Completed },
        }),
      );
      return { enqueued: 0 };
    }

    await this.prismaService.execute((prisma) =>
      prisma.notificationDelivery.createMany({
        data: recipients.flatMap((user) =>
          campaign.channels.map((channel) => ({
            campaignId,
            caseId: campaign.linkedCaseId,
            recipientId: user.id,
            recipientName: user.fullName ?? user.email ?? user.id,
            channel: channel as 'push' | 'in_app' | 'email',
            status: 'queued',
          })),
        ),
      }),
    );

    let delivered = 0;
    if (campaign.channels.includes('push') && template) {
      for (const user of recipients) {
        const title =
          user.preferredLanguage === 'en' ? template.titleEn : template.titleFr;
        const body =
          user.preferredLanguage === 'en' ? template.bodyEn : template.bodyFr;
        await this.pushService.sendToUser(user.id, title, body, {
          campaignId,
          ...(campaign.linkedCaseId ? { caseId: campaign.linkedCaseId } : {}),
        });
        delivered += 1;
      }

      await this.prismaService.execute((prisma) =>
        prisma.notificationDelivery.updateMany({
          where: { campaignId, channel: 'push', status: 'queued' },
          data: { status: 'delivered', deliveredAt: new Date() },
        }),
      );
    }

    if (campaign.channels.includes('email') && template) {
      let emailDelivered = 0;
      for (const user of recipients) {
        if (!user.email) continue;
        
        const title = user.preferredLanguage === 'en' ? template.titleEn : template.titleFr;
        const body = user.preferredLanguage === 'en' ? template.bodyEn : template.bodyFr;
        
        // TODO: Integrate actual email provider (e.g., SendGrid, AWS SES) here
        this.logger.log(`[MOCK EMAIL] Sending to ${user.email}: Subject: "${title}" Body: "${body.substring(0, 30)}..."`);
        emailDelivered += 1;
      }

      await this.prismaService.execute((prisma) =>
        prisma.notificationDelivery.updateMany({
          where: { campaignId, channel: 'email', status: 'queued' },
          data: { status: 'delivered', deliveredAt: new Date() },
        }),
      );
      this.logger.log(`Mock-delivered ${emailDelivered} emails for campaign ${campaignId}`);
    }

    await this.prismaService.execute((prisma) =>
      prisma.notificationCampaign.update({
        where: { id: campaignId },
        data: { status: NotificationCampaignStatus.Completed },
      }),
    );

    this.logger.log(
      `Campaign ${campaignId} executed: ${recipients.length} recipients, ${delivered} push sent.`,
    );
    return { enqueued: recipients.length };
  }

  private async resolveRecipients(
    audienceType: string,
    filters: Record<string, unknown>,
  ) {
    return (
      (await this.prismaService.execute((prisma) => {
        switch (audienceType) {
          case 'all_users':
          case 'all_students': {
            return prisma.userProfile.findMany({
              where: { accountType: 'student' },
              select: {
                id: true,
                fullName: true,
                email: true,
                preferredLanguage: true,
              },
            });
          }
          case 'country': {
            const countryId = filters['countryId'] as string | undefined;
            return prisma.userProfile.findMany({
              where: countryId ? { countryOfResidence: countryId } : undefined,
              select: {
                id: true,
                fullName: true,
                email: true,
                preferredLanguage: true,
              },
            });
          }
          case 'case_status': {
            const status = filters['status'] as string | undefined;
            return prisma.userProfile
              .findMany({
                where: status
                  ? { cases: { some: { status: status as any } } }
                  : undefined,
                select: {
                  id: true,
                  fullName: true,
                  email: true,
                  preferredLanguage: true,
                },
              })
              .catch(() => []);
          }
          case 'single_user': {
            const userId = filters['userId'] as string | undefined;
            if (!userId) return Promise.resolve([]);
            return prisma.userProfile.findMany({
              where: { id: userId },
              select: {
                id: true,
                fullName: true,
                email: true,
                preferredLanguage: true,
              },
            });
          }
          default:
            return Promise.resolve([]);
        }
      })) ?? []
    );
  }
}
