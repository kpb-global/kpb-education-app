import {
  Controller,
  Delete,
  Get,
  Param,
  Post,
  Req,
  UseGuards,
} from '@nestjs/common';

import { StudentAuthGuard } from '../../common/guards/student-auth.guard';
import { ScholarshipAlertsService } from './scholarship-alerts.service';

@Controller('me/scholarship-alerts')
@UseGuards(StudentAuthGuard)
export class ScholarshipAlertsController {
  constructor(private readonly scholarshipAlerts: ScholarshipAlertsService) {}

  @Get()
  list(@Req() req: any) {
    return this.scholarshipAlerts.list(req.studentUser.id);
  }

  @Post(':scholarshipId')
  subscribe(@Param('scholarshipId') scholarshipId: string, @Req() req: any) {
    return this.scholarshipAlerts.subscribe(
      req.studentUser.id,
      scholarshipId,
    );
  }

  @Delete(':scholarshipId')
  unsubscribe(@Param('scholarshipId') scholarshipId: string, @Req() req: any) {
    return this.scholarshipAlerts.unsubscribe(
      req.studentUser.id,
      scholarshipId,
    );
  }
}
