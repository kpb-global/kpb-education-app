import { Controller, Get, ServiceUnavailableException } from '@nestjs/common';

import { LlmService } from '../ai/llm.service';
import { PrismaService } from '../prisma/prisma.service';

/** Captured at import time, so it is the process start and not the call time. */
const PROCESS_STARTED_AT = new Date().toISOString();

@Controller('health')
export class HealthController {
  constructor(
    private readonly prismaService: PrismaService,
    private readonly llmService: LlmService,
  ) {}

  /** Backwards-compatible liveness endpoint: process is able to receive HTTP. */
  @Get()
  check() {
    return {
      status: 'ok',
      timestamp: new Date().toISOString(),
      // Boolean only — never the provider key, never the model name.
      ai: { configured: this.llmService.isConfigured },
    };
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

  /**
   * The short SHA of the code actually serving, so "is prod on this commit?"
   * has an answer that is not a presumption. `unknown` rather than '' when the
   * build is unstamped: an empty string compares equal to too many things, and
   * reads as "no answer" instead of "no build stamp".
   *
   * Deliberately nothing else — no dependency versions, no paths. The short SHA
   * is the only information the preflight needs, and the only one worth
   * revealing on an unauthenticated route.
   */
  @Get('version')
  version() {
    return {
      sha: process.env.KPB_BUILD_SHA?.trim().slice(0, 12) || 'unknown',
      startedAt: PROCESS_STARTED_AT,
    };
  }
}
