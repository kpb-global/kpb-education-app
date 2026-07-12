import { Controller, Get, UseGuards } from '@nestjs/common';

import { Roles } from '../../common/decorators/roles.decorator';
import { InternalRole } from '../../common/enums/internal-role.enum';
import { AdminAuthGuard } from '../../common/guards/admin-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { ReportsService } from './reports.service';

@Controller('admin/reports')
@UseGuards(AdminAuthGuard, RolesGuard)
@Roles(
  InternalRole.Counselor,
  InternalRole.Commercial,
  InternalRole.Admin,
  InternalRole.SuperAdmin,
)
export class ReportsController {
  constructor(private readonly reportsService: ReportsService) {}

  @Get('overview')
  getOverview() {
    return this.reportsService.getOverview();
  }

  @Get('dashboard-activation')
  getDashboardActivation() {
    return this.reportsService.getDashboardActivation();
  }

  @Get('funnel')
  getFunnel() {
    return this.reportsService.getFunnel();
  }

  @Get('counselor-performance')
  getCounselorPerformance() {
    return this.reportsService.getCounselorPerformance();
  }

  @Get('campaign-performance')
  getCampaignPerformance() {
    return this.reportsService.getCampaignPerformance();
  }

  @Get('service-revenue')
  getServiceRevenue() {
    return this.reportsService.getServiceRevenue();
  }
}
