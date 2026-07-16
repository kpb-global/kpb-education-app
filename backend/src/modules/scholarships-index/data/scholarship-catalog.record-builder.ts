import type {
  ScholarshipApplicationRequirement,
  ScholarshipCatalogCycle,
  ScholarshipFundingType,
  ScholarshipOfficialSourceKind,
  ScholarshipStudyLevel,
  VerifiedScholarshipCatalogRecord,
} from './scholarship-catalog.types';

export type BilingualText = readonly [fr: string, en: string];

export interface ScholarshipSourceBundle {
  overview: string;
  eligibility: string;
  benefits: string;
  application: string;
  cycle: string;
}

export interface ScholarshipRecordInput {
  id: string;
  levels: ScholarshipStudyLevel[];
  name: BilingualText;
  country: readonly [id: string, nameFr: string, nameEn: string];
  levelLabel: BilingualText;
  fundingLabel: BilingualText;
  fundingType: ScholarshipFundingType;
  applicationRequirement?: ScholarshipApplicationRequirement;
  deadlineLabel: BilingualText;
  description: BilingualText;
  advantages: BilingualText[];
  eligibility: BilingualText[];
  requirements: BilingualText[];
  steps: Array<
    readonly [
      titleFr: string,
      titleEn: string,
      descriptionFr: string,
      descriptionEn: string,
    ]
  >;
  cycle: ScholarshipCatalogCycle;
  sources: ScholarshipSourceBundle;
  tags: string[];
  relatedFieldIds?: string[];
  baseMatch?: number;
}

const CHECKED_AT = '2026-07-16T00:00:00.000Z';
const VERIFIED_BY = 'KPB Education official-source review';

const SOURCE_KINDS: ScholarshipOfficialSourceKind[] = [
  'overview',
  'eligibility',
  'benefits',
  'application',
  'cycle',
];

function splitBilingual(lines: BilingualText[]): [string[], string[]] {
  return [
    lines.map(([fr]) => fr),
    lines.map(([, en]) => en),
  ];
}

/**
 * Builds the strict legacy-compatible payload used by the catalog importer.
 * This helper only removes repetitive mapping code: all editorial facts,
 * dates and source URLs remain explicit in the versioned record files.
 */
export function buildVerifiedScholarshipRecord(
  input: ScholarshipRecordInput,
): VerifiedScholarshipCatalogRecord {
  const [advantagesFr, advantagesEn] = splitBilingual(input.advantages);
  const [eligibilityFr, eligibilityEn] = splitBilingual(input.eligibility);
  const [keyRequirementsFr, keyRequirementsEn] = splitBilingual(
    input.requirements,
  );

  return {
    catalogId: input.id,
    levels: [...input.levels],
    scholarship: {
      id: input.id,
      nameFr: input.name[0],
      nameEn: input.name[1],
      countryId: input.country[0],
      countryNameFr: input.country[1],
      countryNameEn: input.country[2],
      levelEligibleFr: input.levelLabel[0],
      levelEligibleEn: input.levelLabel[1],
      typeOfFundingFr: input.fundingLabel[0],
      typeOfFundingEn: input.fundingLabel[1],
      fundingType: input.fundingType,
      applicationRequirement:
        input.applicationRequirement ?? 'separate_application',
      deadlineLabelFr: input.deadlineLabel[0],
      deadlineLabelEn: input.deadlineLabel[1],
      descriptionFr: input.description[0],
      descriptionEn: input.description[1],
      advantagesFr,
      advantagesEn,
      eligibilityFr,
      eligibilityEn,
      keyRequirementsFr,
      keyRequirementsEn,
      relatedFieldIds: input.relatedFieldIds ?? [],
      baseMatch: input.baseMatch ?? 78,
      applicationUrl: input.sources.application,
      sourceUrl: input.sources.overview,
      tags: [...input.tags],
    },
    applicationSteps: input.steps.map(
      ([titleFr, titleEn, descriptionFr, descriptionEn], index) => ({
        stepNumber: index + 1,
        titleFr,
        titleEn,
        descriptionFr,
        descriptionEn,
      }),
    ),
    cycle: { ...input.cycle },
    officialSources: SOURCE_KINDS.map((kind) => ({
      kind,
      url: input.sources[kind],
      isOfficial: true,
      checkedAt: CHECKED_AT,
      label: `${input.name[1]} — official ${kind} source`,
    })),
    verifiedAt: CHECKED_AT,
    verifiedBy: VERIFIED_BY,
  };
}
