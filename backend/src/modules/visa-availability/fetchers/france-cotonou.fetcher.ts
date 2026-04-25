import { Injectable } from '@nestjs/common';

import {
  ConsulateFetcher,
  ConsulateFetchResult,
} from '../visa-availability.interface';

/**
 * France — Capago (historically) / TLScontact, Cotonou.
 *
 * ⚠ LEGAL REVIEW REQUIRED
 *   Cotonou has migrated vendors multiple times (Capago → TLScontact).
 *   Verify the current vendor before any technical work, and apply the
 *   same CGU / DPIA gate as other France consulates.
 *
 * Source URL:
 *   https://fr.tlscontact.com/bj/COO/page.php?pid=news
 *   (fallback to Ambassade de France — Cotonou site if vendor changes.)
 *
 * TODO(legal-clearance): verify current vendor + pursue partnership.
 */
@Injectable()
export class FranceCotonouFetcher implements ConsulateFetcher {
  readonly consulateCode = 'france-cotonou';
  readonly countryCode = 'FR';
  readonly city = 'Cotonou';
  readonly displayName = 'France — TLScontact Cotonou';
  readonly vendor = 'tlscontact' as const;
  readonly sourceUrl = 'https://fr.tlscontact.com/bj/COO/page.php?pid=news';
  readonly reviewStatus = 'not-started' as const;

  async fetch(): Promise<ConsulateFetchResult> {
    // TODO(legal-clearance): verify current vendor then implement.
    return { status: 'unknown' };
  }
}
