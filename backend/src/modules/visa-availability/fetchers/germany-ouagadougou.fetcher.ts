import { Injectable } from '@nestjs/common';

import {
  ConsulateFetcher,
  ConsulateFetchResult,
} from '../visa-availability.interface';

/**
 * Germany — Auswärtiges Amt / iData booking system, Ouagadougou (serves
 * BF, TG, NE when the Niamey post is closed).
 *
 * ⚠ LEGAL REVIEW REQUIRED — vendor: iData (operated for Auswärtiges Amt)
 *   iData's Terms of Service (service2.diplo.de/rktermin) are less
 *   restrictive than VFS/TLS — they permit public availability queries
 *   in a read-only capacity. Nonetheless a DPIA is required because the
 *   booking system sets session cookies that could arguably track our
 *   polling pattern back to a data subject.
 *
 *   Preferred approach: the Deutsche Botschaft Ouagadougou maintains an
 *   "aktuelle Wartezeiten" page that is plainly public — scrape that
 *   instead of the booking widget whenever possible.
 *
 * Source URL:
 *   https://ouagadougou.diplo.de/bf-fr/service/visa
 *   (booking system:
 *    https://service2.diplo.de/rktermin/extern/choose_realmList.do?locationCode=ouag)
 *
 * TODO(legal-clearance): scrape the Wartezeiten page, not the booking widget.
 */
@Injectable()
export class GermanyOuagadougouFetcher implements ConsulateFetcher {
  readonly consulateCode = 'germany-ouagadougou';
  readonly countryCode = 'DE';
  readonly city = 'Ouagadougou';
  readonly displayName = 'Germany — Deutsche Botschaft Ouagadougou';
  readonly vendor = 'idata' as const;
  readonly sourceUrl = 'https://ouagadougou.diplo.de/bf-fr/service/visa';
  readonly reviewStatus = 'not-started' as const;

  async fetch(): Promise<ConsulateFetchResult> {
    // TODO(legal-clearance): parse the public Wartezeiten page.
    return { status: 'unknown' };
  }
}
