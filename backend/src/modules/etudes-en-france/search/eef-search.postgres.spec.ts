import { randomUUID } from 'node:crypto';

import { Prisma, PrismaClient } from '@prisma/client';

import {
  EEF_INSTITUTION_ID_PREFIX,
  EEF_PROGRAM_ID_PREFIX,
} from '../../../common/eef-provenance';
import { AdminCatalogService } from '../../admin-catalog/admin-catalog.service';
import type { PrismaService } from '../../prisma/prisma.service';
import {
  FRANCE_COUNTRY_CODES,
  resolveFranceCountryId,
} from '../catalog/eef-country';
import { programSearchText } from '../catalog/eef-search-text';
import { EefSearchService } from './eef-search.service';

/**
 * La recherche libre « Études en France », prouvée contre un vrai Postgres.
 *
 * Les doubles de `eef-search.service.spec.ts` prouvent QUELLE question est posée.
 * Ils ne disent pas si la base répond ce qu'on croit à un `OR` de quatre branches
 * dont une porte sur un `IN` d'établissements et une autre sur un `IN` de cycles.
 *
 * ## Les lignes, et ce que chacune prouve
 *
 *   p1  « Master — Génie civil », Besançon, texte normalisé renseigné
 *         le cas nominal : « genie » et « besancon » doivent la trouver.
 *   p2  « Master — Génie civil », Besançon, texte normalisé NUL
 *         la ligne pas encore rattrapée : la comparaison brute la retrouve à
 *         « génie » accentué, pas à « genie ». Documenté, pas caché.
 *   p3  « L1 - Droit »        sous A   un niveau (licence1)
 *   p4  « L2 - Histoire »     sous B   un autre établissement, un autre niveau
 *   p5  « L1 - Droit »        sous un établissement EN ATTENTE
 *         ne doit JAMAIS être trouvée, même par le nom de son établissement.
 *
 * Tous les noms d'établissement portent un jeton unique par exécution : une base
 * qui contient déjà le vrai catalogue n'invalide pas les lectures.
 */
const describePostgres =
  process.env.KPB_RUN_POSTGRES_INTEGRATION === 'true'
    ? describe
    : describe.skip;

