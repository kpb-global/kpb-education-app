import {
  EEF_INSTITUTION_ID_PREFIX,
  EEF_PROGRAM_ID_PREFIX,
} from '../../../common/eef-provenance';
import { KNOWN_FIELD_IDS } from '../catalog/eef-catalog.normalize';

/**
 * Le plan de publication d'un établissement de l'import « Études en France ».
 *
 * ## Ce que « publier » veut dire ici
 *
 * L'import dépose ses lignes INACTIVES. Tant qu'elles le sont, aucune surface
 * publique ne les sert (`/etudes-en-france/search` est publique : c'est la
 * publication, pas le drapeau du client, qui les expose). Publier, c'est donc
 * l'acte qui rend visibles, à un étudiant qui n'a pas de compte, un nom, une
 * ville, un logo et des formations que personne n'avait relus.
 *
 * Ce module ne fait QUE décider. Il est pur — pas de base, pas d'horloge — pour
 * que chaque refus se prouve par un test qui écrit la ligne à la main, et pour
 * que le service puisse RECALCULER le plan dans la transaction d'écriture au lieu
 * de croire celui que l'administrateur a vu en simulation.
 *
 * ## Ce qu'il exige
 *
 * L'établissement : venir de l'import (préfixe), porter une source HTTPS.
 * Chaque formation : venir de l'import, dépendre de CET établissement, porter une
 * source HTTPS, une procédure qualifiée et un domaine du référentiel.
 *
 * La procédure est exigée parce qu'elle décide du calendrier de l'étudiant ; le
 * domaine parce que la shortlist classe dessus ; la source parce que le badge
 * « Vérifié » promet qu'on a regardé une page.
 *
 * Il n'exige PAS que la source soit une fiche de formation plutôt que la page
 * d'accueil de l'établissement : une machine ne sait pas les distinguer, et le
 * dire serait promettre plus que la vérification (`docs/catalog-verification-sop.md`).
 */
export interface PublicationInstitution {
  readonly id: string;
  readonly nameFr: string;
  readonly isActive: boolean;
  readonly sourceUrl: string | null;
}

export interface PublicationProgram {
  readonly id: string;
  readonly institutionId: string;
  readonly nameFr: string;
  readonly isActive: boolean;
  readonly sourceUrl: string | null;
  readonly procedureType: string | null;
  readonly fieldId: string;
}

export type InstitutionRefusal =
  | 'institution_not_from_import'
  | 'institution_source_missing';

export type ProgramRefusal =
  | 'program_unknown'
  | 'program_not_from_import'
  | 'program_wrong_institution'
  | 'program_source_missing'
  | 'program_procedure_missing'
  | 'program_field_unknown';

/**
 * Ce que désigne le `sourceUrl` d'une formation. Pour 40 % de l'import il ne
 * s'agit PAS de la fiche de la formation : 1 078 masters pointent la page
 * d'accueil du portail Mon Master, 3 134 L2/L3 la page du jeu de données ouvert
 * (`docs/eef-catalog-pipeline.md` § 2.8). Ces sources prouvent que la formation
 * existe ; elles ne disent pas où s'y inscrire.
 */
export type SourceKind =
  | 'formation_page'
  | 'ministry_portal'
  | 'ministry_dataset';

const MINISTRY_PORTAL_HOSTS: ReadonlySet<string> = new Set([
  'monmaster.gouv.fr',
  'www.monmaster.gouv.fr',
]);
const MINISTRY_DATASET_HOST = 'data.enseignementsup-recherche.gouv.fr';

export function classifyProgramSource(url: string | null): SourceKind {
  if (url === null) return 'formation_page';
  try {
    const parsed = new URL(url.trim());
    const host = parsed.hostname.toLowerCase();
    if (host === MINISTRY_DATASET_HOST) return 'ministry_dataset';
    // La racine du portail seulement : une page profonde de `monmaster.gouv.fr`
    // (une fiche de master) est une vraie source.
    if (MINISTRY_PORTAL_HOSTS.has(host) && parsed.pathname.replace(/\/+$/, '') === '') {
      return 'ministry_portal';
    }
  } catch {
    // Une URL illisible est refusée ailleurs (`program_source_missing`).
  }
  return 'formation_page';
}

export interface RefusedProgram {
  readonly id: string;
  readonly nameFr: string | null;
  readonly reasons: readonly ProgramRefusal[];
}

