import {
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';

import { Roles } from '../../common/decorators/roles.decorator';
import { InternalRole } from '../../common/enums/internal-role.enum';
import { AdminAuthGuard } from '../../common/guards/admin-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { StudentAuthGuard } from '../../common/guards/student-auth.guard';
import { CounsellorsService } from './counsellors.service';

/** Public (mobile) — browse the marketplace. */
@Controller('counsellors')
export class CounsellorsController {
  constructor(private readonly counsellorsService: CounsellorsService) {}

  @Get()
  list(
    @Query('country') country?: string,
    @Query('specialty') specialty?: string,
  ) {
    return this.counsellorsService.listPublic({
      countryOfResidence: country,
      specialty,
    });
  }

  @Get(':id')
  get(@Param('id') id: string) {
    return this.counsellorsService.getPublic(id);
  }

  /**
   * Authenticated students can leave a review after a completed case. The
   * review enters moderation (isPublished=false) — admin publishes it via
   * the admin endpoint below.
   */
  @Post(':id/reviews')
  @UseGuards(StudentAuthGuard)
  createReview(
    @Param('id') id: string,
    @Body()
    body: {
      rating: number;
      body: string;
      reviewerName: string;
      caseId?: string;
    },
  ) {
    return this.counsellorsService.createReview(id, body);
  }
}

/** Admin — KYC queue + CRUD. */
@Controller('admin/counsellors')
@UseGuards(AdminAuthGuard, RolesGuard)
@Roles(InternalRole.Admin, InternalRole.SuperAdmin, InternalRole.Moderator)
export class AdminCounsellorsController {
  constructor(private readonly counsellorsService: CounsellorsService) {}

  @Get()
  list(@Query('kycStatus') kycStatus?: string) {
    return this.counsellorsService.listAdmin({ kycStatus });
  }

  @Post()
  create(@Body() input: Record<string, unknown>) {
    return this.counsellorsService.create(input);
  }

  @Patch(':id')
  update(@Param('id') id: string, @Body() input: Record<string, unknown>) {
    return this.counsellorsService.update(id, input);
  }

  @Patch(':id/kyc')
  updateKyc(
    @Param('id') id: string,
    @Body() input: { kycStatus: string; kycNotes?: string | null },
  ) {
    return this.counsellorsService.updateKyc(
      id,
      input as Parameters<CounsellorsService['updateKyc']>[1],
    );
  }

  @Patch('reviews/:reviewId/publish')
  publishReview(
    @Param('reviewId') reviewId: string,
    @Body() input: { isPublished: boolean },
  ) {
    return this.counsellorsService.setReviewPublished(
      reviewId,
      input.isPublished,
    );
  }
}
