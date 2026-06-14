import { Injectable } from '@nestjs/common';

import {
  ScholarshipScraper,
  ScrapedScholarship,
} from '../scholarship-source.interface';

/**
 * Algeria — Ministère de l'Enseignement Supérieur et de la Recherche
 * Scientifique. Publishes annual quotas for sub-Saharan African students
 * via cooperation agreements.
 *
 * Source: https://www.mesrs.dz (FR + AR)
 *
 * REVIEW_STATUS: not-started
 *   Deferred — announcements are typically in PDF circulars; parsing approach
 *   similar to Tunisia (PDF-text pipeline required).
 */
@Injectable()
export class AlgeriaScraper implements ScholarshipScraper {
  readonly prefix = 'algeria';
  readonly name = 'Algeria MESRS';

  async fetch(): Promise<ScrapedScholarship[]> {
    // TODO: https://www.mesrs.dz
    return [];
  }
}
