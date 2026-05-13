import { Injectable, Logger } from '@nestjs/common';

import {
  FundingType,
  ScrapedScholarship,
  ScholarshipScraper,
} from '../scholarship-source.interface';

/**
 * Mastere.tn — French (primary) + English mirror scraper.
 *
 * Source:  https://www.mastere.tn/bourses/
 * English: https://www.mastere.tn/en/  (English version of the site)
 *
 * Strategy:
 *  1. Crawl /bourses/ listing page(s) collecting article URLs.
 *  2. For each article, fetch the FR detail page and parse H2/H3 sections.
 *  3. Detect the EN URL from the hreflang or /en/ prefix.
 *  4. Fetch EN mirror and extract matching sections.
 *  5. Return one ScrapedScholarship per listing with both languages.
 */
@Injectable()
export class MastereTnScraper implements ScholarshipScraper {
  readonly prefix = 'mastereTn';
  readonly name = 'Mastere.tn (FR+EN)';
  private readonly logger = new Logger(MastereTnScraper.name);

  private readonly BASE = 'https://www.mastere.tn';
  private readonly LISTING_URL = 'https://www.mastere.tn/bourses/';
  private readonly HEADERS = {
    'User-Agent':
      'KPB-Education-Bot/1.0 (kpb-education.com; contact@kpb-education.com)',
    Accept: 'text/html,application/xhtml+xml',
    'Accept-Language': 'fr-FR,fr;q=0.9,en;q=0.8',
  };

  async fetch(): Promise<ScrapedScholarship[]> {
    const results: ScrapedScholarship[] = [];

    const articleUrls = await this.collectArticleUrls();
    this.logger.log(`[${this.prefix}] Found ${articleUrls.length} articles`);

    for (const url of articleUrls.slice(0, 50)) {
      try {
        const scholarship = await this.parseArticle(url);
        if (scholarship) results.push(scholarship);
        await this.sleep(700);
      } catch (error) {
        this.logger.warn(
          `[${this.prefix}] Failed to parse ${url}: ${error instanceof Error ? error.message : 'unknown'}`,
        );
      }
    }

    this.logger.log(`[${this.prefix}] Scraped ${results.length} scholarships`);
    return results;
  }

  private async collectArticleUrls(): Promise<string[]> {
    const urls = new Set<string>();
    for (let page = 1; page <= 5; page++) {
      const listUrl =
        page === 1
          ? this.LISTING_URL
          : `${this.LISTING_URL}page/${page}/`;
      try {
        const html = await this.fetchHtml(listUrl);
        const matches = html.matchAll(
          /href="(https:\/\/www\.mastere\.tn\/[a-z0-9À-ÿ-]+\/)"/g,
        );
        let found = 0;
        for (const m of matches) {
          const u = m[1];
          if (
            !u.includes('/bourses/') &&
            !u.includes('/en/') &&
            !u.includes('/page/') &&
            !u.includes('/nous-contacter') &&
            !u.includes('/about') &&
            !u.includes('/privacy') &&
            !u.includes('/termes') &&
            u !== this.BASE + '/'
          ) {
            urls.add(u);
            found++;
          }
        }
        if (found === 0) break;
        await this.sleep(500);
      } catch (err) {
        this.logger.warn(`[${this.prefix}] Listing page ${page} failed: ${err instanceof Error ? err.message : err}`);
        break;
      }
    }
    return [...urls];
  }

  private async parseArticle(url: string): Promise<ScrapedScholarship | null> {
    const html = await this.fetchHtml(url);

    const titleFr =
      this.extractMeta(html, 'og:title') ||
      this.extractTag(html, 'h1') ||
      '';
    if (!titleFr || titleFr.length < 5) return null;

    // English URL: try hreflang or prepend /en
    const enUrlMatch = html.match(/hreflang="en"[^>]*href="([^"]+)"/);
    const enUrl = enUrlMatch
      ? enUrlMatch[1]
      : url.replace('www.mastere.tn/', 'www.mastere.tn/en/');

