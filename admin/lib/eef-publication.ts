/**
 * Contrat et règles d'affichage de la publication de l'import « Études en
 * France » (`POST /admin/etudes-en-france/publication/…`).
 *
 * Ce module ne DÉCIDE rien : le serveur refuse ce qui ne doit pas être publié et
 * recalcule le plan dans sa transaction. Il ne fait que (1) typer ce que le
 * serveur répond, (2) bâtir le corps d'écriture à partir du plan que
 * l'administrateur a réellement sous les yeux, et (3) rendre lisible une erreur
 * du serveur. Le corps d'écriture reprend `expectedPrograms` du plan affiché :
 * c'est ce chiffre, et lui seul, qui confirme « j'ai vu N formations ».
 */

/**
 * Les motifs de refus, tels que le serveur les nomme
 * (`backend/…/publication/eef-publication.plan.ts`). Listés ici pour que la
 * parité soit TESTÉE : un motif ajouté côté serveur sans libellé s'afficherait
 * comme une clé brute, au moment précis où l'administrateur doit comprendre
 * pourquoi une formation ne part pas.
 */
export const INSTITUTION_REFUSALS = [
  'institution_not_from_import',
  'institution_source_missing',
] as const;

export const PROGRAM_REFUSALS = [
  'program_unknown',
  'program_not_from_import',
  'program_wrong_institution',
  'program_source_missing',
  'program_procedure_missing',
  'program_field_unknown',
] as const;

export type InstitutionRefusal = (typeof INSTITUTION_REFUSALS)[number];
export type ProgramRefusal = (typeof PROGRAM_REFUSALS)[number];

export interface RefusedProgram {
  id: string;
  nameFr: string | null;
  reasons: ProgramRefusal[];
}

export interface PublicationPlan {
  institutionId: string;
  institutionName: string;
  institution: {
    alreadyActive: boolean;
    willActivate: boolean;
    refusals: InstitutionRefusal[];
  };
  programs: {
    toPublish: string[];
    alreadyActive: number;
    refused: RefusedProgram[];
    /**
     * Parmi les formations À PUBLIER, celles dont la source n'est pas la fiche de
     * la formation (portail Mon Master, jeu de données ouvert). Informatif.
     */
    genericSource: { ministryPortal: number; ministryDataset: number };
  };
  publishable: boolean;
  nothingToDo: 'no_publishable_program' | 'already_published' | null;
}

export interface UnpublicationPlan {
  institutionId: string;
  institutionName: string;
  deactivateInstitution: boolean;
  toDeactivate: string[];
  refused: RefusedProgram[];
  savedByStudents: number;
  refusals: InstitutionRefusal[];
  nothingToDo: boolean;
}

export interface EefInstitutionRow {
  id: string;
  name: string;
  isActive: boolean;
  sourceUrl: string | null;
  hasLogo: boolean;
  lastVerifiedAt: string | null;
  verifiedByName: string | null;
  programsPending: number;
  programsPublished: number;
}

export interface EefPublicationOverview {
  institutions: EefInstitutionRow[];
  totals: {
    institutions: number;
    institutionsPublished: number;
    programsPending: number;
    programsPublished: number;
  };
}

export type PublicationAction = 'publish' | 'unpublish';

/** Le corps d'une simulation : `apply` absent, le serveur ne lit qu'un plan. */
export function simulationBody(programIds?: string[]): Record<string, unknown> {
  return programIds && programIds.length > 0 ? { programIds } : {};
}

/** Combien de formations à publier renvoient à une source générique. */
export function genericSourceCount(plan: PublicationPlan): number {
  return (
    plan.programs.genericSource.ministryPortal +
    plan.programs.genericSource.ministryDataset
  );
}

/** Le nombre de formations que ce plan écrirait — celui à confirmer. */
export function plannedCount(
  action: PublicationAction,
  plan: PublicationPlan | UnpublicationPlan,
): number {
  return action === 'publish'
    ? (plan as PublicationPlan).programs.toPublish.length
    : (plan as UnpublicationPlan).toDeactivate.length;
}

/** Vrai quand le plan affiché autorise une écriture. */
export function canApply(
  action: PublicationAction,
  plan: PublicationPlan | UnpublicationPlan,
): boolean {
  if (action === 'publish') {
    return (plan as PublicationPlan).publishable;
  }
  const removal = plan as UnpublicationPlan;
  return removal.refusals.length === 0 && !removal.nothingToDo;
}

/**
 * Le corps d'écriture, bâti sur le plan AFFICHÉ. `expectedPrograms` vaut le
 * nombre que l'administrateur a vu : si la base a bougé depuis, le serveur
 * refuse (409) plutôt que d'écrire un autre nombre que celui confirmé.
 */
export function applyBody(
  action: PublicationAction,
  plan: PublicationPlan | UnpublicationPlan,
  programIds?: string[],
): Record<string, unknown> {
  return {
    apply: true,
    expectedPrograms: plannedCount(action, plan),
    ...(programIds && programIds.length > 0 ? { programIds } : {}),
  };
}

/**
 * Un message lisible pour une erreur du serveur.
 *
 * `apiFetch` met le TEXTE de la réponse dans `Error.message` : pour une erreur
 * Nest c'est un JSON (`{"message":"…","statusCode":409}`), qu'on afficherait tel
 * quel — accolades comprises — sans ce décodage. Un `message` tableau (erreurs de
 * validation) est joint. Tout ce qui n'est pas ce format est rendu tel quel.
 */
export function readableApiError(error: unknown, fallback: string): string {
  if (!(error instanceof Error) || error.message === '') return fallback;
  try {
    const parsed: unknown = JSON.parse(error.message);
    if (parsed && typeof parsed === 'object' && 'message' in parsed) {
      const { message } = parsed as { message: unknown };
      if (Array.isArray(message)) return message.map(String).join(' ');
      if (typeof message === 'string' && message !== '') return message;
    }
  } catch {
    // Pas du JSON : le texte brut est déjà le message.
  }
  return error.message;
}

/** La clé de message d'un motif de refus. */
export function refusalMessageKey(
  code: InstitutionRefusal | ProgramRefusal,
): string {
  return `eefPub.reason.${code}`;
}
