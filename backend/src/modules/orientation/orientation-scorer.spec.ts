import { ORIENTATION_QUESTIONS } from './orientation-questions.data';
import {
  DECLARED_INTEREST_PERCENT,
  matchPercentByField,
  scoreOrientationAnswers,
} from './orientation-scorer';

type Answers = Record<string, string[]>;

// ─────────────────────────────────────────────────────────────────────────────
// A match score is a percentage. It has to stay in [0, 100], it has to tell
// fields apart — otherwise the "best match" badge is arbitrary — and it has to
// be the SAME number the Flutter engine computes, because the app takes the
// backend path by default (`AppConfig.enableRemoteSync`) and the offline path
// when the request fails. Two engines that disagree are worse than one that is
// wrong.
//
// Regression: the backend published `rawPoints * 10` floored at 55, which
// shipped result cards reading "160 %" with two different fields on the exact
// same value.
// ─────────────────────────────────────────────────────────────────────────────

/** Answers that used to make `d01` and `d03` both display "160 %". */
const COLLIDING_ANSWERS: Answers = {
  interests: ['tech'],
  strengths: ['analysis'],
  goal: ['global_job'],
  environment: ['office'],
  level: ['bac3'],
  ai_concern: ['ai_yes'],
  languages: ['lang_fr'],
  avoid: ['avoid_desk'],
  budget_band: ['budget_low'],
  mobility: ['mobility_yes'],
};

/** Answers that all point at `d01` — raw total 24, once published as 240 %. */
const MAXED_OUT_ANSWERS: Answers = {
  interests: ['tech'],
  strengths: ['analysis'],
  goal: ['global_job'],
  environment: ['office'],
  level: ['bac5'],
  ai_concern: ['ai_yes'],
  languages: ['lang_en'],
  budget_band: ['budget_high'],
  mobility: ['mobility_yes'],
};

const HEALTH_ANSWERS: Answers = {
  interests: ['health'],
  strengths: ['care'],
  goal: ['impact'],
  environment: ['hospital'],
  level: ['bac8'],
  ai_concern: ['ai_no'],
  languages: ['lang_fr'],
  avoid: ['avoid_sales'],
  budget_band: ['budget_low'],
  mobility: ['mobility_no'],
};

function percentsOf(answers: Answers): Record<string, number> {
  return Object.fromEntries(matchPercentByField(answers));
}

