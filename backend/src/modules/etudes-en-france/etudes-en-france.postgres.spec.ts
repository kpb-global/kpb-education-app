import { randomUUID } from 'node:crypto';

import { NotFoundException } from '@nestjs/common';
import { PrismaClient } from '@prisma/client';

import type { PrismaService } from '../prisma/prisma.service';
import { EtudesEnFranceService } from './etudes-en-france.service';

/**
 * La mise à jour du profil « Études en France », prouvée contre un vrai Postgres.
 *
 * Les doubles du service prouvent QUELLES colonnes la requête nomme. Ils ne
 * prouvent pas que la base laisse les autres intactes, ni que l'absence de ligne
 * lève bien le code `P2025` que le service traduit en 404 : c'est le contrat de
 * Prisma, pas celui d'un double.
 */
const describePostgres =
  process.env.KPB_RUN_POSTGRES_INTEGRATION === 'true'
    ? describe
    : describe.skip;

describePostgres('Profil EEF — intégration PostgreSQL', () => {
  jest.setTimeout(60_000);

  const prisma = new PrismaClient();
  const sfx = randomUUID().replace(/-/g, '').slice(0, 12);
  const USER_ID = `it-eef-profile-${sfx}`;
  const STRANGER_ID = `it-eef-stranger-${sfx}`;

  const prismaService = {
    isEnabled: true,
    execute: async <T>(operation: (client: PrismaClient) => Promise<T>) =>
      operation(prisma),
  } as unknown as PrismaService;
  const service = new EtudesEnFranceService(prismaService);

  async function createUser(id: string) {
    await prisma.userProfile.create({
      data: {
        id,
        accountType: 'student',
        preferredLanguage: 'fr',
        fullName: 'Étudiant de test',
        email: `${id}@example.test`,
        phone: '+22900000000',
        countryOfResidence: 'BJ',
        fieldIds: [],
        targetCountryIds: [],
      },
    });
  }

  beforeAll(async () => {
    await createUser(USER_ID);
    await createUser(STRANGER_ID);
    await service.declareInterest(USER_ID, {
      consent: true,
      consentVersion: 'eef-consent-v1',
      currentLevel: 'terminale',
      targetLevel: 'licence',
      fieldIds: ['d01'],
      wantsPremium: true,
    });
  });

  afterAll(async () => {
    try {
      await prisma.eefInterest.deleteMany({
        where: { userId: { in: [USER_ID, STRANGER_ID] } },
      });
      await prisma.userProfile.deleteMany({
        where: { id: { in: [USER_ID, STRANGER_ID] } },
      });
    } finally {
      await prisma.$disconnect();
    }
  }, 60_000);

  it('change les domaines et les niveaux sans toucher au consentement ni à l’intérêt Premium', async () => {
    const before = await prisma.eefInterest.findUniqueOrThrow({
      where: { userId: USER_ID },
    });

    const view = await service.updateProfile(USER_ID, {
      targetLevel: 'master',
      fieldIds: ['d07', 'd02'],
    });

    const after = await prisma.eefInterest.findUniqueOrThrow({
      where: { userId: USER_ID },
    });
    // Ce qui devait bouger.
    expect(after.targetLevel).toBe('master');
    expect(after.fieldIds).toEqual(['d07', 'd02']);
    // Ce qui ne devait PAS bouger : la preuve de consentement, l'intérêt Premium,
    // et le niveau non envoyé.
    expect(after.consentedAt.getTime()).toBe(before.consentedAt.getTime());
    expect(after.consentVersion).toBe('eef-consent-v1');
    expect(after.wantsPremium).toBe(true);
    expect(after.currentLevel).toBe('terminale');
    expect(view).toMatchObject({
      wantsPremium: true,
      consentedAt: before.consentedAt.toISOString(),
    });
  });

  it('efface un niveau quand on envoie une chaîne vide, et les domaines quand on envoie []', async () => {
    await service.updateProfile(USER_ID, { currentLevel: '', fieldIds: [] });
    const row = await prisma.eefInterest.findUniqueOrThrow({
      where: { userId: USER_ID },
    });
    expect(row.currentLevel).toBeNull();
    expect(row.fieldIds).toEqual([]);
    expect(row.wantsPremium).toBe(true);
  });

  it('ne crée JAMAIS de ligne : sans déclaration, 404 et rien en base', async () => {
    await expect(
      service.updateProfile(STRANGER_ID, { fieldIds: ['d01'] }),
    ).rejects.toBeInstanceOf(NotFoundException);
    expect(
      await prisma.eefInterest.count({ where: { userId: STRANGER_ID } }),
    ).toBe(0);
  });

  it('ne modifie que la ligne de l’appelant', async () => {
    await service.declareInterest(STRANGER_ID, {
      consent: true,
      consentVersion: 'eef-consent-v1',
      fieldIds: ['d09'],
    });
    await service.updateProfile(USER_ID, { fieldIds: ['d03'] });
    const other = await prisma.eefInterest.findUniqueOrThrow({
      where: { userId: STRANGER_ID },
    });
    expect(other.fieldIds).toEqual(['d09']);
  });
});
