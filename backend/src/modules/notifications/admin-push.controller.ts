import { Body, Controller, Post, UseGuards } from '@nestjs/common';

import { Roles } from '../../common/decorators/roles.decorator';
import { InternalRole } from '../../common/enums/internal-role.enum';
import { AdminAuthGuard } from '../../common/guards/admin-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { DeadlineReminderCronService } from './deadline-reminder-cron.service';
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
    private readonly reminders: DeadlineReminderCronService,
  ) {}

  /// Run the scholarship deadline-reminder pass on demand (test the pipeline
  /// without waiting for the daily cron).
  @Post('deadline-reminders')
  runDeadlineReminders() {
    return this.reminders.run();
  }

  /**
   * Fire a test push to a single user (by KPB user id = OneSignal external id).
   * Useful to verify the OneSignal pipeline without the dashboard.
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
