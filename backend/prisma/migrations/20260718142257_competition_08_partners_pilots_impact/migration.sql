-- CreateEnum
CREATE TYPE "PartnershipAgreementStatus" AS ENUM ('draft', 'prospect', 'pending_signature', 'signed', 'active', 'expired', 'terminated');

-- CreateEnum
CREATE TYPE "PartnershipAgreementType" AS ENUM ('letter_of_intent', 'memorandum_of_understanding', 'pilot', 'data_sharing', 'referral', 'sponsorship', 'other');

-- CreateEnum
CREATE TYPE "PilotStatus" AS ENUM ('draft', 'recruiting', 'active', 'analysis', 'completed', 'archived');

-- CreateTable
CREATE TABLE "PartnerAgreement" (
    "id" TEXT NOT NULL,
    "agreementKey" TEXT NOT NULL,
    "revisionNumber" INTEGER NOT NULL,
    "supersedesId" TEXT,
    "isCurrent" BOOLEAN NOT NULL DEFAULT true,
    "lockVersion" INTEGER NOT NULL DEFAULT 1,
    "partnerId" TEXT NOT NULL,
    "institutionId" TEXT,
    "status" "PartnershipAgreementStatus" NOT NULL DEFAULT 'draft',
    "agreementType" "PartnershipAgreementType" NOT NULL,
    "purposeCodes" TEXT[] DEFAULT ARRAY[]::TEXT[],
    "countryCodes" TEXT[] DEFAULT ARRAY[]::TEXT[],
    "canRecruitPilot" BOOLEAN NOT NULL DEFAULT false,
    "canVerifySubmission" BOOLEAN NOT NULL DEFAULT false,
    "canVerifyDecision" BOOLEAN NOT NULL DEFAULT false,
    "canShareAggregateData" BOOLEAN NOT NULL DEFAULT false,
    "canPubliclyNamePartner" BOOLEAN NOT NULL DEFAULT false,
    "canUsePartnerLogo" BOOLEAN NOT NULL DEFAULT false,
    "dataProtectionScope" JSONB,
    "safeguardingScope" JSONB,
    "agreementStorageKey" TEXT,
    "signedAt" TIMESTAMP(3),
    "startsAt" TIMESTAMP(3),
    "endsAt" TIMESTAMP(3),
    "ownerAdminId" TEXT,
    "lastVerifiedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "PartnerAgreement_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "PartnerAgreement_revision_check" CHECK ("revisionNumber" > 0 AND "lockVersion" > 0),
    CONSTRAINT "PartnerAgreement_dates_check" CHECK ("endsAt" IS NULL OR "startsAt" IS NULL OR "endsAt" > "startsAt"),
    CONSTRAINT "PartnerAgreement_active_check" CHECK (
      "status" <> 'active' OR
      ("signedAt" IS NOT NULL AND "startsAt" IS NOT NULL AND ("endsAt" IS NULL OR "endsAt" > "startsAt"))
    )
);

-- CreateTable
CREATE TABLE "PartnerAgreementEvidence" (
    "id" TEXT NOT NULL,
    "agreementId" TEXT NOT NULL,
    "kind" TEXT NOT NULL,
    "storageKey" TEXT,
    "externalUrl" TEXT,
    "note" TEXT,
    "verifiedById" TEXT,
    "verifiedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "PartnerAgreementEvidence_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "PartnerAgreementEvidence_source_check" CHECK ("storageKey" IS NOT NULL OR "externalUrl" IS NOT NULL),
    CONSTRAINT "PartnerAgreementEvidence_verification_check" CHECK (
      ("verifiedAt" IS NULL AND "verifiedById" IS NULL) OR
      ("verifiedAt" IS NOT NULL AND "verifiedById" IS NOT NULL)
    )
);

