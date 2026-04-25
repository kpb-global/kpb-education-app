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

import { StudentAuthGuard } from '../../common/guards/student-auth.guard';
import { ParentLinksService } from './parent-links.service';

type AuthedReq = Request & { studentUser?: { id: string } };

@Controller('parent-links')
@UseGuards(StudentAuthGuard)
export class ParentLinksController {
  constructor(private readonly parentLinksService: ParentLinksService) {}

  /** Parent → create an invite code to share with their child. */
  @Post('invites')
  createInvite(@Req() req: AuthedReq) {
    return this.parentLinksService.invite(req.studentUser!.id);
  }

  /** Student → accept an invite using the 8-character code. */
  @Post('accept')
  accept(@Req() req: AuthedReq, @Body() body: { inviteCode: string }) {
    return this.parentLinksService.accept(
      req.studentUser!.id,
      body.inviteCode,
    );
  }

  @Delete(':id')
  revoke(@Req() req: AuthedReq, @Param('id') id: string) {
    return this.parentLinksService.revoke(req.studentUser!.id, id);
  }

  /** Parent → list their linked children. */
  @Get('children')
  listChildren(@Req() req: AuthedReq) {
    return this.parentLinksService.listChildren(req.studentUser!.id);
  }

  /** Parent → list the cases they can view. */
  @Get('cases')
  listCases(@Req() req: AuthedReq) {
    return this.parentLinksService.listParentVisibleCases(req.studentUser!.id);
  }

  /** Parent → view a single case. */
  @Get('cases/:caseId')
  getCase(@Req() req: AuthedReq, @Param('caseId') caseId: string) {
    return this.parentLinksService.getParentVisibleCase(
      req.studentUser!.id,
      caseId,
    );
  }

  /**
   * Student → toggle whether a specific case is visible to linked parents.
   * Default is false — students opt in explicitly per case.
   */
  @Patch('cases/:caseId/visibility')
  setVisibility(
    @Req() req: AuthedReq,
    @Param('caseId') caseId: string,
    @Body() body: { parentCanView: boolean },
  ) {
    return this.parentLinksService.setParentVisibility(
      req.studentUser!.id,
      caseId,
      body.parentCanView,
    );
  }
}
