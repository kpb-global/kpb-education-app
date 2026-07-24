import { BadRequestException, NotFoundException } from '@nestjs/common';

import { AdminCatalogService } from './admin-catalog.service';
import { PrismaService } from '../prisma/prisma.service';

/**
 * Guards the Bourses enrichment (applicationRequirement + admin-authored
 * application steps): a scholarship created/updated without an explicit
 * requirement must default to "separate_application" (the majority case
 * among scraped rows), an invalid value must never reach Prisma, and a
 * duplicate step number must surface as a readable 400, not a raw P2002.
 */
describe('AdminCatalogService — scholarship application requirement & steps', () => {
  function makeService(
    opts: {
      createThrows?: unknown;
      updateThrows?: unknown;
      deleteThrows?: unknown;
    } = {},
  ) {
    const scholarshipCreates: Array<Record<string, unknown>> = [];
    const scholarshipUpdates: Array<{ where: Record<string, unknown>; data: Record<string, unknown> }> = [];
    const stepCreates: Array<Record<string, unknown>> = [];
    const stepUpdates: Array<{ where: Record<string, unknown>; data: Record<string, unknown> }> = [];
    const stepDeletes: Array<{ where: Record<string, unknown> }> = [];
    const stepFindManyCalls: Array<Record<string, unknown>> = [];

    const client = {
      scholarship: {
        create: async ({ data }: { data: Record<string, unknown> }) => {
          scholarshipCreates.push(data);
          return { id: 'sch-1', ...data };
        },
        update: async ({
          where,
          data,
        }: {
          where: Record<string, unknown>;
          data: Record<string, unknown>;
        }) => {
          if (opts.updateThrows) throw opts.updateThrows;
          scholarshipUpdates.push({ where, data });
          return { id: where.id, ...data };
        },
      },
      scholarshipApplicationStep: {
        findMany: async (args: Record<string, unknown>) => {
          stepFindManyCalls.push(args);
          return [];
        },
        create: async ({ data }: { data: Record<string, unknown> }) => {
          if (opts.createThrows) throw opts.createThrows;
          stepCreates.push(data);
          return { id: 'step-1', ...data };
        },
        update: async ({
          where,
          data,
        }: {
          where: Record<string, unknown>;
          data: Record<string, unknown>;
        }) => {
          if (opts.updateThrows) throw opts.updateThrows;
          stepUpdates.push({ where, data });
          return { id: where.id, ...data };
        },
        delete: async ({ where }: { where: Record<string, unknown> }) => {
          if (opts.deleteThrows) throw opts.deleteThrows;
          stepDeletes.push({ where });
          return { id: where.id };
        },
      },
    };
    const prisma = {
      isEnabled: true,
      execute: async (fn: (c: typeof client) => unknown) => fn(client),
    } as unknown as PrismaService;
    return {
      service: new AdminCatalogService(prisma),
      scholarshipCreates,
      scholarshipUpdates,
      stepCreates,
      stepUpdates,
      stepDeletes,
      stepFindManyCalls,
    };
  }

  describe('applicationRequirement', () => {
    it('createScholarship defaults to separate_application when omitted', async () => {
      const { service, scholarshipCreates } = makeService();
      await service.createScholarship({ nameFr: 'Bourse X', countryId: 'fr' });
      expect(scholarshipCreates[0].applicationRequirement).toBe(
        'separate_application',
      );
      expect(scholarshipCreates[0].moderationStatus).toBe('pending');
    });

    it('createScholarship accepts an explicit automatic value', async () => {
      const { service, scholarshipCreates } = makeService();
      await service.createScholarship({
        nameFr: 'Bourse X',
        countryId: 'fr',
        applicationRequirement: 'automatic',
      });
      expect(scholarshipCreates[0].applicationRequirement).toBe('automatic');
    });

    it('createScholarship falls back to the default on an invalid value', async () => {
      const { service, scholarshipCreates } = makeService();
      await service.createScholarship({
        nameFr: 'Bourse X',
        countryId: 'fr',
        applicationRequirement: 'not-a-real-value',
      });
      expect(scholarshipCreates[0].applicationRequirement).toBe(
        'separate_application',
      );
    });

    it('updateScholarship maps a valid applicationRequirement', async () => {
      const { service, scholarshipUpdates } = makeService();
      await service.updateScholarship('sch-1', {
        applicationRequirement: 'automatic',
      });
      expect(scholarshipUpdates[0].data.applicationRequirement).toBe(
        'automatic',
      );
    });

    it('updateScholarship drops an invalid applicationRequirement instead of writing it', async () => {
      const { service, scholarshipUpdates } = makeService();
      await service.updateScholarship('sch-1', {
        applicationRequirement: 'bogus',
      });
      expect(scholarshipUpdates[0].data).not.toHaveProperty(
        'applicationRequirement',
      );
    });
  });

  describe('application steps', () => {
    it('createApplicationStep persists titleFr/stepNumber and defaults titleEn to titleFr', async () => {
      const { service, stepCreates } = makeService();
      await service.createApplicationStep('sch-1', {
        stepNumber: 1,
        titleFr: 'Formulaire en ligne',
      });
      expect(stepCreates[0]).toMatchObject({
        stepNumber: 1,
        titleFr: 'Formulaire en ligne',
        titleEn: 'Formulaire en ligne',
      });
    });

    it('createApplicationStep requires stepNumber', async () => {
      const { service } = makeService();
      await expect(
        service.createApplicationStep('sch-1', { titleFr: 'Étape' }),
      ).rejects.toBeInstanceOf(BadRequestException);
    });

    it('createApplicationStep requires titleFr', async () => {
      const { service } = makeService();
      await expect(
        service.createApplicationStep('sch-1', { stepNumber: 1 }),
      ).rejects.toBeInstanceOf(BadRequestException);
    });

    it('createApplicationStep maps a duplicate stepNumber (P2002) to a readable 400', async () => {
      const { service } = makeService({ createThrows: { code: 'P2002' } });
      await expect(
        service.createApplicationStep('sch-1', {
          stepNumber: 1,
          titleFr: 'Étape',
        }),
      ).rejects.toBeInstanceOf(BadRequestException);
    });

    it('updateApplicationStep only sends the provided fields', async () => {
      const { service, stepUpdates } = makeService();
      await service.updateApplicationStep('sch-1', 'step-1', {
        titleFr: 'Nouveau titre',
      });
      expect(stepUpdates[0].data).toEqual({ titleFr: 'Nouveau titre' });
    });

    it('updateApplicationStep maps a P2025 (not found) to NotFoundException', async () => {
      const { service } = makeService({ updateThrows: { code: 'P2025' } });
      await expect(
        service.updateApplicationStep('sch-1', 'missing', { titleFr: 'x' }),
      ).rejects.toBeInstanceOf(NotFoundException);
    });

    it('deleteApplicationStep removes the step by id', async () => {
      const { service, stepDeletes } = makeService();
      await service.deleteApplicationStep('sch-1', 'step-1');
      expect(stepDeletes[0].where).toEqual({ id: 'step-1' });
    });

    it('listApplicationSteps orders by stepNumber ascending', async () => {
      const { service, stepFindManyCalls } = makeService();
      await service.listApplicationSteps('sch-1');
      expect(stepFindManyCalls[0]).toMatchObject({
        where: { scholarshipId: 'sch-1' },
        orderBy: { stepNumber: 'asc' },
      });
    });
  });
});

