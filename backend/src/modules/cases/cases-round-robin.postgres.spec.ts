import { randomUUID } from 'node:crypto';

import { AccountType, PrismaClient } from '@prisma/client';

import { CaseType } from '../../common/enums/case-type.enum';
import type { PrismaService } from '../prisma/prisma.service';
import type { OneSignalSenderService } from '../notifications/onesignal-sender.service';
import { CasesService } from './cases.service';

/**
 * Le round-robin d'affectation, prouvé contre un vrai Postgres.
 *
 * Deux propriétés, et il faut les DEUX — la première version de ce test n'avait
 * que la seconde, avec des identifiants dont l'ordre alphabétique était déjà
 * le résultat attendu : il ne pouvait donc pas voir que le tri par `id` prenait
 * le pas sur l'ordre voulu (revue P2 #251).
 *
 *   1. `createdAt` COMMANDE la rotation. Les identifiants du premier scénario
 *      sont volontairement dans l'ordre alphabétique INVERSE de l'ordre
 *      attendu : un tri qui retomberait sur `id` rougirait aussitôt.
 *   2. `id` DÉPARTAGE, et seulement à égalité stricte — le cas des trois lignes
 *      de production, insérées par un `now()` unique.
 *
 * Un test unitaire ne pouvait attraper ni l'une ni l'autre : l'ambiguïté vit
 * dans le moteur, et un Prisma simulé rend toujours le tableau qu'on lui donne.
 */
const describePostgres =
  process.env.KPB_RUN_POSTGRES_INTEGRATION === 'true'
    ? describe
    : describe.skip;

