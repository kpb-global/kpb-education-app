import { PrismaService } from '../prisma/prisma.service';
import { CampaignMailService } from './campaign-mail.service';
import { NotificationDispatchService } from './notification-dispatch.service';
import { WeeklyDigestService } from './weekly-digest.service';

const DAY = 24 * 60 * 60 * 1000;

/**
 * Guards KPB-163: the digest fires only Monday 08:00 LOCAL, honours the opt-out
 * filter, is personalized by target country, and — the load-bearing rule —
 * NEVER sends an empty digest.
 */
describe('WeeklyDigestService', () => {
  const ORIGINAL = process.env.KPB_WEEKLY_DIGEST_ENABLED;
  afterEach(() => {
    if (ORIGINAL === undefined) {
      delete process.env.KPB_WEEKLY_DIGEST_ENABLED;
    } else {
      process.env.KPB_WEEKLY_DIGEST_ENABLED = ORIGINAL;
    }
  });

  function make(
    opts: {
      recipients?: unknown[];
      scholarships?: unknown[];
      saved?: unknown[];
      cases?: unknown[];
      enabled?: boolean;
    } = {},
  ) {
    if (opts.enabled ?? true) {
      process.env.KPB_WEEKLY_DIGEST_ENABLED = 'true';
    } else {
      delete process.env.KPB_WEEKLY_DIGEST_ENABLED;
    }

    const profileWheres: Array<Record<string, unknown>> = [];
    const client = {
      userProfile: {
        findMany: async ({ where }: { where: Record<string, unknown> }) => {
          profileWheres.push(where);
          return opts.recipients ?? [];
        },
      },
      scholarship: { findMany: async () => opts.scholarships ?? [] },
      savedItem: { findMany: async () => opts.saved ?? [] },
      case: { findMany: async () => opts.cases ?? [] },
    };
    const prisma = {
      isEnabled: true,
      execute: async (fn: (c: typeof client) => unknown) => fn(client),
    } as unknown as PrismaService;

    const dispatched: Array<Record<string, unknown>> = [];
    const dispatch = {
      dispatch: async (input: Record<string, unknown>) => {
        dispatched.push(input);
        return 'pushed' as const;
      },
    } as unknown as NotificationDispatchService;

    const emails: Array<{ to: string; subject: string; text: string }> = [];
    const mail = {
      send: async (to: string, subject: string, text: string) => {
        emails.push({ to, subject, text });
        return true;
      },
    } as unknown as CampaignMailService;

    return {
      service: new WeeklyDigestService(prisma, dispatch, mail),
      dispatched,
      emails,
      profileWheres,
    };
  }

  const student = (over: Record<string, unknown> = {}) => ({
    id: 'u1',
    email: 'u1@example.com',
    fullName: 'Awa Diallo',
    preferredLanguage: 'fr',
    countryOfResidence: 'SN', // UTC+0
    targetCountryIds: [] as string[],
    ...over,
  });

  // `cycles` : voir milestone-reminder.service.spec.ts — Prisma rend toujours
  // le tableau, la doublure aussi.
  const freshScholarship = (over: Record<string, unknown> = {}) => ({
    id: 's1',
    nameFr: 'Bourse Nouvelle',
    nameEn: 'New Scholarship',
    countryId: 'fra',
    countryNameFr: 'France',
    deadlineAt: new Date(Date.now() + 40 * DAY),
    cycles: [] as Array<{ dateConfidence: 'confirmed' | 'estimated' }>,
    ...over,
  });

  // 2026-07-27 is a Monday. 08:00 UTC = 08:00 local at UTC+0 (Senegal).
  const mondayMorning = new Date('2026-07-27T08:00:00Z');

  it('sends a digest with new matched scholarships (push + email)', async () => {
    const { service, dispatched, emails, profileWheres } = make({
      recipients: [student()],
      scholarships: [freshScholarship()],
    });

    await service.sendWeeklyDigests(mondayMorning);

    // Opt-out is enforced in the recipient query.
    expect(profileWheres[0]).toMatchObject({
      accountType: 'student',
      NOT: { disabledNotificationTypes: { has: 'weekly_digest' } },
    });
    expect(dispatched).toHaveLength(1);
    expect(dispatched[0]).toMatchObject({
      userId: 'u1',
      kind: 'weekly_digest',
      dedupeKey: 'weekly-digest:2026-07-27:u1',
    });
    // The body reports real counts, never filler.
    expect(String((dispatched[0].body as { fr: string }).fr)).toContain(
      '1 nouvelle bourse',
    );
    // Email carries the deep link to the actual scholarship.
    expect(emails).toHaveLength(1);
    expect(emails[0].to).toBe('u1@example.com');
    expect(emails[0].text).toContain('kpb://scholarships/s1');
  });

  it('HONESTY RULE: sends nothing when the student has nothing new', async () => {
    const { service, dispatched, emails } = make({
      recipients: [student()],
      scholarships: [], // no new scholarships
      saved: [], // no deadlines
      cases: [], // no active dossier
    });

    await service.sendWeeklyDigests(mondayMorning);

    expect(dispatched).toHaveLength(0);
    expect(emails).toHaveLength(0);
  });

  it('filters new scholarships by the student target countries', async () => {
    const { service, dispatched } = make({
      recipients: [student({ targetCountryIds: ['can'] })],
      scholarships: [freshScholarship({ countryId: 'fra' })], // not wanted
    });

    await service.sendWeeklyDigests(mondayMorning);

    // Country mismatch ⇒ empty digest ⇒ nothing sent (honesty rule again).
    expect(dispatched).toHaveLength(0);
  });

  it('does not send outside Monday 08:00 local time', async () => {
    const cases = [
      new Date('2026-07-27T12:00:00Z'), // Monday, but 12:00 local
      new Date('2026-07-28T08:00:00Z'), // Tuesday 08:00 local
    ];
    for (const now of cases) {
      const { service, dispatched } = make({
        recipients: [student()],
        scholarships: [freshScholarship()],
      });
      await service.sendWeeklyDigests(now);
      expect(dispatched).toHaveLength(0);
    }
  });

  it('respects each timezone: UTC+1 is served an hour later', async () => {
    // 07:00 UTC = 08:00 local in Niger (UTC+1) — the Niger student is due,
    // the Senegal one (UTC+0, local 07:00) is not.
    const { service, dispatched } = make({
      recipients: [
        student({ id: 'u-sn', countryOfResidence: 'SN' }),
        student({ id: 'u-ne', countryOfResidence: 'NE' }),
      ],
      scholarships: [freshScholarship()],
    });

    await service.sendWeeklyDigests(new Date('2026-07-27T07:00:00Z'));

    expect(dispatched).toHaveLength(1);
    expect(dispatched[0].userId).toBe('u-ne');
  });

  it('is a no-op while the flag is off', async () => {
    const { service, dispatched, emails } = make({
      enabled: false,
      recipients: [student()],
      scholarships: [freshScholarship()],
    });

    await service.sendWeeklyDigests(mondayMorning);

    expect(dispatched).toHaveLength(0);
    expect(emails).toHaveLength(0);
  });
});
