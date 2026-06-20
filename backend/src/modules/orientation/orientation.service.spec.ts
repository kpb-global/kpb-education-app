import { Test, TestingModule } from '@nestjs/testing';
import { NotFoundException } from '@nestjs/common';

import { LlmService } from '../ai/llm.service';
import { PrismaService } from '../prisma/prisma.service';
import { OrientationService } from './orientation.service';

describe('OrientationService', () => {
  let service: OrientationService;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        OrientationService,
        {
          provide: LlmService,
          useValue: {
            completeJson: jest.fn(async ({ fallback }) => ({
              data: fallback,
              model: 'test-fallback',
            })),
          },
        },
        {
          provide: PrismaService,
          useValue: {
            tryExecute: jest.fn(async () => null),
          },
        },
      ],
    }).compile();

    service = module.get<OrientationService>(OrientationService);
  });

  it('returns ranked recommendations for M4 answer ids', async () => {
    const session = await service.createSession({
      answers: {
        interests: ['tech'],
        ai_concern: ['ai_yes'],
      },
      profile: { fullName: 'Aminata Diallo' },
    });

    expect(session.recommendations.length).toBeGreaterThan(0);
    expect(session.recommendations[0].fieldId).toMatch(/^d\d{2}$/);
    expect(session.recommendations[0].score).toBeGreaterThanOrEqual(55);
    expect(session.recommendations[0].iaResilience).toBeDefined();
  });

  it('throws NotFoundException for unknown session ID', async () => {
    await expect(service.getResults('invalid-id')).rejects.toThrow(NotFoundException);
  });
});
