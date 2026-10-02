// ─────────────────────────────────────────────────────────────────────────────
// `eef:reconcile` — réaligner les formations DÉJÀ en base sur les règles du dépôt.
// La moitié pure : le plan, sans base de données.
//
// LE DÉFAUT QUE CE MODULE FERME
//
// `eef:import` est création seule, et les rattrapages (`eef:backfill:*`) ne
// comblent que des colonnes vides ou des lignes encore inactives. Tant que rien
// n'était publié, une règle corrigée passait par `eef:purge-pending` puis un
// réimport. Depuis la publication du 01/10/2026 (10 029 formations), plus rien ne
// faisait atteindre la base à une correction relue en PR : les cinq erreurs
// établies le 02/10 (`docs/eef-dossier-relecture-procedures.md`, § « Réponses de
// recherche ») seraient restées en ligne.
//
// CE QUI FAIT FOI, ET SUR QUOI
//
// Le dépôt fait foi sur quatre champs, ceux que les règles calculent :
// `procedureType`, `selectivity`, `requirementsFr`, `requirementsEn`. Rien
// d'autre n'est écrit — ni `isActive` (réconcilier n'est pas publier), ni le
// tampon de vérification (`lastVerifiedAt`, `verifiedById`, `verifiedByName`), ni
// l'intitulé, la ville, le domaine.
//
// Mais une formation retouchée dans l'admin APPARTIENT à la base. Aucun journal
// ne trace ces retouches ; on reconnaît donc la ligne intacte à sa prose : une
// ligne n'est réalignée que si ses exigences sont, au caractère près, celles
// qu'une édition connue du générateur a écrites pour SA procédure et SA
// sélectivité (`EEF_PROSE_EDITIONS`). Toute autre ligne est SIGNALÉE — avec les
// champs qui divergent — et laissée telle quelle. Un administrateur qui n'a
// changé que la procédure, sans le texte, est donc protégé aussi : le texte
// machine de SA procédure ne correspond plus à celui en base.
//
// Le plan est calculé ici, sans base, pour que la simulation montre EXACTEMENT ce
// que l'application écrira : celle-ci applique les listes de la simulation, en
// comparant chaque ligne à ce que la simulation a lu (`eef-catalog.reconcile.db.ts`).
// ─────────────────────────────────────────────────────────────────────────────
import { programRequirements1_2, EEF_COPY_EDITION_1_2 } from './eef-catalog.copy-1.2';
import { EEF_COPY_EDITION, programRequirements, type Bilingual } from './eef-catalog.copy';
import {
  EEF_PROCEDURE_TYPES,
  type EefProcedureType,
  type EefProgramRecord,
  type EefSelectivity,
} from './eef-catalog.types';

/// Les seuls champs que la réconciliation écrit. La liste est explicite : un
/// champ de plus se décide en revue, pas par déduction.
export const RECONCILED_PROGRAM_FIELDS = [
  'procedureType',
  'selectivity',
  'requirementsFr',
  'requirementsEn',
] as const;

export type ReconciledProgramField = (typeof RECONCILED_PROGRAM_FIELDS)[number];

/**
 * Les éditions de la prose qu'un import a pu écrire en base, de la plus ancienne à
 * la courante. La 1.0 n'y est pas : les lignes 1.0 ont été rattrapées en 1.2 avant
 * toute publication, puis purgées et réimportées le 29/09. Une ligne qui porterait
 * encore une édition absente d'ici est SIGNALÉE, jamais devinée.
 */
export const EEF_PROSE_EDITIONS: readonly {
  readonly edition: string;
  /// `null` : cette édition n'a jamais écrit de prose pour une telle formation.
  readonly requirements: (program: EefProgramRecord) => Bilingual[] | null;
}[] = [
  { edition: EEF_COPY_EDITION_1_2, requirements: programRequirements1_2 },
  { edition: EEF_COPY_EDITION, requirements: programRequirements },
];

