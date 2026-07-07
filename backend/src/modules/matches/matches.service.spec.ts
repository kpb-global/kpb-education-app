import { NotFoundException } from '@nestjs/common';

import { MatchesService } from './matches.service';
import { PrismaService } from '../prisma/prisma.service';
import {
  ScoringProfile,
  ScoringProgram,
  canonicalLevel,
  gradeRangeMidpoint,
  scoreProgram,
} from './matching';

// Fixed clock so timing scores are deterministic in every factor test.
const NOW = new Date('2026-07-07T00:00:00.000Z');

function monthsFromNow(months: number): Date {
  return new Date(NOW.getTime() + months * 30 * 24 * 60 * 60 * 1000);
}

// A profile/program pair where every factor has data and scores at its best:
// grade 15+ vs min 12, matching field, advanced language, budget ratio ≥ 1.5,
// deadline > 6 months out, level aligned.
const fullProfile: ScoringProfile = {
  gradeRange: '15+/20',
  languageLevel: 'Advanced',
  targetLevel: 'Bachelor',
  monthlyBudgetEur: 1800,
  fieldIds: ['computer_science'],
  targetCountryIds: ['can'],
};

const fullProgram: ScoringProgram = {
  id: 'prog-1',
  institutionId: 'inst-1',
  countryId: 'can',
  fieldId: 'computer_science',
  nameFr: 'Bachelor en informatique',
  nameEn: 'Bachelor in Computer Science',
  levelFr: 'Licence',
  levelEn: 'Bachelor',
  minGpaRequired: 12,
  tuitionMinEur: 12000,
  applicationDeadline: monthsFromNow(8),
  teachingLanguages: ['fr', 'en'],
};

function factor(profile: ScoringProfile, program: ScoringProgram, name: string) {
  const result = scoreProgram(profile, program, { now: NOW });
  const found = result.factors.find((f) => f.name === name);
  if (!found) throw new Error(`missing factor ${name}`);
  return found;
}

describe('gradeRangeMidpoint', () => {
  it.each([
    ['10 - 12/20', 11],
    ['12 - 14/20', 13],
    ['15+/20', 16],
    [null, null],
    ['n/a', null],
  ])('%s → %s', (input, expected) => {
    expect(gradeRangeMidpoint(input)).toBe(expected);
  });
});

describe('canonicalLevel', () => {
  it.each([
    ['Bachelor', 'bachelor'],
    ['Licence', 'bachelor'],
    ['Master in Management', 'master'],
    ['Doctorat', 'phd'],
    ['High school', 'highschool'],
    ['Certificat', null],
    [null, null],
  ])('%s → %s', (input, expected) => {
    expect(canonicalLevel(input)).toBe(expected);
  });
});

