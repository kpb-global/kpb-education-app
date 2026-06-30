import { Injectable, Logger } from '@nestjs/common';

import { PrismaService } from '../prisma/prisma.service';
import { OneSignalSenderService } from './onesignal-sender.service';

/**
 * Sprint 8 — pushes a reminder to every user who saved a scholarship when its
 * deadline is approaching. Sends at fixed thresholds (7 days, then 1 day).
 *
 * KPB-64: the daily auto-fire was removed when MilestoneReminderService took
 * over the unified, bilingual deadline/milestone cron — running both at 08:00
 * double-sent scholarship reminders. `run()` is kept as a manual-only helper,
 * still triggered on demand by the admin push controller.
 */
@Injectable()
export class DeadlineReminderCronService {
  private readonly logger = new Logger(DeadlineReminderCronService.name);
  private static readonly THRESHOLD_DAYS = [7, 1];
  private static readonly DAY_MS = 24 * 60 * 60 * 1000;

  constructor(
    private readonly prisma: PrismaService,
    private readonly push: OneSignalSenderService,
  ) {}

  /// Core logic, also callable from an admin endpoint for testing.
  async run(): Promise<{ scholarshipsDue: number; remindersSent: number }> {
    const now = new Date();
    const horizon = new Date(
      now.getTime() + 8 * DeadlineReminderCronService.DAY_MS,
    );

    const scholarships = await this.prisma.execute((p) =>
      p.scholarship.findMany({
        where: {
          isActive: true,
          moderationStatus: 'approved',
          deadlineAt: { gte: now, lte: horizon },
        },
        select: { id: true, nameFr: true, deadlineAt: true },
      }),
    );

    let scholarshipsDue = 0;
    let remindersSent = 0;

    for (const s of scholarships ?? []) {
      if (!s.deadlineAt) continue;
      const days = Math.ceil(
        (s.deadlineAt.getTime() - now.getTime()) /
          DeadlineReminderCronService.DAY_MS,
      );
      if (!DeadlineReminderCronService.THRESHOLD_DAYS.includes(days)) continue;
      scholarshipsDue++;

      const savers = await this.prisma.execute((p) =>
        p.savedItem.findMany({
          where: { itemType: 'scholarship', itemId: s.id },
          select: { userId: true },
        }),
      );
      if (!savers?.length) continue;

      const body =
        days <= 1
          ? `La bourse « ${s.nameFr} » clôture demain — finalise ta candidature !`
          : `La bourse « ${s.nameFr} » clôture dans ${days} jours.`;

      for (const { userId } of savers) {
        const ok = await this.push.sendToUser(userId, '⏰ Échéance bourse', body, {
          type: 'scholarship_deadline',
          scholarshipId: s.id,
        });
        if (ok) remindersSent++;
      }
    }

    this.logger.log(
      `Deadline reminders: ${scholarshipsDue} scholarship(s) at threshold, ${remindersSent} push(es) sent.`,
    );
    return { scholarshipsDue, remindersSent };
  }
}
