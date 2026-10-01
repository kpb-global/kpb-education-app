// Publie l'import « Études en France » (établissements puis formations) pour le
// compte d'un administrateur, par le MÊME service que l'écran admin.
// Voir `eef-delegated-publication.ts` pour le pourquoi et ce que l'outil n'allège pas.
//
//   npx ts-node --transpile-only scripts/publish-eef-catalog.ts --dry-run
//   npx ts-node --transpile-only scripts/publish-eef-catalog.ts --apply \
//        --expect-programs 9876 [--verifier-email admin@exemple.org] [--institution eef-univ-…]
//
// Aucun mode par défaut. `--apply` exige `--expect-programs N`, le total que la
// simulation annonce : une confirmation SAISIE (un `--apply` collé ne suffit pas) et
// un contrôle de concurrence (si la base a bougé depuis la simulation, rien n'est écrit).
//
// Les formations dont la page-source a disparu (`source-check.json`) restent inactives.
// N'imprime que des noms d'établissements (données publiques) et des décomptes.
import { randomUUID } from 'node:crypto';
import { existsSync } from 'node:fs';
import { loadEnvFile } from 'node:process';

import {
  EEF_INSTITUTION_ID_PREFIX,
  EEF_PROGRAM_ID_PREFIX,
} from '../src/common/eef-provenance';
import { PrismaService } from '../src/modules/prisma/prisma.service';
import {
  delegatedVerifier,
  pickVerifier,
  runDelegatedPublication,
} from '../src/modules/etudes-en-france/publication/eef-delegated-publication';
import { EefPublicationService } from '../src/modules/etudes-en-france/publication/eef-publication.service';
import {
  deadProgramIds,
  EEF_SOURCE_CHECK_FILE,
  loadSourceCheckReport,
} from '../src/modules/etudes-en-france/publication/eef-source-check';

if (existsSync('.env')) loadEnvFile?.('.env');

const argv = process.argv.slice(2);
const flag = (name: string) => argv.includes(name);
function values(name: string): string[] {
  const out: string[] = [];
  argv.forEach((arg, index) => {
    if (arg === name && argv[index + 1] !== undefined) out.push(argv[index + 1]);
  });
  return out;
}
const single = (name: string) => values(name)[0];

const dryRun = flag('--dry-run');
const apply = flag('--apply');
if (dryRun === apply) {
  console.error("Choisir --dry-run OU --apply. Rien n'a été fait.");
  process.exit(2);
}

const MAX_CHECK_AGE_DAYS = Number(single('--max-check-age-days') ?? '14');

const prismaService = new PrismaService();

