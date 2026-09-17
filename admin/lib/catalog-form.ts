import type { InstitutionInput, ProgramInput } from './catalog-admin-api';

/**
 * Formulaire → payload API.
 *
 * Ce module existe parce que le backend est STRICT depuis #271 sur les cinq
 * colonnes de scoring : une valeur présente mais mal typée lève un 400 nommant
 * le champ. Or un formulaire HTML rend « rien » sous trois formes différentes —
 * `''` pour un input vide, `''` pour un `<input type="number">` effacé, `''`
 * pour un `<input type="date">` vide — et les envoyer telles quelles ferait
 * échouer l'enregistrement sur un champ que l'utilisateur n'a même pas touché.
 *
 * La règle, miroir exacte du contrat backend :
 *   champ vide à la CRÉATION  → clé absente  (la colonne prend son défaut)
 *   champ vide à l'ÉDITION    → `null`       (la colonne est vidée)
 *   champ rempli               → valeur typée
 */

export interface ProgramDraft {
  institutionId: string;
  countryId: string;
  fieldId: string;
  nameFr: string;
  nameEn: string;
  levelFr: string;
  durationFr: string;
  tuitionFr: string;
  languageFr: string;
  requirementsFr: string;
  minGpaRequired: string;
  tuitionMinEur: string;
  applicationDeadline: string;
  teachingLanguages: string;
}

export const EMPTY_PROGRAM_DRAFT: ProgramDraft = {
  institutionId: '',
  countryId: '',
  fieldId: '',
  nameFr: '',
  nameEn: '',
  levelFr: '',
  durationFr: '',
  tuitionFr: '',
  languageFr: '',
  requirementsFr: '',
  minGpaRequired: '',
  tuitionMinEur: '',
  applicationDeadline: '',
  teachingLanguages: '',
};

export interface InstitutionDraft {
  nameFr: string;
  nameEn: string;
  countryId: string;
  locationFr: string;
  overviewFr: string;
  studyLevels: string[];
  tuitionLabelFr: string;
  languageRequirementsFr: string;
  intakePeriods: string;
  isPartner: boolean;
}

export const EMPTY_INSTITUTION_DRAFT: InstitutionDraft = {
  nameFr: '',
  nameEn: '',
  countryId: '',
  locationFr: '',
  overviewFr: '',
  studyLevels: [],
  tuitionLabelFr: '',
  languageRequirementsFr: '',
  intakePeriods: '',
  isPartner: false,
};

/** Liste saisie « a, b , c » → ['a','b','c']. Les vides sont écartés. */
export function splitList(raw: string): string[] {
  return raw
    .split(',')
    .map((part) => part.trim())
    .filter(Boolean);
}

export class DraftError extends Error {}

/**
 * Nombre optionnel. Renvoie `undefined` si le champ est vide (clé omise),
 * `null` en mode édition pour vider la colonne, sinon le nombre.
 * Lève sur une saisie non numérique plutôt que d'envoyer au backend une valeur
 * qu'il rejettera par un 400 moins lisible.
 */
function optionalNumber(
  raw: string,
  label: string,
  mode: 'create' | 'edit',
  { integer = false, max }: { integer?: boolean; max?: number } = {},
): number | null | undefined {
  const text = raw.trim();
  if (text === '') return mode === 'edit' ? null : undefined;
  const value = Number(text.replace(',', '.'));
  if (!Number.isFinite(value)) {
    throw new DraftError(`« ${label} » doit être un nombre.`);
  }
  if (value < 0) {
    throw new DraftError(`« ${label} » ne peut pas être négatif.`);
  }
  if (max !== undefined && value > max) {
    throw new DraftError(`« ${label} » ne peut pas dépasser ${max}.`);
  }
  return integer ? Math.trunc(value) : value;
}

/**
 * Date d'échéance. `<input type="date">` rend déjà `YYYY-MM-DD`, la seule forme
 * que le backend accepte depuis #271 — il refuse « 03/01/2027 » et
 * « 2027-02-30 ». On revérifie ici pour que l'erreur s'affiche dans le
 * formulaire plutôt que de revenir en 400.
 */
const ISO_DATE = /^\d{4}-\d{2}-\d{2}$/;

function optionalDate(
  raw: string,
  mode: 'create' | 'edit',
): string | null | undefined {
  const text = raw.trim();
  if (text === '') return mode === 'edit' ? null : undefined;
  if (!ISO_DATE.test(text)) {
    throw new DraftError(
      '« Date limite » doit être au format AAAA-MM-JJ.',
    );
  }
  const [y, m, d] = text.split('-').map(Number);
  const probe = new Date(Date.UTC(y, m - 1, d));
  if (
    probe.getUTCFullYear() !== y ||
    probe.getUTCMonth() !== m - 1 ||
    probe.getUTCDate() !== d
  ) {
    throw new DraftError(`« ${text} » n'est pas une date réelle.`);
  }
  return text;
}

