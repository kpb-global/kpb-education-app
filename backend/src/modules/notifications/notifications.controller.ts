import {
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Post,
  UseGuards,
} from '@nestjs/common';

import { Roles } from '../../common/decorators/roles.decorator';
import { InternalRole } from '../../common/enums/internal-role.enum';
import { AdminAuthGuard } from '../../common/guards/admin-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { CreateNotificationCampaignDto } from './dto/create-notification-campaign.dto';
import { UpsertNotificationTemplateDto } from './dto/upsert-notification-template.dto';
import { NotificationsService } from './notifications.service';

@Controller('admin/notifications')
@UseGuards(AdminAuthGuard, RolesGuard)
@Roles(
  InternalRole.Commercial,
  InternalRole.ContentManager,
  InternalRole.Admin,
  InternalRole.SuperAdmin,
)
export class NotificationsController {
  constructor(private readonly notificationsService: NotificationsService) {}

  @Get('templates')
  listTemplates() {
    return this.notificationsService.listTemplates();
  }

  @Post('templates')
  createTemplate(@Body() input: UpsertNotificationTemplateDto) {
    return this.notificationsService.createTemplate(input);
  }

  @Patch('templates/:id')
  updateTemplate(
    @Param('id') id: string,
    @Body() input: UpsertNotificationTemplateDto,
  ) {
    return this.notificationsService.updateTemplate(id, input);
  }

  @Get('campaigns')
  listCampaigns() {
    return this.notificationsService.listCampaigns();
  }

  @Post('campaigns')
  createCampaign(@Body() input: CreateNotificationCampaignDto) {
    return this.notificationsService.createCampaign(input);
  }

  @Get('campaigns/:id/deliveries')
  listDeliveries(@Param('id') id: string) {
    return this.notificationsService.listDeliveries(id);
  }
}
