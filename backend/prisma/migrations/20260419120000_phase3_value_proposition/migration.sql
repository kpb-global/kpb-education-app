-- Phase 3 — Value proposition
-- ServicePackages (Dossier prêt + scholarship/visa kits), Partners (credibility
-- strip), Salon KPB Virtuel (annual event), Alumni mentor fields on UserProfile,
-- and a free-counsellor-message quota flag on Case.

-- ─── Enums ─────────────────────────────────────────────────────────────────
CREATE TYPE "ServicePackageCategory" AS ENUM ('dossier_pret', 'scholarship_kit', 'visa_kit', 'consultation', 'other');

CREATE TYPE "ServicePurchaseStatus" AS ENUM ('pending_payment', 'paid', 'in_progress', 'delivered', 'cancelled', 'refunded');

CREATE TYPE "AlumniVerificationStatus" AS ENUM ('none', 'pending', 'approved', 'rejected');

CREATE TYPE "PartnerCategory" AS ENUM ('university', 'bank', 'agency', 'ngo', 'other');

CREATE TYPE "SalonEventStatus" AS ENUM ('draft', 'scheduled', 'live', 'ended', 'cancelled');

CREATE TYPE "SalonSessionStatus" AS ENUM ('scheduled', 'live', 'ended', 'cancelled');

-- ─── UserProfile — alumni fields ───────────────────────────────────────────
ALTER TABLE "UserProfile"
  ADD COLUMN "alumniStatus"         "AlumniVerificationStatus" NOT NULL DEFAULT 'none',
  ADD COLUMN "alumniUniversity"     TEXT,
  ADD COLUMN "alumniProgramme"      TEXT,
  ADD COLUMN "alumniGraduationYear" INTEGER,
  ADD COLUMN "alumniCountryCode"    TEXT,
  ADD COLUMN "alumniBioFr"          TEXT,
  ADD COLUMN "alumniBioEn"          TEXT,
  ADD COLUMN "alumniProofUrl"       TEXT,
  ADD COLUMN "alumniVerifiedAt"     TIMESTAMP(3),
  ADD COLUMN "alumniVerifiedById"   TEXT,
  ADD COLUMN "alumniBadgeVisible"   BOOLEAN NOT NULL DEFAULT true;

CREATE INDEX "UserProfile_alumniStatus_idx" ON "UserProfile"("alumniStatus");

-- ─── Case — free-message quota ─────────────────────────────────────────────
ALTER TABLE "Case"
  ADD COLUMN "freeMessageConsumed" BOOLEAN NOT NULL DEFAULT false;

