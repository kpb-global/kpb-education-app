import { randomUUID } from 'node:crypto';

import {
  Body,
  Controller,
  Get,
  Headers,
  Param,
  Patch,
  Post,
  Req,
  Res,
  UseGuards,
} from '@nestjs/common';
import type { Response } from 'express';

import { StudentAuthGuard } from '../../../common/guards/student-auth.guard';
import { idempotencyKeyRequired } from '../common/competition-readiness.errors';
import { BookStudyReviewAppointmentDto } from './dto/book-study-review-appointment.dto';
import { CreateStudyReviewRequestDto } from './dto/create-study-review-request.dto';
import { UpdateStudyReviewRequestDto } from './dto/update-study-review-request.dto';
import { StudyReviewSchedulingService } from './study-review-scheduling.service';
import { StudyReviewService } from './study-review.service';

@Controller('competition-readiness')
@UseGuards(StudentAuthGuard)
export class StudyReviewController {
  constructor(
    private readonly studyReview: StudyReviewService,
    private readonly scheduling: StudyReviewSchedulingService,
  ) {}

  @Post('workspaces/:id/review-requests')
  async create(
    @Param('id') workspaceId: string,
    @Body() input: CreateStudyReviewRequestDto,
    @Headers('idempotency-key') rawIdempotencyKey: string | undefined,
    @Req() req: any,
    @Res({ passthrough: true }) response: Response,
  ) {
    const idempotencyKey = rawIdempotencyKey?.trim();
    if (!idempotencyKey || idempotencyKey.length > 128) {
      throw idempotencyKeyRequired();
    }
    const result = await this.studyReview.create(
      req.studentUser.id,
      workspaceId,
      input,
      idempotencyKey,
    );
    response.status(result.statusCode);
    return result.reviewRequest;
  }

  @Get('review-requests/:id')
  getOne(@Param('id') reviewRequestId: string, @Req() req: any) {
    return this.studyReview.getOne(req.studentUser.id, reviewRequestId);
  }

  @Get('workspaces/:workspaceId/review-requests/active')
  getActive(
    @Param('workspaceId') workspaceId: string,
    @Req() req: any,
    @Res({ passthrough: true }) response: Response,
  ) {
    response.setHeader('Cache-Control', 'private, no-store');
    return this.studyReview.getActive(req.studentUser.id, workspaceId);
  }

  @Patch('review-requests/:id')
  update(
    @Param('id') reviewRequestId: string,
    @Body() input: UpdateStudyReviewRequestDto,
    @Req() req: any,
    @Res({ passthrough: true }) response: Response,
  ) {
    const requestId = this.attachRequestId(req, response);
    response.setHeader('Cache-Control', 'private, no-store');
    return this.studyReview.update(
      req.studentUser.id,
      reviewRequestId,
      input,
      requestId,
    );
  }

  @Get('review-requests/:id/slot-offers')
  listSlotOffers(
    @Param('id') reviewRequestId: string,
    @Req() req: any,
    @Res({ passthrough: true }) response: Response,
  ) {
    response.setHeader('Cache-Control', 'private, no-store');
    return this.scheduling.listOfferedSlots(
      req.studentUser.id,
      reviewRequestId,
    );
  }

  @Post('review-requests/:id/appointments')
  async bookAppointment(
    @Param('id') reviewRequestId: string,
    @Body() input: BookStudyReviewAppointmentDto,
    @Headers('idempotency-key') rawIdempotencyKey: string | undefined,
    @Req() req: any,
    @Res({ passthrough: true }) response: Response,
  ) {
    const idempotencyKey = rawIdempotencyKey?.trim();
    if (!idempotencyKey || idempotencyKey.length > 128) {
      throw idempotencyKeyRequired();
    }
    const requestId = this.attachRequestId(req, response);
    response.setHeader('Cache-Control', 'private, no-store');
    const result = await this.scheduling.book(
      req.studentUser.id,
      reviewRequestId,
      input,
      idempotencyKey,
      requestId,
    );
    response.status(result.statusCode);
    return result.body;
  }

  private attachRequestId(request: any, response: Response): string {
    const header = request.headers?.['x-request-id'];
    const candidate = Array.isArray(header) ? header[0] : header;
    const requestId =
      candidate && /^[A-Za-z0-9._:-]{1,120}$/.test(candidate)
        ? candidate
        : randomUUID();
    response.setHeader('X-Request-Id', requestId);
    return requestId;
  }
}
