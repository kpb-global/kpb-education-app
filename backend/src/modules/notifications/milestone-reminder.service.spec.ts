import { PrismaService } from '../prisma/prisma.service';
import { MilestoneReminderService } from './milestone-reminder.service';
import { OneSignalSenderService } from './onesignal-sender.service';

const DAY = 24 * 60 * 60 * 1000;

/**
 * Guards KPB-64: the unified reminder cron only fires at the fixed thresholds,
 * only for approved+active saved scholarships, localizes on preferredLanguage,
 * and deep-links to /deadlines.
 */
describe('MilestoneReminderService', () => {
  function makeService(
    opts: {
      saved?: unknown[];
      scholarships?: unknown[];
      captureScholarshipWhere?: (where: Record<string, unknown>) => void;
    } = {},
  ) {
    const sent: Array<{ title: string; body: string; data?: Record<string, string> }> = [];
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
    const push = {
      sendToUser: async (
        _userId: string,
        title: string,
        body: string,
        data?: Record<string, string>,
      ) => {
        sent.push({ title, body, data });
        return true;
      },
    } as unknown as OneSignalSenderService;
    return { service: new MilestoneReminderService(prisma, push), sent };
  }

  const savedFor = (lang: string) => ({
    itemId: 'sch-1',
    itemType: 'scholarship',
    user: { id: 'u1', fullName: 'A', preferredLanguage: lang },
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

  it('sends the English copy for an EN user', async () => {
    const { service, sent } = makeService({
      saved: [savedFor('en')],
      scholarships: [scholarshipDueInDays(7)],
    });
    await service.handleDailyMilestoneReminders();
    expect(sent).toHaveLength(1);
    expect(sent[0].title).toBe('Scholarship deadline in 7 days');
    expect(sent[0].data?.route).toBe('/deadlines');
  });
});