-- ─── ServicePackage ────────────────────────────────────────────────────────
CREATE TABLE "ServicePackage" (
    "id"             TEXT NOT NULL,
    "code"           TEXT NOT NULL,
    "nameFr"         TEXT NOT NULL,
    "nameEn"         TEXT NOT NULL,
    "summaryFr"      TEXT NOT NULL,
    "summaryEn"      TEXT NOT NULL,
    "descriptionFr"  TEXT NOT NULL,
    "descriptionEn"  TEXT NOT NULL,
    "category"       "ServicePackageCategory" NOT NULL,
    "priceXOF"       INTEGER NOT NULL,
    "deliverablesFr" TEXT[] DEFAULT ARRAY[]::TEXT[],
    "deliverablesEn" TEXT[] DEFAULT ARRAY[]::TEXT[],
    "turnaroundFr"   TEXT,
    "turnaroundEn"   TEXT,
    "isActive"       BOOLEAN NOT NULL DEFAULT true,
    "displayOrder"   INTEGER NOT NULL DEFAULT 0,
    "createdAt"      TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt"      TIMESTAMP(3) NOT NULL,

    CONSTRAINT "ServicePackage_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "ServicePackage_code_key" ON "ServicePackage"("code");
CREATE INDEX "ServicePackage_category_idx" ON "ServicePackage"("category");
CREATE INDEX "ServicePackage_isActive_idx" ON "ServicePackage"("isActive");

-- ─── ServicePurchase ───────────────────────────────────────────────────────
CREATE TABLE "ServicePurchase" (
    "id"              TEXT NOT NULL,
    "packageId"       TEXT NOT NULL,
    "userId"          TEXT NOT NULL,
    "caseId"          TEXT,
    "paymentIntentId" TEXT,
    "status"          "ServicePurchaseStatus" NOT NULL DEFAULT 'pending_payment',
    "amountXOF"       INTEGER NOT NULL,
    "internalNotes"   TEXT,
    "deliveredAt"     TIMESTAMP(3),
    "createdAt"       TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt"       TIMESTAMP(3) NOT NULL,

    CONSTRAINT "ServicePurchase_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "ServicePurchase_paymentIntentId_key" ON "ServicePurchase"("paymentIntentId");
CREATE INDEX "ServicePurchase_packageId_idx" ON "ServicePurchase"("packageId");
CREATE INDEX "ServicePurchase_userId_idx" ON "ServicePurchase"("userId");
CREATE INDEX "ServicePurchase_status_idx" ON "ServicePurchase"("status");
CREATE INDEX "ServicePurchase_createdAt_idx" ON "ServicePurchase"("createdAt");

ALTER TABLE "ServicePurchase"
    ADD CONSTRAINT "ServicePurchase_packageId_fkey"
    FOREIGN KEY ("packageId") REFERENCES "ServicePackage"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE "ServicePurchase"
    ADD CONSTRAINT "ServicePurchase_userId_fkey"
    FOREIGN KEY ("userId") REFERENCES "UserProfile"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE "ServicePurchase"
    ADD CONSTRAINT "ServicePurchase_paymentIntentId_fkey"
    FOREIGN KEY ("paymentIntentId") REFERENCES "PaymentIntent"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- ─── Partner ───────────────────────────────────────────────────────────────
CREATE TABLE "Partner" (
    "id"            TEXT NOT NULL,
    "slug"          TEXT NOT NULL,
    "nameFr"        TEXT NOT NULL,
    "nameEn"        TEXT NOT NULL,
    "category"      "PartnerCategory" NOT NULL,
    "countryCode"   TEXT,
    "taglineFr"     TEXT,
    "taglineEn"     TEXT,
    "descriptionFr" TEXT,
    "descriptionEn" TEXT,
    "logoUrl"       TEXT,
    "websiteUrl"    TEXT,
    "referralUrl"   TEXT,
    "isFeatured"    BOOLEAN NOT NULL DEFAULT false,
    "displayOrder"  INTEGER NOT NULL DEFAULT 0,
    "isActive"      BOOLEAN NOT NULL DEFAULT true,
    "createdAt"     TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt"     TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Partner_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "Partner_slug_key" ON "Partner"("slug");
CREATE INDEX "Partner_category_idx" ON "Partner"("category");
CREATE INDEX "Partner_isActive_idx" ON "Partner"("isActive");
CREATE INDEX "Partner_countryCode_idx" ON "Partner"("countryCode");

-- ─── SalonEvent ────────────────────────────────────────────────────────────
CREATE TABLE "SalonEvent" (
    "id"            TEXT NOT NULL,
    "slug"          TEXT NOT NULL,
    "nameFr"        TEXT NOT NULL,
    "nameEn"        TEXT NOT NULL,
    "year"          INTEGER NOT NULL,
    "startAt"       TIMESTAMP(3) NOT NULL,
    "endAt"         TIMESTAMP(3) NOT NULL,
    "heroImageUrl"  TEXT,
    "descriptionFr" TEXT,
    "descriptionEn" TEXT,
    "status"        "SalonEventStatus" NOT NULL DEFAULT 'draft',
    "createdAt"     TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt"     TIMESTAMP(3) NOT NULL,

    CONSTRAINT "SalonEvent_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "SalonEvent_slug_key" ON "SalonEvent"("slug");
CREATE INDEX "SalonEvent_status_idx" ON "SalonEvent"("status");
CREATE INDEX "SalonEvent_year_idx" ON "SalonEvent"("year");

-- ─── SalonSession ──────────────────────────────────────────────────────────
CREATE TABLE "SalonSession" (
    "id"              TEXT NOT NULL,
    "eventId"         TEXT NOT NULL,
    "partnerId"       TEXT,
    "titleFr"         TEXT NOT NULL,
    "titleEn"         TEXT NOT NULL,
    "descriptionFr"   TEXT,
    "descriptionEn"   TEXT,
    "hostName"        TEXT,
    "startAt"         TIMESTAMP(3) NOT NULL,
    "durationMinutes" INTEGER NOT NULL DEFAULT 45,
    "joinUrl"         TEXT,
    "recordingUrl"    TEXT,
    "capacity"        INTEGER,
    "status"          "SalonSessionStatus" NOT NULL DEFAULT 'scheduled',
    "displayOrder"    INTEGER NOT NULL DEFAULT 0,
    "createdAt"       TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt"       TIMESTAMP(3) NOT NULL,

    CONSTRAINT "SalonSession_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "SalonSession_eventId_idx" ON "SalonSession"("eventId");
CREATE INDEX "SalonSession_partnerId_idx" ON "SalonSession"("partnerId");
CREATE INDEX "SalonSession_startAt_idx" ON "SalonSession"("startAt");
CREATE INDEX "SalonSession_status_idx" ON "SalonSession"("status");

ALTER TABLE "SalonSession"
    ADD CONSTRAINT "SalonSession_eventId_fkey"
    FOREIGN KEY ("eventId") REFERENCES "SalonEvent"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- Note: no FK on partnerId — we deliberately keep Partner decoupled so
-- admins can delete a Partner without orphaning historical sessions. The
-- orphan shows as a "Session sans partenaire" in the admin UI, which is
-- surviveable.

-- ─── SalonRegistration ─────────────────────────────────────────────────────
CREATE TABLE "SalonRegistration" (
    "id"         TEXT NOT NULL,
    "sessionId"  TEXT NOT NULL,
    "userId"     TEXT NOT NULL,
    "status"     TEXT NOT NULL DEFAULT 'registered',
    "remindedAt" TIMESTAMP(3),
    "createdAt"  TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "SalonRegistration_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "SalonRegistration_sessionId_userId_key" ON "SalonRegistration"("sessionId", "userId");
CREATE INDEX "SalonRegistration_userId_idx" ON "SalonRegistration"("userId");
CREATE INDEX "SalonRegistration_sessionId_idx" ON "SalonRegistration"("sessionId");

ALTER TABLE "SalonRegistration"
    ADD CONSTRAINT "SalonRegistration_sessionId_fkey"
    FOREIGN KEY ("sessionId") REFERENCES "SalonSession"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "SalonRegistration"
    ADD CONSTRAINT "SalonRegistration_userId_fkey"
    FOREIGN KEY ("userId") REFERENCES "UserProfile"("id") ON DELETE CASCADE ON UPDATE CASCADE;
