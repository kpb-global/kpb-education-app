import { Injectable, Logger } from '@nestjs/common';

import {
  ScholarshipScraper,
  ScrapedScholarship,
} from '../scholarship-source.interface';

/**
 * DAAD — Deutscher Akademischer Austauschdienst. German government
 * scholarships, well-funded and widely taken up by West African engineering
 * and STEM students.
 *
 * Source:
 *   - https://www.funding-guide.de (scholarship database, EN + DE)
 *   - Regional filter: "Africa — Sub-Saharan" + country filters for CI/SN/BJ/ML/BF/TG
 *
 * REVIEW_STATUS: pending-legal
 *   DAAD's Impressum / Rechtliche Hinweise permits citation with attribution.
 *   They also publish a JSON API at /api/search/scholarships (undocumented
 *   but stable) — prefer that over HTML scraping once confirmed legal.
 *
 * Expected DOM (funding-guide.de/en/find-scholarships/, April 2026):
 *   - `.scholarship-result-item` → listing card
 *     - `h3 a` → name (EN)
 *     - `.deadline` → deadline (DE format dd.MM.yyyy)
 *     - `.target-group` → level
 *     - `a.detail-link` → detail URL
 *   - Detail page has both EN and DE copy; DAAD consistently supplies both.
 *
 * nameFr strategy: DAAD listings are EN+DE only. For nameFr we suffix the EN
 * title with " (DAAD)" as a placeholder — admins translate during review.
 */
@Injectable()
export class DaadScraper implements ScholarshipScraper {
  readonly prefix = 'daad';
  readonly name = 'DAAD (Germany)';
  private readonly logger = new Logger(DaadScraper.name);

  async fetch(): Promise<ScrapedScholarship[]> {
    // TODO(legal-clearance): per file banner.
    // const response = await fetch(
    //   'https://www2.funding-guide.de/api/search/scholarships?region=subsaharan-africa',
    //   { headers: { Accept: 'application/json' } },
    // );
    // if (!response.ok) {
    //   this.logger.warn(`DAAD API returned ${response.status}`);
    //   return [];
    // }
    // const data = (await response.json()) as { items: Array<{
    //   id: string; title: string; applicationDeadline: string | null;
    //   url: string; targetGroup: string[]; fundingType: string[];
    // }> };
    // return data.items.map((item) => ({
    //   sourceKey: `${this.prefix}-${item.id}`,
    //   nameEn: item.title,
    //   nameFr: `${item.title} (DAAD)`,
    //   countryId: 'de',
    //   deadlineAt: item.applicationDeadline ? new Date(item.applicationDeadline) : null,
    //   applicationUrl: item.url,
    //   sourceUrl: item.url,
    //   tags: [...item.targetGroup, ...item.fundingType, 'daad'],
    // }));

    this.logger.debug(
      'DaadScraper.fetch() is stubbed pending legal clearance.',
    );
    return [];
  }
}
