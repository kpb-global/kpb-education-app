import { Injectable } from '@nestjs/common';

@Injectable()
export class CoachQuotaService {
  private readonly usage = new Map<string, { weekKey: string; count: number }>();

  private weekKeyUtc(): string {
    const now = new Date();
    const day = now.getUTCDay();
    const diff = day === 0 ? -6 : 1 - day;
    const monday = new Date(Date.UTC(
      now.getUTCFullYear(),
      now.getUTCMonth(),
      now.getUTCDate() + diff,
    ));
    return monday.toISOString().slice(0, 10);
  }

  getQuota(userId: string) {
    const weekKey = this.weekKeyUtc();
    const entry = this.usage.get(userId);
    const used = entry?.weekKey === weekKey ? entry.count : 0;
    return {
      quotaLimit: 5,
      quotaRemaining: Math.max(0, 5 - used),
      quotaResetAt: weekKey,
    };
  }

  consume(userId: string): { allowed: boolean; remaining: number } {
    const weekKey = this.weekKeyUtc();
    const entry = this.usage.get(userId) ?? { weekKey, count: 0 };
    const count = entry.weekKey === weekKey ? entry.count : 0;
    if (count >= 5) {
      return { allowed: false, remaining: 0 };
    }
    this.usage.set(userId, { weekKey, count: count + 1 });
    return { allowed: true, remaining: 4 - count };
  }
}
