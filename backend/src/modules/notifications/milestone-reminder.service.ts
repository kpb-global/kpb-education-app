import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';

import { PrismaService } from '../prisma/prisma.service';
import { OneSignalSenderService } from './onesignal-sender.service';

const DAY_MS = 24 * 60 * 60 * 1000;
const TRACKER_ROUTE = '/deadlines';
const SCHOLARSHIP_REMINDER_DAYS = new Set([30, 14, 7, 1, 0]);
const CASE_REMINDER_DAYS = new Set([7, 3, 1, 0]);

interface ReminderRecipient {
  id: string;
  fullName: string | null;
  preferredLanguage: string;
}

interface DueReminder {
  user: ReminderRecipient;
  titleFr: string;
  titleEn: string;
  bodyFr: string;
  bodyEn: string;
  route: string;
  data: Record<string, string>;
}

@Injectable()
export class MilestoneReminderService {
  private readonly logger = new Logger(MilestoneReminderService.name);

  constructor(
    private readonly prismaService: PrismaService,
    private readonly pushService: OneSignalSenderService,
  ) {}

  @Cron('0 8 * * *')
  async handleDailyMilestoneReminders() {
    if (!this.prismaService.isEnabled) return;

    const reminders = await this.collectDueReminders(new Date());
    for (const reminder of reminders) {
      const isEnglish = (reminder.user.preferredLanguage ?? '')
        .toLowerCase()
        .startsWith('en');
      await this.pushService.sendToUser(
        reminder.user.id,
        isEnglish ? reminder.titleEn : reminder.titleFr,
        isEnglish ? reminder.bodyEn : reminder.bodyFr,
        {
          ...reminder.data,
          route: reminder.route,
        },
      );
    }

    if (reminders.length > 0) {
      this.logger.log(`Sent ${reminders.length} milestone reminders.`);
    }
  }

  async collectDueReminders(now: Date): Promise<DueReminder[]> {
    if (!this.prismaService.isEnabled) return [];

    const [scholarshipReminders, caseReminders] = await Promise.all([
      this.collectSavedScholarshipReminders(now),
      this.collectCaseMilestoneReminders(now),
    ]);
    return [...scholarshipReminders, ...caseReminders];
  }

  private async collectSavedScholarshipReminders(
    now: Date,
  ): Promise<DueReminder[]> {
    const horizon = addDays(now, 30);
    const savedItems =
      (await this.prismaService.execute((prisma) =>
        prisma.savedItem.findMany({
          where: { itemType: 'scholarship' },
          include: {
            user: {
              select: {
                id: true,
                fullName: true,
                preferredLanguage: true,
              },
            },
          },
        }),
      )) ?? [];

    const scholarshipIds = Array.from(
      new Set(savedItems.map((item) => item.itemId)),
    );
    if (scholarshipIds.length === 0) return [];

    const scholarships =
      (await this.prismaService.execute((prisma) =>
        prisma.scholarship.findMany({
          where: {
            id: { in: scholarshipIds },
            isActive: true,
            deadlineAt: { gte: startOfDay(now), lte: horizon },
          },
          select: {
            id: true,
            nameFr: true,
            nameEn: true,
            deadlineAt: true,
            countryNameFr: true,
            countryNameEn: true,
          },
        }),
      )) ?? [];

    const byId = new Map(scholarships.map((item) => [item.id, item]));
    const reminders: DueReminder[] = [];
    for (const saved of savedItems) {
      const scholarship = byId.get(saved.itemId);
      if (!scholarship?.deadlineAt) continue;
      const days = daysUntil(now, scholarship.deadlineAt);
      if (!SCHOLARSHIP_REMINDER_DAYS.has(days)) continue;
      reminders.push({
        user: saved.user,
        titleFr:
          days === 0 ? 'Échéance bourse aujourd’hui' : `Bourse à J-${days}`,
        titleEn:
          days === 0
            ? 'Scholarship deadline today'
            : `Scholarship deadline in ${days} day${days > 1 ? 's' : ''}`,
        bodyFr: `${scholarship.nameFr} (${scholarship.countryNameFr || 'destination à confirmer'}) arrive bientôt. Ouvre ton tracker pour vérifier les étapes restantes.`,
        bodyEn: `${scholarship.nameEn} (${scholarship.countryNameEn || 'destination pending'}) is coming up. Open your tracker to review the remaining steps.`,
        route: TRACKER_ROUTE,
        data: {
          type: 'milestone_reminder',
          reminderType: 'saved_scholarship',
          scholarshipId: scholarship.id,
        },
      });
    }
    return reminders;
  }

