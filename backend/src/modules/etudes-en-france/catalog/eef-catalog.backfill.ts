// ─────────────────────────────────────────────────────────────────────────────
// Backfill du catalogue « Études en France » 1.2 — logos, description, repère
// d'admission — sur les lignes DÉJÀ créées par l'import 1.0.
//
// `eef:import` est création seule. C'est délibéré : un administrateur a pu
// corriger une ligne, et un import ne doit pas l'écraser. Conséquence, mesurée
// dès que le catalogue 1.0 a été importé : les 70 établissements et 10 247
// formations conservent leurs identifiants, donc un second import pose les
// 14 établissements nouveaux et laisse les anciens SANS logo, SANS résumé,
// SANS profil Parcoursup. Ce module est l'acte distinct qui comble ça.
//
// Il ne crée rien. Il ne publie rien. Il ne pose pas `lastVerifiedAt`.
// ─────────────────────────────────────────────────────────────────────────────
import type { PlannedInstitution, PlannedProgram } from './eef-catalog.importer';

export const INSTITUTION_LOGO_COLUMNS = [
  'logoUrl',
  'logoSourceUrl',
  'logoLicence',
] as const;

export type InstitutionLogoColumn = (typeof INSTITUTION_LOGO_COLUMNS)[number];

export interface ExistingInstitutionRow {
  readonly id: string;
  readonly logoUrl: string | null;
  readonly logoSourceUrl: string | null;
  readonly logoLicence: string | null;
}

export interface ExistingProgramRow {
  readonly id: string;
  readonly isActive: boolean;
  readonly lastVerifiedAt: Date | null;
  readonly requirementsFr: readonly string[];
  readonly requirementsEn: readonly string[];
}

export type BackfillKeptReason =
  | 'absent'
  | 'already_complete'
  | 'no_reusable_logo'
  | 'logo_partially_set'
  | 'verified_or_published'
  | 'requirements_no_longer_generated';

export interface InstitutionLogoWrite {
  readonly logoUrl: string;
  readonly logoSourceUrl: string;
  readonly logoLicence: string;
}

export interface InstitutionLogoPlan {
  readonly id: string;
  readonly write: InstitutionLogoWrite | null;
  readonly keptReason?: BackfillKeptReason;
}

export interface ProgramRequirementsPlan {
  readonly id: string;
  readonly writeFr: readonly string[] | null;
  readonly writeEn: readonly string[] | null;
  readonly procedureFr: string | null;
  readonly procedureEn: string | null;
  readonly admissionFr: string | null;
  readonly admissionEn: string | null;
  readonly keptReasonFr?: BackfillKeptReason;
  readonly keptReasonEn?: BackfillKeptReason;
}

const ADMISSION_NEEDLE_FR = 'Aucune moyenne minimale officielle';
const ADMISSION_NEEDLE_EN = 'No official minimum grade';

const PROCEDURE_NEEDLES_FR = ['Candidature par', 'Admission gérée'] as const;
const PROCEDURE_NEEDLES_EN = [
  'Apply through',
  'Apply on Parcoursup',
  'Admission is handled',
] as const;

export function admissionLineOf(
  lines: readonly string[],
  lang: 'fr' | 'en',
): string | null {
  const needle = lang === 'fr' ? ADMISSION_NEEDLE_FR : ADMISSION_NEEDLE_EN;
  return lines.find((line) => line.includes(needle)) ?? null;
}

export function procedureLineOf(
  lines: readonly string[],
  lang: 'fr' | 'en',
): string | null {
  const needles = lang === 'fr' ? PROCEDURE_NEEDLES_FR : PROCEDURE_NEEDLES_EN;
  return (
    lines.find((line) => needles.some((needle) => line.startsWith(needle))) ??
    null
  );
}

function linesEqual(left: readonly string[], right: readonly string[]): boolean {
  return (
    left.length === right.length && left.every((line, i) => line === right[i])
  );
}

function plannedLogo(
  planned: PlannedInstitution,
): InstitutionLogoWrite | null {
  const { logoUrl, logoSourceUrl, logoLicence } = planned;
  if (!logoUrl || !logoSourceUrl || !logoLicence) return null;
  return { logoUrl, logoSourceUrl, logoLicence };
}

