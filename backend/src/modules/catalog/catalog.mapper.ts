import type {
  Country,
  Field,
  Institution,
  Program,
  Scholarship,
} from '@prisma/client';

type Localized = { fr: string; en: string };

function localized(fr?: string | null, en?: string | null): Localized {
  return { fr: fr ?? '', en: en ?? fr ?? '' };
}

function localizedList(fr?: string[] | null, en?: string[] | null): Localized[] {
  const frList = fr ?? [];
  const enList = en ?? [];
  const len = Math.max(frList.length, enList.length);
  return Array.from({ length: len }, (_, i) => ({
    fr: frList[i] ?? '',
    en: enList[i] ?? '',
  }));
}

export function mapField(row: Field) {
  return {
    id: row.id,
    name: localized(row.nameFr, row.nameEn),
    description: localized(row.descriptionFr, row.descriptionEn),
    subjects: localizedList(row.subjectsFr, row.subjectsEn),
    careers: localizedList(row.careersFr, row.careersEn),
    dailyLife: localizedList(row.dailyLifeFr, row.dailyLifeEn),
    skills: localizedList(row.skillsFr, row.skillsEn),
    personalityTraits: localizedList(
      row.personalityTraitsFr,
      row.personalityTraitsEn,
    ),
    relatedCountryIds: row.relatedCountryIds,
    relatedScholarshipIds: row.relatedScholarshipIds,
  };
}

export function mapCountry(row: Country) {
  return {
    id: row.id,
    code: row.code,
    flagEmoji: row.flagEmoji,
    name: localized(row.nameFr, row.nameEn),
    tagline: localized(row.taglineFr, row.taglineEn),
    nextIntakeLabel: localized(row.nextIntakeLabelFr, row.nextIntakeLabelEn),
    mainLanguage: localized(row.mainLanguageFr, row.mainLanguageEn),
    whyStudy: localized(row.whyStudyFr, row.whyStudyEn),
    marketingDescription: localized(
      row.marketingDescriptionFr,
      row.marketingDescriptionEn,
    ),
    whyStudyBullets: {
      fr: row.whyStudyBulletsFr,
      en: row.whyStudyBulletsEn,
    },
    howItWorks: localized(row.howItWorksFr, row.howItWorksEn),
    costsOverview: localized(row.costsOverviewFr, row.costsOverviewEn),
    languageSection: localized(row.languageSectionFr, row.languageSectionEn),
    partnerSchools: localized(row.partnerSchoolsFr, row.partnerSchoolsEn),
    scholarshipsSection: localized(
      row.scholarshipsSectionFr,
      row.scholarshipsSectionEn,
    ),
    whatsAppPrefill: localized(row.whatsAppPrefillFr, row.whatsAppPrefillEn),
    mvpNote: localized(row.mvpNoteFr, row.mvpNoteEn),
    tuitionRange: localized(row.tuitionRangeFr, row.tuitionRangeEn),
    livingCostRange: localized(row.livingCostRangeFr, row.livingCostRangeEn),
    visaOverview: localized(row.visaOverviewFr, row.visaOverviewEn),
    admissionDifficulty: localized(
      row.admissionDifficultyFr,
      row.admissionDifficultyEn,
    ),
    popularFieldIds: row.popularFieldIds,
    displayOrder: row.displayOrder,
    isActive: row.isActive,
    nameFr: row.nameFr,
    nameEn: row.nameEn,
    taglineFr: row.taglineFr,
    taglineEn: row.taglineEn,
    nextIntakeLabelFr: row.nextIntakeLabelFr,
    nextIntakeLabelEn: row.nextIntakeLabelEn,
    whyStudyFr: row.whyStudyFr,
    whyStudyEn: row.whyStudyEn,
    tuitionRangeFr: row.tuitionRangeFr,
    tuitionRangeEn: row.tuitionRangeEn,
    livingCostRangeFr: row.livingCostRangeFr,
    livingCostRangeEn: row.livingCostRangeEn,
    visaOverviewFr: row.visaOverviewFr,
    visaOverviewEn: row.visaOverviewEn,
    admissionDifficultyFr: row.admissionDifficultyFr,
    admissionDifficultyEn: row.admissionDifficultyEn,
  };
}

export function mapInstitution(row: Institution) {
  return {
    id: row.id,
    name: localized(row.nameFr, row.nameEn),
    countryId: row.countryId,
    location: localized(row.locationFr, row.locationEn),
    overview: localized(row.overviewFr, row.overviewEn),
    studyLevels: row.studyLevels,
    tuitionLabel: localized(row.tuitionLabelFr, row.tuitionLabelEn),
    languageRequirements: localized(
      row.languageRequirementsFr,
      row.languageRequirementsEn,
    ),
    intakePeriods: row.intakePeriods,
    programIds: row.programIds,
    isPartner: row.isPartner,
  };
}

export function mapProgram(row: Program) {
  return {
    id: row.id,
    institutionId: row.institutionId,
    countryId: row.countryId,
    fieldId: row.fieldId,
    name: localized(row.nameFr, row.nameEn),
    level: localized(row.levelFr, row.levelEn),
    duration: localized(row.durationFr, row.durationEn),
    tuition: localized(row.tuitionFr, row.tuitionEn),
    language: localized(row.languageFr, row.languageEn),
    requirements: localizedList(row.requirementsFr, row.requirementsEn),
    // Flat keys kept for backward compatibility with older clients.
    nameFr: row.nameFr,
    nameEn: row.nameEn,
    levelFr: row.levelFr,
    levelEn: row.levelEn,
    durationFr: row.durationFr,
    durationEn: row.durationEn,
    tuitionFr: row.tuitionFr,
    tuitionEn: row.tuitionEn,
    languageFr: row.languageFr,
    languageEn: row.languageEn,
    requirementsFr: row.requirementsFr,
    requirementsEn: row.requirementsEn,
  };
}

export function mapScholarship(row: Scholarship) {
  return {
    id: row.id,
    name: localized(row.nameFr, row.nameEn),
    countryId: row.countryId,
    levelEligible: localized(row.levelEligibleFr, row.levelEligibleEn),
    typeOfFunding: localized(row.typeOfFundingFr, row.typeOfFundingEn),
    deadlineLabel: localized(row.deadlineLabelFr, row.deadlineLabelEn),
    keyRequirements: localizedList(
      row.keyRequirementsFr,
      row.keyRequirementsEn,
    ),
    eligibility: localizedList(row.eligibilityFr, row.eligibilityEn),
    relatedFieldIds: row.relatedFieldIds,
    baseMatch: row.baseMatch,
  };
}
