import { randomUUID } from 'node:crypto';

import { AccountType, PrismaClient } from '@prisma/client';

import { CaseType } from '../../common/enums/case-type.enum';
import type { PrismaService } from '../prisma/prisma.service';
import type { OneSignalSenderService } from '../notifications/onesignal-sender.service';
import { CasesService } from './cases.service';

/**
 * Le round-robin d'affectation, prouvé contre un vrai Postgres.
 *
 * L'incident : les trois conseillers de production ont été insérés par un seul
 * `INSERT … VALUES (…now()), (…now()), (…now())`. `now()` rend l'horodatage de
 * la TRANSACTION, pas de la ligne — les trois `createdAt` sont donc identiques
 * à la milliseconde. Le tri `orderBy: { createdAt: 'asc' }` n'avait aucun
 * départage : Postgres ne doit alors AUCUN ordre, et la rotation
 * « Jojo → Donald → Richard » annoncée par la seed n'était garantie par rien.
 *
 * Un test unitaire ne pouvait pas l'attraper : l'ambiguïté n'existe que dans le
 * moteur, et un Prisma simulé rend toujours le tableau qu'on lui a donné.
 *
 * Pour que ce test MORDE, les trois lignes sont insérées dans un ordre
 * physique différent de l'ordre des identifiants — sinon Postgres rendrait par
 * hasard le bon ordre et le test serait vert même sans départage.
 */
const describePostgres =
  process.env.KPB_RUN_POSTGRES_INTEGRATION === 'true'
    ? describe
    : describe.skip;

describePostgres('Round-robin des conseillers — intégration PostgreSQL', () => {
  const prisma = new PrismaClient();
  const suffix = randomUUID();

  const userId = `rr-user-${suffix}`;
  // Insérés dans CET ordre ; trié par `id`, l'ordre attendu est aaa, mmm, zzz.
  const insertionOrder = [
    `rr-zzz-${suffix}`,
    `rr-aaa-${suffix}`,
    `rr-mmm-${suffix}`,
  ];
  const byId = [...insertionOrder].sort();

  /** Les conseillers actifs qui préexistent, mis en sommeil puis rendus. */
  let parkedIds: string[] = [];
  const createdCaseIds: string[] = [];

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
      // `moduleRef` sert à deux choses ici : la passerelle temps réel (dont
      // l'absence est déjà avalée) et le crédit de parrainage — celui-là n'est
      // PAS protégé, un `get` qui lève ferait échouer la création. On rend donc
      // un double inerte plutôt qu'une exception.
      {
        get: () => ({
          emitCaseUpdated: () => undefined,
          creditReferrerForFirstCase: async () => undefined,
        }),
      } as never,
      { sendToUser: async () => undefined } as unknown as OneSignalSenderService,
    );
  }

  beforeAll(async () => {
    // Un seul horodatage pour les trois : c'est exactement ce que produit
    // `now()` dans la seed de production.
    const sharedCreatedAt = new Date('2026-08-29T18:56:34.634Z');

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

    // `create` en série, pas `createMany` : on veut maîtriser l'ordre physique.
    for (const id of insertionOrder) {
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
          isActive: true,
          createdAt: sharedCreatedAt,
          updatedAt: sharedCreatedAt,
        },
      });
    }

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
    await prisma.counsellor.deleteMany({ where: { id: { in: insertionOrder } } });
    if (parkedIds.length > 0) {
      await prisma.counsellor.updateMany({
        where: { id: { in: parkedIds } },
        data: { isActive: true },
      });
    }
    await prisma.$disconnect();
  });

  it('tourne dans un ordre stable malgré des createdAt identiques', async () => {
    const cases = service();
    for (let i = 0; i < 6; i += 1) {
      const created = (await cases.create(
        {
          type: CaseType.ApplicationSupport,
          title: `Dossier ${i}`,
          description: 'Test de rotation.',
          contextLabel: 'round-robin',
        },
        userId,
      )) as unknown as { id: string };
      createdCaseIds.push(created.id);
    }

    const rows = await prisma.case.findMany({
      where: { userId },
      select: { seq: true, counsellorId: true },
      orderBy: { seq: 'asc' },
    });
    expect(rows).toHaveLength(6);

    // L'affectation se dérive du `seq` attribué par la base, donc elle ne
    // dépend pas de l'état laissé par d'autres tests.
    for (const row of rows) {
      expect(row.counsellorId).toBe(byId[(row.seq - 1) % byId.length]);
    }

    // Et chacun en a bien eu deux : une rotation, pas une préférence.
    const share = new Map<string, number>();
    for (const row of rows) {
      share.set(row.counsellorId!, (share.get(row.counsellorId!) ?? 0) + 1);
    }
    expect([...share.values()].sort()).toEqual([2, 2, 2]);
  });

  it("l'ordre physique d'insertion ne dicte PAS la rotation", async () => {
    // La contre-épreuve du piège : sans `id` en second critère, Postgres rendrait
    // l'ordre du tas — celui de l'insertion — et le premier dossier irait à
    // `rr-zzz`. C'est cette confusion que le départage supprime.
    expect(insertionOrder[0]).not.toBe(byId[0]);

    const first = await prisma.case.findFirst({
      where: { userId },
      orderBy: { seq: 'asc' },
      select: { seq: true, counsellorId: true },
    });
    expect(first?.counsellorId).toBe(byId[(first!.seq - 1) % byId.length]);
  });
});
