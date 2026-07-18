import type { PrismaService } from '../../prisma/prisma.service';
import type { AdminReviewAccessService } from './admin-review-access.service';
import { AdminAiUsageService } from './admin-ai-usage.service';

describe('AdminAiUsageService', () => {
  const execute = jest.fn();
  const prisma = { isEnabled: true, execute } as unknown as PrismaService;
  const assertCapability = jest.fn();
  const access = { assertCapability } as unknown as AdminReviewAccessService;
  const service = new AdminAiUsageService(prisma, access);
  const actor = {
    id: 'admin-1',
    fullName: 'Admin KPB',
    email: 'admin@kpb.test',
    role: 'admin',
  };

  beforeEach(() => jest.clearAllMocks());

  it('returns bounded operational usage without actor or provider identifiers', async () => {
    const now = new Date('2026-07-17T10:00:00.000Z');
    const findMany = jest.fn().mockResolvedValue([
      {
        id: 'attempt-1',
        attemptNumber: 1,
        provider: 'groq',
        model: 'model-1',
        promptVersion: 'prompt-v1',
        inputTokens: 100,
        cachedInputTokens: 20,
        outputTokens: 30,
        estimatedCostMicrosUsd: 1234n,
        outcome: 'success',
        errorCode: null,
        startedAt: now,
        completedAt: now,
        createdAt: now,
        actorKey: 'must-never-leak',
        providerRequestId: 'must-never-leak',
      },
    ]);
    execute.mockImplementation(async (operation: (db: unknown) => unknown) =>
      operation({
        aiUsageAttempt: {
          findMany,
          groupBy: jest.fn().mockResolvedValue([
            { outcome: 'success', _count: { _all: 1 } },
          ]),
          aggregate: jest.fn().mockResolvedValue({
            _count: { _all: 1 },
            _sum: { estimatedCostMicrosUsd: 1234n },
          }),
        },
        aiBudgetPeriod: {
          findFirst: jest.fn().mockResolvedValue({
            budgetMicrosUsd: 100000n,
            reservedMicrosUsd: 5000n,
            spentMicrosUsd: 1234n,
          }),
        },
      }),
    );

    const result = await service.getUsage(actor, { limit: 20 });

    expect(assertCapability).toHaveBeenCalledWith(
      actor,
      'view_ai_operations',
    );
    expect(result).toMatchObject({
      items: [
        expect.objectContaining({
          diagnosticId: null,
          outcome: 'succeeded',
          estimatedCostMicrosUsd: '1234',
        }),
      ],
      summary: {
        requests: 1,
        validSuccessRate: 1,
        fallbackRate: 0,
        errorRate: 0,
        estimatedCostMicrosUsd: '1234',
        budgetMicrosUsd: '100000',
        reservedMicrosUsd: '5000',
        spentMicrosUsd: '1234',
      },
    });
    expect(JSON.stringify(result)).not.toContain('must-never-leak');
    expect(findMany.mock.calls[0][0].select).not.toHaveProperty('actorKey');
    expect(findMany.mock.calls[0][0].select).not.toHaveProperty(
      'providerRequestId',
    );
  });

  it('uses zero rates and decimal strings when no settled attempts exist', async () => {
    execute.mockImplementation(async (operation: (db: unknown) => unknown) =>
      operation({
        aiUsageAttempt: {
          findMany: jest.fn().mockResolvedValue([]),
          groupBy: jest.fn().mockResolvedValue([]),
          aggregate: jest.fn().mockResolvedValue({
            _count: { _all: 0 },
            _sum: { estimatedCostMicrosUsd: null },
          }),
        },
        aiBudgetPeriod: { findFirst: jest.fn().mockResolvedValue(null) },
      }),
    );

    await expect(service.getUsage(actor, { limit: 20 })).resolves.toMatchObject({
      items: [],
      nextCursor: null,
      summary: {
        requests: 0,
        validSuccessRate: 0,
        fallbackRate: 0,
        errorRate: 0,
        estimatedCostMicrosUsd: '0',
        budgetMicrosUsd: '0',
        reservedMicrosUsd: '0',
        spentMicrosUsd: '0',
      },
    });
  });
});
