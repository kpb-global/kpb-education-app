import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';

import { PrismaService } from '../prisma/prisma.service';
import { NotificationDispatchService } from './notification-dispatch.service';

/**
 * KPB-76 — re-engagement nudge for students with an incomplete profile. An
 * incomplete profile degrades every personalization surface (eligibility,
 * scholarship ranking, coach budget anchoring), and the completion counter is
 * ignored if it never moves.
 *
 * Throttled via `profileNudgedAt` so a user is reminded at most monthly. The
 * push deep-links to `/profile` (route registered in KPB-63).
 *
 * KPB-173: goes through NotificationDispatchService. This is the textbook case
 * quiet hours exist for — an unsolicited re-engagement ping, with no
 * time-criticality whatsoever. It also now lands in the durable feed, so a
 * student who was asleep still finds the nudge in the app.
 */
@Injectable()
export class ProfileNudgeCronService {
  private readonly logger = new Logger(ProfileNudgeCronService.name);
  private static readonly RENUDGE_DAYS = 30;
  private static readonly BATCH = 500;
  private static readonly DAY_MS = 24 * 60 * 60 * 1000;

  constructor(
    private readonly prisma: PrismaService,
    private readonly dispatch: NotificationDispatchService,
  ) {}

  /// Daily at 09:00 UTC (offset from the 08:00 deadline cron).
  @Cron('0 9 * * *')
  async scheduledRun(): Promise<void> {
    if (!this.prisma.isEnabled) return;
    await this.run();
  }

  /// Core logic, also callable from an admin endpoint for testing.
  async run(now = new Date()): Promise<{
    candidates: number;
    nudgesSent: number;
  }> {
    const cutoff = new Date(
      now.getTime() -
        ProfileNudgeCronService.RENUDGE_DAYS * ProfileNudgeCronService.DAY_MS,
    );

    const incomplete = await this.prisma.execute((p) =>
      p.userProfile.findMany({
        where: {
          accountType: 'student',
          AND: [
            {
              // Missing any high-value personalization field.
              OR: [
                { currentLevel: null },
                { targetLevel: null },
                { annualTuitionBudgetEur: null },
                { fieldIds: { isEmpty: true } },
                { targetCountryIds: { isEmpty: true } },
              ],
            },
            {
              // Not nudged within the throttle window.
              OR: [
                { profileNudgedAt: null },
                { profileNudgedAt: { lt: cutoff } },
              ],
            },
          ],
        },
        select: {
          id: true,
          preferredLanguage: true,
          countryOfResidence: true,
        },
        take: ProfileNudgeCronService.BATCH,
      }),
    );

    // One key per user per month — the same window as the profileNudgedAt
    // throttle, so a retried run cannot double-nudge.
    const monthKey = now.toISOString().slice(0, 7);

    let nudgesSent = 0;
    for (const u of incomplete ?? []) {
      const outcome = await this.dispatch.dispatch({
        userId: u.id,
        kind: 'profile_nudge',
        dedupeKey: `profile-nudge:${monthKey}:${u.id}`,
        title: {
          fr: '✨ Complète ton profil',
          en: '✨ Complete your profile',
        },
        body: {
          fr: 'Ajoute tes infos pour débloquer tes recommandations de bourses et d\'écoles sur KPB.',
          en: 'Add your details to unlock your scholarship & school matches on KPB.',
        },
        route: '/profile',
        data: { type: 'profile_nudge' },
        preferredLanguage: u.preferredLanguage,
        countryOfResidence: u.countryOfResidence,
        now,
      });
      if (outcome === 'pushed') nudgesSent++;

      // Stamp regardless of the push outcome so a student whose push was held
      // back (quiet hours, cap) is not re-queried — and potentially hammered —
      // every single day. The reminder is already in their feed.
      await this.prisma.execute((p) =>
        p.userProfile.update({
          where: { id: u.id },
          data: { profileNudgedAt: now },
        }),
      );
    }

    this.logger.log(
      `Profile nudges: ${incomplete?.length ?? 0} candidate(s), ${nudgesSent} push(es) sent.`,
    );
    return { candidates: incomplete?.length ?? 0, nudgesSent };
  }
}
