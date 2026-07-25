// ─────────────────────────────────────────────────────────────────────────────
// Weekly match recompute (KPB-168).
//
// The "aha moment" — seeing your admission chances — fires once, right after
// onboarding, and never again. But matches DO move: the student completes their
// profile, or the catalog gains programmes. Nobody ever learns about it, so the
// most compelling moment in the product is a one-shot.
//
// This job recomputes each active student's top matches once a week and pushes
// ONLY when something actually moved:
//   • a different school entered (or left) the top 3, or
//   • an existing match changed zone (green / yellow / blue).
//
// Two rules keep it honest:
//   • no stored matches yet ⇒ NO push. A first computation is not a change, and
//     pushing on it would blast every never-matched user on the first run.
//   • nothing moved ⇒ nothing sent. Silence is the correct output.
//
// OFF by default (KPB_MATCH_RECOMPUTE_ENABLED). Push goes through
// NotificationDispatchService, so quiet hours, the daily cap, the durable feed
// and per-week dedup are inherited (KPB-155).
// ─────────────────────────────────────────────────────────────────────────────

import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';

import { NotificationDispatchService } from '../notifications/notification-dispatch.service';
import { PrismaService } from '../prisma/prisma.service';
import { MatchesService } from './matches.service';

const TOP_N = 3;
/// Bounds one weekly run. Anything above this is reported, never dropped
/// silently — a truncated run must be visible in the logs.
const MAX_USERS_PER_RUN = 500;

interface MatchSnapshot {
  programIds: string[];
  zoneByProgram: Map<string, string>;
}

@Injectable()
export class MatchRecomputeService {
  private readonly logger = new Logger(MatchRecomputeService.name);

  private readonly enabled =
    process.env.KPB_MATCH_RECOMPUTE_ENABLED === 'true';

  constructor(
    private readonly prisma: PrismaService,
    private readonly matches: MatchesService,
    private readonly dispatch: NotificationDispatchService,
  ) {}

  /** Wednesday 09:00 UTC — deliberately away from the Monday digest (KPB-163)
   *  and the 08:00 deadline reminders, so a student never gets three pushes in
   *  the same morning even before the frequency cap has to intervene. */
  @Cron('0 9 * * 3')
  async recomputeWeekly(now = new Date()): Promise<void> {
    if (!this.enabled || !this.prisma.isEnabled) return;

    const recipients =
      (await this.prisma.execute((db) =>
        db.userProfile.findMany({
          where: {
            accountType: 'student',
            // Only students with something to match on.
            OR: [
              { targetCountryIds: { isEmpty: false } },
              { fieldIds: { isEmpty: false } },
            ],
          },
          select: {
            id: true,
            preferredLanguage: true,
            countryOfResidence: true,
          },
          take: MAX_USERS_PER_RUN + 1,
        }),
      )) ?? [];

    const capped = recipients.length > MAX_USERS_PER_RUN;
    const batch = capped ? recipients.slice(0, MAX_USERS_PER_RUN) : recipients;
    if (capped) {
      this.logger.warn(
        `Match recompute capped at ${MAX_USERS_PER_RUN} students this run — ` +
          'raise MAX_USERS_PER_RUN or shard the job.',
      );
    }

    const weekKey = now.toISOString().slice(0, 10);
    let moved = 0;
    let unchanged = 0;
    let firstTime = 0;

    for (const r of batch) {
      try {
        const before = await this.snapshot(r.id);
        const result = await this.matches.ahaMoment(r.id, TOP_N);
        if (result.items.length === 0) continue;

        // A first computation is not a change.
        if (before.programIds.length === 0) {
          firstTime++;
          continue;
        }

        const after: MatchSnapshot = {
          programIds: result.items.map((i) => i.programId),
          zoneByProgram: new Map(
            result.items.map((i) => [i.programId, i.zone]),
          ),
        };
        if (!this.hasMoved(before, after)) {
          unchanged++;
          continue;
        }

        const top = result.items[0];
        const outcome = await this.dispatch.dispatch({
          userId: r.id,
          kind: 'match_moved',
          dedupeKey: `match-moved:${weekKey}:${r.id}`,
          title: {
            fr: '📈 Tes matches ont bougé',
            en: '📈 Your matches moved',
          },
          body: {
            fr: `${top.institutionName.fr} est maintenant dans ton top ${TOP_N}. Regarde tes nouvelles chances.`,
            en: `${top.institutionName.en} is now in your top ${TOP_N}. See your updated chances.`,
          },
          route: '/',
          data: { type: 'match_moved', institutionId: top.institutionId },
          preferredLanguage: r.preferredLanguage,
          countryOfResidence: r.countryOfResidence,
          now,
        });
        if (outcome === 'pushed') moved++;
      } catch {
        // One student's scoring failure must not abort the weekly run.
        this.logger.warn(`Match recompute failed for user ${r.id}.`);
      }
    }

    this.logger.log(
      `Match recompute: ${batch.length} scanned, ${moved} pushed, ` +
        `${unchanged} unchanged, ${firstTime} first-time (no push).`,
    );
  }

  /** The stored top-N for this user, i.e. what they were last shown. */
  private async snapshot(userId: string): Promise<MatchSnapshot> {
    const rows =
      (await this.prisma.execute((db) =>
        db.match.findMany({
          where: { userProfileId: userId },
          orderBy: { probability: 'desc' },
          take: TOP_N,
          select: { programId: true, zone: true },
        }),
      )) ?? [];
    return {
      programIds: rows.map((r) => r.programId),
      zoneByProgram: new Map(rows.map((r) => [r.programId, r.zone as string])),
    };
  }

  /** Moved = the set of schools changed, or a kept one changed zone. Ordering
   *  alone does NOT count: a reshuffle inside the same zone is not news. */
  private hasMoved(before: MatchSnapshot, after: MatchSnapshot): boolean {
    const beforeSet = new Set(before.programIds);
    const afterSet = new Set(after.programIds);
    if (beforeSet.size !== afterSet.size) return true;
    for (const id of afterSet) {
      if (!beforeSet.has(id)) return true;
    }
    for (const [id, zone] of after.zoneByProgram) {
      const previous = before.zoneByProgram.get(id);
      if (previous !== undefined && previous !== zone) return true;
    }
    return false;
  }
}
