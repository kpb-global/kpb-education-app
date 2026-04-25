import { Injectable } from '@nestjs/common';

import {
  ScholarshipScraper,
  ScrapedScholarship,
} from '../scholarship-source.interface';

/**
 * Chinese MOFCOM / CSC — Ministry of Commerce and China Scholarship Council
 * scholarships, typically announced via each country's Chinese embassy
 * channels and the CSC portal.
 *
 * Sources:
 *   - https://www.campuschina.org (CSC index)
 *   - Per-country embassy pages (CI, SN, ML, BF, BJ, TG)
 *
 * REVIEW_STATUS: not-started
 *   Deferred — multi-source, each embassy publishes on its own schedule;
 *   requires per-country scraper functions and careful deadline parsing
 *   (mix of Gregorian and Lunar dates in some announcements).
 */
@Injectable()
export class ChineseMofcomScraper implements ScholarshipScraper {
  readonly prefix = 'chinese-mofcom';
  readonly name = 'Chinese MOFCOM / CSC';

  async fetch(): Promise<ScrapedScholarship[]> {
    // TODO: https://www.campuschina.org
    return [];
  }
}