async function main(): Promise<void> {
  if (!prismaService.isEnabled) {
    throw new Error('DATABASE_URL absente : rien à publier.');
  }
  const service = new EefPublicationService(prismaService);

  // ── le contrôle des pages doit être récent ──────────────────────────────
  const check = loadSourceCheckReport(single('--source-check') ?? EEF_SOURCE_CHECK_FILE);
  const ageDays = (Date.now() - Date.parse(check.checkedAt)) / 86_400_000;
  console.log(
    `Contrôle des pages-sources du ${check.checkedAt.slice(0, 10)} (${Math.floor(ageDays)} j) : `
      + `${check.totals.ok} valides, ${check.totals.dead} mortes, ${check.totals.uncertain} incertaines.`,
  );
  if (ageDays > MAX_CHECK_AGE_DAYS) {
    const message = `Le contrôle des pages date de plus de ${MAX_CHECK_AGE_DAYS} jours : relancer « npm run eef:check-sources » puis versionner le rapport.`;
    if (apply) throw new Error(message);
    console.warn(`⚠ ${message}`);
  }
  const holdback = deadProgramIds(check);

  // ── le relecteur ────────────────────────────────────────────────────────
  const admins = await prismaService.execute((db) =>
    db.adminUser.findMany({
      where: { isActive: true, role: { in: ['admin', 'super_admin'] } },
      select: {
        id: true,
        fullName: true,
        email: true,
        role: true,
        isActive: true,
        languageScope: true,
      },
    }),
  );
  const admin = pickVerifier(admins ?? [], single('--verifier-email') ?? null);
  const verifier = delegatedVerifier(admin, single('--actor') ?? null);
  console.log(`Relecteur inscrit : ${verifier.fullName} (${admin.role}).`);

  // ── le périmètre ────────────────────────────────────────────────────────
  const only = values('--institution');
  const institutions = await prismaService.execute((db) =>
    db.institution.findMany({
      where: {
        id: only.length > 0 ? { in: only } : { startsWith: EEF_INSTITUTION_ID_PREFIX },
      },
      select: { id: true },
      orderBy: { nameFr: 'asc' },
    }),
  );
  const institutionIds = (institutions ?? []).map((row) => row.id);
  for (const id of only) {
    if (!id.startsWith(EEF_INSTITUTION_ID_PREFIX)) {
      throw new Error(`« ${id} » n'est pas un établissement de l'import (${EEF_INSTITUTION_ID_PREFIX}…).`);
    }
    if (!institutionIds.includes(id)) throw new Error(`Établissement inconnu : ${id}.`);
  }

  // Écarter une procédure entière de la vague (ex. `hors_eef`) : une décision
  // éditoriale, donc EXPLICITE et nommée dans la sortie.
  const excludedProcedures = values('--exclude-procedure');
  if (excludedProcedures.length > 0) {
    const rows = await prismaService.execute((db) =>
      db.program.findMany({
        where: {
          id: { startsWith: EEF_PROGRAM_ID_PREFIX },
          procedureType: { in: excludedProcedures },
        },
        select: { id: true },
      }),
    );
    for (const row of rows ?? []) holdback.add(row.id);
    console.log(`Procédure(s) écartée(s) de cette vague : ${excludedProcedures.join(', ')}.`);
  }
  console.log(`${institutionIds.length} établissement(s) ; ${holdback.size} formation(s) mise(s) en attente.`);

  // ── toujours une simulation complète d'abord ────────────────────────────
  console.log('\n── SIMULATION (rien n\'est écrit) ──');
  const simulation = await runDelegatedPublication({
    service,
    institutionIds,
    holdback,
    apply: false,
    verifier,
    log: (line) => console.log(line),
  });
  const t = simulation.totals;
  console.log(
    `\nTOTAL publiable : ${t.programsPublished} formation(s) dans ${t.institutionsPublished} établissement(s) ; `
      + `${t.programsHeldBack} en attente (page morte) ; ${t.programsRefused} refusée(s) par le plan ; `
      + `${t.institutionsRefused} établissement(s) refusé(s) ; ${t.institutionsFailed} en échec.`,
  );
  if (Object.keys(t.refusedByReason).length > 0) {
    console.log(`Refus par motif : ${JSON.stringify(t.refusedByReason)}`);
  }
  if (simulation.hasFailures) {
    throw new Error('La simulation a échoué pour au moins un établissement : rien n\'est écrit.');
  }
  if (!apply) {
    console.log(`\nPour écrire : relancer avec --apply --expect-programs ${t.programsPublished}.`);
    return;
  }

  // ── l'écriture ──────────────────────────────────────────────────────────
  const expected = Number(single('--expect-programs'));
  if (!Number.isInteger(expected) || expected !== t.programsPublished) {
    throw new Error(
      `--expect-programs vaut « ${single('--expect-programs') ?? '(absent)'} », la simulation annonce `
        + `${t.programsPublished} : rien n'est écrit. Relire la simulation, puis saisir ce nombre.`,
    );
  }
  console.log('\n── APPLICATION ──');
  const applied = await runDelegatedPublication({
    service,
    institutionIds,
    holdback,
    apply: true,
    verifier,
    log: (line) => console.log(line),
  });
  const a = applied.totals;
  console.log(
    `\nPUBLIÉ : ${a.programsPublished} formation(s) ; ${a.institutionsPublished} établissement(s) traité(s) ; `
      + `${a.institutionsFailed} en échec ; ${a.programsHeldBack} en attente (page morte).`,
  );

  // La trace durable : une ligne d'audit par établissement publié. Un échec ici ne
  // défait pas la publication (déjà validée en base) ; il se dit.
  const requestId = randomUUID();
  for (const report of applied.institutions) {
    if (report.outcome !== 'published') continue;
    try {
      await prismaService.execute((db) =>
        db.adminAuditEvent.create({
          data: {
            actorAdminId: admin.id,
            action: 'eef.publication.delegated',
            purposeCode: 'catalog_publication',
            entityType: 'Institution',
            entityId: report.institutionId,
            requestId,
            reasonCode: 'owner_request',
            result: 'applied',
            changes: {
              programsPublished: report.programsPublished,
              programsHeldBack: report.programsHeldBack,
              institutionActivated: report.institutionActivated,
              launchedBy: single('--actor') ?? null,
            },
          },
        }),
      );
    } catch {
      console.warn(`⚠ Trace d'audit non écrite pour ${report.institutionId} (la publication, elle, est en base).`);
    }
  }
  if (applied.hasFailures) process.exitCode = 1;
}

main()
  .catch((error: unknown) => {
    console.error(error instanceof Error ? error.message : error);
    process.exitCode = 1;
  })
  // Sans cette déconnexion le moteur Prisma garde le processus en vie.
  .finally(() => prismaService.onModuleDestroy());
