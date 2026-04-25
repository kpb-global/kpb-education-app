import {
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Post,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';
import { Request } from 'express';

import { Roles } from '../../common/decorators/roles.decorator';
import { InternalRole } from '../../common/enums/internal-role.enum';
import { AdminAuthGuard } from '../../common/guards/admin-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { StudentAuthGuard } from '../../common/guards/student-auth.guard';
import { AlumniService } from './alumni.service';

type StudentReq = Request & { studentUser?: { id: string } };
type AdminReq = Request & { adminUser?: { id?: string; sub?: string } };

/** Public mentor directory — no auth. Renders the community badge strip. */
@Controller('alumni')
export class AlumniController {
  constructor(private readonly alumniService: AlumniService) {}

  @Get()
  list(
    @Query('country') country?: string,
    @Query('university') university?: string,
    @Query('limit') limit?: string,
  ) {
    return this.alumniService.listPublic({
      countryCode: country,
      university,
      limit: limit ? Number(limit) : undefined,
    });
  }
}

/** Authenticated student → apply + manage badge. */
@Controller('me/alumni')
@UseGuards(StudentAuthGuard)
export class MyAlumniController {
  constructor(private readonly alumniService: AlumniService) {}

  @Get()
  mine(@Req() req: StudentReq) {
    return this.alumniService.getMyStatus(req.studentUser!.id);
  }

  @Post('apply')
  apply(
    @Req() req: StudentReq,
    @Body()
    body: {
      alumniUniversity: string;
      alumniProgramme: string;
      alumniGraduationYear: number;
      alumniCountryCode?: string;
      alumniBioFr?: string;
      alumniBioEn?: string;
      alumniProofUrl: string;
    },
  ) {
    return this.alumniService.apply(req.studentUser!.id, body);
  }

  @Patch('badge-visible')
  setVisible(@Req() req: StudentReq, @Body() body: { visible: boolean }) {
    return this.alumniService.setBadgeVisible(req.studentUser!.id, body.visible);
  }
}

/** Admin — review and decide alumni applications. */
@Controller('admin/alumni')
@UseGuards(AdminAuthGuard, RolesGuard)
@Roles(InternalRole.Admin, InternalRole.SuperAdmin, InternalRole.Moderator)
export class AdminAlumniController {
  constructor(private readonly alumniService: AlumniService) {}

  @Get()
  list(
    @Query('status') status?: 'none' | 'pending' | 'approved' | 'rejected',
  ) {
    return this.alumniService.listAdmin(status);
  }

  @Patch(':userId/decision')
  decide(
    @Req() req: AdminReq,
    @Param('userId') userId: string,
    @Body() body: { decision: 'approved' | 'rejected' },
  ) {
    const adminId = req.adminUser?.id ?? req.adminUser?.sub ?? 'unknown-admin';
    return this.alumniService.decide(userId, adminId, body.decision);
  }
}
