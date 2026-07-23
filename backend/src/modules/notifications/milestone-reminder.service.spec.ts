import { PrismaService } from '../prisma/prisma.service';
import { MilestoneReminderService } from './milestone-reminder.service';
import {
  DispatchInput,
  NotificationDispatchService,
} from './notification-dispatch.service';

const DAY = 24 * 60 * 60 * 1000;

/**
 * Guards KPB-64/KPB-155: the unified reminder cron fires only at the fixed
 * thresholds (incl. the new J-3), only for approved+active saved scholarships,
 * deep-links to /deadlines, and routes every reminder through the dispatcher
 * (durable feed + dedup + quiet-hours/cap) carrying both languages.
 */
describe('MilestoneReminderService', () => {
  function makeService(
    opts: {
      saved?: unknown[];
      scholarships?: unknown[];
      captureScholarshipWhere?: (where: Record<string, unknown>) => void;
    } = {},
  ) {
    const dispatched: DispatchInput[] = [];
    const client = {
      savedItem: { findMany: async () => opts.saved ?? [] },
      scholarship: {
        findMany: async ({ where }: { where: Record<string, unknown> }) => {
          opts.captureScholarshipWhere?.(where);
          return opts.scholarships ?? [];
        },
      },
      case: { findMany: async () => [] },
    };
    const prisma = {
      isEnabled: true,
      execute: async (fn: (c: typeof client) => unknown) => fn(client),
    } as unknown as PrismaService;
    const dispatch = {
      dispatch: async (input: DispatchInput) => {
        dispatched.push(input);
        return 'pushed' as const;
      },
    } as unknown as NotificationDispatchService;
    return {
      service: new MilestoneReminderService(prisma, dispatch),
      dispatched,
    };
  }

  const savedFor = (lang: string) => ({
    itemId: 'sch-1',
    itemType: 'scholarship',
    user: {
      id: 'u1',
      fullName: 'A',
      preferredLanguage: lang,
      countryOfResidence: 'SN',
    },
  });
  const scholarshipDueInDays = (days: number) => ({
    id: 'sch-1',
    nameFr: 'Bourse X',
    nameEn: 'Scholarship X',
    deadlineAt: new Date(Date.now() + days * DAY),
    countryNameFr: 'France',
    countryNameEn: 'France',
  });

  it('produces a J-7 reminder deep-linking to /deadlines', async () => {
    const { service } = makeService({
      saved: [savedFor('fr')],
      scholarships: [scholarshipDueInDays(7)],
    });
    const reminders = await service.collectDueReminders(new Date());
    expect(reminders).toHaveLength(1);
    expect(reminders[0].titleFr).toBe('Bourse à J-7');
    expect(reminders[0].route).toBe('/deadlines');
  });

  it('reminds at the new J-3 threshold', async () => {
    const { service } = makeService({
      saved: [savedFor('fr')],
      scholarships: [scholarshipDueInDays(3)],
    });
    const reminders = await service.collectDueReminders(new Date());
    expect(reminders).toHaveLength(1);
    expect(reminders[0].titleFr).toBe('Bourse à J-3');
  });

  it('does not remind off-threshold (J-8)', async () => {
    const { service } = makeService({
      saved: [savedFor('fr')],
      scholarships: [scholarshipDueInDays(8)],
    });
    const reminders = await service.collectDueReminders(new Date());
    expect(reminders).toHaveLength(0);
  });

  it('queries only approved + active scholarships', async () => {
    let where: Record<string, unknown> | undefined;
    const { service } = makeService({
      saved: [savedFor('fr')],
      scholarships: [scholarshipDueInDays(7)],
      captureScholarshipWhere: (w) => {
        where = w;
      },
    });
    await service.collectDueReminders(new Date());
    expect(where?.isActive).toBe(true);
    expect(where?.moderationStatus).toBe('approved');
  });

  it('dispatches with both languages, a stable dedupeKey, and residence', async () => {
    const { service, dispatched } = makeService({
      saved: [savedFor('en')],
      scholarships: [scholarshipDueInDays(7)],
    });
    await service.handleDailyMilestoneReminders();
    expect(dispatched).toHaveLength(1);
    const input = dispatched[0];
    expect(input.dedupeKey).toBe('deadline:scholarship:sch-1:u1:d7');
    expect(input.title.fr).toBe('Bourse à J-7');
    expect(input.title.en).toBe('Scholarship deadline in 7 days');
    expect(input.preferredLanguage).toBe('en');
    expect(input.countryOfResidence).toBe('SN');
    expect(input.scholarshipId).toBe('sch-1');
    expect(input.route).toBe('/deadlines');
  });
});
