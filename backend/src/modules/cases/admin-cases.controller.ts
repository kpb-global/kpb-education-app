import { Body, Controller, Get, Param, Patch, Post, UseGuards } from '@nestjs/common';

import { Roles } from '../../common/decorators/roles.decorator';
import { InternalRole } from '../../common/enums/internal-role.enum';
import { AdminAuthGuard } from '../../common/guards/admin-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { CasesService } from './cases.service';
import { AssignCaseDto } from './dto/assign-case.dto';
import { CreateCaseInternalNoteDto } from './dto/create-case-internal-note.dto';
import { CreateCaseTaskDto } from './dto/create-case-task.dto';
import { CreateCaseTimelineEventDto } from './dto/create-case-timeline-event.dto';
import { UpdateCaseDto } from './dto/update-case.dto';

@Controller('admin/cases')
@UseGuards(AdminAuthGuard, RolesGuard)
@Roles(
  InternalRole.Counselor,
  InternalRole.Commercial,
  InternalRole.Admin,
  InternalRole.SuperAdmin,
)
export class AdminCasesController {
  constructor(private readonly casesService: CasesService) {}

  @Get()
  findAll() {
    return this.casesService.findAllForAdmin();
  }

  @Patch(':id')
  update(@Param('id') id: string, @Body() input: UpdateCaseDto) {
    return this.casesService.update(id, input);
  }

  @Post(':id/assign')
  assign(@Param('id') id: string, @Body() input: AssignCaseDto) {
    return this.casesService.assignCase(id, input);
  }

  @Post(':id/tasks')
  createTask(@Param('id') id: string, @Body() input: CreateCaseTaskDto) {
    return this.casesService.createTask(id, input);
  }

  @Post(':id/internal-notes')
  createInternalNote(
    @Param('id') id: string,
    @Body() input: CreateCaseInternalNoteDto,
  ) {
    return this.casesService.createInternalNote(id, input);
  }

  @Post(':id/timeline-events')
  createTimelineEvent(
    @Param('id') id: string,
    @Body() input: CreateCaseTimelineEventDto,
  ) {
    return this.casesService.createTimelineEvent(id, input);
  }
}