-- CreateTable
CREATE TABLE "ImpactPilot" (
    "id" TEXT NOT NULL,
    "code" TEXT NOT NULL,
    "version" INTEGER NOT NULL DEFAULT 1,
    "name" TEXT NOT NULL,
    "hypothesis" TEXT NOT NULL,
    "countryCodes" TEXT[] DEFAULT ARRAY[]::TEXT[],
    "targetPopulation" JSONB NOT NULL,
    "primaryMetrics" JSONB NOT NULL,
    "guardrailMetrics" JSONB NOT NULL,
    "status" "PilotStatus" NOT NULL DEFAULT 'draft',
    "recruitmentStartsAt" TIMESTAMP(3),
    "startsAt" TIMESTAMP(3),
    "endsAt" TIMESTAMP(3),
    "analysisLockedAt" TIMESTAMP(3),
    "protocolVersion" TEXT NOT NULL,
    "ownerAdminId" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "ImpactPilot_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "ImpactPilot_version_check" CHECK ("version" > 0),
    CONSTRAINT "ImpactPilot_dates_check" CHECK (
      ("startsAt" IS NULL OR "endsAt" IS NULL OR "endsAt" > "startsAt") AND
      ("recruitmentStartsAt" IS NULL OR "startsAt" IS NULL OR "recruitmentStartsAt" <= "startsAt") AND
      ("analysisLockedAt" IS NULL OR "endsAt" IS NULL OR "analysisLockedAt" >= "endsAt")
    )
);

-- CreateTable
CREATE TABLE "ImpactPilotPartnerAgreement" (
    "id" TEXT NOT NULL,
    "pilotId" TEXT NOT NULL,
    "agreementId" TEXT NOT NULL,
    "roleCodes" TEXT[] DEFAULT ARRAY[]::TEXT[],
    "countryCodes" TEXT[] DEFAULT ARRAY[]::TEXT[],
    "startsAt" TIMESTAMP(3),
    "endsAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ImpactPilotPartnerAgreement_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "ImpactPilotPartnerAgreement_dates_check" CHECK ("endsAt" IS NULL OR "startsAt" IS NULL OR "endsAt" > "startsAt")
);

-- CreateTable
CREATE TABLE "ImpactCohort" (
    "id" TEXT NOT NULL,
    "pilotId" TEXT NOT NULL,
    "code" TEXT NOT NULL,
    "version" INTEGER NOT NULL DEFAULT 1,
    "label" TEXT NOT NULL,
    "cohortType" TEXT NOT NULL,
    "inclusionRules" JSONB NOT NULL,
    "exclusionRules" JSONB NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "ImpactCohort_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "ImpactCohort_version_check" CHECK ("version" > 0)
);

-- CreateTable
CREATE TABLE "ImpactCohortMembership" (
    "id" TEXT NOT NULL,
    "cohortId" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "workspaceId" TEXT,
    "consentReceiptId" TEXT NOT NULL,
    "version" INTEGER NOT NULL DEFAULT 1,
    "status" TEXT NOT NULL DEFAULT 'enrolled',
    "enrolledAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "withdrawnAt" TIMESTAMP(3),
    "exitReason" TEXT,
    "countryCodeLocked" TEXT NOT NULL,
    "studyLevelLocked" TEXT,
    "genderCodeLocked" TEXT,
    "deviceClassLocked" TEXT,
    "connectivityLocked" TEXT,
    "profileRubricVersion" TEXT NOT NULL,
    "matchingAlgorithmVersion" TEXT,
    "baselineSnapshot" JSONB NOT NULL,

    CONSTRAINT "ImpactCohortMembership_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "ImpactCohortMembership_version_check" CHECK ("version" > 0),
    CONSTRAINT "ImpactCohortMembership_status_check" CHECK ("status" IN ('enrolled', 'withdrawn', 'completed', 'ineligible')),
    CONSTRAINT "ImpactCohortMembership_country_check" CHECK ("countryCodeLocked" ~ '^[A-Z]{2}$'),
    CONSTRAINT "ImpactCohortMembership_withdrawal_check" CHECK (
      ("status" = 'withdrawn' AND "withdrawnAt" IS NOT NULL) OR
      ("status" <> 'withdrawn' AND "withdrawnAt" IS NULL)
    )
);

