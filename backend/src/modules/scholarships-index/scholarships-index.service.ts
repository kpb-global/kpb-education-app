import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';

import { PrismaService } from '../prisma/prisma.service';
import {
  ScrapedScholarship,
  ScholarshipScraper,
} from './scholarship-source.interface';
import { AlgeriaScraper } from './scrapers/algeria.scraper';
import { AufEiffelScraper } from './scrapers/auf-eiffel.scraper';
import { BgmMarocScraper } from './scrapers/bgm-maroc.scraper';
import { ChineseMofcomScraper } from './scrapers/chinese-mofcom.scraper';
import { DaadScraper } from './scrapers/daad.scraper';
import { RussianQuotaScraper } from './scrapers/russian-quota.scraper';
import { TunisiaScraper } from './scrapers/tunisia.scraper';
import { TurkiyeBurslariScraper } from './scrapers/turkiye-burslari.scraper';
import { TurkiyeMevlanaScraper } from './scrapers/turkiye-mevlana.scraper';

export type RefreshResult = {
  startedAt: Date;
  finishedAt: Date;
  sources: Array<{
    prefix: string;
    name: string;
    fetched: number;
    upserted: number;
    deactivated: number;
    error: string | null;
  }>;
  totalFetched: number;
  totalUpserted: number;
  totalDeactivated: number;
};

/**
 * Weekly scholarship-index refresh (Phase 1, Track A1).
 *
 * Responsibilities:
 *   1. Iterate every registered scraper, collecting scraped rows.
 *   2. Upsert each by sourceKey, flagging it lastVerifiedAt=now, isActive=true.
 *   3. After each scraper run, deactivate any row whose sourceKey matches the
 *      scraper's prefix but wasn't seen in this run (stale listings).
 *
 * Design notes:
 * - Scrapers are stateless and injected individually so they can be unit-
 *   tested in isolation. The service never reaches into their internals.
 * - Non-nullable Scholarship fields (levelEligibleFr/En, typeOfFundingFr/En,
 *   deadlineLabelFr/En, keyRequirementsFr/En, relatedFieldIds) are filled
 *   with empty placeholders on *create*. Admins curate copy post-scrape in
 *   the admin UI. On *update* we never overwrite these — admin edits win
 *   over automated refresh, so a curated listing stays curated.
 * - A scraper returning [] is treated as "source is down or empty right
 *   now" — we deactivate its prefix regardless. The admin UI should surface
 *   a warning if > N prefixes report 0 in a given run.
 */
@Injectable()
export class ScholarshipsIndexService {
  private readonly logger = new Logger(ScholarshipsIndexService.name);
  private readonly scrapers: ScholarshipScraper[];

  constructor(
    private readonly prismaService: PrismaService,
    bgmMaroc: BgmMarocScraper,
    aufEiffel: AufEiffelScraper,
    daad: DaadScraper,
    turkiyeBurslari: TurkiyeBurslariScraper,
    chineseMofcom: ChineseMofcomScraper,
    russianQuota: RussianQuotaScraper,
    tunisia: TunisiaScraper,
    algeria: AlgeriaScraper,
    turkiyeMevlana: TurkiyeMevlanaScraper,
  ) {
    this.scrapers = [
      bgmMaroc,
      aufEiffel,
      daad,
      turkiyeBurslari,
      chineseMofcom,
      russianQuota,
      tunisia,
      algeria,
      turkiyeMevlana,
    ];
  }

  /** Weekly cron — runs automatically at Sunday 03:00 UTC. */
  @Cron(CronExpression.EVERY_WEEK)
  async weeklyRefresh(): Promise<void> {
    this.logger.log('Starting weekly scholarship-index refresh');
    try {
      const result = await this.refresh();
      this.logger.log(
        `Refresh complete: ${result.totalUpserted} upserted, ${result.totalDeactivated} deactivated across ${result.sources.length} sources`,
      );
    } catch (error) {
      this.logger.error(
        `Weekly refresh failed: ${error instanceof Error ? error.message : 'unknown'}`,
        error instanceof Error ? error.stack : undefined,
      );
    }
  }

  /** Triggered from admin UI ("Refresh now" button) and by the weekly cron. */
  async refresh(): Promise<RefreshResult> {
    const startedAt = new Date();
    const sources: RefreshResult['sources'] = [];

    for (const scraper of this.scrapers) {
      const sourceResult = {
        prefix: scraper.prefix,
        name: scraper.name,
        fetched: 0,
        upserted: 0,
        deactivated: 0,
        error: null as string | null,
      };

      try {
        const scraped = await scraper.fetch();
        sourceResult.fetched = scraped.length;

        // Invariant: every sourceKey returned must start with the scraper's
        // prefix. Otherwise the deactivation step would miss rows — and
        // worse, another scraper's prefix could claim them.
        const valid = scraped.filter((s) => {
          if (!s.sourceKey.startsWith(`${scraper.prefix}-`)) {
            this.logger.warn(
              `[${scraper.prefix}] rejecting sourceKey "${s.sourceKey}" — must start with "${scraper.prefix}-"`,
            );
            return false;
          }
          return true;
        });

        for (const row of valid) {
          const ok = await this.upsert(row);
          if (ok) sourceResult.upserted += 1;
        }

        sourceResult.deactivated = await this.deactivateMissing(
          scraper.prefix,
          valid.map((r) => r.sourceKey),
        );
      } catch (error) {
        sourceResult.error =
          error instanceof Error ? error.message : 'unknown error';
        this.logger.error(
          `[${scraper.prefix}] failed: ${sourceResult.error}`,
          error instanceof Error ? error.stack : undefined,
        );
      }

      sources.push(sourceResult);
    }

    const finishedAt = new Date();
    return {
      startedAt,
      finishedAt,
      sources,
      totalFetched: sources.reduce((sum, s) => sum + s.fetched, 0),
      totalUpserted: sources.reduce((sum, s) => sum + s.upserted, 0),
      totalDeactivated: sources.reduce((sum, s) => sum + s.deactivated, 0),
    };
  }

  /**
   * Upsert one scraped row. Create fills required non-null fields with empty
   * placeholders; update only touches index fields so admin-curated copy is
   * preserved across refreshes.
   */
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
          // Admin-curated copy placeholders — filled in via admin UI.
          levelEligibleFr: '',
          levelEligibleEn: '',
          typeOfFundingFr: '',
          typeOfFundingEn: '',
          deadlineLabelFr: '',
          deadlineLabelEn: '',
          keyRequirementsFr: [],
          keyRequirementsEn: [],
          relatedFieldIds: [],
        },
        update: {
          // Refresh index fields only — never clobber admin-edited copy.
          sourceUrl: row.sourceUrl,
          applicationUrl: row.applicationUrl,
          deadlineAt: row.deadlineAt,
          lastVerifiedAt: now,
          isActive: true,
          tags: row.tags,
        },
      }),
    );
    return !!result;
  }

  /**
   * After a scraper's run, flag any row whose sourceKey shares the prefix
   * but isn't in the seen-list as inactive. Seen rows were already set
   * `isActive=true` in upsert() so we don't need to re-touch them.
   */
  private async deactivateMissing(
    prefix: string,
    seenKeys: string[],
  ): Promise<number> {
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
