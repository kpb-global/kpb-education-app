import {
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';

import { Roles } from '../../common/decorators/roles.decorator';
import { InternalRole } from '../../common/enums/internal-role.enum';
import { AdminAuthGuard } from '../../common/guards/admin-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { StudentAuthGuard } from '../../common/guards/student-auth.guard';
import { ScholarshipsIndexService } from './scholarships-index.service';

/**
 * Admin: manual refresh trigger.
 * Public (student): profile-aware scholarship listing.
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

  // ── Moderation queue (Sprint 3) ───────────────────────────────────────────
  /// List scholarships by moderation status (default: pending review).
  @Get('moderation')
  listForModeration(@Query('status') status?: string) {
    const s =
      status === 'approved' || status === 'rejected' ? status : 'pending';
    return this.scholarshipsIndexService.listForModeration(s);
  }

  @Post(':id/approve')
  @HttpCode(HttpStatus.OK)
  approve(@Param('id') id: string) {
    return this.scholarshipsIndexService.setModeration(id, 'approved');
  }

  @Post(':id/reject')
  @HttpCode(HttpStatus.OK)
  reject(@Param('id') id: string) {
    return this.scholarshipsIndexService.setModeration(id, 'rejected');
  }
}

/** Public endpoint — consumed by the mobile app. */
@Controller('scholarships')
export class ScholarshipsController {
  constructor(
    private readonly scholarshipsIndexService: ScholarshipsIndexService,
  ) {}

  @Get()
  @UseGuards(StudentAuthGuard)
  list(
    @Query('lang') lang: string = 'fr',
    @Query('level') level?: string,
    @Query('fields') fields?: string,
    @Query('countryId') countryId?: string,
    @Query('fundingType') fundingType?: string,
    @Query('limit') limit?: string,
    @Query('offset') offset?: string,
  ) {
    return this.scholarshipsIndexService.listForProfile({
      lang: lang === 'en' ? 'en' : 'fr',
      level,
      fieldIds: fields ? fields.split(',') : undefined,
      countryId,
      fundingType,
      limit: limit ? parseInt(limit, 10) : 20,
      offset: offset ? parseInt(offset, 10) : 0,
    });
  }
}