/** Ranked `[fieldId, percentage]` pairs, as the service publishes them. */
function rankedOf(answers: Answers): Array<[string, number]> {
  const prioritizeIaResilience = (answers.ai_concern ?? []).includes('ai_yes');
  return scoreOrientationAnswers(answers, { prioritizeIaResilience }).map(
    (entry): [string, number] => [entry.fieldId, entry.score],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Golden vectors produced by the Flutter engine itself
// (`OrientationEngine.matchPercentByField` / `.evaluate`, from
// `lib/app/core/data/orientation_engine.dart` fed with the app's own question
// list: `MockCatalog.orientationQuestions + orientationQuestionsM4Extension`).
//
// 16 hand-picked answer sets (including the two that used to collide, the
// subtract-only ones, the practical-questions-only ones, unknown option ids and
// an option sent under the wrong question) followed by 26 seeded random ones.
//
// This is the test that stops the two engines from re-diverging: any change to
// the weights, the per-question importance, the 0.8 perfect-match ratio, the 98
// ceiling or the tie-break has to be made on both sides or this fails.
// ─────────────────────────────────────────────────────────────────────────────
type GoldenVector = {
  answers: Answers;
  /** `OrientationEngine.matchPercentByField` output. */
  percents: Record<string, number>;
  /** Top 5 of `OrientationEngine.evaluate`, best match first. */
  ranked: Array<[string, number]>;
};

const DART_GOLDEN: GoldenVector[] = [
  {
    answers: { "interests": ['tech'], "strengths": ['analysis'], "goal": ['global_job'], "environment": ['office'], "level": ['bac5'], "ai_concern": ['ai_yes'], "languages": ['lang_en'], "budget_band": ['budget_high'], "mobility": ['mobility_yes'] },
    percents: { d01: 98, d05: 36, d03: 87, d02: 45, d07: 31, d04: 13, d12: 5 },
    ranked: [['d01', 98], ['d03', 87], ['d02', 45], ['d05', 36], ['d07', 31]],
  },
  {
    answers: { "interests": ['tech'], "strengths": ['analysis'], "goal": ['global_job'], "environment": ['office'], "level": ['bac3'], "ai_concern": ['ai_yes'], "languages": ['lang_fr'], "avoid": ['avoid_desk'], "budget_band": ['budget_low'], "mobility": ['mobility_yes'] },
    percents: { d01: 87, d05: 37, d03: 80, d02: 41, d06: 7, d12: 17, d04: 14, d07: 14, d09: 11, d08: 5 },
    ranked: [['d01', 87], ['d03', 80], ['d02', 41], ['d05', 37], ['d12', 17]],
  },
  {
    answers: { "interests": ['health'], "strengths": ['care'], "goal": ['impact'], "environment": ['hospital'], "level": ['bac8'], "ai_concern": ['ai_no'], "languages": ['lang_fr'], "avoid": ['avoid_sales'], "budget_band": ['budget_low'], "mobility": ['mobility_no'] },
    percents: { d04: 98, d09: 49, d07: 16, d08: 21, d05: 7, d10: 11, d06: 4, d12: 5 },
    ranked: [['d04', 98], ['d09', 49], ['d08', 21], ['d07', 16], ['d10', 11]],
  },
  {
    answers: { "interests": ['tech'], "ai_concern": ['ai_yes'] },
    percents: { d01: 98, d05: 63, d03: 42, d04: 28, d07: 28 },
    ranked: [['d01', 98], ['d05', 63], ['d03', 42], ['d04', 28], ['d07', 28]],
  },
  {
    answers: { "avoid": ['avoid_sales'] },
    percents: {  },
    ranked: [],
  },
  {
    answers: { "avoid": ['avoid_sales', 'avoid_lab', 'avoid_desk'] },
    percents: {  },
    ranked: [],
  },
  {
    answers: { "interests": ['tech', 'biz', 'create'], "strengths": ['creativity'], "goal": ['entrepreneur'], "environment": ['studio'], "level": ['bac3'], "languages": ['lang_both'], "budget_band": ['budget_mid'], "mobility": ['mobility_maybe'] },
    percents: { d01: 24, d05: 15, d02: 53, d03: 19, d06: 70, d11: 35, d12: 14, d07: 5, d09: 2 },
    ranked: [['d06', 70], ['d02', 53], ['d11', 35], ['d01', 24], ['d03', 19]],
  },
  {
    answers: { "budget_band": ['budget_low'] },
    percents: { d09: 98, d08: 98, d12: 98 },
    ranked: [['d08', 98], ['d09', 98], ['d12', 98]],
  },
  {
    answers: { "mobility": ['mobility_yes'] },
    percents: { d07: 98, d12: 98, d02: 63 },
    ranked: [['d07', 98], ['d12', 98], ['d02', 63]],
  },
  {
    answers: { "budget_band": ['budget_low'], "mobility": ['mobility_no'] },
    percents: { d09: 98, d08: 63, d12: 63, d10: 31 },
    ranked: [['d09', 98], ['d08', 63], ['d12', 63], ['d10', 31]],
  },
  {
    answers: {  },
    percents: {  },
    ranked: [],
  },
  {
    answers: { "interests": ['env'], "strengths": ['analysis'], "goal": ['impact'], "environment": ['field'], "level": ['bac5'], "ai_concern": ['ai_yes'], "languages": ['lang_en'], "avoid": ['avoid_lab'], "budget_band": ['budget_low'], "mobility": ['mobility_yes'] },
    percents: { d08: 64, d10: 32, d01: 51, d03: 43, d05: 31, d04: 20, d07: 42, d02: 15, d09: 5, d12: 10 },
    ranked: [['d08', 64], ['d01', 51], ['d03', 43], ['d07', 42], ['d10', 32]],
  },
  {
    answers: { "interests": ['tech', 'nope_unknown'], "unknown_question": ['tech'] },
    percents: { d01: 98, d05: 94 },
    ranked: [['d01', 98], ['d05', 94]],
  },
  {
    answers: { "interests": ['analysis'], "strengths": ['tech'] },
    percents: {  },
    ranked: [],
  },
  {
    answers: { "mobility": ['mobility_maybe'], "avoid": ['avoid_sales'] },
    percents: { d09: 98 },
    ranked: [['d09', 98]],
  },
  {
    answers: { "interests": ['tech'], "avoid": ['avoid_desk'], "mobility": ['mobility_no'] },
    percents: { d01: 83, d05: 78, d09: 21, d10: 10 },
    ranked: [['d01', 83], ['d05', 78], ['d09', 21], ['d10', 10]],
  },
  {
    answers: { "interests": ['tech', 'env'], "strengths": ['communication'], "goal": ['research'], "environment": ['hospital'], "ai_concern": ['ai_no'], "languages": ['lang_both'], "budget_band": ['budget_low'], "mobility": ['mobility_no'] },
    percents: { d01: 27, d05: 31, d08: 26, d10: 26, d06: 24, d02: 21, d07: 15, d09: 28, d04: 30, d12: 4 },
    ranked: [['d05', 31], ['d04', 30], ['d09', 28], ['d01', 27], ['d08', 26]],
  },
  {
    answers: { "interests": ['create'], "strengths": ['care'], "goal": ['global_job'], "level": ['bac3'], "ai_concern": ['ai_yes'], "avoid": ['avoid_sales'], "budget_band": ['budget_mid'], "mobility": ['mobility_no'] },
    percents: { d06: 46, d11: 16, d04: 40, d09: 28, d01: 36, d02: 23, d03: 50, d12: 8, d07: 11, d10: 3 },
    ranked: [['d03', 50], ['d06', 46], ['d04', 40], ['d01', 36], ['d09', 28]],
  },
  {
    answers: { "interests": ['create'], "strengths": ['communication'], "environment": ['field'], "ai_concern": ['ai_yes'], "languages": ['lang_fr'], "avoid": ['avoid_desk'], "budget_band": ['budget_high'], "mobility": ['mobility_no'] },
    percents: { d06: 64, d11: 16, d02: 24, d07: 33, d05: 18, d08: 24, d10: 21, d01: 16, d03: 16, d04: 25, d09: 14 },
    ranked: [['d06', 64], ['d07', 33], ['d04', 25], ['d02', 24], ['d08', 24]],
  },
  {
    answers: { "interests": ['env', 'law_pol'], "strengths": ['analysis'], "goal": ['research'], "ai_concern": ['ai_no'], "budget_band": ['budget_low'] },
    percents: { d07: 29, d09: 45, d08: 35, d10: 31, d01: 27, d03: 27, d05: 39, d04: 13, d06: 5, d12: 6 },
    ranked: [['d09', 45], ['d05', 39], ['d08', 35], ['d10', 31], ['d07', 29]],
  },
  {
    answers: { "interests": ['tech', 'create', 'health'], "goal": ['entrepreneur'], "environment": ['field'], "level": ['bac8'], "ai_concern": ['ai_no'], "avoid": ['avoid_lab'], "budget_band": ['budget_high'], "mobility": ['mobility_no'] },
    percents: { d01: 26, d05: 34, d04: 26, d09: 19, d06: 35, d11: 11, d02: 19, d12: 9, d08: 16, d10: 21, d07: 4 },
    ranked: [['d06', 35], ['d05', 34], ['d01', 26], ['d04', 26], ['d10', 21]],
  },
  {
    answers: { "interests": ['create'], "strengths": ['care'], "goal": ['research'], "ai_concern": ['ai_yes'], "languages": ['lang_fr'], "mobility": ['mobility_maybe'] },
    percents: { d06: 34, d11: 17, d04: 67, d09: 65, d05: 22, d01: 17, d03: 17, d07: 11, d02: 11 },
    ranked: [['d04', 67], ['d09', 65], ['d06', 34], ['d05', 22], ['d01', 17]],
  },
  {
    answers: { "interests": ['biz'], "strengths": ['leadership'], "goal": ['research'], "environment": ['field'], "level": ['bac8'], "ai_concern": ['ai_yes'], "languages": ['lang_both'], "avoid": ['avoid_sales'], "budget_band": ['budget_mid'], "mobility": ['mobility_yes'] },
    percents: { d02: 51, d03: 33, d05: 48, d09: 31, d04: 29, d08: 18, d10: 14, d01: 18, d07: 19, d06: 5, d12: 5 },
    ranked: [['d02', 51], ['d05', 48], ['d03', 33], ['d09', 31], ['d04', 29]],
  },
  {
    answers: { "interests": ['env'], "strengths": ['analysis'], "goal": ['global_job'], "environment": ['intl'], "level": ['bac5'], "ai_concern": ['ai_yes'], "languages": ['lang_fr'], "avoid": ['avoid_sales'], "budget_band": ['budget_high'], "mobility": ['mobility_maybe'] },
    percents: { d08: 26, d10: 19, d01: 66, d03: 66, d05: 18, d02: 31, d07: 35, d12: 19, d04: 20, d09: 9 },
    ranked: [['d01', 66], ['d03', 66], ['d07', 35], ['d02', 31], ['d08', 26]],
  },
  {
    answers: { "interests": ['health'], "strengths": ['analysis'], "goal": ['entrepreneur'], "level": ['bac3'], "languages": ['lang_both'], "avoid": ['avoid_desk'], "budget_band": ['budget_high'] },
    percents: { d04: 43, d09: 9, d01: 42, d03: 38, d05: 25, d02: 42, d06: 25, d12: 25, d07: 15 },
    ranked: [['d04', 43], ['d01', 42], ['d02', 42], ['d03', 38], ['d05', 25]],
  },
  {
    answers: { "interests": ['create', 'law_pol', 'tech'], "strengths": ['care'], "goal": ['impact'], "environment": ['office'], "level": ['bac8'], "ai_concern": ['ai_no'], "languages": ['lang_en'], "avoid": ['avoid_lab'], "budget_band": ['budget_low'], "mobility": ['mobility_maybe'] },
    percents: { d01: 34, d05: 18, d07: 34, d09: 34, d06: 21, d11: 9, d04: 33, d08: 15, d02: 16, d03: 14, d10: 6, d12: 4 },
    ranked: [['d01', 34], ['d07', 34], ['d09', 34], ['d04', 33], ['d06', 21]],
  },
  {
    answers: { "interests": ['env', 'law_pol', 'biz'], "strengths": ['leadership'], "goal": ['global_job'], "environment": ['hospital'], "level": ['bac5'], "languages": ['lang_en'], "avoid": ['avoid_lab'], "mobility": ['mobility_no'] },
    percents: { d02: 59, d03: 37, d07: 29, d09: 13, d08: 19, d10: 16, d05: 9, d01: 24, d04: 10 },
    ranked: [['d02', 59], ['d03', 37], ['d07', 29], ['d01', 24], ['d08', 19]],
  },
  {
    answers: { "strengths": ['leadership'], "goal": ['impact'], "level": ['bac8'], "ai_concern": ['ai_no'], "languages": ['lang_fr'], "avoid": ['avoid_lab'], "budget_band": ['budget_high'], "mobility": ['mobility_maybe'] },
    percents: { d02: 52, d05: 30, d04: 53, d07: 35, d08: 26, d09: 30, d10: 14, d06: 7, d01: 8 },
    ranked: [['d04', 53], ['d02', 52], ['d07', 35], ['d05', 30], ['d09', 30]],
  },
  {
    answers: { "interests": ['biz', 'health', 'tech'], "goal": ['entrepreneur'], "environment": ['intl'], "level": ['bac8'], "languages": ['lang_fr'], "avoid": ['avoid_lab'], "budget_band": ['budget_low'] },
    percents: { d01: 23, d05: 23, d02: 57, d03: 13, d04: 28, d09: 25, d06: 10, d12: 31, d07: 13, d08: 5 },
    ranked: [['d02', 57], ['d12', 31], ['d04', 28], ['d09', 25], ['d01', 23]],
  },
  {
    answers: { "interests": ['create', 'tech', 'health'], "goal": ['global_job'], "environment": ['intl'], "level": ['bac3'], "ai_concern": ['ai_no'], "avoid": ['avoid_lab'], "mobility": ['mobility_no'] },
    percents: { d01: 38, d05: 17, d04: 14, d09: 10, d06: 33, d11: 12, d02: 30, d03: 19, d07: 13, d12: 23, d10: 10 },
    ranked: [['d01', 38], ['d06', 33], ['d02', 30], ['d12', 23], ['d03', 19]],
  },
  {
    answers: { "interests": ['biz'], "strengths": ['communication'], "goal": ['global_job'], "environment": ['field'], "level": ['bac8'], "ai_concern": ['ai_yes'], "languages": ['lang_both'], "avoid": ['avoid_lab'], "budget_band": ['budget_low'] },
    percents: { d02: 66, d03: 49, d06: 24, d07: 27, d01: 36, d05: 21, d08: 24, d10: 14, d04: 9, d09: 15, d12: 5 },
    ranked: [['d02', 66], ['d03', 49], ['d01', 36], ['d07', 27], ['d06', 24]],
  },
  {
    answers: { "strengths": ['care'], "goal": ['entrepreneur'], "environment": ['office'], "ai_concern": ['ai_yes'], "languages": ['lang_fr'], "budget_band": ['budget_low'], "mobility": ['mobility_maybe'] },
    percents: { d04: 53, d09: 43, d02: 61, d06: 15, d12: 22, d01: 37, d03: 43, d07: 12, d08: 7 },
    ranked: [['d02', 61], ['d04', 53], ['d03', 43], ['d09', 43], ['d01', 37]],
  },
  {
    answers: { "interests": ['create', 'biz', 'tech'], "strengths": ['analysis'], "goal": ['entrepreneur'], "environment": ['office'], "level": ['bac8'], "ai_concern": ['ai_no'], "languages": ['lang_fr'], "avoid": ['avoid_desk'], "budget_band": ['budget_mid'], "mobility": ['mobility_yes'] },
    percents: { d01: 41, d05: 31, d02: 50, d03: 46, d06: 33, d11: 9, d12: 11, d04: 11, d09: 11, d10: 6, d07: 4 },
    ranked: [['d02', 50], ['d03', 46], ['d01', 41], ['d06', 33], ['d05', 31]],
  },
  {
    answers: { "interests": ['env', 'law_pol', 'tech'], "strengths": ['analysis'], "goal": ['global_job'], "level": ['bac5'], "ai_concern": ['ai_yes'], "budget_band": ['budget_mid'], "mobility": ['mobility_maybe'] },
    percents: { d01: 71, d05: 31, d07: 34, d09: 13, d08: 21, d10: 16, d03: 57, d02: 26, d04: 7, d06: 4 },
    ranked: [['d01', 71], ['d03', 57], ['d07', 34], ['d05', 31], ['d02', 26]],
  },
  {
    answers: { "interests": ['tech'], "strengths": ['analysis'], "goal": ['research'], "environment": ['hospital'], "ai_concern": ['ai_yes'], "languages": ['lang_en'], "avoid": ['avoid_lab'], "budget_band": ['budget_high'] },
    percents: { d01: 78, d05: 55, d03: 38, d09: 23, d04: 39, d07: 20, d02: 6 },
    ranked: [['d01', 78], ['d05', 55], ['d04', 39], ['d03', 38], ['d09', 23]],
  },
  {
    answers: { "interests": ['tech'], "goal": ['global_job'], "environment": ['studio'], "ai_concern": ['ai_no'], "languages": ['lang_both'], "avoid": ['avoid_sales'], "mobility": ['mobility_no'] },
    percents: { d01: 70, d05: 28, d02: 18, d03: 32, d06: 33, d11: 20, d10: 16, d07: 9, d09: 7 },
    ranked: [['d01', 70], ['d06', 33], ['d03', 32], ['d05', 28], ['d11', 20]],
  },
  {
    answers: { "interests": ['tech', 'biz', 'health'], "goal": ['impact'], "environment": ['hospital'], "ai_concern": ['ai_no'], "languages": ['lang_both'], "budget_band": ['budget_low'], "mobility": ['mobility_maybe'] },
    percents: { d01: 27, d05: 17, d02: 29, d03: 17, d04: 62, d09: 12, d07: 20, d08: 19, d10: 7, d06: 4, d12: 4 },
    ranked: [['d04', 62], ['d02', 29], ['d01', 27], ['d07', 20], ['d08', 19]],
  },
  {
    answers: { "interests": ['env', 'create', 'tech'], "goal": ['research'], "level": ['bac8'], "ai_concern": ['ai_yes'], "languages": ['lang_en'], "avoid": ['avoid_lab'] },
    percents: { d01: 45, d05: 41, d06: 24, d11: 12, d08: 24, d10: 18, d09: 31, d04: 19, d03: 13, d07: 14, d02: 6 },
    ranked: [['d01', 45], ['d05', 41], ['d09', 31], ['d06', 24], ['d08', 24]],
  },
  {
    answers: { "strengths": ['analysis'], "goal": ['entrepreneur'], "environment": ['hospital'], "level": ['bac5'], "ai_concern": ['ai_yes'], "languages": ['lang_en'], "avoid": ['avoid_sales'], "budget_band": ['budget_mid'], "mobility": ['mobility_yes'] },
    percents: { d01: 61, d03: 60, d05: 21, d02: 37, d06: 19, d12: 19, d04: 37, d07: 31 },
    ranked: [['d01', 61], ['d03', 60], ['d04', 37], ['d02', 37], ['d07', 31]],
  },
  {
    answers: { "interests": ['health', 'tech', 'biz'], "strengths": ['care'], "goal": ['global_job'], "environment": ['office'], "level": ['bac3'], "ai_concern": ['ai_no'], "avoid": ['avoid_sales'], "budget_band": ['budget_low'], "mobility": ['mobility_no'] },
    percents: { d01: 42, d05: 14, d02: 40, d03: 48, d04: 37, d09: 26, d06: 8, d12: 9, d10: 8, d08: 4 },
    ranked: [['d03', 48], ['d01', 42], ['d02', 40], ['d04', 37], ['d09', 26]],
  },
  {
    answers: { "interests": ['law_pol'], "strengths": ['creativity'], "goal": ['impact'], "level": ['bac5'], "ai_concern": ['ai_no'], "languages": ['lang_en'], "avoid": ['avoid_sales'] },
    percents: { d07: 72, d09: 17, d06: 37, d11: 23, d04: 29, d08: 22, d01: 21, d02: 3, d03: 17, d10: 11 },
    ranked: [['d07', 72], ['d06', 37], ['d04', 29], ['d11', 23], ['d08', 22]],
  },
  {
    answers: { "strengths": ['creativity'], "goal": ['research'], "level": ['bac8'], "ai_concern": ['ai_yes'], "avoid": ['avoid_desk'], "budget_band": ['budget_mid'], "mobility": ['mobility_yes'] },
    percents: { d06: 46, d11: 28, d09: 51, d05: 37, d04: 47, d01: 12, d03: 24, d07: 22, d02: 4, d12: 8 },
    ranked: [['d09', 51], ['d04', 47], ['d06', 46], ['d05', 37], ['d11', 28]],
  },
];

describe('orientation scorer — Flutter/backend parity', () => {
  it('covers every question and a decent spread of answer sets', () => {
    expect(DART_GOLDEN.length).toBeGreaterThanOrEqual(40);
    const questionsSeen = new Set<string>();
    for (const vector of DART_GOLDEN) {
      Object.keys(vector.answers).forEach((id) => questionsSeen.add(id));
    }
    for (const question of ORIENTATION_QUESTIONS) {
      expect(questionsSeen).toContain(question.id);
    }
  });

  DART_GOLDEN.forEach((vector, index) => {
    it(`publishes the Dart percentages for vector #${index}`, () => {
      expect(percentsOf(vector.answers)).toEqual(vector.percents);
    });

    it(`publishes the Dart ranking for vector #${index}`, () => {
      expect(rankedOf(vector.answers)).toEqual(vector.ranked);
    });
  });

  it('falls back to the declared profile fields at the Dart percentage', () => {
    // Dart: profile.fieldIds ['d07','d02','d07'] with no answers →
    // d02 and d07 at 55, deduplicated, id-ascending.
    expect(
      scoreOrientationAnswers({}, { declaredFieldIds: ['d07', 'd02', 'd07'] }),
    ).toEqual([
      { fieldId: 'd02', score: DECLARED_INTEREST_PERCENT },
      { fieldId: 'd07', score: DECLARED_INTEREST_PERCENT },
    ]);
  });
});

describe('orientation scorer — percentage invariants', () => {
  it('never publishes more than 100 %, even when answers pile up', () => {
    const ranked = rankedOf(MAXED_OUT_ANSWERS);

    expect(ranked.length).toBeGreaterThan(0);
    expect(ranked[0][0]).toBe('d01');
    for (const [fieldId, score] of ranked) {
      expect(score).toBeGreaterThanOrEqual(0);
      expect(score).toBeLessThanOrEqual(100);
      expect(`${fieldId}:${score}`).not.toBe(`${fieldId}:240`);
    }
  });

  it('stays inside [0, 100] over 400 random answer sets', () => {
    // Deterministic PRNG (mulberry32) — a failure is always reproducible.
    let seed = 0x9e3779b9;
    const random = () => {
      seed = (seed + 0x6d2b79f5) | 0;
      let t = Math.imul(seed ^ (seed >>> 15), 1 | seed);
      t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
      return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };

    for (let i = 0; i < 400; i++) {
      const answers: Answers = {};
      for (const question of ORIENTATION_QUESTIONS) {
        const options = question.options;
        if (question.multiSelect) {
          const picks = new Set<string>();
          const count = 1 + Math.floor(random() * Math.min(3, options.length));
          while (picks.size < count) {
            picks.add(options[Math.floor(random() * options.length)].id);
          }
          answers[question.id] = Array.from(picks);
        } else {
          answers[question.id] = [
            options[Math.floor(random() * options.length)].id,
          ];
        }
      }

      for (const [fieldId, score] of matchPercentByField(answers)) {
        expect({ fieldId, score, answers }).toMatchObject({
          score: expect.any(Number),
        });
        expect(score).toBeGreaterThanOrEqual(0);
        expect(score).toBeLessThanOrEqual(100);
      }
    }
  });

  it('tells the top two fields apart on the answers that used to tie', () => {
    const ranked = rankedOf(COLLIDING_ANSWERS);

    expect(ranked.length).toBeGreaterThanOrEqual(2);
    // d01 and d03 both totalled 16 raw points → both displayed "160 %".
    expect(ranked[0][1]).not.toBe(ranked[1][1]);
    expect(new Set(ranked.map(([, score]) => score)).size).toBe(ranked.length);
    // Ranked best first — the "best match" badge sits on the highest score.
    const sorted = [...ranked].sort((a, b) => b[1] - a[1]);
    expect(ranked).toEqual(sorted);
  });

  it('gives different profiles different scores', () => {
    const tech = percentsOf(COLLIDING_ANSWERS);
    const health = percentsOf(HEALTH_ANSWERS);

    expect(tech).not.toEqual(health);
    expect(rankedOf(COLLIDING_ANSWERS)[0][0]).toBe('d01');
    expect(rankedOf(HEALTH_ANSWERS)[0][0]).toBe('d04');
    expect(rankedOf(COLLIDING_ANSWERS)[0][1]).not.toBe(
      rankedOf(HEALTH_ANSWERS)[0][1],
    );
    // Two sets that differ only on the practical questions must not collapse
    // onto the same percentage either.
    expect(rankedOf(COLLIDING_ANSWERS)[0][1]).not.toBe(
      rankedOf(MAXED_OUT_ANSWERS)[0][1],
    );
  });

  it('has no 55 floor: a weak match stays weak', () => {
    const weak = rankedOf({
      interests: ['tech'],
      avoid: ['avoid_desk'],
      mobility: ['mobility_no'],
    });
    const lowest = weak[weak.length - 1][1];

    expect(lowest).toBeGreaterThan(0);
    expect(lowest).toBeLessThan(DECLARED_INTEREST_PERCENT);
  });

  it('does not recommend a field the answers pushed away', () => {
    expect(rankedOf({ avoid: ['avoid_sales'] })).toEqual([]);
    // d02 nets 0.6 - 2.4 here, so it is not a recommendation at all.
    expect(
      rankedOf({ mobility: ['mobility_maybe'], avoid: ['avoid_sales'] }).map(
        ([fieldId]) => fieldId,
      ),
    ).toEqual(['d09']);
  });

  it('ignores unknown questions and misplaced option ids', () => {
    expect(percentsOf({ nope: ['tech'] })).toEqual({});
    // `analysis` belongs to `strengths`, not `interests`.
    expect(percentsOf({ interests: ['analysis'] })).toEqual({});
    expect(percentsOf({ interests: ['tech', 'unknown_option'] })).toEqual(
      percentsOf({ interests: ['tech'] }),
    );
  });
});

describe('orientation scorer — every question is scored', () => {
  it('scores every option of every question', () => {
    // The backend used to ignore the budget_* and mobility_* options entirely:
    // 2 of the 10 questions did not count server-side while they counted in the
    // app, so the two engines could not agree by construction.
    for (const question of ORIENTATION_QUESTIONS) {
      for (const option of question.options) {
        const weights = Object.values(option.weights);
        expect(weights.length).toBeGreaterThan(0);

        const percents = matchPercentByField({ [question.id]: [option.id] });
        const isSubtractiveOnly = weights.every((weight) => weight < 0);
        if (isSubtractiveOnly) {
          expect(percents.size).toBe(0);
        } else {
          expect(percents.size).toBeGreaterThan(0);
        }
      }
    }
  });

  it('lets budget_band and mobility move the score', () => {
    const base: Answers = { interests: ['tech'], strengths: ['analysis'] };

    const withBudget = percentsOf({ ...base, budget_band: ['budget_low'] });
    const withMobility = percentsOf({ ...base, mobility: ['mobility_no'] });

    expect(withBudget).not.toEqual(percentsOf(base));
    expect(withMobility).not.toEqual(percentsOf(base));
    // budget_low pulls d08/d09/d12 in; without it they score nothing.
    expect(Object.keys(percentsOf(base))).not.toContain('d09');
    expect(withBudget.d09).toBeGreaterThan(0);
    expect(withMobility.d09).toBeGreaterThan(0);
  });
});