export interface PublicationPlan {
  readonly institutionId: string;
  readonly institutionName: string;
  readonly institution: {
    readonly alreadyActive: boolean;
    /** Vrai si l'application de ce plan RENDRAIT l'établissement visible. */
    readonly willActivate: boolean;
    readonly refusals: readonly InstitutionRefusal[];
  };
  readonly programs: {
    /** Les identifiants que l'application publierait, triés. */
    readonly toPublish: readonly string[];
    readonly alreadyActive: number;
    readonly refused: readonly RefusedProgram[];
    /**
     * Parmi les formations à publier, celles dont la source n'est pas la fiche de
     * la formation. INFORMATIF : le plan ne les refuse pas (voir
     * `docs/eef-catalog-pipeline.md` § 2.8), il les montre avant la signature.
     */
    readonly genericSource: {
      readonly ministryPortal: number;
      readonly ministryDataset: number;
    };
  };
  /** Il y a quelque chose à écrire, et rien ne l'interdit. */
  readonly publishable: boolean;
  /**
   * Pourquoi rien ne s'écrirait, quand `publishable` est faux et qu'aucun refus
   * ne l'explique (établissement sans formation publiable, ou déjà tout publié).
   */
  readonly nothingToDo: 'no_publishable_program' | 'already_published' | null;
}

function isHttpsUrl(value: string | null): boolean {
  if (value === null || value.trim() === '') return false;
  try {
    return new URL(value.trim()).protocol === 'https:';
  } catch {
    return false;
  }
}

function programRefusals(
  program: PublicationProgram,
  institutionId: string,
): ProgramRefusal[] {
  const reasons: ProgramRefusal[] = [];
  if (!program.id.startsWith(EEF_PROGRAM_ID_PREFIX)) {
    reasons.push('program_not_from_import');
  }
  if (program.institutionId !== institutionId) {
    reasons.push('program_wrong_institution');
  }
  if (!isHttpsUrl(program.sourceUrl)) reasons.push('program_source_missing');
  if (program.procedureType === null || program.procedureType.trim() === '') {
    reasons.push('program_procedure_missing');
  }
  if (!KNOWN_FIELD_IDS.has(program.fieldId)) {
    reasons.push('program_field_unknown');
  }
  return reasons;
}

export function planEefPublication(input: {
  readonly institution: PublicationInstitution;
  /**
   * Sans `programIds` : les formations de CET établissement. Avec : les formations
   * dont l'identifiant a été demandé, QUEL QUE SOIT leur établissement — c'est le
   * plan qui refuse celle d'un autre (`program_wrong_institution`), pas la requête
   * qui la fait disparaître en silence.
   */
  readonly programs: readonly PublicationProgram[];
  /**
   * Restreint la publication à ces formations. Absent : toutes les formations
   * encore inactives de l'établissement. Un identifiant inconnu est REFUSÉ et
   * nommé, jamais ignoré — sinon une faute de frappe se lirait « publié ».
   */
  readonly programIds?: readonly string[];
}): PublicationPlan {
  const { institution } = input;
  const institutionRefusals: InstitutionRefusal[] = [];
  if (!institution.id.startsWith(EEF_INSTITUTION_ID_PREFIX)) {
    institutionRefusals.push('institution_not_from_import');
  }
  if (!isHttpsUrl(institution.sourceUrl)) {
    institutionRefusals.push('institution_source_missing');
  }

  const byId = new Map(input.programs.map((program) => [program.id, program]));
  const refused: RefusedProgram[] = [];
  const toPublish: string[] = [];
  let alreadyActive = 0;

  const candidates: Array<{ id: string; program: PublicationProgram | null }> =
    input.programIds
      ? Array.from(new Set(input.programIds)).map((id) => ({
          id,
          program: byId.get(id) ?? null,
        }))
      : input.programs
          .filter((program) => !program.isActive)
          .map((program) => ({ id: program.id, program }));

  if (input.programIds === undefined) {
    alreadyActive = input.programs.filter((program) => program.isActive).length;
  }

  for (const { id, program } of candidates) {
    if (program === null) {
      refused.push({ id, nameFr: null, reasons: ['program_unknown'] });
      continue;
    }
    if (program.isActive) {
      alreadyActive += 1;
      continue;
    }
    const reasons = programRefusals(program, institution.id);
    if (reasons.length > 0) {
      refused.push({ id, nameFr: program.nameFr, reasons });
    } else {
      toPublish.push(id);
    }
  }
  toPublish.sort();
  refused.sort((a, b) => a.id.localeCompare(b.id));

  // Un établissement refusé n'écrit RIEN : annoncer des formations « à publier »
  // sous une fiche qui ne le sera pas ferait lire un plan qui n'aura pas lieu.
  const blocked = institutionRefusals.length > 0;
  if (blocked) toPublish.length = 0;
  const sourceKinds = new Map(
    input.programs.map((program) => [
      program.id,
      classifyProgramSource(program.sourceUrl),
    ]),
  );
  const publishable = !blocked && toPublish.length > 0;
  let nothingToDo: PublicationPlan['nothingToDo'] = null;
  if (!blocked && toPublish.length === 0) {
    nothingToDo =
      refused.length === 0 && institution.isActive && alreadyActive > 0
        ? 'already_published'
        : 'no_publishable_program';
  }

  return {
    institutionId: institution.id,
    institutionName: institution.nameFr,
    institution: {
      alreadyActive: institution.isActive,
      willActivate: publishable && !institution.isActive,
      refusals: institutionRefusals,
    },
    programs: {
      toPublish,
      alreadyActive,
      refused,
      genericSource: {
        ministryPortal: toPublish.filter(
          (id) => sourceKinds.get(id) === 'ministry_portal',
        ).length,
        ministryDataset: toPublish.filter(
          (id) => sourceKinds.get(id) === 'ministry_dataset',
        ).length,
      },
    },
    publishable,
    nothingToDo,
  };
}

