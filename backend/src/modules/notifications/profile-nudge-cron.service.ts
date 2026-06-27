import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';

import { PrismaService } from '../prisma/prisma.service';
import { OneSignalSenderService } from './onesignal-sender.service';

/**
 * KPB-76 — re-engagement nudge for students with an incomplete profile. An
 * incomplete profile degrades every personalization surface (eligibility,
 * scholarship ranking, coach budget anchoring), and the completion counter is
 * ignored if it never moves. Mirrors DeadlineReminderCronService.
 *
 * Throttled via `profileNudgedAt` so a user is reminded at most monthly. The
 * push deep-links to `/profile` (route registered in KPB-63).
 */
@Injectable()
export class ProfileNudgeCronService {
  private readonly logger = new Logger(ProfileNudgeCronService.name);
  private static readonly RENUDGE_DAYS = 30;
  private static readonly BATCH = 500;
  private static readonly DAY_MS = 24 * 60 * 60 * 1000;

  constructor(
    private readonly prisma: PrismaService,
    private readonly push: OneSignalSenderService,
  ) {}

  /// Daily at 09:00 UTC (offset from the 08:00 deadline cron).
  @Cron('0 9 * * *')
  async scheduledRun(): Promise<void> {
    if (!this.prisma.isEnabled) return;
    await this.run();
  }

  /// Core logic, also callable from an admin endpoint for testing.
  async run(): Promise<{ candidates: number; nudgesSent: number }> {
    const cutoff = new Date(
      Date.now() -
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
                { monthlyBudgetEur: null },
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
        select: { id: true, preferredLanguage: true },
        take: ProfileNudgeCronService.BATCH,
      }),
    );

    let nudgesSent = 0;
    for (const u of incomplete ?? []) {
      const en = (u.preferredLanguage ?? '').toLowerCase().startsWith('en');
      const title = en ? '✨ Complete your profile' : '✨ Complète ton profil';
      const body = en
        ? 'Add your details to unlock your scholarship & school matches on KPB.'
        : 'Ajoute tes infos pour débloquer tes recommandations de bourses et d\'écoles sur KPB.';

      const ok = await this.push.sendToUser(u.id, title, body, {
        type: 'profile_nudge',
        route: '/profile',
      });
      if (ok) nudgesSent++;

      // Stamp regardless of push success so a device without a push identity
      // is not re-queried (and potentially hammered) every single day.
      await this.prisma.execute((p) =>
        p.userProfile.update({
          where: { id: u.id },
          data: { profileNudgedAt: new Date() },
        }),
      );
    }

    this.logger.log(
      `Profile nudges: ${incomplete?.length ?? 0} candidate(s), ${nudgesSent} push(es) sent.`,
    );
    return { candidates: incomplete?.length ?? 0, nudgesSent };
  }
}
