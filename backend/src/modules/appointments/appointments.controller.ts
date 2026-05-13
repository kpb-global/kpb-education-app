import { Body, Controller, Get, Post, Req, UseGuards } from '@nestjs/common';
import { StudentAuthGuard } from '../../common/guards/student-auth.guard';

import { AppointmentsService } from './appointments.service';
import { CreateAppointmentDto } from './dto/create-appointment.dto';

@Controller('appointments')
@UseGuards(StudentAuthGuard)
export class AppointmentsController {
  constructor(private readonly appointmentsService: AppointmentsService) {}

  @Get()
  findAll(@Req() req: any) {
    return this.appointmentsService.findAll(req.studentUser.id);
  }

  @Post()
  create(@Body() input: CreateAppointmentDto, @Req() req: any) {
    return this.appointmentsService.create(input, req.studentUser.id);
  }
}
