import { execFileSync } from 'node:child_process';
import { randomUUID } from 'node:crypto';
import { mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

import { type Prisma, PrismaClient } from '@prisma/client';

import {
  EEF_INSTITUTION_ID_PREFIX,
  EEF_PROGRAM_ID_PREFIX,
} from '../../../common/eef-provenance';
import type { PrismaService } from '../../prisma/prisma.service';
import { FRANCE_COUNTRY_CODES, resolveFranceCountryId } from '../catalog/eef-country';
import { EefSearchService } from '../search/eef-search.service';
import {
  delegatedVerifier,
  pickVerifier,
  runDelegatedPublication,
} from './eef-delegated-publication';
import { EefPublicationService } from './eef-publication.service';

/**
 * La publication déléguée, contre un vrai Postgres — puis le script de bout en bout.
 *
 * Ce que le test unitaire ne prouve pas :
 *
 *   • la liste d'attente ne touche QUE les formations nommées : leur ligne reste
 *     inactive, jamais vérifiée, invisible de la recherche publique ;
 *   • le tampon posé en base porte le compte administrateur ET la mention
 *     « publication déléguée » — pas un nom nu ;
 *   • un second passage n'écrit plus rien (le tampon du premier n'est pas remplacé) ;
 *   • le SCRIPT, lui, refuse d'écrire sans le total annoncé, écrit avec, laisse une
 *     trace d'audit, et n'a pas besoin de session (il lit le compte en base).
 *
 * Les identifiants sont uniques par exécution et bornés par `--institution` : une base
 * qui porte déjà l'import ne change ni le test, ni le résultat.
 */
const describePostgres =
  process.env.KPB_RUN_POSTGRES_INTEGRATION === 'true' ? describe : describe.skip;

describePostgres('Publication EEF déléguée — intégration PostgreSQL', () => {
  jest.setTimeout(180_000);

  const prisma = new PrismaClient();
  const sfx = randomUUID().replace(/-/g, '').slice(0, 12);
  const ids = {
    instA: `${EEF_INSTITUTION_ID_PREFIX}${sfx}-a`,
    instB: `${EEF_INSTITUTION_ID_PREFIX}${sfx}-b`,
    instC: `${EEF_INSTITUTION_ID_PREFIX}${sfx}-c`,
    a1: `${EEF_PROGRAM_ID_PREFIX}${sfx}-a1`,
    a2: `${EEF_PROGRAM_ID_PREFIX}${sfx}-a2`,
    /// Page-source morte : doit rester inactive.
    aDead: `${EEF_PROGRAM_ID_PREFIX}${sfx}-adead`,
    b1: `${EEF_PROGRAM_ID_PREFIX}${sfx}-b1`,
    c1: `${EEF_PROGRAM_ID_PREFIX}${sfx}-c1`,
    admin: `it-deleg-admin-${sfx}`,
    adminEmail: `it-deleg-${sfx}@kpb.test`,
  };
  const institutionIds = [ids.instA, ids.instB, ids.instC];
  const programIds = [ids.a1, ids.a2, ids.aDead, ids.b1, ids.c1];

  const prismaService = {
    isEnabled: true,
    execute: async <T>(operation: (client: PrismaClient) => Promise<T>) => operation(prisma),
    tryExecute: async <T>(operation: (client: PrismaClient) => Promise<T>) => operation(prisma),
  } as unknown as PrismaService;
  const service = new EefPublicationService(prismaService);
  const search = new EefSearchService(prismaService);

  let franceId = '';
  let createdCountryId: string | null = null;
  const workdir = mkdtempSync(join(tmpdir(), 'eef-deleg-'));

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

  async function cleanup() {
    await prisma.adminAuditEvent.deleteMany({ where: { entityId: { in: institutionIds } } });
    await prisma.program.deleteMany({ where: { id: { in: programIds } } });
    await prisma.institution.deleteMany({ where: { id: { in: institutionIds } } });
    await prisma.adminUser.deleteMany({ where: { id: ids.admin } });
  }

  const rows = async () => ({
    programs: await prisma.program.findMany({
      where: { id: { in: programIds } },
      orderBy: { id: 'asc' },
    }),
    institutions: await prisma.institution.findMany({
      where: { id: { in: institutionIds } },
      orderBy: { id: 'asc' },
    }),
  });
  const active = async () =>
    (await prisma.program.findMany({
      where: { id: { in: programIds }, isActive: true },
      select: { id: true },
    }))
      .map((r) => r.id)
      .sort();
  const visibleInSearch = async () =>
    ((await search.search({ q: sfx, limit: '50' })).items as Array<{ id: string }>)
      .map((item) => item.id)
      .sort();

  beforeAll(async () => {
    await cleanup();
    const activeCountries = await prisma.country.findMany({
      where: { isActive: true },
      select: { id: true, code: true },
    });
    const frances = activeCountries.filter((country) =>
      (FRANCE_COUNTRY_CODES as readonly string[]).includes((country.code ?? '').trim().toUpperCase()),
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
      throw new Error(`Base inutilisable pour ce test : ${frances.length} pays FR/FRA actifs.`);
    }
    await prisma.adminUser.create({
      data: {
        id: ids.admin,
        fullName: 'Relectrice Test',
        email: ids.adminEmail,
        role: 'super_admin',
        isActive: true,
        languageScope: [],
      },
    });
    await prisma.institution.createMany({
      data: [
        institution(ids.instA),
        institution(ids.instB),
        // Sans source : refusé par le plan, doit rester invisible.
        institution(ids.instC, { sourceUrl: null }),
      ],
    });
    await prisma.program.createMany({
      data: [
        program(ids.a1, ids.instA),
        program(ids.a2, ids.instA),
        program(ids.aDead, ids.instA),
        program(ids.b1, ids.instB),
        program(ids.c1, ids.instC),
      ],
    });
  });

  afterAll(async () => {
    await cleanup();
    if (createdCountryId) await prisma.country.deleteMany({ where: { id: createdCountryId } });
    rmSync(workdir, { recursive: true, force: true });
    await prisma.$disconnect();
  });

  const verifier = () =>
    delegatedVerifier(
      pickVerifier(
        [
          {
            id: ids.admin,
            fullName: 'Relectrice Test',
            email: ids.adminEmail,
            role: 'super_admin',
            isActive: true,
            languageScope: [],
          },
        ],
        ids.adminEmail,
      ),
      'lanceur-gh',
    );

  it('une simulation ne change AUCUNE ligne', async () => {
    const before = await rows();
    const report = await runDelegatedPublication({
      service,
      institutionIds,
      holdback: new Set([ids.aDead]),
      apply: false,
      verifier: verifier(),
    });
    expect(await rows()).toEqual(before);
    expect(report.totals.programsPublished).toBe(3); // a1, a2, b1
    expect(report.totals.programsHeldBack).toBe(1); // aDead
    expect(report.totals.institutionsRefused).toBe(1); // instC
    expect(await visibleInSearch()).toEqual([]);
  });

  it('l’écriture publie ce qui passe, laisse la page morte et l’établissement refusé inactifs', async () => {
    const report = await runDelegatedPublication({
      service,
      institutionIds,
      holdback: new Set([ids.aDead]),
      apply: true,
      verifier: verifier(),
    });
    expect(report.hasFailures).toBe(false);
    expect(await active()).toEqual([ids.a1, ids.a2, ids.b1].sort());

    const { programs, institutions } = await rows();
    const byId = new Map(programs.map((p) => [p.id, p]));
    expect(byId.get(ids.aDead)?.isActive).toBe(false);
    expect(byId.get(ids.aDead)?.lastVerifiedAt).toBeNull();
    expect(byId.get(ids.c1)?.isActive).toBe(false);

    const instById = new Map(institutions.map((i) => [i.id, i]));
    expect(instById.get(ids.instA)?.isActive).toBe(true);
    expect(instById.get(ids.instB)?.isActive).toBe(true);
    expect(instById.get(ids.instC)?.isActive).toBe(false);

    // Le tampon : le compte ET la mention de délégation.
    for (const id of [ids.a1, ids.a2, ids.b1]) {
      expect(byId.get(id)?.verifiedById).toBe(ids.admin);
      expect(byId.get(id)?.verifiedByName).toBe(
        'Relectrice Test (publication déléguée · lancée par lanceur-gh)',
      );
      expect(byId.get(id)?.lastVerifiedAt).toBeInstanceOf(Date);
    }
    expect(instById.get(ids.instA)?.verifiedById).toBe(ids.admin);

    // Le but : visible de la recherche publique, et seulement ce qui a passé.
    expect(await visibleInSearch()).toEqual([ids.a1, ids.a2, ids.b1].sort());
  });

  it('un second passage n’écrit plus rien et ne remplace pas le premier tampon', async () => {
    const before = await rows();
    const report = await runDelegatedPublication({
      service,
      institutionIds,
      holdback: new Set([ids.aDead]),
      apply: true,
      verifier: delegatedVerifier(pickVerifier([
        { id: ids.admin, fullName: 'Autre Nom', email: ids.adminEmail, role: 'super_admin', isActive: true, languageScope: [] },
      ], null), 'autre-lanceur'),
    });
    expect(report.totals.programsPublished).toBe(0);
    expect(await rows()).toEqual(before);
  });

  describe('le script de bout en bout', () => {
    const run = (args: string[]) => {
      try {
        const stdout = execFileSync(
          'npx',
          ['ts-node', '--transpile-only', 'scripts/publish-eef-catalog.ts', ...args],
          { cwd: process.cwd(), env: { ...process.env }, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] },
        );
        return { code: 0, out: stdout };
      } catch (error) {
        const e = error as { status?: number; stdout?: string; stderr?: string };
        return { code: e.status ?? 1, out: `${e.stdout ?? ''}${e.stderr ?? ''}` };
      }
    };
    const reportFile = (checkedAt: string, deadId: string) => {
      const file = join(workdir, `check-${randomUUID()}.json`);
      writeFileSync(
        file,
        JSON.stringify({
          checkedAt,
          method: 'test',
          totals: { programsChecked: 1, urlsChecked: 1, ok: 0, dead: 1, uncertain: 0 },
          dead: [{ programId: deadId, institutionId: ids.instA, url: 'https://exemple.fr/formation', status: 404, passes: 2, redirectedToHome: false }],
          uncertain: [],
        }),
      );
      return file;
    };
    const scope = ['--institution', ids.instA, '--institution', ids.instB, '--institution', ids.instC];

    beforeAll(async () => {
      // Repartir d'une base « jamais publiée » pour ce bloc.
      await prisma.program.updateMany({
        where: { id: { in: programIds } },
        data: { isActive: false, lastVerifiedAt: null, verifiedById: null, verifiedByName: null },
      });
      await prisma.institution.updateMany({
        where: { id: { in: institutionIds } },
        data: { isActive: false, lastVerifiedAt: null, verifiedById: null, verifiedByName: null },
      });
    });

    it('--dry-run n’écrit rien et annonce le total à saisir', async () => {
      const file = reportFile(new Date().toISOString(), ids.aDead);
      const result = run(['--dry-run', '--source-check', file, '--verifier-email', ids.adminEmail, ...scope]);
      expect(result.code).toBe(0);
      expect(result.out).toContain('TOTAL publiable : 3 formation(s)');
      expect(result.out).toContain('--expect-programs 3');
      expect(await active()).toEqual([]);
    });

    it('--apply sans le bon total ne PUBLIE RIEN', async () => {
      const file = reportFile(new Date().toISOString(), ids.aDead);
      const wrong = run(['--apply', '--expect-programs', '4', '--source-check', file, '--verifier-email', ids.adminEmail, ...scope]);
      expect(wrong.code).not.toBe(0);
      expect(wrong.out).toContain('rien n\'est écrit');
      const missing = run(['--apply', '--source-check', file, '--verifier-email', ids.adminEmail, ...scope]);
      expect(missing.code).not.toBe(0);
      expect(await active()).toEqual([]);
    });

    it('--apply refuse un contrôle de pages trop ancien', async () => {
      const old = new Date(Date.now() - 40 * 86_400_000).toISOString();
      const file = reportFile(old, ids.aDead);
      const result = run(['--apply', '--expect-programs', '3', '--source-check', file, '--verifier-email', ids.adminEmail, ...scope]);
      expect(result.code).not.toBe(0);
      expect(result.out).toContain('plus de 14 jours');
      expect(await active()).toEqual([]);
    });

    it('--apply avec le bon total publie, trace l’audit, et laisse la page morte', async () => {
      const file = reportFile(new Date().toISOString(), ids.aDead);
      const result = run(['--apply', '--expect-programs', '3', '--source-check', file, '--verifier-email', ids.adminEmail, '--actor', 'lanceur-gh', ...scope]);
      expect(result.out).toContain('PUBLIÉ : 3 formation(s)');
      expect(result.code).toBe(0);
      expect(await active()).toEqual([ids.a1, ids.a2, ids.b1].sort());
      const aDead = await prisma.program.findUniqueOrThrow({ where: { id: ids.aDead } });
      expect(aDead.isActive).toBe(false);
      const stamped = await prisma.program.findUniqueOrThrow({ where: { id: ids.a1 } });
      expect(stamped.verifiedByName).toContain('publication déléguée');
      expect(stamped.verifiedByName).toContain('lanceur-gh');
      const audit = await prisma.adminAuditEvent.findMany({
        where: { entityId: { in: institutionIds }, action: 'eef.publication.delegated' },
      });
      expect(audit.map((event) => event.entityId).sort()).toEqual([ids.instA, ids.instB].sort());
      expect(audit.every((event) => event.actorAdminId === ids.admin)).toBe(true);
    });

    it('un e-mail inconnu ou un rôle qui ne signe pas est refusé avant toute lecture du catalogue', async () => {
      const file = reportFile(new Date().toISOString(), ids.aDead);
      const result = run(['--dry-run', '--source-check', file, '--verifier-email', `inconnu-${sfx}@kpb.test`, ...scope]);
      expect(result.code).not.toBe(0);
      expect(result.out).toContain('Aucun compte administrateur actif');
    });
  });
});
