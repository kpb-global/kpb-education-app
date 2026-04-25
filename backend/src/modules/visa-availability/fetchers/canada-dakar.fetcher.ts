import { Injectable } from '@nestjs/common';

import {
  ConsulateFetcher,
  ConsulateFetchResult,
} from '../visa-availability.interface';

/**
 * Canada — VFS Global, Dakar (serves SN, ML, BF, GM, CV, GW, MR).
 *
 * ⚠ LEGAL REVIEW REQUIRED — vendor: VFS Global
 *   Same TOS constraints as canada-abidjan: VFS Terms §3.2 bars automated
 *   retrieval. See canada-abidjan.fetcher.ts for the full review checklist.
 *
 * Source URL:
 *   https://visa.vfsglobal.com/sen/fr/can/book-an-appointment
 *
 * TODO(legal-clearance): implement once VFS TOS exemption is confirmed.
 */
@Injectable()
export class CanadaDakarFetcher implements ConsulateFetcher {
  readonly consulateCode = 'canada-dakar';
  readonly countryCode = 'CA';
  readonly city = 'Dakar';
  readonly displayName = 'Canada — VFS Dakar';
  readonly vendor = 'vfs-global' as const;
  readonly sourceUrl = 'https://visa.vfsglobal.com/sen/fr/can/book-an-appointment';
  readonly reviewStatus = 'not-started' as const;

  async fetch(): Promise<ConsulateFetchResult> {
    // TODO(legal-clearance): implement once VFS TOS exemption is confirmed.
    return { status: 'unknown' };
  }
}
