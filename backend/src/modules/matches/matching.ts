// Deterministic admission-probability scoring, v1 (Phase 0 / P0-D).
// Adapted from the Karatou kit's docs/matching_algorithm.md to the data this
// repo actually has (see docs/phase0-new-plan-alignment.md, decision D8):
//  - academic uses the UserProfile.gradeRange bucket midpoint (no gpa field);
//  - field match is binary (no adjacency table yet);
//  - language uses the single UserProfile.languageLevel (no per-language
//    FR/EN granularity yet);
//  - budget compares EUR to EUR directly (monthlyBudgetEur is already EUR,
//    no ExchangeRate needed).
// Pure functions, no I/O — MatchesService feeds them and persists results.

export const ALGORITHM_VERSION = 'v1';

export type FactorName = 'academic' | 'field' | 'language' | 'budget' | 'timing';

export interface MatchFactor {
  name: FactorName;
  weight: number;
  score: number;
  isEstimate: boolean;
}

export type MatchZoneValue = 'green' | 'yellow' | 'blue';

export interface ScoringProfile {
  gradeRange: string | null;
  languageLevel: string | null;
  targetLevel: string | null;
  monthlyBudgetEur: number | null;
  fieldIds: string[];
  targetCountryIds: string[];
}

export interface ScoringProgram {
  id: string;
  institutionId: string;
  countryId: string;
  fieldId: string;
  nameFr: string;
  nameEn: string;
  levelFr: string;
  levelEn: string;
  minGpaRequired: number | null;
  tuitionMinEur: number | null;
  applicationDeadline: Date | null;
  teachingLanguages: string[];
}

export interface MatchScore {
  probability: number;
  zone: MatchZoneValue;
  isEstimate: boolean;
  factors: MatchFactor[];
}

const WEIGHTS: Record<FactorName, number> = {
  academic: 0.3,
  field: 0.2,
  language: 0.2,
  budget: 0.2,
  timing: 0.1,
};

// Neutral score for any factor whose input is missing on either side. The
// kit's rule: never guess in the student's favor nor against them — score
// 0.5, flag the estimate, and cap the total below GREEN when ≥2 are missing.
const NEUTRAL = 0.5;
const MISSING_CAP = 0.65;
const LEVEL_MISMATCH_CAP = 0.2;
const DEADLINE_PASSED_CAP = 0.1;

const LANGUAGE_LEVEL_SCORES: Record<string, number> = {
  none: 0,
  beginner: 0.25,
  intermediate: 0.5,
  advanced: 0.8,
  native: 1,
};

// Canonical study levels and the tokens (FR/EN, case-insensitive) that map to
// them, covering both the onboarding picklists and catalog level labels.
const LEVEL_TOKENS: Record<string, string[]> = {
  highschool: ['high school', 'lycée', 'lycee'],
  bachelor: ['bachelor', 'licence', 'license', 'undergraduate'],
  master: ['master', 'msc', 'mba', 'mim'],
  phd: ['phd', 'doctorat', 'doctorate'],
};

function clamp01(value: number): number {
  return Math.min(1, Math.max(0, value));
}

/** '10 - 12/20' → 11 · '12 - 14/20' → 13 · '15+/20' → 16 · junk → null */
export function gradeRangeMidpoint(gradeRange: string | null): number | null {
  if (!gradeRange) return null;
  const beforeScale = gradeRange.split('/')[0] ?? '';
  const numbers = (beforeScale.match(/\d+(?:[.,]\d+)?/g) ?? []).map((n) =>
    Number(n.replace(',', '.')),
  );
  if (numbers.length === 0) return null;
  if (numbers.length === 1) {
    // Open-ended bucket ('15+') — nudge above the floor.
    return beforeScale.includes('+') ? numbers[0] + 1 : numbers[0];
  }
  return (numbers[0] + numbers[1]) / 2;
}

export function canonicalLevel(label: string | null): string | null {
  if (!label) return null;
  const lower = label.toLowerCase();
  for (const [canonical, tokens] of Object.entries(LEVEL_TOKENS)) {
    if (tokens.some((t) => lower.includes(t))) return canonical;
  }
  return null;
}

function academicFactor(
  profile: ScoringProfile,
  program: ScoringProgram,
): MatchFactor {
  const weight = WEIGHTS.academic;
  const gpa = gradeRangeMidpoint(profile.gradeRange);
  if (gpa === null) {
    return { name: 'academic', weight, score: NEUTRAL, isEstimate: true };
  }
  if (program.minGpaRequired !== null) {
    // 2 points above the requirement = 1.0 · at the requirement = 0.5 ·
    // 2 points below = 0 (kit formula).
    return {
      name: 'academic',
      weight,
      score: clamp01((gpa - program.minGpaRequired + 2) / 4),
      isEstimate: false,
    };
  }
  // No requirement published: absolute scale, 16/20 ⇒ 1.0. The program-side
  // input is missing, so this stays an estimate.
  return {
    name: 'academic',
    weight,
    score: clamp01(gpa / 16),
    isEstimate: true,
  };
}

