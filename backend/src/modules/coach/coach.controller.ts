import {
  Body,
  Controller,
  Get,
  Param,
  Post,
  Query,
  Sse,
  MessageEvent,
} from '@nestjs/common';
import { Observable } from 'rxjs';

import { CoachService } from './coach.service';

@Controller('coach')
export class CoachController {
  constructor(private readonly coachService: CoachService) {}

  @Get('quota')
  getQuota(@Query('userId') userId = 'demo-user') {
    return this.coachService.getQuota(userId);
  }

  @Get('suggestions')
  getSuggestions(@Query('userId') userId = 'demo-user') {
    return this.coachService.getSuggestions({ fullName: 'Étudiant' });
  }

  @Post('conversations')
  createConversation(@Body() body: Record<string, unknown>) {
    const userId = String(body.userId ?? 'demo-user');
    const profile = (body.profile as Record<string, unknown> | undefined) ?? {};
    return this.coachService.createConversation(userId, profile);
  }

  @Get('conversations/:id/messages')
  getMessages(@Param('id') id: string) {
    return this.coachService.getMessages(id);
  }

  @Sse('conversations/:id/messages/stream')
  streamMessage(
    @Param('id') id: string,
    @Query('userId') userId = 'demo-user',
    @Query('message') message = '',
    @Query('fullName') fullName = 'Étudiant',
    @Query('currentLevel') currentLevel = '',
    @Query('targetCountryIds') targetCountryIds = '',
  ): Observable<MessageEvent> {
    return this.coachService.streamReply({
      conversationId: id,
      userId,
      message,
      profile: {
        fullName,
        currentLevel,
        targetCountryIds: targetCountryIds
          ? targetCountryIds.split(',').filter(Boolean)
          : [],
      },
    });
  }

  @Post('conversations/:id/messages')
  postMessage(
    @Param('id') id: string,
    @Body() body: Record<string, unknown>,
  ): Observable<MessageEvent> {
    const userId = String(body.userId ?? 'demo-user');
    const profile = (body.profile as Record<string, unknown> | undefined) ?? {};
    const message = String(body.message ?? '');
    return this.coachService.streamReply({
      conversationId: id,
      userId,
      message,
      profile,
    });
  }
}