export interface UnpublicationPlan {
  readonly institutionId: string;
  readonly institutionName: string;
  /** Vrai : l'établissement disparaît aussi (aucun `programIds` demandé). */
  readonly deactivateInstitution: boolean;
  readonly toDeactivate: readonly string[];
  readonly refused: readonly RefusedProgram[];
  /**
   * Étudiants ayant enregistré l'une de ces formations : ils la perdent de leur
   * liste. Rendu visible AVANT d'écrire, parce que c'est le seul coût d'un retrait
   * que l'administrateur ne peut pas deviner.
   */
  readonly savedByStudents: number;
  readonly refusals: readonly InstitutionRefusal[];
  readonly nothingToDo: boolean;
}

export function planEefUnpublication(input: {
  readonly institution: PublicationInstitution;
  readonly programs: readonly PublicationProgram[];
  readonly programIds?: readonly string[];
  readonly savedByStudents: number;
}): UnpublicationPlan {
  const { institution } = input;
  const refusals: InstitutionRefusal[] = [];
  if (!institution.id.startsWith(EEF_INSTITUTION_ID_PREFIX)) {
    refusals.push('institution_not_from_import');
  }

  const byId = new Map(input.programs.map((program) => [program.id, program]));
  const refused: RefusedProgram[] = [];
  const toDeactivate: string[] = [];

  if (input.programIds) {
    for (const id of new Set(input.programIds)) {
      const program = byId.get(id);
      if (!program) {
        refused.push({ id, nameFr: null, reasons: ['program_unknown'] });
      } else if (
        !program.id.startsWith(EEF_PROGRAM_ID_PREFIX)
        || program.institutionId !== institution.id
      ) {
        refused.push({
          id,
          nameFr: program.nameFr,
          reasons: [
            ...(program.id.startsWith(EEF_PROGRAM_ID_PREFIX)
              ? []
              : (['program_not_from_import'] as const)),
            ...(program.institutionId === institution.id
              ? []
              : (['program_wrong_institution'] as const)),
          ],
        });
      } else if (program.isActive) {
        toDeactivate.push(id);
      }
    }
  } else {
    for (const program of input.programs) {
      if (!program.id.startsWith(EEF_PROGRAM_ID_PREFIX)) continue;
      if (program.isActive) toDeactivate.push(program.id);
    }
  }
  toDeactivate.sort();
  refused.sort((a, b) => a.id.localeCompare(b.id));

  const deactivateInstitution =
    refusals.length === 0 && input.programIds === undefined && institution.isActive;
  return {
    institutionId: institution.id,
    institutionName: institution.nameFr,
    deactivateInstitution,
    toDeactivate: refusals.length > 0 ? [] : toDeactivate,
    refused,
    savedByStudents: input.savedByStudents,
    refusals,
    nothingToDo:
      refusals.length === 0 && toDeactivate.length === 0 && !deactivateInstitution,
  };
}