    const body = this.extractArticleBody(html);
    const descriptionFr = this.extractDescription(body);
    const advantagesFr = this.extractSection(body, ['Avantages', 'Bénéfices', 'Ce que couvre', 'Couverture', 'Montant', 'Allocation', 'Avantages de la bourse']);
    const eligibilityFr = this.extractSection(body, ['Éligibilité', 'Critères', 'Conditions d\'admissibilité', 'Qui peut postuler', 'Exigences']);
    const deadlineInfo = this.extractDeadline(body, titleFr);
    const fundingType = this.detectFunding(titleFr, html);
    const countryFr = this.detectCountryFr(titleFr, html, body);
    const countryEn = this.translateCountryToEn(countryFr);
    const levelFr = this.detectLevelFr(titleFr, body);
    const levelEn = this.translateLevelToEn(levelFr);
    const tags = this.buildTags(titleFr, fundingType, levelFr);
    const applyUrl = this.extractApplyUrl(html) || url;

    // ── Fetch English mirror ──────────────────────────────────────────────
    let titleEn = titleFr;
    let descriptionEn = '';
    let advantagesEn: string[] = [];
    let eligibilityEn: string[] = [];

    try {
      await this.sleep(400);
      const enHtml = await this.fetchHtml(enUrl);
      titleEn =
        this.extractMeta(enHtml, 'og:title') ||
        this.extractTag(enHtml, 'h1') ||
        titleFr;
      const enBody = this.extractArticleBody(enHtml);
      descriptionEn = this.extractDescription(enBody);
      advantagesEn = this.extractSection(enBody, ['Benefits', 'What Does', 'Advantages', 'Scholarship Covers', 'Amount']);
      eligibilityEn = this.extractSection(enBody, ['Eligibility', 'Who Can Apply', 'Requirements', 'Eligible']);
    } catch {
      // English page unavailable
      titleEn = titleFr;
    }

    const slug = url.replace(this.BASE + '/', '').replace(/\/$/, '');
    const sourceKey = `${this.prefix}-${slug}`.slice(0, 200);

    const score = this.computeScore({
      descriptionFr,
      advantagesFr,
      eligibilityFr,
      descriptionEn,
      advantagesEn,
      eligibilityEn,
    });

    return {
      sourceKey,
      nameFr: titleFr.trim(),
      nameEn: titleEn.trim(),
      countryId: countryEn.toLowerCase().replace(/\s+/g, '-') || 'unknown',
      countryNameFr: countryFr,
      countryNameEn: countryEn,
      descriptionFr,
      descriptionEn: descriptionEn || descriptionFr,
      advantagesFr,
      advantagesEn: advantagesEn.length ? advantagesEn : advantagesFr,
      eligibilityFr,
      eligibilityEn: eligibilityEn.length ? eligibilityEn : eligibilityFr,
      fundingType,
      deadlineAt: deadlineInfo.date,
      deadlineLabelFr: deadlineInfo.label,
      deadlineLabelEn: deadlineInfo.label,
      levelEligibleFr: levelFr,
      levelEligibleEn: levelEn,
      applicationUrl: applyUrl,
      sourceUrl: url,
      tags,
      contentScore: score,
    };
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  private async fetchHtml(url: string): Promise<string> {
    const res = await fetch(url, { headers: this.HEADERS });
    if (!res.ok) throw new Error(`HTTP ${res.status} for ${url}`);
    return res.text();
  }

  private extractMeta(html: string, property: string): string {
    const m = html.match(
      new RegExp(`<meta[^>]+property=["']${property}["'][^>]+content=["']([^"']+)["']`, 'i'),
    );
    return m ? m[1].trim() : '';
  }

  private extractTag(html: string, tag: string): string {
    const m = html.match(new RegExp(`<${tag}[^>]*>([^<]+)<\/${tag}>`, 'i'));
    return m ? m[1].trim() : '';
  }

