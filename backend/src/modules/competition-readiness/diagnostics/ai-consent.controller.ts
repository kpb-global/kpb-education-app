import {
  Body,
  Controller,
  Delete,
  Get,
  Post,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';

import { StudentAuthGuard } from '../../../common/guards/student-auth.guard';
import { AiConsentService } from './ai-consent.service';
import { GrantAiConsentDto } from './dto/grant-ai-consent.dto';

@Controller('competition-readiness/consents/ai')
@UseGuards(StudentAuthGuard)
export class AiConsentController {
  constructor(private readonly consent: AiConsentService) {}

  @Get('notice')
  getNotice(@Query('language') language: string | undefined, @Req() req: any) {
    return this.consent.getNotice(req.studentUser.id, language);
  }

  @Post()
  grant(@Body() input: GrantAiConsentDto, @Req() req: any) {
    return this.consent.grant(req.studentUser.id, input);
  }

  @Delete()
  revoke(@Req() req: any) {
    return this.consent.revoke(req.studentUser.id);
  }
}
