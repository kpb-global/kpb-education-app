/**
 * Chemin de publication du catalogue de bourses, exécutable EN PRODUCTION.
 *
 * Ce fichier vit sous `src/` — et non sous `scripts/` — parce que `tsconfig.json`
 * n'inclut que `src/**\/*.ts` et que l'image Docker ne copie que `dist`. Un
 * script laissé dans `scripts/` est absent du conteneur : la commande
 * documentée était donc physiquement inexécutable en production, ce qui a
 * laissé les 34 fiches vérifiées dans le dépôt et 11 fiches de démonstration
 * dans la base pendant un mois.
 *
 * Quatre sous-commandes :
 *   import              crée les fiches manquantes, inactives et en attente
 *   publish             active les fiches éligibles
 *   deactivate-legacy   désactive les 11 fiches de démonstration nommément
 *   switch              publish puis deactivate-legacy, dans UNE transaction
 *
 * `switch` est la commande de la bascule : l'ordre publier-puis-dépublier et la
 * transaction unique garantissent qu'il n'existe aucun instant où l'onglet
 * Bourses est vide pour les utilisateurs.
 */
import { existsSync } from 'node:fs';
import { loadEnvFile } from 'node:process';

import { Prisma, PrismaClient } from '@prisma/client';

import {
  importScholarshipCatalog,
  type ScholarshipCatalogWriter,
} from '../modules/scholarships-index/data/scholarship-catalog.importer';
import { buildScholarshipCreateData } from '../modules/scholarships-index/data/scholarship-catalog.create-data';
import { SCHOLARSHIP_CATALOG_V1 } from '../modules/scholarships-index/data/scholarship-catalog.v1';
import {
  validateScholarshipCatalog,
  type ScholarshipCatalogValidationReport,
} from '../modules/scholarships-index/data/scholarship-catalog.validator';
import { ScholarshipContentQualityService } from '../modules/scholarships-index/scholarship-content-quality.service';
import type { PrismaService } from '../modules/prisma/prisma.service';

/**
 * Les 11 fiches semées par une version antérieure du seed, servies en
 * production comme des bourses réelles. La liste est EXPLICITE et non déduite
 * d'un tag : ces lignes ont été créées avant que le seed ne pose
 * `tags: ['legacy-seed']`, et l'API publique n'expose pas `tags`, donc rien ne
 * permet de vérifier depuis l'extérieur qu'elles le portent.
 *
 * On désactive, on ne supprime pas : des cycles, des étapes, des vidéos et des
 * abonnements d'alerte pointent dessus, et la désactivation est réversible.
 */
const LEGACY_SEED_IDS = [
  'chevening_uk',
  'knight_hennessy_stanford',
  'mccall_macbain',
  'rhodes_oxford',
  'mext_japan',
  'canada_future',
  'france_excellence',
  'fulbright_foreign',
  'mastercard_foundation',
  'helmut_schmidt_daad',
  'turkiye_burslari',
] as const;

const COMMANDS = ['import', 'publish', 'deactivate-legacy', 'switch'] as const;
type Command = (typeof COMMANDS)[number];

const CATALOG_TAG = `catalog:${SCHOLARSHIP_CATALOG_V1.catalogVersion}`;

interface Options {
  command: Command;
  apply: boolean;
  confirmedOnly: boolean;
}

/**
 * Levée pour annuler une transaction après avoir imprimé le détail : Prisma
 * n'écrit rien si le callback rejette.
 */
class RollbackSignal extends Error {}

function parseArgs(argv: string[]): Options | string {
  const positional = argv.filter((arg) => !arg.startsWith('--'));
  const command = positional[0] as Command | undefined;
  if (!command || !COMMANDS.includes(command)) {
    return `Usage: scholarships-catalog <${COMMANDS.join('|')}> (--dry-run|--apply) [--confirmed-only]`;
  }
  const apply = argv.includes('--apply');
  const dryRun = argv.includes('--dry-run');
  if (apply === dryRun) {
    return 'Choose exactly one mode: --dry-run or --apply.';
  }
  const confirmedOnly = argv.includes('--confirmed-only');
  if (confirmedOnly && command === 'import') {
    return '--confirmed-only applies to publish and switch, not to import.';
  }
  return { command, apply, confirmedOnly };
}

