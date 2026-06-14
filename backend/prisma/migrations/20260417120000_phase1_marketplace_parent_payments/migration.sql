-- Phase 1 — Counsellor marketplace (B), Parent mode (C1), Payment abstraction (C3),
-- plus live-index fields on Scholarship (A1).

-- ── Enums ───────────────────────────────────────────────────────────────────
CREATE TYPE "CounsellorKycStatus" AS ENUM ('pending', 'under_review', 'approved', 'rejected', 'suspended');
CREATE TYPE "ParentLinkStatus"    AS ENUM ('pending', 'active', 'revoked');
CREATE TYPE "PaymentProvider"     AS ENUM ('cinetpay', 'paydunya', 'stripe', 'manual');
CREATE TYPE "PaymentStatus"       AS ENUM ('created', 'pending', 'paid', 'failed', 'refunded', 'cancelled');

-- ── Scholarship live-index fields ───────────────────────────────────────────
ALTER TABLE "Scholarship"
  ADD COLUMN "sourceKey"      TEXT,
  ADD COLUMN "sourceUrl"      TEXT,
  ADD COLUMN "applicationUrl" TEXT,
  ADD COLUMN "deadlineAt"     TIMESTAMP(3),
  ADD COLUMN "lastVerifiedAt" TIMESTAMP(3),
  ADD COLUMN "isActive"       BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN "tags"           TEXT[]  NOT NULL DEFAULT ARRAY[]::TEXT[];

CREATE UNIQUE INDEX "Scholarship_sourceKey_key" ON "Scholarship"("sourceKey");
CREATE INDEX "Scholarship_deadlineAt_idx"       ON "Scholarship"("deadlineAt");
CREATE INDEX "Scholarship_isActive_idx"         ON "Scholarship"("isActive");

-- ── Counsellor marketplace ──────────────────────────────────────────────────
CREATE TABLE "Counsellor" (
  "id"                 TEXT PRIMARY KEY,
  "fullName"           TEXT NOT NULL,
  "email"              TEXT NOT NULL UNIQUE,
  "phone"              TEXT NOT NULL,
  "whatsApp"           TEXT,
  "countryOfResidence" TEXT NOT NULL,
  "specialties"        TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
  "languagesSpoken"    TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
  "bioFr"              TEXT NOT NULL,
  "bioEn"              TEXT NOT NULL,
  "yearsExperience"    INTEGER NOT NULL DEFAULT 0,
  "hourlyRateXOF"      INTEGER NOT NULL DEFAULT 0,
  "commissionBps"      INTEGER NOT NULL DEFAULT 1500,
  "kycStatus"          "CounsellorKycStatus" NOT NULL DEFAULT 'pending',
  "kycNotes"           TEXT,
  "kycVerifiedAt"      TIMESTAMP(3),
  "isActive"           BOOLEAN NOT NULL DEFAULT false,
  "avgRating"          DOUBLE PRECISION NOT NULL DEFAULT 0,
  "reviewCount"        INTEGER NOT NULL DEFAULT 0,
  "createdAt"          TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt"          TIMESTAMP(3) NOT NULL
);

CREATE INDEX "Counsellor_kycStatus_idx"          ON "Counsellor"("kycStatus");
CREATE INDEX "Counsellor_isActive_idx"           ON "Counsellor"("isActive");
CREATE INDEX "Counsellor_countryOfResidence_idx" ON "Counsellor"("countryOfResidence");

CREATE TABLE "CounsellorReview" (
  "id"             TEXT PRIMARY KEY,
  "counsellorId"   TEXT NOT NULL,
  "reviewerName"   TEXT NOT NULL,
  "reviewerUserId" TEXT,
  "caseId"         TEXT,
  "rating"         INTEGER NOT NULL,
  "body"           TEXT NOT NULL,
  "isPublished"    BOOLEAN NOT NULL DEFAULT false,
  "createdAt"      TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "CounsellorReview_counsellorId_fkey"
    FOREIGN KEY ("counsellorId") REFERENCES "Counsellor"("id") ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE INDEX "CounsellorReview_counsellorId_idx" ON "CounsellorReview"("counsellorId");
CREATE INDEX "CounsellorReview_isPublished_idx"  ON "CounsellorReview"("isPublished");

-- ── Case: link to counsellor + parent visibility ────────────────────────────
ALTER TABLE "Case"
  ADD COLUMN "counsellorId"  TEXT,
  ADD COLUMN "parentCanView" BOOLEAN NOT NULL DEFAULT false;

ALTER TABLE "Case"
  ADD CONSTRAINT "Case_counsellorId_fkey"
    FOREIGN KEY ("counsellorId") REFERENCES "Counsellor"("id") ON DELETE SET NULL ON UPDATE CASCADE;

CREATE INDEX "Case_counsellorId_idx" ON "Case"("counsellorId");

-- ── Parent ↔ child link ─────────────────────────────────────────────────────
CREATE TABLE "ParentChildLink" (
  "id"         TEXT PRIMARY KEY,
  "parentId"   TEXT NOT NULL,
  "childId"    TEXT, -- null while the invite is pending
  "inviteCode" TEXT NOT NULL UNIQUE,
  "status"     "ParentLinkStatus" NOT NULL DEFAULT 'pending',
  "acceptedAt" TIMESTAMP(3),
  "createdAt"  TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt"  TIMESTAMP(3) NOT NULL,
  CONSTRAINT "ParentChildLink_parentId_fkey"
    FOREIGN KEY ("parentId") REFERENCES "UserProfile"("id") ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "ParentChildLink_childId_fkey"
    FOREIGN KEY ("childId")  REFERENCES "UserProfile"("id") ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE UNIQUE INDEX "ParentChildLink_parentId_childId_key" ON "ParentChildLink"("parentId", "childId");
CREATE INDEX "ParentChildLink_childId_idx" ON "ParentChildLink"("childId");
CREATE INDEX "ParentChildLink_status_idx"  ON "ParentChildLink"("status");

-- ── Payment intents ─────────────────────────────────────────────────────────
CREATE TABLE "PaymentIntent" (
  "id"            TEXT PRIMARY KEY,
  "userId"        TEXT NOT NULL,
  "caseId"        TEXT,
  "counsellorId"  TEXT,
  "amountMinor"   INTEGER NOT NULL,
  "currency"      TEXT NOT NULL DEFAULT 'XOF',
  "provider"      "PaymentProvider" NOT NULL,
  "providerRef"   TEXT UNIQUE,
  "checkoutUrl"   TEXT,
  "status"        "PaymentStatus" NOT NULL DEFAULT 'created',
  "description"   TEXT,
  "lastWebhookAt" TIMESTAMP(3),
  "paidAt"        TIMESTAMP(3),
  "failureReason" TEXT,
  "createdAt"     TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt"     TIMESTAMP(3) NOT NULL,
  CONSTRAINT "PaymentIntent_userId_fkey"
    FOREIGN KEY ("userId") REFERENCES "UserProfile"("id") ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "PaymentIntent_caseId_fkey"
    FOREIGN KEY ("caseId") REFERENCES "Case"("id")        ON DELETE SET NULL ON UPDATE CASCADE
);

CREATE INDEX "PaymentIntent_userId_idx"    ON "PaymentIntent"("userId");
CREATE INDEX "PaymentIntent_caseId_idx"    ON "PaymentIntent"("caseId");
CREATE INDEX "PaymentIntent_status_idx"    ON "PaymentIntent"("status");
CREATE INDEX "PaymentIntent_provider_idx"  ON "PaymentIntent"("provider");
