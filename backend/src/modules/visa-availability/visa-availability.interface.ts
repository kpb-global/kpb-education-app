/**
 * Contract for a per-consulate visa-availability fetcher.
 *
 * ─────────────────────────────────────────────────────────────────────────────
 *  ⚠ LEGAL REVIEW REQUIRED BEFORE ENABLING ANY FETCHER
 * ─────────────────────────────────────────────────────────────────────────────
 *
 * Consulate appointment systems are almost universally operated by third-
 * party vendors (TLScontact, VFS Global, iData, BLS, …) whose Conditions
 * d'utilisation explicitly prohibit automated access. Before a fetcher is
 * moved off stub status, the business owner must:
 *
 *   1. CONDITIONS D'UTILISATION REVIEW
 *      Retrieve the per-vendor CGU / Terms of Use and confirm in writing
 *      whether unauthenticated availability polling is permitted. If the
 *      vendor requires a partner / API agreement, negotiate that first.
 *
 *   2. GDPR IMPACT ASSESSMENT
 *      Even public availability pages can leak inferable information when
 *      stored (e.g. rate-of-appointment-fill correlated to applicant
 *      nationality). If a fetcher requires session cookies, headers tied
 *      to individual accounts, or anything that could attach to a data
 *      subject, a full DPIA is mandatory under RGPD Art. 35 — we are
 *      currently under CNIL francophone jurisdiction in all target markets.
 *
 *   3. ROBOTS + RATE LIMITS
 *      Respect `robots.txt` and set a conservative ceiling (≤ 1 request
 *      per consulate per 6 h cron tick). Identify ourselves via User-Agent
 *      with an honest contact email so vendors can reach us before
 *      blocking.
 *
 * Until a fetcher is cleared, its `fetch()` MUST return `{ status: 'unknown' }`
 * and perform no network I/O. A fetcher that calls out while its
 * `reviewStatus` is anything other than `'cleared'` is a compliance bug.
 */

export type VisaAvailabilityStatus = 'available' | 'full' | 'unknown' | 'error';

export type ConsulateFetchResult = {
  status: VisaAvailabilityStatus;
  nextAvailableAt?: Date | null;
  soonestSlot?: string | null;
  errorMessage?: string | null;
};

export interface ConsulateFetcher {
  /** Stable slug used as the DB primary identifier. */
  readonly consulateCode: string;
  /** ISO 3166-1 alpha-2 of the destination country. */
  readonly countryCode: string;
  /** City the appointment centre sits in (Abidjan, Dakar, …). */
  readonly city: string;
  /** Human-readable label for admin UI / logs. */
  readonly displayName: string;
  /** Vendor / platform that runs the booking system. */
  readonly vendor: 'tlscontact' | 'vfs-global' | 'france-visas' | 'idata' | 'bls' | 'unknown';
  /** Upstream URL — noted in logs + visible in admin UI. */
  readonly sourceUrl: string;
  /** Legal-review gate. Never call fetch() with a non-cleared state. */
  readonly reviewStatus: 'not-started' | 'pending-legal' | 'pending-dpia' | 'cleared';
  /**
   * Perform one check. Implementations MUST short-circuit to
   * `{ status: 'unknown' }` when `reviewStatus !== 'cleared'`. The service
   * double-checks this, but the fetcher is still the primary gatekeeper.
   */
  fetch(): Promise<ConsulateFetchResult>;
}