/**
 * Rattache chaque anomalie à l'index de la fiche concernée, pour pouvoir écarter
 * UNE fiche au lieu de refuser tout le catalogue. Le refus global était la
 * falaise du 19 août : une seule campagne close rendait les 33 autres fiches
 * inimportables.
 */
function issuesByRecordIndex(
  report: ScholarshipCatalogValidationReport,
): Map<number, string[]> {
  const byIndex = new Map<number, string[]>();
  for (const issue of report.issues) {
    const match = /^records\[(\d+)\]/.exec(issue.path);
    if (!match) continue;
    const index = Number(match[1]);
    const codes = byIndex.get(index) ?? [];
    codes.push(issue.code);
    byIndex.set(index, codes);
  }
  return byIndex;
}

function globalIssues(report: ScholarshipCatalogValidationReport): string[] {
  return report.issues
    .filter((issue) => !issue.path.startsWith('records['))
    .map((issue) => `${issue.code} @ ${issue.path}`);
}

type ScholarshipWithRelations = Prisma.ScholarshipGetPayload<{
  include: { applicationSteps: true; cycles: true };
}>;

/** La même porte que celle de l'admin, jamais une seconde règle parallèle. */
const quality = new ScholarshipContentQualityService(
  {} as unknown as PrismaService,
);

function closingDate(
  cycle: ScholarshipWithRelations['cycles'][number],
): Date | null {
  return cycle.dateConfidence === 'estimated'
    ? cycle.estimatedCloseAt
    : cycle.closesAt;
}

interface PublishDecision {
  id: string;
  publish: boolean;
  reason: string;
  confidence: string;
}

function decidePublication(
  row: ScholarshipWithRelations,
  now: Date,
  confirmedOnly: boolean,
): PublishDecision {
  const report = quality.evaluate(row, undefined, now);
  const cycle = row.cycles.find((item) => item.status === 'open') ?? row.cycles[0];
  const confidence = cycle?.dateConfidence ?? 'unknown';
  if (!report.ready) {
    return {
      id: row.id,
      publish: false,
      reason: `porte de qualité : ${report.blockingIssues.map((issue) => issue.code).join(', ')}`,
      confidence,
    };
  }
  // La porte de qualité vérifie la cohérence du cycle, pas que la campagne soit
  // encore ouverte à l'heure qu'il est. On refuse donc en plus toute fiche dont
  // la clôture est passée : c'était le défaut servi en production (trois dates
  // limites dépassées de 13 à 90 jours, toujours affichées comme disponibles).
  const close = cycle ? closingDate(cycle) : null;
  if (!close || close.getTime() <= now.getTime()) {
    return {
      id: row.id,
      publish: false,
      reason: `clôture absente ou passée (${close ? close.toISOString().slice(0, 10) : 'aucune'})`,
      confidence,
    };
  }
  if (confirmedOnly && confidence !== 'confirmed') {
    return {
      id: row.id,
      publish: false,
      reason: 'dates estimées, écartées par --confirmed-only',
      confidence,
    };
  }
  return { id: row.id, publish: true, reason: 'éligible', confidence };
}

