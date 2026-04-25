import { Controller, HttpCode, HttpStatus, Post, UseGuards } from '@nestjs/common';

import { Roles } from '../../common/decorators/roles.decorator';
import { InternalRole } from '../../common/enums/internal-role.enum';
import { AdminAuthGuard } from '../../common/guards/admin-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { ScholarshipsIndexService } from './scholarships-index.service';

/**
 * Admin-only trigger for an out-of-band scholarship refresh. The weekly cron
 * handles steady-state maintenance; this endpoint exists so an operator can
 * react to a new funding announcement without waiting for the next run.
 *
 * Returned payload reports per-source counts (fetched / upserted /
 * deactivated / error) so admins can spot broken scrapers quickly. If a
 * source returns `error`, the UI should surface it alongside the prefix.
 */
@Controller('admin/scholarships')
@UseGuards(AdminAuthGuard, RolesGuard)
@Roles(InternalRole.Admin, InternalRole.SuperAdmin, InternalRole.ContentManager)
export class AdminScholarshipsController {
  constructor(
    private readonly scholarshipsIndexService: ScholarshipsIndexService,
  ) {}

  @Post('refresh')
  @HttpCode(HttpStatus.OK)
  refresh() {
    return this.scholarshipsIndexService.refresh();
  }
}