describePostgres('Round-robin des conseillers — intégration PostgreSQL', () => {
  const prisma = new PrismaClient();
  const suffix = randomUUID();
  const userId = `rr-user-${suffix}`;

  /** Ordre voulu : c, b, a — soit l'INVERSE de l'ordre alphabétique des id. */
  const ordered = [
    { id: `rr-c-${suffix}`, at: new Date('2026-08-29T00:00:01Z') },
    { id: `rr-b-${suffix}`, at: new Date('2026-08-29T00:00:02Z') },
    { id: `rr-a-${suffix}`, at: new Date('2026-08-29T00:00:03Z') },
  ];

  /** Trois horodatages identiques : l'état exact de la production. */
  const sameInstant = new Date('2026-08-29T18:56:34.634Z');
  const tied = [`rr-tie-z-${suffix}`, `rr-tie-a-${suffix}`, `rr-tie-m-${suffix}`];

  const allIds = [...ordered.map((o) => o.id), ...tied];
  let parkedIds: string[] = [];

  const prismaService = {
    isEnabled: true,
    execute: async <T>(operation: (client: PrismaClient) => Promise<T>) =>
      operation(prisma),
    tryExecute: async <T>(operation: (client: PrismaClient) => Promise<T>) =>
      operation(prisma),
  } as unknown as PrismaService;

  function service() {
    return new CasesService(
      prismaService,
      // `moduleRef` sert à deux choses : la passerelle temps réel (dont
      // l'absence est déjà avalée) et le crédit de parrainage — celui-là n'est
      // PAS protégé, un `get` qui lève ferait échouer la création.
      {
        get: () => ({
          emitCaseUpdated: () => undefined,
          creditReferrerForFirstCase: async () => undefined,
        }),
      } as never,
      { sendToUser: async () => undefined } as unknown as OneSignalSenderService,
    );
  }

  async function counsellor(id: string, createdAt: Date) {
    await prisma.counsellor.create({
      data: {
        id,
        fullName: `Conseiller ${id}`,
        email: `${id}@example.test`,
        phone: '+22790000000',
        countryOfResidence: 'NE',
        specialties: ['admissions'],
        languagesSpoken: ['fr'],
        bioFr: 'Conseiller de test.',
        bioEn: 'Test counsellor.',
        kycStatus: 'approved',
        isActive: false,
        createdAt,
        updatedAt: createdAt,
      },
    });
  }

  /** N'active QUE `ids`, crée `count` dossiers, rend les affectations par seq. */
  async function rotationOf(ids: string[], count: number) {
    await prisma.counsellor.updateMany({
      where: { id: { in: allIds } },
      data: { isActive: false },
    });
    await prisma.counsellor.updateMany({
      where: { id: { in: ids } },
      data: { isActive: true },
    });

    const cases = service();
    const created: string[] = [];
    for (let i = 0; i < count; i += 1) {
      const c = (await cases.create(
        {
          type: CaseType.ApplicationSupport,
          title: `Dossier ${i}`,
          description: 'Test de rotation.',
          contextLabel: 'round-robin',
        },
        userId,
      )) as unknown as { id: string };
      created.push(c.id);
    }

    const rows = await prisma.case.findMany({
      where: { id: { in: created } },
      select: { seq: true, counsellorId: true },
      orderBy: { seq: 'asc' },
    });
    return rows;
  }

  beforeAll(async () => {
    // Les conseillers déjà actifs sont mis en sommeil : la rotation les lirait.
    const others = await prisma.counsellor.findMany({
      where: { isActive: true },
      select: { id: true },
    });
    parkedIds = others.map((o) => o.id);
    if (parkedIds.length > 0) {
      await prisma.counsellor.updateMany({
        where: { id: { in: parkedIds } },
        data: { isActive: false },
      });
    }

    for (const o of ordered) await counsellor(o.id, o.at);
    // En série et dans CET ordre : on veut que l'ordre physique des lignes
    // diffère de l'ordre des identifiants.
    for (const id of tied) await counsellor(id, sameInstant);

    await prisma.userProfile.create({
      data: {
        id: userId,
        accountType: AccountType.student,
        preferredLanguage: 'fr',
        fullName: 'Étudiant round-robin',
        email: `rr-${suffix}@example.test`,
        phone: '+22790000000',
        countryOfResidence: 'Niger',
      },
    });
  });

  afterAll(async () => {
    // Les enfants d'un dossier sont en RESTRICT : les retirer d'abord.
    const mine = await prisma.case.findMany({
      where: { userId },
      select: { id: true },
    });
    const ids = mine.map((c) => c.id);
    if (ids.length > 0) {
      await prisma.caseMessage.deleteMany({ where: { caseId: { in: ids } } });
      await prisma.caseTimelineEvent.deleteMany({ where: { caseId: { in: ids } } });
      await prisma.caseDocument.deleteMany({ where: { caseId: { in: ids } } });
      await prisma.caseTask.deleteMany({ where: { caseId: { in: ids } } });
    }
    await prisma.case.deleteMany({ where: { userId } });
    await prisma.userProfile.deleteMany({ where: { id: userId } });
    await prisma.counsellor.deleteMany({ where: { id: { in: allIds } } });
    if (parkedIds.length > 0) {
      await prisma.counsellor.updateMany({
        where: { id: { in: parkedIds } },
        data: { isActive: true },
      });
    }
    await prisma.$disconnect();
  });

  it('suit createdAt, PAS l\'ordre alphabétique des identifiants', async () => {
    const expected = ordered.map((o) => o.id);
    const alphabetical = [...expected].sort();
    // Le piège que la première version de ce test n'avait pas : si l'attendu
    // était déjà l'ordre alphabétique, un tri par `id` seul passerait.
    expect(alphabetical).not.toEqual(expected);

    const rows = await rotationOf(expected, 6);
    expect(rows).toHaveLength(6);
    for (const row of rows) {
      expect(row.counsellorId).toBe(expected[(row.seq - 1) % expected.length]);
    }
  });

  it('à createdAt strictement égal, départage par id et non par ordre physique', async () => {
    const expected = [...tied].sort();
    // Insérés z, a, m : sans départage, Postgres rendrait l'ordre du tas.
    expect(tied[0]).not.toBe(expected[0]);

    const rows = await rotationOf(tied, 6);
    expect(rows).toHaveLength(6);
    for (const row of rows) {
      expect(row.counsellorId).toBe(expected[(row.seq - 1) % expected.length]);
    }

    const share = new Map<string, number>();
    for (const row of rows) {
      share.set(row.counsellorId!, (share.get(row.counsellorId!) ?? 0) + 1);
    }
    expect([...share.values()].sort()).toEqual([2, 2, 2]);
  });
});
