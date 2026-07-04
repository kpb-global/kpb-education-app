import { GreatYopScraper } from './scrapers/greatyop.scraper';
import { MastereTnScraper } from './scrapers/mastereTn.scraper';
import { ScholarshipsIndexService } from './scholarships-index.service';
import { PrismaService } from '../prisma/prisma.service';

/**
 * Guards the Bourses enrichment surfacing on both consumers of the live
 * index: the public listing (`listForProfile`, localized single-language)
 * and the admin moderation queue (`listForModeration`, both languages so the
 * admin can edit either). Neither must silently drop `applicationRequirement`
 * or `applicationSteps` — that would leave the mobile UI with nothing to
 * render and the admin UI with nothing to edit.
 */
describe('ScholarshipsIndexService — application requirement & steps', () => {
  const baseRow = {
    id: 'sch-1',
    nameFr: 'Bourse Chevening',
    nameEn: 'Chevening Scholarship',
    countryId: 'gb',
    countryNameFr: 'Royaume-Uni',
    countryNameEn: 'United Kingdom',
    levelEligibleFr: 'Master',
    levelEligibleEn: 'Master',
    fundingType: 'fully_funded',
    applicationRequirement: 'separate_application',
    descriptionFr: 'Description FR',
    descriptionEn: 'Description EN',
    advantagesFr: ['Avantage FR'],
    advantagesEn: ['Benefit EN'],
    eligibilityFr: ['Critère FR'],
    eligibilityEn: ['Criterion EN'],
    deadlineLabelFr: 'Novembre',
    deadlineLabelEn: 'November',
    deadlineAt: null,
    applicationUrl: 'https://chevening.org',
    sourceUrl: null,
    tags: ['uk'],
    relatedFieldIds: [],
    baseMatch: 30,
    sourceKey: null,
    applicationUrl2: undefined,
    moderationStatus: 'pending',
    lastVerifiedAt: null,
    applicationSteps: [
      {
        id: 'step-1',
        stepNumber: 1,
        titleFr: 'Formulaire en ligne',
        titleEn: 'Online form',
        descriptionFr: 'Remplir le formulaire',
        descriptionEn: 'Fill in the form',
        estimatedDurationDays: 30,
      },
    ],
  };

  function makeService(rows: Array<Record<string, unknown>>) {
    const findManyCalls: Array<Record<string, unknown>> = [];
    const client = {
      scholarship: {
        findMany: async (args: Record<string, unknown>) => {
          findManyCalls.push(args);
          return rows;
        },
        count: async () => rows.length,
      },
    };
    const prisma = {
      isEnabled: true,
      execute: async (fn: (c: typeof client) => unknown) => fn(client),
    } as unknown as PrismaService;
    const service = new ScholarshipsIndexService(
      prisma,
      {} as unknown as GreatYopScraper,
      {} as unknown as MastereTnScraper,
    );
    return { service, findManyCalls };
  }

  describe('listForProfile (public, single-language)', () => {
    it('includes applicationRequirement and localized applicationSteps (fr)', async () => {
      const { service } = makeService([baseRow]);
      const result = await service.listForProfile({ lang: 'fr' });

      expect(result.items[0].applicationRequirement).toBe(
        'separate_application',
      );
      expect(result.items[0].applicationSteps).toEqual([
        {
          id: 'step-1',
          stepNumber: 1,
          title: 'Formulaire en ligne',
          description: 'Remplir le formulaire',
          estimatedDurationDays: 30,
        },
      ]);
    });

    it('localizes applicationSteps to English when lang=en', async () => {
      const { service } = makeService([baseRow]);
      const result = await service.listForProfile({ lang: 'en' });

      expect(result.items[0].applicationSteps[0]).toMatchObject({
        title: 'Online form',
        description: 'Fill in the form',
      });
    });

    it('requests applicationSteps ordered by stepNumber ascending', async () => {
      const { service, findManyCalls } = makeService([baseRow]);
      await service.listForProfile({ lang: 'fr' });

      expect(findManyCalls[0].include).toMatchObject({
        applicationSteps: { orderBy: { stepNumber: 'asc' } },
      });
    });

    it('defaults to an empty steps array when a scholarship has none', async () => {
      const { service } = makeService([{ ...baseRow, applicationSteps: [] }]);
      const result = await service.listForProfile({ lang: 'fr' });

      expect(result.items[0].applicationSteps).toEqual([]);
    });
  });

  describe('listForModeration (admin, bilingual)', () => {
    it('exposes applicationRequirement and both-language applicationSteps for editing', async () => {
      const { service } = makeService([baseRow]);
      const result = await service.listForModeration('pending');

      expect(result.items[0].applicationRequirement).toBe(
        'separate_application',
      );
      expect(result.items[0].applicationSteps).toEqual([
        {
          id: 'step-1',
          stepNumber: 1,
          titleFr: 'Formulaire en ligne',
          titleEn: 'Online form',
          descriptionFr: 'Remplir le formulaire',
          descriptionEn: 'Fill in the form',
          estimatedDurationDays: 30,
        },
      ]);
    });
  });
});
