import { Test, TestingModule } from '@nestjs/testing';

import { PrismaService } from '../prisma/prisma.service';
import { MilestoneReminderService } from './milestone-reminder.service';
import { OneSignalSenderService } from './onesignal-sender.service';

function makeDb() {
  return {
    savedItem: {
      findMany: jest.fn(),
    },
    scholarship: {
      findMany: jest.fn(),
    },
    case: {
      findMany: jest.fn(),
    },
  };
}

describe('MilestoneReminderService', () => {
  let service: MilestoneReminderService;
  let db: ReturnType<typeof makeDb>;

  const prismaMock = {
    isEnabled: true,
    execute: jest.fn(),
  };
  const pushMock = {
    sendToUser: jest.fn(),
  };

  beforeEach(async () => {
    db = makeDb();
    prismaMock.isEnabled = true;
    prismaMock.execute.mockImplementation(
      (operation: (client: unknown) => unknown) => operation(db),
    );

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        MilestoneReminderService,
        { provide: PrismaService, useValue: prismaMock },
        { provide: OneSignalSenderService, useValue: pushMock },
      ],
    }).compile();

    service = module.get<MilestoneReminderService>(MilestoneReminderService);
    jest.clearAllMocks();
    prismaMock.execute.mockImplementation(
      (operation: (client: unknown) => unknown) => operation(db),
    );
  });

  it('collects saved scholarship and case milestone reminders with deep-links', async () => {
    const now = new Date('2026-06-30T10:00:00Z');
    db.savedItem.findMany.mockResolvedValue([
      {
        itemId: 'sch-1',
        user: {
          id: 'user-1',
          fullName: 'Awa',
          preferredLanguage: 'fr',
        },
      },
    ]);
    db.scholarship.findMany.mockResolvedValue([
      {
        id: 'sch-1',
        nameFr: 'Bourse Canada',
        nameEn: 'Canada scholarship',
        countryNameFr: 'Canada',
        countryNameEn: 'Canada',
        deadlineAt: new Date('2026-07-07T12:00:00Z'),
      },
    ]);
    db.case.findMany.mockResolvedValue([
      {
        id: 'case-1',
        referenceCode: 'KPB-2026-001',
        nextStepTitle: 'Envoyer le passeport',
        scheduledAt: null,
        user: {
          id: 'user-1',
          fullName: 'Awa',
          preferredLanguage: 'fr',
        },
        tasks: [
          {
            id: 'task-1',
            title: 'Passeport',
            dueAt: new Date('2026-07-03T12:00:00Z'),
          },
        ],
      },
    ]);

    const reminders = await service.collectDueReminders(now);

    expect(reminders).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          route: '/deadlines',
          data: expect.objectContaining({ scholarshipId: 'sch-1' }),
        }),
        expect.objectContaining({
          route: '/cases/case-1',
          data: expect.objectContaining({ taskId: 'task-1' }),
        }),
      ]),
    );
  });

  it('sends localized English push copy with the tracker route', async () => {
    const now = new Date('2026-06-30T10:00:00Z');
    jest.useFakeTimers().setSystemTime(now);
    db.savedItem.findMany.mockResolvedValue([
      {
        itemId: 'sch-1',
        user: {
          id: 'user-1',
          fullName: 'Awa',
          preferredLanguage: 'en',
        },
      },
    ]);
    db.scholarship.findMany.mockResolvedValue([
      {
        id: 'sch-1',
        nameFr: 'Bourse Canada',
        nameEn: 'Canada scholarship',
        countryNameFr: 'Canada',
        countryNameEn: 'Canada',
        deadlineAt: new Date('2026-07-07T12:00:00Z'),
      },
    ]);
    db.case.findMany.mockResolvedValue([]);

    await service.handleDailyMilestoneReminders();

    expect(pushMock.sendToUser).toHaveBeenCalledWith(
      'user-1',
      'Scholarship deadline in 7 days',
      expect.stringContaining('Canada scholarship'),
      expect.objectContaining({
        route: '/deadlines',
        reminderType: 'saved_scholarship',
      }),
    );
    jest.useRealTimers();
  });
});
