import { Injectable, Logger } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { randomBytes } from 'crypto';

import { PrismaService } from '../prisma/prisma.service';

/// No-cash referral rewards (KPB-77). One credit is earned when a referred
/// friend reaches the first-case milestone, and spent into a WhatsApp advisor
/// voucher (an in-depth human dossier review). Nothing here ever touches money:
/// a spend only ever decrements the balance and mints a voucher code the student
/// shows a KPB advisor — settlement stays on WhatsApp, per the product model.

/// Credits granted to the referrer when a referee creates their first case.
export const CREDITS_PER_REFERRAL = 1;
/// Credits spent to redeem one advisor review voucher.
export const VOUCHER_COST = 1;
/// How many recent ledger rows the balance endpoint returns.
const HISTORY_LIMIT = 20;

export interface CreditsSummary {
  balance: number;
  history: Array<{ amount: number; reason: string; createdAt: string }>;
}

export type RedeemResult =
  | { ok: true; balance: number; voucherCode: string }
  | { ok: false; reason: 'insufficient' | 'unavailable' };

function isUniqueViolation(error: unknown): boolean {
  return (
    error instanceof Prisma.PrismaClientKnownRequestError &&
    error.code === 'P2002'
  );
}

@Injectable()
export class ReferralCreditsService {
  private readonly logger = new Logger(ReferralCreditsService.name);

  constructor(private readonly prisma: PrismaService) {}

  /// Credit the referrer when their referee reaches the first-case milestone.
  /// Idempotent two ways: (1) only fires on the referee's FIRST case
  /// (caseCount === 1); (2) the ledger row is keyed `firstcase:<referralId>`
  /// with a UNIQUE dedupeKey, so a concurrent/retried call collides on insert
  /// (Prisma P2002) and no-ops. Runs via tryExecute (fire-and-forget) — a
  /// crediting failure must never roll back or block the student's case.
  async creditReferrerForFirstCase(refereeId: string): Promise<void> {
    await this.prisma.tryExecute(async (db) => {
      const referral = await db.referral.findUnique({
        where: { refereeProfileId: refereeId },
        select: { id: true, referrerId: true },
      });
      if (!referral) return; // referee was never referred — nothing to credit

      const caseCount = await db.case.count({ where: { userId: refereeId } });
      if (caseCount !== 1) return; // only the FIRST case earns

      try {
        await db.$transaction([
          db.creditTransaction.create({
            data: {
              profileId: referral.referrerId,
              amount: CREDITS_PER_REFERRAL,
              reason: 'referralFirstCase',
              dedupeKey: `firstcase:${referral.id}`,
              metadata: { refereeId },
            },
          }),
          db.userProfile.update({
            where: { id: referral.referrerId },
            data: { reviewCredits: { increment: CREDITS_PER_REFERRAL } },
          }),
        ]);
        this.logger.log(
          `Referral credit: +${CREDITS_PER_REFERRAL} to ${referral.referrerId} (referral ${referral.id}).`,
        );
      } catch (error) {
        if (isUniqueViolation(error)) return; // already credited — idempotent no-op
        throw error;
      }
    });
  }

  /// Caller's credit balance + recent ledger entries.
  async getCredits(userId: string): Promise<CreditsSummary> {
    const result = await this.prisma.execute(async (db) => {
      const profile = await db.userProfile.findUnique({
        where: { id: userId },
        select: { reviewCredits: true },
      });
      const rows = await db.creditTransaction.findMany({
        where: { profileId: userId },
        orderBy: { createdAt: 'desc' },
        take: HISTORY_LIMIT,
        select: { amount: true, reason: true, createdAt: true },
      });
      return {
        balance: profile?.reviewCredits ?? 0,
        history: rows.map((r) => ({
          amount: r.amount,
          reason: r.reason,
          createdAt: r.createdAt.toISOString(),
        })),
      };
    });

    // No database (demo mode): an empty, non-persisted summary.
    return result ?? { balance: 0, history: [] };
  }

  /// Spend `VOUCHER_COST` credits to mint a WhatsApp advisor voucher. No cash:
  /// the voucher is a code the student shows a KPB advisor for an in-depth
  /// human review. Atomic + guarded so the balance can never go negative, and
  /// idempotent per `clientRef` (a retried tap reuses the dedupeKey → no-op).
  async redeemReviewVoucher(
    userId: string,
    clientRef: string,
  ): Promise<RedeemResult> {
    const result = await this.prisma.execute(async (db) => {
      // If this clientRef was already redeemed, return its voucher (idempotent).
      const prior = await db.creditTransaction.findUnique({
        where: { dedupeKey: `voucher:${clientRef}` },
        select: { metadata: true },
      });
      if (prior) {
        const profile = await db.userProfile.findUnique({
          where: { id: userId },
          select: { reviewCredits: true },
        });
        const meta = (prior.metadata ?? {}) as { voucherCode?: string };
        return {
          ok: true as const,
          balance: profile?.reviewCredits ?? 0,
          voucherCode: meta.voucherCode ?? generateVoucherCode(),
        };
      }

      const voucherCode = generateVoucherCode();
      try {
        const out = await db.$transaction(async (tx) => {
          // Conditional decrement: only succeeds when the balance covers it.
          const dec = await tx.userProfile.updateMany({
            where: { id: userId, reviewCredits: { gte: VOUCHER_COST } },
            data: { reviewCredits: { decrement: VOUCHER_COST } },
          });
          if (dec.count === 0) return null; // insufficient credits

          await tx.creditTransaction.create({
            data: {
              profileId: userId,
              amount: -VOUCHER_COST,
              reason: 'reviewVoucherRedeemed',
              dedupeKey: `voucher:${clientRef}`,
              metadata: { voucherCode },
            },
          });
          const profile = await tx.userProfile.findUnique({
            where: { id: userId },
            select: { reviewCredits: true },
          });
          return { balance: profile?.reviewCredits ?? 0, voucherCode };
        });

        if (!out) return { ok: false as const, reason: 'insufficient' as const };
        return { ok: true as const, balance: out.balance, voucherCode: out.voucherCode };
      } catch (error) {
        // Concurrent redeem with the same clientRef collided on dedupeKey.
        if (isUniqueViolation(error)) {
          const profile = await db.userProfile.findUnique({
            where: { id: userId },
            select: { reviewCredits: true },
          });
          return {
            ok: true as const,
            balance: profile?.reviewCredits ?? 0,
            voucherCode,
          };
        }
        throw error;
      }
    });

    return result ?? { ok: false, reason: 'unavailable' };
  }
}

/// Human-readable voucher code, unambiguous (no 0/O, 1/I) — easy to dictate to
/// a KPB advisor over WhatsApp. e.g. "KPB-7K4M-QH9N".
function generateVoucherCode(): string {
  const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  const bytes = randomBytes(8);
  let body = '';
  for (let i = 0; i < 8; i += 1) body += alphabet[bytes[i] % alphabet.length];
  return `KPB-${body.slice(0, 4)}-${body.slice(4, 8)}`;
}