-- CreateTable
CREATE TABLE "ExperimentAssignment" (
    "id" TEXT NOT NULL,
    "membershipId" TEXT NOT NULL,
    "experimentKey" TEXT NOT NULL,
    "experimentVersion" TEXT NOT NULL,
    "armCode" TEXT NOT NULL,
    "assignmentSeedHash" TEXT NOT NULL,
    "assignedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ExperimentAssignment_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "ExperimentAssignment_seed_check" CHECK ("assignmentSeedHash" ~ '^[0-9a-f]{64}$')
);

-- CreateTable
CREATE TABLE "PilotAssessment" (
    "id" TEXT NOT NULL,
    "membershipId" TEXT NOT NULL,
    "assessmentType" TEXT NOT NULL,
    "instrumentVersion" TEXT NOT NULL,
    "answers" JSONB NOT NULL,
    "score" DECIMAL(65,30),
    "administeredAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "PilotAssessment_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ImpactSnapshot" (
    "id" TEXT NOT NULL,
    "pilotId" TEXT NOT NULL,
    "snapshotVersion" INTEGER NOT NULL,
    "correctionOfId" TEXT,
    "periodStart" TIMESTAMP(3) NOT NULL,
    "periodEnd" TIMESTAMP(3) NOT NULL,
    "metricDefinitions" JSONB NOT NULL,
    "metrics" JSONB NOT NULL,
    "sourceWatermark" TIMESTAMP(3) NOT NULL,
    "methodologyVersion" TEXT NOT NULL,
    "methodologyHash" TEXT NOT NULL,
    "dataHash" TEXT NOT NULL,
    "generatedByVersion" TEXT NOT NULL,
    "generatedByAdminId" TEXT NOT NULL,
    "isPublicSafe" BOOLEAN NOT NULL DEFAULT false,
    "generatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ImpactSnapshot_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "ImpactSnapshot_version_check" CHECK ("snapshotVersion" > 0),
    CONSTRAINT "ImpactSnapshot_period_check" CHECK ("periodEnd" > "periodStart" AND "sourceWatermark" >= "periodStart"),
    CONSTRAINT "ImpactSnapshot_hash_check" CHECK (
      "methodologyHash" ~ '^[0-9a-f]{64}$' AND "dataHash" ~ '^[0-9a-f]{64}$'
    )
);

-- CreateTable
CREATE TABLE "ImpactDataRoomExport" (
    "id" TEXT NOT NULL,
    "pilotId" TEXT NOT NULL,
    "snapshotId" TEXT NOT NULL,
    "requestedByAdminId" TEXT NOT NULL,
    "purposeCode" TEXT NOT NULL,
    "format" TEXT NOT NULL DEFAULT 'json',
    "manifest" JSONB NOT NULL,
    "sha256" TEXT NOT NULL,
    "storageKey" TEXT,
    "expiresAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ImpactDataRoomExport_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "ImpactDataRoomExport_format_check" CHECK ("format" IN ('json', 'csv', 'zip')),
    CONSTRAINT "ImpactDataRoomExport_hash_check" CHECK ("sha256" ~ '^[0-9a-f]{64}$'),
    CONSTRAINT "ImpactDataRoomExport_expiry_check" CHECK ("expiresAt" IS NULL OR "expiresAt" > "createdAt")
);

-- CreateIndex
CREATE UNIQUE INDEX "PartnerAgreement_supersedesId_key" ON "PartnerAgreement"("supersedesId");

-- Exactly one immutable current revision for an agreement key.
CREATE UNIQUE INDEX "PartnerAgreement_one_current_per_key" ON "PartnerAgreement"("agreementKey") WHERE "isCurrent" = true;

-- Private storage objects cannot be attached to multiple contractual rows.
CREATE UNIQUE INDEX "PartnerAgreement_agreementStorageKey_key" ON "PartnerAgreement"("agreementStorageKey");

