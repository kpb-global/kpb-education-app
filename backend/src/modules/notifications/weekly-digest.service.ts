// ─────────────────────────────────────────────────────────────────────────────
// Weekly digest (KPB-163) — the Monday-morning recap.
//
// One personalized summary per student, sent Monday 08:00 in THEIR local time:
//   • new scholarships matching their target countries (created in the last 7d);
//   • saved scholarships whose deadline falls within 14 days;
//   • the next step on their active dossier.
//
// HONESTY RULE: a student with nothing new gets NOTHING. We never pad a digest
// to have something to send — an empty digest would train people to ignore it.
//
// Push goes through NotificationDispatchService (KPB-155), so quiet hours, the
// daily frequency cap, the durable in-app feed and per-week dedup are inherited.
// Email goes through CampaignMailService (Resend) — Mautic only manages
// newsletter SEGMENT membership and is not a transactional sender.
//
// OFF by default (KPB_WEEKLY_DIGEST_ENABLED) so nothing ships until ops enable it.
// ─────────────────────────────────────────────────────────────────────────────

import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';

import {
  localHourFor,
  localWeekdayFor,
  utcOffsetHoursForCountry,
} from '../../common/country-timezone';
import { PrismaService } from '../prisma/prisma.service';
import { CampaignMailService } from './campaign-mail.service';
import { NotificationDispatchService } from './notification-dispatch.service';

const DAY_MS = 24 * 60 * 60 * 1000;
const SEND_HOUR_LOCAL = 8;
const MONDAY = 1;
const NEW_SCHOLARSHIP_WINDOW_DAYS = 7;
const DEADLINE_WINDOW_DAYS = 14;
const MAX_ITEMS_PER_BLOCK = 3;

interface DigestScholarship {
  id: string;
  title: string;
  countryName: string | null;
  deadlineAt: Date | null;
}

interface DigestCase {
  id: string;
  referenceCode: string;
  nextStepTitle: string;
}

/** A week-fresh scholarship, carrying the country used to match a profile. */
interface FreshScholarship extends DigestScholarship {
  countryId: string;
}

/** What one student gets this week. Empty digest ⇒ nothing is sent. */
export interface WeeklyDigest {
  newScholarships: DigestScholarship[];
  upcomingDeadlines: DigestScholarship[];
  nextCaseStep: DigestCase | null;
}

export function isEmptyDigest(d: WeeklyDigest): boolean {
  return (
    d.newScholarships.length === 0 &&
    d.upcomingDeadlines.length === 0 &&
    d.nextCaseStep == null
  );
}

@Injectable()
export class WeeklyDigestService {
  private readonly logger = new Logger(WeeklyDigestService.name);

  private readonly enabled = process.env.KPB_WEEKLY_DIGEST_ENABLED === 'true';

  constructor(
    private readonly prisma: PrismaService,
    private readonly dispatch: NotificationDispatchService,
    private readonly mail: CampaignMailService,
  ) {}

  /**
   * Hourly tick. Sends only to students whose LOCAL time is Monday 08:00, so a
   * single daily-ish job serves every timezone without a per-country schedule.
   */
  @Cron('0 * * * *')
  async sendWeeklyDigests(now = new Date()): Promise<void> {
    if (!this.enabled || !this.prisma.isEnabled) return;

    const recipients =
      (await this.prisma.execute((db) =>
        db.userProfile.findMany({
          where: {
            accountType: 'student',
            NOT: { disabledNotificationTypes: { has: 'weekly_digest' } },
          },
          select: {
            id: true,
            email: true,
            fullName: true,
            preferredLanguage: true,
            countryOfResidence: true,
            targetCountryIds: true,
          },
        }),
      )) ?? [];

    // Only those for whom it is Monday 08:00 locally. Filtering FIRST keeps the
    // other 23 hourly runs to a single cheap query.
    const due = recipients.filter((r) => {
      const offset = utcOffsetHoursForCountry(r.countryOfResidence);
      return (
        localWeekdayFor(now, offset) === MONDAY &&
        localHourFor(now, offset) === SEND_HOUR_LOCAL
      );
    });
    if (due.length === 0) return;

    const dueIds = due.map((r) => r.id);
    const [fresh, savedByUser, caseByUser] = await Promise.all([
      this.fetchNewScholarships(now),
      this.fetchDeadlinesByUser(dueIds, now),
      this.fetchNextCaseByUser(dueIds),
    ]);

    const weekKey = this.weekKey(now);
    let sent = 0;
    let skippedEmpty = 0;

    for (const r of due) {
      const digest: WeeklyDigest = {
        newScholarships: this.matchToProfile(fresh, r.targetCountryIds),
        upcomingDeadlines: savedByUser.get(r.id) ?? [],
        nextCaseStep: caseByUser.get(r.id) ?? null,
      };

      // Honesty rule: nothing new ⇒ no digest at all.
      if (isEmptyDigest(digest)) {
        skippedEmpty++;
        continue;
      }

      const isEnglish = (r.preferredLanguage ?? '')
        .toLowerCase()
        .startsWith('en');
      const outcome = await this.dispatch.dispatch({
        userId: r.id,
        kind: 'weekly_digest',
        dedupeKey: `weekly-digest:${weekKey}:${r.id}`,
        title: {
          fr: '📌 Ton résumé de la semaine',
          en: '📌 Your week ahead',
        },
        body: {
          fr: this.summaryLine(digest, 'fr'),
          en: this.summaryLine(digest, 'en'),
        },
        route: this.primaryRoute(digest),
        data: { type: 'weekly_digest' },
        preferredLanguage: r.preferredLanguage,
        countryOfResidence: r.countryOfResidence,
        now,
      });

      // Email only when the push was actually recorded for this week — the
      // dedupe outcome means this user already got this week's digest.
      if (outcome !== 'deduped' && outcome !== 'skipped' && r.email) {
        await this.mail.send(
          r.email,
          isEnglish ? 'Your week ahead — KPB' : 'Ton résumé de la semaine — KPB',
          this.emailBody(digest, r.fullName, isEnglish ? 'en' : 'fr'),
        );
      }
      if (outcome === 'pushed') sent++;
    }

    this.logger.log(
      `Weekly digest: ${due.length} due, ${sent} pushed, ${skippedEmpty} skipped (nothing new).`,
    );
  }

