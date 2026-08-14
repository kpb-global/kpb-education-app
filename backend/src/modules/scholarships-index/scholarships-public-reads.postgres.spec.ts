import { randomUUID } from 'node:crypto';

import { PrismaClient } from '@prisma/client';

import type { PrismaService } from '../prisma/prisma.service';
import { CatalogService } from '../catalog/catalog.service';
import { ScholarshipContentQualityService } from './scholarship-content-quality.service';
import { ScholarshipsIndexService } from './scholarships-index.service';
import type { GreatYopScraper } from './scrapers/greatyop.scraper';
import type { MastereTnScraper } from './scrapers/mastereTn.scraper';

/**
 * Ce que les lectures publiques doivent refuser, prouvé contre un vrai Postgres.
 *
 * Chacune des trois insertions ci-dessous reproduit un état qui a RÉELLEMENT été
 * servi à des étudiants :
 *   • une bourse dont la date limite est passée, affichée comme disponible
 *     (trois l'étaient, dépassées de 13, 44 et 90 jours) ;
 *   • une bourse sans aucune date de vérification, publique quand même
 *     (les 11 fiches de démonstration, jusqu'au 14/08/2026) ;
 *   • un cycle marqué « ouvert » dont la clôture est passée, et qu'aucun chemin
 *     d'écriture ne sait fermer.
 *
 * Les tests unitaires ne pouvaient pas attraper ça : la règle vit dans un `where`
 * Prisma, donc seule une base réelle dit si elle filtre.
 */
const describePostgres =
  process.env.KPB_RUN_POSTGRES_INTEGRATION === 'true'
    ? describe
    : describe.skip;