/// Une formation telle que la base la porte, réduite à ce qu'on compare.
export interface ReconcilableProgramRow {
  readonly id: string;
  readonly institutionId: string;
  readonly isActive: boolean;
  readonly procedureType: string | null;
  readonly selectivity: string | null;
  readonly requirementsFr: readonly string[];
  readonly requirementsEn: readonly string[];
}

/// Ce que la réconciliation écrit.
export interface ReconciledValues {
  readonly procedureType: EefProcedureType;
  readonly selectivity: EefSelectivity;
  readonly requirementsFr: readonly string[];
  readonly requirementsEn: readonly string[];
}

export type ProgramReconcileOutcome =
  /** Déjà aligné : rien à écrire. */
  | 'current'
  /** Prose machine d'une édition connue : réalignée. */
  | 'update'
  /** Ni l'une ni l'autre édition : retouchée dans l'admin, ou inconnue. Signalée. */
  | 'kept_edited'
  /** Déplacée vers un autre établissement depuis l'import. Signalée. */
  | 'kept_moved'
  /** Identifiant de l'import absent des fichiers versionnés. Signalé. */
  | 'absent_from_catalog';

export interface ProgramReconcilePlan {
  readonly id: string;
  readonly institutionId: string;
  readonly isActive: boolean;
  readonly outcome: ProgramReconcileOutcome;
  /** Les champs qui diffèrent entre la base et les règles (vide si `current`). */
  readonly fields: readonly ReconciledProgramField[];
  /** L'édition reconnue dans la prose en base (`update` et `current`). */
  readonly edition: string | null;
  /** Ce que la simulation a LU : l'écriture n'a lieu que si la base le porte encore. */
  readonly before: ReconcilableProgramRow;
  /** Ce qui sera écrit (`update` seulement). */
  readonly write: ReconciledValues | null;
}

function sameLines(left: readonly string[], right: readonly string[]): boolean {
  return left.length === right.length && left.every((line, i) => line === right[i]);
}

function isProcedure(value: string | null): value is EefProcedureType {
  return value !== null && (EEF_PROCEDURE_TYPES as readonly string[]).includes(value);
}

function isSelectivity(value: string | null): value is EefSelectivity {
  return value === 'selective' || value === 'non_selective';
}

/**
 * L'édition dont la prose en base est la copie exacte, calculée avec la procédure
 * et la sélectivité QUE LA LIGNE PORTE — ou `null`.
 */
export function proseEditionOf(
  row: ReconcilableProgramRow,
  record: EefProgramRecord,
): string | null {
  if (!isProcedure(row.procedureType) || !isSelectivity(row.selectivity)) return null;
  const asStored: EefProgramRecord = {
    ...record,
    procedureType: row.procedureType,
    selectivity: row.selectivity,
  };
  for (const { edition, requirements } of EEF_PROSE_EDITIONS) {
    const lines = requirements(asStored);
    if (
      lines !== null
      && sameLines(row.requirementsFr, lines.map((line) => line.fr))
      && sameLines(row.requirementsEn, lines.map((line) => line.en))
    ) {
      return edition;
    }
  }
  return null;
}

/// Ce que les règles courantes donnent : c'est aussi ce qu'`eef:import` écrirait.
export function reconciledValuesOf(record: EefProgramRecord): ReconciledValues {
  const lines = programRequirements(record);
  return {
    procedureType: record.procedureType,
    selectivity: record.selectivity,
    requirementsFr: lines.map((line) => line.fr),
    requirementsEn: lines.map((line) => line.en),
  };
}

function divergingFields(
  row: ReconcilableProgramRow,
  target: ReconciledValues,
): ReconciledProgramField[] {
  const out: ReconciledProgramField[] = [];
  if (row.procedureType !== target.procedureType) out.push('procedureType');
  if (row.selectivity !== target.selectivity) out.push('selectivity');
  if (!sameLines(row.requirementsFr, target.requirementsFr)) out.push('requirementsFr');
  if (!sameLines(row.requirementsEn, target.requirementsEn)) out.push('requirementsEn');
  return out;
}

