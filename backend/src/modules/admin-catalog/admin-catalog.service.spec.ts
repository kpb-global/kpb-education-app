import { BadRequestException, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';

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

/**
 * Guards the match-scoring columns on Program writes (lot 1).
 *
 * `minGpaRequired`, `tuitionMinEur`, `applicationDeadline`, `teachingLanguages`
 * and `campusOfferings` feed matches.service.ts. Before this lot the admin API
 * accepted them and threw them away: every program created from the back-office
 * landed with null scoring inputs, which the scorer turns into a neutral 0.5
 * factor and a permanent `isEstimate` flag — a silent catalogue degradation
 * that nothing surfaced. These tests pin BOTH halves: the values must reach
 * Prisma, and a present-but-malformed value must fail loudly instead of being
 * dropped.
 */
describe('AdminCatalogService — Program match-scoring columns', () => {
  function makeService() {
    const creates: Array<Record<string, unknown>> = [];
    const updates: Array<{ where: Record<string, unknown>; data: Record<string, unknown> }> = [];
    const client = {
      program: {
        create: async ({ data }: { data: Record<string, unknown> }) => {
          creates.push(data);
          return { id: 'prog-1', ...data };
        },
        update: async ({
          where,
          data,
        }: {
          where: Record<string, unknown>;
          data: Record<string, unknown>;
        }) => {
          updates.push({ where, data });
          return { id: where.id, ...data };
        },
        // Ajoutés quand le service s'est mis à entretenir
        // `Institution.programIds` : ces tests portent sur les colonnes de
        // scoring, mais toute écriture de formation touche désormais aussi la
        // liste de son établissement. Un harnais qui ne l'expose pas ferait
        // échouer le service pour une raison étrangère à ce qu'il vérifie.
        findUnique: async () => ({ institutionId: 'omnes-ece' }),
        findMany: async () => [{ id: 'prog-1' }],
      },
      institution: {
        updateMany: async () => ({ count: 1 }),
      },
    };
    const prisma = {
      isEnabled: true,
      execute: async (fn: (c: typeof client) => unknown) => fn(client),
    } as unknown as PrismaService;
    return { service: new AdminCatalogService(prisma), creates, updates };
  }

  const required = {
    institutionId: 'omnes-ece',
    countryId: 'fra',
    fieldId: 'd01',
    nameFr: 'Bachelor Cybersécurité',
  };

  describe('createProgram', () => {
    it('persists every match-scoring column instead of dropping it', async () => {
      const { service, creates } = makeService();
      await service.createProgram({
        ...required,
        minGpaRequired: 12.5,
        tuitionMinEur: 6690,
        applicationDeadline: '2027-03-01T00:00:00.000Z',
        teachingLanguages: ['fr', 'en'],
      });
      expect(creates).toHaveLength(1);
      expect(creates[0].minGpaRequired).toBe(12.5);
      expect(creates[0].tuitionMinEur).toBe(6690);
      expect(creates[0].applicationDeadline).toEqual(
        new Date('2027-03-01T00:00:00.000Z'),
      );
      expect(creates[0].teachingLanguages).toEqual(['fr', 'en']);
    });

    it('truncates tuitionMinEur to an integer (the column is Int?)', async () => {
      const { service, creates } = makeService();
      await service.createProgram({ ...required, tuitionMinEur: 6690.9 });
      expect(creates[0].tuitionMinEur).toBe(6690);
    });

    it('defaults teachingLanguages to [] and leaves the other columns unset', async () => {
      const { service, creates } = makeService();
      await service.createProgram(required);
      expect(creates[0].teachingLanguages).toEqual([]);
      expect(creates[0].minGpaRequired).toBeUndefined();
      expect(creates[0].tuitionMinEur).toBeUndefined();
      expect(creates[0].applicationDeadline).toBeUndefined();
      expect(creates[0].campusOfferings).toBeUndefined();
    });

    it('rejects a non-numeric minGpaRequired instead of silently dropping it', async () => {
      const { service, creates } = makeService();
      await expect(
        service.createProgram({ ...required, minGpaRequired: '12.5' }),
      ).rejects.toBeInstanceOf(BadRequestException);
      expect(creates).toHaveLength(0);
    });

    it('rejects an unparseable applicationDeadline', async () => {
      const { service, creates } = makeService();
      await expect(
        service.createProgram({ ...required, applicationDeadline: 'bientôt' }),
      ).rejects.toBeInstanceOf(BadRequestException);
      expect(creates).toHaveLength(0);
    });

    // Revue #271 (P2) : `new Date(str)` accepte bien plus que de l'ISO-8601 et
    // lit les autres formes en heure LOCALE. Mesuré sous Node avant correctif :
    //   '1 mars 2027'  → 2027-02-28T23:00Z   (accepté, et décalé d'un jour)
    //   '03/01/2027'   → 2027-02-28T23:00Z   (accepté, ambigu FR/US)
    //   '2027-02-30'   → 2027-03-02T00:00Z   (jour inexistant, reporté)
    // Une faute de frappe devenait donc une échéance valide et fausse.
    it.each([
      ['une date en toutes lettres', '1 mars 2027'],
      ['un format anglo-saxon', 'March 1 2027'],
      ['un format ambigu à slashes', '03/01/2027'],
      ['un format compact sans tirets', '20270301'],
      ['une date-heure sans décalage UTC', '2027-03-01T10:00:00'],
    ])('rejette %s comme applicationDeadline', async (_label, value) => {
      const { service, creates } = makeService();
      await expect(
        service.createProgram({ ...required, applicationDeadline: value }),
      ).rejects.toBeInstanceOf(BadRequestException);
      expect(creates).toHaveLength(0);
    });

    it.each([
      ['le 30 février', '2027-02-30'],
      ['le 31 avril', '2027-04-31'],
      ['un 29 février hors année bissextile', '2027-02-29'],
      ['un mois 13', '2027-13-01'],
    ])('rejette %s : jour inexistant au calendrier', async (_label, value) => {
      const { service, creates } = makeService();
      await expect(
        service.createProgram({ ...required, applicationDeadline: value }),
      ).rejects.toThrow(BadRequestException);
      expect(creates).toHaveLength(0);
    });

    it('accepte le 29 février d\'une vraie année bissextile', async () => {
      const { service, creates } = makeService();
      await service.createProgram({
        ...required,
        applicationDeadline: '2028-02-29',
      });
      expect(creates[0].applicationDeadline).toEqual(
        new Date('2028-02-29T00:00:00.000Z'),
      );
    });

    it('lit une date seule en UTC, sans décalage de fuseau', async () => {
      const { service, creates } = makeService();
      await service.createProgram({
        ...required,
        applicationDeadline: '2027-03-01',
      });
      // Le jour stocké doit rester le 1er mars quel que soit le fuseau du
      // serveur : c'est ce que garantit la forme date-seule de la spec ES.
      const stored = creates[0].applicationDeadline as Date;
      expect(stored.toISOString()).toBe('2027-03-01T00:00:00.000Z');
    });

    it('accepte une date-heure portant un décalage explicite', async () => {
      const { service, creates } = makeService();
      await service.createProgram({
        ...required,
        applicationDeadline: '2027-03-01T10:00:00+01:00',
      });
      expect((creates[0].applicationDeadline as Date).toISOString()).toBe(
        '2027-03-01T09:00:00.000Z',
      );
    });

    it('rejects teachingLanguages that is not an array of strings', async () => {
      const { service } = makeService();
      await expect(
        service.createProgram({ ...required, teachingLanguages: 'fr' }),
      ).rejects.toBeInstanceOf(BadRequestException);
    });
  });

  describe('campusOfferings', () => {
    it('keeps the documented shape and drops unknown keys', async () => {
      const { service, creates } = makeService();
      await service.createProgram({
        ...required,
        campusOfferings: [
          {
            campus: 'Lyon',
            tuitionUpfront: 6690,
            tuitionInstallments: 7025,
            intake: 'Mars 2027',
            prixSecret: 999,
          },
        ],
      });
      expect(creates[0].campusOfferings).toEqual([
        {
          campus: 'Lyon',
          tuitionUpfront: 6690,
          tuitionInstallments: 7025,
          intake: 'Mars 2027',
        },
      ]);
    });

    it('fills the optional members with null rather than omitting them', async () => {
      const { service, creates } = makeService();
      await service.createProgram({
        ...required,
        campusOfferings: [{ campus: 'Paris' }],
      });
      expect(creates[0].campusOfferings).toEqual([
        {
          campus: 'Paris',
          tuitionUpfront: null,
          tuitionInstallments: null,
          intake: null,
        },
      ]);
    });

    it('rejects an entry without a campus, naming the offending index', async () => {
      const { service, creates } = makeService();
      await expect(
        service.createProgram({
          ...required,
          campusOfferings: [{ campus: 'Lyon' }, { tuitionUpfront: 6690 }],
        }),
      ).rejects.toThrow(/campusOfferings\[1\]\.campus/);
      expect(creates).toHaveLength(0);
    });

    it('rejects a non-numeric tuition inside an entry', async () => {
      const { service } = makeService();
      await expect(
        service.createProgram({
          ...required,
          campusOfferings: [{ campus: 'Lyon', tuitionUpfront: '6690 €' }],
        }),
      ).rejects.toThrow(/campusOfferings\[0\]\.tuitionUpfront/);
    });
  });

  describe('updateProgram', () => {
    it('sends only the columns that were provided', async () => {
      const { service, updates } = makeService();
      await service.updateProgram('prog-1', { tuitionMinEur: 7025 });
      expect(Object.keys(updates[0].data)).toEqual(['tuitionMinEur']);
      expect(updates[0].data.tuitionMinEur).toBe(7025);
    });

    // Revue #271 (P2) : le commentaire du service promet « null explicite =
    // colonne vidée » pour les cinq colonnes de scoring. teachingLanguages
    // faisait exception — il renvoyait undefined, clean() retirait la clé, et
    // l'ancien tableau survivait à l'édition. La colonne n'étant pas nullable,
    // « vider » veut dire tableau vide.
    it('clears teachingLanguages with [] when the caller sends null', async () => {
      const { service, updates } = makeService();
      await service.updateProgram('prog-1', { teachingLanguages: null });
      expect(updates[0].data.teachingLanguages).toEqual([]);
    });

    it('clears a scalar column when the caller sends an explicit null', async () => {
      const { service, updates } = makeService();
      await service.updateProgram('prog-1', {
        minGpaRequired: null,
        applicationDeadline: null,
      });
      expect(updates[0].data.minGpaRequired).toBeNull();
      expect(updates[0].data.applicationDeadline).toBeNull();
    });

    it('clears campusOfferings with Prisma.DbNull, not a bare null', async () => {
      const { service, updates } = makeService();
      await service.updateProgram('prog-1', { campusOfferings: null });
      // A bare `null` on a Json? column is rejected by Prisma at runtime; the
      // mock here would happily accept it, so assert the sentinel explicitly.
      expect(updates[0].data.campusOfferings).toBe(Prisma.DbNull);
    });

    it('validates campusOfferings on update too, not only on create', async () => {
      const { service, updates } = makeService();
      await expect(
        service.updateProgram('prog-1', { campusOfferings: [{ intake: 'Mars' }] }),
      ).rejects.toBeInstanceOf(BadRequestException);
      expect(updates).toHaveLength(0);
    });
  });
});

/**
 * `Institution.programIds` est une liste DÉNORMALISÉE que l'app lit pour
 * compter les formations d'un établissement, en afficher un aperçu, et ouvrir
 * la navigation depuis une fiche pays — désactivée quand la liste est vide
 * (`country_detail_screen.dart:241`). Rien en base ne la lie aux lignes
 * `Program` : créer une formation sans l'entretenir produit une formation qui
 * existe mais reste inatteignable, sans la moindre erreur.
 *
 * Mesuré en production le 18/09 : 46 formations Mundiapolis dans ce cas, créées
 * par un import qui écrivait une liste vide. La page Catalogue livrée en #275
 * reproduisait le défaut à chaque création.
 */
describe('AdminCatalogService — entretien de Institution.programIds', () => {
  function makeService(programsByInstitution: Record<string, string[]> = {}) {
    const rows: Record<string, string[]> = { ...programsByInstitution };
    const institutionUpdates: Array<{ where: Record<string, unknown>; data: Record<string, unknown> }> = [];
    let seq = 0;
    const client = {
      program: {
        create: async ({ data }: { data: Record<string, unknown> }) => {
          const id = `prog-${++seq}`;
          const inst = data.institutionId as string;
          (rows[inst] ??= []).push(id);
          return { id, ...data };
        },
        update: async ({ where, data }: { where: { id: string }; data: Record<string, unknown> }) => {
          const next = data.institutionId as string | undefined;
          if (next) {
            for (const key of Object.keys(rows)) {
              rows[key] = rows[key].filter((x) => x !== where.id);
            }
            (rows[next] ??= []).push(where.id);
          }
          return { id: where.id, ...data };
        },
        delete: async ({ where }: { where: { id: string } }) => {
          for (const key of Object.keys(rows)) {
            rows[key] = rows[key].filter((x) => x !== where.id);
          }
          return { id: where.id };
        },
        findUnique: async ({ where }: { where: { id: string } }) => {
          for (const [inst, ids] of Object.entries(rows)) {
            if (ids.includes(where.id)) return { institutionId: inst };
          }
          return null;
        },
        findMany: async ({ where }: { where: { institutionId: string } }) =>
          (rows[where.institutionId] ?? []).map((id) => ({ id })),
      },
      institution: {
        updateMany: async (args: { where: Record<string, unknown>; data: Record<string, unknown> }) => {
          institutionUpdates.push(args);
          return { count: 1 };
        },
      },
    };
    const prisma = {
      isEnabled: true,
      execute: async (fn: (c: typeof client) => unknown) => fn(client),
    } as unknown as PrismaService;
    return { service: new AdminCatalogService(prisma), institutionUpdates, rows };
  }

  const required = {
    institutionId: 'partner-mundiapolis',
    countryId: 'mar',
    fieldId: 'd04',
    nameFr: 'Licence Infirmier',
  };

  it('créer une formation renseigne la liste de son établissement', async () => {
    const { service, institutionUpdates } = makeService();
    await service.createProgram(required);
    expect(institutionUpdates).toHaveLength(1);
    expect(institutionUpdates[0].where).toMatchObject({ id: 'partner-mundiapolis' });
    expect(institutionUpdates[0].data.programIds).toEqual(['prog-1']);
  });

  it('la liste est reconstruite depuis la base, pas incrémentée à l’aveugle', async () => {
    const { service, institutionUpdates } = makeService({
      'partner-mundiapolis': ['déjà-là'],
    });
    await service.createProgram(required);
    expect(institutionUpdates[0].data.programIds).toEqual(['déjà-là', 'prog-1']);
  });

  it('supprimer une formation la retire de la liste', async () => {
    const { service, institutionUpdates } = makeService({
      'partner-mundiapolis': ['prog-a', 'prog-b'],
    });
    await service.deleteProgram('prog-a');
    expect(institutionUpdates).toHaveLength(1);
    expect(institutionUpdates[0].data.programIds).toEqual(['prog-b']);
  });

  // Le cas qui se perd le plus facilement : changer d'établissement doit
  // toucher les DEUX listes, celle qu'on quitte et celle qu'on rejoint.
  it('déplacer une formation met à jour les deux établissements', async () => {
    const { service, institutionUpdates } = makeService({
      'inst-a': ['prog-x'],
      'inst-b': [],
    });
    await service.updateProgram('prog-x', { institutionId: 'inst-b' });
    const touched = institutionUpdates.map((u) => (u.where as { id: string }).id).sort();
    expect(touched).toEqual(['inst-a', 'inst-b']);
    const byInst = Object.fromEntries(
      institutionUpdates.map((u) => [(u.where as { id: string }).id, u.data.programIds]),
    );
    expect(byInst['inst-a']).toEqual([]);
    expect(byInst['inst-b']).toEqual(['prog-x']);
  });

  it('une modification sans changement d’établissement n’en touche qu’un', async () => {
    const { service, institutionUpdates } = makeService({ 'inst-a': ['prog-x'] });
    await service.updateProgram('prog-x', { nameFr: 'Nouveau nom' });
    expect(institutionUpdates).toHaveLength(1);
    expect((institutionUpdates[0].where as { id: string }).id).toBe('inst-a');
  });
});