describePostgres('Lectures publiques de bourses — intégration PostgreSQL', () => {
  const prisma = new PrismaClient();
  const suffix = randomUUID();

  const expiredId = `pubread-expired-${suffix}`;
  const unverifiedId = `pubread-unverified-${suffix}`;
  const servableId = `pubread-servable-${suffix}`;
  const staleCycleId = `pubread-stalecycle-${suffix}`;
  const defaultsId = `pubread-defaults-${suffix}`;
  const moderatableId = `pubread-moderatable-${suffix}`;
  const allIds = [
    expiredId,
    unverifiedId,
    servableId,
    staleCycleId,
    defaultsId,
    moderatableId,
  ];

  const prismaService = {
    isEnabled: true,
    execute: async <T>(operation: (client: PrismaClient) => Promise<T>) =>
      operation(prisma),
    tryExecute: async <T>(operation: (client: PrismaClient) => Promise<T>) =>
      operation(prisma),
  } as unknown as PrismaService;

  /** Les scrapers ne sont jamais appelés par une lecture publique. */
  function indexService() {
    return new ScholarshipsIndexService(
      prismaService,
      {} as GreatYopScraper,
      {} as MastereTnScraper,
      new ScholarshipContentQualityService(prismaService),
    );
  }

  const hour = 60 * 60 * 1000;
  const day = 24 * hour;

  /** Le minimum que le schéma exige, pour que le test porte sur le filtre. */
  function row(id: string, overrides: Record<string, unknown>) {
    return {
      id,
      nameFr: `Bourse ${id}`,
      nameEn: `Scholarship ${id}`,
      countryId: 'fra',
      countryNameFr: 'France',
      countryNameEn: 'France',
      levelEligibleFr: 'Master',
      levelEligibleEn: "Master's",
      typeOfFundingFr: 'Complète',
      typeOfFundingEn: 'Full',
      fundingType: 'fully_funded' as const,
      deadlineLabelFr: 'Ouvert — clôture le 31 août',
      deadlineLabelEn: 'Open — closes 31 August',
      descriptionFr: 'Description.',
      descriptionEn: 'Description.',
      advantagesFr: ['Frais'],
      advantagesEn: ['Fees'],
      eligibilityFr: ['Licence'],
      eligibilityEn: ["Bachelor's"],
      keyRequirementsFr: ['Deux références'],
      keyRequirementsEn: ['Two references'],
      relatedFieldIds: ['d01'],
      baseMatch: 50,
      sourceUrl: 'https://official.example.org',
      applicationUrl: 'https://apply.example.org',
      ...overrides,
    };
  }

  beforeAll(async () => {
    const now = Date.now();
    await prisma.scholarship.deleteMany({ where: { id: { in: allIds } } });

    // (a) Approuvée, active, vérifiée — mais la campagne est close depuis hier.
    await prisma.scholarship.create({
      data: row(expiredId, {
        isActive: true,
        moderationStatus: 'approved',
        lastVerifiedAt: new Date(now - 2 * day),
        deadlineAt: new Date(now - day),
      }),
    });

    // (b) Approuvée, active, échéance lointaine — mais jamais vérifiée. C'est
    // exactement l'état des 11 fiches servies en production.
    await prisma.scholarship.create({
      data: row(unverifiedId, {
        isActive: true,
        moderationStatus: 'approved',
        lastVerifiedAt: null,
        deadlineAt: new Date(now + 90 * day),
      }),
    });

    // Le témoin : rien ne doit l'écarter. Sans lui, un filtre trop large
    // passerait pour un succès.
    await prisma.scholarship.create({
      data: row(servableId, {
        isActive: true,
        moderationStatus: 'approved',
        lastVerifiedAt: new Date(now - day),
        deadlineAt: new Date(now + 30 * day),
      }),
    });

    // Fiche complète, celle qui franchit la porte de qualité : c'est la seule
    // sur laquelle une approbation admin peut être testée, puisque
    // `setModeration` refuse d'approuver un contenu incomplet.
    await prisma.scholarship.create({
      data: row(moderatableId, {
        isActive: true,
        moderationStatus: 'pending',
        lastVerifiedAt: new Date(now - day),
        deadlineAt: new Date(now + 45 * day),
        applicationSteps: {
          create: {
            stepNumber: 1,
            titleFr: 'Créer un compte',
            titleEn: 'Create an account',
            descriptionFr: 'Ouvrir le portail officiel.',
            descriptionEn: 'Open the official portal.',
          },
        },
        cycles: {
          create: {
            academicYear: '2026-2027',
            status: 'open',
            dateConfidence: 'confirmed',
            closesAt: new Date(now + 45 * day),
            sourceUrl: 'https://official.example.org/dates',
            verifiedAt: new Date(now - day),
          },
        },
      }),
    });

    // (c) Servable, mais son cycle est marqué « ouvert » avec une clôture d'il
    // y a une heure. Aucun chemin d'écriture ne pose jamais `closed`.
    await prisma.scholarship.create({
      data: row(staleCycleId, {
        isActive: true,
        moderationStatus: 'approved',
        lastVerifiedAt: new Date(now - day),
        deadlineAt: new Date(now + 30 * day),
        cycles: {
          create: {
            academicYear: '2026-2027',
            status: 'open',
            dateConfidence: 'confirmed',
            opensAt: new Date(now - 30 * day),
            closesAt: new Date(now - hour),
            sourceUrl: 'https://official.example.org/dates',
            verifiedAt: new Date(now - day),
          },
        },
      }),
    });
  });

  afterAll(async () => {
    await prisma.scholarship.deleteMany({ where: { id: { in: allIds } } });
    await prisma.$disconnect();
  });

  describe('GET /catalog/scholarships', () => {
    it('ne sert ni une campagne close ni une fiche non vérifiée', async () => {
      const service = new CatalogService(prismaService);
      const response = await service.getScholarships();
      const ids = (response.items as Array<{ id: string }>).map((i) => i.id);

      expect(ids).toContain(servableId);
      expect(ids).not.toContain(expiredId);
      expect(ids).not.toContain(unverifiedId);
    });
  });

  describe('GET /scholarships', () => {
    it('ne liste ni une campagne close ni une fiche non vérifiée', async () => {
      const response = await indexService().listForProfile({ lang: 'fr', limit: 100 });
      const ids = (response.items as Array<{ id: string }>).map((i) => i.id);

      expect(ids).toContain(servableId);
      expect(ids).not.toContain(expiredId);
      expect(ids).not.toContain(unverifiedId);
    });

    it("rend un cycle « ouvert » dont la clôture est passée comme « closed »", async () => {
      const response = await indexService().listForProfile({ lang: 'fr', limit: 100 });
      const served = (
        response.items as Array<{
          id: string;
          currentCycle?: { status: string } | null;
        }>
      ).find((item) => item.id === staleCycleId);

      expect(served).toBeDefined();
      // En base le littéral vaut toujours `open` : c'est la lecture qui corrige.
      const inDb = await prisma.scholarshipCycle.findFirst({
        where: { scholarshipId: staleCycleId },
        select: { status: true },
      });
      expect(inDb?.status).toBe('open');
      expect(served?.currentCycle?.status).toBe('closed');
    });
  });

  describe('GET /scholarships/:id', () => {
    it('rend 404 sur une campagne close au lieu de sa fiche figée', async () => {
      const service = indexService();

      await expect(
        service.getForProfile(expiredId, { lang: 'fr', userId: 'user-test' }),
      ).rejects.toThrow(/not found/i);
      await expect(
        service.getForProfile(unverifiedId, { lang: 'fr', userId: 'user-test' }),
      ).rejects.toThrow(/not found/i);
    });
  });

  describe("l'approbation depuis l'admin", () => {
    // Contrepartie non optionnelle de `lastVerifiedAt: { not: null }` : sans
    // elle, la seule interface d'ajout de bourse de l'équipe produirait des
    // fiches approuvées et impubliables.
    it('horodate la vérification, sinon la fiche resterait invisible', async () => {
      const service = indexService();
      await prisma.scholarship.update({
        where: { id: moderatableId },
        data: { lastVerifiedAt: null, verifiedByName: null },
      });

      await service.setModeration(moderatableId, 'approved', {
        id: 'admin-1',
        email: 'moderateur@kpbeducation.com',
        fullName: 'Modérateur KPB',
      } as never);

      const after = await prisma.scholarship.findUnique({
        where: { id: moderatableId },
        select: { lastVerifiedAt: true, verifiedByName: true },
      });
      expect(after?.lastVerifiedAt).not.toBeNull();
      expect(after?.verifiedByName).toBe('Modérateur KPB');

      const catalog = await new CatalogService(prismaService).getScholarships();
      expect(
        (catalog.items as Array<{ id: string }>).map((i) => i.id),
      ).toContain(moderatableId);
    });
  });

  describe('les défauts du schéma', () => {
    // Reproduction en test de l'incident : une fiche créée sans qu'on précise
    // rien était publique immédiatement.
    it('créent une bourse inactive et en attente, donc invisible', async () => {
      const created = await prisma.scholarship.create({
        data: row(defaultsId, {
          lastVerifiedAt: new Date(),
          deadlineAt: new Date(Date.now() + 60 * day),
        }),
        select: { isActive: true, moderationStatus: true },
      });

      expect(created.isActive).toBe(false);
      expect(created.moderationStatus).toBe('pending');

      const catalog = await new CatalogService(prismaService).getScholarships();
      expect(
        (catalog.items as Array<{ id: string }>).map((i) => i.id),
      ).not.toContain(defaultsId);
    });
  });
});
