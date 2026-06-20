import { Controller, Get, Query } from '@nestjs/common';

import { YoutubeService } from './youtube.service';

/// Public endpoint — students fetch the KPB "Parcours / Témoignages" videos.
/// No auth: it's published marketing content. The API key stays server-side.
@Controller('content')
export class YoutubeController {
  constructor(private readonly youtubeService: YoutubeService) {}

  @Get('youtube-playlist')
  getPlaylist(@Query('playlistId') playlistId?: string) {
    return this.youtubeService.getPlaylist(playlistId);
  }
}
