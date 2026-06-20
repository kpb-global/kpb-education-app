import { Body, Controller, Post, UseGuards } from '@nestjs/common';
import { StudentAuthGuard } from '../../common/guards/student-auth.guard';
import {
  CvSummaryDto,
  InterviewFeedbackDto,
  InterviewQuestionsDto,
  LetterPersonalizeDto,
  ToolsService,
} from './tools.service';

@Controller('tools')
@UseGuards(StudentAuthGuard)
export class ToolsController {
  constructor(private readonly toolsService: ToolsService) {}

  @Post('cv-summary')
  generateCvSummary(@Body() dto: CvSummaryDto) {
    return this.toolsService.generateCvSummary(dto);
  }

  @Post('personalize-letter')
  personalizeLetters(@Body() dto: LetterPersonalizeDto) {
    return this.toolsService.personalizeLetters(dto);
  }

  @Post('interview/questions')
  getInterviewQuestions(@Body() dto: InterviewQuestionsDto) {
    return this.toolsService.getInterviewQuestions(dto);
  }

  @Post('interview/feedback')
  evaluateInterviewAnswer(@Body() dto: InterviewFeedbackDto) {
    return this.toolsService.evaluateInterviewAnswer(dto);
  }
}
