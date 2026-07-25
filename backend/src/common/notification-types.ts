// ─────────────────────────────────────────────────────────────────────────────
// Per-type notification opt-outs (KPB-169).
//
// Each recurring, non-transactional notification family is one stable key,
// stored in `UserProfile.disabledNotificationTypes`. The keys are deliberately
// the same strings as the dispatch `kind` — one vocabulary for the feed, the
// analytics and the preference screen.
//
// This replaces the per-type boolean columns (`dailyScholarshipOptOut`,
// `weeklyDigestOptOut`): a third type was the point at which one column per
// preference stopped scaling. Adding a fourth family is now a one-line change
// here plus a label in the app — no migration.
//
// Opting out of one family NEVER silences another, and never silences
// transactional notifications (deadlines, dossier updates, messages).
// ─────────────────────────────────────────────────────────────────────────────

export const NOTIFICATION_OPT_OUT_TYPES = [
  'daily_scholarship', // KPB-162 — "Bourse du jour", 19h local.
  'weekly_digest', // KPB-163 — Monday 08h local recap (push + email).
  'parcours_weekly', // KPB-169 — Sunday 18h local "récit de la semaine".
] as const;

export type NotificationOptOutType = (typeof NOTIFICATION_OPT_OUT_TYPES)[number];

/** Keeps unknown/legacy strings out of the column. Order is not significant, so
 *  the result is sorted and deduped to make stored values comparable. */
export function sanitizeOptOutTypes(raw: unknown): NotificationOptOutType[] {
  if (!Array.isArray(raw)) return [];
  const allowed = new Set<string>(NOTIFICATION_OPT_OUT_TYPES);
  return [...new Set(raw.filter((v): v is string => typeof v === 'string'))]
    .filter((v): v is NotificationOptOutType => allowed.has(v))
    .sort();
}

/** Applies a single `{ type, optOut }` change to an existing list. */
export function withOptOut(
  current: readonly string[],
  type: NotificationOptOutType,
  optOut: boolean,
): NotificationOptOutType[] {
  const next = new Set(sanitizeOptOutTypes([...current]));
  if (optOut) next.add(type);
  else next.delete(type);
  return [...next].sort();
}
