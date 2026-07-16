import { ServiceUnavailableException } from '@nestjs/common';

import { PrismaService } from '../prisma/prisma.service';
import { HealthController } from './health.controller';

describe('HealthController', () => {
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
});
