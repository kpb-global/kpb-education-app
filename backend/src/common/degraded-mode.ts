import { HttpException, HttpStatus } from '@nestjs/common';

/**
 * Shared degraded-mode policy for every module that could otherwise substitute
 * the bundled demo fixtures (`src/common/data/mock-catalog.ts`) for real
 * database rows. Extracted from `modules/catalog/catalog-degraded-mode.ts`
 * (the reference fix for the "invented scholarships served in production"
 * incident) so the matches module applies the exact same rules instead of
 * duplicating them.
 */

/**
 * Where the rows in an envelope actually come from.
 *
 * `database` is the only trustworthy value: it means the rows were read from
 * Postgres. `mock` means the API answered with the bundled demo fixtures from
 * `src/common/data/mock-catalog.ts` because the database was unreachable.
 *
 * The field is part of the public envelope on purpose. Before it existed, a
 * production device could not tell a real scholarship from a fixture, and two
 * demo cards ("Bourse McCall MacBain", "Programme Mastercard Foundation
 * Scholars") reached real users and were cached as if they were real.
 */
export type CatalogSource = 'database' | 'mock';

export const CATALOG_SOURCE_DATABASE: CatalogSource = 'database';
export const CATALOG_SOURCE_MOCK: CatalogSource = 'mock';

type Env = Record<string, string | undefined>;

/** True when the process runs under the production profile. */
export function isProductionRuntime(env: Env = process.env): boolean {
  return (env.NODE_ENV ?? '').trim().toLowerCase() === 'production';
}

/**
 * Whether this process is allowed to answer with `mock-catalog.ts` fixtures
 * when the database is unreachable. One flag governs every consumer of those
 * fixtures (catalog lists AND match scoring): a process either may fall back
 * to demo data or it may not.
 *
 * Rules, in order:
 *  1. **Never in production.** There is no opt-in: a fixture served to a real
 *     user is a data-integrity incident (fake scholarship names, ids that
 *     resolve to nothing, cached client-side for weeks). Production answers
 *     503 with an explicit code instead, which the app can render honestly.
 *  2. Outside production the fallback stays on by default, because working on
 *     the Flutter app without a local Postgres is a normal, useful setup.
 *  3. `KPB_CATALOG_MOCK_FALLBACK=0|false|off` turns it off anywhere, so CI and
 *     staging can assert on the real "service unavailable" behaviour.
 */
export function isMockCatalogFallbackAllowed(env: Env = process.env): boolean {
  if (isProductionRuntime(env)) return false;
  const flag = (env.KPB_CATALOG_MOCK_FALLBACK ?? '').trim().toLowerCase();
  return !(flag === '0' || flag === 'false' || flag === 'off' || flag === 'no');
}

/**
 * 503 returned instead of fixtures. Body shape matches the other KPB domain
 * errors (`{ code, message, details }`) so the app can branch on `code`.
 */
export function degradedServiceUnavailable(
  code: string,
  message: string,
  resource: string,
): HttpException {
  return new HttpException(
    { code, message, details: { resource } },
    HttpStatus.SERVICE_UNAVAILABLE,
  );
}