function fieldFactor(
  profile: ScoringProfile,
  program: ScoringProgram,
): MatchFactor {
  const weight = WEIGHTS.field;
  if (profile.fieldIds.length === 0) {
    return { name: 'field', weight, score: NEUTRAL, isEstimate: true };
  }
  // Binary v1: adjacency tiers arrive with a curated mapping table (see
  // alignment doc — field_adjacency.json does not exist yet).
  return {
    name: 'field',
    weight,
    score: profile.fieldIds.includes(program.fieldId) ? 1 : 0.2,
    isEstimate: false,
  };
}

function languageFactor(
  profile: ScoringProfile,
  program: ScoringProgram,
): MatchFactor {
  const weight = WEIGHTS.language;
  const level = profile.languageLevel?.toLowerCase() ?? '';
  const score = LANGUAGE_LEVEL_SCORES[level];
  if (score === undefined || program.teachingLanguages.length === 0) {
    return { name: 'language', weight, score: NEUTRAL, isEstimate: true };
  }
  // v1 simplification: one self-declared level, applied to whichever language
  // the program teaches in (the profile has no per-language FR/EN detail yet).
  return { name: 'language', weight, score, isEstimate: false };
}

function budgetFactor(
  profile: ScoringProfile,
  program: ScoringProgram,
): MatchFactor {
  const weight = WEIGHTS.budget;
  if (
    profile.monthlyBudgetEur === null ||
    profile.monthlyBudgetEur <= 0 ||
    program.tuitionMinEur === null ||
    program.tuitionMinEur <= 0
  ) {
    return { name: 'budget', weight, score: NEUTRAL, isEstimate: true };
  }
  const ratio = (profile.monthlyBudgetEur * 12) / program.tuitionMinEur;
  let score: number;
  if (ratio >= 1.5) score = 1;
  else if (ratio >= 1) score = 0.7;
  else if (ratio >= 0.7) score = 0.4; // workable with a scholarship
  else score = 0.1;
  return { name: 'budget', weight, score, isEstimate: false };
}

function timingFactor(program: ScoringProgram, now: Date): MatchFactor {
  const weight = WEIGHTS.timing;
  if (!program.applicationDeadline) {
    return { name: 'timing', weight, score: NEUTRAL, isEstimate: true };
  }
  const msLeft = program.applicationDeadline.getTime() - now.getTime();
  const monthsLeft = msLeft / (30 * 24 * 60 * 60 * 1000);
  let score: number;
  if (monthsLeft < 0) score = 0; // passed — also triggers the hard cap below
  else if (monthsLeft > 6) score = 1;
  else if (monthsLeft >= 3) score = 0.8;
  else if (monthsLeft >= 1) score = 0.5;
  else score = 0.2;
  return { name: 'timing', weight, score, isEstimate: false };
}

/** Scores one (profile, program) pair. Deterministic for a fixed `now`. */
export function scoreProgram(
  profile: ScoringProfile,
  program: ScoringProgram,
  options: { institutionStudyLevels?: string[]; now?: Date } = {},
): MatchScore {
  const now = options.now ?? new Date();
  const factors: MatchFactor[] = [
    academicFactor(profile, program),
    fieldFactor(profile, program),
    languageFactor(profile, program),
    budgetFactor(profile, program),
    timingFactor(program, now),
  ];

  let probability = factors.reduce((sum, f) => sum + f.weight * f.score, 0);

  const missingCount = factors.filter((f) => f.isEstimate).length;
  if (missingCount >= 2) {
    probability = Math.min(probability, MISSING_CAP);
  }

  // Guardrail 1 — target level incompatible with the program (falling back to
  // the institution's published levels when the program label is unmappable).
  const targetLevel = canonicalLevel(profile.targetLevel);
  if (targetLevel) {
    const programLevel =
      canonicalLevel(program.levelEn) ?? canonicalLevel(program.levelFr);
    const institutionLevels = (options.institutionStudyLevels ?? [])
      .map((l) => canonicalLevel(l))
      .filter((l): l is string => l !== null);
    const compatible = programLevel
      ? programLevel === targetLevel
      : institutionLevels.length === 0 || institutionLevels.includes(targetLevel);
    if (!compatible) {
      probability = Math.min(probability, LEVEL_MISMATCH_CAP);
    }
  }

  // Guardrail 2 — deadline already passed.
  if (
    program.applicationDeadline &&
    program.applicationDeadline.getTime() < now.getTime()
  ) {
    probability = Math.min(probability, DEADLINE_PASSED_CAP);
  }

  probability = Math.round(probability * 100) / 100;

  return {
    probability,
    zone: probability > 0.7 ? 'green' : probability >= 0.3 ? 'yellow' : 'blue',
    isEstimate: missingCount >= 1,
    factors,
  };
}
