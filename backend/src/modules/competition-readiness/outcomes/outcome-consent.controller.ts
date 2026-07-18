import { Body, Controller, Get, Param, Post, Query, Req, UseGuards } from '@nestjs/common';

import { StudentAuthGuard } from '../../../common/guards/student-auth.guard';
import { GrantOutcomeConsentDto } from './dto/grant-outcome-consent.dto';
import { OutcomeConsentService } from './outcome-consent.service';

@Controller('competition-readiness')
@UseGuards(StudentAuthGuard)
export class OutcomeConsentController {
  constructor(private readonly consent: OutcomeConsentService) {}

  @Get('workspaces/:id/consents/outcome-evidence/notice')
  getNotice(
    @Param('id') workspaceId: string,
    @Query('language') language: string | undefined,
    @Req() req: any,
  ) {
    return this.consent.getNotice(req.studentUser.id, workspaceId, language);
  }

  @Post('workspaces/:id/consents')
  grant(
    @Param('id') workspaceId: string,
    @Body() input: GrantOutcomeConsentDto,
    @Req() req: any,
  ) {
    return this.consent.grant(req.studentUser.id, workspaceId, input);
  }
}