-- CreateIndex
CREATE INDEX "PartnerAgreement_partnerId_status_idx" ON "PartnerAgreement"("partnerId", "status");

-- CreateIndex
CREATE INDEX "PartnerAgreement_institutionId_idx" ON "PartnerAgreement"("institutionId");

-- CreateIndex
CREATE INDEX "PartnerAgreement_status_endsAt_idx" ON "PartnerAgreement"("status", "endsAt");

-- CreateIndex
CREATE UNIQUE INDEX "PartnerAgreement_agreementKey_revisionNumber_key" ON "PartnerAgreement"("agreementKey", "revisionNumber");

-- CreateIndex
CREATE INDEX "PartnerAgreementEvidence_agreementId_kind_idx" ON "PartnerAgreementEvidence"("agreementId", "kind");

CREATE UNIQUE INDEX "PartnerAgreementEvidence_storageKey_key" ON "PartnerAgreementEvidence"("storageKey");

-- CreateIndex
CREATE UNIQUE INDEX "ImpactPilot_code_key" ON "ImpactPilot"("code");

-- CreateIndex
CREATE INDEX "ImpactPilot_status_startsAt_idx" ON "ImpactPilot"("status", "startsAt");

-- CreateIndex
CREATE INDEX "ImpactPilotPartnerAgreement_agreementId_idx" ON "ImpactPilotPartnerAgreement"("agreementId");

-- CreateIndex
CREATE UNIQUE INDEX "ImpactPilotPartnerAgreement_pilotId_agreementId_key" ON "ImpactPilotPartnerAgreement"("pilotId", "agreementId");

-- CreateIndex
CREATE INDEX "ImpactCohort_pilotId_cohortType_idx" ON "ImpactCohort"("pilotId", "cohortType");

-- CreateIndex
CREATE UNIQUE INDEX "ImpactCohort_pilotId_code_key" ON "ImpactCohort"("pilotId", "code");

-- CreateIndex
CREATE INDEX "ImpactCohortMembership_userId_idx" ON "ImpactCohortMembership"("userId");

-- CreateIndex
CREATE INDEX "ImpactCohortMembership_workspaceId_idx" ON "ImpactCohortMembership"("workspaceId");

-- CreateIndex
CREATE INDEX "ImpactCohortMembership_consentReceiptId_idx" ON "ImpactCohortMembership"("consentReceiptId");

-- CreateIndex
CREATE INDEX "ImpactCohortMembership_cohortId_status_enrolledAt_idx" ON "ImpactCohortMembership"("cohortId", "status", "enrolledAt");

-- CreateIndex
CREATE UNIQUE INDEX "ImpactCohortMembership_cohortId_userId_key" ON "ImpactCohortMembership"("cohortId", "userId");

-- CreateIndex
CREATE UNIQUE INDEX "ExperimentAssignment_membershipId_key" ON "ExperimentAssignment"("membershipId");

-- CreateIndex
CREATE INDEX "ExperimentAssignment_experimentKey_experimentVersion_armCod_idx" ON "ExperimentAssignment"("experimentKey", "experimentVersion", "armCode");

-- CreateIndex
CREATE INDEX "PilotAssessment_membershipId_assessmentType_administeredAt_idx" ON "PilotAssessment"("membershipId", "assessmentType", "administeredAt");

-- CreateIndex
CREATE UNIQUE INDEX "PilotAssessment_membershipId_assessmentType_instrumentVersi_key" ON "PilotAssessment"("membershipId", "assessmentType", "instrumentVersion");

-- CreateIndex
CREATE INDEX "ImpactSnapshot_pilotId_periodEnd_idx" ON "ImpactSnapshot"("pilotId", "periodEnd");

-- CreateIndex
CREATE INDEX "ImpactSnapshot_correctionOfId_idx" ON "ImpactSnapshot"("correctionOfId");

