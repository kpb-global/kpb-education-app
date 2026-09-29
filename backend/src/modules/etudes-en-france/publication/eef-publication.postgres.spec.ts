import { randomUUID } from 'node:crypto';

import {
  BadRequestException,
  ConflictException,
  NotFoundException,
  UnprocessableEntityException,
} from '@nestjs/common';
import { type Prisma, PrismaClient } from '@prisma/client';

import {
  EEF_INSTITUTION_ID_PREFIX,
  EEF_PROGRAM_ID_PREFIX,
} from '../../../common/eef-provenance';
import type { AdminSessionUser } from '../../auth/auth.service';
import type { PrismaService } from '../../prisma/prisma.service';
import {
  FRANCE_COUNTRY_CODES,
  resolveFranceCountryId,
} from '../catalog/eef-country';
import { EefSearchService } from '../search/eef-search.service';
import { EefPublicationService } from './eef-publication.service';

/**
 * La publication d'un établissement de l'import, contre un vrai Postgres.
 *
 * Ce qu'il prouve, et que le plan pur ne peut pas prouver :
 *
 *   • une SIMULATION n'écrit rien ;
 *   • l'écriture pose le tampon de l'administrateur de la SESSION, active
 *     l'établissement et ne touche à AUCUNE ligne voisine (autre établissement,
 *     formation refusée, fiche partenaire de même état) ;
 *   • un état qui bouge entre la simulation et l'écriture annule TOUT : le plan
 *     est recalculé dans la transaction, et le compte attendu doit correspondre ;
 *   • le tampon d'un relecteur précédent n'est pas écrasé ;
 *   • le retrait est l'inverse exact, garde les tampons et ne supprime pas les
 *     formations enregistrées par les étudiants ;
 *   • et le but : une formation publiée devient VISIBLE dans la recherche
 *     publique, un retrait la fait disparaître.
 *
 * Les identifiants sont uniques par exécution et les lectures sont bornées à ces
 * identifiants : une base qui porte déjà l'import ne fausse rien.
 */
const describePostgres =
  process.env.KPB_RUN_POSTGRES_INTEGRATION === 'true'
    ? describe
    : describe.skip;

