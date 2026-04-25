-- Visa appointment availability (Phase 1 — Track A2).
-- One row per consulate; cron upserts by consulateCode.

CREATE TYPE "VisaAvailabilityStatus" AS ENUM ('available', 'full', 'unknown', 'error');

CREATE TABLE "VisaAvailabilitySnapshot" (
  "id"              TEXT PRIMARY KEY,
  "consulateCode"   TEXT NOT NULL UNIQUE,
  "countryCode"     TEXT NOT NULL,
  "city"            TEXT NOT NULL,
  "nextAvailableAt" TIMESTAMP(3),
  "soonestSlot"     TEXT,
  "lastCheckedAt"   TIMESTAMP(3),
  "status"          "VisaAvailabilityStatus" NOT NULL DEFAULT 'unknown',
  "errorMessage"    TEXT,
  "createdAt"       TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt"       TIMESTAMP(3) NOT NULL
);

CREATE INDEX "VisaAvailabilitySnapshot_countryCode_idx" ON "VisaAvailabilitySnapshot"("countryCode");
CREATE INDEX "VisaAvailabilitySnapshot_status_idx"      ON "VisaAvailabilitySnapshot"("status");
