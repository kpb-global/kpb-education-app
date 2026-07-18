import { ConsentPurpose } from '@prisma/client';

import { PrismaService } from '../../prisma/prisma.service';
import { FeatureAccessService } from './feature-access.service';

const ENV_KEYS = [
  'KPB_COMPETITION_READINESS_ENABLED',
  'KPB_SUCCESS_LAB_ENABLED',
  'KPB_AI_DIAGNOSTIC_ENABLED',
  'KPB_AI_DIAGNOSTIC_KILL_SWITCH',
  'KPB_AI_DIAGNOSTIC_MIN_AGE',
  'KPB_OUTCOME_EVIDENCE_ENABLED',
  'KPB_IMPACT_PUBLIC_STATS_ENABLED',
  'KPB_SUCCESS_LAB_PILOT_COUNTRIES',
  'KPB_SUCCESS_LAB_ROLLOUT_PERCENT',
  'KPB_FEATURE_ROLLOUT_SECRET',
] as const;

describe('FeatureAccessService', () => {
  const previousEnv = Object.fromEntries(
    ENV_KEYS.map((key) => [key, process.env[key]]),
  );

  beforeEach(() => {
    for (const key of ENV_KEYS) delete process.env[key];
  });

  afterAll(() => {
    for (const key of ENV_KEYS) {
      const value = previousEnv[key];
      if (value === undefined) delete process.env[key];
      else process.env[key] = value;
    }
  });

  it('keeps every feature disabled by default without reading the database', async () => {
    const execute = jest.fn();
    const service = new FeatureAccessService({
      isEnabled: true,
      execute,
    } as unknown as PrismaService);

    await expect(
      service.evaluate({
        feature: 'competition_readiness',
        userId: 'user-1',
      }),
    ).resolves.toEqual({
      allowed: false,
      feature: 'competition_readiness',
      reason: 'feature_disabled',
    });
    expect(execute).not.toHaveBeenCalled();
  });

  it('fails closed when Prisma is unavailable', async () => {
    enableAiDiagnostic();
    const execute = jest.fn();
    const service = new FeatureAccessService({
      isEnabled: false,
      execute,
    } as unknown as PrismaService);

    await expect(
      service.evaluate({
        feature: 'ai_diagnostic',
        userId: 'user-1',
        countryCode: 'NE',
      }),
    ).resolves.toMatchObject({
      allowed: false,
      reason: 'database_unavailable',
    });
    expect(execute).not.toHaveBeenCalled();
  });

  it('allows an adult with active AI consent in a fully opened pilot', async () => {
    enableAiDiagnostic();
    const execute = jest.fn().mockResolvedValue({
      accountType: 'student',
      birthDate: new Date('1990-01-01T00:00:00.000Z'),
      countryOfResidence: 'Niger',
      consentReceipts: [
        {
          purpose: ConsentPurpose.ai_third_party,
          guardianAuthorization: null,
        },
      ],
    });
    const service = new FeatureAccessService({
      isEnabled: true,
      execute,
    } as unknown as PrismaService);

    await expect(
      service.evaluate({
        feature: 'ai_diagnostic',
        userId: 'user-1',
        countryCode: 'ne',
        now: new Date('2026-07-16T12:00:00.000Z'),
      }),
    ).resolves.toEqual({ allowed: true, feature: 'ai_diagnostic' });
  });

  it('denies AI when its versioned consent receipt is missing', async () => {
    enableAiDiagnostic();
    const service = new FeatureAccessService({
      isEnabled: true,
      execute: jest.fn().mockResolvedValue({
        accountType: 'student',
        birthDate: new Date('1990-01-01T00:00:00.000Z'),
        countryOfResidence: 'NE',
        consentReceipts: [],
      }),
    } as unknown as PrismaService);

    await expect(
      service.evaluate({
        feature: 'ai_diagnostic',
        userId: 'user-1',
        countryCode: 'NE',
      }),
    ).resolves.toMatchObject({ allowed: false, reason: 'consent_required' });
  });

  it('denies a minor whose linked guardian authorization is not verified', async () => {
    enableAiDiagnostic();
    const service = new FeatureAccessService({
      isEnabled: true,
      execute: jest.fn().mockResolvedValue({
        accountType: 'student',
        birthDate: new Date('2012-01-01T00:00:00.000Z'),
        countryOfResidence: 'NE',
        consentReceipts: [
          {
            purpose: ConsentPurpose.ai_third_party,
            guardianAuthorization: {
              status: 'pending',
              verifiedAt: null,
              expiresAt: null,
              revokedAt: null,
            },
          },
        ],
      }),
    } as unknown as PrismaService);

    await expect(
      service.evaluate({
        feature: 'ai_diagnostic',
        userId: 'minor-1',
        countryCode: 'NE',
        now: new Date('2026-07-16T12:00:00.000Z'),
      }),
    ).resolves.toMatchObject({
      allowed: false,
      reason: 'guardian_authorization_required',
    });
  });

  it('denies AI below the configured minimum age even with guardian authorization', async () => {
    enableAiDiagnostic();
    process.env.KPB_AI_DIAGNOSTIC_MIN_AGE = '13';
    const service = new FeatureAccessService({
      isEnabled: true,
      execute: jest.fn().mockResolvedValue({
        accountType: 'student',
        birthDate: new Date('2015-08-01T00:00:00.000Z'),
        countryOfResidence: 'NE',
        consentReceipts: [
          {
            purpose: ConsentPurpose.ai_third_party,
            guardianAuthorization: {
              status: 'verified',
              verifiedAt: new Date('2026-01-01T00:00:00.000Z'),
              expiresAt: null,
              revokedAt: null,
            },
          },
        ],
      }),
    } as unknown as PrismaService);

    await expect(
      service.evaluate({
        feature: 'ai_diagnostic',
        userId: 'child-1',
        countryCode: 'NE',
        now: new Date('2026-07-17T12:00:00.000Z'),
      }),
    ).resolves.toMatchObject({
      allowed: false,
      reason: 'age_below_minimum',
    });
  });

  it('fails closed when a percentage rollout has no HMAC secret', async () => {
    enableAiDiagnostic();
    process.env.KPB_SUCCESS_LAB_ROLLOUT_PERCENT = '50';
    delete process.env.KPB_FEATURE_ROLLOUT_SECRET;
    const service = new FeatureAccessService({
      isEnabled: true,
      execute: jest.fn().mockResolvedValue({
        accountType: 'student',
        birthDate: new Date('1990-01-01T00:00:00.000Z'),
        countryOfResidence: 'NE',
        consentReceipts: [
          {
            purpose: ConsentPurpose.ai_third_party,
            guardianAuthorization: null,
          },
        ],
      }),
    } as unknown as PrismaService);

    await expect(
      service.evaluate({
        feature: 'ai_diagnostic',
        userId: 'user-1',
        countryCode: 'NE',
      }),
    ).resolves.toMatchObject({
      allowed: false,
      reason: 'rollout_not_configured',
    });
  });

  it.each(['success_lab', 'ai_diagnostic', 'outcome_evidence'] as const)(
    'denies %s to a non-student account with a stable reason',
    async (feature) => {
      enableAiDiagnostic();
      process.env.KPB_OUTCOME_EVIDENCE_ENABLED = 'true';
      const execute = jest.fn().mockResolvedValue({
        accountType: 'parent',
        birthDate: new Date('1990-01-01T00:00:00.000Z'),
        countryOfResidence: 'NE',
        consentReceipts: [],
      });
      const service = new FeatureAccessService({
        isEnabled: true,
        execute,
      } as unknown as PrismaService);

      await expect(
        service.evaluate({ feature, userId: 'parent-1', countryCode: 'NE' }),
      ).resolves.toEqual({
        allowed: false,
        feature,
        reason: 'account_type_not_allowed',
      });
    },
  );

  it('keeps outcome evidence disabled when the Success Lab master gate is off', async () => {
    process.env.KPB_COMPETITION_READINESS_ENABLED = 'true';
    process.env.KPB_SUCCESS_LAB_ENABLED = 'false';
    process.env.KPB_OUTCOME_EVIDENCE_ENABLED = 'true';
    const execute = jest.fn();
    const service = new FeatureAccessService({
      isEnabled: true,
      execute,
    } as unknown as PrismaService);

    await expect(
      service.evaluate({ feature: 'outcome_evidence', userId: 'student-1' }),
    ).resolves.toMatchObject({
      allowed: false,
      reason: 'feature_disabled',
    });
    expect(execute).not.toHaveBeenCalled();
  });

  it.each([
    ['Niger', 'NE'],
    ['Senegal', 'SN'],
    ['Sénégal', 'SN'],
    ["Cote d'Ivoire", 'CI'],
    ["Côte d'Ivoire", 'CI'],
  ])(
    'maps the legacy profile country %s to pilot code %s',
    async (countryOfResidence) => {
      enableAiDiagnostic();
      const service = new FeatureAccessService({
        isEnabled: true,
        execute: jest.fn().mockResolvedValue({
          accountType: 'student',
          birthDate: new Date('1990-01-01T00:00:00.000Z'),
          countryOfResidence,
          consentReceipts: [],
        }),
      } as unknown as PrismaService);

      await expect(
        service.evaluate({ feature: 'success_lab', userId: 'student-1' }),
      ).resolves.toEqual({ allowed: true, feature: 'success_lab' });
    },
  );
});

function enableAiDiagnostic(): void {
  process.env.KPB_COMPETITION_READINESS_ENABLED = 'true';
  process.env.KPB_SUCCESS_LAB_ENABLED = 'true';
  process.env.KPB_AI_DIAGNOSTIC_ENABLED = 'true';
  process.env.KPB_AI_DIAGNOSTIC_KILL_SWITCH = 'false';
  process.env.KPB_SUCCESS_LAB_PILOT_COUNTRIES = 'NE,SN,CI';
  process.env.KPB_SUCCESS_LAB_ROLLOUT_PERCENT = '100';
}
