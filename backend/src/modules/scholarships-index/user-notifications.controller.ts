import {
  Controller,
  Get,
  Param,
  Patch,
  Post,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';

import { StudentAuthGuard } from '../../common/guards/student-auth.guard';
import { UserNotificationsService } from './user-notifications.service';

@Controller('me/notifications')
@UseGuards(StudentAuthGuard)
export class UserNotificationsController {
  constructor(private readonly notifications: UserNotificationsService) {}

  @Get()
  list(@Req() req: any, @Query('lang') lang: string = 'fr') {
    return this.notifications.list(
      req.studentUser.id,
      lang === 'en' ? 'en' : 'fr',
    );
  }

  @Patch(':id/read')
  markRead(@Param('id') id: string, @Req() req: any) {
    return this.notifications.markRead(req.studentUser.id, id);
  }

  @Post('read-all')
  markAllRead(@Req() req: any) {
    return this.notifications.markAllRead(req.studentUser.id);
  }
}
