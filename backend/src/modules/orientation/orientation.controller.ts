import {
  Body,
  Controller,
  Get,
  Param,
  Post,
  Req,
  UseGuards,
} from '@nestjs/common';

import { StudentAuthGuard } from '../../common/guards/student-auth.guard';
import { OrientationService } from './orientation.service';

@Controller('orientation')
export class OrientationController {
  constructor(private readonly orientationService: OrientationService) {}

  // Public: static question catalogue, no LLM, no DB write.
  @Get('questions')
  getQuestions() {
    return this.orientationService.getQuestions();
  }

  // Authenticated: calls Groq + writes OrientationSession. Without the guard,
  // an attacker could burn Groq quota and spam the DB at the global rate-limit
  // (60 req/min/IP in prod = ~86 400 paid completions/day per IP).
  @Post('sessions')
  @UseGuards(StudentAuthGuard)
  createSession(@Body() body: Record<string, unknown>, @Req() req: any) {
    return this.orientationService.createSession(
      this._withAuthenticatedUserId(body, req),
    );
  }

  @Post('submit')
  @UseGuards(StudentAuthGuard)
  submit(@Body() body: Record<string, unknown>, @Req() req: any) {
    return this.orientationService.createSession(
      this._withAuthenticatedUserId(body, req),
    );
  }

  @Get('results/:id')
  @UseGuards(StudentAuthGuard)
  getResults(@Param('id') id: string) {
    return this.orientationService.getResults(id);
  }

  /// Overrides any client-supplied userId / profile.id with the authenticated
  /// id so the persisted session can never be attributed to another user.
  private _withAuthenticatedUserId(
    body: Record<string, unknown>,
    req: any,
  ): Record<string, unknown> {
    const studentId = req.studentUser.id;
    const profile = (body.profile as Record<string, unknown> | undefined) ?? {};
    return {
      ...body,
      userId: studentId,
      profile: { ...profile, id: studentId },
    };
  }
}
