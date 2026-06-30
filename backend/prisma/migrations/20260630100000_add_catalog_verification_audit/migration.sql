-- KPB-47: operational verification trail behind catalogue trust badges.

ALTER TABLE "Country"
  ADD COLUMN "verificationSourceUrl" TEXT,
  ADD COLUMN "lastVerifiedAt" TIMESTAMP(3),
  ADD COLUMN "verifiedById" TEXT,
  ADD COLUMN "verifiedByName" TEXT;

ALTER TABLE "Institution"
  ADD COLUMN "verificationSourceUrl" TEXT,
  ADD COLUMN "lastVerifiedAt" TIMESTAMP(3),
  ADD COLUMN "verifiedById" TEXT,
  ADD COLUMN "verifiedByName" TEXT;

ALTER TABLE "Program"
  ADD COLUMN "verificationSourceUrl" TEXT,
  ADD COLUMN "lastVerifiedAt" TIMESTAMP(3),
  ADD COLUMN "verifiedById" TEXT,
  ADD COLUMN "verifiedByName" TEXT;

ALTER TABLE "Scholarship"
  ADD COLUMN "verificationSourceUrl" TEXT,
  ADD COLUMN "verifiedById" TEXT,
  ADD COLUMN "verifiedByName" TEXT;

CREATE INDEX "Country_lastVerifiedAt_idx" ON "Country"("lastVerifiedAt");
CREATE INDEX "Institution_lastVerifiedAt_idx" ON "Institution"("lastVerifiedAt");
CREATE INDEX "Program_lastVerifiedAt_idx" ON "Program"("lastVerifiedAt");
CREATE INDEX "Scholarship_lastVerifiedAt_idx" ON "Scholarship"("lastVerifiedAt");
