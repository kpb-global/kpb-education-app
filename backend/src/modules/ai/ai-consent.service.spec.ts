import { AiConsentService } from './ai-consent.service';
import { PrismaService } from '../prisma/prisma.service';

describe('AiConsentService', () => {
  function makeService(opts: {
    tryExecuteResult?:
      | {
          aiConsentedAt: Date | null;
          birthDate: Date | null;
          guardianConsentedAt: Date | null;
        }
      | null
      | 'run-null';
  } = {}) {
    const prisma = {
      tryExecute: jest.fn(async () => {
        if (opts.tryExecuteResult === 'run-null' || opts.tryExecuteResult === undefined) {
          return null;
        }
        return opts.tryExecuteResult;
      }),
    } as unknown as PrismaService;
    return { service: new AiConsentService(prisma), prisma };
  }

  function yearsAgo(years: number): Date {
    const date = new Date();
    date.setFullYear(date.getFullYear() - years);
    return date;
  }

  it('fail-open: tryExecute → null does not block', async () => {
    const { service } = makeService({ tryExecuteResult: null });
    await expect(service.consentBlockCode('user-a')).resolves.toBeNull();
  });

  it('blocks when aiConsentedAt is absent', async () => {
    const { service } = makeService({
      tryExecuteResult: {
        aiConsentedAt: null,
        birthDate: null,
        guardianConsentedAt: null,
      },
    });
    await expect(service.consentBlockCode('user-a')).resolves.toBe(
      'ai_consent_required',
    );
  });

  it('blocks a minor without guardian consent', async () => {
    const { service } = makeService({
      tryExecuteResult: {
        aiConsentedAt: new Date(),
        birthDate: yearsAgo(15),
        guardianConsentedAt: null,
      },
    });
    await expect(service.consentBlockCode('user-a')).resolves.toBe(
      'guardian_consent_required',
    );
  });

  it('allows an adult with consent', async () => {
    const { service } = makeService({
      tryExecuteResult: {
        aiConsentedAt: new Date(),
        birthDate: yearsAgo(20),
        guardianConsentedAt: null,
      },
    });
    await expect(service.consentBlockCode('user-a')).resolves.toBeNull();
  });

  it('does not treat an unknown birthDate as minor', async () => {
    const { service } = makeService({
      tryExecuteResult: {
        aiConsentedAt: new Date(),
        birthDate: null,
        guardianConsentedAt: null,
      },
    });
    await expect(service.consentBlockCode('user-a')).resolves.toBeNull();
  });
});
