import { randomUUID } from 'node:crypto';

import {
  ConflictException,
  ForbiddenException,
  NotFoundException,
} from '@nestjs/common';
import { AccountType, PrismaClient } from '@prisma/client';

import type { PrismaService } from '../prisma/prisma.service';
import { ProfilesService } from '../profiles/profiles.service';
import type { StorageService } from '../storage/storage.service';
import { CounsellorsService } from './counsellors.service';

/**
 * L'avis conseiller, du chemin d'écriture réel à l'effacement du compte, prouvé
 * contre un vrai Postgres.
 *
 * ## Pourquoi ce test passe par le service
 *
 * La suite de confidentialité (`profiles.postgres.spec.ts`) prouve que la
 * suppression de compte efface les avis de l'utilisateur — mais elle POSE l'avis
 * avec son `reviewerUserId` déjà renseigné, c'est-à-dire dans un état que la
 * production ne produisait jamais : l'app n'envoyait pas l'auteur, et le service
 * recopiait ce que le client envoyait. C'est ainsi que le défaut est resté
 * invisible : le test partait de l'état où la suppression fonctionne.
 *
 * Ici l'avis est créé par `CounsellorsService.createReview`, avec l'identité que
 * le garde d'authentification pose, puis lu, publié, et enfin effacé avec le
 * compte. Si l'auteur cesse un jour d'être écrit, le dernier test rougit.
 *
 * ## Ce que la fiche publique doit taire
 *
 * `GET /counsellors/:id` sert les avis publiés. Tant que l'auteur restait nul, la
 * clé de rattachement au profil ne pouvait pas en sortir. Il est renseigné
 * désormais : la fiche ne doit servir que ce que le carrousel d'accueil
 * (`/impact/reviews`) sert déjà.
 *
 * ## Les avis d'AVANT l'auteur-par-jeton
 *
 * Tous ceux enregistrés jusqu'ici ont `reviewerUserId = NULL` : la seule trace de
 * leur auteur est le dossier noté, que la suppression du compte emporte. La
 * migration de reprise n'en rattache qu'une partie (elle exige que le conseiller
 * du dossier soit celui qui est noté). Les deux derniers tests vérifient donc que
 * l'export les rend à leur auteur et que l'effacement les emporte — et n'emporte
 * NI l'avis sans auteur posé sur le dossier d'un autre, NI l'avis qu'un autre a
 * signé.
 *
 * Les tests se suivent : le dernier supprime l'étudiant que les précédents ont
 * créé, et hérite de l'avis qu'ils ont publié.
 */
const describePostgres =
  process.env.KPB_RUN_POSTGRES_INTEGRATION === 'true'
    ? describe
    : describe.skip;

