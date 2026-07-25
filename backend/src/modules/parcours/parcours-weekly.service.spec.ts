import { NotificationDispatchService } from '../notifications/notification-dispatch.service';
import { PrismaService } from '../prisma/prisma.service';
import { ParcoursWeeklyService } from './parcours-weekly.service';
import { ParcoursDto, ParcoursService } from './parcours.service';

/**
 * Guards the KPB-169 push half: Sunday 18h LOCAL, opt-out honoured, and — the
 * rule that keeps the slot editorial — nothing at all when no story is
 * featured.
 */
describe('ParcoursWeeklyService', () => {
  const ORIGINAL = process.env.KPB_PARCOURS_WEEKLY_ENABLED;
  afterEach(() => {
    if (ORIGINAL === undefined) delete process.env.KPB_PARCOURS_WEEKLY_ENABLED;
    else process.env.KPB_PARCOURS_WEEKLY_ENABLED = ORIGINAL;
  });

  const story = (over: Partial<ParcoursDto> = {}): ParcoursDto =>
    ({
      id: 's1',
      slug: 'awa-ingenieure',
      kind: 'video',
      personName: 'Awa Diallo',
      hook: { fr: 'De Niamey à Rennes en 18 mois', en: 'Niamey to Rennes' },
      title: { fr: 'Ingénieure au Canada', en: 'Engineer in Canada' },
      ...over,
    }) as ParcoursDto;

  function make(opts: {
    recipients?: Array<Record<string, unknown>>;
    pick?: ParcoursDto | null;
    enabled?: boolean;
  }) {
    if (opts.enabled ?? true) process.env.KPB_PARCOURS_WEEKLY_ENABLED = 'true';
    else delete process.env.KPB_PARCOURS_WEEKLY_ENABLED;

    const profileWheres: Array<Record<string, unknown>> = [];
    const client = {
      userProfile: {
        findMany: async ({ where }: { where: Record<string, unknown> }) => {
          profileWheres.push(where);
          return opts.recipients ?? [];
        },
      },
    };
    const prisma = {
      isEnabled: true,
      execute: async (fn: (c: typeof client) => unknown) => fn(client),
    } as unknown as PrismaService;

    let picks = 0;
    const parcours = {
      pickStoryOfWeek: async () => {
        picks += 1;
        return opts.pick === undefined ? story() : opts.pick;
      },
      weekKey: () => '2026-W2951',
    } as unknown as ParcoursService;

    const dispatched: Array<Record<string, unknown>> = [];
    const dispatch = {
      dispatch: async (input: Record<string, unknown>) => {
        dispatched.push(input);
        return 'pushed' as const;
      },
    } as unknown as NotificationDispatchService;

    return {
      service: new ParcoursWeeklyService(prisma, parcours, dispatch),
      dispatched,
      profileWheres,
      pickCount: () => picks,
    };
  }

  // 2026-07-26 is a Sunday. 18:00 UTC == 18:00 local in Niger (UTC+1 is SN?
  // no: SN/NE handled below via explicit offsets).
  const sunday18Utc = new Date('2026-07-26T18:00:00.000Z');

  it('does nothing when the flag is off', async () => {
    const { service, dispatched } = make({
      enabled: false,
      recipients: [{ id: 'u1', preferredLanguage: 'fr', countryOfResidence: 'SN' }],
    });
    await service.sendWeeklyPush(sunday18Utc);
    expect(dispatched).toEqual([]);
  });

  it('filters the recipient query on the parcours_weekly opt-out', async () => {
    const { service, profileWheres } = make({ recipients: [] });
    await service.sendWeeklyPush(sunday18Utc);
    expect(profileWheres[0]).toMatchObject({
      accountType: 'student',
      NOT: { disabledNotificationTypes: { has: 'parcours_weekly' } },
    });
  });

  it('pushes only to students whose local time is Sunday 18h', async () => {
    const { service, dispatched } = make({
      recipients: [
        // Senegal is UTC+0 → local Sunday 18h. In window.
        { id: 'u-sn', preferredLanguage: 'fr', countryOfResidence: 'SN' },
        // Niger is UTC+1 → local Sunday 19h. Out of window.
        { id: 'u-ne', preferredLanguage: 'fr', countryOfResidence: 'NE' },
      ],
    });
    await service.sendWeeklyPush(sunday18Utc);
    expect(dispatched).toHaveLength(1);
    expect(dispatched[0]).toMatchObject({
      userId: 'u-sn',
      kind: 'parcours_weekly',
      dedupeKey: 'parcours-weekly:2026-W2951:u-sn',
      route: '/parcours/awa-ingenieure',
      data: { type: 'parcours_weekly', storySlug: 'awa-ingenieure' },
    });
    expect(String((dispatched[0].body as { fr: string }).fr)).toBe(
      'Awa Diallo — De Niamey à Rennes en 18 mois',
    );
  });

  it('sends nothing on a weekday', async () => {
    const { service, dispatched } = make({
      recipients: [{ id: 'u-sn', preferredLanguage: 'fr', countryOfResidence: 'SN' }],
    });
    await service.sendWeeklyPush(new Date('2026-07-29T18:00:00.000Z'));
    expect(dispatched).toEqual([]);
  });

  it('sends nothing — and never looks up a story — when nobody is in the window', async () => {
    const { service, dispatched, pickCount } = make({
      recipients: [{ id: 'u-ne', preferredLanguage: 'fr', countryOfResidence: 'NE' }],
    });
    await service.sendWeeklyPush(sunday18Utc);
    expect(dispatched).toEqual([]);
    expect(pickCount()).toBe(0);
  });

  it('sends nothing when no story is featured', async () => {
    const { service, dispatched } = make({
      recipients: [{ id: 'u-sn', preferredLanguage: 'fr', countryOfResidence: 'SN' }],
      pick: null,
    });
    await service.sendWeeklyPush(sunday18Utc);
    expect(dispatched).toEqual([]);
  });

  it('falls back to the title when the story has no hook', async () => {
    const { service, dispatched } = make({
      recipients: [{ id: 'u-sn', preferredLanguage: 'fr', countryOfResidence: 'SN' }],
      pick: story({ hook: { fr: '  ', en: '' } }),
    });
    await service.sendWeeklyPush(sunday18Utc);
    expect(String((dispatched[0].body as { fr: string }).fr)).toBe(
      'Awa Diallo — Ingénieure au Canada',
    );
  });
});
