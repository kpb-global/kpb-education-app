import { Controller, Get, ServiceUnavailableException } from '@nestjs/common';

import { LlmService } from '../ai/llm.service';
import { OneSignalSenderService } from '../notifications/onesignal-sender.service';
import { PrismaService } from '../prisma/prisma.service';

/** Captured at import time, so it is the process start and not the call time. */
const PROCESS_STARTED_AT = new Date().toISOString();

@Controller('health')
export class HealthController {
  constructor(
    private readonly prismaService: PrismaService,
    private readonly llmService: LlmService,
    private readonly pushSender: OneSignalSenderService,
  ) {}

  /** Backwards-compatible liveness endpoint: process is able to receive HTTP. */
  @Get()
  check() {
    return {
      status: 'ok',
      timestamp: new Date().toISOString(),
      // Boolean only — never the provider key, never the model name.
      ai: { configured: this.llmService.isConfigured },
      /**
       * Le push est-il seulement CAPABLE de partir ?
       *
       * `OneSignalSenderService` se dégrade en silence : sans
       * `ONESIGNAL_APP_ID` / `ONESIGNAL_REST_API_KEY`, chaque envoi devient un
       * no-op journalisé, le fil d'actualité s'écrit quand même, et le
       * dispatcher rend `push_unconfigured`. Personne ne s'en apercevait :
       * cette route annonçait l'état de l'IA et RIEN sur le push, alors que
       * les deux se désactivent de la même façon — par une variable absente.
       *
       * C'est la forme d'échec qui a envoyé la build 50 chez les testeurs sans
       * PostHog : une capacité éteinte sans le moindre signal. Un booléen ici
       * coûte une ligne et rend la panne visible de l'extérieur.
       *
       * Booléen SEUL, comme pour l'IA : la clé REST est un secret, et même sa
       * longueur n'a rien à faire sur une route non authentifiée.
       */
      push: { configured: this.pushSender.isConfigured },
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
