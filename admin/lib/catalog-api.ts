'use client';

// Back-office catalogue client (Chantier B).
//
// Talks to the admin-only `/admin/catalog/*` endpoints, which return raw,
// full-fidelity rows (every writable column, incl. inactive items) — unlike the
// public `/catalog/*` reads that are mapped/filtered for the mobile app.

import { apiFetch } from './api-client';

// Canonical program degree labels — mirror of the Flutter `ProgramLevel`
// referential and the backend `normalizeDegreeLevel` outputs (Chantier A).
export const PROGRAM_LEVELS = [
  'Bachelor',
  'BBA',
  'Master',
  'MBA / DBA',
  'Doctorat',
  'Bac+2',
] as const;

export interface ProgramRow {
  id: string;
  institutionId: string;
  countryId: string;
  fieldId: string;
  nameFr: string;
  nameEn: string;
  levelFr: string;
  levelEn: string;
  durationFr: string;
  durationEn: string;
  tuitionFr: string;
  tuitionEn: string;
  languageFr: string;
  languageEn: string;
  requirementsFr: string[];
  requirementsEn: string[];
}

export interface InstitutionRow {
  id: string;
  nameFr: string;
  nameEn: string;
  countryId: string;
  locationFr: string;
  locationEn: string;
  overviewFr: string;
  overviewEn: string;
  studyLevels: string[];
  tuitionLabelFr: string;
  tuitionLabelEn: string;
  languageRequirementsFr: string;
  languageRequirementsEn: string;
  intakePeriods: string[];
  programIds: string[];
  isPartner: boolean;
}

export interface ScholarshipRow {
  id: string;
  nameFr: string;
  nameEn: string;
  countryId: string;
  countryNameFr: string;
  countryNameEn: string;
  levelEligibleFr: string;
  levelEligibleEn: string;
  typeOfFundingFr: string;
  typeOfFundingEn: string;
  deadlineLabelFr: string;
  deadlineLabelEn: string;
  descriptionFr: string;
  descriptionEn: string;
  advantagesFr: string[];
  advantagesEn: string[];
  eligibilityFr: string[];
  eligibilityEn: string[];
  keyRequirementsFr: string[];
  keyRequirementsEn: string[];
  relatedFieldIds: string[];
  baseMatch: number;
  applicationUrl: string | null;
  sourceUrl: string | null;
  isActive: boolean;
  tags: string[];
  sourceKey: string | null;
}

export interface CountryOption {
  id: string;
  code: string;
  flagEmoji: string;
  nameFr: string;
  nameEn: string;
  isActive: boolean;
}

export interface FieldOption {
  id: string;
  nameFr: string;
  nameEn: string;
}

interface ListResponse<T> {
  items: T[];
  total: number;
}

interface ProgramListResponse extends ListResponse<ProgramRow> {
  limit: number;
  offset: number;
}

export interface ProgramQuery {
  q?: string;
  countryId?: string;
  fieldId?: string;
  institutionId?: string;
  limit?: number;
  offset?: number;
}

function queryString(params: Record<string, string | number | undefined>) {
  const search = new URLSearchParams();
  Object.entries(params).forEach(([key, value]) => {
    if (value !== undefined && value !== '') {
      search.set(key, String(value));
    }
  });
  const qs = search.toString();
  return qs ? `?${qs}` : '';
}

export function fetchPrograms(query: ProgramQuery = {}) {
  return apiFetch<ProgramListResponse>(
    `/admin/catalog/programs${queryString({ ...query })}`,
  );
}

export function fetchInstitutions(countryId?: string) {
  return apiFetch<ListResponse<InstitutionRow>>(
    `/admin/catalog/institutions${queryString({ countryId })}`,
  );
}

export function fetchScholarships() {
  return apiFetch<ListResponse<ScholarshipRow>>('/admin/catalog/scholarships');
}

export function fetchCountries() {
  return apiFetch<ListResponse<CountryOption>>('/admin/catalog/countries');
}

export function fetchFields() {
  return apiFetch<ListResponse<FieldOption>>('/admin/catalog/fields');
}

/** Textarea (one item per line) → trimmed, non-empty string array. */
export function linesToArray(value: string): string[] {
  return value
    .split('\n')
    .map((line) => line.trim())
    .filter(Boolean);
}

/** String array → textarea body (one item per line). */
export function arrayToLines(value?: string[] | null): string {
  return (value ?? []).join('\n');
}
