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
 * Cinq sous-commandes :
 *   import              crée les fiches manquantes, inactives et en attente
 *   reconcile           réaligne les fiches DÉJÀ présentes sur le dépôt
 *   publish             active les fiches éligibles
 *   deactivate-legacy   désactive les 11 fiches de démonstration nommément
 *   switch              publish puis deactivate-legacy, dans UNE transaction
 *
 * `switch` est la commande de la bascule : l'ordre publier-puis-dépublier et la
 * transaction unique garantissent qu'il n'existe aucun instant où l'onglet
 * Bourses est vide pour les utilisateurs.
 *
 * `reconcile` ferme la seconde moitié du même défaut. `import` ne touche jamais
 * une ligne existante — c'est voulu — mais rien ne réalignait ces lignes ensuite :
 * une correction relue en PR n'atteignait donc JAMAIS la production une fois la
 * fiche créée. Mesuré le 31/08/2026 : `york_pise_2027_forecast` et
 * `jj_wbgsp_2027_forecast` servaient un cycle `estimated` là où le dépôt dit
 * `confirmed` depuis le 24/08. `import --dry-run` annonçait « 34 existantes » et
 * se lisait « rien à faire ». Il liste désormais les écarts, champ par champ.
 *
 * `reconcile` ne publie ni n'approuve JAMAIS : il ne nomme même pas `isActive`
 * ni `moderationStatus`, et une assertion en fin de transaction annule tout si
 * l'état de modération d'une seule fiche a bougé pendant l'opération.
 */
import { existsSync } from 'node:fs';
import { loadEnvFile } from 'node:process';

import { Prisma, PrismaClient } from '@prisma/client';

import {
  importScholarshipCatalog,
  type ScholarshipCatalogWriter,
} from '../modules/scholarships-index/data/scholarship-catalog.importer';
import {
  planIsEmpty,
  planScholarshipReconciliation,
  type CatalogDrift,
  type ReconcilableScholarshipRow,
  type ReconciliationPlan,
} from '../modules/scholarships-index/data/scholarship-catalog.reconcile';
import { buildScholarshipCreateData } from '../modules/scholarships-index/data/scholarship-catalog.create-data';
import { SCHOLARSHIP_CATALOG_V1 } from '../modules/scholarships-index/data/scholarship-catalog.v1';
import {
  validateScholarshipCatalog,
  type ScholarshipCatalogValidationReport,
} from '../modules/scholarships-index/data/scholarship-catalog.validator';
import { ScholarshipContentQualityService } from '../modules/scholarships-index/scholarship-content-quality.service';
import type { VerifiedScholarshipCatalogRecord } from '../modules/scholarships-index/data/scholarship-catalog.types';
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

