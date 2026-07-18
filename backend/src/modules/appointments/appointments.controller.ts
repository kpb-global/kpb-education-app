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
import { StudentAuthGuard } from '../../common/guards/student-auth.guard';
import { idempotencyKeyRequired } from '../competition-readiness/common/competition-readiness.errors';
import { CancelStudyReviewAppointmentDto } from '../competition-readiness/reviews/dto/cancel-study-review-appointment.dto';
import { RescheduleStudyReviewAppointmentDto } from '../competition-readiness/reviews/dto/reschedule-study-review-appointment.dto';
import { StudyReviewSchedulingService } from '../competition-readiness/reviews/study-review-scheduling.service';

import { AppointmentsService } from './appointments.service';
import { CreateAppointmentDto } from './dto/create-appointment.dto';

@Controller('appointments')
@UseGuards(StudentAuthGuard)
export class AppointmentsController {
  constructor(
    private readonly appointmentsService: AppointmentsService,
    private readonly studyReviewScheduling: StudyReviewSchedulingService,
  ) {}

  @Get()
  findAll(@Req() req: any) {
    return this.appointmentsService.findAll(req.studentUser.id);
  }

  @Post()
  create(@Body() input: CreateAppointmentDto, @Req() req: any) {
    return this.appointmentsService.create(input, req.studentUser.id);
  }

  @Patch(':id/cancel')
  async cancelStudyReviewAppointment(
    @Param('id') appointmentId: string,
    @Body() input: CancelStudyReviewAppointmentDto,
    @Headers('idempotency-key') rawIdempotencyKey: string | undefined,
    @Req() req: any,
    @Res({ passthrough: true }) response: Response,
  ) {
    const idempotencyKey = this.requireIdempotencyKey(rawIdempotencyKey);
    const requestId = this.attachRequestId(req, response);
    response.setHeader('Cache-Control', 'private, no-store');
    const result = await this.studyReviewScheduling.cancel(
      req.studentUser.id,
      appointmentId,
      input,
      idempotencyKey,
      requestId,
    );
    response.status(result.statusCode);
    return result.body;
  }

  @Patch(':id/reschedule')
  async rescheduleStudyReviewAppointment(
    @Param('id') appointmentId: string,
    @Body() input: RescheduleStudyReviewAppointmentDto,
    @Headers('idempotency-key') rawIdempotencyKey: string | undefined,
    @Req() req: any,
    @Res({ passthrough: true }) response: Response,
  ) {
    const idempotencyKey = this.requireIdempotencyKey(rawIdempotencyKey);
    const requestId = this.attachRequestId(req, response);
    response.setHeader('Cache-Control', 'private, no-store');
    const result = await this.studyReviewScheduling.reschedule(
      req.studentUser.id,
      appointmentId,
      input,
      idempotencyKey,
      requestId,
    );
    response.status(result.statusCode);
    return result.body;
  }

  private requireIdempotencyKey(value: string | undefined): string {
    const key = value?.trim();
    if (!key || key.length > 128) throw idempotencyKeyRequired();
    return key;
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