function required(raw: string, label: string): string {
  const text = raw.trim();
  if (!text) throw new DraftError(`« ${label} » est obligatoire.`);
  return text;
}

/** Pose la clé seulement si une valeur a été calculée (`undefined` = ne pas toucher). */
function assign<T extends object, K extends keyof T>(
  target: T,
  key: K,
  value: T[K] | undefined,
) {
  if (value !== undefined) target[key] = value;
}

export function toProgramInput(
  draft: ProgramDraft,
  mode: 'create' | 'edit',
): ProgramInput {
  const teaching = splitList(draft.teachingLanguages);
  const payload: ProgramInput = {
    institutionId: required(draft.institutionId, 'Établissement'),
    countryId: required(draft.countryId, 'Pays'),
    fieldId: required(draft.fieldId, 'Filière'),
    nameFr: required(draft.nameFr, 'Nom (FR)'),
  };
  // Un champ texte vidé doit VIDER la colonne. `updateProgram` traite une clé
  // absente comme « ne pas toucher » : omettre ici ferait afficher « enregistré »
  // à l'utilisateur pendant que l'ancienne valeur survit et réapparaît au
  // rechargement. Même règle que pour les colonnes de scoring, appliquée
  // partout au lieu d'aux seuls champs numériques.
  const text = (value: string) => {
    const trimmed = value.trim();
    if (trimmed) return trimmed;
    return mode === 'edit' ? '' : undefined;
  };
  assign(payload, 'nameEn', text(draft.nameEn));
  assign(payload, 'levelFr', text(draft.levelFr));
  assign(payload, 'durationFr', text(draft.durationFr));
  assign(payload, 'tuitionFr', text(draft.tuitionFr));
  assign(payload, 'languageFr', text(draft.languageFr));
  if (draft.requirementsFr.trim()) {
    payload.requirementsFr = splitList(draft.requirementsFr);
  } else if (mode === 'edit') {
    payload.requirementsFr = [];
  }

  const gpa = optionalNumber(draft.minGpaRequired, 'Moyenne minimale', mode, {
    // L'échelle est sur 20 : `matching.ts` calcule
    // `(gpa - minGpaRequired + 2) / 4`. Un seuil de 125 mettrait TOUT candidat
    // à zéro, et avec `isEstimate: false` — l'app présenterait ce zéro comme
    // une certitude.
    max: 20,
  });
  if (gpa !== undefined) payload.minGpaRequired = gpa;

  const tuition = optionalNumber(draft.tuitionMinEur, 'Plancher en euros', mode, {
    integer: true,
  });
  if (tuition !== undefined) payload.tuitionMinEur = tuition;

  const deadline = optionalDate(draft.applicationDeadline, mode);
  if (deadline !== undefined) payload.applicationDeadline = deadline;

  if (teaching.length) payload.teachingLanguages = teaching;
  else if (mode === 'edit') payload.teachingLanguages = null;

  return payload;
}

export function toInstitutionInput(
  draft: InstitutionDraft,
  mode: 'create' | 'edit' = 'create',
): InstitutionInput {
  const payload: InstitutionInput = {
    nameFr: required(draft.nameFr, 'Nom (FR)'),
    countryId: required(draft.countryId, 'Pays'),
  };
  // Même règle que pour les formations : vidé à l'édition = colonne vidée.
  // Sans cela, ces champs étaient IMPOSSIBLES à effacer depuis l'éditeur, qui
  // acceptait pourtant la valeur vide sans rien dire.
  const text = (value: string) => {
    const trimmed = value.trim();
    if (trimmed) return trimmed;
    return mode === 'edit' ? '' : undefined;
  };
  assign(payload, 'nameEn', text(draft.nameEn));
  assign(payload, 'locationFr', text(draft.locationFr));
  assign(payload, 'overviewFr', text(draft.overviewFr));
  assign(payload, 'tuitionLabelFr', text(draft.tuitionLabelFr));
  assign(payload, 'languageRequirementsFr', text(draft.languageRequirementsFr));
  if (draft.studyLevels.length) payload.studyLevels = draft.studyLevels;
  else if (mode === 'edit') payload.studyLevels = [];
  if (draft.intakePeriods.trim()) {
    payload.intakePeriods = splitList(draft.intakePeriods);
  } else if (mode === 'edit') {
    payload.intakePeriods = [];
  }
  payload.isPartner = draft.isPartner;
  return payload;
}
