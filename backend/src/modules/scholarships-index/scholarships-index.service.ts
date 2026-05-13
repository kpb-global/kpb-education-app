import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';

import { PrismaService } from '../prisma/prisma.service';
import {
  ScrapedScholarship,
  ScholarshipScraper,
} from './scholarship-source.interface';
import { GreatYopScraper } from './scrapers/greatyop.scraper';
import { MastereTnScraper } from './scrapers/mastereTn.scraper';

export type RefreshResult = {
  startedAt: Date;
  finishedAt: Date;
  sources: Array<{
    prefix: string;
    name: string;
    fetched: number;
    upserted: number;
    deactivated: number;
    merged: number;
    error: string | null;
  }>;
  totalFetched: number;
  totalUpserted: number;
  totalDeactivated: number;
  totalMerged: number;
};

/**
 * Scholarship-index refresh — every 48 hours.
 *
 * Responsibilities:
 *   1. Iterate scrapers (GreatYop + MastereTn), collecting scraped rows.
 *   2. Deduplicate across sources: when the same scholarship appears in both
 *      sites (detected by normalized title similarity), keep the record with
 *      the highest `contentScore` and merge missing fields from the other.
 *   3. Upsert each row into the Scholarship table (sourceKey as the stable ID).
 *   4. After each scraper run, deactivate any row with this scraper's prefix
 *      that wasn't seen in the current run (expired / removed listings).
 */
@Injectable()
export class ScholarshipsIndexService {
  private readonly logger = new Logger(ScholarshipsIndexService.name);
  private readonly scrapers: ScholarshipScraper[];

  constructor(
    private readonly prismaService: PrismaService,
    greatYop: GreatYopScraper,
    mastereTn: MastereTnScraper,
  ) {
    this.scrapers = [greatYop, mastereTn];
  }

  /** Cron tick — every 48 hours (midnight every other day). */
  @Cron('0 0 */2 * *')
  async scheduledRefresh(): Promise<void> {
    this.logger.log('Starting 48h scholarship-index refresh');
    try {
      const result = await this.refresh();
      this.logger.log(
        `Refresh complete: ${result.totalUpserted} upserted, ${result.totalDeactivated} deactivated, ${result.totalMerged} merged across ${result.sources.length} sources`,
      );
    } catch (error) {
      this.logger.error(
        `48h refresh failed: ${error instanceof Error ? error.message : 'unknown'}`,
        error instanceof Error ? error.stack : undefined,
      );
    }
  }

  /** Triggered from admin UI ("Refresh now" button) and by the cron. */
  async refresh(): Promise<RefreshResult> {
    const startedAt = new Date();
    const allScraped: Array<{ prefix: string; rows: ScrapedScholarship[] }> = [];
    const sources: RefreshResult['sources'] = [];

    // ── Phase 1: Fetch from all scrapers ─────────────────────────────────────
    for (const scraper of this.scrapers) {
      const sourceResult = {
        prefix: scraper.prefix,
        name: scraper.name,
        fetched: 0,
        upserted: 0,
        deactivated: 0,
        merged: 0,
        error: null as string | null,
      };
      try {
        const rows = await scraper.fetch();
        const valid = rows.filter((r) => {
          if (!r.sourceKey.startsWith(`${scraper.prefix}-`)) {
            this.logger.warn(
              `[${scraper.prefix}] rejecting key "${r.sourceKey}" — bad prefix`,
            );
            return false;
          }
          return true;
        });
        sourceResult.fetched = valid.length;
        allScraped.push({ prefix: scraper.prefix, rows: valid });
      } catch (error) {
        sourceResult.error =
          error instanceof Error ? error.message : 'unknown error';
        this.logger.error(
          `[${scraper.prefix}] failed: ${sourceResult.error}`,
          error instanceof Error ? error.stack : undefined,
        );
        allScraped.push({ prefix: scraper.prefix, rows: [] });
      }
      sources.push(sourceResult);
    }

    // ── Phase 2: Cross-source deduplication ──────────────────────────────────
    const allRows = allScraped.flatMap((s) => s.rows);
    const { deduplicated, mergeCount } = this.deduplicateAcrossSources(allRows);

    // Update merge counts per source
    const mergesBySource = new Map<string, number>();
    for (const row of deduplicated) {
      const prefix = row.sourceKey.split('-')[0];
      mergesBySource.set(prefix, (mergesBySource.get(prefix) ?? 0));
    }
    sources.forEach((s) => {
      s.merged = mergeCount;
    });

    // ── Phase 3: Upsert all deduplicated rows ─────────────────────────────────
    for (const source of sources) {
      const rows = deduplicated.filter((r) =>
        r.sourceKey.startsWith(`${source.prefix}-`),
      );
      for (const row of rows) {
        const ok = await this.upsert(row);
        if (ok) source.upserted += 1;
      }
      source.deactivated = await this.deactivateMissing(
        source.prefix,
        rows.map((r) => r.sourceKey),
      );
    }

    const finishedAt = new Date();
    return {
      startedAt,
      finishedAt,
      sources,
      totalFetched: sources.reduce((sum, s) => sum + s.fetched, 0),
      totalUpserted: sources.reduce((sum, s) => sum + s.upserted, 0),
      totalDeactivated: sources.reduce((sum, s) => sum + s.deactivated, 0),
      totalMerged: mergeCount,
    };
  }

