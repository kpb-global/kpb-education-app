import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';

import { NotificationCampaignStatus } from '../../common/enums/notification-campaign-status.enum';
import { PrismaService } from '../prisma/prisma.service';
import { CampaignExecutorService } from './campaign-executor.service';

@Injectable()
export class CampaignCronService {
  private readonly logger = new Logger(CampaignCronService.name);

  constructor(
    private readonly prismaService: PrismaService,
    private readonly campaignExecutor: CampaignExecutorService,
  ) {}

  @Cron(CronExpression.EVERY_MINUTE)
  async handleScheduledCampaigns() {
    if (!this.prismaService.isEnabled) {
      return;
    }

    try {
      const now = new Date();
      
      const pendingCampaigns = await this.prismaService.execute((prisma) =>
        prisma.notificationCampaign.findMany({
          where: {
            status: NotificationCampaignStatus.Scheduled,
            scheduledFor: { lte: now },
          },
          take: 10,
        }),
      );

      if (!pendingCampaigns || pendingCampaigns.length === 0) {
        return;
      }

      this.logger.log(`Found ${pendingCampaigns.length} scheduled campaigns to execute.`);

      for (const campaign of pendingCampaigns) {
        await this.prismaService.execute((prisma) =>
          prisma.notificationCampaign.update({
            where: { id: campaign.id },
            data: { status: NotificationCampaignStatus.Sending },
          }),
        );

        this.logger.log(`Executing scheduled campaign ${campaign.id} ("${campaign.name}")`);
        await this.campaignExecutor.execute(campaign.id).catch((error) => {
          this.logger.error(`Failed to execute scheduled campaign ${campaign.id}:`, error);
        });
      }
    } catch (error) {
      this.logger.error('Error while checking for scheduled campaigns:', error);
    }
  }
}
