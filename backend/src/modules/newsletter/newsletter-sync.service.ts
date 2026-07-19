// ─────────────────────────────────────────────────────────────────────────────
// NewsletterSyncService — state reconciliation between the profile's desired
// newsletter opt-in (`newsletterOptIn`) and what Mautic actually holds
// (`newsletterSyncedOptIn`). Called fire-and-forget right after a consent
// change for low latency, and swept by NewsletterSyncCronService so a failed
// push self-heals. Idempotent by design: Mautic upserts by email and
// segment add/remove converge, so re-syncing the same state is harmless.
// ─────────────────────────────────────────────────────────────────────────────

import { Injectable, Logger } from '@nestjs/common';

import { PrismaService } from '../prisma/prisma.service';
import { MauticService } from './mautic.service';

const PENDING_BATCH = 100;

@Injectable()
export class NewsletterSyncService {
  private readonly logger = new Logger(NewsletterSyncService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly mautic: MauticService,
  ) {}

  /// Syncs one profile if its desired state differs from the synced state.
  /// Never throws — failures stay pending and the cron retries them.
  async syncProfile(profileId: string): Promise<boolean> {
    if (!this.mautic.isConfigured || !this.prisma.isEnabled) return false;

    const profile = await this.prisma.execute((p) =>
      p.userProfile.findUnique({
        where: { id: profileId },
        select: {
          id: true,
          email: true,
          fullName: true,
          phone: true,
          whatsApp: true,
          countryOfResidence: true,
          preferredLanguage: true,
          newsletterOptIn: true,
          newsletterSyncedOptIn: true,
        },
      }),
    );
    if (!profile) return false;
    if (profile.newsletterSyncedOptIn === profile.newsletterOptIn) return true;

    try {
      await this.mautic.syncContact(profile, profile.newsletterOptIn);
      await this.prisma.execute((p) =>
        p.userProfile.update({
          where: { id: profile.id },
          data: { newsletterSyncedOptIn: profile.newsletterOptIn },
        }),
      );
      return true;
    } catch (error) {
      this.logger.warn(
        `Newsletter sync failed for profile ${profile.id} (will retry via cron): ${
          error instanceof Error ? error.message : error
        }`,
      );
      return false;
    }
  }

  /// Sweeps profiles whose desired state was never pushed (or a previous push
  /// failed). Returns counts for logging/tests.
  async syncPending(): Promise<{ pending: number; synced: number }> {
    if (!this.mautic.isConfigured || !this.prisma.isEnabled) {
      return { pending: 0, synced: 0 };
    }

    const pending = await this.prisma.execute((p) =>
      p.userProfile.findMany({
        where: {
          OR: [
            // Never synced but the user opted in.
            { newsletterSyncedOptIn: null, newsletterOptIn: true },
            // Opted in, last sync recorded an opt-out (or vice versa).
            { newsletterSyncedOptIn: false, newsletterOptIn: true },
            { newsletterSyncedOptIn: true, newsletterOptIn: false },
          ],
        },
        select: { id: true },
        take: PENDING_BATCH,
      }),
    );
    if (!pending || pending.length === 0) return { pending: 0, synced: 0 };

    let synced = 0;
    for (const { id } of pending) {
      if (await this.syncProfile(id)) synced += 1;
    }
    return { pending: pending.length, synced };
  }
}
