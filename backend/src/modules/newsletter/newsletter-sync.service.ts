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

/// What Mautic must be told about one profile, if anything.
export type NewsletterAction = 'none' | 'subscribe' | 'unsubscribe';

/**
 * Resolves the pair (desired opt-in, last state pushed to Mautic) into the one
 * action Mautic needs. Extracted and named because the naive
 * `synced === desired` test that used to live here got the privacy-critical
 * case wrong.
 *
 * Three states, and the two opt-out ones demand the OPPOSITE of each other
 * while looking almost identical in the row:
 *   • (desired false, synced null) — NEVER consented. Mautic must not be
 *     contacted at all. `null !== false`, so the old equality test fell
 *     through and called syncContact(profile, false), whose upsert step ships
 *     e-mail, first name, last name, phone, WhatsApp, country and locale
 *     BEFORE it branches on the flag. The privacy policy promises the data
 *     goes out "only if you consented", so this row must produce silence.
 *   • (desired false, synced true) — consent WITHDRAWN after a real push.
 *     Mautic MUST be contacted: skipping it would keep mailing someone who
 *     said no, which is the mirror-image failure.
 *   • (desired true, synced anything but true) — consent given: subscribe.
 *
 * `null` is therefore load-bearing, not a lazy default: it is the only record
 * that Mautic holds nothing about this profile, and the sole thing keeping the
 * first two cases apart. Which is why the "never consented" branch below
 * writes nothing — stamping `false` would forge proof of an opt-out push that
 * never happened and collapse the two states into one.
 */
export function resolveNewsletterAction(
  desiredOptIn: boolean,
  syncedOptIn: boolean | null,
): NewsletterAction {
  if (desiredOptIn) return syncedOptIn === true ? 'none' : 'subscribe';
  return syncedOptIn === true ? 'unsubscribe' : 'none';
}

@Injectable()
export class NewsletterSyncService {
  private readonly logger = new Logger(NewsletterSyncService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly mautic: MauticService,
  ) {}

  /// Syncs one profile when, and only when, resolveNewsletterAction says
  /// Mautic has something to learn about it.
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

    const action = resolveNewsletterAction(
      profile.newsletterOptIn,
      profile.newsletterSyncedOptIn,
    );
    // `none` covers both "already in sync" and "never consented"; in the
    // latter case returning before the try block is the whole guard, so keep
    // every network call and every write below this line.
    if (action === 'none') return true;

    try {
      await this.mautic.syncContact(profile, action === 'subscribe');
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
          // These three branches are exactly the rows resolveNewsletterAction
          // answers with something other than `none`. The fourth combination,
          // (synced null, optIn false) — never consented, never synced — is
          // absent on purpose: sweeping it would hand Mautic a profile that
          // never opted in. syncProfile refuses it anyway, so the two layers
          // agree; do not "complete" this list.
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
