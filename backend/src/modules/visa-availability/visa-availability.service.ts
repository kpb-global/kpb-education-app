import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';

import { PrismaService } from '../prisma/prisma.service';
import { CanadaAbidjanFetcher } from './fetchers/canada-abidjan.fetcher';
import { CanadaDakarFetcher } from './fetchers/canada-dakar.fetcher';
import { FranceAbidjanFetcher } from './fetchers/france-abidjan.fetcher';
import { FranceBamakoFetcher } from './fetchers/france-bamako.fetcher';
import { FranceCotonouFetcher } from './fetchers/france-cotonou.fetcher';
import { FranceDakarFetcher } from './fetchers/france-dakar.fetcher';
import { GermanyOuagadougouFetcher } from './fetchers/germany-ouagadougou.fetcher';
import {
  ConsulateFetcher,
  ConsulateFetchResult,
} from './visa-availability.interface';

/**
 * Visa-appointment availability orchestration (Phase 1 — Track A2).
 *
 * Every 6 hours, iterates each registered consulate fetcher and upserts a
 * VisaAvailabilitySnapshot row. One row per consulate — no history table.
 *
 * ⚠ Compliance gate:
 *   The service enforces the `reviewStatus` contract from the fetcher side:
 *   if a fetcher's `reviewStatus !== 'cleared'`, we never call its fetch()
 *   and persist `{ status: 'unknown' }` directly. This is a defence in
 *   depth — the fetcher also gates itself, but a buggy fetcher shouldn't be
 *   able to reach the network simply because the service forgot to check.
 */
@Injectable()
export class VisaAvailabilityService {
  private readonly logger = new Logger(VisaAvailabilityService.name);
  private readonly fetchers: ConsulateFetcher[];

  constructor(
    private readonly prismaService: PrismaService,
    canadaAbidjan: CanadaAbidjanFetcher,
    canadaDakar: CanadaDakarFetcher,
    franceAbidjan: FranceAbidjanFetcher,
    franceDakar: FranceDakarFetcher,
    franceCotonou: FranceCotonouFetcher,
    franceBamako: FranceBamakoFetcher,
    germanyOuagadougou: GermanyOuagadougouFetcher,
  ) {
    this.fetchers = [
      canadaAbidjan,
      canadaDakar,
      franceAbidjan,
      franceDakar,
      franceCotonou,
      franceBamako,
      germanyOuagadougou,
    ];
  }

  /** Cron tick — every 6 hours (00:00, 06:00, 12:00, 18:00 UTC). */
  @Cron(CronExpression.EVERY_6_HOURS)
  async refreshAll(): Promise<void> {
    this.logger.log(
      `Starting visa-availability refresh across ${this.fetchers.length} consulates`,
    );
    for (const fetcher of this.fetchers) {
      await this.refreshOne(fetcher);
    }
    this.logger.log('Visa-availability refresh complete');
  }

  /** Single-consulate refresh. Isolated so one failure doesn't kill the rest. */
  private async refreshOne(fetcher: ConsulateFetcher): Promise<void> {
    let result: ConsulateFetchResult;

    if (fetcher.reviewStatus !== 'cleared') {
      // Defence-in-depth: the fetcher is supposed to self-gate, but we also
      // refuse to invoke fetch() at all until legal + DPIA are signed off.
      this.logger.debug(
        `[${fetcher.consulateCode}] skipped — reviewStatus=${fetcher.reviewStatus}`,
      );
      result = { status: 'unknown' };
    } else {
      try {
        result = await fetcher.fetch();
      } catch (error) {
        const msg = error instanceof Error ? error.message : 'unknown error';
        this.logger.warn(`[${fetcher.consulateCode}] fetch error: ${msg}`);
        result = { status: 'error', errorMessage: msg };
      }
    }

    await this.prismaService.execute((prisma) =>
      prisma.visaAvailabilitySnapshot.upsert({
        where: { consulateCode: fetcher.consulateCode },
        create: {
          consulateCode: fetcher.consulateCode,
          countryCode: fetcher.countryCode,
          city: fetcher.city,
          status: result.status,
          nextAvailableAt: result.nextAvailableAt ?? null,
          soonestSlot: result.soonestSlot ?? null,
          errorMessage: result.errorMessage ?? null,
          lastCheckedAt: new Date(),
        },
        update: {
          status: result.status,
          nextAvailableAt: result.nextAvailableAt ?? null,
          soonestSlot: result.soonestSlot ?? null,
          errorMessage: result.errorMessage ?? null,
          lastCheckedAt: new Date(),
        },
      }),
    );
  }

  /** Public listing for mobile — latest snapshot per consulate. */
  async listPublic(params: { countryCode?: string }) {
    const items = await this.prismaService.execute((prisma) =>
      prisma.visaAvailabilitySnapshot.findMany({
        where: {
          ...(params.countryCode
            ? { countryCode: params.countryCode.toUpperCase() }
            : {}),
        },
        orderBy: [{ countryCode: 'asc' }, { city: 'asc' }],
        select: {
          consulateCode: true,
          countryCode: true,
          city: true,
          status: true,
          nextAvailableAt: true,
          soonestSlot: true,
          lastCheckedAt: true,
          // Intentionally omits errorMessage — that's admin-only.
        },
      }),
    );

    // If the DB is empty (fresh install or no cron has run yet), return a
    // best-effort list of known consulates in `unknown` state so the mobile
    // UI can render the set instead of showing nothing.
    if (!items || items.length === 0) {
      return {
        items: this.fetchers
          .filter(
            (f) => !params.countryCode || f.countryCode === params.countryCode,
          )
          .map((f) => ({
            consulateCode: f.consulateCode,
            countryCode: f.countryCode,
            city: f.city,
            status: 'unknown' as const,
            nextAvailableAt: null,
            soonestSlot: null,
            lastCheckedAt: null,
          })),
      };
    }
    return { items };
  }
}
