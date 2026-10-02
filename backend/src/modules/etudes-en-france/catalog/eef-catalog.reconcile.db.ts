// ─────────────────────────────────────────────────────────────────────────────
// `eef:reconcile` — la moitié qui lit et écrit la base. Le pourquoi et les règles
// sont dans `eef-catalog.reconcile.ts`.
//
// DEUX GARANTIES, PRISES À LA PUBLICATION DÉLÉGUÉE
//
// 1. L'écriture applique les listes EXACTES de la simulation. Chaque formation
//    n'est réécrite que si la base porte encore, au caractère près, ce que la
//    simulation a lu (`updateMany` dont le `WHERE` répète les quatre champs) : une
//    retouche faite dans l'admin entre les deux fait échouer son établissement,
//    sans rien écrire pour lui.
// 2. Une transaction PAR ÉTABLISSEMENT, avec sa trace d'audit DEDANS : un
//    établissement est réaligné en entier avec sa trace, ou pas du tout. Un échec
//    n'arrête pas les autres ; le code de sortie, lui, le dit.
// ─────────────────────────────────────────────────────────────────────────────
import { Prisma, type PrismaClient } from '@prisma/client';

import { EEF_PROGRAM_ID_PREFIX } from '../../../common/eef-provenance';
import {
  institutionToUpdate,
  planProgramReconcile,
  type InstitutionReconcilePlan,
  type ProgramReconcilePlan,
  type ReconciledProgramField,
} from './eef-catalog.reconcile';
import type { EefCatalog, EefProgramRecord } from './eef-catalog.types';

const RECONCILABLE_SELECT = {
  id: true,
  institutionId: true,
  isActive: true,
  procedureType: true,
  selectivity: true,
  requirementsFr: true,
  requirementsEn: true,
} as const satisfies Prisma.ProgramSelect;

const TRANSACTION = {
  timeout: 5 * 60_000,
  maxWait: 30_000,
  isolationLevel: Prisma.TransactionIsolationLevel.RepeatableRead,
} as const;

export const EEF_RECONCILE_AUDIT_ACTION = 'eef.catalog.reconciled';

export interface EefReconcilePlanResult {
  readonly catalogVersion: string;
  readonly plans: readonly InstitutionReconcilePlan[];
  /**
   * Formations de l'import rattachées à un établissement ABSENT des fichiers : ni
   * réalignées ni signalées une à une — elles ne relèvent d'aucune règle connue.
   * `null` quand l'examen est restreint à quelques établissements.
   */
  readonly programsOutsideCatalogInstitutions: number | null;
}

/**
 * Lit la base établissement par établissement (le conteneur de production est
 * plafonné en mémoire : voir `eef-scripts.memory.spec.ts`) et calcule le plan.
 * N'écrit rien.
 */
export async function planEefReconcile(
  client: PrismaClient,
  catalog: EefCatalog,
  options: { readonly onlyInstitutionIds?: readonly string[] } = {},
): Promise<EefReconcilePlanResult> {
  const only = options.onlyInstitutionIds;
  const files = catalog.universities.filter(
    (file) => !only || only.includes(file.institution.id),
  );
  if (only) {
    const known = new Set(catalog.universities.map((file) => file.institution.id));
    const unknown = only.filter((id) => !known.has(id));
    if (unknown.length > 0) {
      throw new Error(`Établissement(s) absent(s) du catalogue versionné : ${unknown.join(', ')}.`);
    }
  }

  const recordById = new Map<string, EefProgramRecord>();
  for (const file of catalog.universities) {
    for (const program of file.programs) recordById.set(program.id, program);
  }

  const plans: InstitutionReconcilePlan[] = [];
  for (const file of files) {
    const rows = await client.program.findMany({
      where: {
        institutionId: file.institution.id,
        id: { startsWith: EEF_PROGRAM_ID_PREFIX },
      },
      select: RECONCILABLE_SELECT,
      orderBy: { id: 'asc' },
    });
    plans.push({
      institutionId: file.institution.id,
      institutionName: file.institution.nameFr,
      programs: rows.map((row) => planProgramReconcile(row, recordById.get(row.id))),
    });
  }

  const programsOutsideCatalogInstitutions = only
    ? null
    : await client.program.count({
        where: {
          id: { startsWith: EEF_PROGRAM_ID_PREFIX },
          institutionId: { notIn: catalog.universities.map((file) => file.institution.id) },
        },
      });

  return {
    catalogVersion: catalog.manifest.catalogVersion,
    plans,
    programsOutsideCatalogInstitutions,
  };
}

export type InstitutionApplyOutcome = 'updated' | 'nothing' | 'failed';

export interface InstitutionApplyReport {
  readonly institutionId: string;
  readonly institutionName: string;
  readonly outcome: InstitutionApplyOutcome;
  readonly programsUpdated: number;
  readonly error?: string;
}