const COMMANDS = [
  'import',
  'reconcile',
  'publish',
  'deactivate-legacy',
  'switch',
] as const;
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
  if (confirmedOnly && (command === 'import' || command === 'reconcile')) {
    return `--confirmed-only applies to publish and switch, not to ${command}.`;
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

/**
 * La porte d'entrée commune à `import` et `reconcile` : le validateur écarte les
 * fiches fautives une par une, jamais le catalogue entier.
 *
 * `reconcile` la franchit pour la même raison qu'`import` : réaligner la
 * production sur un littéral que le validateur refuse reviendrait à pousser
 * l'anomalie en base au lieu de la laisser dehors.
 */
interface CatalogGate {
  importable: VerifiedScholarshipCatalogRecord[];
  skipped: string[];
}

function gateCatalog(now: Date): CatalogGate {
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
  return {
    importable: SCHOLARSHIP_CATALOG_V1.records.filter(
      (_, index) => !blocking.has(index),
    ),
    skipped: SCHOLARSHIP_CATALOG_V1.records
      .map((record, index) => ({ record, codes: blocking.get(index) }))
      .filter((entry) => entry.codes)
      .map(
        (entry) => `${entry.record.scholarship.id} (${entry.codes!.join(', ')})`,
      ),
  };
}

type CatalogReader = Pick<PrismaClient, 'scholarship'> | Prisma.TransactionClient;

/** Confronte chaque fiche du catalogue à la ligne correspondante en base. */
async function loadReconciliationPlans(
  db: CatalogReader,
  records: VerifiedScholarshipCatalogRecord[],
  catalogVersion: string,
): Promise<ReconciliationPlan[]> {
  const rows = await db.scholarship.findMany({
    where: { id: { in: records.map((record) => record.scholarship.id) } },
    include: {
      applicationSteps: { orderBy: { stepNumber: 'asc' } },
      cycles: { orderBy: { academicYear: 'desc' } },
    },
  });
  const byId = new Map(rows.map((row) => [row.id, row]));
  return records.map((record) =>
    planScholarshipReconciliation(
      record,
      catalogVersion,
      (byId.get(record.scholarship.id) ??
        null) as unknown as ReconcilableScholarshipRow | null,
    ),
  );
}

/**
 * Une divergence rendue en UNE ligne lisible dans un terminal de CI : le champ,
 * la valeur servie, la valeur du dépôt. Un rapport qui dit seulement « 2 fiches
 * divergent » oblige à ouvrir psql pour savoir sur quoi.
 */
export function driftLine(drift: CatalogDrift): string {
  const head = `${drift.scope}.${drift.field} : ${drift.inDatabase} → ${drift.inCatalog}`;
  return drift.reconciled
    ? head
    : `${head}  [CONSERVÉ EN BASE — ${drift.keptReason}]`;
}

function driftSummary(plan: ReconciliationPlan) {
  return {
    id: plan.scholarshipId,
    realign: plan.drifts.filter((drift) => drift.reconciled).length,
    keptFromDatabase: plan.drifts.filter((drift) => !drift.reconciled).length,
    fields: plan.drifts.map(driftLine),
  };
}

async function runImport(prisma: PrismaClient, apply: boolean): Promise<void> {
  const now = new Date();
  const { importable, skipped } = gateCatalog(now);

  // L'écart est relevé AVANT toute création : une ligne créée à l'instant est
  // alignée par construction, l'inclure diluerait le compte.
  const plans = await loadReconciliationPlans(
    prisma,
    importable,
    SCHOLARSHIP_CATALOG_V1.catalogVersion,
  );
  const existing = plans.filter((plan) => plan.presentInDatabase);
  const drifted = existing.filter((plan) => plan.drifts.length > 0);

  console.log(
    JSON.stringify(
      {
        step: 'import',
        mode: apply ? 'apply' : 'dry-run',
        catalogVersion: SCHOLARSHIP_CATALOG_V1.catalogVersion,
        records: SCHOLARSHIP_CATALOG_V1.records.length,
        importable: importable.length,
        skipped,
        missingFromDatabase: importable.length - existing.length,
        // Ce bloc est la raison d'être du changement : « 34 existantes » ne se
        // lit plus « rien à faire ». On dit combien sont réellement à jour, et
        // pour les autres, quel champ diverge.
        existingNotUpdated: existing.length,
        existingAligned: existing.length - drifted.length,
        existingDrifted: drifted.length,
        drift: drifted.map(driftSummary),
      },
      null,
      2,
    ),
  );
  if (drifted.length > 0) {
    console.error(
      `::warning::${drifted.length} fiche(s) en base divergent du catalogue ${SCHOLARSHIP_CATALOG_V1.catalogVersion}. ` +
        '`import` ne les corrigera pas — il ne touche jamais une ligne existante. ' +
        'Lancer `catalog:reconcile --dry-run` puis `--apply`.',
    );
  }
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

/**
 * Instantané de l'état de modération de TOUTE la table, pas seulement des fiches
 * réconciliées.
 *
 * Comparer avant/après est la seule preuve qui résiste à une régression future :
 * une assertion qui se contenterait de relire les fiches que le plan a touchées
 * ne verrait pas un effet de bord — un trigger, une cascade, un futur champ
 * ajouté par mégarde au plan. Onze fiches de démonstration sont devenues
 * publiques sur ce projet parce qu'un chemin d'écriture posait `isActive` sans
 * que personne ne l'ait demandé.
 */
async function moderationSnapshot(
  tx: Prisma.TransactionClient,
): Promise<Map<string, string>> {
  const rows = await tx.scholarship.findMany({
    select: { id: true, isActive: true, moderationStatus: true },
  });
  return new Map(
    rows.map((row) => [row.id, `${String(row.isActive)}/${row.moderationStatus}`]),
  );
}

/** Réconcilier n'est pas publier. Si la modération a bougé, on annule tout. */
export function moderationDifferences(
  before: Map<string, string>,
  after: Map<string, string>,
): string[] {
  const changed: string[] = [];
  for (const [id, state] of after) {
    const was = before.get(id);
    if (was === undefined) changed.push(`${id} (apparue : ${state})`);
    else if (was !== state) changed.push(`${id} (${was} → ${state})`);
  }
  for (const id of before.keys()) {
    if (!after.has(id)) changed.push(`${id} (disparue)`);
  }
  return changed.sort();
}

async function assertModerationUnchanged(
  tx: Prisma.TransactionClient,
  before: Map<string, string>,
): Promise<void> {
  const changed = moderationDifferences(before, await moderationSnapshot(tx));
  if (changed.length > 0) {
    throw new Error(
      `Transaction annulée : réconcilier ne doit RIEN changer à l'état de ` +
        `modération, or ${changed.length} fiche(s) ont bougé — ${changed.join(' ; ')}. ` +
        'Publier est le travail de `publish` / `switch`, jamais de `reconcile`.',
    );
  }
}

/**
 * Applique UN plan. Aucun `delete` : les étapes de candidature sont mises à jour
 * par `stepNumber` et créées si absentes, jamais supprimées — la progression des
 * étudiants y est rattachée par `ScholarshipWorkspaceStep.sourceStepId`
 * (`onDelete: SetNull`), qu'une suppression détacherait en silence.
 */
export async function applyReconciliation(
  tx: Prisma.TransactionClient,
  plan: ReconciliationPlan,
): Promise<void> {
  if (Object.keys(plan.scholarshipUpdate).length > 0) {
    await tx.scholarship.update({
      where: { id: plan.scholarshipId },
      data: plan.scholarshipUpdate as Prisma.ScholarshipUpdateInput,
    });
  }
  if (plan.cycle.action === 'create') {
    await tx.scholarshipCycle.create({
      data: {
        ...(plan.cycle.data as Prisma.ScholarshipCycleUncheckedCreateInput),
        scholarshipId: plan.scholarshipId,
      },
    });
  } else if (plan.cycle.action === 'update') {
    await tx.scholarshipCycle.update({
      where: {
        scholarshipId_academicYear: {
          scholarshipId: plan.scholarshipId,
          academicYear: plan.cycle.academicYear,
        },
      },
      data: plan.cycle.data as Prisma.ScholarshipCycleUpdateInput,
    });
  }
  for (const step of plan.steps.create) {
    await tx.scholarshipApplicationStep.create({
      data: {
        ...(step as unknown as Prisma.ScholarshipApplicationStepUncheckedCreateInput),
        scholarshipId: plan.scholarshipId,
      },
    });
  }
  for (const step of plan.steps.update) {
    await tx.scholarshipApplicationStep.update({
      where: {
        scholarshipId_stepNumber: {
          scholarshipId: plan.scholarshipId,
          stepNumber: step.stepNumber,
        },
      },
      data: step.data as Prisma.ScholarshipApplicationStepUpdateInput,
    });
  }
}

async function runReconcile(
  prisma: PrismaClient,
  apply: boolean,
): Promise<void> {
  const now = new Date();
  const { importable, skipped } = gateCatalog(now);

  try {
    await prisma.$transaction(async (tx) => {
      const before = await moderationSnapshot(tx);
      const plans = await loadReconciliationPlans(
        tx,
        importable,
        SCHOLARSHIP_CATALOG_V1.catalogVersion,
      );
      const present = plans.filter((plan) => plan.presentInDatabase);
      const writable = present.filter((plan) => !planIsEmpty(plan));
      // Divergences RÉELLES qu'on choisit de ne pas écrire (cycle activé depuis
      // l'admin, vérification humaine plus récente, étape en trop). Les taire
      // reproduirait le défaut d'origine à un cran plus loin.
      const keptOnly = present.filter(
        (plan) => planIsEmpty(plan) && plan.drifts.length > 0,
      );

      console.log(
        JSON.stringify(
          {
            step: 'reconcile',
            mode: apply ? 'apply' : 'dry-run',
            catalogVersion: SCHOLARSHIP_CATALOG_V1.catalogVersion,
            candidates: importable.length,
            presentInDatabase: present.length,
            notInDatabase: plans
              .filter((plan) => !plan.presentInDatabase)
              .map((plan) => plan.scholarshipId),
            aligned: present.length - writable.length - keptOnly.length,
            realigned: writable.map(driftSummary),
            keptFromDatabase: keptOnly.map(driftSummary),
            skippedByValidator: skipped,
          },
          null,
          2,
        ),
      );

      for (const plan of writable) {
        await applyReconciliation(tx, plan);
      }

      // Dans cet ordre : d'abord qu'on n'a rien publié, ensuite qu'on n'a rien
      // rendu impubliable en effaçant un tampon de vérification.
      await assertModerationUnchanged(tx, before);
      await assertNoUnverifiedPublication(tx);

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

/**
 * Dépublier l'ancien sans publier le neuf vide l'onglet Bourses.
 *
 * C'est arrivé en production le 14/08/2026 : `switch` a été lancé sans que
 * `import` l'ait précédé, n'a trouvé aucune ligne portant le tag du catalogue, a
 * donc publié 0 fiche — et a quand même dépublié les 11 fiches legacy. Résultat :
 * 0 bourse servie aux utilisateurs.
 *
 * Mettre les deux opérations dans une seule transaction protégeait l'ORDRE, pas
 * le RÉSULTAT. C'est le résultat que voit l'utilisateur.
 *
 * Renvoie la raison du refus, ou `null` si l'opération peut continuer.
 */
export function refuseSwitchReason(
  decisions: PublishDecision[],
  alsoDeactivate: boolean,
): string | null {
  if (!alsoDeactivate) return null;
  if (decisions.some((item) => item.publish)) return null;
  const head =
    'switch refusé : aucune fiche à publier, donc dépublier les fiches legacy ' +
    "laisserait l'onglet Bourses vide.\n" +
    `Fiches portant le tag ${CATALOG_TAG} trouvées en base : ${decisions.length}.\n`;
  if (decisions.length === 0) {
    return (
      head +
      "Cause probable : `import` n'a jamais été exécuté sur cette base. Lancez " +
      '`catalog:import --apply`, vérifiez avec `catalog:publish --dry-run`, puis ' +
      'relancez.'
    );
  }
  return (
    head +
    `Toutes ont été écartées : ${decisions
      .map((item) => `${item.id} (${item.reason})`)
      .join(' ; ')}`
  );
}

/**
 * Dernier filet, posé sur l'état FINAL de la base et non sur l'intention : à la
 * sortie d'un `switch`, il doit rester au moins une bourse publiée. Le contrôle
 * précédent raisonne sur les décisions, celui-ci sur ce que l'utilisateur verra.
 * Les deux sont nécessaires : le premier explique la cause, le second garantit
 * le résultat même si un futur chemin d'écriture contourne le premier.
 */
async function assertCatalogNotEmptied(
  tx: Prisma.TransactionClient,
  alsoDeactivate: boolean,
): Promise<void> {
  if (!alsoDeactivate) return;
  const active = await tx.scholarship.count({
    where: { isActive: true, moderationStatus: 'approved' },
  });
  if (active === 0) {
    throw new Error(
      'Transaction annulée : à la fin de cette opération, 0 bourse serait ' +
        "publiée. L'onglet Bourses serait vide pour tous les utilisateurs.",
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

      const refusal = refuseSwitchReason(decisions, alsoDeactivate);
      if (refusal) throw new Error(refusal);

      const deactivated = alsoDeactivate
        ? await deactivateLegacyInTransaction(tx)
        : [];

      await assertNoUnverifiedPublication(tx);
      await assertCatalogNotEmptied(tx, alsoDeactivate);

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
    } else if (parsed.command === 'reconcile') {
      await runReconcile(prisma, parsed.apply);
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

export {
  LEGACY_SEED_IDS,
  decidePublication,
  issuesByRecordIndex,
  parseArgs,
};
