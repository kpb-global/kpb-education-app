import { ServiceUnavailableException } from '@nestjs/common';

import { PrismaService } from '../prisma/prisma.service';
import { HealthController } from './health.controller';

describe('HealthController', () => {
  const previousBuildSha = process.env.KPB_BUILD_SHA;

  afterEach(() => {
    if (previousBuildSha === undefined) {
      delete process.env.KPB_BUILD_SHA;
    } else {
      process.env.KPB_BUILD_SHA = previousBuildSha;
    }
  });

  it('reports live without requiring the database', () => {
    const prisma = { isReady: jest.fn() } as unknown as PrismaService;
    expect(new HealthController(prisma).live().status).toBe('live');
  });

  it('reports ready only when PostgreSQL can be queried', async () => {
    const prisma = {
      isReady: jest.fn().mockResolvedValue(true),
    } as unknown as PrismaService;
    await expect(new HealthController(prisma).ready()).resolves.toMatchObject({
      status: 'ready',
    });
  });

  it('returns 503 when PostgreSQL is unavailable', async () => {
    const prisma = {
      isReady: jest.fn().mockResolvedValue(false),
    } as unknown as PrismaService;
    await expect(new HealthController(prisma).ready()).rejects.toBeInstanceOf(
      ServiceUnavailableException,
    );
  });

  // The preflight compares this sha to `git rev-parse --short=12 <ref>`. An
  // empty string would compare equal to nothing and to everything depending on
  // the shell quoting on the other side, and would read as "no answer" rather
  // than "no build stamp" — so an unstamped build must SAY so.
  it('reports an unstamped build as "unknown", never as an empty string', () => {
    delete process.env.KPB_BUILD_SHA;
    const prisma = { isReady: jest.fn() } as unknown as PrismaService;
    expect(new HealthController(prisma).version().sha).toBe('unknown');

    process.env.KPB_BUILD_SHA = '   ';
    expect(new HealthController(prisma).version().sha).toBe('unknown');
  });

  it('shortens the build sha to 12 characters and exposes nothing else', () => {
    process.env.KPB_BUILD_SHA = '0bb0d16098256a35dceb6c6b1a5506180fb99a97';
    const prisma = { isReady: jest.fn() } as unknown as PrismaService;
    const version = new HealthController(prisma).version();

    expect(version.sha).toBe('0bb0d1609825');
    expect(Object.keys(version).sort()).toEqual(['sha', 'startedAt']);
    expect(new Date(version.startedAt).toISOString()).toBe(version.startedAt);
  });
});
