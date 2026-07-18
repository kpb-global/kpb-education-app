import type { PrismaService } from '../../prisma/prisma.service';
import { AiBudgetService } from './ai-budget.service';

describe('AiBudgetService', () => {
  const previous = {
    budget: process.env.KPB_AI_DIAGNOSTIC_MONTHLY_BUDGET_MICROS_USD,
    price: process.env.KPB_AI_DIAGNOSTIC_PRICE_VERSION,
  };

  afterEach(() => {
    restore('KPB_AI_DIAGNOSTIC_MONTHLY_BUDGET_MICROS_USD', previous.budget);
    restore('KPB_AI_DIAGNOSTIC_PRICE_VERSION', previous.price);
  });

  it('fails closed before any database call when no budget is configured', async () => {
    process.env.KPB_AI_DIAGNOSTIC_MONTHLY_BUDGET_MICROS_USD = '0';
    process.env.KPB_AI_DIAGNOSTIC_PRICE_VERSION = 'groq-2026-07';
    const execute = jest.fn();
    const service = new AiBudgetService({
      isEnabled: true,
      execute,
    } as unknown as PrismaService);

    await expect(
      service.reserve({
        userId: 'student-1',
        diagnosticId: 'diagnostic-1',
        attemptKey: 'diagnostic-1:1',
        attemptNumber: 1,
        provider: 'groq',
        model: 'openai/gpt-oss-20b',
        promptVersion: 'success-lab-v1',
      }),
    ).resolves.toEqual({
      allowed: false,
      reason: 'budget_not_configured',
    });
    expect(execute).not.toHaveBeenCalled();
  });

  it('fails closed before any database call when price version is absent', async () => {
    process.env.KPB_AI_DIAGNOSTIC_MONTHLY_BUDGET_MICROS_USD = '1000000';
    delete process.env.KPB_AI_DIAGNOSTIC_PRICE_VERSION;
    const execute = jest.fn();
    const service = new AiBudgetService({
      isEnabled: true,
      execute,
    } as unknown as PrismaService);

    await expect(
      service.reserve({
        userId: 'student-1',
        diagnosticId: 'diagnostic-1',
        attemptKey: 'diagnostic-1:1',
        attemptNumber: 1,
        provider: 'groq',
        model: 'openai/gpt-oss-20b',
        promptVersion: 'success-lab-v1',
      }),
    ).resolves.toEqual({
      allowed: false,
      reason: 'price_not_configured',
    });
    expect(execute).not.toHaveBeenCalled();
  });
});

function restore(key: string, value: string | undefined) {
  if (value === undefined) delete process.env[key];
  else process.env[key] = value;
}
