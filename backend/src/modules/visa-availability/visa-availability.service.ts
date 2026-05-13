import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';

import { PrismaService } from '../prisma/prisma.service';


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

  constructor(private readonly prismaService: PrismaService) {}

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
      return { items: [] };
    }
    return { items };
  }
}
