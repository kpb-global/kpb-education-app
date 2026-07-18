import {
  Body,
  Controller,
  Get,
  Post,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';

import { StudentAuthGuard } from '../../../common/guards/student-auth.guard';
import { GrantStudyReviewConsentDto } from './dto/grant-study-review-consent.dto';
import { StudyReviewConsentService } from './study-review-consent.service';

@Controller('competition-readiness/consents/study-review')
@UseGuards(StudentAuthGuard)
export class StudyReviewConsentController {
  constructor(private readonly consent: StudyReviewConsentService) {}

  @Get('notice')
  getNotice(@Query('language') language: string | undefined, @Req() req: any) {
    return this.consent.getNotice(req.studentUser.id, language);
  }

  @Post()
  grant(@Body() input: GrantStudyReviewConsentDto, @Req() req: any) {
    return this.consent.grant(req.studentUser.id, input);
  }
}