describePostgres('Publication EEF — intégration PostgreSQL', () => {
  jest.setTimeout(120_000);

  const prisma = new PrismaClient();
  const sfx = randomUUID().replace(/-/g, '').slice(0, 12);
  const USER = `it-pub-user-${sfx}`;

  const ids = {
    inst: `${EEF_INSTITUTION_ID_PREFIX}${sfx}-main`,
    instOther: `${EEF_INSTITUTION_ID_PREFIX}${sfx}-other`,
    instNoSource: `${EEF_INSTITUTION_ID_PREFIX}${sfx}-nosrc`,
    partnerInst: `it-pub-partner-inst-${sfx}`,
    p1: `${EEF_PROGRAM_ID_PREFIX}${sfx}-p1`,
    p2: `${EEF_PROGRAM_ID_PREFIX}${sfx}-p2`,
    p3: `${EEF_PROGRAM_ID_PREFIX}${sfx}-p3`,
    /// Sans procédure : refusée, doit rester inactive.
    pNoProcedure: `${EEF_PROGRAM_ID_PREFIX}${sfx}-noproc`,
    otherP1: `${EEF_PROGRAM_ID_PREFIX}${sfx}-o1`,
    noSourceP1: `${EEF_PROGRAM_ID_PREFIX}${sfx}-n1`,
    partnerP1: `it-pub-partner-prog-${sfx}`,
  };
  const institutionIds = [ids.inst, ids.instOther, ids.instNoSource, ids.partnerInst];
  const programIds = [
    ids.p1,
    ids.p2,
    ids.p3,
    ids.pNoProcedure,
    ids.otherP1,
    ids.noSourceP1,
    ids.partnerP1,
  ];

  const admin: AdminSessionUser = {
    id: 'admin-relectrice',
    fullName: 'Aïcha Relectrice',
    email: 'aicha@kpb.test',
    role: 'admin',
    languageScope: [],
  };

  /// Le client Prisma, avec un point d'accroche dans les transactions
  /// interactives : c'est ainsi qu'on fait bouger la base ENTRE le plan et
  /// l'écriture, sans bricoler le service.
  const hooks: {
    beforeTransaction?: () => Promise<void>;
    beforeFirstProgramUpdateMany?: () => Promise<void>;
  } = {};
  const hooked = new Proxy(prisma, {
    get(target, property, receiver) {
      if (property === '$transaction') {
        return async (
          callback: ((tx: Prisma.TransactionClient) => Promise<unknown>) | unknown[],
          options?: unknown,
        ) => {
          // La forme « tableau » (`$transaction([q1, q2])`, celle de la recherche)
          // n'a pas de corps à surveiller : elle passe telle quelle.
          if (typeof callback !== 'function') {
            return target.$transaction(callback as never, options as never);
          }
          const before = hooks.beforeTransaction;
          hooks.beforeTransaction = undefined;
          if (before) await before();
          return target.$transaction(async (tx) => {
            let armed = hooks.beforeFirstProgramUpdateMany;
            hooks.beforeFirstProgramUpdateMany = undefined;
            const programProxy = new Proxy(tx.program, {
              get(programTarget, method, programReceiver) {
                if (method === 'updateMany') {
                  return async (args: unknown) => {
                    if (armed) {
                      const run = armed;
                      armed = undefined;
                      await run();
                    }
                    return programTarget.updateMany(args as never);
                  };
                }
                return Reflect.get(programTarget, method, programReceiver);
              },
            });
            const txProxy = new Proxy(tx, {
              get(txTarget, key, txReceiver) {
                if (key === 'program') return programProxy;
                return Reflect.get(txTarget, key, txReceiver);
              },
            });
            return callback(txProxy as Prisma.TransactionClient);
          }, options as never);
        };
      }
      return Reflect.get(target, property, receiver) as unknown;
    },
  });
  const prismaService = {
    isEnabled: true,
    execute: async <T>(operation: (client: PrismaClient) => Promise<T>) =>
      operation(hooked as PrismaClient),
    tryExecute: async <T>(operation: (client: PrismaClient) => Promise<T>) =>
      operation(hooked as PrismaClient),
  } as unknown as PrismaService;
  const service = new EefPublicationService(prismaService);
  const search = new EefSearchService(prismaService);

  let franceId = '';
  let createdCountryId: string | null = null;

  const institution = (
    id: string,
    over: Partial<Prisma.InstitutionUncheckedCreateInput> = {},
  ): Prisma.InstitutionUncheckedCreateInput => ({
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
    institutionType: 'universite_publique',
    isActive: false,
    sourceUrl: 'https://exemple.fr/',
    lastVerifiedAt: null,
    ...over,
  });
  const program = (
    id: string,
    institutionId: string,
    over: Partial<Prisma.ProgramUncheckedCreateInput> = {},
  ): Prisma.ProgramUncheckedCreateInput => ({
    id,
    institutionId,
    countryId: franceId,
    fieldId: 'd01',
    // Le jeton unique est dans l'intitulé : `q` le retrouve, et lui seul.
    nameFr: `Formation ${id} ${sfx}`,
    nameEn: `Programme ${id} ${sfx}`,
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
    cycle: 'master',
    procedureType: 'eef',
    sourceUrl: 'https://exemple.fr/formation',
    isActive: false,
    lastVerifiedAt: null,
    ...over,
  });

  const snapshot = async () => ({
    institutions: await prisma.institution.findMany({
      where: { id: { in: institutionIds } },
      orderBy: { id: 'asc' },
    }),
    programs: await prisma.program.findMany({
      where: { id: { in: programIds } },
      orderBy: { id: 'asc' },
    }),
  });

  const activeProgramIds = async () =>
    (
      await prisma.program.findMany({
        where: { id: { in: programIds }, isActive: true },
        select: { id: true },
      })
    )
      .map((row) => row.id)
      .sort();

  const searchIds = async () =>
    ((await search.search({ q: sfx, limit: '50' })).items as Array<{ id: string }>)
      .map((item) => item.id)
      .sort();

  async function cleanup() {
    await prisma.savedItem.deleteMany({ where: { userId: USER } });
    await prisma.program.deleteMany({
      where: {
        OR: [
          { id: { in: programIds } },
          // Les restes d'une exécution interrompue.
          { id: { startsWith: 'it-pub-partner-prog-' } },
          {
            AND: [
              { id: { startsWith: EEF_PROGRAM_ID_PREFIX } },
              { OR: ['-p1', '-p2', '-p3', '-noproc', '-o1', '-n1'].map((s) => ({ id: { endsWith: s } })) },
            ],
          },
        ],
      },
    });
    await prisma.institution.deleteMany({
      where: {
        OR: [
          { id: { in: institutionIds } },
          { id: { startsWith: 'it-pub-partner-inst-' } },
          {
            AND: [
              { id: { startsWith: EEF_INSTITUTION_ID_PREFIX } },
              { OR: ['-main', '-other', '-nosrc'].map((s) => ({ id: { endsWith: s } })) },
            ],
          },
        ],
      },
    });
    await prisma.userProfile.deleteMany({ where: { id: USER } });
  }

  async function seed() {
    await prisma.institution.createMany({
      data: [
        institution(ids.inst),
        institution(ids.instOther),
        institution(ids.instNoSource, { sourceUrl: null }),
        // Pas l'import : même état « inactive, jamais vérifiée ».
        institution(ids.partnerInst, { isPartner: true }),
      ],
    });
    await prisma.program.createMany({
      data: [
        program(ids.p1, ids.inst),
        program(ids.p2, ids.inst),
        program(ids.p3, ids.inst),
        program(ids.pNoProcedure, ids.inst, { procedureType: null }),
        program(ids.otherP1, ids.instOther),
        program(ids.noSourceP1, ids.instNoSource),
        program(ids.partnerP1, ids.partnerInst),
      ],
    });
  }

  beforeAll(async () => {
    await cleanup();
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
      const inactive = await prisma.country.findFirst({
        where: { code: { in: [...FRANCE_COUNTRY_CODES] } },
        select: { id: true },
      });
      if (inactive) {
        throw new Error(`Base inutilisable pour ce test : ${inactive.id} existe mais est inactif.`);
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
          lastVerifiedAt: new Date(),
        },
      });
      franceId = createdCountryId;
    } else {
      throw new Error(`Base inutilisable pour ce test : ${frances.length} pays FR/FRA actifs.`);
    }
    await prisma.userProfile.create({
      data: {
        id: USER,
        accountType: 'student',
        preferredLanguage: 'fr',
        fullName: 'Étudiant publication',
        email: `${USER}@example.test`,
        phone: '+22900000000',
        countryOfResidence: 'BJ',
      },
    });
  });

  beforeEach(async () => {
    await prisma.savedItem.deleteMany({ where: { userId: USER } });
    await prisma.program.deleteMany({ where: { id: { in: programIds } } });
    await prisma.institution.deleteMany({ where: { id: { in: institutionIds } } });
    await seed();
    hooks.beforeTransaction = undefined;
    hooks.beforeFirstProgramUpdateMany = undefined;
  });

  afterAll(async () => {
    try {
      await cleanup();
      if (createdCountryId) {
        await prisma.country.deleteMany({ where: { id: createdCountryId } });
      }
    } finally {
      await prisma.$disconnect();
    }
  }, 60_000);

  const publish = (
    id: string,
    over: Partial<Parameters<EefPublicationService['publish']>[1]> = {},
  ) => service.publish(id, { apply: false, verifier: admin, ...over });
  const unpublish = (
    id: string,
    over: Partial<Parameters<EefPublicationService['unpublish']>[1]> = {},
  ) => service.unpublish(id, { apply: false, verifier: admin, ...over });

  describe('simulation', () => {
    it('annonce le plan sans rien écrire', async () => {
      const before = await snapshot();

      const result = await publish(ids.inst);

      expect(result.mode).toBe('dry-run');
      expect(result.plan.programs.toPublish).toEqual([ids.p1, ids.p2, ids.p3].sort());
      expect(result.plan.programs.refused.map((r) => [r.id, r.reasons])).toEqual([
        [ids.pNoProcedure, ['program_procedure_missing']],
      ]);
      expect(result.plan.institution.willActivate).toBe(true);
      expect(await snapshot()).toEqual(before);
    });

    it('est la valeur par défaut : sans `apply`, jamais d’écriture', async () => {
      const before = await snapshot();
      await service.publish(ids.inst, { verifier: admin } as never);
      expect(await snapshot()).toEqual(before);
    });
  });

  describe('écriture', () => {
    it('publie les formations publiables, active l’établissement et signe avec la session', async () => {
      const result = await publish(ids.inst, { apply: true, expectedPrograms: 3 });

      expect(result).toMatchObject({
        mode: 'applied',
        institutionActivated: true,
        programsPublished: 3,
        verifiedBy: { id: 'admin-relectrice', name: 'Aïcha Relectrice' },
      });
      expect(await activeProgramIds()).toEqual([ids.p1, ids.p2, ids.p3].sort());

      const rows = await prisma.program.findMany({
        where: { id: { in: [ids.p1, ids.p2, ids.p3] } },
      });
      for (const row of rows) {
        expect(row.isActive).toBe(true);
        expect(row.verifiedById).toBe('admin-relectrice');
        expect(row.verifiedByName).toBe('Aïcha Relectrice');
        expect(row.lastVerifiedAt).toBeInstanceOf(Date);
      }
      const inst = await prisma.institution.findUniqueOrThrow({ where: { id: ids.inst } });
      expect(inst.isActive).toBe(true);
      expect(inst.verifiedById).toBe('admin-relectrice');
      expect(inst.lastVerifiedAt).toBeInstanceOf(Date);
    });

    it('ne touche à AUCUNE ligne voisine', async () => {
      const others = async () => ({
        instOther: await prisma.institution.findUniqueOrThrow({ where: { id: ids.instOther } }),
        instNoSource: await prisma.institution.findUniqueOrThrow({ where: { id: ids.instNoSource } }),
        partnerInst: await prisma.institution.findUniqueOrThrow({ where: { id: ids.partnerInst } }),
        refused: await prisma.program.findUniqueOrThrow({ where: { id: ids.pNoProcedure } }),
        otherP1: await prisma.program.findUniqueOrThrow({ where: { id: ids.otherP1 } }),
        noSourceP1: await prisma.program.findUniqueOrThrow({ where: { id: ids.noSourceP1 } }),
        partnerP1: await prisma.program.findUniqueOrThrow({ where: { id: ids.partnerP1 } }),
      });
      const before = await others();

      await publish(ids.inst, { apply: true, expectedPrograms: 3 });

      expect(await others()).toEqual(before);
    });

    it('publie seulement les formations demandées, et garde le reste en attente', async () => {
      const result = await publish(ids.inst, {
        apply: true,
        programIds: [ids.p2],
        expectedPrograms: 1,
      });

      expect(result).toMatchObject({ programsPublished: 1, institutionActivated: true });
      expect(await activeProgramIds()).toEqual([ids.p2]);
    });

    it('refuse la formation d’un AUTRE établissement, même demandée, et n’écrit rien', async () => {
      const before = await snapshot();

      await expect(
        publish(ids.inst, { apply: true, programIds: [ids.otherP1], expectedPrograms: 0 }),
      ).rejects.toBeInstanceOf(UnprocessableEntityException);

      expect(await snapshot()).toEqual(before);
    });

    it('refuse un établissement sans source, et n’écrit rien', async () => {
      const before = await snapshot();

      await expect(
        publish(ids.instNoSource, { apply: true, expectedPrograms: 0 }),
      ).rejects.toBeInstanceOf(UnprocessableEntityException);

      expect(await snapshot()).toEqual(before);
    });

    it('refuse une fiche partenaire, même inactive et jamais vérifiée', async () => {
      const before = await snapshot();

      await expect(
        publish(ids.partnerInst, { apply: true, expectedPrograms: 0 }),
      ).rejects.toBeInstanceOf(UnprocessableEntityException);

      expect(await snapshot()).toEqual(before);
    });

    it('ne publie pas deux fois : le second appel n’a plus rien à faire', async () => {
      await publish(ids.inst, { apply: true, expectedPrograms: 3 });

      const again = await publish(ids.inst);
      expect(again.plan.publishable).toBe(false);
      expect(again.plan.programs.toPublish).toEqual([]);
      await expect(
        publish(ids.inst, { apply: true, expectedPrograms: 0 }),
      ).rejects.toBeInstanceOf(UnprocessableEntityException);
    });

    it('ne remplace pas le tampon du relecteur précédent de l’établissement', async () => {
      const earlier = new Date('2026-08-01T10:00:00.000Z');
      await prisma.institution.update({
        where: { id: ids.inst },
        data: {
          isActive: true,
          lastVerifiedAt: earlier,
          verifiedById: 'admin-hier',
          verifiedByName: 'Relecteur d’hier',
        },
      });

      const result = await publish(ids.inst, { apply: true, expectedPrograms: 3 });

      expect(result).toMatchObject({ institutionActivated: false, programsPublished: 3 });
      const inst = await prisma.institution.findUniqueOrThrow({ where: { id: ids.inst } });
      expect(inst.verifiedById).toBe('admin-hier');
      expect(inst.verifiedByName).toBe('Relecteur d’hier');
      expect(inst.lastVerifiedAt).toEqual(earlier);
      // … mais les nouvelles formations portent le relecteur d'aujourd'hui.
      const p1 = await prisma.program.findUniqueOrThrow({ where: { id: ids.p1 } });
      expect(p1.verifiedById).toBe('admin-relectrice');
    });

    it('exige le chiffre annoncé pour écrire', async () => {
      const before = await snapshot();

      await expect(publish(ids.inst, { apply: true })).rejects.toBeInstanceOf(BadRequestException);

      expect(await snapshot()).toEqual(before);
    });

    it('refuse un chiffre qui ne correspond pas, et n’écrit rien', async () => {
      const before = await snapshot();

      await expect(
        publish(ids.inst, { apply: true, expectedPrograms: 2 }),
      ).rejects.toBeInstanceOf(ConflictException);

      expect(await snapshot()).toEqual(before);
    });

    it('répond 404 pour un établissement inconnu', async () => {
      await expect(publish(`${EEF_INSTITUTION_ID_PREFIX}${sfx}-absent`)).rejects.toBeInstanceOf(
        NotFoundException,
      );
    });
  });

  describe('l’état bouge entre la simulation et l’écriture', () => {
    it('annule tout quand une formation cesse d’être publiable avant la transaction', async () => {
      const before = await snapshot();
      hooks.beforeTransaction = async () => {
        await prisma.program.update({ where: { id: ids.p2 }, data: { sourceUrl: null } });
      };

      await expect(
        publish(ids.inst, { apply: true, expectedPrograms: 3 }),
      ).rejects.toBeInstanceOf(ConflictException);

      const after = await snapshot();
      expect(after.institutions).toEqual(before.institutions);
      expect(after.programs.filter((p) => p.id !== ids.p2)).toEqual(
        before.programs.filter((p) => p.id !== ids.p2),
      );
      expect(await activeProgramIds()).toEqual([]);
    });

    it('annule tout quand une formation est publiée par quelqu’un d’autre PENDANT l’écriture', async () => {
      hooks.beforeFirstProgramUpdateMany = async () => {
        await prisma.program.update({ where: { id: ids.p3 }, data: { isActive: true } });
      };

      await expect(
        publish(ids.inst, { apply: true, expectedPrograms: 3 }),
      ).rejects.toBeInstanceOf(ConflictException);

      // Seule la ligne que l'autre écrivain a publiée est active : rien de ce
      // que notre transaction avait écrit avant l'échec n'a survécu.
      expect(await activeProgramIds()).toEqual([ids.p3]);
      const inst = await prisma.institution.findUniqueOrThrow({ where: { id: ids.inst } });
      expect(inst.isActive).toBe(false);
      const p1 = await prisma.program.findUniqueOrThrow({ where: { id: ids.p1 } });
      expect(p1.verifiedById).toBeNull();
    });
  });

  describe('visibilité', () => {
    it('rend les formations visibles dans la recherche publique, et le retrait les cache', async () => {
      expect(await searchIds()).toEqual([]);

      await publish(ids.inst, { apply: true, expectedPrograms: 3 });
      expect(await searchIds()).toEqual([ids.p1, ids.p2, ids.p3].sort());

      await unpublish(ids.inst, { apply: true, expectedPrograms: 3 });
      expect(await searchIds()).toEqual([]);
    });

    it('ne montre pas une formation publiée sous un établissement encore inactif', async () => {
      // Publication partielle imposée à la main : le parent bloque l'affichage.
      await prisma.program.update({ where: { id: ids.p1 }, data: { isActive: true } });

      expect(await searchIds()).toEqual([]);
    });
  });

  describe('retrait', () => {
    beforeEach(async () => {
      await publish(ids.inst, { apply: true, expectedPrograms: 3 });
    });

    it('retire l’établissement et ses formations, sans effacer les tampons', async () => {
      const result = await unpublish(ids.inst, { apply: true, expectedPrograms: 3 });

      expect(result).toMatchObject({
        mode: 'applied',
        institutionDeactivated: true,
        programsDeactivated: 3,
      });
      expect(await activeProgramIds()).toEqual([]);
      const inst = await prisma.institution.findUniqueOrThrow({ where: { id: ids.inst } });
      expect(inst.isActive).toBe(false);
      expect(inst.verifiedById).toBe('admin-relectrice');
      const p1 = await prisma.program.findUniqueOrThrow({ where: { id: ids.p1 } });
      expect(p1.verifiedById).toBe('admin-relectrice');
    });

    it('annonce combien d’étudiants perdent la formation, sans supprimer leur enregistrement', async () => {
      await prisma.savedItem.create({
        data: { userId: USER, itemType: 'program', itemId: ids.p1 },
      });

      const plan = (await unpublish(ids.inst)).plan;
      expect(plan.savedByStudents).toBe(1);

      await unpublish(ids.inst, { apply: true, expectedPrograms: 3 });
      expect(await prisma.savedItem.count({ where: { userId: USER } })).toBe(1);
    });

    it('avec une liste, retire ces formations et garde l’établissement', async () => {
      const result = await unpublish(ids.inst, {
        apply: true,
        programIds: [ids.p1],
        expectedPrograms: 1,
      });

      expect(result).toMatchObject({ institutionDeactivated: false, programsDeactivated: 1 });
      expect(await activeProgramIds()).toEqual([ids.p2, ids.p3].sort());
      const inst = await prisma.institution.findUniqueOrThrow({ where: { id: ids.inst } });
      expect(inst.isActive).toBe(true);
    });

    it('refuse un chiffre qui ne correspond pas, et n’écrit rien', async () => {
      await expect(
        unpublish(ids.inst, { apply: true, expectedPrograms: 1 }),
      ).rejects.toBeInstanceOf(ConflictException);

      expect(await activeProgramIds()).toEqual([ids.p1, ids.p2, ids.p3].sort());
    });

    it('refuse de retirer une fiche partenaire', async () => {
      await prisma.institution.update({ where: { id: ids.partnerInst }, data: { isActive: true } });
      await prisma.program.update({ where: { id: ids.partnerP1 }, data: { isActive: true } });

      await expect(
        unpublish(ids.partnerInst, { apply: true, expectedPrograms: 0 }),
      ).rejects.toBeInstanceOf(UnprocessableEntityException);

      const partner = await prisma.institution.findUniqueOrThrow({ where: { id: ids.partnerInst } });
      expect(partner.isActive).toBe(true);
    });
  });

  describe('vue d’ensemble', () => {
    it('compte ce qui attend et ce qui est publié, par établissement', async () => {
      const before = (await service.overview()).institutions.find((i) => i.id === ids.inst);
      expect(before).toMatchObject({ programsPending: 4, programsPublished: 0, isActive: false });

      await publish(ids.inst, { apply: true, expectedPrograms: 3 });

      const after = (await service.overview()).institutions.find((i) => i.id === ids.inst);
      expect(after).toMatchObject({
        programsPending: 1,
        programsPublished: 3,
        isActive: true,
        verifiedByName: 'Aïcha Relectrice',
      });
    });

    it('ne liste jamais une fiche partenaire', async () => {
      const listed = (await service.overview()).institutions.map((i) => i.id);
      expect(listed).not.toContain(ids.partnerInst);
      expect(listed).toContain(ids.inst);
    });
  });
});
