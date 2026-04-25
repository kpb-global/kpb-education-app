-- CreateTable
CREATE TABLE "Field" (
    "id" TEXT NOT NULL,
    "nameFr" TEXT NOT NULL,
    "nameEn" TEXT NOT NULL,
    "descriptionFr" TEXT NOT NULL,
    "descriptionEn" TEXT NOT NULL,
    "subjectsFr" TEXT[],
    "subjectsEn" TEXT[],
    "careersFr" TEXT[],
    "careersEn" TEXT[],
    "dailyLifeFr" TEXT[],
    "dailyLifeEn" TEXT[],
    "skillsFr" TEXT[],
    "skillsEn" TEXT[],
    "personalityTraitsFr" TEXT[],
    "personalityTraitsEn" TEXT[],
    "relatedCountryIds" TEXT[],
    "relatedScholarshipIds" TEXT[],
    "accentColorHex" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Field_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Country" (
    "id" TEXT NOT NULL,
    "nameFr" TEXT NOT NULL,
    "nameEn" TEXT NOT NULL,
    "whyStudyFr" TEXT NOT NULL,
    "whyStudyEn" TEXT NOT NULL,
    "tuitionRangeFr" TEXT NOT NULL,
    "tuitionRangeEn" TEXT NOT NULL,
    "livingCostRangeFr" TEXT NOT NULL,
    "livingCostRangeEn" TEXT NOT NULL,
    "visaOverviewFr" TEXT NOT NULL,
    "visaOverviewEn" TEXT NOT NULL,
    "admissionDifficultyFr" TEXT NOT NULL,
    "admissionDifficultyEn" TEXT NOT NULL,
    "popularFieldIds" TEXT[],
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Country_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Institution" (
    "id" TEXT NOT NULL,
    "nameFr" TEXT NOT NULL,
    "nameEn" TEXT NOT NULL,
    "countryId" TEXT NOT NULL,
    "locationFr" TEXT NOT NULL,
    "locationEn" TEXT NOT NULL,
    "overviewFr" TEXT NOT NULL,
    "overviewEn" TEXT NOT NULL,
    "studyLevels" TEXT[],
    "tuitionLabelFr" TEXT NOT NULL,
    "tuitionLabelEn" TEXT NOT NULL,
    "languageRequirementsFr" TEXT NOT NULL,
    "languageRequirementsEn" TEXT NOT NULL,
    "intakePeriods" TEXT[],
    "programIds" TEXT[],
    "isPartner" BOOLEAN NOT NULL DEFAULT false,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Institution_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Program" (
    "id" TEXT NOT NULL,
    "institutionId" TEXT NOT NULL,
    "countryId" TEXT NOT NULL,
    "fieldId" TEXT NOT NULL,
    "nameFr" TEXT NOT NULL,
    "nameEn" TEXT NOT NULL,
    "levelFr" TEXT NOT NULL,
    "levelEn" TEXT NOT NULL,
    "durationFr" TEXT NOT NULL,
    "durationEn" TEXT NOT NULL,
    "tuitionFr" TEXT NOT NULL,
    "tuitionEn" TEXT NOT NULL,
    "languageFr" TEXT NOT NULL,
    "languageEn" TEXT NOT NULL,
    "requirementsFr" TEXT[],
    "requirementsEn" TEXT[],
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Program_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Scholarship" (
    "id" TEXT NOT NULL,
    "nameFr" TEXT NOT NULL,
    "nameEn" TEXT NOT NULL,
    "countryId" TEXT NOT NULL,
    "levelEligibleFr" TEXT NOT NULL,
    "levelEligibleEn" TEXT NOT NULL,
    "typeOfFundingFr" TEXT NOT NULL,
    "typeOfFundingEn" TEXT NOT NULL,
    "deadlineLabelFr" TEXT NOT NULL,
    "deadlineLabelEn" TEXT NOT NULL,
    "keyRequirementsFr" TEXT[],
    "keyRequirementsEn" TEXT[],
    "relatedFieldIds" TEXT[],
    "baseMatch" INTEGER NOT NULL DEFAULT 30,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Scholarship_pkey" PRIMARY KEY ("id")
);
