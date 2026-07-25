import { Body, Controller, Post, UseGuards } from '@nestjs/common';

import { Roles } from '../../common/decorators/roles.decorator';
import { InternalRole } from '../../common/enums/internal-role.enum';
import { AdminAuthGuard } from '../../common/guards/admin-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { MilestoneReminderService } from './milestone-reminder.service';
import { OneSignalSenderService } from './onesignal-sender.service';

interface TestPushDto {
  userId: string;
  title?: string;
  body?: string;
  route?: string;
}

@Controller('admin/push')
@UseGuards(AdminAuthGuard, RolesGuard)
@Roles(InternalRole.Admin, InternalRole.SuperAdmin)
export class AdminPushController {
  constructor(
    private readonly sender: OneSignalSenderService,
    private readonly reminders: MilestoneReminderService,
  ) {}

  /// Run the deadline / milestone pass on demand (test the pipeline without
  /// waiting for the 08:00 cron). KPB-173: this used to call a second, parallel
  /// reminder service that pushed directly — bypassing the durable feed, the
  /// dedup, the quiet hours and the daily cap. It now runs the same code as the
  /// cron, so a manual trigger can no longer produce a send the scheduled path
  /// would not have produced. Re-running the same day returns `deduped`.
  @Post('deadline-reminders')
  runDeadlineReminders() {
    return this.reminders.handleDailyMilestoneReminders();
  }

  /**
   * Fire a test push to a single user (by KPB user id = OneSignal external id).
   * Useful to verify the OneSignal pipeline without the dashboard.
   *
   * KPB-173: intentionally direct — this is a diagnostic ping for one known
   * account, not a user-facing reminder. Routing it through the dispatcher
   * would write a fake entry into that person's durable feed and consume their
   * daily cap, which is exactly what a probe must not do.
   */
  @Post('test')
  async sendTest(@Body() dto: TestPushDto) {
    if (!dto?.userId) {
      return { ok: false, reason: 'userId is required' };
    }
    if (!this.sender.isConfigured) {
      return {
        ok: false,
        reason:
          'OneSignal not configured — set ONESIGNAL_APP_ID and ONESIGNAL_REST_API_KEY.',
      };
    }

    await this.sender.sendToUser(
      dto.userId,
      dto.title?.trim() || 'Test KPB Education',
      dto.body?.trim() || 'Ceci est une notification de test 🎓',
      dto.route ? { route: dto.route } : undefined,
    );

    return { ok: true, sentTo: dto.userId };
  }
}