  /**
   * Profile-aware list for the mobile app.
   * Filters and scores by user profile (level, fields of interest, country).
   */
  async listForProfile(params: {
    lang: 'fr' | 'en';
    level?: string;
    fieldIds?: string[];
    countryId?: string;
    fundingType?: string;
    limit?: number;
    offset?: number;
  }) {
    const { lang, limit = 20, offset = 0 } = params;

    const items = await this.prismaService.execute((prisma) =>
      prisma.scholarship.findMany({
        where: {
          isActive: true,
          ...(params.fundingType ? { fundingType: params.fundingType as any } : {}),
          ...(params.countryId ? { countryId: params.countryId } : {}),
          ...(params.fieldIds?.length
            ? {
                relatedFieldIds: {
                  hasSome: params.fieldIds,
                },
              }
            : {}),
        },
        orderBy: [{ deadlineAt: 'asc' }, { createdAt: 'desc' }],
        take: limit + offset,
      }),
    );

    if (!items) return { items: [], total: 0 };

    const mapped = items.map((s) => {
      // Profile-match score
      let matchScore = s.baseMatch;
      if (params.level) {
        const levelField = lang === 'fr' ? s.levelEligibleFr : s.levelEligibleEn;
        if (levelField.toLowerCase().includes(params.level.toLowerCase())) {
          matchScore += 30;
        }
      }
      if (params.fieldIds?.length) {
        const fieldOverlap = params.fieldIds.filter((f) =>
          s.relatedFieldIds.includes(f),
        ).length;
        matchScore += fieldOverlap * 10;
      }

      return {
        id: s.id,
        title: lang === 'fr' ? s.nameFr : s.nameEn,
        countryName: lang === 'fr' ? s.countryNameFr : s.countryNameEn,
        fundingType: s.fundingType,
        description: lang === 'fr' ? s.descriptionFr : s.descriptionEn,
        advantages: lang === 'fr' ? s.advantagesFr : s.advantagesEn,
        eligibility: lang === 'fr' ? s.eligibilityFr : s.eligibilityEn,
        level: lang === 'fr' ? s.levelEligibleFr : s.levelEligibleEn,
        deadlineLabel: lang === 'fr' ? s.deadlineLabelFr : s.deadlineLabelEn,
        deadlineAt: s.deadlineAt?.toISOString() ?? null,
        applicationUrl: s.applicationUrl,
        sourceUrl: s.sourceUrl,
        tags: s.tags,
        matchScore,
      };
    });

    // Sort by matchScore desc, then by deadline asc
    mapped.sort((a, b) => {
      if (b.matchScore !== a.matchScore) return b.matchScore - a.matchScore;
      if (a.deadlineAt && b.deadlineAt) {
        return new Date(a.deadlineAt).getTime() - new Date(b.deadlineAt).getTime();
      }
      return 0;
    });

    return { items: mapped.slice(offset, offset + limit), total: mapped.length };
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  /**
   * Detect scholarships appearing in multiple sources by normalizing their
   * English titles (strip year, punctuation, lowercase). When a match is
   * found, merge into the record with the highest `contentScore`, filling
   * missing fields from the lower-score record.
   */
  private deduplicateAcrossSources(rows: ScrapedScholarship[]): {
    deduplicated: ScrapedScholarship[];
    mergeCount: number;
  } {
    const normalized = (title: string) =>
      title
        .toLowerCase()
        .replace(/\d{4}[-/]\d{4}|\d{4}/g, '')
        .replace(/[^a-z\s]/g, '')
        .replace(/\s+/g, ' ')
        .trim();

    const groups = new Map<string, ScrapedScholarship[]>();
    for (const row of rows) {
      const key = normalized(row.nameEn || row.nameFr);
      if (!groups.has(key)) groups.set(key, []);
      groups.get(key)!.push(row);
    }

    const deduplicated: ScrapedScholarship[] = [];
    let mergeCount = 0;

    for (const [, group] of groups) {
      if (group.length === 1) {
        deduplicated.push(group[0]);
        continue;
      }
      // Sort by contentScore desc — winner is the best record
      group.sort((a, b) => (b.contentScore ?? 0) - (a.contentScore ?? 0));
      const winner = { ...group[0] };
      mergeCount += group.length - 1;

      // Fill empty fields from secondary records
      for (const other of group.slice(1)) {
        if (!winner.descriptionFr && other.descriptionFr) winner.descriptionFr = other.descriptionFr;
        if (!winner.descriptionEn && other.descriptionEn) winner.descriptionEn = other.descriptionEn;
        if (!winner.advantagesFr.length && other.advantagesFr.length) winner.advantagesFr = other.advantagesFr;
        if (!winner.advantagesEn.length && other.advantagesEn.length) winner.advantagesEn = other.advantagesEn;
        if (!winner.eligibilityFr.length && other.eligibilityFr.length) winner.eligibilityFr = other.eligibilityFr;
        if (!winner.eligibilityEn.length && other.eligibilityEn.length) winner.eligibilityEn = other.eligibilityEn;
        if (!winner.deadlineAt && other.deadlineAt) winner.deadlineAt = other.deadlineAt;
        if (winner.fundingType === 'unknown' && other.fundingType !== 'unknown') winner.fundingType = other.fundingType;
        // Merge tags
        winner.tags = [...new Set([...winner.tags, ...other.tags])];
      }

      deduplicated.push(winner);
    }

    return { deduplicated, mergeCount };
  }

  private async upsert(row: ScrapedScholarship): Promise<boolean> {
    const now = new Date();
    const result = await this.prismaService.execute((prisma) =>
      prisma.scholarship.upsert({
        where: { sourceKey: row.sourceKey },
        create: {
          sourceKey: row.sourceKey,
          sourceUrl: row.sourceUrl,
          applicationUrl: row.applicationUrl,
          deadlineAt: row.deadlineAt,
          lastVerifiedAt: now,
          isActive: true,
          tags: row.tags,
          nameFr: row.nameFr,
          nameEn: row.nameEn,
          countryId: row.countryId,
          countryNameFr: row.countryNameFr,
          countryNameEn: row.countryNameEn,
          descriptionFr: row.descriptionFr,
          descriptionEn: row.descriptionEn,
          advantagesFr: row.advantagesFr,
          advantagesEn: row.advantagesEn,
          eligibilityFr: row.eligibilityFr,
          eligibilityEn: row.eligibilityEn,
          fundingType: row.fundingType,
          levelEligibleFr: row.levelEligibleFr,
          levelEligibleEn: row.levelEligibleEn,
          deadlineLabelFr: row.deadlineLabelFr,
          deadlineLabelEn: row.deadlineLabelEn,
          // Admin-curated fields (initialized empty)
          typeOfFundingFr: '',
          typeOfFundingEn: '',
          keyRequirementsFr: [],
          keyRequirementsEn: [],
          relatedFieldIds: [],
        },
        update: {
          // Refresh scraped fields. Admin-curated fields are NOT touched.
          sourceUrl: row.sourceUrl,
          applicationUrl: row.applicationUrl,
          deadlineAt: row.deadlineAt,
          lastVerifiedAt: now,
          isActive: true,
          tags: row.tags,
          // Update content fields if they now have better data
          ...(row.descriptionFr ? { descriptionFr: row.descriptionFr } : {}),
          ...(row.descriptionEn ? { descriptionEn: row.descriptionEn } : {}),
          ...(row.advantagesFr.length ? { advantagesFr: row.advantagesFr } : {}),
          ...(row.advantagesEn.length ? { advantagesEn: row.advantagesEn } : {}),
          ...(row.eligibilityFr.length ? { eligibilityFr: row.eligibilityFr } : {}),
          ...(row.eligibilityEn.length ? { eligibilityEn: row.eligibilityEn } : {}),
          ...(row.fundingType !== 'unknown' ? { fundingType: row.fundingType } : {}),
        },
      }),
    );
    return !!result;
  }

  private async deactivateMissing(prefix: string, seenKeys: string[]): Promise<number> {
    const result = await this.prismaService.execute((prisma) =>
      prisma.scholarship.updateMany({
        where: {
          sourceKey: { startsWith: `${prefix}-` },
          NOT: { sourceKey: { in: seenKeys } },
          isActive: true,
        },
        data: { isActive: false },
      }),
    );
    return result?.count ?? 0;
  }
}