export interface EefReconcileApplyReport {
  readonly institutions: readonly InstitutionApplyReport[];
  readonly programsUpdated: number;
  readonly hasFailures: boolean;
}

/// Levée quand une formation n'est plus ce que la simulation a lu : la
/// transaction de son établissement est annulée en entier.
export class EefReconcileConflict extends Error {
  constructor(readonly programId: string) {
    super(
      `La formation ${programId} a changé depuis la simulation (retouche dans l'admin, `
        + 'ou réconciliation concurrente) : rien n’est écrit pour son établissement. '
        + 'Relancer la simulation.',
    );
  }
}

function tally<T extends string>(values: readonly T[]): Record<string, number> {
  const out: Record<string, number> = {};
  for (const value of values) out[value] = (out[value] ?? 0) + 1;
  return out;
}

function auditChanges(
  catalogVersion: string,
  updates: readonly ProgramReconcilePlan[],
  actor: string | null,
): Prisma.InputJsonObject {
  const fields: ReconciledProgramField[] = updates.flatMap((program) => [...program.fields]);
  return {
    catalogVersion,
    programsUpdated: updates.length,
    programsPublished: updates.filter((program) => program.isActive).length,
    fields: tally(fields),
    procedureTransitions: tally(
      updates
        .filter((program) => program.fields.includes('procedureType'))
        .map((program) => `${program.before.procedureType ?? 'null'}→${program.write?.procedureType}`),
    ),
    editions: tally(updates.map((program) => program.edition ?? 'inconnue')),
    programIds: updates.map((program) => program.id),
    launchedBy: actor,
  };
}

/**
 * Écrit le plan d'une simulation. Refuse tout, AVANT la première écriture, si le
 * total confirmé n'est pas celui que la simulation annonce.
 */
export async function applyEefReconcile(
  client: PrismaClient,
  planned: EefReconcilePlanResult,
  options: {
    readonly expectedPrograms: number;
    readonly requestId: string;
    readonly actor?: string | null;
    readonly log?: (line: string) => void;
  },
): Promise<EefReconcileApplyReport> {
  const log = options.log ?? (() => undefined);
  const total = planned.plans.reduce((n, plan) => n + institutionToUpdate(plan).length, 0);
  if (!Number.isInteger(options.expectedPrograms) || options.expectedPrograms !== total) {
    throw new Error(
      `Total confirmé « ${options.expectedPrograms} », la simulation annonce ${total} : rien n'est écrit. `
        + 'Relire la simulation, puis saisir ce nombre.',
    );
  }

  const reports: InstitutionApplyReport[] = [];
  for (const plan of planned.plans) {
    const updates = institutionToUpdate(plan);
    if (updates.length === 0) {
      reports.push({
        institutionId: plan.institutionId,
        institutionName: plan.institutionName,
        outcome: 'nothing',
        programsUpdated: 0,
      });
      continue;
    }
    try {
      await client.$transaction(async (tx) => {
        for (const program of updates) {
          const write = program.write!;
          const before = program.before;
          const result = await tx.program.updateMany({
            where: {
              id: program.id,
              institutionId: plan.institutionId,
              procedureType: before.procedureType,
              selectivity: before.selectivity,
              requirementsFr: { equals: [...before.requirementsFr] },
              requirementsEn: { equals: [...before.requirementsEn] },
            },
            data: {
              procedureType: write.procedureType,
              selectivity: write.selectivity,
              requirementsFr: { set: [...write.requirementsFr] },
              requirementsEn: { set: [...write.requirementsEn] },
            },
          });
          if (result.count !== 1) throw new EefReconcileConflict(program.id);
        }
        await tx.adminAuditEvent.create({
          data: {
            actorAdminId: null,
            action: EEF_RECONCILE_AUDIT_ACTION,
            purposeCode: 'catalog_correction',
            entityType: 'Institution',
            entityId: plan.institutionId,
            requestId: options.requestId,
            reasonCode: 'catalog_rules_corrected',
            result: 'applied',
            changes: auditChanges(planned.catalogVersion, updates, options.actor ?? null),
          },
        });
      }, TRANSACTION);
      reports.push({
        institutionId: plan.institutionId,
        institutionName: plan.institutionName,
        outcome: 'updated',
        programsUpdated: updates.length,
      });
      log(`✓ ${plan.institutionName} : ${updates.length} formation(s) réalignée(s)`);
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      reports.push({
        institutionId: plan.institutionId,
        institutionName: plan.institutionName,
        outcome: 'failed',
        programsUpdated: 0,
        error: message,
      });
      log(`✗ ${plan.institutionName} : ÉCHEC, rien n'a été écrit pour lui — ${message}`);
    }
  }

  return {
    institutions: reports,
    programsUpdated: reports.reduce((n, report) => n + report.programsUpdated, 0),
    hasFailures: reports.some((report) => report.outcome === 'failed'),
  };
}
