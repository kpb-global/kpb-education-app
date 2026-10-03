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
  /// Le jeton de l'établissement « santé », distinct de `tok` : ses formations ne
  /// doivent pas entrer dans les listes exactes que les autres blocs attendent.
  const tokS = `yy${sfx}`;

  const ids = {
    instA: `${EEF_INSTITUTION_ID_PREFIX}${sfx}-a`,
    instB: `${EEF_INSTITUTION_ID_PREFIX}${sfx}-b`,
    instPending: `${EEF_INSTITUTION_ID_PREFIX}${sfx}-pending`,
    p1: `${EEF_PROGRAM_ID_PREFIX}${sfx}-p1`,
    p2: `${EEF_PROGRAM_ID_PREFIX}${sfx}-p2`,
    p3: `${EEF_PROGRAM_ID_PREFIX}${sfx}-p3`,
    p4: `${EEF_PROGRAM_ID_PREFIX}${sfx}-p4`,
    p5: `${EEF_PROGRAM_ID_PREFIX}${sfx}-p5`,
    instS: `${EEF_INSTITUTION_ID_PREFIX}${sfx}-s`,
    /// Une L.AS : « L1 - Chimie » en accès santé. Son intitulé ne dit rien de la santé.
    las: `${EEF_PROGRAM_ID_PREFIX}${sfx}-las`,
    /// La même « L1 - Chimie », sans accès santé.
    chimie: `${EEF_PROGRAM_ID_PREFIX}${sfx}-chim`,
    /// Un PASS, dont l'intitulé porte « Santé » et « PASS ».
    pass: `${EEF_PROGRAM_ID_PREFIX}${sfx}-pass`,
    /// Un diplôme paramédical de la famille « Études de santé » : pas un accès
    /// aux études de médecine.
    ortho: `${EEF_PROGRAM_ID_PREFIX}${sfx}-ortho`,
    /// « plastiques » contient « las ».
    plast: `${EEF_PROGRAM_ID_PREFIX}${sfx}-plast`,
  };
  const institutionIds = [ids.instA, ids.instB, ids.instPending, ids.instS];
  const programIds = [
    ids.p1, ids.p2, ids.p3, ids.p4, ids.p5, ids.las, ids.chimie, ids.pass, ids.ortho, ids.plast,
  ];

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
        institution(ids.instS, {
          nameFr: `Université Gamma ${tokS}`,
          isActive: true,
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
        program(ids.las, ids.instS, 'L1 - Chimie', 'Tours', {
          cycle: 'sante',
          procedureType: 'dap_blanche',
          searchText: programSearchText('L1 - Chimie', 'Tours'),
        }),
        program(ids.chimie, ids.instS, 'L1 - Chimie', 'Tours', {
          cycle: 'licence1',
          procedureType: 'dap_blanche',
          searchText: programSearchText('L1 - Chimie', 'Tours'),
        }),
        program(ids.pass, ids.instS, "L1 - Parcours d'Accès Spécifique Santé (PASS)", 'Tours', {
          cycle: 'sante',
          procedureType: 'dap_blanche',
          searchText: programSearchText("L1 - Parcours d'Accès Spécifique Santé (PASS)", 'Tours'),
        }),
        program(ids.ortho, ids.instS, "Certificat de capacité d'Orthophoniste", 'Tours', {
          cycle: 'sante',
          procedureType: 'dap_blanche',
          searchText: programSearchText("Certificat de capacité d'Orthophoniste", 'Tours'),
        }),
        program(ids.plast, ids.instS, 'L1 - Arts plastiques', 'Tours', {
          cycle: 'licence1',
          procedureType: 'dap_blanche',
          searchText: programSearchText('L1 - Arts plastiques', 'Tours'),
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

  describe('par les mots des études de santé', () => {
    // Aucun intitulé du catalogue ne contient « médecine » : on y entre par un PASS
    // ou une L.AS (« L1 - Chimie » en accès santé). Mesuré en production le
    // 01/10/2026 : `q=medecine` rendait 0 résultat, puis, mené au cycle `sante`
    // entier, les diplômes paramédicaux en tête — aucune PASS ni L.AS dans les 50
    // premiers résultats.
    it('« médecine » trouve le PASS et la L.AS — ni la même licence sans accès santé, ni l’orthophonie', async () => {
      expect(await served(`${tokS} medecine`)).toEqual(sorted(ids.las, ids.pass));
      expect(await served(`${tokS} médecine`)).toEqual(sorted(ids.las, ids.pass));
      expect(await served(`${tokS} Médecine`)).toEqual(sorted(ids.las, ids.pass));
    });

    it.each(['pharmacie', 'kine', 'maieutique', 'dentaire', 'las', 'L.AS', 'L AS'])(
      '« %s » désigne l’accès santé, et lui seul',
      async (word) => {
        expect(await served(`${tokS} ${word}`)).toEqual(sorted(ids.las, ids.pass));
      },
    );

    it('« las » ne trouve pas « Arts plastiques »', async () => {
      expect(await served(`${tokS} las`)).not.toContain(ids.plast);
      // Le mot « plastiques » le trouve toujours.
      expect(await served(`${tokS} plastiques`)).toEqual([ids.plast]);
    });

    it('« PASS » trouve le PASS, pas la L.AS', async () => {
      expect(await served(`${tokS} pass`)).toEqual([ids.pass]);
    });

    it.each(['santé', 'health'])('« %s » trouve toute la famille santé, orthophonie comprise', async (word) => {
      expect(await served(`${tokS} ${word}`)).toEqual(sorted(ids.las, ids.pass, ids.ortho));
    });

    it('l’orthophonie se trouve par son nom', async () => {
      expect(await served(`${tokS} orthophoniste`)).toEqual([ids.ortho]);
    });

    it('la carte dit « accès santé » pour le PASS et la L.AS, et pour eux seuls', async () => {
      const result = await search.search({ q: tokS, limit: '50' });
      const healthAccess = Object.fromEntries(
        (result.items as Array<{ id: string; healthAccess: boolean }>).map((item) => [
          item.id,
          item.healthAccess,
        ]),
      );
      expect(healthAccess).toEqual({
        [ids.las]: true,
        [ids.pass]: true,
        [ids.chimie]: false,
        [ids.ortho]: false,
        [ids.plast]: false,
      });
    });

    it('« chimie » trouve les deux licences : le synonyme n’ôte rien au texte', async () => {
      expect(await served(`${tokS} chimie`)).toEqual(sorted(ids.las, ids.chimie));
    });

    it('« médecine chimie » trouve la seule L.AS de chimie : chaque mot resserre', async () => {
      expect(await served(`${tokS} medecine chimie`)).toEqual([ids.las]);
    });

    it('« licence » ne désigne pas l’accès santé', async () => {
      expect(await served(`${tokS} licence`)).toEqual(sorted(ids.chimie, ids.plast));
    });

    it('un mot sans rapport ne trouve toujours rien', async () => {
      expect(await served(`${tokS} droit`)).toEqual([]);
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

  // ── Les villes : la liste COMPLÈTE, avec des compteurs croisés ──────────────
  //
  // `GET /etudes-en-france/cities`. La facette `campusCity` de la recherche
  // s'arrête à 20 villes ; celle-ci les rend toutes, chacune avec ce que la
  // recherche rendrait SI ON LA CHOISISSAIT, les autres filtres restant ceux de
  // l'écran. Les doublures du service disent QUELLE question est posée ; seule
  // une base réelle dit ce qu'elle répond : les accents, l'apostrophe, les
  // ex æquo, et surtout que le compteur d'une ville égale le total de la
  // recherche qui la choisit.
  //
  // Ce bloc a SES établissements, SES formations et SON jeton, et chaque lecture
  // est bornée à ses établissements (`institutionId`) : une base qui contient
  // déjà le vrai catalogue — ou les lignes des autres blocs — ne change aucune
  // réponse attendue.
  describe('villes — la liste complète, avec compteurs croisés', () => {
    const ctok = `cc${sfx}`;
    const cityIds = {
      inst1: `${EEF_INSTITUTION_ID_PREFIX}${sfx}-c1`,
      inst2: `${EEF_INSTITUTION_ID_PREFIX}${sfx}-c2`,
      /// Établissement EN ATTENTE : ses formations, actives, ne doivent donner
      /// aucune ville.
      instPending: `${EEF_INSTITUTION_ID_PREFIX}${sfx}-cp`,
      /// Établissement partenaire, ACTIF mais hors import : ses formations,
      /// qualifiées d'une procédure, ne sont pas de cet espace.
      instPartner: `partner-${sfx}-c`,
    };
    const scope = [
      cityIds.inst1,
      cityIds.inst2,
      cityIds.instPending,
      cityIds.instPartner,
    ];

    interface CityRow {
      key: string;
      inst: string;
      city: string | null;
      name?: string;
      procedureType?: string | null;
      cycle?: string;
      selectivity?: string;
      fieldId?: string;
      isActive?: boolean;
      /// Un identifiant hors du préfixe de l'import.
      partnerId?: boolean;
    }

    const FILLERS = Array.from({ length: 25 }, (_, i) => `Filler ${String(i).padStart(2, '0')}`);

    /// Tout est écrit ici : chaque compteur attendu plus bas se relit sur cette
    /// table. Par défaut une ligne est « eef · master · sélective · d07 ».
    const cityRows: CityRow[] = [
      // Paris : 3 formations actives, plus une INACTIVE qui ne compte pas.
      { key: 'p-a', inst: cityIds.inst1, city: 'Paris', name: 'Master - Droit' },
      { key: 'p-b', inst: cityIds.inst1, city: 'Paris', procedureType: 'dap_blanche', cycle: 'licence1', selectivity: 'non_selective' },
      { key: 'p-c', inst: cityIds.inst2, city: 'Paris', fieldId: 'd01' },
      { key: 'p-x', inst: cityIds.inst1, city: 'Paris', isActive: false },
      // Trois villes à 2 : l'ordre des ex æquo ne tient qu'aux accents ôtés.
      { key: 'e-a', inst: cityIds.inst2, city: 'Épinal', cycle: 'licence2' },
      { key: 'e-b', inst: cityIds.inst2, city: 'Épinal', procedureType: 'dap_blanche', cycle: 'licence1', selectivity: 'non_selective' },
      { key: 'v-a', inst: cityIds.inst1, city: 'Evry', name: 'Master - Droit' },
      { key: 'v-b', inst: cityIds.inst1, city: 'Evry' },
      // L'apostrophe : la valeur doit revenir intacte dans `campusCity`.
      { key: 's-a', inst: cityIds.inst1, city: "Saint-Martin-d'Hères", cycle: 'licence3', name: 'L3 - Droit' },
      { key: 's-b', inst: cityIds.inst2, city: "Saint-Martin-d'Hères", cycle: 'licence3', selectivity: 'non_selective' },
      // Deux graphies d'une même ville, comme dans le catalogue réel (deux jeux
      // ouverts) : deux entrées, chacune avec son propre compteur.
      { key: 'b-a', inst: cityIds.inst1, city: 'Besançon' },
      { key: 'b-b', inst: cityIds.inst1, city: 'Besancon' },
      { key: 'z-a', inst: cityIds.inst2, city: 'Zola-sur-Mer', procedureType: 'dap_blanche', cycle: 'licence1' },
      // Vingt-cinq villes de plus : 32 en tout, la facette en rend 20.
      ...FILLERS.map((city, i) => ({
        key: `f-${i}`,
        inst: cityIds.inst2,
        city,
      })),
      // Sans ville : dans `total`, dans aucune ville.
      { key: 'n-a', inst: cityIds.inst1, city: null },
      { key: 'n-b', inst: cityIds.inst2, city: null, procedureType: 'dap_blanche', cycle: 'licence1' },
      // Ce qui ne doit JAMAIS donner de ville.
      { key: 'x-inactive', inst: cityIds.inst1, city: 'Fantôme', isActive: false },
      { key: 'x-pending', inst: cityIds.instPending, city: 'Pendante' },
      { key: 'x-partner', inst: cityIds.instPartner, city: 'Partenaire', partnerId: true },
      { key: 'x-noproc', inst: cityIds.inst1, city: 'Sansprocedure', procedureType: null },
    ];
    const cityProgramId = (row: CityRow) =>
      row.partnerId
        ? `partner-prog-${sfx}-c-${row.key}`
        : `${EEF_PROGRAM_ID_PREFIX}${sfx}-c-${row.key}`;

    /// Les villes et leurs compteurs sous la forme `[valeur, nombre]`, dans
    /// l'ordre rendu : ce qu'un test compare à une liste écrite à la main.
    async function citiesOf(filters: Record<string, string | string[]> = {}) {
      const result = await search.cities({ institutionId: scope, ...filters });
      return {
        pairs: result.cities.map((entry) => [entry.value, entry.count] as const),
        result,
      };
    }
    const fillerPairs = (count = 1) =>
      FILLERS.map((city) => [city, count] as [string, number]);

    beforeAll(async () => {
      await prisma.institution.createMany({
        data: [
          institution(cityIds.inst1, {
            nameFr: `Université Villes Un ${ctok}`,
            isActive: true,
          }),
          institution(cityIds.inst2, {
            nameFr: `Université Villes Deux ${ctok}b`,
            isActive: true,
          }),
          institution(cityIds.instPending, {
            nameFr: `Université Villes Attente ${ctok}p`,
            isActive: false,
          }),
          institution(cityIds.instPartner, {
            nameFr: `École partenaire ${ctok}q`,
            isActive: true,
          }),
        ],
      });
      await prisma.program.createMany({
        data: cityRows.map((row) => {
          const nameFr = row.name ?? `Formation ${row.key}`;
          return program(cityProgramId(row), row.inst, nameFr, row.city ?? '', {
            campusCity: row.city,
            procedureType: row.procedureType === undefined ? 'eef' : row.procedureType,
            cycle: row.cycle ?? 'master',
            selectivity: row.selectivity ?? 'selective',
            fieldId: row.fieldId ?? 'd07',
            isActive: row.isActive ?? true,
            searchText: programSearchText(nameFr, row.city),
          });
        }),
      });
    });

    afterAll(async () => {
      await prisma.program.deleteMany({ where: { id: { in: cityRows.map(cityProgramId) } } });
      await prisma.institution.deleteMany({ where: { id: { in: scope } } });
    }, 60_000);

    it('rend TOUTES les villes — accents et apostrophe compris — dans l’ordre promis', async () => {
      const { pairs } = await citiesOf();
      expect(pairs).toEqual([
        ['Paris', 3],
        // Trois villes à 2, sans tenir compte des accents : Épinal avant Evry.
        ['Épinal', 2],
        ['Evry', 2],
        ["Saint-Martin-d'Hères", 2],
        // À 1 : deux graphies d'une même ville, départagées de façon stable
        // (« Besancon » avant « Besançon »), puis les 25 autres, puis Zola.
        ['Besancon', 1],
        ['Besançon', 1],
        ...fillerPairs(),
        ['Zola-sur-Mer', 1],
      ]);
      expect(pairs).toHaveLength(32);
    });

    it('en rend plus que la facette de la recherche, qui s’arrête à 20 et le dit', async () => {
      const searched = await search.search({ institutionId: scope, limit: '1' });
      expect(searched.facets.campusCity).toHaveLength(20);
      expect(searched.facetsTruncated).toContain('campusCity');

      const { result } = await citiesOf();
      expect(result.cities).toHaveLength(32);
      // La facette et la liste décrivent le même catalogue : chaque ville que
      // la facette montre y a le même compteur. (L'ordre des ex æquo de la
      // facette est celui de la base, donc on ne compare pas les rangs.)
      for (const facet of searched.facets.campusCity) {
        expect(result.cities).toContainEqual(facet);
      }
    });

    it('`total` compte les formations correspondant aux filtres HORS ville — sans ville comprises', async () => {
      const { result, pairs } = await citiesOf();
      const withCity = pairs.reduce((sum, [, count]) => sum + count, 0);
      expect(withCity).toBe(37);
      // 37 avec ville + 2 sans : les lignes inactives, en attente, partenaires et
      // sans procédure n'y sont pas.
      expect(result.total).toBe(39);
      expect(result.catalogPublished).toBe(true);
      expect(result.source).toBe('database');

      const searched = await search.search({ institutionId: scope, limit: '1' });
      expect(searched.total).toBe(39);
    });

    it('ne rend jamais la ville d’une ligne inactive, en attente, partenaire ou sans procédure', async () => {
      const { pairs } = await citiesOf();
      const names = pairs.map(([value]) => value);
      for (const absent of ['Fantôme', 'Pendante', 'Partenaire', 'Sansprocedure']) {
        expect(names).not.toContain(absent);
      }
      // Et la ligne inactive de Paris n'est pas comptée : 3, pas 4.
      expect(pairs.find(([value]) => value === 'Paris')).toEqual(['Paris', 3]);
    });

    it('une ligne sans ville n’apparaît dans aucune ville', async () => {
      const { pairs } = await citiesOf();
      for (const [value] of pairs) expect(value.trim()).not.toBe('');
      expect(pairs.some(([value]) => value === 'null')).toBe(false);
    });

    describe('compteurs croisés avec les autres filtres', () => {
      it('cycle=master : les villes sans master disparaissent, les autres sont recomptées', async () => {
        const { pairs, result } = await citiesOf({ cycle: 'master' });
        expect(pairs).toEqual([
          ['Evry', 2],
          ['Paris', 2],
          ['Besancon', 1],
          ['Besançon', 1],
          ...fillerPairs(),
        ]);
        // Dont n-a, sans ville.
        expect(result.total).toBe(32);
      });

      it('procedureType=dap_blanche', async () => {
        const { pairs, result } = await citiesOf({ procedureType: 'dap_blanche' });
        expect(pairs).toEqual([
          ['Épinal', 1],
          ['Paris', 1],
          ['Zola-sur-Mer', 1],
        ]);
        expect(result.total).toBe(4);
      });

      it('selectivity=non_selective', async () => {
        const { pairs, result } = await citiesOf({ selectivity: 'non_selective' });
        expect(pairs).toEqual([
          ['Épinal', 1],
          ['Paris', 1],
          ["Saint-Martin-d'Hères", 1],
        ]);
        expect(result.total).toBe(3);
      });

      it('fieldId + cycle, en plusieurs valeurs et sous les deux formes', async () => {
        const csv = await citiesOf({ cycle: 'licence1,licence2', fieldId: 'd07' });
        const repeated = await citiesOf({ cycle: ['licence1', 'licence2'], fieldId: ['d07'] });
        expect(csv.pairs).toEqual([
          ['Épinal', 2],
          ['Paris', 1],
          ['Zola-sur-Mer', 1],
        ]);
        expect(repeated.pairs).toEqual(csv.pairs);
        expect(repeated.result.total).toBe(csv.result.total);
        expect(csv.result.total).toBe(5);
      });

      it('fieldId=d01 : une seule formation, donc une seule ville', async () => {
        const { pairs, result } = await citiesOf({ fieldId: 'd01' });
        expect(pairs).toEqual([['Paris', 1]]);
        expect(result.total).toBe(1);
      });

      it('institutionId : un seul établissement', async () => {
        const { pairs, result } = await citiesOf({ institutionId: cityIds.inst2 });
        expect(pairs).toEqual([
          ['Épinal', 2],
          ...fillerPairs(),
          ['Paris', 1],
          ["Saint-Martin-d'Hères", 1],
          ['Zola-sur-Mer', 1],
        ]);
        // 30 avec ville + n-b sans ville.
        expect(result.total).toBe(31);
      });

      it('q : les mots sont ceux de la recherche (texte, sans accents)', async () => {
        const droit = await citiesOf({ q: 'droit' });
        expect(droit.pairs).toEqual([
          ['Evry', 1],
          ['Paris', 1],
          ["Saint-Martin-d'Hères", 1],
        ]);
        expect(droit.result.total).toBe(3);

        // « epinal » sans accent trouve Épinal — le même texte normalisé que la
        // recherche.
        const epinal = await citiesOf({ q: 'epinal' });
        expect(epinal.pairs).toEqual([['Épinal', 2]]);
        expect(epinal.result.total).toBe(2);
      });

      it('q : un mot de niveau désigne des cycles, un nom d’établissement ses formations', async () => {
        const licence = await citiesOf({ q: 'licence' });
        expect(licence.pairs).toEqual([
          ['Épinal', 2],
          ["Saint-Martin-d'Hères", 2],
          ['Paris', 1],
          ['Zola-sur-Mer', 1],
        ]);
        // Le jeton de l'établissement n°2 (le mot « Deux ») : ses formations.
        const byInstitution = await citiesOf({ q: `deux ${ctok}b` });
        expect(byInstitution.result.total).toBe(31);
      });

      it('des filtres sans résultat rendent une liste vide — et le catalogue reste « publié »', async () => {
        const { pairs, result } = await citiesOf({ q: `introuvable${sfx}` });
        expect(pairs).toEqual([]);
        expect(result.total).toBe(0);
        // Zéro ville ne veut pas dire catalogue vide : l'écran dit « aucune ville
        // pour ces filtres », pas « le catalogue arrive ».
        expect(result.catalogPublished).toBe(true);
      });

      it('un établissement non publié, demandé seul, ne donne rien', async () => {
        const { pairs, result } = await citiesOf({ institutionId: cityIds.instPending });
        expect(pairs).toEqual([]);
        expect(result.total).toBe(0);
      });

      it('campusCity est ignoré : le même résultat avec ou sans', async () => {
        const without = await citiesOf({ cycle: 'master' });
        const withCity = await search.cities({
          institutionId: scope,
          cycle: 'master',
          campusCity: 'Paris',
        } as never);
        expect(withCity.cities).toEqual(without.result.cities);
        expect(withCity.total).toBe(without.result.total);
      });
    });

    describe('le compteur d’une ville EST le total de la recherche qui la choisit', () => {
      // La promesse du point d'accès : « combien en aurais-je si je choisissais
      // cette ville, avec les autres filtres actuels ? ». Prouvée pour CHAQUE ville
      // rendue, en posant la vraie recherche avec `campusCity` — pas en relisant la
      // même clause : les deux chemins pourraient se tromper ensemble.
      const filterSets: [string, Record<string, string | string[]>][] = [
        ['aucun filtre', {}],
        ['cycle=master', { cycle: 'master' }],
        ['cycle=licence1,licence2', { cycle: 'licence1,licence2' }],
        ['procedureType=dap_blanche', { procedureType: 'dap_blanche' }],
        ['selectivity=non_selective', { selectivity: 'non_selective' }],
        ['fieldId=d01', { fieldId: 'd01' }],
        ['q=droit', { q: 'droit' }],
        ['q=licence + cycle répété', { q: 'licence', cycle: ['licence1', 'licence3'] }],
      ];

      it.each(filterSets)('%s', async (_label, filters) => {
        const { result } = await citiesOf(filters);
        const base = { institutionId: scope, ...filters };

        const searched = await search.search({ ...base, limit: '1' });
        expect(result.total).toBe(searched.total);

        for (const entry of result.cities) {
          const chosen = await search.search({
            ...base,
            campusCity: entry.value,
            limit: '1',
          });
          expect({ city: entry.value, count: chosen.total }).toEqual({
            city: entry.value,
            count: entry.count,
          });
        }
      });

      it('la valeur rendue est la chaîne EXACTE à renvoyer : apostrophe et accent compris', async () => {
        const { result } = await citiesOf();
        const apostrophe = result.cities.find((entry) => entry.value.includes("'"));
        expect(apostrophe).toEqual({ value: "Saint-Martin-d'Hères", count: 2 });
        const chosen = await search.search({
          institutionId: scope,
          campusCity: apostrophe!.value,
        });
        expect(chosen.total).toBe(2);
        // Et sous la forme répétée que produisent les clients HTTP.
        const repeated = await search.search({
          institutionId: scope,
          campusCity: ['Épinal', apostrophe!.value],
        });
        expect(repeated.total).toBe(4);
      });
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
