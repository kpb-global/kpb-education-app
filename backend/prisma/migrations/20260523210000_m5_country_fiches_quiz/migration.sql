-- M5 country fiches + eligibility quizzes
ALTER TABLE "Country" ADD COLUMN IF NOT EXISTS "code" TEXT;
ALTER TABLE "Country" ADD COLUMN IF NOT EXISTS "flagEmoji" TEXT NOT NULL DEFAULT '🌍';
ALTER TABLE "Country" ADD COLUMN IF NOT EXISTS "taglineFr" TEXT NOT NULL DEFAULT '';
ALTER TABLE "Country" ADD COLUMN IF NOT EXISTS "taglineEn" TEXT NOT NULL DEFAULT '';
ALTER TABLE "Country" ADD COLUMN IF NOT EXISTS "nextIntakeLabelFr" TEXT NOT NULL DEFAULT '';
ALTER TABLE "Country" ADD COLUMN IF NOT EXISTS "nextIntakeLabelEn" TEXT NOT NULL DEFAULT '';
ALTER TABLE "Country" ADD COLUMN IF NOT EXISTS "mainLanguageFr" TEXT NOT NULL DEFAULT '';
ALTER TABLE "Country" ADD COLUMN IF NOT EXISTS "mainLanguageEn" TEXT NOT NULL DEFAULT '';
ALTER TABLE "Country" ADD COLUMN IF NOT EXISTS "marketingDescriptionFr" TEXT NOT NULL DEFAULT '';
ALTER TABLE "Country" ADD COLUMN IF NOT EXISTS "marketingDescriptionEn" TEXT NOT NULL DEFAULT '';
ALTER TABLE "Country" ADD COLUMN IF NOT EXISTS "whyStudyBulletsFr" TEXT[] DEFAULT ARRAY[]::TEXT[];
ALTER TABLE "Country" ADD COLUMN IF NOT EXISTS "whyStudyBulletsEn" TEXT[] DEFAULT ARRAY[]::TEXT[];
ALTER TABLE "Country" ADD COLUMN IF NOT EXISTS "howItWorksFr" TEXT NOT NULL DEFAULT '';
ALTER TABLE "Country" ADD COLUMN IF NOT EXISTS "howItWorksEn" TEXT NOT NULL DEFAULT '';
ALTER TABLE "Country" ADD COLUMN IF NOT EXISTS "costsOverviewFr" TEXT NOT NULL DEFAULT '';
ALTER TABLE "Country" ADD COLUMN IF NOT EXISTS "costsOverviewEn" TEXT NOT NULL DEFAULT '';
ALTER TABLE "Country" ADD COLUMN IF NOT EXISTS "languageSectionFr" TEXT NOT NULL DEFAULT '';
ALTER TABLE "Country" ADD COLUMN IF NOT EXISTS "languageSectionEn" TEXT NOT NULL DEFAULT '';
ALTER TABLE "Country" ADD COLUMN IF NOT EXISTS "partnerSchoolsFr" TEXT NOT NULL DEFAULT '';
ALTER TABLE "Country" ADD COLUMN IF NOT EXISTS "partnerSchoolsEn" TEXT NOT NULL DEFAULT '';
ALTER TABLE "Country" ADD COLUMN IF NOT EXISTS "scholarshipsSectionFr" TEXT NOT NULL DEFAULT '';
ALTER TABLE "Country" ADD COLUMN IF NOT EXISTS "scholarshipsSectionEn" TEXT NOT NULL DEFAULT '';
ALTER TABLE "Country" ADD COLUMN IF NOT EXISTS "whatsAppPrefillFr" TEXT NOT NULL DEFAULT '';
ALTER TABLE "Country" ADD COLUMN IF NOT EXISTS "whatsAppPrefillEn" TEXT NOT NULL DEFAULT '';
ALTER TABLE "Country" ADD COLUMN IF NOT EXISTS "mvpNoteFr" TEXT NOT NULL DEFAULT '';
ALTER TABLE "Country" ADD COLUMN IF NOT EXISTS "mvpNoteEn" TEXT NOT NULL DEFAULT '';
ALTER TABLE "Country" ADD COLUMN IF NOT EXISTS "displayOrder" INTEGER NOT NULL DEFAULT 0;
ALTER TABLE "Country" ADD COLUMN IF NOT EXISTS "isActive" BOOLEAN NOT NULL DEFAULT true;

-- Resolve legacy duplicate slug ids before ISO codes
UPDATE "Country" SET "code" = 'LEGACY_FRANCE', "isActive" = false WHERE "id" = 'france';
UPDATE "Country" SET "code" = 'LEGACY_CANADA', "isActive" = false WHERE "id" = 'canada';
UPDATE "Country" SET "code" = 'LEGACY_UK', "isActive" = false WHERE "id" = 'uk';
UPDATE "Country" SET "code" = 'LEGACY_GERMANY', "isActive" = false WHERE "id" = 'germany';
UPDATE "Country" SET "code" = 'LEGACY_SPAIN', "isActive" = false WHERE "id" = 'spain';
UPDATE "Country" SET "code" = UPPER("id") WHERE "code" IS NULL OR "code" = '';

ALTER TABLE "Country" ALTER COLUMN "code" SET NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS "Country_code_key" ON "Country"("code");
CREATE INDEX IF NOT EXISTS "Country_isActive_displayOrder_idx" ON "Country"("isActive", "displayOrder");

CREATE TABLE IF NOT EXISTS "CountryEligibilityQuiz" (
    "id" TEXT NOT NULL,
    "countryId" TEXT NOT NULL,
    "questions" JSONB NOT NULL,
    "verdicts" JSONB NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "CountryEligibilityQuiz_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX IF NOT EXISTS "CountryEligibilityQuiz_countryId_key" ON "CountryEligibilityQuiz"("countryId");

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'CountryEligibilityQuiz_countryId_fkey'
  ) THEN
    ALTER TABLE "CountryEligibilityQuiz"
      ADD CONSTRAINT "CountryEligibilityQuiz_countryId_fkey"
      FOREIGN KEY ("countryId") REFERENCES "Country"("id") ON DELETE CASCADE ON UPDATE CASCADE;
  END IF;
END $$;