describePostgres('Recherche EEF — intégration PostgreSQL', () => {
  jest.setTimeout(60_000);

  const prisma = new PrismaClient();
  const sfx = randomUUID().replace(/-/g, '').slice(0, 12);
  /// Un mot entier, alphanumérique, propre à cette exécution.
  const tok = `zz${sfx}`;
  const acr = `acr${sfx}`;

  const ids = {
    instA: `${EEF_INSTITUTION_ID_PREFIX}${sfx}-a`,
    instB: `${EEF_INSTITUTION_ID_PREFIX}${sfx}-b`,
    instPending: `${EEF_INSTITUTION_ID_PREFIX}${sfx}-pending`,
    p1: `${EEF_PROGRAM_ID_PREFIX}${sfx}-p1`,
    p2: `${EEF_PROGRAM_ID_PREFIX}${sfx}-p2`,
    p3: `${EEF_PROGRAM_ID_PREFIX}${sfx}-p3`,
    p4: `${EEF_PROGRAM_ID_PREFIX}${sfx}-p4`,
    p5: `${EEF_PROGRAM_ID_PREFIX}${sfx}-p5`,
  };
  const institutionIds = [ids.instA, ids.instB, ids.instPending];
  const programIds = [ids.p1, ids.p2, ids.p3, ids.p4, ids.p5];

  const prismaService = {
    isEnabled: true,
    execute: async <T>(operation: (client: PrismaClient) => Promise<T>) =>
      operation(prisma),
    tryExecute: async <T>(operation: (client: PrismaClient) => Promise<T>) =>
      operation(prisma),
  } as unknown as PrismaService;
  const search = new EefSearchService(prismaService);
  const admin = new AdminCatalogService(prismaService);

  let franceId = '';
  let createdCountryId: string | null = null;

  function institution(
    id: string,
    overrides: Partial<Prisma.InstitutionUncheckedCreateInput>,
  ): Prisma.InstitutionUncheckedCreateInput {
    return {
      id,
      nameFr: `Établissement ${id}`,
      nameEn: `Institution ${id}`,
      countryId: franceId,
      locationFr: 'Rennes, Bretagne',
      locationEn: 'Rennes, Brittany',
      overviewFr: 'Test.',
      overviewEn: 'Test.',
      studyLevels: ['master'],
      tuitionLabelFr: 'Test',
      tuitionLabelEn: 'Test',
      languageRequirementsFr: 'Test',
      languageRequirementsEn: 'Test',
      intakePeriods: [],
      programIds: [],
      institutionType: 'universite_publique',
      lastVerifiedAt: new Date(),
      ...overrides,
    };
  }

  function program(
    id: string,
    institutionId: string,
    nameFr: string,
    campusCity: string,
    overrides: Partial<Prisma.ProgramUncheckedCreateInput>,
  ): Prisma.ProgramUncheckedCreateInput {
    return {
      id,
      institutionId,
      countryId: franceId,
      fieldId: 'd07',
      nameFr,
      nameEn: nameFr,
      levelFr: 'Niveau',
      levelEn: 'Level',
      durationFr: '3 ans',
      durationEn: '3 years',
      tuitionFr: 'Test',
      tuitionEn: 'Test',
      languageFr: 'Français',
      languageEn: 'French',
      requirementsFr: [],
      requirementsEn: [],
      procedureType: 'eef',
      selectivity: 'selective',
      campusCity,
      isActive: true,
      lastVerifiedAt: new Date(),
      ...overrides,
    };
  }

  /** Les identifiants servis pour `q`, triés. */
  async function served(q: string): Promise<string[]> {
    const result = await search.search({ q, limit: '50' });
    return (result.items as Array<{ id: string }>).map((item) => item.id).sort();
  }
  const sorted = (...list: string[]) => [...list].sort();

  beforeAll(async () => {
    const activeCountries = await prisma.country.findMany({
      where: { isActive: true },
      select: { id: true, code: true },
    });
    const frances = activeCountries.filter((country) =>
      (FRANCE_COUNTRY_CODES as readonly string[]).includes(
        (country.code ?? '').trim().toUpperCase(),
      ),
    );
    if (frances.length === 1) {
      franceId = resolveFranceCountryId(activeCountries);
    } else if (frances.length === 0) {
      createdCountryId = `it-fra-${sfx}`;
      await prisma.country.create({
        data: {
          id: createdCountryId,
          code: 'FRA',
          nameFr: 'France (test)',
          nameEn: 'France (test)',
          whyStudyFr: 'Test.',
          whyStudyEn: 'Test.',
          tuitionRangeFr: 'Test.',
          tuitionRangeEn: 'Test.',
          livingCostRangeFr: 'Test.',
          livingCostRangeEn: 'Test.',
          visaOverviewFr: 'Test.',
          visaOverviewEn: 'Test.',
          admissionDifficultyFr: 'Test.',
          admissionDifficultyEn: 'Test.',
          popularFieldIds: [],
          lastVerifiedAt: new Date(),
        },
      });
      franceId = createdCountryId;
    } else {
      throw new Error(
        `Base inutilisable : ${frances.length} pays actifs de code FR/FRA.`,
      );
    }

    await prisma.institution.createMany({
      data: [
        institution(ids.instA, {
          nameFr: `Université Alpha ${tok}`,
          nameEn: `University Alpha ${tok}`,
          acronym: acr.toUpperCase(),
          isActive: true,
          logoUrl:
            'https://upload.wikimedia.org/wikipedia/commons/thumb/a/ab/Test.svg/320px-Test.svg.png',
          logoSourceUrl: 'https://commons.wikimedia.org/wiki/File:Test.svg',
          logoLicence: 'CC0',
        }),
        institution(ids.instB, {
          nameFr: `Université Beta ${tok}b`,
          isActive: true,
        }),
        institution(ids.instPending, {
          nameFr: `Université Pending ${tok}p`,
          isActive: false,
        }),
      ],
    });

    const genie = `Master — Génie civil ${sfx}`;
    await prisma.program.createMany({
      data: [
        program(ids.p1, ids.instA, genie, 'Besançon', {
          cycle: 'master',
          searchText: programSearchText(genie, 'Besançon'),
        }),
        program(ids.p2, ids.instA, genie, 'Besançon', {
          cycle: 'master',
          searchText: null,
        }),
        program(ids.p3, ids.instA, 'L1 - Droit', 'Rennes', {
          cycle: 'licence1',
          searchText: programSearchText('L1 - Droit', 'Rennes'),
        }),
        program(ids.p4, ids.instB, 'L2 - Histoire', 'Lyon', {
          cycle: 'licence2',
          searchText: programSearchText('L2 - Histoire', 'Lyon'),
        }),
        program(ids.p5, ids.instPending, 'L1 - Droit', 'Rennes', {
          cycle: 'licence1',
          searchText: programSearchText('L1 - Droit', 'Rennes'),
        }),
      ],
    });
  });

  afterAll(async () => {
    try {
      await prisma.program.deleteMany({ where: { id: { in: programIds } } });
      await prisma.institution.deleteMany({ where: { id: { in: institutionIds } } });
      if (createdCountryId !== null) {
        await prisma.country.deleteMany({ where: { id: createdCountryId } });
      }
    } finally {
      await prisma.$disconnect();
    }
  }, 60_000);

  describe('sans accents', () => {
    it('« genie » trouve « Génie civil », accentué ou non, en majuscules ou non', async () => {
      for (const typed of ['genie', 'génie', 'GENIE', 'GÉNIE']) {
        expect(await served(`${sfx} ${typed}`)).toContain(ids.p1);
      }
      expect(await served(`${sfx} genie`)).not.toContain(ids.p3);
    });

    it('« besancon » trouve Besançon', async () => {
      expect(await served(`${sfx} besancon`)).toContain(ids.p1);
    });

    it('avant rattrapage, la comparaison brute retrouve « génie » accentué mais pas « genie »', async () => {
      // p2 a son texte normalisé NUL. Ce n'est pas un état voulu, c'est celui des
      // lignes importées avant la colonne : le repli garantit qu'elles ne
      // disparaissent pas, et `eef:backfill:search` les met au niveau des autres.
      expect(await served(`${sfx} génie`)).toEqual(sorted(ids.p1, ids.p2));
      expect(await served(`${sfx} genie`)).toEqual([ids.p1]);
    });
  });

  describe('par établissement', () => {
    it('trouve les formations d’un établissement par un mot de son nom', async () => {
      expect(await served(tok)).toEqual(sorted(ids.p1, ids.p2, ids.p3, ids.p4));
      expect(await served('alpha ' + tok)).toEqual(sorted(ids.p1, ids.p2, ids.p3));
    });

    it('trouve un établissement par son sigle', async () => {
      expect(await served(acr)).toEqual(sorted(ids.p1, ids.p2, ids.p3));
      expect(await served(acr.toUpperCase())).toEqual(sorted(ids.p1, ids.p2, ids.p3));
    });

    it('jamais par un morceau au milieu d’un mot', async () => {
      // « lpha » est au milieu de « Alpha » : l'établissement ne doit pas être
      // désigné, donc ses formations (dont l'intitulé ne le contient pas) non plus.
      const found = await served('lpha');
      for (const id of [ids.p3, ids.p4]) expect(found).not.toContain(id);
      // Et le sigle n'est pas un préfixe de mot : « cr » ne désigne pas « acr… ».
      expect(await served(acr.slice(1))).toEqual([]);
    });

    it('ne sert rien d’un établissement en attente, même nommé', async () => {
      expect(await served(`${tok}p`)).toEqual([]);
      expect(await served(`pending ${tok}p`)).toEqual([]);
      expect(await served(tok)).not.toContain(ids.p5);
    });

    it('se combine avec les autres mots : tous doivent être satisfaits', async () => {
      expect(await served(`${tok} droit`)).toEqual([ids.p3]);
      expect(await served(`${tok} histoire`)).toEqual([ids.p4]);
      expect(await served(`${tok} introuvable`)).toEqual([]);
    });
  });

  describe('par niveau', () => {
    it('« licence » désigne L1, L2 et L3 — pas les masters', async () => {
      expect(await served(`${tok} licence`)).toEqual(sorted(ids.p3, ids.p4));
    });

    it('« master » désigne les masters', async () => {
      expect(await served(`${tok} master`)).toEqual(sorted(ids.p1, ids.p2));
    });

    it('« L2 » désigne la deuxième année', async () => {
      expect(await served(`${tok} l2`)).toEqual([ids.p4]);
    });

    it('« licence droit » trouve « L1 - Droit », qui ne contient pas le mot « licence »', async () => {
      expect(await served(`${tok} licence droit`)).toEqual([ids.p3]);
    });

    it('les mots vides ne restreignent rien : « licence de droit » = « licence droit »', async () => {
      expect(await served(`${tok} licence de droit`)).toEqual(
        await served(`${tok} licence droit`),
      );
    });
  });

  describe('ce que chaque item dit', () => {
    it('nomme l’établissement, avec son logo servi à 330 px ET sa licence', async () => {
      const result = await search.search({ q: `${tok} droit` });
      const [item] = result.items as Array<Record<string, any>>;
      expect(item).toMatchObject({
        id: ids.p3,
        cycle: 'licence1',
        procedureType: 'eef',
        campusCity: 'Rennes',
        institution: {
          id: ids.instA,
          name: { fr: `Université Alpha ${tok}` },
          acronym: acr.toUpperCase(),
          logoLicence: 'CC0',
          logoSourceUrl: 'https://commons.wikimedia.org/wiki/File:Test.svg',
        },
      });
      expect(item.institution.logoUrl).toContain('330px');
    });
  });

  describe('catalogPublished', () => {
    it('est vrai quand la recherche est trop étroite sur un catalogue publié', async () => {
      const result = await search.search({ q: `introuvable${sfx}` });
      expect(result.total).toBe(0);
      expect(result.catalogPublished).toBe(true);
    });

    it('est vrai quand il y a des résultats', async () => {
      expect((await search.search({ q: tok })).catalogPublished).toBe(true);
    });
  });

  describe('les facettes et le total suivent les mêmes mots', () => {
    it('compte la même chose que la page', async () => {
      const result = await search.search({ q: `${tok} licence` });
      expect(result.total).toBe(2);
      const cycles = Object.fromEntries(
        (result.facets.cycle ?? []).map((entry) => [entry.value, entry.count]),
      );
      // La facette « cycle » est comptée SANS son propre filtre, mais avec les
      // autres mots : « licence » désigne des cycles, pas un filtre de cycle.
      expect(cycles.licence1).toBe(1);
      expect(cycles.licence2).toBe(1);
    });
  });

  // Doit rester le DERNIER bloc : il renomme p3.
  describe('une formation renommée depuis l’admin reste cherchée sous son nouveau nom', () => {
    it('le nouveau mot la trouve, l’ancien non — le texte cherchable suit la ligne', async () => {
      expect(await served(`${tok} droit`)).toEqual([ids.p3]);

      await admin.updateProgram(ids.p3, { nameFr: 'L1 - Économie' });

      const row = await prisma.program.findUniqueOrThrow({ where: { id: ids.p3 } });
      expect(row.searchText).toBe('l1 economie rennes');
      // Sans le recalcul, `searchText` restait « l1 droit rennes » : « droit »
      // trouvait encore la formation, et « economie » (sans accent) la manquait.
      expect(await served(`${tok} economie`)).toEqual([ids.p3]);
      expect(await served(`${tok} économie`)).toEqual([ids.p3]);
      expect(await served(`${tok} droit`)).toEqual([]);
    });
  });
});
