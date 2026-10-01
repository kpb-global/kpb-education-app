import { randomUUID } from 'node:crypto';

import { PrismaClient } from '@prisma/client';

import type { PrismaService } from '../prisma/prisma.service';
import { CampaignExecutorService } from './campaign-executor.service';

/**
 * Les audiences « Études en France », prouvées contre un vrai Postgres.
 *
 * Les doubles de `campaign-executor.service.spec.ts` prouvent QUELLE clause la
 * requête construit. Ils ne prouvent pas ce que la base en fait : que `NOT (OR
 * …)` ne retire pas les comptes sans pays, que `mode: 'insensitive'` attrape
 * « NIGER », que `eefInterest: { isNot: null }` ne ramène que ceux qui ont une
 * ligne. C'est le contrat de Postgres, pas celui d'un double — et c'est de lui
 * que dépend « la campagne est ouverte » arrivant, ou non, à un étudiant d'un
 * pays dont l'État dit que les dossiers ne sont pas traités.
 */
const describePostgres =
  process.env.KPB_RUN_POSTGRES_INTEGRATION === 'true'
    ? describe
    : describe.skip;

describePostgres('Audiences EEF — intégration PostgreSQL', () => {
  jest.setTimeout(60_000);

  const prisma = new PrismaClient();
  const sfx = randomUUID().replace(/-/g, '').slice(0, 10);
  const id = (name: string) => `it-aud-${name}-${sfx}`;

  const prismaService = {
    isEnabled: true,
    execute: async <T>(operation: (client: PrismaClient) => Promise<T>) =>
      operation(prisma),
  } as unknown as PrismaService;
  const executor = new CampaignExecutorService(
    prismaService,
    {} as never,
    {} as never,
  );

  const users = {
    senegalDeclarant: { country: 'Sénégal', type: 'student', declared: true },
    nigerDeclarant: { country: 'Niger', type: 'student', declared: true },
    nigerUpperDeclarant: { country: 'NIGER', type: 'student', declared: true },
    nigerPlain: { country: 'niger', type: 'student', declared: false },
    senegalPlain: { country: 'Sénégal', type: 'student', declared: false },
    nigeria: { country: 'Nigeria', type: 'student', declared: true },
    parentDeclarant: { country: 'Sénégal', type: 'parent', declared: false },
  } as const;

  async function recipientsOf(
    audience: string,
    filters: Record<string, unknown>,
  ): Promise<string[]> {
    const rows = await executor.resolveRecipients(audience, filters);
    // On ne regarde QUE les comptes de ce test : la base peut contenir d'autres
    // lignes.
    return rows
      .map((row) => row.id)
      .filter((value) => value.endsWith(`-${sfx}`))
      .sort();
  }

  const ids = (...names: (keyof typeof users)[]) =>
    names.map((name) => id(name)).sort();

  beforeAll(async () => {
    for (const [name, spec] of Object.entries(users)) {
      await prisma.userProfile.create({
        data: {
          id: id(name),
          accountType: spec.type,
          preferredLanguage: 'fr',
          fullName: `Test ${name}`,
          email: `${id(name)}@example.test`,
          phone: '+22900000000',
          countryOfResidence: spec.country,
          fieldIds: [],
          targetCountryIds: [],
        },
      });
      if (spec.declared) {
        await prisma.eefInterest.create({
          data: {
            userId: id(name),
            consentVersion: 'eef-consent-v1',
            consentedAt: new Date(),
            fieldIds: [],
          },
        });
      }
    }
  });

  afterAll(async () => {
    try {
      const all = Object.keys(users).map(id);
      await prisma.eefInterest.deleteMany({ where: { userId: { in: all } } });
      await prisma.userProfile.deleteMany({ where: { id: { in: all } } });
    } finally {
      await prisma.$disconnect();
    }
  });

  describe('eef_interest', () => {
    it('ne ramène que les étudiants qui ont une déclaration', async () => {
      expect(await recipientsOf('eef_interest', {})).toEqual(
        ids(
          'senegalDeclarant',
          'nigerDeclarant',
          'nigerUpperDeclarant',
          'nigeria',
        ),
      );
    });

    it('exclut les pays suspendus, quelle que soit la casse', async () => {
      expect(
        await recipientsOf('eef_interest', { exceptCountries: ['Niger'] }),
      ).toEqual(ids('senegalDeclarant', 'nigeria'));
    });

    // Le piège du préfixe : « Niger » est un préfixe de « Nigeria », et une
    // comparaison par `contains` aurait retiré le Nigeria de la campagne.
    it('ne confond PAS le Nigeria avec le Niger', async () => {
      const got = await recipientsOf('eef_interest', {
        exceptCountries: ['Niger'],
      });
      expect(got).toContain(id('nigeria'));
    });

    it("le jeton suit la liste de l'exploitation", async () => {
      const previous = process.env.KPB_EEF_SUSPENDED_COUNTRIES;
      process.env.KPB_EEF_SUSPENDED_COUNTRIES = 'Niger,NE';
      try {
        expect(
          await recipientsOf('eef_interest', {
            exceptCountries: ['eef_suspended'],
          }),
        ).toEqual(ids('senegalDeclarant', 'nigeria'));
      } finally {
        if (previous === undefined) {
          delete process.env.KPB_EEF_SUSPENDED_COUNTRIES;
        } else {
          process.env.KPB_EEF_SUSPENDED_COUNTRIES = previous;
        }
      }
    });
  });

  describe('all_students_except_countries', () => {
    it('retire le pays donné, garde les autres étudiants — pas les parents', async () => {
      expect(
        await recipientsOf('all_students_except_countries', {
          exceptCountries: ['Niger'],
        }),
      ).toEqual(ids('senegalDeclarant', 'senegalPlain', 'nigeria'));
    });

    it('accepte plusieurs pays', async () => {
      expect(
        await recipientsOf('all_students_except_countries', {
          exceptCountries: ['Niger', 'Nigeria'],
        }),
      ).toEqual(ids('senegalDeclarant', 'senegalPlain'));
    });

    // Une exclusion illisible est « personne », jamais « tous les étudiants ».
    it('une exclusion vide ne ramène personne', async () => {
      expect(
        await recipientsOf('all_students_except_countries', {
          exceptCountries: [],
        }),
      ).toEqual([]);
      expect(await recipientsOf('all_students_except_countries', {})).toEqual(
        [],
      );
    });
  });
});
