import { ORIENTATION_FIELD_BY_ID } from './orientation-fields.data';

type Answers = Record<string, string[]>;

const OPTION_WEIGHTS: Record<string, Record<string, number>> = {
  tech: { d01: 4, d05: 3 },
  biz: { d02: 4, d03: 3 },
  health: { d04: 4, d09: 1 },
  law_pol: { d07: 4, d09: 2 },
  create: { d06: 4, d11: 2 },
  env: { d08: 4, d10: 3 },
  analysis: { d01: 4, d03: 4, d05: 3 },
  communication: { d06: 4, d02: 3, d07: 2 },
  care: { d04: 4, d09: 3 },
  creativity: { d06: 4, d11: 3 },
  leadership: { d02: 4, d05: 2 },
  global_job: { d01: 3, d02: 3, d03: 4 },
  impact: { d04: 4, d07: 3, d08: 3 },
  entrepreneur: { d02: 4, d06: 2, d12: 2 },
  research: { d09: 4, d05: 3, d04: 2 },
  office: { d01: 3, d02: 3, d03: 4 },
  field: { d05: 3, d08: 4, d10: 3 },
  hospital: { d04: 5 },
  studio: { d06: 4, d11: 3 },
  intl: { d02: 2, d07: 3, d12: 4 },
  bac3: { d02: 2, d06: 2, d12: 2, d03: 1 },
  bac5: { d01: 2, d02: 2, d03: 2, d07: 2 },
  bac8: { d04: 3, d05: 2, d09: 3 },
  ai_yes: { d01: 3, d03: 3, d04: 2, d07: 2 },
  ai_no: { d10: 2, d06: 1 },
  lang_en: { d01: 3, d02: 2, d03: 2, d07: 2 },
  lang_fr: { d02: 2, d04: 2, d09: 2 },
  lang_both: { d02: 2, d01: 2, d07: 2 },
  avoid_sales: { d02: -2 },
  avoid_lab: { d04: -2, d03: -1 },
  avoid_desk: { d01: -1, d02: -1 },
};

const IA_RESILIENCE_RANK = { high: 3, medium: 2, low: 1 } as const;

export function scoreOrientationAnswers(
  answers: Answers,
  options?: { prioritizeIaResilience?: boolean },
): Array<{ fieldId: string; score: number }> {
  const scores = new Map<string, number>();

  for (const selected of Object.values(answers)) {
    for (const optionId of selected) {
      const weights = OPTION_WEIGHTS[optionId];
      if (!weights) continue;
      for (const [fieldId, weight] of Object.entries(weights)) {
        scores.set(fieldId, (scores.get(fieldId) ?? 0) + weight);
      }
    }
  }

  let ranked = Array.from(scores.entries())
    .filter(([, score]) => score > 0)
    .map(([fieldId, score]) => ({ fieldId, score: score * 10 }));

  if (options?.prioritizeIaResilience) {
    ranked = ranked.sort((left, right) => {
      const leftMeta = ORIENTATION_FIELD_BY_ID.get(left.fieldId);
      const rightMeta = ORIENTATION_FIELD_BY_ID.get(right.fieldId);
      const resilienceCmp =
        (IA_RESILIENCE_RANK[rightMeta?.iaResilience ?? 'medium'] ?? 0) -
        (IA_RESILIENCE_RANK[leftMeta?.iaResilience ?? 'medium'] ?? 0);
      if (resilienceCmp !== 0) return resilienceCmp;
      return right.score - left.score;
    });
  } else {
    ranked.sort((left, right) => right.score - left.score);
  }

  return ranked.slice(0, 5);
}
