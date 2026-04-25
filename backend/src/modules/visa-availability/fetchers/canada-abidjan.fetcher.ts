import { Injectable } from '@nestjs/common';

import {
  ConsulateFetcher,
  ConsulateFetchResult,
} from '../visa-availability.interface';

/**
 * Canada — VFS Global, Abidjan (serves CI, TG, BJ).
 *
 * ⚠ LEGAL REVIEW REQUIRED — vendor: VFS Global
 *   VFS Global's standard Terms of Use (https://visa.vfsglobal.com/one-pager-terms)
 *   §3.2 explicitly prohibits automated retrieval. Polling must not be
 *   enabled without either (a) a partner agreement with VFS, or (b) written
 *   legal opinion confirming our narrow read-only availability signal
 *   qualifies under an exemption. GDPR DPIA must be completed regardless.
 *
 * Source URL (public availability widget, last verified April 2026):
 *   https://visa.vfsglobal.com/civ/fr/can/book-an-appointment
 *
 * TODO(legal-clearance): when cleared, replace stub with real fetch.
 */
@Injectable()
export class CanadaAbidjanFetcher implements ConsulateFetcher {
  readonly consulateCode = 'canada-abidjan';
  readonly countryCode = 'CA';
  readonly city = 'Abidjan';
  readonly displayName = 'Canada — VFS Abidjan';
  readonly vendor = 'vfs-global' as const;
  readonly sourceUrl = 'https://visa.vfsglobal.com/civ/fr/can/book-an-appointment';
  readonly reviewStatus = 'not-started' as const;

  async fetch(): Promise<ConsulateFetchResult> {
    // TODO(legal-clearance): implement once VFS TOS exemption is confirmed.
    return { status: 'unknown' };
  }
}