  /** ISO-ish week bucket (the Monday date) — one digest per user per week. */
  private weekKey(now: Date): string {
    return now.toISOString().slice(0, 10);
  }

  private async fetchNewScholarships(now: Date): Promise<FreshScholarship[]> {
    const since = new Date(now.getTime() - NEW_SCHOLARSHIP_WINDOW_DAYS * DAY_MS);
    const rows = await this.prisma.execute((db) =>
      db.scholarship.findMany({
        where: {
          isActive: true,
          moderationStatus: 'approved',
          createdAt: { gte: since },
          OR: [{ deadlineAt: null }, { deadlineAt: { gt: now } }],
        },
        orderBy: { createdAt: 'desc' },
        take: 30,
        select: {
          id: true,
          nameFr: true,
          nameEn: true,
          countryId: true,
          countryNameFr: true,
          deadlineAt: true,
        },
      }),
    );
    return (rows ?? []).map((r) => ({
      id: r.id,
      title: r.nameFr,
      countryName: r.countryNameFr,
      deadlineAt: r.deadlineAt,
      countryId: r.countryId,
    }));
  }

  /** A student's target countries filter the week's new scholarships; a student
   *  who set none sees them all (better than an empty digest). */
  private matchToProfile(
    fresh: FreshScholarship[],
    targetCountryIds: string[],
  ): DigestScholarship[] {
    const wanted = new Set(targetCountryIds ?? []);
    const matched =
      wanted.size === 0
        ? fresh
        : fresh.filter((s) => wanted.has(s.countryId));
    return matched.slice(0, MAX_ITEMS_PER_BLOCK);
  }

  private async fetchDeadlinesByUser(
    userIds: string[],
    now: Date,
  ): Promise<Map<string, DigestScholarship[]>> {
    const byUser = new Map<string, DigestScholarship[]>();
    if (userIds.length === 0) return byUser;

    const saved =
      (await this.prisma.execute((db) =>
        db.savedItem.findMany({
          where: { itemType: 'scholarship', userId: { in: userIds } },
          select: { userId: true, itemId: true },
        }),
      )) ?? [];
    if (saved.length === 0) return byUser;

    const horizon = new Date(now.getTime() + DEADLINE_WINDOW_DAYS * DAY_MS);
    const rows =
      (await this.prisma.execute((db) =>
        db.scholarship.findMany({
          where: {
            id: { in: Array.from(new Set(saved.map((s) => s.itemId))) },
            isActive: true,
            moderationStatus: 'approved',
            deadlineAt: { gte: now, lte: horizon },
          },
          orderBy: { deadlineAt: 'asc' },
          select: {
            id: true,
            nameFr: true,
            countryNameFr: true,
            deadlineAt: true,
            // Confirmée ou projetée ? Le bloc « ÉCHÉANCES SOUS 14 JOURS »
            // imprime la date brute, donc il ne peut lister que du confirmé.
            cycles: {
              orderBy: { academicYear: 'desc' },
              take: 1,
              select: { dateConfidence: true },
            },
          },
        }),
      )) ?? [];

    const byId = new Map(rows.map((r) => [r.id, r]));
    for (const s of saved) {
      const row = byId.get(s.itemId);
      if (!row) continue;
      // Une date ESTIMÉE sous un titre « ÉCHÉANCES SOUS 14 JOURS » est une
      // affirmation fausse : `deadlineAt` vient alors de `estimatedCloseAt`.
      // Même règle que les rappels J-30/…/J-1 ; « pas de cycle » vaut confirmé.
      if (row.cycles[0]?.dateConfidence === 'estimated') continue;
      const list = byUser.get(s.userId) ?? [];
      if (list.length >= MAX_ITEMS_PER_BLOCK) continue;
      list.push({
        id: row.id,
        title: row.nameFr,
        countryName: row.countryNameFr,
        deadlineAt: row.deadlineAt,
      });
      byUser.set(s.userId, list);
    }
    return byUser;
  }

