import { ORIENTATION_FIELD_BY_ID } from './orientation-fields.data';
import { ORIENTATION_QUESTIONS } from './orientation-questions.data';

type Answers = Record<string, string[]>;

export type ScoredField = { fieldId: string; score: number };

/**
 * Relative importance of each question in the match score. What a student is
 * drawn to (interests, strengths, goal) weighs more than the practical
 * constraints (budget, mobility).
 *
 * The non-uniform, fractional importances are also what give the score real
 * resolution. A flat sum of integer weights landed two *different* fields on
 * the exact same total for ~15% of answer sets, so two cards displayed the same
 * percentage and the "best match" badge fell on whichever field the sort
 * happened to keep first.
 *
 * Mirrors `OrientationEngine._questionImportance`
 * (`lib/app/core/data/orientation_engine.dart`).
 */
const QUESTION_IMPORTANCE: Record<string, number> = {
  interests: 1.5,
  strengths: 1.4,
  goal: 1.3,
  avoid: 1.2,
  environment: 1.1,
  ai_concern: 1.0,
  level: 0.8,
  languages: 0.7,
  budget_band: 0.6,
  mobility: 0.6,
};

/** Importance applied to any question missing from `QUESTION_IMPORTANCE`. */
const DEFAULT_IMPORTANCE = 1.0;

/**
 * Share of the attainable weight that counts as a perfect (100%) match.
 *
 * The attainable weight is what an imaginary field would score if it were the
 * top-weighted answer to *every* question the student answered. No real field
 * can be, so normalising on that raw ceiling would keep even excellent matches
 * near 60%. A field that captures 80% of the ceiling is a perfect match.
 */
const PERFECT_MATCH_RATIO = 0.8;

/** Highest percentage ever surfaced — no card claims a flawless 100%. */
const MAX_PERCENT = 98;

/**
 * Percentage used when there is nothing to score and the recommendation falls
 * back to the fields the student declared in their profile.
 */
export const DECLARED_INTEREST_PERCENT = 55;

/**
 * AI-resilience ranking used to break *exact* percentage ties.
 *
 * Mirrors `OrientationEngine._fieldIaResilience` so client and server rank an
 * identical set of scores identically. Careful: that Dart table disagrees with
 * the catalog metadata (`ORIENTATION_FIELDS` here, `fields_data.dart` in the
 * app) on `d08` and `d11`. Only the tie-break reads this map — the resilience
 * *published* in a recommendation still comes from the catalog — and the
 * discrepancy should be reconciled on the Dart side, after which this map can
 * be replaced by `ORIENTATION_FIELD_BY_ID`.
 */
const TIE_BREAK_IA_RESILIENCE: Record<string, 'high' | 'medium' | 'low'> = {
  d01: 'high',
  d02: 'medium',
  d03: 'high',
  d04: 'high',
  d05: 'medium',
  d06: 'medium',
  d07: 'high',
  d08: 'medium',
  d09: 'medium',
  d10: 'low',
  d11: 'high',
  d12: 'medium',
};

const IA_RESILIENCE_RANK = { high: 3, medium: 2, low: 1 } as const;

function iaRankOf(fieldId: string): number {
  return IA_RESILIENCE_RANK[TIE_BREAK_IA_RESILIENCE[fieldId] ?? 'medium'];
}

/**
 * Weighted alignment per field for `answers`, plus the ceiling a single field
 * could reach on those very same answers.
 *
 * Only ids declared in `ORIENTATION_QUESTIONS` count: an unknown question id,
 * or an option id sent under the wrong question, is ignored — exactly like the
 * Dart engine, which looks options up inside their question.
 */
function weigh(answers: Answers): {
  weights: Map<string, number>;
  attainable: number;
} {
  const weights = new Map<string, number>();
  let attainable = 0;

  for (const question of ORIENTATION_QUESTIONS) {
    const selected = answers[question.id];
    if (!Array.isArray(selected) || selected.length === 0) continue;
    const importance = QUESTION_IMPORTANCE[question.id] ?? DEFAULT_IMPORTANCE;

    for (const option of question.options) {
      if (!selected.includes(option.id)) continue;

      let best = 0;
      for (const [fieldId, weight] of Object.entries(option.weights)) {
        weights.set(fieldId, (weights.get(fieldId) ?? 0) + importance * weight);
        if (weight > best) best = weight;
      }
      // Best a single field could score on this option. Options that only
      // subtract (the "what would you NOT do" question) raise nobody's score,
      // so they add nothing to the ceiling either.
      attainable += importance * best;
    }
  }

  return { weights, attainable };
}

