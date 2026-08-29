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
  // `cycles` fait partie de la SÉLECTION Prisma depuis que le rappel refuse
  // les dates estimées. Prisma rend toujours un tableau (vide s'il n'y a pas de
  // cycle) : la doublure doit donc en rendre un aussi, sinon elle ne décrit
  // plus la requête qu'elle prétend simuler — et le service se protégerait d'un
  // `undefined` qui n'existe jamais en production.
  const scholarshipDueInDays = (
    days: number,
    cycles: Array<{ dateConfidence: 'confirmed' | 'estimated' }> = [],
  ) => ({
    id: 'sch-1',
    nameFr: 'Bourse X',
    nameEn: 'Scholarship X',
    deadlineAt: new Date(Date.now() + days * DAY),
    countryNameFr: 'France',
    countryNameEn: 'France',
    cycles,
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

  // ── Revue du build 49, point 9 : les bourses « à venir » ────────────────
  //
  // L'importeur remplit `deadlineAt` depuis `estimatedCloseAt` quand le cycle
  // n'est pas confirmé. Sans le refus, l'app poussait « plus que 3 jours pour
  // candidater » sur une campagne dont AUCUNE date n'a été publiée. Deux
  // surfaces se taisaient déjà correctement (pastille de liste, calendrier) ;
  // la notification, seule des trois à réveiller le téléphone, ne consultait
  // pas le champ.
  it('ne rappelle JAMAIS sur une date estimée', async () => {
    const { service } = makeService({
      saved: [savedFor('fr')],
      scholarships: [scholarshipDueInDays(7, [{ dateConfidence: 'estimated' }])],
    });
    const reminders = await service.collectDueReminders(new Date());
    expect(reminders).toHaveLength(0);
  });

  it('rappelle bien sur une date confirmée', async () => {
    const { service } = makeService({
      saved: [savedFor('fr')],
      scholarships: [scholarshipDueInDays(7, [{ dateConfidence: 'confirmed' }])],
    });
    // Contre-garde du test précédent : sans elle, une erreur qui supprimerait
    // TOUS les rappels passerait pour un correctif.
    expect(await service.collectDueReminders(new Date())).toHaveLength(1);
  });

  it('une fiche héritée SANS cycle reste rappelée (le silence n\'est pas un refus)', async () => {
    const { service } = makeService({
      saved: [savedFor('fr')],
      scholarships: [scholarshipDueInDays(7, [])],
    });
    expect(await service.collectDueReminders(new Date())).toHaveLength(1);
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
