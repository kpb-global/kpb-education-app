import { Injectable, Logger } from '@nestjs/common';
import type { NotificationCampaign } from '@prisma/client';
import { NotificationCampaignStatus } from '../../common/enums/notification-campaign-status.enum';
import { PrismaService } from '../prisma/prisma.service';
import { OneSignalSenderService } from './onesignal-sender.service';

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
    private readonly pushService: OneSignalSenderService,
  ) {}

  async execute(campaignId: string): Promise<{ enqueued: number }> {
    const campaign = await this.prismaService.execute((prisma) =>
      prisma.notificationCampaign.findUnique({ where: { id: campaignId } }),
    );
    if (!campaign) {
      this.logger.warn(`Campaign ${campaignId} not found for execution.`);
      return { enqueued: 0 };
    }

    try {
      return await this.run(campaign, campaignId);
    } catch (error) {
      // Never leave a campaign stuck in `Sending`: any failure transitions it
      // to `Failed` so the cron won't re-pick it and operators can see it.
      this.logger.error(`Campaign ${campaignId} execution failed:`, error);
      await this.prismaService.tryExecute((prisma) =>
        prisma.notificationCampaign.update({
          where: { id: campaignId },
          data: { status: NotificationCampaignStatus.Failed },
        }),
      );
      throw error;
    }
  }

  private async run(
    campaign: NotificationCampaign,
    campaignId: string,
  ): Promise<{ enqueued: number }> {
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
        const ok = await this.pushService.sendToUser(user.id, title, body, {
          campaignId,
          ...(campaign.linkedCaseId ? { caseId: campaign.linkedCaseId } : {}),
        });
        if (ok) delivered += 1;

        // Record the real per-recipient outcome instead of blanket-marking
        // every queued push as delivered (no token / send failure → failed).
        await this.prismaService.execute((prisma) =>
          prisma.notificationDelivery.updateMany({
            where: {
              campaignId,
              recipientId: user.id,
              channel: 'push',
              status: 'queued',
            },
            data: ok
              ? { status: 'delivered', deliveredAt: new Date() }
              : { status: 'failed' },
          }),
        );
      }
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
          case 'all_users': {
            // Every account, including parents — no accountType filter.
            return prisma.userProfile.findMany({
              select: {
                id: true,
                fullName: true,
                email: true,
                preferredLanguage: true,
              },
            });
          }
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
            // A missing filter must NOT fall through to "everyone".
            if (!countryId) return Promise.resolve([]);
            return prisma.userProfile.findMany({
              where: { countryOfResidence: countryId },
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
          // ── Persona (account type) ─────────────────────────────────────
          case 'account_type': {
            const accountType = filters['accountType'] as string | undefined;
            return prisma.userProfile.findMany({
              where: accountType
                ? { accountType: accountType as 'student' | 'parent' | 'partner' }
                : undefined,
              select: {
                id: true,
                fullName: true,
                email: true,
                preferredLanguage: true,
              },
            });
          }
          // ── Study level ────────────────────────────────────────────────
          case 'study_level': {
            const levels = filters['levels'] as string[] | string | undefined;
            const levelArray = Array.isArray(levels)
              ? levels
              : levels
                ? [levels]
                : undefined;
            return prisma.userProfile.findMany({
              where: {
                accountType: 'student',
                ...(levelArray ? { currentLevel: { in: levelArray } } : {}),
              },
              select: {
                id: true,
                fullName: true,
                email: true,
                preferredLanguage: true,
              },
            });
          }
          // ── Country of residence ───────────────────────────────────────
          case 'country_of_residence': {
            const countryCode = filters['countryCode'] as string | undefined;
            return prisma.userProfile.findMany({
              where: countryCode
                ? { countryOfResidence: countryCode }
                : undefined,
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
