import { ServiceUnavailableException } from '@nestjs/common';

import { LlmService } from '../ai/llm.service';
import { OneSignalSenderService } from '../notifications/onesignal-sender.service';
import { PrismaService } from '../prisma/prisma.service';
import { HealthController } from './health.controller';

function makeController(
  prisma: PrismaService,
  llm: Pick<LlmService, 'isConfigured'> = { isConfigured: false },
  push: Pick<OneSignalSenderService, 'isConfigured'> = { isConfigured: false },
) {
  return new HealthController(
    prisma,
    llm as LlmService,
    push as OneSignalSenderService,
  );
}

describe('HealthController', () => {
  const previousBuildSha = process.env.KPB_BUILD_SHA;
  const previousGroqKey = process.env.GROQ_API_KEY;

  afterEach(() => {
    if (previousBuildSha === undefined) {
      delete process.env.KPB_BUILD_SHA;
    } else {
      process.env.KPB_BUILD_SHA = previousBuildSha;
    }
    if (previousGroqKey === undefined) {
      delete process.env.GROQ_API_KEY;
    } else {
      process.env.GROQ_API_KEY = previousGroqKey;
    }
  });

  it('reports live without requiring the database', () => {
    const prisma = { isReady: jest.fn() } as unknown as PrismaService;
    expect(makeController(prisma).live().status).toBe('live');
  });

  it('reports ready only when PostgreSQL can be queried', async () => {
    const prisma = {
      isReady: jest.fn().mockResolvedValue(true),
    } as unknown as PrismaService;
    await expect(makeController(prisma).ready()).resolves.toMatchObject({
      status: 'ready',
    });
  });

  it('returns 503 when PostgreSQL is unavailable', async () => {
    const prisma = {
      isReady: jest.fn().mockResolvedValue(false),
    } as unknown as PrismaService;
    await expect(makeController(prisma).ready()).rejects.toBeInstanceOf(
      ServiceUnavailableException,
    );
  });

  it('exposes ai.configured as a boolean and never the provider key', () => {
    delete process.env.GROQ_API_KEY;
    const prisma = { isReady: jest.fn() } as unknown as PrismaService;
    const body = makeController(prisma, { isConfigured: true }).check();
    expect(body.ai).toEqual({ configured: true });
    expect(JSON.stringify(body)).not.toMatch(/gsk_|GROQ_API_KEY/i);

    const off = makeController(prisma, { isConfigured: false }).check();
    expect(off.ai).toEqual({ configured: false });
  });

  // Le push se désactive EXACTEMENT comme l'IA — par une variable absente — et
  // rien ne le disait. `OneSignalSenderService` se dégrade en no-op journalisé :
  // le fil d'actualité s'écrit, le push ne part pas, et personne ne s'en aperçoit.
  // C'est la forme d'échec qui a envoyé la build 50 sans PostHog.
  it('expose push.configured, et jamais la clé REST', () => {
    const prisma = { isReady: jest.fn() } as unknown as PrismaService;

    const on = makeController(
      prisma,
      { isConfigured: false },
      { isConfigured: true },
    ).check();
    expect(on.push).toEqual({ configured: true });

    const off = makeController(prisma).check();
    expect(off.push).toEqual({ configured: false });

    // Booléen SEUL : ni la clé, ni sa longueur, ni l'App ID sur une route
    // non authentifiée.
    process.env.ONESIGNAL_REST_API_KEY = 'os_v2_supersecret_value';
    const body = makeController(
      prisma,
      { isConfigured: false },
      { isConfigured: true },
    ).check();
    expect(JSON.stringify(body)).not.toMatch(
      /os_v2_|ONESIGNAL_REST_API_KEY|supersecret/i,
    );
    delete process.env.ONESIGNAL_REST_API_KEY;
  });

  // L'IA et le push sont deux capacités indépendantes : les lire d'un seul
  // booléen ferait passer une panne de l'une pour la santé de l'autre.
  it('rapporte l\'IA et le push indépendamment', () => {
    const prisma = { isReady: jest.fn() } as unknown as PrismaService;
    const body = makeController(
      prisma,
      { isConfigured: true },
      { isConfigured: false },
    ).check();
    expect(body.ai).toEqual({ configured: true });
    expect(body.push).toEqual({ configured: false });
  });

  // The preflight compares this sha to `git rev-parse --short=12 <ref>`. An
  // empty string would compare equal to nothing and to everything depending on
  // the shell quoting on the other side, and would read as "no answer" rather
  // than "no build stamp" — so an unstamped build must SAY so.
  it('reports an unstamped build as "unknown", never as an empty string', () => {
    delete process.env.KPB_BUILD_SHA;
    const prisma = { isReady: jest.fn() } as unknown as PrismaService;
    expect(makeController(prisma).version().sha).toBe('unknown');

    process.env.KPB_BUILD_SHA = '   ';
    expect(makeController(prisma).version().sha).toBe('unknown');
  });

  it('shortens the build sha to 12 characters and exposes nothing else', () => {
    process.env.KPB_BUILD_SHA = '0bb0d16098256a35dceb6c6b1a5506180fb99a97';
    const prisma = { isReady: jest.fn() } as unknown as PrismaService;
    const version = makeController(prisma).version();

    expect(version.sha).toBe('0bb0d1609825');
    expect(Object.keys(version).sort()).toEqual(['sha', 'startedAt']);
    expect(new Date(version.startedAt).toISOString()).toBe(version.startedAt);
  });
});
