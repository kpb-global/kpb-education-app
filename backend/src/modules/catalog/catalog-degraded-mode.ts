import type { HttpException } from '@nestjs/common';

import { degradedServiceUnavailable } from '../../common/degraded-mode';

/**
 * Catalog-facing façade over the shared degraded-mode policy.
 *
 * The rules themselves live in `src/common/degraded-mode.ts` so that every
 * consumer of the `mock-catalog.ts` fixtures (catalog lists AND match scoring)
 * applies the exact same "never fixtures in production" policy. This file only
 * keeps the catalog's historical import path and its domain error code.
 */
export {
  CATALOG_SOURCE_DATABASE,
  CATALOG_SOURCE_MOCK,
  isMockCatalogFallbackAllowed,
  isProductionRuntime,
  type CatalogSource,
} from '../../common/degraded-mode';

/**
 * 503 returned instead of fixtures. Body shape matches the other KPB domain
 * errors (`{ code, message, details }`) so the app can branch on `code`.
 */
export function catalogUnavailable(resource: string): HttpException {
  return degradedServiceUnavailable(
    'CATALOG_UNAVAILABLE',
    'The catalog is temporarily unavailable.',
    resource,
  );
}