function percentOf(weighted: number, attainable: number): number {
  if (weighted <= 0 || attainable <= 0) return 0;
  const ratio = weighted / (attainable * PERFECT_MATCH_RATIO);
  return Math.min(MAX_PERCENT, Math.max(0, Math.round(ratio * 100)));
}

/**
 * Match percentage in `[0, MAX_PERCENT]` for every field the answers give
 * positive evidence for.
 *
 * This is the single source of truth for the percentage a result card shows,
 * and the exact counterpart of `OrientationEngine.matchPercentByField`. Fields
 * the answers actively pushed away (negative weight only, e.g. "I would never
 * do sales") are not recommendations and are left out.
 */
export function matchPercentByField(answers: Answers): Map<string, number> {
  const { weights, attainable } = weigh(answers);
  const percents = new Map<string, number>();
  for (const [fieldId, weight] of weights) {
    if (weight <= 0) continue;
    percents.set(fieldId, percentOf(weight, attainable));
  }
  return percents;
}

/**
 * Comparator putting the best match first.
 *
 * Ranking key is the percentage. AI resilience (when the student asked for an
 * AI-resilient career) and then the field id only break exact ties: ranking on
 * resilience first used to surface a weaker match above a stronger one, putting
 * the "best match" badge on the wrong card.
 */
export function compareScoredFields(
  prioritizeIaResilience: boolean,
): (left: ScoredField, right: ScoredField) => number {
  return (left, right) => {
    const byScore = right.score - left.score;
    if (byScore !== 0) return byScore;
    if (prioritizeIaResilience) {
      const byResilience = iaRankOf(right.fieldId) - iaRankOf(left.fieldId);
      if (byResilience !== 0) return byResilience;
    }
    if (left.fieldId === right.fieldId) return 0;
    return left.fieldId < right.fieldId ? -1 : 1;
  };
}

/** True when the student asked for an AI-resilient career. */
export function prioritizesIaResilience(answers: Answers): boolean {
  const selected = answers.ai_concern;
  return Array.isArray(selected) && selected.includes('ai_yes');
}

/**
 * Top 5 fields for `answers`, best match first, each with its normalised
 * percentage.
 */
export function scoreOrientationAnswers(
  answers: Answers,
  options?: { prioritizeIaResilience?: boolean; declaredFieldIds?: string[] },
): ScoredField[] {
  let scores: ScoredField[] = Array.from(
    matchPercentByField(answers),
    ([fieldId, score]) => ({ fieldId, score }),
  );

  const declaredFieldIds = options?.declaredFieldIds ?? [];
  if (scores.length === 0 && declaredFieldIds.length > 0) {
    scores = Array.from(new Set(declaredFieldIds), (fieldId) => ({
      fieldId,
      score: DECLARED_INTEREST_PERCENT,
    }));
  }

  scores.sort(compareScoredFields(options?.prioritizeIaResilience ?? false));

  // Unknown ids (a stale field declared in a profile) take a slot then drop
  // out, as they do in the Dart engine.
  return scores
    .slice(0, 5)
    .filter((entry) => ORIENTATION_FIELD_BY_ID.has(entry.fieldId));
}

/**
 * Re-reads the percentage of an already-scored recommendation.
 *
 * Sessions persisted before the normalisation fix hold `rawPoints * 10` (up to
 * 260) with a 55 floor, so their stored `score` is not a percentage at all.
 * Re-scoring from the stored answers puts every session — old or new — on the
 * one normalised scale; a session whose field cannot be re-scored falls back to
 * its stored score clamped into `[0, 100]`.
 */
export function normalizeStoredScore(
  fieldId: string,
  storedScore: unknown,
  percentByField: Map<string, number>,
): number {
  const recomputed = percentByField.get(fieldId);
  if (recomputed !== undefined) return recomputed;
  if (typeof storedScore !== 'number' || !Number.isFinite(storedScore)) return 0;
  return Math.min(100, Math.max(0, Math.round(storedScore)));
}