/**
 * Guards KPB-161: the freshness SLA summary aggregates the verification queue
 * by category — overdue count, never-verified count, and oldest age — so the
 * daily ops alert reports what admins see.
 */
describe('AdminCatalogService — verification SLA (KPB-161)', () => {
  const DAY = 24 * 60 * 60 * 1000;

  function makeService(rows: {
    countries?: unknown[];
    institutions?: unknown[];
    programs?: unknown[];
    scholarships?: unknown[];
  }) {
    const client = {
      country: { findMany: async () => rows.countries ?? [] },
      institution: { findMany: async () => rows.institutions ?? [] },
      program: { findMany: async () => rows.programs ?? [] },
      scholarship: { findMany: async () => rows.scholarships ?? [] },
      $transaction: async (ps: Promise<unknown>[]) => Promise.all(ps),
    };
    const prisma = {
      isEnabled: true,
      execute: async (fn: (c: typeof client) => unknown) => fn(client),
    } as unknown as PrismaService;
    return new AdminCatalogService(prisma);
  }

  it('groups overdue items by category with never-verified + oldest age',
      async () => {
    const now = new Date();
    const service = makeService({
      countries: [
        {
          id: 'c1',
          nameFr: 'Niger',
          nameEn: 'Niger',
          lastVerifiedAt: null, // never verified
          verifiedByName: null,
          sourceUrl: null,
        },
      ],
      scholarships: [
        {
          id: 's1',
          nameFr: 'Bourse X',
          nameEn: 'Scholarship X',
          countryId: 'fra',
          deadlineLabelFr: 'Juin',
          lastVerifiedAt: new Date(now.getTime() - 45 * DAY),
          verifiedByName: 'Amina',
          sourceUrl: null,
        },
      ],
    });

    const sla = await service.verificationSlaSummary(now);

    expect(sla.totalOverdue).toBe(2);
    expect(sla.neverVerified).toBe(1);
    expect(sla.byCategory.country_visa.overdue).toBe(1);
    expect(sla.byCategory.country_visa.neverVerified).toBe(1);
    expect(sla.byCategory.country_visa.oldestDays).toBeNull();
    expect(sla.byCategory.scholarship_deadline.overdue).toBe(1);
    expect(sla.byCategory.scholarship_deadline.oldestDays).toBe(45);
  });

  it('reports zero overdue when the queue is empty', async () => {
    const service = makeService({});
    const sla = await service.verificationSlaSummary();
    expect(sla.totalOverdue).toBe(0);
    expect(sla.neverVerified).toBe(0);
    expect(sla.byCategory.scholarship_deadline.overdue).toBe(0);
  });
});