  private async fetchNextCaseByUser(
    userIds: string[],
  ): Promise<Map<string, DigestCase>> {
    const byUser = new Map<string, DigestCase>();
    if (userIds.length === 0) return byUser;

    const rows =
      (await this.prisma.execute((db) =>
        db.case.findMany({
          where: {
            userId: { in: userIds },
            status: { notIn: ['completed', 'rejected', 'cancelled'] },
          },
          orderBy: { updatedAt: 'desc' },
          select: {
            id: true,
            userId: true,
            referenceCode: true,
            nextStepTitle: true,
          },
        }),
      )) ?? [];

    for (const row of rows) {
      // Most recently updated active dossier wins.
      if (byUser.has(row.userId)) continue;
      byUser.set(row.userId, {
        id: row.id,
        referenceCode: row.referenceCode,
        nextStepTitle: row.nextStepTitle,
      });
    }
    return byUser;
  }

  /** Push body: counts only, so it stays short and truthful. */
  private summaryLine(d: WeeklyDigest, lang: 'fr' | 'en'): string {
    const parts: string[] = [];
    if (lang === 'fr') {
      if (d.newScholarships.length) {
        parts.push(
          `${d.newScholarships.length} nouvelle${d.newScholarships.length > 1 ? 's' : ''} bourse${d.newScholarships.length > 1 ? 's' : ''} pour toi`,
        );
      }
      if (d.upcomingDeadlines.length) {
        parts.push(
          `${d.upcomingDeadlines.length} échéance${d.upcomingDeadlines.length > 1 ? 's' : ''} sous 14 jours`,
        );
      }
      if (d.nextCaseStep) parts.push('1 action sur ton dossier');
      return `${parts.join(' · ')}.`;
    }
    if (d.newScholarships.length) {
      parts.push(
        `${d.newScholarships.length} new scholarship${d.newScholarships.length > 1 ? 's' : ''} for you`,
      );
    }
    if (d.upcomingDeadlines.length) {
      parts.push(
        `${d.upcomingDeadlines.length} deadline${d.upcomingDeadlines.length > 1 ? 's' : ''} within 14 days`,
      );
    }
    if (d.nextCaseStep) parts.push('1 action on your dossier');
    return `${parts.join(' · ')}.`;
  }

  /** Deep-link the push at the most actionable block. */
  private primaryRoute(d: WeeklyDigest): string {
    if (d.upcomingDeadlines.length) return '/deadlines';
    if (d.newScholarships.length) {
      return `/scholarships/${d.newScholarships[0].id}`;
    }
    return d.nextCaseStep ? `/cases/${d.nextCaseStep.id}` : '/';
  }

  /** Plain-text email (CampaignMailService sends text). `kpb://` links open the
   *  app directly on mobile, which is where this audience reads email. */
  private emailBody(
    d: WeeklyDigest,
    fullName: string | null,
    lang: 'fr' | 'en',
  ): string {
    const first = (fullName ?? '').trim().split(/\s+/)[0] || '';
    const lines: string[] = [];
    const fr = lang === 'fr';

    lines.push(fr ? `Salut ${first},`.trim() : `Hi ${first},`.trim());
    lines.push('');

    if (d.newScholarships.length) {
      lines.push(fr ? 'NOUVELLES BOURSES POUR TOI' : 'NEW SCHOLARSHIPS FOR YOU');
      for (const s of d.newScholarships) {
        lines.push(
          `- ${s.title}${s.countryName ? ` (${s.countryName})` : ''} → kpb://scholarships/${s.id}`,
        );
      }
      lines.push('');
    }

    if (d.upcomingDeadlines.length) {
      lines.push(fr ? 'ÉCHÉANCES SOUS 14 JOURS' : 'DEADLINES WITHIN 14 DAYS');
      for (const s of d.upcomingDeadlines) {
        const when = s.deadlineAt
          ? s.deadlineAt.toISOString().slice(0, 10)
          : '—';
        lines.push(`- ${when} · ${s.title} → kpb://scholarships/${s.id}`);
      }
      lines.push('');
    }

    if (d.nextCaseStep) {
      lines.push(fr ? 'TON DOSSIER' : 'YOUR DOSSIER');
      lines.push(
        `- ${d.nextCaseStep.referenceCode}: ${d.nextCaseStep.nextStepTitle} → kpb://cases/${d.nextCaseStep.id}`,
      );
      lines.push('');
    }

    lines.push(
      fr
        ? 'Pour ne plus recevoir ce résumé : Profil → Notifications dans l\'app.'
        : 'To stop receiving this digest: Profile → Notifications in the app.',
    );
    lines.push('— KPB Education');
    return lines.join('\n');
  }
}
