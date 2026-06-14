import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  Req,
  UseGuards,
} from '@nestjs/common';
import { Request } from 'express';

import { Roles } from '../../common/decorators/roles.decorator';
import { InternalRole } from '../../common/enums/internal-role.enum';
import { AdminAuthGuard } from '../../common/guards/admin-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { StudentAuthGuard } from '../../common/guards/student-auth.guard';
import { SalonService } from './salon.service';

type StudentReq = Request & { studentUser?: { id: string } };

/** Public event + session listing. */
@Controller('salon')
export class SalonController {
  constructor(private readonly salonService: SalonService) {}

  @Get('events')
  listEvents() {
    return this.salonService.listEvents();
  }

  @Get('events/:slug')
  getEvent(@Param('slug') slug: string) {
    return this.salonService.getEventBySlug(slug);
  }

  @Get('sessions/:id')
  getSession(@Param('id') id: string) {
    return this.salonService.getSession(id);
  }
}

/** Authenticated student → RSVP flow. */
@Controller('me/salon')
@UseGuards(StudentAuthGuard)
export class MySalonController {
  constructor(private readonly salonService: SalonService) {}

  @Get('registrations')
  myRegistrations(@Req() req: StudentReq) {
    return this.salonService.listMyRegistrations(req.studentUser!.id);
  }

  @Post('sessions/:id/register')
  register(@Req() req: StudentReq, @Param('id') sessionId: string) {
    return this.salonService.register(req.studentUser!.id, sessionId);
  }

  @Delete('sessions/:id/register')
  cancel(@Req() req: StudentReq, @Param('id') sessionId: string) {
    return this.salonService.cancelRegistration(
      req.studentUser!.id,
      sessionId,
    );
  }
}

/** Admin — manage events, sessions, and inspect registrations. */
@Controller('admin/salon')
@UseGuards(AdminAuthGuard, RolesGuard)
@Roles(
  InternalRole.Admin,
  InternalRole.SuperAdmin,
  InternalRole.ContentManager,
)
export class AdminSalonController {
  constructor(private readonly salonService: SalonService) {}

  @Get('events')
  listEvents() {
    return this.salonService.listAdminEvents();
  }

  @Post('events')
  createEvent(@Body() body: Parameters<SalonService['createEvent']>[0]) {
    return this.salonService.createEvent(body);
  }

  @Patch('events/:id')
  updateEvent(
    @Param('id') id: string,
    @Body() body: Parameters<SalonService['updateEvent']>[1],
  ) {
    return this.salonService.updateEvent(id, body);
  }

  @Post('sessions')
  createSession(@Body() body: Parameters<SalonService['createSession']>[0]) {
    return this.salonService.createSession(body);
  }

  @Patch('sessions/:id')
  updateSession(
    @Param('id') id: string,
    @Body() body: Parameters<SalonService['updateSession']>[1],
  ) {
    return this.salonService.updateSession(id, body);
  }

  @Get('sessions/:id/registrations')
  sessionRegistrations(@Param('id') sessionId: string) {
    return this.salonService.listSessionRegistrations(sessionId);
  }
}
