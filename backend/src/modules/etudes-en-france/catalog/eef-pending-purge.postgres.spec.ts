import { randomUUID } from 'node:crypto';

import {
  AccountType,
  type Prisma,
  PrismaClient,
} from '@prisma/client';

import { purgePendingEefRows } from './eef-pending-purge';

/**
 * La purge des lignes de l'import jamais publiées, contre un vrai Postgres.
 *
 * Ce qui compte n'est pas ce qu'elle supprime, c'est ce qu'elle REFUSE de
 * supprimer : une formation publiée, vérifiée ou enregistrée par un utilisateur,
 * un établissement qui garde une formation qu'on ne supprime pas, et tout ce qui
 * ne porte pas le préfixe de l'import. Le test restreint l'outil à SES
 * établissements (`onlyInstitutionIds`) : il ne supprime jamais les lignes
 * qu'une base de développement contiendrait déjà.
 */
const describePostgres =
  process.env.KPB_RUN_POSTGRES_INTEGRATION === 'true'
    ? describe
    : describe.skip;

describePostgres('Purge des lignes EEF en attente — intégration PostgreSQL', () => {
  jest.setTimeout(60_000);

  const prisma = new PrismaClient();
  const sfx = randomUUID().replace(/-/g, '').slice(0, 12);
  const COUNTRY = `it-purge-country-${sfx}`;
  const USER = `it-purge-user-${sfx}`;

  const inst = (suffix: string) => `eef-univ-${sfx}-${suffix}`;
  const prog = (suffix: string) => `eef-prog-${sfx}-${suffix}`;
  const ids = {
    instPending: inst('pending'),
    instLive: inst('live'),
    instMixed: inst('mixed'),
    instSaved: inst('saved'),
    // Publié SANS avoir été vérifié (activé à la main) : il est publié, donc pas
    // candidat, même si personne ne l'a relu.
    instActiveUnverified: inst('active-unverified'),
    partnerInst: `it-purge-partner-inst-${sfx}`,
    progPend1: prog('pend1'),
    progPend2: prog('pend2'),
    progUnderLive: prog('under-live'),
    progLive: prog('live'),
    // Idem pour une formation : active mais jamais vérifiée. Elle est visible des
    // étudiants ; la supprimer serait retirer une fiche publiée.
    progActiveUnverified: prog('active-unverified'),
    progMixedPending: prog('mixed-pending'),
    progMixedVerified: prog('mixed-verified'),
    // Une seule des deux marques de vérification suffit à protéger : les
    // scripts de reprise n'écrivent pas toujours les deux.
    progVerifiedAtOnly: prog('verified-at-only'),
    progVerifiedByOnly: prog('verified-by-only'),
    progSaved: prog('saved'),
    partnerProg: `it-purge-partner-prog-${sfx}`,
  };
  const eefInstitutions = [
    ids.instPending,
    ids.instLive,
    ids.instMixed,
    ids.instSaved,
    ids.instActiveUnverified,
  ];

  const institution = (
    id: string,
    over: Partial<Prisma.InstitutionUncheckedCreateInput> = {},
  ): Prisma.InstitutionUncheckedCreateInput => ({
    id,
    nameFr: `Établissement ${id}`,
    nameEn: `Institution ${id}`,
    countryId: COUNTRY,
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
    isActive: false,
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
    countryId: COUNTRY,
    fieldId: 'd01',
    nameFr: `Formation ${id}`,
    nameEn: `Programme ${id}`,
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
    isActive: false,
    lastVerifiedAt: null,
    ...over,
  });

  const allProgramIds = Object.values(ids).filter((id) =>
    id.includes('prog'),
  );
  const allInstitutionIds = [...eefInstitutions, ids.partnerInst];
  const remaining = async () => ({
    programs: (
      await prisma.program.findMany({
        where: { id: { in: allProgramIds } },
        select: { id: true },
      })
    )
      .map((p) => p.id)
      .sort(),
    institutions: (
      await prisma.institution.findMany({
        where: { id: { in: allInstitutionIds } },
        select: { id: true },
      })
    )
      .map((i) => i.id)
      .sort(),
  });

  beforeAll(async () => {
    await prisma.userProfile.create({
      data: {
        id: USER,
        accountType: AccountType.student,
        preferredLanguage: 'fr',
        fullName: 'Étudiant purge',
        email: `${USER}@example.test`,
        phone: '+22900000000',
        countryOfResidence: 'BJ',
      },
    });
    await prisma.institution.createMany({
      data: [
        institution(ids.instPending),
        institution(ids.instLive, {
          isActive: true,
          lastVerifiedAt: new Date(),
          verifiedById: 'admin-1',
        }),
        institution(ids.instMixed),
        institution(ids.instSaved),
        institution(ids.instActiveUnverified, { isActive: true }),
        // Pas l'import : même état « inactive, jamais vérifiée », autre préfixe.
        institution(ids.partnerInst),
      ],
    });
    await prisma.program.createMany({
      data: [
        program(ids.progPend1, ids.instPending),
        program(ids.progPend2, ids.instPending),
        // En attente sous un établissement PUBLIÉ : la formation part, pas lui.
        program(ids.progUnderLive, ids.instLive),
        program(ids.progLive, ids.instLive, {
          isActive: true,
          lastVerifiedAt: new Date(),
          verifiedById: 'admin-1',
        }),
        program(ids.progActiveUnverified, ids.instLive, { isActive: true }),
        program(ids.progMixedPending, ids.instMixed),
        // Inactive mais VÉRIFIÉE : quelqu'un l'a relue, elle n'est pas candidate.
        program(ids.progMixedVerified, ids.instMixed, {
          lastVerifiedAt: new Date(),
          verifiedById: 'admin-1',
        }),
        // Enregistrée par un utilisateur : protégée, et son parent avec elle.
        program(ids.progVerifiedAtOnly, ids.instMixed, {
          lastVerifiedAt: new Date(),
        }),
        program(ids.progVerifiedByOnly, ids.instMixed, {
          verifiedById: 'admin-1',
        }),
        program(ids.progSaved, ids.instSaved),
        program(ids.partnerProg, ids.partnerInst),
      ],
    });
    await prisma.savedItem.create({
      data: { userId: USER, itemType: 'program', itemId: ids.progSaved },
    });
    await prisma.match.create({
      data: {
        userProfileId: USER,
        programId: ids.progPend1,
        institutionId: ids.instPending,
        probability: 0.5,
        zone: 'yellow',
        expiresAt: new Date(Date.now() + 86_400_000),
      },
    });
  }, 60_000);

  afterAll(async () => {
    try {
      await prisma.match.deleteMany({ where: { userProfileId: USER } });
      await prisma.savedItem.deleteMany({ where: { userId: USER } });
      await prisma.program.deleteMany({ where: { id: { in: allProgramIds } } });
      await prisma.institution.deleteMany({
        where: { id: { in: allInstitutionIds } },
      });
      await prisma.userProfile.deleteMany({ where: { id: USER } });
    } finally {
      await prisma.$disconnect();
    }
  }, 60_000);

  // Le périmètre du test inclut l'établissement PARTENAIRE : sa formation et lui
  // sont « inactifs, jamais vérifiés » comme des lignes de l'import, et seul le
  // préfixe d'identifiant les met à l'abri.
  const scope = { onlyInstitutionIds: allInstitutionIds };

  it('compte sans rien écrire en simulation, et dit ce qu’elle protège', async () => {
    const summary = await purgePendingEefRows(prisma, { apply: false, ...scope });

    expect(summary).toEqual({
      // pend1, pend2, sous-établissement-publié, mixte-en-attente, enregistrée.
      programsPending: 5,
      programsProtected: { saved: 1 },
      programsDeleted: 0,
      // pending, mixed, saved — `live` est publié, donc pas candidat.
      institutionsPending: 3,
      institutionsProtected: {
        // mixed garde la formation vérifiée ; saved garde la formation enregistrée.
        keepsNonPendingPrograms: 2,
        partnerAgreement: 0,
        saved: 0,
      },
      institutionsDeleted: 0,
      matchesDeleted: 0,
    });
    const rows = await remaining();
    expect(rows.programs).toHaveLength(11);
    expect(rows.institutions).toHaveLength(6);
  });

  it('supprime les seules lignes jamais publiées, vérifiées ni enregistrées', async () => {
    const summary = await purgePendingEefRows(prisma, { apply: true, ...scope });

    expect(summary).toMatchObject({
      programsDeleted: 4,
      institutionsDeleted: 1,
      matchesDeleted: 1,
    });
    const rows = await remaining();
    expect(rows.programs).toEqual(
      [
        ids.progLive,
        ids.progActiveUnverified,
        ids.progMixedVerified,
        ids.progVerifiedAtOnly,
        ids.progVerifiedByOnly,
        ids.progSaved,
        ids.partnerProg,
      ].sort(),
    );
    expect(rows.institutions).toEqual(
      [
        ids.instLive,
        ids.instActiveUnverified,
        ids.instMixed,
        ids.instSaved,
        ids.partnerInst,
      ].sort(),
    );
    // Les correspondances de la formation supprimée sont parties avec elle.
    expect(
      await prisma.match.count({ where: { userProfileId: USER } }),
    ).toBe(0);
    // La formation enregistrée par l'utilisateur est intacte.
    expect(
      await prisma.savedItem.count({ where: { userId: USER } }),
    ).toBe(1);
  });

  it('est rejouable : plus rien à supprimer', async () => {
    const summary = await purgePendingEefRows(prisma, { apply: true, ...scope });

    expect(summary).toMatchObject({
      programsDeleted: 0,
      institutionsDeleted: 0,
      matchesDeleted: 0,
    });
    expect((await remaining()).programs).toHaveLength(7);
  });

  it('ne supprime pas une ligne publiée entre la lecture et l’écriture', async () => {
    // Le plan est lu (la formation est en attente, donc candidate), puis un
    // administrateur la publie, puis la transaction d'écriture démarre. Le WHERE
    // de chaque suppression répète « inactive, jamais vérifiée » : la ligne
    // publiée entre-temps ne doit pas être emportée par un plan périmé.
    const lateId = prog('late');
    await prisma.program.create({ data: program(lateId, ids.instMixed) });
    const racing = new Proxy(prisma, {
      get(target, property, receiver) {
        if (property === '$transaction') {
          return async (...args: unknown[]) => {
            await prisma.program.update({
              where: { id: lateId },
              data: {
                isActive: true,
                lastVerifiedAt: new Date(),
                verifiedById: 'admin-2',
              },
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
    try {
      const summary = await purgePendingEefRows(racing, { apply: true, ...scope });

      // La ligne était candidate à la lecture (avec la formation enregistrée,
      // candidate elle aussi mais protégée)…
      expect(summary.programsPending).toBe(2);
      // … et n'a pas été supprimée.
      expect(summary.programsDeleted).toBe(0);
      expect(await prisma.program.count({ where: { id: lateId } })).toBe(1);
    } finally {
      await prisma.program.deleteMany({ where: { id: lateId } });
    }
  });
});