describePostgres('Avis conseiller — intégration PostgreSQL', () => {
  jest.setTimeout(60_000);

  const prisma = new PrismaClient();
  const sfx = randomUUID().replace(/-/g, '').slice(0, 12);

  const ids = {
    student: `rev-student-${sfx}`,
    stranger: `rev-stranger-${sfx}`,
    counsellorA: `rev-counsellor-a-${sfx}`,
    counsellorB: `rev-counsellor-b-${sfx}`,
    caseDone: `rev-case-done-${sfx}`,
    caseOngoing: `rev-case-ongoing-${sfx}`,
    caseOfStranger: `rev-case-stranger-${sfx}`,
    caseOfB: `rev-case-b-${sfx}`,
    // Des avis d'AVANT l'auteur-par-jeton : `reviewerUserId` NULL, la seule trace
    // de leur auteur est le dossier noté.
    legacyOwn: `rev-legacy-own-${sfx}`,
    legacyStranger: `rev-legacy-stranger-${sfx}`,
    strangerAuthored: `rev-stranger-authored-${sfx}`,
  };
  const STUDENT_NAME = 'Étudiante Adjovi';

  const prismaService = {
    isEnabled: true,
    execute: async <T>(operation: (client: PrismaClient) => Promise<T>) =>
      operation(prisma),
    tryExecute: async <T>(operation: (client: PrismaClient) => Promise<T>) =>
      operation(prisma),
  } as unknown as PrismaService;

  const service = new CounsellorsService(prismaService);
  const student = { id: ids.student, fullName: STUDENT_NAME };

  /** Le minimum que le schéma exige, pour que le test porte sur l'avis. */
  const profile = (id: string, fullName: string) => ({
    id,
    accountType: AccountType.student,
    preferredLanguage: 'fr',
    fullName,
    email: `${id}@example.test`,
    phone: '+22900000000',
    countryOfResidence: 'BJ',
  });
  const counsellor = (id: string) => ({
    id,
    fullName: `Conseiller ${id}`,
    email: `${id}@example.test`,
    phone: '+22900000001',
    countryOfResidence: 'BJ',
    bioFr: 'Bio.',
    bioEn: 'Bio.',
    // `getPublic` ne sert que les conseillers actifs et approuvés.
    isActive: true,
    kycStatus: 'approved' as const,
  });
  let seq = 0;
  const kase = (
    id: string,
    userId: string,
    counsellorId: string,
    status: 'completed' | 'in_progress',
  ) => ({
    id,
    referenceCode: `REV-${sfx}-${(seq += 1)}`,
    userId,
    counsellorId,
    type: 'consultation' as const,
    status,
    title: 'Dossier de test',
    description: 'Test.',
    contextLabel: 'Test',
    nextStepTitle: 'Test',
    nextStepDescription: 'Test.',
  });

  beforeAll(async () => {
    await prisma.userProfile.createMany({
      data: [
        profile(ids.student, STUDENT_NAME),
        profile(ids.stranger, 'Autre Étudiant'),
      ],
    });
    await prisma.counsellor.createMany({
      data: [counsellor(ids.counsellorA), counsellor(ids.counsellorB)],
    });
    await prisma.case.createMany({
      data: [
        kase(ids.caseDone, ids.student, ids.counsellorA, 'completed'),
        kase(ids.caseOngoing, ids.student, ids.counsellorA, 'in_progress'),
        kase(ids.caseOfStranger, ids.stranger, ids.counsellorA, 'completed'),
        kase(ids.caseOfB, ids.student, ids.counsellorB, 'completed'),
      ],
    });
    await prisma.counsellorReview.createMany({
      data: [
        // À l'étudiant, par son dossier : rien d'autre ne le rattache à lui.
        {
          id: ids.legacyOwn,
          counsellorId: ids.counsellorB,
          caseId: ids.caseOfB,
          reviewerName: 'Nom civil hérité',
          reviewerUserId: null,
          rating: 4,
          body: 'Avis hérité.',
          isPublished: true,
        },
        // Au dossier d'un AUTRE : ne doit jamais être touché par l'étudiant.
        {
          id: ids.legacyStranger,
          counsellorId: ids.counsellorB,
          caseId: ids.caseOfStranger,
          reviewerName: 'Autre nom civil',
          reviewerUserId: null,
          rating: 1,
          body: 'Autre avis hérité.',
          isPublished: false,
        },
        // Signé par un autre étudiant.
        {
          id: ids.strangerAuthored,
          counsellorId: ids.counsellorB,
          caseId: null,
          reviewerName: 'Autre Étudiant',
          reviewerUserId: ids.stranger,
          rating: 2,
          body: 'Avis signé.',
          isPublished: true,
        },
      ],
    });
    // Les compteurs de B suivent ses deux avis publiés : (4 + 2) / 2.
    await prisma.counsellor.update({
      where: { id: ids.counsellorB },
      data: { avgRating: 3, reviewCount: 2 },
    });
  }, 60_000);

  afterAll(async () => {
    const counsellorIds = [ids.counsellorA, ids.counsellorB];
    await prisma.counsellorReview.deleteMany({
      where: { counsellorId: { in: counsellorIds } },
    });
    await prisma.case.deleteMany({
      where: {
        id: {
          in: [
            ids.caseDone,
            ids.caseOngoing,
            ids.caseOfStranger,
            ids.caseOfB,
          ],
        },
      },
    });
    await prisma.counsellor.deleteMany({ where: { id: { in: counsellorIds } } });
    await prisma.userProfile.deleteMany({
      where: { id: { in: [ids.student, ids.stranger] } },
    });
    await prisma.$disconnect();
  }, 60_000);

  let reviewId = '';

  it("enregistre l'auteur et le nom du profil, en modération", async () => {
    const created = await service.createReview(
      ids.counsellorA,
      { rating: 5, body: '  Suivi impeccable.  ', caseId: ids.caseDone },
      student,
    );
    reviewId = created.id;

    const row = await prisma.counsellorReview.findUniqueOrThrow({
      where: { id: reviewId },
    });
    // Le champ qui manquait en production : sans lui, rien ne rattache l'avis à
    // son auteur, et la suppression de compte ne le trouve pas.
    expect(row.reviewerUserId).toBe(ids.student);
    expect(row.reviewerName).toBe(STUDENT_NAME);
    expect(row.caseId).toBe(ids.caseDone);
    expect(row.body).toBe('Suivi impeccable.');
    expect(row.isPublished).toBe(false);
  });

  it("refuse, sans rien écrire, ce que le dossier ne permet pas", async () => {
    const attempt = (
      counsellorId: string,
      caseId: string,
      marker: string,
    ) =>
      service.createReview(
        counsellorId,
        { rating: 1, body: marker, caseId },
        student,
      );

    // Le dossier d'un autre : même réponse qu'un dossier inconnu.
    await expect(
      attempt(ids.counsellorA, ids.caseOfStranger, 'refus-autrui'),
    ).rejects.toBeInstanceOf(NotFoundException);
    await expect(
      attempt(ids.counsellorA, `rev-inconnu-${sfx}`, 'refus-inconnu'),
    ).rejects.toBeInstanceOf(NotFoundException);
    // Le dossier est le sien, mais un AUTRE conseiller l'a traité.
    await expect(
      attempt(ids.counsellorA, ids.caseOfB, 'refus-autre-conseiller'),
    ).rejects.toBeInstanceOf(ForbiddenException);
    // Le dossier est le sien, le bon conseiller, mais rien n'est terminé.
    await expect(
      attempt(ids.counsellorA, ids.caseOngoing, 'refus-en-cours'),
    ).rejects.toBeInstanceOf(ConflictException);

    expect(
      await prisma.counsellorReview.count({
        where: {
          body: {
            in: [
              'refus-autrui',
              'refus-inconnu',
              'refus-autre-conseiller',
              'refus-en-cours',
            ],
          },
        },
      }),
    ).toBe(0);
  });

  it('refuse un second avis sur le même dossier, sans rien écrire', async () => {
    await expect(
      service.createReview(
        ids.counsellorA,
        { rating: 1, body: 'doublon', caseId: ids.caseDone },
        student,
      ),
    ).rejects.toBeInstanceOf(ConflictException);

    expect(
      await prisma.counsellorReview.count({ where: { caseId: ids.caseDone } }),
    ).toBe(1);
  });

  it("ne sert, sur la fiche publique, ni l'auteur ni le dossier de l'avis publié", async () => {
    await service.setReviewPublished(reviewId, true);

    const detail = (await service.getPublic(ids.counsellorA)) as unknown as {
      reviews: Array<Record<string, unknown>>;
    };

    expect(detail.reviews).toHaveLength(1);
    // Exactement ce que `/impact/reviews` sert déjà — et rien de plus. Une clé de
    // plus ici est une clé de rattachement au profil publiée à tout le monde.
    expect(Object.keys(detail.reviews[0]).sort()).toEqual(
      [
        'body',
        'counsellorId',
        'createdAt',
        'id',
        'rating',
        'reviewerName',
      ].sort(),
    );
    expect(JSON.stringify(detail)).not.toContain(ids.student);
    expect(JSON.stringify(detail)).not.toContain(ids.caseDone);
  });

  const storage = {
    keyFromUrl: () => null,
    delete: jest.fn().mockResolvedValue(undefined),
  } as unknown as StorageService;

  it("rend à l'étudiant ses avis dans l'export — signés ou hérités, jamais ceux d'un autre", async () => {
    // L'export manquait de ses avis alors que la suppression de compte les
    // efface : tant que l'auteur restait NULL, il n'existait aucun moyen de les
    // retrouver. Son nom, sa note et son texte sont SES données.
    const exported = (await new ProfilesService(
      prismaService,
      storage,
    ).exportMe(ids.student)) as unknown as {
      counsellorReviews: Array<{ id: string; body: string; reviewerName: string }>;
    };

    expect(exported.counsellorReviews.map((r) => r.id).sort()).toEqual(
      [reviewId, ids.legacyOwn].sort(),
    );
    const serialized = JSON.stringify(exported.counsellorReviews);
    expect(serialized).toContain('Avis hérité.');
    expect(serialized).not.toContain('Autre nom civil');
    expect(serialized).not.toContain('Avis signé.');
  });

  it("efface les avis avec le compte — signés ou hérités —, épargne ceux d'un autre, et recalcule les compteurs", async () => {
    // Le compteur suit la publication : un avis de 5 étoiles.
    expect(
      await prisma.counsellor.findUniqueOrThrow({
        where: { id: ids.counsellorA },
        select: { avgRating: true, reviewCount: true },
      }),
    ).toEqual({ avgRating: 5, reviewCount: 1 });

    const profiles = new ProfilesService(prismaService, storage);

    await expect(profiles.deleteMe(ids.student)).resolves.toMatchObject({
      deleted: true,
    });

    // Le nom civil et le texte de l'étudiant ne survivent pas à son compte : ni
    // l'avis qu'il a signé…
    expect(
      await prisma.counsellorReview.count({ where: { id: reviewId } }),
    ).toBe(0);
    expect(
      await prisma.counsellorReview.count({
        where: { reviewerUserId: ids.student },
      }),
    ).toBe(0);
    // … ni celui d'avant l'auteur-par-jeton, que seul son dossier rattache à lui.
    expect(
      await prisma.counsellorReview.count({ where: { id: ids.legacyOwn } }),
    ).toBe(0);

    // Ce qui n'est pas à lui reste : un avis sans auteur sur le dossier d'un
    // autre, et un avis signé par un autre.
    expect(
      await prisma.counsellorReview.count({
        where: { id: { in: [ids.legacyStranger, ids.strangerAuthored] } },
      }),
    ).toBe(2);

    // Les compteurs dénormalisés suivent : A n'a plus d'avis publié ; B garde
    // celui de l'autre étudiant (2 étoiles), plus le sien (4 étoiles).
    expect(
      await prisma.counsellor.findUniqueOrThrow({
        where: { id: ids.counsellorA },
        select: { avgRating: true, reviewCount: true },
      }),
    ).toEqual({ avgRating: 0, reviewCount: 0 });
    expect(
      await prisma.counsellor.findUniqueOrThrow({
        where: { id: ids.counsellorB },
        select: { avgRating: true, reviewCount: true },
      }),
    ).toEqual({ avgRating: 2, reviewCount: 1 });
  });
});
