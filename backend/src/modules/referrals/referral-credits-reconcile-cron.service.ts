import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';

import { PrismaService } from '../prisma/prisma.service';
import { ReferralCreditsService } from './referral-credits.service';

/**
 * KPB-80 — Referral-credits reconciliation cron.
 *
 * A safety net for the inline crediting hook (KPB-77): if the fire-and-forget
 * `creditReferrerForFirstCase` call ever fails silently (transient DB error,
 * process crash mid-case-creation, deploy window), the referrer's credit is
 * simply never minted. This hourly cron finds referrals whose referee has
 * already created at least one case but whose ledger has no
 * `firstcase:<referralId>` earn row yet, and re-issues the credit.
 *
 * It never double-credits: it delegates to the SAME idempotent
 * `creditReferrerForFirstCase` (UNIQUE dedupeKey `firstcase:<referralId>`), so a
 * row already credited — or credited concurrently between the scan and the
 * write — collides on insert (Prisma P2002) and no-ops. The pre-filter on
 * existing dedupeKeys is only a scan-narrowing optimisation, not the
 * correctness guarantee.
 */
@Injectable()
export class ReferralCreditsReconcileCronService {
  private readonly logger = new Logger(ReferralCreditsReconcileCronService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly credits: ReferralCreditsService,
  ) {}

  /// Hourly, on the hour.
  @Cron('0 * * * *')
  async scheduledRun(): Promise<void> {
    if (!this.prisma.isEnabled) return;
    await this.run();
  }

  /// Core logic, also callable from an admin endpoint for testing.
  ///
  /// `referralsChecked` is the number of candidate referrals inspected (referee
  /// has a case + no existing earn row); `creditsBackfilled` is how many of
  /// those actually minted a new credit this run.
  async run(): Promise<{ referralsChecked: number; creditsBackfilled: number }> {
    const result = await this.prisma.execute(async (db) => {
      // All referrals + the set of earn dedupeKeys already in the ledger.
      const [referrals, earnedTxns] = await Promise.all([
        db.referral.findMany({
          select: { id: true, refereeProfileId: true },
        }),
        db.creditTransaction.findMany({
          where: { reason: 'referralFirstCase' },
          select: { dedupeKey: true },
        }),
      ]);

      const alreadyCredited = new Set(earnedTxns.map((t) => t.dedupeKey));

      // Candidates: not yet credited AND the referee has created a case.
      const candidates: string[] = [];
      for (const r of referrals) {
        if (alreadyCredited.has(`firstcase:${r.id}`)) continue;
        const caseCount = await db.case.count({
          where: { userId: r.refereeProfileId },
        });
        if (caseCount < 1) continue;
        candidates.push(r.refereeProfileId);
      }
      return candidates;
    });

    const refereeIds = result ?? [];

    let creditsBackfilled = 0;
    for (const refereeId of refereeIds) {
      // Idempotent: only mints when caseCount === 1 and the dedupeKey is free.
      // The call reports whether it actually minted, so backfills are counted
      // directly — no extra ledger scans.
      if (await this.credits.creditReferrerForFirstCase(refereeId)) {
        creditsBackfilled++;
      }
    }

    this.logger.log(
      `Referral credits reconcile: ${refereeIds.length} candidate(s) checked, ${creditsBackfilled} credit(s) backfilled.`,
    );
    return { referralsChecked: refereeIds.length, creditsBackfilled };
  }
}