export function planProgramReconcile(
  row: ReconcilableProgramRow,
  record: EefProgramRecord | undefined,
): ProgramReconcilePlan {
  const base = {
    id: row.id,
    institutionId: row.institutionId,
    isActive: row.isActive,
    before: row,
  };
  if (!record) {
    return { ...base, outcome: 'absent_from_catalog', fields: [], edition: null, write: null };
  }
  const target = reconciledValuesOf(record);
  const fields = divergingFields(row, target);
  if (record.institutionId !== row.institutionId) {
    return { ...base, outcome: 'kept_moved', fields, edition: null, write: null };
  }
  if (fields.length === 0) {
    // Identique aux règles courantes : c'est, par définition, l'édition courante.
    return { ...base, outcome: 'current', fields, edition: EEF_COPY_EDITION, write: null };
  }
  const edition = proseEditionOf(row, record);
  if (edition === null) {
    return { ...base, outcome: 'kept_edited', fields, edition: null, write: null };
  }
  return { ...base, outcome: 'update', fields, edition, write: target };
}

/// Le plan d'UN établissement : l'unité de transaction et de trace d'audit.
export interface InstitutionReconcilePlan {
  readonly institutionId: string;
  readonly institutionName: string;
  readonly programs: readonly ProgramReconcilePlan[];
}

export interface ReconcileTotals {
  readonly institutions: number;
  readonly institutionsToUpdate: number;
  readonly programsExamined: number;
  readonly programsToUpdate: number;
  /** Parmi elles, combien sont publiées (`isActive`) : ce que les étudiants voient. */
  readonly programsToUpdatePublished: number;
  readonly programsCurrent: number;
  readonly programsKeptEdited: number;
  readonly programsKeptMoved: number;
  readonly programsAbsentFromCatalog: number;
  /** Par champ, le nombre de formations où il change (parmi celles réalignées). */
  readonly byField: Readonly<Record<ReconciledProgramField, number>>;
  /** « dap_blanche→hors_eef » : 39. */
  readonly procedureTransitions: Readonly<Record<string, number>>;
  /** L'édition reconnue dans la prose des formations réalignées. */
  readonly byEdition: Readonly<Record<string, number>>;
}

export function institutionToUpdate(plan: InstitutionReconcilePlan): ProgramReconcilePlan[] {
  return plan.programs.filter((program) => program.outcome === 'update');
}

export function reconcileTotals(plans: readonly InstitutionReconcilePlan[]): ReconcileTotals {
  const byField: Record<ReconciledProgramField, number> = {
    procedureType: 0,
    selectivity: 0,
    requirementsFr: 0,
    requirementsEn: 0,
  };
  const procedureTransitions: Record<string, number> = {};
  const byEdition: Record<string, number> = {};
  const count = (outcome: ProgramReconcileOutcome) =>
    plans.reduce((n, plan) => n + plan.programs.filter((p) => p.outcome === outcome).length, 0);
  let published = 0;
  for (const plan of plans) {
    for (const program of institutionToUpdate(plan)) {
      if (program.isActive) published += 1;
      for (const field of program.fields) byField[field] += 1;
      if (program.fields.includes('procedureType')) {
        const key = `${program.before.procedureType ?? 'null'}→${program.write?.procedureType}`;
        procedureTransitions[key] = (procedureTransitions[key] ?? 0) + 1;
      }
      const edition = program.edition ?? 'inconnue';
      byEdition[edition] = (byEdition[edition] ?? 0) + 1;
    }
  }
  return {
    institutions: plans.length,
    institutionsToUpdate: plans.filter((plan) => institutionToUpdate(plan).length > 0).length,
    programsExamined: plans.reduce((n, plan) => n + plan.programs.length, 0),
    programsToUpdate: count('update'),
    programsToUpdatePublished: published,
    programsCurrent: count('current'),
    programsKeptEdited: count('kept_edited'),
    programsKeptMoved: count('kept_moved'),
    programsAbsentFromCatalog: count('absent_from_catalog'),
    byField,
    procedureTransitions,
    byEdition,
  };
}
