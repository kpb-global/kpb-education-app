import { Injectable } from '@nestjs/common';

import {
  ConsulateFetcher,
  ConsulateFetchResult,
} from '../visa-availability.interface';

/**
 * France — TLScontact, Dakar.
 *
 * ⚠ LEGAL REVIEW REQUIRED — vendor: TLScontact
 *   Same TLScontact CGU §7 constraints as france-abidjan. Dakar additionally
 *   serves as the regional hub for Mali applicants during periods when the
 *   Bamako centre is closed — capacity signal here is especially valuable
 *   but also especially TOS-sensitive.
 *
 * Source URL:
 *   https://fr.tlscontact.com/sn/DKR/page.php?pid=news
 *
 * TODO(legal-clearance): prefer partnership with Ambassade de France.
 */
@Injectable()
export class FranceDakarFetcher implements ConsulateFetcher {
  readonly consulateCode = 'france-dakar';
  readonly countryCode = 'FR';
  readonly city = 'Dakar';
  readonly displayName = 'France — TLScontact Dakar';
  readonly vendor = 'tlscontact' as const;
  readonly sourceUrl = 'https://fr.tlscontact.com/sn/DKR/page.php?pid=news';
  readonly reviewStatus = 'not-started' as const;

  async fetch(): Promise<ConsulateFetchResult> {
    // TODO(legal-clearance): prefer partnership with Ambassade de France.
    return { status: 'unknown' };
  }
}