async function runImport(prisma: PrismaClient, apply: boolean): Promise<void> {
  const now = new Date();
  const report = validateScholarshipCatalog(SCHOLARSHIP_CATALOG_V1, {
    includeVolumeTargets: false,
    now,
  });
  const blocking = issuesByRecordIndex(report);
  const global = globalIssues(report);
  if (global.length > 0) {
    throw new Error(
      `Catalogue refusé au niveau global : ${global.join(' | ')}. ` +
        'Ces anomalies ne concernent aucune fiche en particulier et doivent être corrigées.',
    );
  }

  const importable = SCHOLARSHIP_CATALOG_V1.records.filter(
    (_, index) => !blocking.has(index),
  );
  const skipped = SCHOLARSHIP_CATALOG_V1.records
    .map((record, index) => ({ record, codes: blocking.get(index) }))
    .filter((entry) => entry.codes)
    .map((entry) => `${entry.record.scholarship.id} (${entry.codes!.join(', ')})`);

  console.log(
    JSON.stringify(
      {
        step: 'import',
        mode: apply ? 'apply' : 'dry-run',
        catalogVersion: SCHOLARSHIP_CATALOG_V1.catalogVersion,
        records: SCHOLARSHIP_CATALOG_V1.records.length,
        importable: importable.length,
        skipped,
      },
      null,
      2,
    ),
  );
  if (importable.length === 0) {
    throw new Error('Aucune fiche importable : rien à faire.');
  }
  if (!apply) return;

  const writer: ScholarshipCatalogWriter = {
    async createIfAbsent(record) {
      const existing = await prisma.scholarship.findUnique({
        where: { id: record.scholarship.id },
        select: { id: true },
      });
      if (existing) return 'existing';
      try {
        await prisma.scholarship.create({
          data: buildScholarshipCreateData(
            record,
            SCHOLARSHIP_CATALOG_V1.catalogVersion,
          ),
        });
        return 'created';
      } catch (error) {
        if (isUniqueConflict(error)) {
          const concurrent = await prisma.scholarship.findUnique({
            where: { id: record.scholarship.id },
            select: { id: true },
          });
          if (concurrent) return 'existing';
        }
        throw error;
      }
    },
  };

  const summary = await importScholarshipCatalog(
    { ...SCHOLARSHIP_CATALOG_V1, records: importable },
    writer,
  );
  console.log(JSON.stringify({ step: 'import', ...summary }, null, 2));
}

async function publishInTransaction(
  tx: Prisma.TransactionClient,
  now: Date,
  confirmedOnly: boolean,
): Promise<PublishDecision[]> {
  const rows = await tx.scholarship.findMany({
    where: { tags: { has: CATALOG_TAG } },
    include: {
      applicationSteps: { orderBy: { stepNumber: 'asc' } },
      cycles: { orderBy: { academicYear: 'desc' } },
    },
  });
  const decisions = rows.map((row) => decidePublication(row, now, confirmedOnly));
  for (const decision of decisions.filter((item) => item.publish)) {
    await tx.scholarship.update({
      where: { id: decision.id },
      data: { isActive: true, moderationStatus: 'approved' },
    });
  }
  return decisions;
}

async function deactivateLegacyInTransaction(
  tx: Prisma.TransactionClient,
): Promise<string[]> {
  const present = await tx.scholarship.findMany({
    where: { id: { in: [...LEGACY_SEED_IDS] }, isActive: true },
    select: { id: true },
  });
  if (present.length > 0) {
    await tx.scholarship.updateMany({
      where: { id: { in: present.map((row) => row.id) } },
      data: { isActive: false, moderationStatus: 'pending' },
    });
  }
  return present.map((row) => row.id);
}

/**
 * Refuse de valider la transaction si une fiche publiée n'a pas de date de
 * vérification. C'est l'état exact que la production servait : 11 fiches
 * actives, 0 vérifiée. Cette assertion est le dernier filet, après la porte de
 * qualité, parce qu'une réapprobation manuelle depuis l'admin peut contourner
 * la première.
 */
async function assertNoUnverifiedPublication(
  tx: Prisma.TransactionClient,
): Promise<void> {
  const unverified = await tx.scholarship.findMany({
    where: { isActive: true, lastVerifiedAt: null },
    select: { id: true },
  });
  if (unverified.length > 0) {
    throw new Error(
      `Transaction annulée : ${unverified.length} fiche(s) publiée(s) sans date de vérification (${unverified
        .map((row) => row.id)
        .join(', ')}).`,
    );
  }
}