describe('scoreProgram — factors', () => {
  it('academic: kit formula against minGpaRequired', () => {
    // grade 16 vs min 12 → (16-12+2)/4 = 1.5 → clamped 1.0
    expect(factor(fullProfile, fullProgram, 'academic').score).toBe(1);
    // grade 11 vs min 12 → (11-12+2)/4 = 0.25
    expect(
      factor({ ...fullProfile, gradeRange: '10 - 12/20' }, fullProgram, 'academic')
        .score,
    ).toBe(0.25);
  });

  it('academic: absolute scale when program publishes no requirement — estimate', () => {
    const f = factor(
      { ...fullProfile, gradeRange: '12 - 14/20' },
      { ...fullProgram, minGpaRequired: null },
      'academic',
    );
    expect(f.score).toBe(13 / 16);
    expect(f.isEstimate).toBe(true);
  });

  it('academic: missing gradeRange → neutral estimate', () => {
    const f = factor({ ...fullProfile, gradeRange: null }, fullProgram, 'academic');
    expect(f).toMatchObject({ score: 0.5, isEstimate: true });
  });

  it('field: binary match / mismatch / missing', () => {
    expect(factor(fullProfile, fullProgram, 'field').score).toBe(1);
    expect(
      factor({ ...fullProfile, fieldIds: ['business'] }, fullProgram, 'field').score,
    ).toBe(0.2);
    expect(
      factor({ ...fullProfile, fieldIds: [] }, fullProgram, 'field'),
    ).toMatchObject({ score: 0.5, isEstimate: true });
  });

  it('language: level ladder and missing sides', () => {
    expect(factor(fullProfile, fullProgram, 'language').score).toBe(0.8);
    expect(
      factor({ ...fullProfile, languageLevel: 'Beginner' }, fullProgram, 'language')
        .score,
    ).toBe(0.25);
    expect(
      factor({ ...fullProfile, languageLevel: null }, fullProgram, 'language'),
    ).toMatchObject({ score: 0.5, isEstimate: true });
    expect(
      factor(fullProfile, { ...fullProgram, teachingLanguages: [] }, 'language'),
    ).toMatchObject({ score: 0.5, isEstimate: true });
  });

  it('budget: annualized EUR ratio tiers', () => {
    // 1800*12/12000 = 1.8 → 1.0
    expect(factor(fullProfile, fullProgram, 'budget').score).toBe(1);
    // 1250*12/12000 = 1.25 → 0.7
    expect(
      factor({ ...fullProfile, monthlyBudgetEur: 1250 }, fullProgram, 'budget')
        .score,
    ).toBe(0.7);
    // 750*12/12000 = 0.75 → 0.4
    expect(
      factor({ ...fullProfile, monthlyBudgetEur: 750 }, fullProgram, 'budget')
        .score,
    ).toBe(0.4);
    // 400*12/12000 = 0.4 → 0.1
    expect(
      factor({ ...fullProfile, monthlyBudgetEur: 400 }, fullProgram, 'budget')
        .score,
    ).toBe(0.1);
    expect(
      factor({ ...fullProfile, monthlyBudgetEur: null }, fullProgram, 'budget'),
    ).toMatchObject({ score: 0.5, isEstimate: true });
  });

  it('timing: months-to-deadline ladder', () => {
    const withDeadline = (months: number) => ({
      ...fullProgram,
      applicationDeadline: monthsFromNow(months),
    });
    expect(factor(fullProfile, withDeadline(8), 'timing').score).toBe(1);
    expect(factor(fullProfile, withDeadline(4), 'timing').score).toBe(0.8);
    expect(factor(fullProfile, withDeadline(2), 'timing').score).toBe(0.5);
    expect(factor(fullProfile, withDeadline(0.5), 'timing').score).toBe(0.2);
    expect(factor(fullProfile, withDeadline(-1), 'timing').score).toBe(0);
    expect(
      factor(fullProfile, { ...fullProgram, applicationDeadline: null }, 'timing'),
    ).toMatchObject({ score: 0.5, isEstimate: true });
  });
});

describe('scoreProgram — totals, caps and guardrails', () => {
  it('full-data best case: 0.96 (Advanced language caps at 0.8), green, not an estimate', () => {
    const result = scoreProgram(fullProfile, fullProgram, { now: NOW });
    // 0.3·1 + 0.2·1 + 0.2·0.8 + 0.2·1 + 0.1·1 = 0.96
    expect(result.probability).toBe(0.96);
    expect(result.zone).toBe('green');
    expect(result.isEstimate).toBe(false);
  });

  it('one missing factor: isEstimate but no cap', () => {
    const result = scoreProgram(
      fullProfile,
      { ...fullProgram, applicationDeadline: null },
      { now: NOW },
    );
    // 0.3 + 0.2 + 0.16 + 0.2 + 0.1*0.5 = 0.91 — above the 0.65 cap, kept.
    expect(result.probability).toBe(0.91);
    expect(result.isEstimate).toBe(true);
  });

  it('two missing factors: capped at 0.65 (never GREEN on guesses)', () => {
    const result = scoreProgram(
      fullProfile,
      {
        ...fullProgram,
        applicationDeadline: null,
        teachingLanguages: [],
      },
      { now: NOW },
    );
    expect(result.probability).toBeLessThanOrEqual(0.65);
    expect(result.zone).toBe('yellow');
    expect(result.isEstimate).toBe(true);
  });

  it('level-mismatch guardrail caps at 0.20 (blue)', () => {
    const result = scoreProgram(
      { ...fullProfile, targetLevel: 'Master' },
      fullProgram, // Bachelor program
      { now: NOW },
    );
    expect(result.probability).toBeLessThanOrEqual(0.2);
    expect(result.zone).toBe('blue');
  });

  it('unmappable program level falls back to institution studyLevels', () => {
    const oddLevel = {
      ...fullProgram,
      levelFr: 'Certificat',
      levelEn: 'Certificate',
    };
    const capped = scoreProgram({ ...fullProfile, targetLevel: 'Master' }, oddLevel, {
      now: NOW,
      institutionStudyLevels: ['Bachelor'],
    });
    expect(capped.probability).toBeLessThanOrEqual(0.2);
    const allowed = scoreProgram(
      { ...fullProfile, targetLevel: 'Master' },
      oddLevel,
      { now: NOW, institutionStudyLevels: ['Bachelor', 'Master'] },
    );
    expect(allowed.probability).toBeGreaterThan(0.2);
  });

  it('deadline-passed guardrail caps at 0.10', () => {
    const result = scoreProgram(
      fullProfile,
      { ...fullProgram, applicationDeadline: monthsFromNow(-2) },
      { now: NOW },
    );
    expect(result.probability).toBeLessThanOrEqual(0.1);
    expect(result.zone).toBe('blue');
  });

  it('zone thresholds: green > 0.70, yellow 0.30–0.70, blue < 0.30', () => {
    // Mid case: mismatch field (0.2*0.2) + everything else strong.
    const yellow = scoreProgram(
      { ...fullProfile, monthlyBudgetEur: 400, fieldIds: ['business'] },
      fullProgram,
      { now: NOW },
    );
    // 0.3 + 0.04 + 0.16 + 0.02 + 0.1 = 0.62
    expect(yellow.zone).toBe('yellow');

    const blue = scoreProgram(
      {
        ...fullProfile,
        gradeRange: '10 - 12/20',
        fieldIds: ['business'],
        languageLevel: 'Beginner',
        monthlyBudgetEur: 400,
      },
      fullProgram,
      { now: NOW },
    );
    // 0.075 + 0.04 + 0.05 + 0.02 + 0.1 = 0.29 (rounded)
    expect(blue.zone).toBe('blue');
  });
});

