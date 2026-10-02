import { randomUUID } from 'node:crypto';

import { type Prisma, PrismaClient } from '@prisma/client';

import { programRequirements1_2 } from './eef-catalog.copy-1.2';
import {
  applyEefReconcile,
  EEF_RECONCILE_AUDIT_ACTION,
  planEefReconcile,
} from './eef-catalog.reconcile.db';
import { reconcileTotals } from './eef-catalog.reconcile';
import type {
  EefCatalog,
  EefInstitutionRecord,
  EefProgramRecord,
} from './eef-catalog.types';

/**
 * `eef:reconcile` contre un vrai Postgres.
 *
 * Ce qui compte : ce qu'il écrit (les quatre champs des règles, sur les lignes
 * restées telles que l'import les a écrites), et surtout ce qu'il REFUSE d'écrire —
 * une ligne retouchée dans l'admin, une ligne qui n'est pas de l'import, le tampon
 * de vérification, la publication. Et l'atomicité par établissement : une ligne qui
 * change entre la simulation et l'écriture annule tout son établissement, trace
 * d'audit comprise, sans empêcher les autres.
 *
 * Le catalogue est SYNTHÉTIQUE (deux établissements à identifiants uniques) : le test
 * ne lit ni n'écrit les lignes qu'une base de développement contiendrait déjà.
 */
const describePostgres =
  process.env.KPB_RUN_POSTGRES_INTEGRATION === 'true' ? describe : describe.skip;

