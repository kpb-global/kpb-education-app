import { randomUUID } from 'node:crypto';

import { NotFoundException } from '@nestjs/common';
import { Prisma, PrismaClient } from '@prisma/client';

import { AdminCatalogService } from '../modules/admin-catalog/admin-catalog.service';
import {
  institutionVerificationDueWhere,
  programVerificationDueWhere,
} from '../modules/admin-catalog/verification-due';
import { CatalogService } from '../modules/catalog/catalog.service';
import {
  buildEefSearchWhere,
  parseEefSearchInput,
} from '../modules/etudes-en-france/search/eef-search.query';
import { EefSearchService } from '../modules/etudes-en-france/search/eef-search.service';
import { buildShortlistWhere } from '../modules/etudes-en-france/shortlist/eef-shortlist.rank';
import { EefShortlistService } from '../modules/etudes-en-france/shortlist/eef-shortlist.service';
import { MatchesService } from '../modules/matches/matches.service';
import type { PrismaService } from '../modules/prisma/prisma.service';
import { ReportsService } from '../modules/reports/reports.service';
import {
  FRANCE_COUNTRY_CODES,
  resolveFranceCountryId,
} from '../modules/etudes-en-france/catalog/eef-country';
import {
  EEF_INSTITUTION_ID_PREFIX,
  EEF_PROGRAM_ID_PREFIX,
} from './eef-provenance';

/**
 * La frontière de l'import « Études en France », prouvée contre un vrai Postgres.
 *
 * `eef-provenance.spec.ts` prouve QUELLE question chaque porte pose : ses doubles
 * enregistrent la forme du `where`. Ils ne disent pas si Prisma l'accepte, ni
 * surtout si la base répond ce qu'on croit — `NOT`, `AND`, `IN` sur une liste qui
 * peut être vide. C'est le cas que ce dépôt a déjà connu pour les bourses (voir
 * `scholarships-public-reads.postgres.spec.ts`) : la règle vit dans un `where`,
 * donc seule une base réelle dit si elle filtre.
 *
 * ## Les lignes, et ce que chacune prouve
 *
 *   partenaire, publiée         le témoin : rien ne doit l'écarter. Sans lui, un
 *                               filtre trop large passerait pour un succès.
 *   partenaire, désactivée      le témoin de la file : l'exclusion des lignes en
 *                               attente ne vise que l'import, jamais une fiche
 *                               que l'équipe a elle-même désactivée.
 *   EEF, établissement + formation publiés
 *                               la seule ligne que l'espace « Études en France »
 *                               doit servir — et que le catalogue général ne doit
 *                               JAMAIS servir.
 *   EEF, établissement en attente + formation publiée dessous
 *                               le défaut de la recherche et de la shortlist :
 *                               une formation activée sous une université que
 *                               personne n'a relue.
 *   EEF, formation en attente sous un établissement publié
 *                               le tri inverse.
 *   EEF, établissement en attente
 *                               ce que l'import dépose : ni servi, ni à revérifier.
 *   formation créée À LA MAIN sous un établissement de l'import
 *                               identifiant généré, active par défaut : elle est de
 *                               l'import par son parent, et le catalogue général
 *                               ne doit pas la servir sur une carte sans école.
 *   EEF publiés, vérifiés il y a 100 et 400 jours
 *                               la cadence de 180 jours : la coupure doit tomber
 *                               entre les deux, dans le bon sens. Ce sont les seules
 *                               lignes qui pilotent la DATE — les autres sont
 *                               « jamais vérifiées ».
 *
 * ## Ce que le test suppose, et ne peut pas garantir
 *
 * Les comptes sont des ÉCARTS (avant / après l'insertion), jamais des valeurs
 * absolues : la suite tourne sur une base qui peut porter d'autres lignes. Les
 * identifiants, les jetons de recherche (`q`) et le domaine (`FIELD`) sont
 * uniques par exécution, donc un catalogue EEF déjà importé n'invalide pas les
 * lectures. Restent trois hypothèses, non vérifiables d'ici :
 *
 *   • exactement UN pays actif de code FR ou FRA — c'est la règle du service
 *     (`resolveFranceCountryId`), reprise telle quelle ;
 *   • AUCUN autre écrivain entre la mesure de départ et les écarts : lancée en
 *     parallèle d'une suite qui insère une bourse approuvée jamais vérifiée, la
 *     file gagnerait une ligne de plus. D'où `--runInBand` dans le script npm ;
 *   • une base migrée. Sur base neuve la France est créée puis retirée ; sur base
 *     semée elle est réutilisée.
 *
 * Les restes d'une exécution interrompue (SIGKILL, annulation de la CI) sont
 * purgés au démarrage par des motifs que ne peut satisfaire aucun identifiant
 * d'import réel (`eef-prog-<hex>` n'a pas de suffixe).
 */
