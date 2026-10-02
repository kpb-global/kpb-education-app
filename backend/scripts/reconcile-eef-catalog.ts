// Réaligne les formations « Études en France » DÉJÀ en base (publiées ou en attente)
// sur les règles du dépôt : procédure, sélectivité, exigences FR/EN. Voir
// `eef-catalog.reconcile.ts` pour le pourquoi et ce qui n'est jamais écrit.
//
//   npx ts-node --transpile-only scripts/reconcile-eef-catalog.ts --dry-run
//   npx ts-node --transpile-only scripts/reconcile-eef-catalog.ts --apply \
//        --expect-programs 3600 [--institution eef-univ-…] [--actor login]
//
// Aucun mode par défaut. `--apply` exige `--expect-programs N`, le total que la
// simulation annonce : une confirmation SAISIE, et un contrôle — l'écriture applique
// les listes EXACTES de la simulation, et une formation retouchée entre-temps fait
// échouer son établissement sans rien écrire pour lui.
//
// N'imprime que des noms d'établissements (données publiques), des identifiants de
// formation et des décomptes.
import { randomUUID } from 'node:crypto';
import { existsSync } from 'node:fs';
import { loadEnvFile } from 'node:process';

import { PrismaClient } from '@prisma/client';

import { loadEefCatalog } from '../src/modules/etudes-en-france/catalog/eef-catalog.loader';
import {
  institutionToUpdate,
  reconcileTotals,
} from '../src/modules/etudes-en-france/catalog/eef-catalog.reconcile';
import {
  applyEefReconcile,
  planEefReconcile,
} from '../src/modules/etudes-en-france/catalog/eef-catalog.reconcile.db';

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

// Un drapeau sans valeur, ou suivi d'un autre drapeau, est une faute de frappe :
// « --institution » vide ne doit pas vouloir dire « tous les établissements ».
for (const name of ['--institution', '--expect-programs', '--actor']) {
  argv.forEach((arg, index) => {
    const next = argv[index + 1];
    if (arg === name && (next === undefined || next.startsWith('--'))) {
      console.error(`${name} attend une valeur. Rien n'a été fait.`);
      process.exit(2);
    }
  });
}

const dryRun = flag('--dry-run');
const apply = flag('--apply');
if (dryRun === apply) {
  console.error("Choisir --dry-run OU --apply. Rien n'a été fait.");
  process.exit(2);
}

/// Combien de formations signalées on liste une à une (toutes sont comptées).
const KEPT_LISTED = 50;

const prisma = new PrismaClient();

async function main(): Promise<void> {
  const catalog = loadEefCatalog();
  const only = values('--institution');
  const planned = await planEefReconcile(prisma, catalog, {
    onlyInstitutionIds: only.length > 0 ? only : undefined,
  });
  const t = reconcileTotals(planned.plans);

  // ── toujours la simulation complète d'abord ─────────────────────────────
  console.log(`── SIMULATION (rien n'est écrit) — règles du catalogue ${planned.catalogVersion} ──`);
  for (const plan of planned.plans) {
    const updates = institutionToUpdate(plan).length;
    const kept = plan.programs.filter((p) => p.outcome.startsWith('kept_') || p.outcome === 'absent_from_catalog').length;
    if (updates === 0 && kept === 0) continue;
    console.log(
      `${updates > 0 ? '✓' : '·'} ${plan.institutionName} : ${updates} formation(s) à réaligner`
        + (kept > 0 ? `, ${kept} signalée(s), non écrite(s)` : ''),
    );
  }
  console.log(
    `\nExaminées : ${t.programsExamined} formation(s) dans ${t.institutions} établissement(s).`
      + `\n  déjà alignées                         : ${t.programsCurrent}`
      + `\n  À RÉALIGNER                           : ${t.programsToUpdate} (dont ${t.programsToUpdatePublished} publiée(s)), dans ${t.institutionsToUpdate} établissement(s)`
      + `\n  signalées — retouchées ou inconnues   : ${t.programsKeptEdited}`
      + `\n  signalées — changées d'établissement  : ${t.programsKeptMoved}`
      + `\n  signalées — absentes des fichiers     : ${t.programsAbsentFromCatalog}`,
  );
  if (planned.programsOutsideCatalogInstitutions !== null) {
    console.log(`  hors des établissements du catalogue  : ${planned.programsOutsideCatalogInstitutions}`);
  }
  console.log(`Champs qui changent : ${JSON.stringify(t.byField)}`);
  console.log(`Procédures : ${JSON.stringify(t.procedureTransitions)}`);
  console.log(`Prose reconnue : ${JSON.stringify(t.byEdition)}`);

  const kept = planned.plans.flatMap((plan) =>
    plan.programs.filter((p) => p.outcome !== 'update' && p.outcome !== 'current'),
  );
  if (kept.length > 0) {
    console.log(`\nSignalées (laissées telles quelles), ${Math.min(kept.length, KEPT_LISTED)} sur ${kept.length} :`);
    for (const program of kept.slice(0, KEPT_LISTED)) {
      console.log(`  ${program.id} (${program.institutionId}) — ${program.outcome} : ${program.fields.join(', ') || '—'}`);
    }
  }

  if (!apply) {
    console.log(`\nPour écrire : relancer avec --apply --expect-programs ${t.programsToUpdate}.`);
    return;
  }

  // ── l'écriture ──────────────────────────────────────────────────────────
  const expected = Number(single('--expect-programs'));
  if (!Number.isInteger(expected)) {
    throw new Error(
      `--expect-programs vaut « ${single('--expect-programs') ?? '(absent)'} » : rien n'est écrit. `
        + `La simulation annonce ${t.programsToUpdate}.`,
    );
  }
  console.log('\n── APPLICATION ──');
  const applied = await applyEefReconcile(prisma, planned, {
    expectedPrograms: expected,
    requestId: randomUUID(),
    // `github.triggering_actor` : la personne qui a LANCÉ ce passage, dans l'audit
    // seulement — jamais dans une donnée servie.
    actor: single('--actor') ?? null,
    log: (line) => console.log(line),
  });
  console.log(`\nRÉALIGNÉES : ${applied.programsUpdated} formation(s).`);
  if (applied.programsUpdated !== expected) {
    console.error(
      `⚠ ${applied.programsUpdated} formation(s) réalignée(s) alors que ${expected} avaient été confirmées : `
        + 'relire le détail ci-dessus avant toute autre action.',
    );
    process.exitCode = 1;
  }
  if (applied.hasFailures) process.exitCode = 1;
}

main()
  .catch((error: unknown) => {
    console.error(error instanceof Error ? error.message : error);
    process.exitCode = 1;
  })
  // Sans cette déconnexion le moteur Prisma garde le processus en vie.
  .finally(() => prisma.$disconnect());
