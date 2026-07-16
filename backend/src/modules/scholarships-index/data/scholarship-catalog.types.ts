export const SCHOLARSHIP_STUDY_LEVELS = [
  'secondary',
  'bachelor',
  'master',
] as const;

export type ScholarshipStudyLevel =
  (typeof SCHOLARSHIP_STUDY_LEVELS)[number];

export const REQUIRED_OFFICIAL_SOURCE_KINDS = [
  'overview',
  'eligibility',
  'benefits',
  'application',
  'cycle',
] as const;

export type ScholarshipOfficialSourceKind =
  (typeof REQUIRED_OFFICIAL_SOURCE_KINDS)[number];

export type ScholarshipFundingType =
  | 'fully_funded'
  | 'partially_funded'
  | 'unknown';

export type ScholarshipApplicationRequirement =
  | 'automatic'
  | 'separate_application';

export type ScholarshipCycleStatus =
  | 'forecast'
  | 'open'
  | 'closed'
  | 'suspended';

export type ScholarshipDateConfidence = 'estimated' | 'confirmed';

export interface ScholarshipOfficialSource {
  kind: ScholarshipOfficialSourceKind;
  url: string;
  isOfficial: true;
  checkedAt: string;
  label: string;
}

export interface ScholarshipCatalogApplicationStep {
  stepNumber: number;
  titleFr: string;
  titleEn: string;
  descriptionFr: string;
  descriptionEn: string;
  estimatedDurationDays?: number;
}

export interface ScholarshipCatalogCycle {
  academicYear: string;
  status: ScholarshipCycleStatus;
  dateConfidence: ScholarshipDateConfidence;
  estimatedOpenAt?: string;
  estimatedCloseAt?: string;
  opensAt?: string;
  closesAt?: string;
  sourceUrl: string;
}

/**
 * Exact write shape supported by the current legacy Prisma Scholarship model.
 * Relations that already exist in the schema (steps and one annual cycle) are
 * kept beside the row and are created in the same transaction by the importer.
 */
export interface LegacyScholarshipCatalogPayload {
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
  fundingType: ScholarshipFundingType;
  applicationRequirement: ScholarshipApplicationRequirement;
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
  applicationUrl: string;
  sourceUrl: string;
  tags: string[];
}

export interface VerifiedScholarshipCatalogRecord {
  catalogId: string;
  levels: ScholarshipStudyLevel[];
  scholarship: LegacyScholarshipCatalogPayload;
  applicationSteps: ScholarshipCatalogApplicationStep[];
  cycle: ScholarshipCatalogCycle;
  officialSources: ScholarshipOfficialSource[];
  verifiedAt: string;
  verifiedBy: string;
}

export type ScholarshipBacklogReason =
  | 'legacy_record_requires_official_verification'
  | 'legacy_record_incomplete';

export interface ScholarshipCatalogBacklogItem {
  legacyId: string;
  intendedLevels: ScholarshipStudyLevel[];
  reasons: ScholarshipBacklogReason[];
}

export interface ScholarshipCatalogVolumeTargets {
  uniqueRecords: number;
  secondary: number;
  bachelor: number;
  master: number;
}

export interface VersionedScholarshipCatalog {
  schemaVersion: 1;
  catalogVersion: string;
  volumeTargets: ScholarshipCatalogVolumeTargets;
  records: VerifiedScholarshipCatalogRecord[];
  backlog: ScholarshipCatalogBacklogItem[];
}