async function runPublishAndSwitch(
  prisma: PrismaClient,
  options: Options,
): Promise<void> {
  const now = new Date();
  const alsoDeactivate = options.command === 'switch';

  try {
    await prisma.$transaction(async (tx) => {
      const decisions = await publishInTransaction(
        tx,
        now,
        options.confirmedOnly,
      );
      const deactivated = alsoDeactivate
        ? await deactivateLegacyInTransaction(tx)
        : [];

      await assertNoUnverifiedPublication(tx);

      const active = await tx.scholarship.count({
        where: { isActive: true, moderationStatus: 'approved' },
      });
      console.log(
        JSON.stringify(
          {
            step: options.command,
            mode: options.apply ? 'apply' : 'dry-run',
            confirmedOnly: options.confirmedOnly,
            published: decisions.filter((item) => item.publish).length,
            refused: decisions
              .filter((item) => !item.publish)
              .map((item) => `${item.id} — ${item.reason}`),
            legacyDeactivated: deactivated,
            activeApprovedAfter: active,
          },
          null,
          2,
        ),
      );
      if (!options.apply) {
        throw new RollbackSignal('dry-run');
      }
    });
  } catch (error) {
    if (error instanceof RollbackSignal) {
      console.log('Mode --dry-run : transaction annulée, aucune écriture.');
      return;
    }
    throw error;
  }
}

async function runDeactivateLegacy(
  prisma: PrismaClient,
  apply: boolean,
): Promise<void> {
  try {
    await prisma.$transaction(async (tx) => {
      const deactivated = await deactivateLegacyInTransaction(tx);
      console.log(
        JSON.stringify(
          {
            step: 'deactivate-legacy',
            mode: apply ? 'apply' : 'dry-run',
            deactivated,
            untouched: LEGACY_SEED_IDS.filter(
              (id) => !deactivated.includes(id),
            ),
          },
          null,
          2,
        ),
      );
      if (!apply) throw new RollbackSignal('dry-run');
    });
  } catch (error) {
    if (error instanceof RollbackSignal) {
      console.log('Mode --dry-run : transaction annulée, aucune écriture.');
      return;
    }
    throw error;
  }
}

function isUniqueConflict(error: unknown): boolean {
  return (
    error != null &&
    typeof error === 'object' &&
    'code' in error &&
    (error as { code?: unknown }).code === 'P2002'
  );
}

async function main(): Promise<void> {
  const parsed = parseArgs(process.argv.slice(2));
  if (typeof parsed === 'string') {
    console.error(parsed);
    process.exitCode = 2;
    return;
  }

  if (!process.env.DATABASE_URL && existsSync('.env')) {
    loadEnvFile('.env');
  }
  if (!process.env.DATABASE_URL) {
    throw new Error('DATABASE_URL is required.');
  }

  const prisma = new PrismaClient();
  try {
    if (parsed.command === 'import') {
      await runImport(prisma, parsed.apply);
    } else if (parsed.command === 'deactivate-legacy') {
      await runDeactivateLegacy(prisma, parsed.apply);
    } else {
      await runPublishAndSwitch(prisma, parsed);
    }
  } finally {
    await prisma.$disconnect();
  }
}

// Garde d'exécution directe : sans elle, importer ce module depuis un test
// ouvrirait une connexion Prisma et lancerait la commande.
if (require.main === module) {
  void main().catch((error: unknown) => {
    console.error(
      `scholarships-catalog a échoué : ${error instanceof Error ? error.message : String(error)}`,
    );
    process.exitCode = 1;
  });
}

export { LEGACY_SEED_IDS, decidePublication, issuesByRecordIndex, parseArgs };
