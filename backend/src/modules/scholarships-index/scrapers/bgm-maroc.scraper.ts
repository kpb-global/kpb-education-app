import { Injectable, Logger } from '@nestjs/common';

import {
  ScholarshipScraper,
  ScrapedScholarship,
} from '../scholarship-source.interface';

/**
 * Bourse du Gouvernement Marocain — AMCI (Agence Marocaine de Coopération
 * Internationale).
 *
 * Source index:    https://www.amci.ma/fr/content/bourses-detudes
 * Listing detail:  https://www.amci.ma/fr/bourses/<slug>
 *
 * REVIEW_STATUS: pending-legal
 *   AMCI does not publish an explicit TOS for the bourses pages. Scraping is
 *   likely permitted under French data-ré-utilisation norms since the data is
 *   publicly posted by a government agency, but get written confirmation
 *   from counsel before enabling.
 *
 * Expected DOM structure (as of April 2026):
 *   - `.view-bourses .views-row` → listing card
 *     - `h3 a` → name (FR) + detail URL
 *     - `.field-date` → deadline label
 *   - Detail page:
 *     - `.field-pays .field-item` → country name
 *     - `.field-niveau .field-item` → level
 *     - `.field-body .field-item` → description
 *
 * Fallback strategy when structure changes: log + return []. The cron run
 * will then deactivate all `bgm-maroc-*` rows; the admin alarm on that
 * deactivation count is the trigger to update the selectors.
 */
@Injectable()
export class BgmMarocScraper implements ScholarshipScraper {
  readonly prefix = 'bgm-maroc';
  readonly name = 'Bourse du Gouvernement Marocain (AMCI)';
  private readonly logger = new Logger(BgmMarocScraper.name);

  async fetch(): Promise<ScrapedScholarship[]> {
    // TODO(legal-clearance): uncomment the fetch once TOS review is complete.
    // const response = await fetch(
    //   'https://www.amci.ma/fr/content/bourses-detudes',
    //   { headers: { 'User-Agent': 'KPB-Education-Bot/1.0 (contact@kpb-education.com)' } },
    // );
    // if (!response.ok) {
    //   this.logger.warn(`AMCI returned ${response.status}`);
    //   return [];
    // }
    // const html = await response.text();
    // TODO: parse with node-html-parser or cheerio — selectors in the file banner.

    this.logger.debug(
      'BgmMarocScraper.fetch() is stubbed pending legal clearance.',
    );
    return [];
  }
}