describe('MatchesService', () => {
  const mockPrismaService = {
    execute: jest.fn(),
    tryExecute: jest.fn(),
  };
  let service: MatchesService;

  beforeEach(() => {
    jest.clearAllMocks();
    service = new MatchesService(mockPrismaService as unknown as PrismaService);
  });

  function dbFallsBack() {
    // Every tryExecute call returns null → service must fall back to the
    // mock catalog for programs/institutions... except loadProfile, which
    // legitimately 404s. So tests below stub profile explicitly.
    mockPrismaService.tryExecute.mockImplementation(
      async (op: (prisma: unknown) => Promise<unknown>) => {
        const prisma = {
          userProfile: {
            findUnique: async () => ({
              gradeRange: '15+/20',
              languageLevel: 'Advanced',
              targetLevel: 'Bachelor',
              monthlyBudgetEur: 1800,
              fieldIds: ['computer_science'],
              targetCountryIds: ['can'],
            }),
          },
          program: { findMany: async () => null },
          institution: { findMany: async () => null },
          match: { upsert: async () => null },
        };
        try {
          const result = await op(prisma);
          return result ?? null;
        } catch {
          return null;
        }
      },
    );
  }

  it('schoolMatch returns the best-scoring mock program when the DB is down', async () => {
    dbFallsBack();

    const result = await service.schoolMatch('user-1', 'uottawa');

    expect(result.institutionId).toBe('uottawa');
    expect(result.programId).toBe('uottawa-cs');
    expect(result.zone).toBeDefined();
    expect(result.factors).toHaveLength(5);
    expect(result.narrative.fr).toContain('Bachelor en informatique');
    expect(result.narrative.en).toContain('Bachelor in Computer Science');
  });

  it('schoolMatch 404s on an unknown institution', async () => {
    dbFallsBack();

    await expect(service.schoolMatch('user-1', 'nope')).rejects.toThrow(
      NotFoundException,
    );
  });

  it('ahaMoment returns one entry per institution, sorted by probability', async () => {
    dbFallsBack();

    const result = await service.ahaMoment('user-1', 5);

    // Mock catalog: profile targets 'can' → uottawa-cs only.
    expect(result.items).toHaveLength(1);
    expect(result.items[0].institutionId).toBe('uottawa');
    expect(result.items[0].institutionName.en).toBe('University of Ottawa');
  });

  it('ahaMoment falls back to the whole catalog when preference filters match nothing', async () => {
    mockPrismaService.tryExecute.mockImplementation(
      async (op: (prisma: unknown) => Promise<unknown>) => {
        const prisma = {
          userProfile: {
            findUnique: async () => ({
              gradeRange: null,
              languageLevel: null,
              targetLevel: null,
              monthlyBudgetEur: null,
              fieldIds: [],
              targetCountryIds: ['xyz'], // matches no catalog row
            }),
          },
          program: { findMany: async () => null },
          institution: { findMany: async () => null },
          match: { upsert: async () => null },
        };
        try {
          const result = await op(prisma);
          return result ?? null;
        } catch {
          return null;
        }
      },
    );

    const result = await service.ahaMoment('user-1');

    expect(result.items.length).toBeGreaterThan(0);
    // Everything is missing on the profile side → estimates, capped ≤ 0.65.
    expect(result.isEstimate).toBe(true);
    for (const item of result.items) {
      expect(item.probability).toBeLessThanOrEqual(0.65);
    }
  });

  it('ahaMoment 404s when the profile does not exist', async () => {
    mockPrismaService.tryExecute.mockResolvedValue(null);

    await expect(service.ahaMoment('ghost')).rejects.toThrow(NotFoundException);
  });
});