const describePostgres =
  process.env.KPB_RUN_POSTGRES_INTEGRATION === 'true'
    ? describe
    : describe.skip;

describePostgres('Provenance EEF — intégration PostgreSQL', () => {
  jest.setTimeout(60_000);

  const prisma = new PrismaClient();
  const sfx = randomUUID().replace(/-/g, '').slice(0, 12);

  /// Un domaine que personne d'autre n'utilise : il isole la shortlist et le
  /// moment aha de tout ce que la base contient déjà.
  const FIELD = `zz${sfx}`;
  const USER_ID = `it-user-${sfx}`;

  const ids = {
    partnerInst: `it-partner-inst-${sfx}`,
    partnerProg: `it-partner-prog-${sfx}`,
    partnerProgOff: `it-partner-prog-off-${sfx}`,
    // Une formation partenaire à laquelle l'exploitation a fini par donner une
    // procédure et un cycle : tout ce que la recherche et la shortlist filtrent.
    partnerQualified: `it-partner-prog-qualified-${sfx}`,
    eefInstLive: `${EEF_INSTITUTION_ID_PREFIX}${sfx}-live`,
    eefProgLive: `${EEF_PROGRAM_ID_PREFIX}${sfx}-live`,
    eefInstPending: `${EEF_INSTITUTION_ID_PREFIX}${sfx}-pending`,
    eefProgOrphan: `${EEF_PROGRAM_ID_PREFIX}${sfx}-orphan`,
    eefProgPending: `${EEF_PROGRAM_ID_PREFIX}${sfx}-pending`,
    // Une formation saisie à la main sous une université de l'import : son
    // identifiant n'a pas le préfixe, son établissement l'a.
    manualUnderEef: `it-manual-under-eef-${sfx}`,
    // Les âges de vérification (cadence des établissements et des formations : 180 j).
    eefInstFresh: `${EEF_INSTITUTION_ID_PREFIX}${sfx}-fresh`,
    eefInstStale: `${EEF_INSTITUTION_ID_PREFIX}${sfx}-stale`,
    eefProgFresh: `${EEF_PROGRAM_ID_PREFIX}${sfx}-fresh`,
    eefProgStale: `${EEF_PROGRAM_ID_PREFIX}${sfx}-stale`,
  };
  const institutionIds = [
    ids.partnerInst,
    ids.eefInstLive,
    ids.eefInstPending,
    ids.eefInstFresh,
    ids.eefInstStale,
  ];
  const programIds = [
    ids.partnerProg,
    ids.partnerProgOff,
    ids.partnerQualified,
    ids.eefProgLive,
    ids.eefProgOrphan,
    ids.eefProgPending,
    ids.manualUnderEef,
    ids.eefProgFresh,
    ids.eefProgStale,
  ];

  const DAY_MS = 24 * 60 * 60 * 1000;
  const daysAgo = (days: number) => new Date(Date.now() - days * DAY_MS);

  const prismaService = {
    isEnabled: true,
    execute: async <T>(operation: (client: PrismaClient) => Promise<T>) =>
      operation(prisma),
    tryExecute: async <T>(operation: (client: PrismaClient) => Promise<T>) =>
      operation(prisma),
  } as unknown as PrismaService;

  const catalog = new CatalogService(prismaService);
  const search = new EefSearchService(prismaService);
  const shortlist = new EefShortlistService(prismaService);
  const matches = new MatchesService(prismaService);
  const admin = new AdminCatalogService(prismaService);
  const reports = new ReportsService(prismaService);

  let franceId = '';
  /// Renseigné seulement si CE test a créé la France : c'est alors à lui de la
  /// retirer. Une base déjà semée garde la sienne.
  let createdCountryId: string | null = null;

  /** Le minimum que le schéma exige, pour que le test porte sur le filtre. */
  function institution(
    id: string,
    overrides: Partial<Prisma.InstitutionUncheckedCreateInput>,
  ): Prisma.InstitutionUncheckedCreateInput {
    return {
      id,
      nameFr: `Établissement ${id}`,
      nameEn: `Institution ${id}`,
      countryId: franceId,
      locationFr: 'Rennes',
      locationEn: 'Rennes',
      overviewFr: 'Test.',
      overviewEn: 'Test.',
      studyLevels: ['master'],
      tuitionLabelFr: 'Test',
      tuitionLabelEn: 'Test',
      languageRequirementsFr: 'Test',
      languageRequirementsEn: 'Test',
      intakePeriods: [],
      programIds: [],
      lastVerifiedAt: null,
      ...overrides,
    };
  }

  function program(
    id: string,
    institutionId: string,
    label: string,
    overrides: Partial<Prisma.ProgramUncheckedCreateInput>,
  ): Prisma.ProgramUncheckedCreateInput {
    return {
      id,
      institutionId,
      countryId: franceId,
      fieldId: FIELD,
      // Le jeton unique est dans l'intitulé : `q` le retrouve, et lui seul.
      nameFr: `${label} ${sfx}`,
      nameEn: `${label} ${sfx}`,
      levelFr: 'Master',
      levelEn: "Master's",
      durationFr: '2 ans',
      durationEn: '2 years',
      tuitionFr: 'Test',
      tuitionEn: 'Test',
      languageFr: 'Français',
      languageEn: 'French',
      requirementsFr: [],
      requirementsEn: [],
      lastVerifiedAt: null,
      ...overrides,
    };
  }

  /** Les identifiants des formations servies par la recherche. */
  const searchIds = async (limit = '50') =>
    ((await search.search({ q: sfx, limit })).items as Array<{ id: string }>)
      .map((item) => item.id)
      .sort();

  /** Les identifiants de la shortlist, tous étages confondus, et son total. */
  async function shortlistOf() {
    const result = await shortlist.getShortlist(USER_ID, '10');
    return {
      ids: result.tiers
        .flatMap((tier) => tier.items)
        .map((item) => (item.program as { id: string }).id),
      total: result.tiers.reduce((sum, tier) => sum + tier.total, 0),
    };
  }

  /**
   * Publie l'établissement en attente le temps de `run`, puis le remet en
   * attente — même si `run` échoue : les tests suivants comptent sur l'état
   * initial.
   */
  async function whileParentIsPublished<T>(run: () => Promise<T>): Promise<T> {
    await prisma.institution.update({
      where: { id: ids.eefInstPending },
      data: { isActive: true },
    });
    try {
      return await run();
    } finally {
      await prisma.institution.update({
        where: { id: ids.eefInstPending },
        data: { isActive: false },
      });
    }
  }

  const before = {
    catalogInstitutions: 0,
    catalogPrograms: 0,
    shortlistTotal: 0,
    queue: 0,
    sla: 0,
    dashboard: 0,
  };

  /// Les lignes d'une exécution interrompue. Chaque motif est impossible pour un
  /// identifiant d'import réel (`eef-prog-<hex>`, `eef-univ-<hex>` : aucun
  /// suffixe) comme pour une fiche partenaire réelle.
  const LEFTOVER_SUFFIXES = ['-live', '-orphan', '-pending', '-fresh', '-stale'];
  async function purgeLeftovers() {
    const eefLeftovers = (prefix: string) =>
      LEFTOVER_SUFFIXES.map((suffix) => ({
        AND: [{ id: { startsWith: prefix } }, { id: { endsWith: suffix } }],
      }));
    await prisma.match.deleteMany({
      where: { userProfileId: { startsWith: 'it-user-' } },
    });
    await prisma.eefInterest.deleteMany({
      where: { userId: { startsWith: 'it-user-' } },
    });
    await prisma.userProfile.deleteMany({
      where: { id: { startsWith: 'it-user-' } },
    });
    await prisma.program.deleteMany({
      where: {
        OR: [
          { id: { startsWith: 'it-partner-prog-' } },
          { id: { startsWith: 'it-manual-under-eef-' } },
          ...eefLeftovers(EEF_PROGRAM_ID_PREFIX),
        ],
      },
    });
    await prisma.institution.deleteMany({
      where: {
        OR: [
          { id: { startsWith: 'it-partner-inst-' } },
          ...eefLeftovers(EEF_INSTITUTION_ID_PREFIX),
        ],
      },
    });
    await prisma.country.deleteMany({ where: { id: { startsWith: 'it-fra-' } } });
  }

  beforeAll(async () => {
    await purgeLeftovers();

    // ── La France : réutilisée si la base est semée, créée sinon ────────────
    // Même règle que le service (`eef-country.ts`) : les pays ACTIFS dont le
    // code, normalisé, est FR ou FRA.
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
      // Un pays INACTIF de même code bloquerait la création (`code` est unique).
      const inactive = await prisma.country.findFirst({
        where: { code: { in: [...FRANCE_COUNTRY_CODES] } },
        select: { id: true, code: true },
      });
      if (inactive) {
        throw new Error(
          `Base inutilisable pour ce test : le pays ${inactive.id} (${inactive.code}) `
            + 'existe mais est inactif, donc la France ne se résout pas et ne '
            + 'peut pas être recréée.',
        );
      }
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
          // Vérifiée à l'instant : ce pays ne doit pas gonfler la file.
          lastVerifiedAt: new Date(),
        },
      });
      franceId = createdCountryId;
    } else {
      throw new Error(
        `Base inutilisable pour ce test : ${frances.length} pays actifs de code `
          + `FR/FRA (${frances.map((c) => `${c.id}:${c.code}`).join(', ')}). La `
          + "résolution de la France en exige exactement un.",
      );
    }

    // ── L'étudiant qui interroge la shortlist et le moment aha ──────────────
    await prisma.userProfile.create({
      data: {
        id: USER_ID,
        accountType: 'student',
        preferredLanguage: 'fr',
        fullName: 'Étudiant de test',
        email: `${USER_ID}@example.test`,
        phone: '+22900000000',
        countryOfResidence: 'BJ',
        fieldIds: [FIELD],
        targetCountryIds: [franceId],
      },
    });
    await prisma.eefInterest.create({
      data: {
        userId: USER_ID,
        currentLevel: 'licence',
        targetLevel: 'master',
        fieldIds: [FIELD],
        consentVersion: 'integration-test',
        consentedAt: new Date(),
      },
    });

    // ── L'état de départ, AVANT toute ligne de catalogue ────────────────────
    // Sur une base neuve, aucun établissement n'est publié : la shortlist
    // interroge donc `institutionId IN ()` — la liste vide — et Prisma doit
    // répondre « rien », pas lever. (Que « rien » soit bien la réponse est prouvé
    // plus bas, lignes en place ; ici on ne prouve que l'absence d'erreur.)
    before.catalogInstitutions = (await catalog.getInstitutions()).total;
    before.catalogPrograms = (await catalog.getPrograms()).total;
    before.shortlistTotal = (await shortlistOf()).total;
    before.queue = (await admin.listVerificationDue()).total;
    before.sla = (await admin.verificationSlaSummary()).totalOverdue;
    before.dashboard = (await reports.getDashboardActivation()).urgent
      .verificationDue;

    // ── Les lignes ──────────────────────────────────────────────────────────
    await prisma.institution.createMany({
      data: [
        institution(ids.partnerInst, { isPartner: true, isActive: true }),
        institution(ids.eefInstLive, {
          institutionType: 'universite_publique',
          isActive: true,
        }),
        institution(ids.eefInstPending, {
          institutionType: 'universite_publique',
          isActive: false,
        }),
        // Publiés, vérifiés il y a 100 jours (dans la cadence) et 400 (hors).
        institution(ids.eefInstFresh, {
          institutionType: 'universite_publique',
          isActive: true,
          lastVerifiedAt: daysAgo(100),
        }),
        institution(ids.eefInstStale, {
          institutionType: 'universite_publique',
          isActive: true,
          lastVerifiedAt: daysAgo(400),
        }),
      ],
    });
    await prisma.program.createMany({
      data: [
        program(ids.partnerProg, ids.partnerInst, 'Formation partenaire', {
          isActive: true,
        }),
        program(ids.partnerProgOff, ids.partnerInst, 'Partenaire désactivée', {
          isActive: false,
        }),
        program(ids.partnerQualified, ids.partnerInst, 'Partenaire qualifiée', {
          isActive: true,
          procedureType: 'eef',
          cycle: 'master',
          campusCity: 'Rennes',
          admissionModes: ['Dossier'],
        }),
        program(ids.eefProgLive, ids.eefInstLive, 'Master publié', {
          isActive: true,
          procedureType: 'eef',
          cycle: 'master',
          campusCity: 'Rennes',
          admissionModes: ['Dossier'],
        }),
        program(ids.eefProgOrphan, ids.eefInstPending, 'Master orphelin', {
          isActive: true,
          procedureType: 'eef',
          cycle: 'master',
          campusCity: 'Rennes',
          admissionModes: ['Dossier'],
        }),
        program(ids.eefProgPending, ids.eefInstLive, 'Master en attente', {
          isActive: false,
          procedureType: 'eef',
          cycle: 'master',
          campusCity: 'Rennes',
          admissionModes: ['Dossier'],
        }),
        // Sans procédure ni cycle : ni la recherche ni la shortlist ne la
        // servent ; seule la frontière du catalogue général et la file la voient.
        program(ids.manualUnderEef, ids.eefInstLive, 'Saisie à la main', {
          isActive: true,
        }),
        program(ids.eefProgFresh, ids.eefInstLive, 'Vérifiée récente', {
          isActive: true,
          lastVerifiedAt: daysAgo(100),
        }),
        program(ids.eefProgStale, ids.eefInstLive, 'Vérifiée ancienne', {
          isActive: true,
          lastVerifiedAt: daysAgo(400),
        }),
      ],
    });
  }, 60_000);

  afterAll(async () => {
    // `finally` : un `deleteMany` qui lève ne doit ni sauter le reste du
    // nettoyage ni laisser la connexion ouverte (Jest ne se terminerait pas).
    try {
      await prisma.match.deleteMany({ where: { userProfileId: USER_ID } });
      await prisma.eefInterest.deleteMany({ where: { userId: USER_ID } });
      await prisma.userProfile.deleteMany({ where: { id: USER_ID } });
      await prisma.program.deleteMany({ where: { id: { in: programIds } } });
      await prisma.institution.deleteMany({
        where: { id: { in: institutionIds } },
      });
      if (createdCountryId !== null) {
        await prisma.country.deleteMany({ where: { id: createdCountryId } });
      }
    } finally {
      await prisma.$disconnect();
    }
  }, 60_000);

  // ── /catalog/* : la surface de TOUTES les builds installées ───────────────
  describe('le catalogue général (/catalog/institutions, /catalog/programs)', () => {
    it("ne sert aucun établissement de l'import, publié ou non", async () => {
      const response = await catalog.getInstitutions();
      const served = (response.items as Array<{ id: string }>).map((i) => i.id);

      // `source` d'abord : ce service avale une erreur de base et, hors
      // production, se replie sur les jeux de démonstration. Sans cette ligne,
      // une requête que Prisma refuserait passerait pour une réponse.
      expect(response.source).toBe('database');
      expect(served).toContain(ids.partnerInst);
      expect(served).not.toContain(ids.eefInstLive);
      expect(served).not.toContain(ids.eefInstPending);
      expect(response.total - before.catalogInstitutions).toBe(1);
    });

    it("ne sert aucune formation de l'import, publiée ou non", async () => {
      const response = await catalog.getPrograms({ q: sfx, limit: 1000 });
      const served = (response.items as Array<{ id: string }>).map((p) => p.id);

      expect(response.source).toBe('database');
      // Les témoins, et eux seuls : les deux formations actives du partenaire,
      // y compris celle qu'une procédure a qualifiée — elle RESTE dans le
      // catalogue général, et n'est que là (voir la recherche plus bas).
      expect(served.sort()).toEqual([ids.partnerProg, ids.partnerQualified].sort());
      expect(response.total).toBe(2);
    });

    it("n'ajoute rien au total non filtré que chaque build charge d'un appel", async () => {
      // C'est la liste de `limit=1000` triée par nom : c'est elle que des lignes
      // EEF actives auraient fini par évincer.
      const response = await catalog.getPrograms();
      expect(response.total - before.catalogPrograms).toBe(2);
    });
  });

  // ── /etudes-en-france/search ──────────────────────────────────────────────
  describe("la recherche de l'espace (/etudes-en-france/search)", () => {
    it("ne sert que la formation publiée d'un établissement publié", async () => {
      const result = await search.search({ q: sfx, limit: '50' });

      expect(result.source).toBe('database');
      expect(await searchIds()).toEqual([ids.eefProgLive]);
      expect(result.total).toBe(1);
    });

    it("ne sert pas la formation d'une école partenaire, même qualifiée d'une procédure", async () => {
      // Elle est active, sous un établissement actif de la France, avec
      // procédure, cycle et modalité : tout ce que la recherche filtre. Seule la
      // provenance la tient dehors — et le catalogue général la sert (voir plus
      // haut) : une ligne, un espace.
      expect(await searchIds()).not.toContain(ids.partnerQualified);
      const facets = (await search.search({ q: sfx, limit: '50' })).facets;
      expect(facets.institutionId.map((f: { value: string }) => f.value)).not.toContain(
        ids.partnerInst,
      );
    });

    it('compte les facettes sur ce même ensemble', async () => {
      const { facets } = await search.search({ q: sfx, limit: '50' });

      // L'établissement en attente ne doit apparaître dans AUCUNE facette : une
      // facette qui le compterait ferait choisir un filtre qui ne rend rien.
      expect(facets.institutionId).toEqual([
        { value: ids.eefInstLive, count: 1 },
      ]);
      expect(facets.cycle).toEqual([{ value: 'master', count: 1 }]);
    });

    it("rend la formation dès que son établissement est publié (c'est bien lui la cause)", async () => {
      // Contre-épreuve : sans elle, « la formation orpheline est absente »
      // pourrait tenir à n'importe quelle autre clause.
      const withParent = await whileParentIsPublished(() => searchIds());
      expect(withParent).toEqual([ids.eefProgLive, ids.eefProgOrphan].sort());

      expect(await searchIds()).toEqual([ids.eefProgLive]);
    });
  });

  // ── /etudes-en-france/shortlist ───────────────────────────────────────────
  describe("la shortlist de l'espace (/etudes-en-france/shortlist)", () => {
    it("ne recommande que la formation publiée d'un établissement publié", async () => {
      const result = await shortlistOf();

      expect(result.ids).toContain(ids.eefProgLive);
      expect(result.ids).not.toContain(ids.eefProgOrphan);
      expect(result.ids).not.toContain(ids.eefProgPending);
      // Une formation partenaire n'a aucune procédure : elle n'a pas de cycle.
      expect(result.ids).not.toContain(ids.partnerProg);
      // Et celle d'une école partenaire qualifiée n'entre pas non plus : la
      // provenance, pas le cycle, dit ce qui vient de l'import.
      expect(result.ids).not.toContain(ids.partnerQualified);
      expect(result.total - before.shortlistTotal).toBe(1);
    });

    it('recommande la formation dès que son établissement est publié', async () => {
      const withParent = await whileParentIsPublished(shortlistOf);

      expect(withParent.ids).toContain(ids.eefProgOrphan);
      expect(withParent.total - before.shortlistTotal).toBe(2);
      expect((await shortlistOf()).total - before.shortlistTotal).toBe(1);
    });
  });

  // ── /matches/* ────────────────────────────────────────────────────────────
  describe('le moteur de recommandation (/matches/aha-moment, /matches/school)', () => {
    it("ne recommande aucune formation de l'import", async () => {
      const response = await matches.ahaMoment(USER_ID, 10);
      const programs = response.items.map((match) => match.programId);

      expect(response.source).toBe('database');
      // Le profil vise ce domaine, la France et rien d'autre : le partenaire est
      // donc la seule formation qui puisse sortir. Une formation EEF qui sortirait
      // ici prouverait que la porte est ouverte.
      expect(programs).toContain(ids.partnerProg);
      expect(programs).not.toContain(ids.eefProgLive);
      expect(programs).not.toContain(ids.eefProgOrphan);
      expect(programs).not.toContain(ids.eefProgPending);
      // Créée à la main, active, sous une université de l'import : recommandée,
      // elle porterait un nom d'école vide (l'école est exclue de ce moteur).
      expect(programs).not.toContain(ids.manualUnderEef);
    });

    it("ne connaît pas un établissement de l'import, même publié et pourvu de formations", async () => {
      // Le témoin d'abord : la même porte laisse passer le partenaire.
      const partner = await matches.schoolMatch(USER_ID, ids.partnerInst);
      expect(partner.programId).toBe(ids.partnerProg);

      // Le MESSAGE est ce qui nomme la couche qui a refusé. Une `NotFound` seule
      // ne le dit pas : sans la garde de l'établissement, la garde des formations
      // refuserait quand même — « No programs found » — et le test resterait
      // vert alors que la lecture de l'établissement serait grande ouverte.
      const refused = (institutionId: string) =>
        matches.schoolMatch(USER_ID, institutionId).catch((error: unknown) => {
          expect(error).toBeInstanceOf(NotFoundException);
          return (error as NotFoundException).message;
        });
      expect(await refused(ids.eefInstLive)).toBe('Institution not found.');
      expect(await refused(ids.eefInstPending)).toBe('Institution not found.');
    });
  });

  // ── La file de revérification, le SLA et le compteur ──────────────────────
  describe('la file de revérification, le SLA quotidien et le compteur du tableau de bord', () => {
    // Dix lignes entrent dans la file :
    //   • huit JAMAIS vérifiées — les quatre du partenaire (l'établissement, la
    //     formation, la formation désactivée à la main, la formation qualifiée)
    //     et quatre publiées de l'import (établissement, formation, formation
    //     sous un parent en attente, formation saisie à la main) ;
    //   • deux vérifiées il y a 400 jours, au-delà de la cadence de 180.
    // N'y entrent pas : les deux lignes EN ATTENTE de l'import (l'établissement
    // et la formation — onze sans la règle), et les deux vérifiées il y a 100
    // jours, DANS la cadence. Ces dernières sont les seules à piloter la coupure :
    // une coupure dans le mauvais sens, ou à 30 jours au lieu de 180, les ferait
    // compter.
    const EXPECTED_DUE = 10;

    it('ne comptent que ce qui a été publié, et pas ce que le pipeline a déposé', async () => {
      const queue = await admin.listVerificationDue();
      const sla = await admin.verificationSlaSummary();
      const dashboard = await reports.getDashboardActivation();

      expect(queue.total - before.queue).toBe(EXPECTED_DUE);
      expect(sla.totalOverdue - before.sla).toBe(EXPECTED_DUE);
      expect(dashboard.urgent.verificationDue - before.dashboard).toBe(
        EXPECTED_DUE,
      );
    });

    it('ne se contredisent pas : une seule règle, trois consommateurs', async () => {
      const queue = await admin.listVerificationDue();
      const sla = await admin.verificationSlaSummary();
      const dashboard = await reports.getDashboardActivation();

      expect(sla.totalOverdue).toBe(queue.total);
      expect(dashboard.urgent.verificationDue).toBe(queue.total);
    });

    it('excluent exactement les lignes de l\'import encore en attente', async () => {
      // L'identité des lignes, indépendante du plafond de la file : la clause
      // PARTAGÉE, appliquée à nos seules lignes.
      const now = new Date();
      const dueInstitutions = await prisma.institution.findMany({
        where: {
          AND: [
            { id: { in: institutionIds } },
            institutionVerificationDueWhere(180, now),
          ],
        },
        select: { id: true },
      });
      const duePrograms = await prisma.program.findMany({
        where: {
          AND: [
            { id: { in: programIds } },
            programVerificationDueWhere(180, now),
          ],
        },
        select: { id: true },
      });

      expect(dueInstitutions.map((row) => row.id).sort()).toEqual(
        [ids.partnerInst, ids.eefInstLive, ids.eefInstStale].sort(),
      );
      expect(duePrograms.map((row) => row.id).sort()).toEqual(
        [
          ids.partnerProg,
          ids.partnerProgOff,
          ids.partnerQualified,
          ids.eefProgLive,
          ids.eefProgOrphan,
          ids.manualUnderEef,
          ids.eefProgStale,
        ].sort(),
      );
    });
  });

  // ── La liste vide : « rien », jamais « tout » ─────────────────────────────
  describe("quand aucun établissement n'est publié", () => {
    // Prouvé DIRECTEMENT, et non déduit de l'état d'une base : sur une base neuve
    // la liste est vide, mais aucune ligne n'existe alors, donc « rien » et « pas
    // de filtre » donnent tous deux zéro ; sur une base semée elle ne l'est jamais
    // (les établissements partenaires sont actifs). Ici les lignes existent, la
    // liste est vide, et la base doit répondre zéro.
    it('la recherche ne sert aucune ligne, alors que les lignes existent', async () => {
      const params = parseEefSearchInput({ q: sfx });

      const withNone = await prisma.program.count({
        where: buildEefSearchWhere(params, franceId, []) as never,
      });
      // Le témoin : la même requête, l'établissement publié dans la liste.
      const withLive = await prisma.program.count({
        where: buildEefSearchWhere(params, franceId, [ids.eefInstLive]) as never,
      });

      expect(withNone).toBe(0);
      expect(withLive).toBe(1);

      // L'établissement partenaire est, lui aussi, dans la liste des publiés
      // (« actif, en France ») : la formation partenaire qualifiée passe donc la
      // clause de l'établissement, la procédure et le pays. Seule la provenance
      // la retient — sans elle ce compte serait de deux.
      const withPartner = await prisma.program.count({
        where: buildEefSearchWhere(params, franceId, [
          ids.eefInstLive,
          ids.partnerInst,
        ]) as never,
      });
      expect(withPartner).toBe(1);
    });

    it('la shortlist ne sert aucune ligne, alors que les lignes existent', async () => {
      const where = (publishedInstitutionIds: string[]) =>
        buildShortlistWhere({
          path: 'master',
          countryId: franceId,
          declaredFieldIds: [FIELD],
          tier: 'securite',
          stratum: 'any',
          publishedInstitutionIds,
        }) as never;

      expect(await prisma.program.count({ where: where([]) })).toBe(0);
      const live = await prisma.program.count({
        where: where([ids.eefInstLive]),
      });
      expect(live).toBeGreaterThanOrEqual(1);
      // Même contre-épreuve que pour la recherche : avec l'établissement
      // partenaire dans la liste, la formation qualifiée reste dehors.
      expect(
        await prisma.program.count({
          where: where([ids.eefInstLive, ids.partnerInst]),
        }),
      ).toBe(live);
    });
  });
});