/**
 * Les trois colonnes logo voyagent ensemble : une URL sans licence n'est pas
 * affichable, une licence sans URL n'identifie rien. On n'écrit donc que si
 * les trois valeurs du plan sont présentes ET que les trois colonnes en base
 * sont encore nulles. Un logo déjà saisi — même incomplet — appartient à la
 * base.
 */
export function planInstitutionLogoBackfill(
  planned: PlannedInstitution,
  existing: ExistingInstitutionRow | null,
): InstitutionLogoPlan {
  const write = plannedLogo(planned);
  if (existing == null) {
    return { id: planned.id, write: null, keptReason: 'absent' };
  }
  if (write == null) {
    return { id: planned.id, write: null, keptReason: 'no_reusable_logo' };
  }
  const empty =
    existing.logoUrl == null &&
    existing.logoSourceUrl == null &&
    existing.logoLicence == null;
  if (!empty) {
    const already =
      existing.logoUrl === write.logoUrl &&
      existing.logoSourceUrl === write.logoSourceUrl &&
      existing.logoLicence === write.logoLicence;
    return {
      id: planned.id,
      write: null,
      keptReason: already ? 'already_complete' : 'logo_partially_set',
    };
  }
  return { id: planned.id, write };
}

function planOneLanguage(
  planned: readonly string[],
  existing: ExistingProgramRow,
  lang: 'fr' | 'en',
): {
  write: readonly string[] | null;
  procedure: string | null;
  admission: string | null;
  keptReason?: BackfillKeptReason;
} {
  const procedure = procedureLineOf(planned, lang);
  const admission = admissionLineOf(planned, lang);
  const current = lang === 'fr' ? existing.requirementsFr : existing.requirementsEn;

  if (existing.isActive || existing.lastVerifiedAt != null) {
    return {
      write: null,
      procedure,
      admission,
      keptReason: 'verified_or_published',
    };
  }
  if (procedure == null || admission == null) {
    return {
      write: null,
      procedure,
      admission,
      keptReason: 'requirements_no_longer_generated',
    };
  }
  if (linesEqual(current, planned)) {
    return { write: null, procedure, admission, keptReason: 'already_complete' };
  }
  if (!current.includes(procedure)) {
    return {
      write: null,
      procedure,
      admission,
      keptReason: 'requirements_no_longer_generated',
    };
  }
  if (current.includes(admission)) {
    return { write: null, procedure, admission, keptReason: 'already_complete' };
  }
  return { write: planned, procedure, admission };
}

/**
 * Réécrit `requirementsFr` / `requirementsEn` seulement si la ligne est
 * encore la prose machine de l'import 1.0 : inactive, jamais vérifiée, et
 * elle porte encore la phrase de procédure que cet import avait écrite.
 * Une ligne publiée, vérifiée, ou éditée au point de ne plus citer la
 * procédure, appartient à la base.
 */
export function planProgramRequirementsBackfill(
  planned: PlannedProgram,
  existing: ExistingProgramRow | null,
): ProgramRequirementsPlan {
  if (existing == null) {
    return {
      id: planned.id,
      writeFr: null,
      writeEn: null,
      procedureFr: procedureLineOf(planned.requirementsFr, 'fr'),
      procedureEn: procedureLineOf(planned.requirementsEn, 'en'),
      admissionFr: admissionLineOf(planned.requirementsFr, 'fr'),
      admissionEn: admissionLineOf(planned.requirementsEn, 'en'),
      keptReasonFr: 'absent',
      keptReasonEn: 'absent',
    };
  }
  const fr = planOneLanguage(planned.requirementsFr, existing, 'fr');
  const en = planOneLanguage(planned.requirementsEn, existing, 'en');
  return {
    id: planned.id,
    writeFr: fr.write,
    writeEn: en.write,
    procedureFr: fr.procedure,
    procedureEn: en.procedure,
    admissionFr: fr.admission,
    admissionEn: en.admission,
    keptReasonFr: fr.keptReason,
    keptReasonEn: en.keptReason,
  };
}