  private async collectCaseMilestoneReminders(
    now: Date,
  ): Promise<DueReminder[]> {
    const horizon = addDays(now, 7);
    const cases =
      (await this.prismaService.execute((prisma) =>
        prisma.case.findMany({
          where: {
            status: { notIn: ['completed', 'rejected', 'cancelled'] },
            OR: [
              { scheduledAt: { gte: startOfDay(now), lte: horizon } },
              {
                tasks: {
                  some: {
                    dueAt: { gte: startOfDay(now), lte: horizon },
                    status: { notIn: ['done', 'completed', 'cancelled'] },
                  },
                },
              },
            ],
          },
          include: {
            user: {
              select: {
                id: true,
                fullName: true,
                preferredLanguage: true,
              },
            },
            tasks: {
              where: {
                dueAt: { gte: startOfDay(now), lte: horizon },
                status: { notIn: ['done', 'completed', 'cancelled'] },
              },
              orderBy: { dueAt: 'asc' },
            },
          },
        }),
      )) ?? [];

    const reminders: DueReminder[] = [];
    for (const item of cases) {
      if (item.scheduledAt) {
        const days = daysUntil(now, item.scheduledAt);
        if (CASE_REMINDER_DAYS.has(days)) {
          reminders.push({
            user: item.user,
            titleFr:
              days === 0 ? 'Rendez-vous dossier aujourd’hui' : `Dossier à J-${days}`,
            titleEn:
              days === 0
                ? 'Case appointment today'
                : `Case milestone in ${days} day${days > 1 ? 's' : ''}`,
            bodyFr: `${item.referenceCode}: ${item.nextStepTitle}. Ouvre ton dossier pour confirmer la prochaine action.`,
            bodyEn: `${item.referenceCode}: ${item.nextStepTitle}. Open your case to confirm the next action.`,
            route: `/cases/${item.id}`,
            data: {
              type: 'milestone_reminder',
              reminderType: 'case_schedule',
              caseId: item.id,
            },
          });
        }
      }

      for (const task of item.tasks) {
        if (!task.dueAt) continue;
        const days = daysUntil(now, task.dueAt);
        if (!CASE_REMINDER_DAYS.has(days)) continue;
        reminders.push({
          user: item.user,
          titleFr:
            days === 0 ? 'Action dossier aujourd’hui' : `Action dossier à J-${days}`,
          titleEn:
            days === 0
              ? 'Case action due today'
              : `Case action due in ${days} day${days > 1 ? 's' : ''}`,
          bodyFr: `${item.referenceCode}: ${task.title}.`,
          bodyEn: `${item.referenceCode}: ${task.title}.`,
          route: `/cases/${item.id}`,
          data: {
            type: 'milestone_reminder',
            reminderType: 'case_task',
            caseId: item.id,
            taskId: task.id,
          },
        });
      }
    }
    return reminders;
  }
}

function startOfDay(date: Date) {
  const copy = new Date(date);
  copy.setHours(0, 0, 0, 0);
  return copy;
}

function addDays(date: Date, days: number) {
  return new Date(startOfDay(date).getTime() + days * DAY_MS);
}

function daysUntil(now: Date, target: Date) {
  return Math.round(
    (startOfDay(target).getTime() - startOfDay(now).getTime()) / DAY_MS,
  );
}
