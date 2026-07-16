import { Controller, Get, ServiceUnavailableException } from '@nestjs/common';

import { PrismaService } from '../prisma/prisma.service';

@Controller('health')
export class HealthController {
  constructor(private readonly prismaService: PrismaService) {}

  /** Backwards-compatible liveness endpoint: process is able to receive HTTP. */
  @Get()
  check() {
    return { status: 'ok', timestamp: new Date().toISOString() };
  }

  @Get('live')
  live() {
    return { status: 'live', timestamp: new Date().toISOString() };
  }

  /** Readiness includes PostgreSQL, so load balancers do not route to a dead API. */
  @Get('ready')
  async ready() {
    if (!(await this.prismaService.isReady())) {
      throw new ServiceUnavailableException('Database is not ready.');
    }
    return { status: 'ready', timestamp: new Date().toISOString() };
  }
}
