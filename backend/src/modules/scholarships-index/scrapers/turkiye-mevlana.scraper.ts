import { Injectable } from '@nestjs/common';

import {
  ScholarshipScraper,
  ScrapedScholarship,
} from '../scholarship-source.interface';

/**
 * Türkiye — Mevlana Exchange Programme. Separate from Türkiye Bursları
 * (which is full-funding, undergrad + postgrad): Mevlana targets exchange
 * semesters between Turkish universities and partners abroad.
 *
 * Source: https://mevlana.yok.gov.tr
 *
 * REVIEW_STATUS: not-started
 *   Deferred — niche programme; enable only after Bursları scraper ships and
 *   we validate demand in-app.
 */
@Injectable()
export class TurkiyeMevlanaScraper implements ScholarshipScraper {
  readonly prefix = 'turkiye-mevlana';
  readonly name = 'Türkiye — Mevlana Exchange';

  async fetch(): Promise<ScrapedScholarship[]> {
    // TODO: https://mevlana.yok.gov.tr
    return [];
  }
}