describePostgres('eef:reconcile — intégration PostgreSQL', () => {
  jest.setTimeout(60_000);

  const prisma = new PrismaClient();
  const sfx = randomUUID().replace(/-/g, '').slice(0, 12);
  const COUNTRY = `it-reconcile-country-${sfx}`;
  const INST_A = `eef-univ-${sfx}-a`;
  const INST_B = `eef-univ-${sfx}-b`;
  const prog = (suffix: string) => `eef-prog-${sfx}-${suffix}`;
  const ids = {
    // A : une L1 non sélective en DAP, à réaligner — et ÉCRITE AVANT `aCorrected`
    // (ordre des identifiants) : c'est elle qui prouve l'annulation du lot entier
    // quand `aCorrected` est en conflit.
    aBefore: prog('a-before'),
    // A : une 1re année de Sciences Po restée telle que l'import 1.2.0 l'a écrite.
    aCorrected: prog('a-corrected'),
    // A : retouchée dans l'admin (une ligne du texte réécrite à la main).
    aEdited: prog('a-edited'),
    // A : déjà alignée (aucune phrase n'a changé pour elle).
    aCurrent: prog('a-current'),
    // A : identifiant de l'import absent des fichiers.
    aAbsent: prog('a-absent'),
    // B : une L1 non sélective en DAP, publiée et vérifiée.
    bDap: prog('b-dap'),
    // B : une formation hors procédure, en attente (inactive).
    bEngineering: prog('b-engineering'),
  };
  // Pas l'import : même établissement, autre préfixe. Jamais lue, jamais écrite.
  const GENERAL = `it-reconcile-general-${sfx}`;

  const institutionRecord = (id: string, uai: string): EefInstitutionRecord => ({
    id,
    uai,
    nameFr: `Établissement ${id}`,
    nameEn: `Institution ${id}`,
    acronym: null,
    city: 'Rennes',
    department: 'Ille-et-Vilaine',
    region: 'Bretagne',
    websiteUrl: 'https://exemple.fr',
    typology: null,
    enrolment: null,
    sourceUrl: 'https://exemple.fr/source',
  });

  const record = (
    id: string,
    institutionId: string,
    over: Partial<EefProgramRecord> = {},
  ): EefProgramRecord => ({
    id,
    institutionId,
    nameFr: 'L1 - Droit',
    level: 'Bachelor',
    cycle: 'licence1',
    fieldId: 'd07',
    fieldIsFallback: false,
    durationYears: 3,
    campusCity: 'Rennes',
    procedureType: 'dap_blanche',
    selectivity: 'non_selective',
    formationCode: id,
    tracks: [],
    recommendedBachelors: [],
    admissionModes: [],
    dataset: 'parcoursup',
    sourceUrl: `https://exemple.fr/${id}`,
    ...over,
  });

  const records: Record<string, EefProgramRecord> = {
    aBefore: record(ids.aBefore, INST_A, { nameFr: 'L1 - Géographie' }),
    aCorrected: record(ids.aCorrected, INST_A, {
      nameFr: 'L1 - Histoire',
      procedureType: 'hors_eef',
      selectivity: 'selective',
    }),
    aEdited: record(ids.aEdited, INST_A, { nameFr: 'L1 - Lettres' }),
    aCurrent: record(ids.aCurrent, INST_A, {
      nameFr: 'Science politique',
      cycle: 'master',
      level: 'Master',
      durationYears: 2,
      procedureType: 'eef',
      selectivity: 'selective',
      dataset: 'trouver-mon-master',
    }),
    bDap: record(ids.bDap, INST_B, { nameFr: 'L1 - Économie' }),
    bEngineering: record(ids.bEngineering, INST_B, {
      nameFr: "Formation d'ingénieur Bac + 5",
      cycle: 'ingenieur',
      level: 'Master',
      durationYears: 5,
      procedureType: 'hors_eef',
      selectivity: 'selective',
    }),
  };

  const catalog: EefCatalog = {
    manifest: {
      catalogVersion: '1.3.0',
      generatedAt: '2026-09-20T00:00:00.000Z',
      countryId: COUNTRY,
      institutionCount: 2,
      programCount: 6,
      sources: [],
    },
    universities: [
      {
        institution: institutionRecord(INST_A, '0753431X'),
        programs: [records.aBefore, records.aCorrected, records.aEdited, records.aCurrent],
      },
      {
        institution: institutionRecord(INST_B, '0350000B'),
        programs: [records.bDap, records.bEngineering],
      },
    ],
  };

  /// La ligne telle que l'import 1.2.0 l'a écrite, avec la procédure d'ALORS.
  const asImported1_2 = (
    rec: EefProgramRecord,
    procedureType = rec.procedureType,
  ): Pick<Prisma.ProgramUncheckedCreateInput, 'procedureType' | 'selectivity' | 'requirementsFr' | 'requirementsEn'> => {
    const lines = programRequirements1_2({ ...rec, procedureType })!;
    return {
      procedureType,
      selectivity: rec.selectivity,
      requirementsFr: lines.map((line) => line.fr),
      requirementsEn: lines.map((line) => line.en),
    };
  };

  const VERIFIED_AT = new Date('2026-10-01T20:00:00.000Z');
  const row = (
    id: string,
    institutionId: string,
    over: Partial<Prisma.ProgramUncheckedCreateInput>,
  ): Prisma.ProgramUncheckedCreateInput => ({
    id,
    institutionId,
    countryId: COUNTRY,
    fieldId: 'd07',
    nameFr: `Formation ${id}`,
    nameEn: `Programme ${id}`,
    levelFr: 'Bac+3',
    levelEn: 'Bac+3',
    durationFr: '3 ans',
    durationEn: '3 years',
    tuitionFr: 'Test',
    tuitionEn: 'Test',
    languageFr: 'Français',
    languageEn: 'French',
    requirementsFr: [],
    requirementsEn: [],
    isActive: true,
    lastVerifiedAt: VERIFIED_AT,
    verifiedById: 'admin-1',
    verifiedByName: 'Administrateur KPB (publication déléguée)',
    ...over,
  });

  const editedFr = [
    ...asImported1_2(records.aEdited).requirementsFr as string[],
  ];
  editedFr[editedFr.length - 1] = 'Précision ajoutée à la main par un conseiller.';

  const allProgramIds = [...Object.values(ids), GENERAL];

  const snapshot = async () =>
    prisma.program.findMany({
      where: { id: { in: allProgramIds } },
      orderBy: { id: 'asc' },
      select: {
        id: true,
        isActive: true,
        lastVerifiedAt: true,
        verifiedById: true,
        verifiedByName: true,
        procedureType: true,
        selectivity: true,
        requirementsFr: true,
        requirementsEn: true,
        nameFr: true,
      },
    });

  const audits = () =>
    prisma.adminAuditEvent.findMany({
      where: { action: EEF_RECONCILE_AUDIT_ACTION, entityId: { in: [INST_A, INST_B] } },
    });

  async function seed(): Promise<void> {
    await prisma.program.deleteMany({ where: { id: { in: allProgramIds } } });
    await prisma.adminAuditEvent.deleteMany({ where: { entityId: { in: [INST_A, INST_B] } } });
    await prisma.program.createMany({
      data: [
        row(ids.aBefore, INST_A, asImported1_2(records.aBefore)),
        row(ids.aCorrected, INST_A, asImported1_2(records.aCorrected, 'dap_blanche')),
        row(ids.aEdited, INST_A, { ...asImported1_2(records.aEdited), requirementsFr: editedFr }),
        row(ids.aCurrent, INST_A, asImported1_2(records.aCurrent)),
        row(ids.aAbsent, INST_A, asImported1_2(records.aEdited)),
        row(ids.bDap, INST_B, asImported1_2(records.bDap)),
        row(ids.bEngineering, INST_B, {
          ...asImported1_2(records.bEngineering),
          isActive: false,
          lastVerifiedAt: null,
          verifiedById: null,
          verifiedByName: null,
        }),
        // Le catalogue général : texte périmé, même établissement. Hors périmètre.
        row(GENERAL, INST_A, asImported1_2(records.bDap)),
      ],
    });
  }

  beforeAll(async () => {
    await prisma.institution.createMany({
      data: [INST_A, INST_B].map((id) => ({
        id,
        nameFr: `Établissement ${id}`,
        nameEn: `Institution ${id}`,
        countryId: COUNTRY,
        locationFr: 'Rennes',
        locationEn: 'Rennes',
        overviewFr: 'Test.',
        overviewEn: 'Test.',
        studyLevels: ['Bachelor'],
        tuitionLabelFr: 'Test',
        tuitionLabelEn: 'Test',
        languageRequirementsFr: 'Test',
        languageRequirementsEn: 'Test',
        intakePeriods: [],
        programIds: [],
        isActive: true,
        lastVerifiedAt: VERIFIED_AT,
      })),
    });
  });

  beforeEach(seed);

  afterAll(async () => {
    try {
      await prisma.adminAuditEvent.deleteMany({ where: { entityId: { in: [INST_A, INST_B] } } });
      await prisma.program.deleteMany({ where: { id: { in: allProgramIds } } });
      await prisma.institution.deleteMany({ where: { id: { in: [INST_A, INST_B] } } });
    } finally {
      await prisma.$disconnect();
    }
  });

  const only = { onlyInstitutionIds: [INST_A, INST_B] };

  it('la simulation classe chaque ligne et n’écrit RIEN', async () => {
    const before = await snapshot();
    const planned = await planEefReconcile(prisma, catalog, only);
    const totals = reconcileTotals(planned.plans);
    expect(totals).toMatchObject({
      programsExamined: 7,
      programsToUpdate: 4,
      programsToUpdatePublished: 3,
      programsCurrent: 1,
      programsKeptEdited: 1,
      programsAbsentFromCatalog: 1,
      procedureTransitions: { 'dap_blanche→hors_eef': 1 },
      byEdition: { '1.2.0': 4 },
    });
    // Restreint à ses établissements : le décompte hors catalogue n'a pas de sens.
    expect(planned.programsOutsideCatalogInstitutions).toBeNull();
    expect(await snapshot()).toEqual(before);
    expect(await audits()).toHaveLength(0);
  });

  it('refuse d’écrire sur un total qui n’est pas celui de la simulation', async () => {
    const before = await snapshot();
    const planned = await planEefReconcile(prisma, catalog, only);
    await expect(
      applyEefReconcile(prisma, planned, { expectedPrograms: 3, requestId: randomUUID() }),
    ).rejects.toThrow(/la simulation annonce 4/);
    expect(await snapshot()).toEqual(before);
  });

  it('réaligne les lignes machine, et seulement leurs quatre champs', async () => {
    const before = new Map((await snapshot()).map((r) => [r.id, r]));
    const planned = await planEefReconcile(prisma, catalog, only);
    const requestId = randomUUID();
    const applied = await applyEefReconcile(prisma, planned, {
      expectedPrograms: 4,
      requestId,
      actor: 'operateur-github',
    });
    expect(applied.hasFailures).toBe(false);
    expect(applied.programsUpdated).toBe(4);

    const after = new Map((await snapshot()).map((r) => [r.id, r]));
    const corrected = after.get(ids.aCorrected)!;
    expect(corrected.procedureType).toBe('hors_eef');
    expect(corrected.requirementsFr.join(' ')).toContain("Admission propre à l'établissement");
    expect(after.get(ids.bDap)!.requirementsFr.join(' ')).toContain(
      'Classée non sélective sur Parcoursup',
    );
    expect(after.get(ids.bEngineering)!.requirementsFr.join(' ')).not.toContain(
      'ne se demande pas par la procédure',
    );

    // Ni la publication, ni le tampon, ni l'intitulé.
    for (const id of [ids.aBefore, ids.aCorrected, ids.bDap, ids.bEngineering]) {
      const was = before.get(id)!;
      const now = after.get(id)!;
      expect({
        isActive: now.isActive,
        lastVerifiedAt: now.lastVerifiedAt,
        verifiedById: now.verifiedById,
        verifiedByName: now.verifiedByName,
        nameFr: now.nameFr,
      }).toEqual({
        isActive: was.isActive,
        lastVerifiedAt: was.lastVerifiedAt,
        verifiedById: was.verifiedById,
        verifiedByName: was.verifiedByName,
        nameFr: was.nameFr,
      });
    }
    // Retouchée, absente des fichiers, déjà alignée, catalogue général : intactes.
    for (const id of [ids.aEdited, ids.aAbsent, ids.aCurrent, GENERAL]) {
      expect(after.get(id)).toEqual(before.get(id));
    }

    // Une trace par établissement réaligné, avec l'opérateur, jamais dans la ligne.
    const events = await audits();
    expect(events.map((e) => e.entityId).sort()).toEqual([INST_A, INST_B].sort());
    for (const event of events) {
      expect(event.requestId).toBe(requestId);
      expect(event.actorAdminId).toBeNull();
      expect(event.result).toBe('applied');
    }
    const a = events.find((e) => e.entityId === INST_A)!.changes as Record<string, unknown>;
    expect(a).toMatchObject({
      catalogVersion: '1.3.0',
      programsUpdated: 2,
      programsPublished: 2,
      procedureTransitions: { 'dap_blanche→hors_eef': 1 },
      programIds: [ids.aBefore, ids.aCorrected],
      launchedBy: 'operateur-github',
    });

    // Une seconde passe ne trouve plus rien à écrire.
    const second = reconcileTotals((await planEefReconcile(prisma, catalog, only)).plans);
    expect(second.programsToUpdate).toBe(0);
    expect(second.programsKeptEdited).toBe(1);
  });

  it('une ligne retouchée APRÈS la simulation annule son établissement, pas les autres', async () => {
    const planned = await planEefReconcile(prisma, catalog, only);
    // Un administrateur corrige la formation de A pendant que la simulation est relue.
    await prisma.program.update({
      where: { id: ids.aCorrected },
      data: { requirementsFr: { set: ['Corrigé à la main entre-temps.'] } },
    });
    const before = new Map((await snapshot()).map((r) => [r.id, r]));
    const applied = await applyEefReconcile(prisma, planned, {
      expectedPrograms: 4,
      requestId: randomUUID(),
    });
    expect(applied.hasFailures).toBe(true);
    expect(applied.institutions.find((r) => r.institutionId === INST_A)).toMatchObject({
      outcome: 'failed',
      programsUpdated: 0,
    });
    expect(applied.institutions.find((r) => r.institutionId === INST_A)?.error).toContain(
      ids.aCorrected,
    );
    expect(applied.institutions.find((r) => r.institutionId === INST_B)).toMatchObject({
      outcome: 'updated',
      programsUpdated: 2,
    });
    expect(applied.programsUpdated).toBe(2);

    const after = new Map((await snapshot()).map((r) => [r.id, r]));
    // A : rien d'écrit, pas même la correction de l'administrateur écrasée — et la
    // formation réalignée AVANT le conflit, dans la même transaction, est annulée.
    expect(after.get(ids.aCorrected)).toEqual(before.get(ids.aCorrected));
    expect(after.get(ids.aBefore)).toEqual(before.get(ids.aBefore));
    expect(after.get(ids.aBefore)!.requirementsFr.join(' ')).not.toContain(
      'Classée non sélective sur Parcoursup',
    );
    expect(after.get(ids.aCorrected)!.requirementsFr).toEqual(['Corrigé à la main entre-temps.']);
    // Ni trace pour A ; une pour B.
    expect((await audits()).map((e) => e.entityId)).toEqual([INST_B]);
  });
});
