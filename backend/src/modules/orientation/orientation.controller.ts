import { Body, Controller, Get, Param, Post } from '@nestjs/common';

import { OrientationService } from './orientation.service';

@Controller('orientation')
export class OrientationController {
  constructor(private readonly orientationService: OrientationService) {}

  @Post('sessions')
  createSession(@Body() body: Record<string, unknown>) {
    return this.orientationService.createSession(body);
  }

  @Get('results/:id')
  getResults(@Param('id') id: string) {
    return this.orientationService.getResults(id);
  }
}