-- CreateIndex
CREATE UNIQUE INDEX "ImpactSnapshot_pilotId_snapshotVersion_key" ON "ImpactSnapshot"("pilotId", "snapshotVersion");

-- CreateIndex
CREATE INDEX "ImpactDataRoomExport_pilotId_createdAt_idx" ON "ImpactDataRoomExport"("pilotId", "createdAt");

-- CreateIndex
CREATE INDEX "ImpactDataRoomExport_snapshotId_idx" ON "ImpactDataRoomExport"("snapshotId");

CREATE UNIQUE INDEX "ImpactDataRoomExport_storageKey_key" ON "ImpactDataRoomExport"("storageKey");

-- AddForeignKey
ALTER TABLE "PartnerAgreement" ADD CONSTRAINT "PartnerAgreement_partnerId_fkey" FOREIGN KEY ("partnerId") REFERENCES "Partner"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "PartnerAgreement" ADD CONSTRAINT "PartnerAgreement_institutionId_fkey" FOREIGN KEY ("institutionId") REFERENCES "Institution"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "PartnerAgreement" ADD CONSTRAINT "PartnerAgreement_supersedesId_fkey" FOREIGN KEY ("supersedesId") REFERENCES "PartnerAgreement"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "PartnerAgreementEvidence" ADD CONSTRAINT "PartnerAgreementEvidence_agreementId_fkey" FOREIGN KEY ("agreementId") REFERENCES "PartnerAgreement"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ImpactPilotPartnerAgreement" ADD CONSTRAINT "ImpactPilotPartnerAgreement_pilotId_fkey" FOREIGN KEY ("pilotId") REFERENCES "ImpactPilot"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ImpactPilotPartnerAgreement" ADD CONSTRAINT "ImpactPilotPartnerAgreement_agreementId_fkey" FOREIGN KEY ("agreementId") REFERENCES "PartnerAgreement"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ImpactCohort" ADD CONSTRAINT "ImpactCohort_pilotId_fkey" FOREIGN KEY ("pilotId") REFERENCES "ImpactPilot"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ImpactCohortMembership" ADD CONSTRAINT "ImpactCohortMembership_cohortId_fkey" FOREIGN KEY ("cohortId") REFERENCES "ImpactCohort"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ImpactCohortMembership" ADD CONSTRAINT "ImpactCohortMembership_userId_fkey" FOREIGN KEY ("userId") REFERENCES "UserProfile"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ImpactCohortMembership" ADD CONSTRAINT "ImpactCohortMembership_workspaceId_fkey" FOREIGN KEY ("workspaceId") REFERENCES "ScholarshipWorkspace"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ImpactCohortMembership" ADD CONSTRAINT "ImpactCohortMembership_consentReceiptId_fkey" FOREIGN KEY ("consentReceiptId") REFERENCES "ConsentReceipt"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ExperimentAssignment" ADD CONSTRAINT "ExperimentAssignment_membershipId_fkey" FOREIGN KEY ("membershipId") REFERENCES "ImpactCohortMembership"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "PilotAssessment" ADD CONSTRAINT "PilotAssessment_membershipId_fkey" FOREIGN KEY ("membershipId") REFERENCES "ImpactCohortMembership"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ImpactSnapshot" ADD CONSTRAINT "ImpactSnapshot_pilotId_fkey" FOREIGN KEY ("pilotId") REFERENCES "ImpactPilot"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ImpactSnapshot" ADD CONSTRAINT "ImpactSnapshot_correctionOfId_fkey" FOREIGN KEY ("correctionOfId") REFERENCES "ImpactSnapshot"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ImpactDataRoomExport" ADD CONSTRAINT "ImpactDataRoomExport_pilotId_fkey" FOREIGN KEY ("pilotId") REFERENCES "ImpactPilot"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ImpactDataRoomExport" ADD CONSTRAINT "ImpactDataRoomExport_snapshotId_fkey" FOREIGN KEY ("snapshotId") REFERENCES "ImpactSnapshot"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
