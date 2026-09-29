import { randomUUID } from 'node:crypto';

import { AccountType, PrismaClient } from '@prisma/client';

import { purgeOrphanReviews } from './orphan-reviews';

/**
 * Les avis orphelins, contre un vrai Postgres.
 *
 * Un avis orphelin est sans auteur ET sans dossier : plus rien ne le rattache à
 * quelqu'un, et son `reviewerName` est un nom civil. L'outil les supprime (comme
 * `deleteMe` l'aurait fait), recalcule les compteurs du conseiller, et ne touche
 * ni un avis signé ni un avis sans auteur dont le dossier existe encore.
 *
 * Le test restreint l'outil à SES conseillers (`counsellorIds`) : il ne
 * supprime jamais les avis qu'une base de développement contiendrait déjà.
 */
const describePostgres =
  process.env.KPB_RUN_POSTGRES_INTEGRATION === 'true'
    ? describe
    : describe.skip;

describePostgres('Avis orphelins — intégration PostgreSQL', () => {
  jest.setTimeout(60_000);

  const prisma = new PrismaClient();
  const sfx = randomUUID().replace(/-/g, '').slice(0, 12);
  const ids = {
    user: `orph-user-${sfx}`,
    counsellor: `orph-counsellor-${sfx}`,
    otherCounsellor: `orph-other-${sfx}`,
    liveCase: `orph-case-${sfx}`,
    goneOrphan: `orph-gone-${sfx}`,
    noCaseOrphan: `orph-nocase-${sfx}`,
    keptWithCase: `orph-kept-case-${sfx}`,
    signed: `orph-signed-${sfx}`,
    outsideScope: `orph-outside-${sfx}`,
  };
  const scope = { counsellorIds: [ids.counsellor] };

  const review = (
    id: string,
    counsellorId: string,
    over: Record<string, unknown>,
  ) => ({
    id,
    counsellorId,
    reviewerName: `Nom civil ${id}`,
    rating: 3,
    body: `Texte ${id}`,
    isPublished: true,
    ...over,
  });
  const counsellor = (id: string) => ({
    id,
    fullName: `Conseiller ${id}`,
    email: `${id}@example.test`,
    phone: '+22900000001',
    countryOfResidence: 'BJ',
    bioFr: 'Bio.',
    bioEn: 'Bio.',
    isActive: true,
    kycStatus: 'approved' as const,
  });

  beforeAll(async () => {
    await prisma.userProfile.create({
      data: {
        id: ids.user,
        accountType: AccountType.student,
        preferredLanguage: 'fr',
        fullName: 'Étudiante orpheline',
        email: `${ids.user}@example.test`,
        phone: '+22900000000',
        countryOfResidence: 'BJ',
      },
    });
    await prisma.counsellor.createMany({
      data: [counsellor(ids.counsellor), counsellor(ids.otherCounsellor)],
    });
    await prisma.case.create({
      data: {
        id: ids.liveCase,
        referenceCode: `ORPH-${sfx}`,
        userId: ids.user,
        counsellorId: ids.counsellor,
        type: 'consultation',
        status: 'completed',
        title: 'Dossier',
        description: 'Test.',
        contextLabel: 'Test',
        nextStepTitle: 'Test',
        nextStepDescription: 'Test.',
      },
    });
    await prisma.counsellorReview.createMany({
      data: [
        // Orphelin publié : le dossier n'existe plus.
        review(ids.goneOrphan, ids.counsellor, {
          caseId: `orph-deleted-case-${sfx}`,
          rating: 5,
        }),
        // Orphelin non publié : aucun dossier n'a jamais été renseigné.
        review(ids.noCaseOrphan, ids.counsellor, {
          caseId: null,
          rating: 1,
          isPublished: false,
        }),
        // Sans auteur, mais le dossier existe : c'est à son propriétaire.
        review(ids.keptWithCase, ids.counsellor, {
          caseId: ids.liveCase,
          rating: 3,
        }),
        // Signé.
        review(ids.signed, ids.counsellor, {
          reviewerUserId: ids.user,
          caseId: null,
          rating: 4,
        }),
        // Orphelin d'un AUTRE conseiller : hors périmètre du test.
        review(ids.outsideScope, ids.otherCounsellor, {
          caseId: `orph-deleted-case-${sfx}`,
          rating: 2,
        }),
      ],
    });
    // Les compteurs suivent les avis publiés : (5 + 3 + 4) / 3.
    await prisma.counsellor.update({
      where: { id: ids.counsellor },
      data: { avgRating: 4, reviewCount: 3 },
    });
  }, 60_000);

  afterAll(async () => {
    try {
      const counsellorIds = [ids.counsellor, ids.otherCounsellor];
      await prisma.counsellorReview.deleteMany({
        where: { counsellorId: { in: counsellorIds } },
      });
      await prisma.case.deleteMany({ where: { id: ids.liveCase } });
      await prisma.counsellor.deleteMany({ where: { id: { in: counsellorIds } } });
      await prisma.userProfile.deleteMany({ where: { id: ids.user } });
    } finally {
      await prisma.$disconnect();
    }
  }, 60_000);

  const remaining = async (counsellorId: string) =>
    (
      await prisma.counsellorReview.findMany({
        where: { counsellorId },
        select: { id: true },
      })
    )
      .map((r) => r.id)
      .sort();
  const counters = () =>
    prisma.counsellor.findUniqueOrThrow({
      where: { id: ids.counsellor },
      select: { avgRating: true, reviewCount: true },
    });

  it("compte sans rien écrire en simulation", async () => {
    const summary = await purgeOrphanReviews(prisma, { apply: false, ...scope });

    expect(summary).toEqual({
      unauthored: 3,
      orphans: 2,
      orphansPublished: 1,
      keptBecauseCaseExists: 1,
      counsellorsAffected: 1,
      deleted: 0,
    });
    expect(await remaining(ids.counsellor)).toEqual(
      [ids.goneOrphan, ids.noCaseOrphan, ids.keptWithCase, ids.signed].sort(),
    );
    expect(await counters()).toEqual({ avgRating: 4, reviewCount: 3 });
  });

  it("supprime les seuls orphelins, épargne les autres, et recalcule les compteurs", async () => {
    const summary = await purgeOrphanReviews(prisma, { apply: true, ...scope });

    expect(summary.deleted).toBe(2);
    // Ni l'avis signé, ni l'avis sans auteur dont le dossier existe encore…
    expect(await remaining(ids.counsellor)).toEqual(
      [ids.keptWithCase, ids.signed].sort(),
    );
    // … ni ceux d'un conseiller hors périmètre.
    expect(await remaining(ids.otherCounsellor)).toEqual([ids.outsideScope]);
    // (3 + 4) / 2 : l'orphelin publié de 5 étoiles n'y est plus.
    expect(await counters()).toEqual({ avgRating: 3.5, reviewCount: 2 });
  });

  it("est rejouable : plus rien à supprimer, compteurs inchangés", async () => {
    const summary = await purgeOrphanReviews(prisma, { apply: true, ...scope });

    expect(summary).toMatchObject({ orphans: 0, deleted: 0 });
    expect(await counters()).toEqual({ avgRating: 3.5, reviewCount: 2 });
  });

  it("supprime aussi l'orphelin dont le dossier disparaît APRÈS coup", async () => {
    // Le propriétaire supprime son compte : le dossier s'en va, l'avis sans
    // auteur qui le portait devient orphelin.
    await prisma.case.delete({ where: { id: ids.liveCase } });

    const summary = await purgeOrphanReviews(prisma, { apply: true, ...scope });

    expect(summary).toMatchObject({ orphans: 1, deleted: 1 });
    expect(await remaining(ids.counsellor)).toEqual([ids.signed]);
    expect(await counters()).toEqual({ avgRating: 4, reviewCount: 1 });
  });

  it("ne supprime pas un avis qui a reçu un auteur entre la lecture et l'écriture", async () => {
    // Le plan est lu (l'avis est sans auteur, dossier disparu : orphelin), puis
    // la reprise de la migration, rejouée, lui rattache son auteur, puis la
    // transaction démarre. Le WHERE répète `reviewerUserId: null` : l'avis, qui a
    // maintenant un propriétaire, ne doit pas être emporté par un plan périmé.
    const lateId = `orph-late-${sfx}`;
    await prisma.counsellorReview.create({
      data: review(lateId, ids.counsellor, {
        caseId: `orph-deleted-case-${sfx}`,
        isPublished: false,
      }),
    });
    const racing = new Proxy(prisma, {
      get(target, property, receiver) {
        if (property === '$transaction') {
          return async (...args: unknown[]) => {
            await prisma.counsellorReview.update({
              where: { id: lateId },
              data: { reviewerUserId: ids.user },
            });
            return (target.$transaction as (...a: unknown[]) => unknown)(...args);
          };
        }
        const value = Reflect.get(target, property, receiver) as unknown;
        return typeof value === 'function'
          ? (value as (...a: unknown[]) => unknown).bind(target)
          : value;
      },
    });

    const summary = await purgeOrphanReviews(racing, { apply: true, ...scope });

    expect(summary.orphans).toBe(1);
    expect(summary.deleted).toBe(0);
    expect(
      await prisma.counsellorReview.count({ where: { id: lateId } }),
    ).toBe(1);
  });
});
