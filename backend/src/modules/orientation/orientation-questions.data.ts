/**
 * Server-side mirror of the questionnaire the mobile app scores locally.
 *
 * The client and the server must publish the *same* match percentage for the
 * same answers: a student who submits online (the default path — the app's
 * `AppConfig.enableRemoteSync` is true) and one who submits offline both see
 * the number computed from this table. It is therefore a byte-for-byte port of
 * the Flutter tables, and must be kept in sync with them:
 *
 *   - `lib/app/core/data/mock_catalog/orientation_data.dart`
 *     (questions 1–5: interests, strengths, goal, environment, level)
 *   - `lib/app/core/data/orientation_questions_m4.dart`
 *     (questions 6–10: ai_concern, languages, avoid, budget_band, mobility)
 *
 * Question order, option order and the key order inside `weights` all mirror
 * the Dart declarations on purpose: the scorer accumulates floating-point
 * weights in iteration order, so the same order guarantees bit-identical sums
 * on both sides.
 *
 * Labels/prompts are deliberately absent — the app ships the wording (and its
 * translations) locally; the backend only needs the ids and their weights.
 */
export type OrientationOptionMeta = {
  id: string;
  /** Points added to each field id when the student picks this option. */
  weights: Record<string, number>;
};

export type OrientationQuestionMeta = {
  id: string;
  multiSelect: boolean;
  options: OrientationOptionMeta[];
};

export const ORIENTATION_QUESTIONS: OrientationQuestionMeta[] = [
  {
    id: 'interests',
    multiSelect: true,
    options: [
      { id: 'tech', weights: { d01: 4, d05: 3 } },
      { id: 'biz', weights: { d02: 4, d03: 3 } },
      { id: 'health', weights: { d04: 4, d09: 1 } },
      { id: 'law_pol', weights: { d07: 4, d09: 2 } },
      { id: 'create', weights: { d06: 4, d11: 2 } },
      { id: 'env', weights: { d08: 4, d10: 3 } },
    ],
  },
  {
    id: 'strengths',
    multiSelect: false,
    options: [
      { id: 'analysis', weights: { d01: 4, d03: 4, d05: 3 } },
      { id: 'communication', weights: { d06: 4, d02: 3, d07: 2 } },
      { id: 'care', weights: { d04: 4, d09: 3 } },
      { id: 'creativity', weights: { d06: 4, d11: 3 } },
      { id: 'leadership', weights: { d02: 4, d05: 2 } },
    ],
  },
  {
    id: 'goal',
    multiSelect: false,
    options: [
      { id: 'global_job', weights: { d01: 3, d02: 3, d03: 4 } },
      { id: 'impact', weights: { d04: 4, d07: 3, d08: 3 } },
      { id: 'entrepreneur', weights: { d02: 4, d06: 2, d12: 2 } },
      { id: 'research', weights: { d09: 4, d05: 3, d04: 2 } },
    ],
  },
  {
    id: 'environment',
    multiSelect: false,
    options: [
      { id: 'office', weights: { d01: 3, d02: 3, d03: 4 } },
      { id: 'field', weights: { d05: 3, d08: 4, d10: 3 } },
      { id: 'hospital', weights: { d04: 5 } },
      { id: 'studio', weights: { d06: 4, d11: 3 } },
      { id: 'intl', weights: { d02: 2, d07: 3, d12: 4 } },
    ],
  },
  {
    id: 'level',
    multiSelect: false,
    options: [
      { id: 'bac3', weights: { d02: 2, d06: 2, d12: 2, d03: 1 } },
      { id: 'bac5', weights: { d01: 2, d02: 2, d03: 2, d07: 2 } },
      { id: 'bac8', weights: { d04: 3, d05: 2, d09: 3 } },
    ],
  },
  {
    id: 'ai_concern',
    multiSelect: false,
    options: [
      { id: 'ai_yes', weights: { d01: 3, d03: 3, d04: 2, d07: 2 } },
      { id: 'ai_no', weights: { d10: 2, d06: 1 } },
    ],
  },
  {
    id: 'languages',
    multiSelect: false,
    options: [
      { id: 'lang_en', weights: { d01: 3, d02: 2, d03: 2, d07: 2 } },
      { id: 'lang_fr', weights: { d02: 2, d04: 2, d09: 2 } },
      { id: 'lang_both', weights: { d02: 2, d01: 2, d07: 2 } },
    ],
  },
  {
    // "What would you definitely NOT do" — subtractive only.
    id: 'avoid',
    multiSelect: false,
    options: [
      { id: 'avoid_sales', weights: { d02: -2 } },
      { id: 'avoid_lab', weights: { d04: -2, d03: -1 } },
      { id: 'avoid_desk', weights: { d01: -1, d02: -1 } },
    ],
  },
  {
    id: 'budget_band',
    multiSelect: false,
    options: [
      { id: 'budget_low', weights: { d09: 2, d08: 2, d12: 2 } },
      { id: 'budget_mid', weights: { d02: 2, d06: 2, d03: 1 } },
      { id: 'budget_high', weights: { d01: 2, d04: 2, d07: 2 } },
    ],
  },
  {
    id: 'mobility',
    multiSelect: false,
    options: [
      { id: 'mobility_yes', weights: { d07: 2, d12: 2, d02: 1 } },
      { id: 'mobility_maybe', weights: { d02: 1, d09: 1 } },
      { id: 'mobility_no', weights: { d09: 2, d10: 1 } },
    ],
  },
];
