import { BadRequestException } from '@nestjs/common';

import { AmbassadorService } from './ambassador.service';
import { PrismaService } from '../prisma/prisma.service';

/**
 * The Ambassadeur surface must render before activation (sample preview) and
 * from real data after. Withdrawals are recorded requests (no external
 * transfer) and must enforce the 20 000 FCFA floor + available balance.
 */
describe('AmbassadorService', () => {
  const nullPrisma = { execute: async () => null } as unknown as PrismaService;

  function dbPrisma(
    ambassador: Record<string, unknown> | null,
    // Sum returned by commission.aggregate after claiming (the batched total).
    claimedSumFCFA = 0,
  ) {
    const calls = {
      withdrawalCreate: [] as unknown[],
      withdrawalUpdate: [] as unknown[],
      commissionUpdateMany: [] as unknown[],
    };
    const client = {
      ambassador: {
        findUnique: async () => ambassador,
        findMany: async () => (ambassador ? [ambassador] : []),
        create: async ({ data }: { data: Record<string, unknown> }) => ({ id: 'amb-new', ...data }),
      },
      withdrawal: {
        create: async ({ data }: { data: Record<string, unknown> }) => {
          calls.withdrawalCreate.push(data);
          return { id: 'wd-1', ...data };
        },
        update: async ({ where, data }: { where: { id: string }; data: Record<string, unknown> }) => {
          calls.withdrawalUpdate.push({ where, data });
          return { id: where.id, status: 'requested', ...data };
        },
      },
      commission: {
        updateMany: async (args: unknown) => {
          calls.commissionUpdateMany.push(args);
          return { count: 1 };
        },
        aggregate: async () => ({ _sum: { amountFCFA: claimedSumFCFA } }),
      },
      $transaction: async (fn: (tx: unknown) => unknown) => fn(client),
    };
    const prisma = {
      execute: async (fn: (c: typeof client) => unknown) => fn(client),
    } as unknown as PrismaService;
    return { prisma, calls };
  }

  describe('getDashboard — sample preview (not activated / DB down)', () => {
    it('returns the Binta Sarr sample with the design headline figures', async () => {
      const svc = new AmbassadorService(nullPrisma);
      const d = await svc.getDashboard('profile-x');
      expect(d.activated).toBe(false);
      expect(d.isSample).toBe(true);
      expect(d.ambassador.code).toBe('KTOU-BS-7c21');
      expect(d.ambassador.initials).toBe('BS');
      expect(d.stats).toEqual({ activeReferrals: 12, placed: 3, earnedFCFA: 117000 });
      expect(d.objective).toEqual({ target: 15, current: 12, bonusFCFA: 10000 });
      expect(d.balanceFCFA).toBe(47000);
      expect(d.referrals).toHaveLength(5);
      expect(d.leaderboard.find((l) => l.isMe)?.rank).toBe(2);
      expect(d.minWithdrawalFCFA).toBe(20000);
    });

    it('maps reward tiers (signup 1 000 / placed 35 000)', async () => {
      const svc = new AmbassadorService(nullPrisma);
      const d = await svc.getDashboard('p');
      const byReason = Object.fromEntries(d.rewards.map((r) => [r.reason, r.amountFCFA]));
      expect(byReason['referral_signup']).toBe(1000);
      expect(byReason['referral_placed']).toBe(35000);
    });
  });

  describe('getDashboard — real data', () => {
    it('derives stats from the ambassador row', async () => {
      const amb = {
        id: 'amb-1',
        userProfileId: 'p1',
        code: 'KTOU-AL-1a2b',
        displayName: 'Awa Lo',
        campus: 'UCAD',
        city: 'Dakar',
        payoutMethod: 'wave',
        payoutAccount: '+221770000000',
        monthlyObjective: 15,
        monthlyBonusFCFA: 10000,
        referrals: [
          { id: 'r1', refereeName: 'X', status: 'placed', note: '', signedUpAt: new Date() },
          { id: 'r2', refereeName: 'Y', status: 'signed_up', note: '', signedUpAt: new Date() },
        ],
        commissions: [
          { id: 'c1', referralId: 'r1', reason: 'referral_placed', label: '', amountFCFA: 35000, earnedAt: new Date(), withdrawalId: null },
        ],
        withdrawals: [],
      };
      const { prisma } = dbPrisma(amb);
      const svc = new AmbassadorService(prisma);
      const d = await svc.getDashboard('p1');
      expect(d.activated).toBe(true);
      expect(d.isSample).toBe(false);
      expect(d.stats.placed).toBe(1);
      expect(d.stats.activeReferrals).toBe(2);
      expect(d.stats.earnedFCFA).toBe(35000);
      expect(d.balanceFCFA).toBe(35000); // unbatched commission
      expect(d.referrals[0].gainFCFA).toBe(35000);
    });
  });

  describe('requestWithdrawal (full balance only)', () => {
    const ambWithBalance = {
      id: 'amb-1',
      payoutMethod: 'wave',
      payoutAccount: '+221770000000',
      commissions: [{ amountFCFA: 47000, withdrawalId: null }],
    };

    it('rejects when not activated', async () => {
      const svc = new AmbassadorService(nullPrisma);
      await expect(svc.requestWithdrawal('p')).rejects.toBeInstanceOf(
        BadRequestException,
      );
    });

    it('rejects when the available balance is below the 20 000 FCFA floor', async () => {
      const { prisma } = dbPrisma({
        ...ambWithBalance,
        commissions: [{ amountFCFA: 5000, withdrawalId: null }],
      });
      const svc = new AmbassadorService(prisma);
      await expect(svc.requestWithdrawal('p1')).rejects.toBeInstanceOf(
        BadRequestException,
      );
    });

    it('pays out exactly the claimed total (amount = batched sum) and batches once', async () => {
      const { prisma, calls } = dbPrisma(ambWithBalance, 47000);
      const svc = new AmbassadorService(prisma);
      const res = await svc.requestWithdrawal('p1');
      expect(res.status).toBe('requested');
      expect(res.amountFCFA).toBe(47000);
      expect(res.etaHours).toBe(48);
      expect(calls.withdrawalCreate).toHaveLength(1);
      expect(calls.commissionUpdateMany).toHaveLength(1);
      // The recorded amount is set from the aggregate of claimed commissions.
      expect((calls.withdrawalUpdate[0] as { data: { amountFCFA: number } }).data.amountFCFA)
          .toBe(47000);
    });

    it('rolls back when a concurrent request already claimed the balance (0 claimed)', async () => {
      // Pre-check passes (unbatched 47000) but the in-tx aggregate sees 0 —
      // i.e. another request claimed the commissions first.
      const { prisma } = dbPrisma(ambWithBalance, 0);
      const svc = new AmbassadorService(prisma);
      await expect(svc.requestWithdrawal('p1')).rejects.toBeInstanceOf(
        BadRequestException,
      );
    });
  });
});
