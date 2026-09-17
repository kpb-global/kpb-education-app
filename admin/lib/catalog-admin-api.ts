import { apiFetch } from './api-client';

/**
 * Client du catalogue pour le back-office.
 *
 * Les LECTURES passent par `/catalog/*`, public et non authentifié ; les
 * ÉCRITURES par `/admin/catalog/*`, derrière AdminAuthGuard + RolesGuard. Ce
 * partage vient du backend (voir le commentaire de tête de
 * admin-catalog.controller.ts), pas d'un choix côté client.
 *
 * `countryId` et `fieldId` ne sont PAS des clés étrangères en base : ce sont
 * des colonnes indexées, et rien n'empêche une fiche de pointer vers un pays
 * inexistant — elle ne remonterait alors sous aucun filtre, sans erreur. D'où
 * [fetchCountries] et [fetchFields] : les formulaires doivent proposer des
 * listes, jamais de la saisie libre.
 */

/** Champ bilingue tel que sérialisé par `/catalog/*`. */
export interface Localized {
  fr: string;
  en: string;
}

export interface CatalogCountry {
  id: string;
  name?: Localized;
  nameFr?: string;
}

export interface CatalogField {
  id: string;
  name?: Localized;
  nameFr?: string;
}

export interface CatalogInstitution {
  id: string;
  countryId: string;
  name: Localized;
  location: Localized;
  overview: Localized;
  studyLevels: string[];
  tuitionLabel: Localized;
  languageRequirements: Localized;
  intakePeriods: string[];
  isPartner: boolean;
  lastVerifiedAt: string | null;
  sourceUrl: string | null;
}

export interface CatalogProgram {
  id: string;
  institutionId: string;
  countryId: string;
  fieldId: string;
  nameFr: string;
  nameEn: string;
  levelFr: string;
  durationFr: string;
  tuitionFr: string;
  languageFr: string;
  requirementsFr: string[];
  minGpaRequired: number | null;
  tuitionMinEur: number | null;
  applicationDeadline: string | null;
  teachingLanguages: string[];
  lastVerifiedAt: string | null;
}

/**
 * Niveaux de diplôme du référentiel.
 *
 * Miroir de `normalizeDegreeLevel` côté backend, qui laisse passer TEL QUEL ce
 * qu'il ne reconnaît pas : une saisie libre ferait apparaître « Prépa » ou
 * « 1re année » dans le filtre par niveau de l'app, à côté de Bachelor et
 * Master. C'est exactement ce qui s'est produit lors de l'import Mundiapolis —
 * 4 valeurs hors référentiel sont en production.
 */
export const DEGREE_LEVELS = [
  'Bac+2',
  'Bachelor',
  'BBA',
  'Master',
  'MBA / DBA',
  'Doctorat',
] as const;

export type DegreeLevel = (typeof DEGREE_LEVELS)[number];

function unwrap<T>(payload: T[] | { items: T[] } | null | undefined): T[] {
  if (Array.isArray(payload)) return payload;
  return payload?.items ?? [];
}

/** Libellé français d'une entrée, quelle que soit la forme sérialisée. */
export function labelOf(entry: {
  name?: Localized;
  nameFr?: string;
  id: string;
}): string {
  return entry.name?.fr ?? entry.nameFr ?? entry.id;
}

// ── Lectures ────────────────────────────────────────────────────────────────

export async function fetchCountries(signal?: AbortSignal) {
  return unwrap(
    await apiFetch<CatalogCountry[] | { items: CatalogCountry[] }>(
      '/catalog/countries',
      { signal },
    ),
  );
}

export async function fetchFields(signal?: AbortSignal) {
  return unwrap(
    await apiFetch<CatalogField[] | { items: CatalogField[] }>(
      '/catalog/fields',
      { signal },
    ),
  );
}

export async function fetchInstitutions(
  params: { countryId?: string; partnerOnly?: boolean } = {},
  signal?: AbortSignal,
) {
  const query = new URLSearchParams();
  if (params.countryId) query.set('countryId', params.countryId);
  if (params.partnerOnly) query.set('partnerOnly', 'true');
  const suffix = query.size ? `?${query}` : '';
  return unwrap(
    await apiFetch<CatalogInstitution[] | { items: CatalogInstitution[] }>(
      `/catalog/institutions${suffix}`,
      { signal },
    ),
  );
}

export async function fetchPrograms(
  params: {
    q?: string;
    institutionId?: string;
    countryId?: string;
    fieldId?: string;
    limit?: number;
    offset?: number;
  } = {},
  signal?: AbortSignal,
) {
  const query = new URLSearchParams();
  for (const [key, value] of Object.entries(params)) {
    if (value !== undefined && value !== '') query.set(key, String(value));
  }
  const suffix = query.size ? `?${query}` : '';
  return unwrap(
    await apiFetch<CatalogProgram[] | { items: CatalogProgram[] }>(
      `/catalog/programs${suffix}`,
      { signal },
    ),
  );
}

// ── Écritures ───────────────────────────────────────────────────────────────

export interface InstitutionInput {
  nameFr: string;
  nameEn?: string;
  countryId: string;
  locationFr?: string;
  overviewFr?: string;
  studyLevels?: string[];
  tuitionLabelFr?: string;
  languageRequirementsFr?: string;
  intakePeriods?: string[];
  isPartner?: boolean;
}

export interface ProgramInput {
  institutionId: string;
  countryId: string;
  fieldId: string;
  nameFr: string;
  nameEn?: string;
  levelFr?: string;
  durationFr?: string;
  tuitionFr?: string;
  languageFr?: string;
  requirementsFr?: string[];
  /**
   * Colonnes de scoring, débloquées côté backend par #271. Elles alimentent la
   * probabilité d'admission ; une valeur absente vaut facteur neutre 0,5 et
   * marque le match `isEstimate`. `null` vide explicitement la colonne.
   */
  minGpaRequired?: number | null;
  tuitionMinEur?: number | null;
  applicationDeadline?: string | null;
  teachingLanguages?: string[] | null;
}

export function createInstitution(input: InstitutionInput) {
  return apiFetch<CatalogInstitution>('/admin/catalog/institutions', {
    method: 'POST',
    body: input,
  });
}

export function updateInstitution(id: string, input: Partial<InstitutionInput>) {
  return apiFetch<CatalogInstitution>(`/admin/catalog/institutions/${id}`, {
    method: 'PATCH',
    body: input,
  });
}

export function deleteInstitution(id: string) {
  return apiFetch<{ id: string; deleted: boolean }>(
    `/admin/catalog/institutions/${id}`,
    { method: 'DELETE' },
  );
}

export function createProgram(input: ProgramInput) {
  return apiFetch<CatalogProgram>('/admin/catalog/programs', {
    method: 'POST',
    body: input,
  });
}

export function updateProgram(id: string, input: Partial<ProgramInput>) {
  return apiFetch<CatalogProgram>(`/admin/catalog/programs/${id}`, {
    method: 'PATCH',
    body: input,
  });
}

export function deleteProgram(id: string) {
  return apiFetch<{ id: string; deleted: boolean }>(
    `/admin/catalog/programs/${id}`,
    { method: 'DELETE' },
  );
}
