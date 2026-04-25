import { Injectable, Logger } from '@nestjs/common';

import {
  ScholarshipScraper,
  ScrapedScholarship,
} from '../scholarship-source.interface';

/**
 * Campus France — Bourse Eiffel + AUF (Agence Universitaire de la
 * Francophonie) joint listing. Two sources share this scraper because Campus
 * France cross-posts AUF scholarships under the same URL scheme.
 *
 * Source index:
 *   - https://www.campusfrance.org/fr/eiffel
 *   - https://www.auf.org/nouvelles/appels-a-candidatures/
 *
 * REVIEW_STATUS: pending-legal
 *   Campus France's Mentions légales (§5) includes a "pas d'exploitation
 *   automatisée" clause. Counsel must confirm whether our use (read-only
 *   index of publicly-posted deadlines, no re-hosting of copy) qualifies as
 *   "fair use" under French CPI L.122-5 or requires an explicit licence.
 *
 *   AUF is more permissive — their CGU allows "reproduction à des fins
 *   d'information non commerciales" which plausibly covers our public
 *   scholarship index. Still, document the position.
 *
 * Expected DOM (Campus France, April 2026):
 *   - `article.bourse-card` → listing
 *     - `h2.card__title` → name
 *     - `.card__meta time[datetime]` → deadline ISO date
 *     - `.card__link` → detail URL
 *   - `.tag` → filter tags (level, funding type)
 *
 * Expected DOM (AUF):
 *   - `.actualite-item` → listing with similar shape.
 */
@Injectable()
export class AufEiffelScraper implements ScholarshipScraper {
  readonly prefix = 'auf-eiffel';
  readonly name = 'Campus France Eiffel + AUF';
  private readonly logger = new Logger(AufEiffelScraper.name);

  async fetch(): Promise<ScrapedScholarship[]> {
    // TODO(legal-clearance): per file banner.
    // const [campusFrance, auf] = await Promise.allSettled([
    //   fetch('https://www.campusfrance.org/fr/eiffel'),
    //   fetch('https://www.auf.org/nouvelles/appels-a-candidatures/'),
    // ]);
    // const results: ScrapedScholarship[] = [];
    // if (campusFrance.status === 'fulfilled' && campusFrance.value.ok) {
    //   const html = await campusFrance.value.text();
    //   // TODO: parse per file banner selectors
    // }
    // if (auf.status === 'fulfilled' && auf.value.ok) {
    //   const html = await auf.value.text();
    //   // TODO: parse per file banner selectors
    // }

    this.logger.debug(
      'AufEiffelScraper.fetch() is stubbed pending legal clearance.',
    );
    return [];
  }
}
