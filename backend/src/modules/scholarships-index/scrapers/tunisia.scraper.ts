import { Injectable } from '@nestjs/common';

import {
  ScholarshipScraper,
  ScrapedScholarship,
} from '../scholarship-source.interface';

/**
 * Tunisia — Ministère de l'Enseignement Supérieur et de la Recherche
 * Scientifique (MESRS) + Office des Tunisiens à l'Étranger exchange
 * programmes.
 *
 * Sources:
 *   - http://www.mes.tn (FR + AR)
 *   - https://www.ote.nat.tn
 *
 * REVIEW_STATUS: not-started
 *   Deferred — site structure is legacy ASP + PDFs; extraction likely needs
 *   a PDF-text pipeline rather than HTML parsing.
 */
@Injectable()
export class TunisiaScraper implements ScholarshipScraper {
  readonly prefix = 'tunisia';
  readonly name = 'Tunisia MESRS';

  async fetch(): Promise<ScrapedScholarship[]> {
    // TODO: http://www.mes.tn
    return [];
  }
}
