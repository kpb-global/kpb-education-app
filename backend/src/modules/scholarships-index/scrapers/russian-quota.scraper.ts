import { Injectable } from '@nestjs/common';

import {
  ScholarshipScraper,
  ScrapedScholarship,
} from '../scholarship-source.interface';

/**
 * Russian government quota (Rossotrudnichestvo / Russia Education) — free
 * tuition slots allocated to African students through the "Education in
 * Russia" portal.
 *
 * Source: https://education-in-russia.com
 *
 * REVIEW_STATUS: not-started
 *   Deferred — sanctions landscape as of 2026 means this source is lower
 *   priority until business confirms whether we should surface Russian
 *   scholarships at all given payment-rail and safety considerations for
 *   students.
 */
@Injectable()
export class RussianQuotaScraper implements ScholarshipScraper {
  readonly prefix = 'russian-quota';
  readonly name = 'Russian Government Quota';

  async fetch(): Promise<ScrapedScholarship[]> {
    // TODO: https://education-in-russia.com
    return [];
  }
}
