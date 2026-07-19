import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';

import { NewsletterSyncService } from './newsletter-sync.service';

/**
 * Reconciliation sweep for the Mautic newsletter opt-in. The immediate push in
 * ProfilesService.updateMe is fire-and-forget; this cron guarantees that every
 * consent change eventually reaches Mautic (network blip, Mautic restart,
 * deploy window). Mirrors ProfileNudgeCronService's shape.
 */
@Injectable()
export class NewsletterSyncCronService {
  private readonly logger = new Logger(NewsletterSyncCronService.name);

  constructor(private readonly newsletterSync: NewsletterSyncService) {}

  /// Every 15 minutes — cheap query (indexed booleans, small batch).
  @Cron('*/15 * * * *')
  async scheduledRun(): Promise<void> {
    const { pending, synced } = await this.newsletterSync.syncPending();
    if (pending > 0) {
      this.logger.log(
        `Newsletter reconciliation: ${synced}/${pending} pending profile(s) synced to Mautic.`,
      );
    }
  }
}
