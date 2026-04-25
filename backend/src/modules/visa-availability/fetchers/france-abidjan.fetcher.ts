import { Injectable } from '@nestjs/common';

import {
  ConsulateFetcher,
  ConsulateFetchResult,
} from '../visa-availability.interface';

/**
 * France — TLScontact, Abidjan.
 *
 * ⚠ LEGAL REVIEW REQUIRED — vendor: TLScontact (Teleperformance group)
 *   TLScontact CGU (https://fr.tlscontact.com/mentionslegales) §7 prohibits
 *   "tout usage automatisé". Additionally, France-Visas is a French State
 *   service — unsolicited automated queries may implicate the LCEN and the
 *   Loi Informatique et Libertés. Legal must confirm the narrow use-case
 *   (publish "slots within N weeks" to students) does not constitute
 *   "extraction répétée et systématique" under Art. L.342-1 CPI.
 *
 *   Preferred path: approach the Ambassade de France — Abidjan directly
 *   for an official data-sharing arrangement. They have historically been
 *   receptive to education-sector partners.
 *
 * Source URL:
 *   https://fr.tlscontact.com/ci/ABJ/page.php?pid=news
 *
 * TODO(legal-clearance): prefer partnership route over scraping.
 */
@Injectable()
export class FranceAbidjanFetcher implements ConsulateFetcher {
  readonly consulateCode = 'france-abidjan';
  readonly countryCode = 'FR';
  readonly city = 'Abidjan';
  readonly displayName = 'France — TLScontact Abidjan';
  readonly vendor = 'tlscontact' as const;
  readonly sourceUrl = 'https://fr.tlscontact.com/ci/ABJ/page.php?pid=news';
  readonly reviewStatus = 'not-started' as const;

  async fetch(): Promise<ConsulateFetchResult> {
    // TODO(legal-clearance): prefer partnership with Ambassade de France.
    return { status: 'unknown' };
  }
}
