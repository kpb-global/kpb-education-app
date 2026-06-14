import { Injectable } from '@nestjs/common';

import {
  ScholarshipScraper,
  ScrapedScholarship,
} from '../scholarship-source.interface';

/**
 * Türkiye Bursları — Turkish government scholarships, significant uptake
 * across francophone West Africa (especially Côte d'Ivoire and Sénégal).
 *
 * Source: https://www.turkiyeburslari.gov.tr/en/ (EN + TR)
 *
 * REVIEW_STATUS: not-started
 *   Scraper deferred — structure + legal review pending.
 */
@Injectable()
export class TurkiyeBurslariScraper implements ScholarshipScraper {
  readonly prefix = 'turkiye-burslari';
  readonly name = 'Türkiye Bursları';

  async fetch(): Promise<ScrapedScholarship[]> {
    // TODO: https://www.turkiyeburslari.gov.tr/en/
    return [];
  }
}