  private extractArticleBody(html: string): string {
    const m =
      html.match(/<div[^>]*class="[^"]*entry-content[^"]*"[^>]*>([\s\S]*?)<div[^>]*class="[^"]*sharedaddy/i) ||
      html.match(/<article[^>]*>([\s\S]*?)<\/article>/i);
    if (m) return m[1];
    const start = html.indexOf('<h2');
    if (start > 0) return html.slice(start, start + 20000);
    return html;
  }

  private extractDescription(body: string): string {
    const beforeH2 = body.split(/<h2/i)[0];
    const paras: string[] = [];
    const matches = beforeH2.matchAll(/<p[^>]*>([\s\S]*?)<\/p>/gi);
    for (const m of matches) {
      const text = m[1].replace(/<[^>]+>/g, '').trim();
      if (text.length > 40) paras.push(text);
    }
    return paras.slice(0, 3).join(' ').trim();
  }

  private extractSection(body: string, headings: string[]): string[] {
    const items: string[] = [];
    for (const heading of headings) {
      const pattern = new RegExp(
        `<h[23][^>]*>[^<]*${heading}[^<]*<\/h[23]>([\s\S]*?)(?=<h[23]|$)`,
        'i',
      );
      const m = body.match(pattern);
      if (!m) continue;
      const sectionHtml = m[1];
      const liMatches = sectionHtml.matchAll(/<li[^>]*>([\s\S]*?)<\/li>/gi);
      for (const li of liMatches) {
        const text = li[1].replace(/<[^>]+>/g, '').trim();
        if (text.length > 5) items.push(text);
      }
      if (items.length === 0) {
        const pMatches = sectionHtml.matchAll(/<p[^>]*>([\s\S]*?)<\/p>/gi);
        for (const p of pMatches) {
          const text = p[1].replace(/<[^>]+>/g, '').trim();
          if (text.length > 10) items.push(text);
        }
      }
      if (items.length) break;
    }
    return items;
  }

  private extractDeadline(body: string, title: string): { date: Date | null; label: string } {
    const patterns = [
      /Date limite\s*:?\s*([^\n<.]+\d{4})/i,
      /deadline[^\d]*(\w+\s+\d{1,2},?\s*\d{4})/i,
      /(\d{1,2}\s+\w+\s+\d{4})/,
    ];
    const text = body + ' ' + title;
    for (const p of patterns) {
      const m = text.match(p);
      if (m) {
        const date = new Date(m[1].trim());
        if (!isNaN(date.getTime())) {
          return {
            date,
            label: date.toLocaleDateString('fr-FR', { day: 'numeric', month: 'long', year: 'numeric' }),
          };
        }
      }
    }
    return { date: null, label: 'Voir site officiel' };
  }

  private detectFunding(title: string, html: string): FundingType {
    const text = (title + ' ' + html).toLowerCase();
    if (text.includes('entièrement financé') || text.includes('fully funded') || text.includes('bourse complète') || text.includes('100%')) {
      return 'fully_funded';
    }
    if (text.includes('partiel') || text.includes('partial') || text.includes('allocation mensuelle')) {
      return 'partially_funded';
    }
    return 'unknown';
  }

  private detectCountryFr(title: string, html: string, body: string): string {
    const known: [string, string][] = [
      ['France', 'France'], ['Allemagne', 'Allemagne'], ['Canada', 'Canada'],
      ['Japon', 'Japon'], ['Suisse', 'Suisse'], ['Belgique', 'Belgique'],
      ['Italie', 'Italie'], ['Espagne', 'Espagne'], ['Royaume-Uni', 'Royaume-Uni'],
      ['Australie', 'Australie'], ['Chine', 'Chine'], ['Turquie', 'Turquie'],
      ['Maroc', 'Maroc'], ['Tunisie', 'Tunisie'], ['Pays-Bas', 'Pays-Bas'],
      ['États-Unis', 'États-Unis'], ['Corée du Sud', 'Corée du Sud'],
      ['Sénégal', 'Sénégal'], ['Suède', 'Suède'],
    ];
    const text = title + ' ' + body;
    for (const [fr] of known) {
      if (text.includes(fr)) return fr;
    }
    return 'International';
  }

  private translateCountryToEn(fr: string): string {
    const map: Record<string, string> = {
      'France': 'France', 'Allemagne': 'Germany', 'Canada': 'Canada',
      'Japon': 'Japan', 'Suisse': 'Switzerland', 'Belgique': 'Belgium',
      'Italie': 'Italy', 'Espagne': 'Spain', 'Royaume-Uni': 'United Kingdom',
      'Australie': 'Australia', 'Chine': 'China', 'Turquie': 'Turkey',
      'Maroc': 'Morocco', 'Tunisie': 'Tunisia', 'Pays-Bas': 'Netherlands',
      'États-Unis': 'United States', 'Corée du Sud': 'South Korea',
      'Sénégal': 'Senegal', 'Suède': 'Sweden', 'International': 'International',
    };
    return map[fr] || fr;
  }

  private detectLevelFr(title: string, body: string): string {
    const text = (title + ' ' + body).toLowerCase();
    const levels: string[] = [];
    if (text.includes('licence') || text.includes('bachelor') || text.includes('undergraduate')) levels.push('Licence');
    if (text.includes('master')) levels.push('Master');
    if (text.includes('doctorat') || text.includes('doctoral') || text.includes('phd')) levels.push('Doctorat');
    if (text.includes('post-doc')) levels.push('Post-doctorat');
    return levels.join(', ') || 'Tous niveaux';
  }

  private translateLevelToEn(fr: string): string {
    return fr
      .replace('Licence', 'Bachelor')
      .replace('Master', 'Master')
      .replace('Doctorat', 'PhD')
      .replace('Post-doctorat', 'Postdoc')
      .replace('Tous niveaux', 'All levels');
  }

  private buildTags(title: string, funding: FundingType, level: string): string[] {
    const tags: string[] = [];
    if (funding === 'fully_funded') tags.push('fully-funded');
    if (funding === 'partially_funded') tags.push('partially-funded');
    if (level.includes('Master')) tags.push('masters');
    if (level.includes('Doctorat') || level.includes('PhD')) tags.push('phd');
    if (level.includes('Licence') || level.includes('Bachelor')) tags.push('undergraduate');
    const lower = title.toLowerCase();
    if (lower.includes('erasmus')) tags.push('erasmus');
    if (lower.includes('afrique') || lower.includes('africa')) tags.push('africa-priority');
    return [...new Set(tags)];
  }

  private extractApplyUrl(html: string): string | null {
    const m =
      html.match(/href="([^"]+)"[^>]*>\s*(?:Postuler|Apply|Candidater|Déposer)[^<]*<\/a>/i) ||
      html.match(/href="([^"]+)"[^>]*>\s*(?:Site officiel|Official)[^<]*<\/a>/i);
    return m ? m[1] : null;
  }

  private computeScore(data: {
    descriptionFr: string;
    advantagesFr: string[];
    eligibilityFr: string[];
    descriptionEn: string;
    advantagesEn: string[];
    eligibilityEn: string[];
  }): number {
    let score = 0;
    if (data.descriptionFr.length > 100) score += 20;
    if (data.advantagesFr.length > 0) score += 20;
    if (data.eligibilityFr.length > 0) score += 20;
    if (data.descriptionEn.length > 100) score += 20;
    if (data.advantagesEn.length > 0) score += 10;
    if (data.eligibilityEn.length > 0) score += 10;
    return score;
  }

  private sleep(ms: number): Promise<void> {
    return new Promise((r) => setTimeout(r, ms));
  }
}
