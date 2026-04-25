import { Injectable } from '@nestjs/common';

import {
  ConsulateFetcher,
  ConsulateFetchResult,
} from '../visa-availability.interface';

/**
 * France — TLScontact, Bamako.
 *
 * ⚠ LEGAL REVIEW REQUIRED — vendor: TLScontact
 *   Same TLScontact constraints as other FR consulates. Bamako has had
 *   intermittent closures since 2022; the service should treat long
 *   stretches of `status: 'error'` as expected and not alert spam.
 *
 * Source URL:
 *   https://fr.tlscontact.com/ml/BKO/page.php?pid=news
 *
 * TODO(legal-clearance): prefer partnership with Ambassade de France.
 */
@Injectable()
export class FranceBamakoFetcher implements ConsulateFetcher {
  readonly consulateCode = 'france-bamako';
  readonly countryCode = 'FR';
  readonly city = 'Bamako';
  readonly displayName = 'France — TLScontact Bamako';
  readonly vendor = 'tlscontact' as const;
  readonly sourceUrl = 'https://fr.tlscontact.com/ml/BKO/page.php?pid=news';
  readonly reviewStatus = 'not-started' as const;

  async fetch(): Promise<ConsulateFetchResult> {
    // TODO(legal-clearance): prefer partnership with Ambassade de France.
    return { status: 'unknown' };
  }
}
