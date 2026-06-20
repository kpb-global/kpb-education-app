import { Controller, Get, UseGuards } from '@nestjs/common';

import { Roles } from '../../common/decorators/roles.decorator';
import { InternalRole } from '../../common/enums/internal-role.enum';
import { AdminAuthGuard } from '../../common/guards/admin-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { AdminDashboardService } from './admin-dashboard.service';

@Controller('admin/dashboard')
@UseGuards(AdminAuthGuard, RolesGuard)
@Roles(
  InternalRole.Admin,
  InternalRole.SuperAdmin,
  InternalRole.Counselor,
  InternalRole.Commercial,
)
export class AdminDashboardController {
  constructor(private readonly dashboardService: AdminDashboardService) {}

  @Get()
  getKpis() {
    return this.dashboardService.getKpis();
  }
}
