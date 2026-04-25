/**
 * Contract for a scholarship-index scraper.
 *
 * Scrapers are pure: they fetch/parse the source, return a typed list, and
 * never touch the database. The service does upsert + deactivation.
 *
 * ── LEGAL REVIEW REQUIRED ───────────────────────────────────────────────────
 * Each source's Terms of Service must be reviewed before enabling its scraper
 * in production. Some (notably Campus France) explicitly forbid automated
 * access in their TOU; others have robots.txt signals. Until a source has
 * been cleared by counsel, keep its fetch() stubbed out and mark the file
 * with a `REVIEW_STATUS: pending-legal` banner.
 */
export interface ScholarshipScraper {
  /** Stable identifier used as the sourceKey prefix for this scraper. */
  readonly prefix: string;

  /**
   * Human-readable name — used in logs and the admin-trigger response so the
   * operator can see which sources ran successfully.
   */
  readonly name: string;

  /**
   * Fetch + parse the upstream index. Returns [] on any parse error rather
   * than throwing — a single flaky source shouldn't break the whole weekly
   * refresh. The service logs partial failures.
   */
  fetch(): Promise<ScrapedScholarship[]>;
}

export type ScrapedScholarship = {
  /** MUST start with `${scraper.prefix}-` — enforced by the service. */
  sourceKey: string;
  nameFr: string;
  nameEn: string;
  /** FK to Country.id. Unknown countries should resolve to a fallback id. */
  countryId: string;
  /** Null if the source doesn't publish an explicit deadline date. */
  deadlineAt: Date | null;
  /** URL a student would visit to apply. */
  applicationUrl: string;
  /** Canonical source page for admins to verify the listing. */
  sourceUrl?: string;
  /** Freeform labels: ["masters", "fully-funded", "africa-priority", …]. */
  tags: string[];
};
