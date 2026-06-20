import { Body, Controller, Get, Param, Patch, Query, UseGuards } from '@nestjs/common';

import { Roles } from '../../common/decorators/roles.decorator';
import { InternalRole } from '../../common/enums/internal-role.enum';
import { AdminAuthGuard } from '../../common/guards/admin-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { CommercialService } from './commercial.service';

@Controller('commercial')
@UseGuards(AdminAuthGuard, RolesGuard)
@Roles(InternalRole.Commercial, InternalRole.Admin, InternalRole.SuperAdmin)
export class CommercialController {
  constructor(private readonly commercialService: CommercialService) {}

  @Get('leads')
  listLeads(
    @Query('email') email?: string,
    @Query('filter') filter?: string,
  ) {
    return this.commercialService.listLeads(email, filter);
  }

  @Patch('leads/:id')
  updateLead(
    @Param('id') id: string,
    @Body() body: { leadTag?: string; discussionMotive?: string },
  ) {
    return this.commercialService.updateLead(id, {
      leadTag: body.leadTag as never,
      discussionMotive: body.discussionMotive,
    });
  }

  @Get('stats')
  stats(@Query('email') email?: string) {
    return this.commercialService.stats(email);
  }

  // ── Admin only — performance overview for all counsellors ────────────────
  // Method-level @Roles overrides the class default (Reflector.getAllAndOverride).
  @Get('performance')
  @Roles(InternalRole.Admin, InternalRole.SuperAdmin)
  performance() {
    return this.commercialService.performance();
  }
}
