-- Competition Readiness CR-017/CR-018: private, consented, versioned outcomes.
-- Additive only: no legacy Case, alumni or scholarship row is reinterpreted.

CREATE TYPE "EvidenceVerificationStatus" AS ENUM (
  'self_reported',
  'pending',
  'verified',
  'needs_information',
  'rejected'
);

CREATE TYPE "AdmissionDecision" AS ENUM (
  'admitted',
  'rejected',
  'waitlisted',
  'deferred',
  'withdrawn'
);

CREATE TYPE "FundingDecision" AS ENUM (
  'full',
  'partial',
  'none',
  'pending',
  'not_applicable'
);

CREATE TYPE "OutcomeEvidenceKind" AS ENUM (
  'submission_confirmation',
  'admission_decision',
  'rejection_decision',
  'waitlist_decision',
  'funding_award',
  'funding_rejection',
  'enrollment_confirmation',
  'other'
);

CREATE TABLE "OutcomeEvidenceAsset" (
  "id" TEXT NOT NULL,
  "workspaceId" TEXT NOT NULL,
  "ownerUserId" TEXT NOT NULL,
  "consentReceiptId" TEXT NOT NULL,
  "kind" "OutcomeEvidenceKind" NOT NULL,
  "storageKey" TEXT,
  "originalFileName" TEXT NOT NULL,
  "mimeType" TEXT NOT NULL,
  "sizeBytes" INTEGER NOT NULL,
  "sha256" TEXT NOT NULL,
  "processingStatus" "ArtifactProcessingStatus" NOT NULL DEFAULT 'pending_upload',
  "version" INTEGER NOT NULL DEFAULT 1,
  "rejectionCode" TEXT,
  "retentionClass" TEXT NOT NULL DEFAULT 'outcome_evidence_private',
  "uploadedAt" TIMESTAMP(3),
  "deletedAt" TIMESTAMP(3),
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,

  CONSTRAINT "OutcomeEvidenceAsset_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "OutcomeEvidenceAsset_size_check" CHECK ("sizeBytes" > 0),
  CONSTRAINT "OutcomeEvidenceAsset_version_check" CHECK ("version" > 0),
  CONSTRAINT "OutcomeEvidenceAsset_sha256_check" CHECK ("sha256" ~ '^[0-9a-f]{64}$'),
  CONSTRAINT "OutcomeEvidenceAsset_clean_storage_check" CHECK (
    "processingStatus" <> 'clean' OR
    ("storageKey" IS NOT NULL AND "uploadedAt" IS NOT NULL AND "deletedAt" IS NULL)
  )
);

CREATE TABLE "ApplicationSubmission" (
  "id" TEXT NOT NULL,
  "workspaceId" TEXT NOT NULL,
  "version" INTEGER NOT NULL,
  "lockVersion" INTEGER NOT NULL DEFAULT 1,
  "submittedAt" TIMESTAMP(3) NOT NULL,
  "submissionChannel" TEXT,
  "applicationRefHash" TEXT,
  "evidenceId" TEXT NOT NULL,
  "verificationStatus" "EvidenceVerificationStatus" NOT NULL DEFAULT 'self_reported',
  "verificationNotes" TEXT,
  "verifiedAt" TIMESTAMP(3),
  "verifiedById" TEXT,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,

  CONSTRAINT "ApplicationSubmission_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "ApplicationSubmission_version_check" CHECK ("version" > 0),
  CONSTRAINT "ApplicationSubmission_lock_version_check" CHECK ("lockVersion" > 0),
  CONSTRAINT "ApplicationSubmission_reference_hash_check" CHECK ("applicationRefHash" IS NULL OR "applicationRefHash" ~ '^[0-9a-f]{64}$'),
  CONSTRAINT "ApplicationSubmission_verification_check" CHECK (
    ("verificationStatus" = 'verified' AND "verifiedAt" IS NOT NULL AND "verifiedById" IS NOT NULL) OR
    ("verificationStatus" <> 'verified' AND "verifiedAt" IS NULL AND "verifiedById" IS NULL)
  )
);

CREATE TABLE "ApplicationDecisionRecord" (
  "id" TEXT NOT NULL,
  "workspaceId" TEXT NOT NULL,
  "supersedesId" TEXT,
  "version" INTEGER NOT NULL,
  "lockVersion" INTEGER NOT NULL DEFAULT 1,
  "isCurrent" BOOLEAN NOT NULL DEFAULT true,
  "issuedByName" TEXT NOT NULL,
  "admissionDecision" "AdmissionDecision" NOT NULL,
  "issuedAt" TIMESTAMP(3),
  "receivedAt" TIMESTAMP(3) NOT NULL,
  "evidenceId" TEXT NOT NULL,
  "verificationStatus" "EvidenceVerificationStatus" NOT NULL DEFAULT 'self_reported',
  "verificationNotes" TEXT,
  "verifiedAt" TIMESTAMP(3),
  "verifiedById" TEXT,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,

  CONSTRAINT "ApplicationDecisionRecord_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "ApplicationDecisionRecord_version_check" CHECK ("version" > 0),
  CONSTRAINT "ApplicationDecisionRecord_lock_version_check" CHECK ("lockVersion" > 0),
  CONSTRAINT "ApplicationDecisionRecord_issuer_check" CHECK (length(btrim("issuedByName")) BETWEEN 1 AND 180),
  CONSTRAINT "ApplicationDecisionRecord_verification_check" CHECK (
    ("verificationStatus" = 'verified' AND "verifiedAt" IS NOT NULL AND "verifiedById" IS NOT NULL) OR
    ("verificationStatus" <> 'verified' AND "verifiedAt" IS NULL AND "verifiedById" IS NULL)
  )
);

CREATE TABLE "FundingDecisionRecord" (
  "id" TEXT NOT NULL,
  "workspaceId" TEXT NOT NULL,
  "admissionDecisionId" TEXT,
  "supersedesId" TEXT,
  "version" INTEGER NOT NULL,
  "lockVersion" INTEGER NOT NULL DEFAULT 1,
  "isCurrent" BOOLEAN NOT NULL DEFAULT true,
  "issuedByName" TEXT NOT NULL,
  "fundingDecision" "FundingDecision" NOT NULL,
  "fundingAmountMinor" BIGINT,
  "fundingCurrency" TEXT,
  "issuedAt" TIMESTAMP(3),
  "receivedAt" TIMESTAMP(3) NOT NULL,
  "evidenceId" TEXT NOT NULL,
  "verificationStatus" "EvidenceVerificationStatus" NOT NULL DEFAULT 'self_reported',
  "verificationNotes" TEXT,
  "verifiedAt" TIMESTAMP(3),
  "verifiedById" TEXT,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,

  CONSTRAINT "FundingDecisionRecord_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "FundingDecisionRecord_version_check" CHECK ("version" > 0),
  CONSTRAINT "FundingDecisionRecord_lock_version_check" CHECK ("lockVersion" > 0),
  CONSTRAINT "FundingDecisionRecord_issuer_check" CHECK (length(btrim("issuedByName")) BETWEEN 1 AND 180),
  CONSTRAINT "FundingDecisionRecord_amount_currency_check" CHECK (
    (
      "fundingDecision" IN ('full', 'partial') AND
      (
        ("fundingAmountMinor" IS NULL AND "fundingCurrency" IS NULL) OR
        (
          "fundingAmountMinor" IS NOT NULL AND
          "fundingCurrency" IS NOT NULL AND
          "fundingAmountMinor" > 0 AND
          "fundingCurrency" ~ '^[A-Z]{3}$'
        )
      )
    ) OR (
      "fundingDecision" NOT IN ('full', 'partial') AND
      "fundingAmountMinor" IS NULL AND
      "fundingCurrency" IS NULL
    )
  ),
  CONSTRAINT "FundingDecisionRecord_verification_check" CHECK (
    ("verificationStatus" = 'verified' AND "verifiedAt" IS NOT NULL AND "verifiedById" IS NOT NULL) OR
    ("verificationStatus" <> 'verified' AND "verifiedAt" IS NULL AND "verifiedById" IS NULL)
  )
);

CREATE TABLE "OutcomeEvidenceLink" (
  "id" TEXT NOT NULL,
  "evidenceId" TEXT NOT NULL,
  "entityType" TEXT NOT NULL,
  "entityId" TEXT NOT NULL,
  "isPrimary" BOOLEAN NOT NULL DEFAULT false,
  "linkedByUserId" TEXT NOT NULL,
  "linkedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT "OutcomeEvidenceLink_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "OutcomeEvidenceLink_entity_type_check" CHECK ("entityType" IN ('submission', 'admission', 'funding'))
);

CREATE TABLE "OutcomeVerificationEvent" (
  "id" TEXT NOT NULL,
  "entityType" TEXT NOT NULL,
  "entityId" TEXT NOT NULL,
  "fromStatus" "EvidenceVerificationStatus" NOT NULL,
  "toStatus" "EvidenceVerificationStatus" NOT NULL,
  "actorAdminId" TEXT NOT NULL,
  "reasonCode" TEXT,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT "OutcomeVerificationEvent_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "OutcomeVerificationEvent_entity_type_check" CHECK ("entityType" IN ('submission', 'admission', 'funding')),
  CONSTRAINT "OutcomeVerificationEvent_reason_check" CHECK ("reasonCode" IS NULL OR length("reasonCode") <= 80)
);

CREATE UNIQUE INDEX "OutcomeEvidenceAsset_storageKey_key" ON "OutcomeEvidenceAsset"("storageKey");
CREATE INDEX "OutcomeEvidenceAsset_workspaceId_kind_idx" ON "OutcomeEvidenceAsset"("workspaceId", "kind");
CREATE INDEX "OutcomeEvidenceAsset_ownerUserId_createdAt_idx" ON "OutcomeEvidenceAsset"("ownerUserId", "createdAt");
CREATE INDEX "OutcomeEvidenceAsset_processingStatus_createdAt_idx" ON "OutcomeEvidenceAsset"("processingStatus", "createdAt");
CREATE INDEX "OutcomeEvidenceAsset_consentReceiptId_idx" ON "OutcomeEvidenceAsset"("consentReceiptId");

CREATE UNIQUE INDEX "ApplicationSubmission_workspaceId_version_key" ON "ApplicationSubmission"("workspaceId", "version");
CREATE INDEX "ApplicationSubmission_workspaceId_submittedAt_idx" ON "ApplicationSubmission"("workspaceId", "submittedAt");
CREATE INDEX "ApplicationSubmission_verificationStatus_createdAt_idx" ON "ApplicationSubmission"("verificationStatus", "createdAt");

CREATE UNIQUE INDEX "ApplicationDecisionRecord_supersedesId_key" ON "ApplicationDecisionRecord"("supersedesId");
CREATE UNIQUE INDEX "ApplicationDecisionRecord_workspaceId_version_key" ON "ApplicationDecisionRecord"("workspaceId", "version");
CREATE UNIQUE INDEX "ApplicationDecisionRecord_one_current_per_workspace" ON "ApplicationDecisionRecord"("workspaceId") WHERE "isCurrent" = true;
CREATE INDEX "ApplicationDecisionRecord_workspaceId_isCurrent_idx" ON "ApplicationDecisionRecord"("workspaceId", "isCurrent");
CREATE INDEX "ApplicationDecisionRecord_verificationStatus_createdAt_idx" ON "ApplicationDecisionRecord"("verificationStatus", "createdAt");
CREATE INDEX "ApplicationDecisionRecord_admissionDecision_verificationSta_idx" ON "ApplicationDecisionRecord"("admissionDecision", "verificationStatus");

CREATE UNIQUE INDEX "FundingDecisionRecord_supersedesId_key" ON "FundingDecisionRecord"("supersedesId");
CREATE UNIQUE INDEX "FundingDecisionRecord_workspaceId_version_key" ON "FundingDecisionRecord"("workspaceId", "version");
CREATE UNIQUE INDEX "FundingDecisionRecord_one_current_per_workspace" ON "FundingDecisionRecord"("workspaceId") WHERE "isCurrent" = true;
CREATE INDEX "FundingDecisionRecord_workspaceId_isCurrent_idx" ON "FundingDecisionRecord"("workspaceId", "isCurrent");
CREATE INDEX "FundingDecisionRecord_admissionDecisionId_idx" ON "FundingDecisionRecord"("admissionDecisionId");
CREATE INDEX "FundingDecisionRecord_verificationStatus_createdAt_idx" ON "FundingDecisionRecord"("verificationStatus", "createdAt");
CREATE INDEX "FundingDecisionRecord_fundingDecision_verificationStatus_idx" ON "FundingDecisionRecord"("fundingDecision", "verificationStatus");

CREATE UNIQUE INDEX "OutcomeEvidenceLink_entityType_entityId_evidenceId_key" ON "OutcomeEvidenceLink"("entityType", "entityId", "evidenceId");
CREATE UNIQUE INDEX "OutcomeEvidenceLink_one_primary_per_entity" ON "OutcomeEvidenceLink"("entityType", "entityId") WHERE "isPrimary" = true;
CREATE INDEX "OutcomeEvidenceLink_entityType_entityId_linkedAt_idx" ON "OutcomeEvidenceLink"("entityType", "entityId", "linkedAt");
CREATE INDEX "OutcomeEvidenceLink_evidenceId_idx" ON "OutcomeEvidenceLink"("evidenceId");
CREATE INDEX "OutcomeVerificationEvent_entityType_entityId_createdAt_idx" ON "OutcomeVerificationEvent"("entityType", "entityId", "createdAt");
CREATE INDEX "OutcomeVerificationEvent_actorAdminId_createdAt_idx" ON "OutcomeVerificationEvent"("actorAdminId", "createdAt");

ALTER TABLE "OutcomeEvidenceAsset" ADD CONSTRAINT "OutcomeEvidenceAsset_workspaceId_fkey" FOREIGN KEY ("workspaceId") REFERENCES "ScholarshipWorkspace"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "OutcomeEvidenceAsset" ADD CONSTRAINT "OutcomeEvidenceAsset_ownerUserId_fkey" FOREIGN KEY ("ownerUserId") REFERENCES "UserProfile"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "OutcomeEvidenceAsset" ADD CONSTRAINT "OutcomeEvidenceAsset_consentReceiptId_fkey" FOREIGN KEY ("consentReceiptId") REFERENCES "ConsentReceipt"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE "ApplicationSubmission" ADD CONSTRAINT "ApplicationSubmission_workspaceId_fkey" FOREIGN KEY ("workspaceId") REFERENCES "ScholarshipWorkspace"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "ApplicationSubmission" ADD CONSTRAINT "ApplicationSubmission_evidenceId_fkey" FOREIGN KEY ("evidenceId") REFERENCES "OutcomeEvidenceAsset"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "ApplicationSubmission" ADD CONSTRAINT "ApplicationSubmission_verifiedById_fkey" FOREIGN KEY ("verifiedById") REFERENCES "AdminUser"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE "ApplicationDecisionRecord" ADD CONSTRAINT "ApplicationDecisionRecord_workspaceId_fkey" FOREIGN KEY ("workspaceId") REFERENCES "ScholarshipWorkspace"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "ApplicationDecisionRecord" ADD CONSTRAINT "ApplicationDecisionRecord_supersedesId_fkey" FOREIGN KEY ("supersedesId") REFERENCES "ApplicationDecisionRecord"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "ApplicationDecisionRecord" ADD CONSTRAINT "ApplicationDecisionRecord_evidenceId_fkey" FOREIGN KEY ("evidenceId") REFERENCES "OutcomeEvidenceAsset"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "ApplicationDecisionRecord" ADD CONSTRAINT "ApplicationDecisionRecord_verifiedById_fkey" FOREIGN KEY ("verifiedById") REFERENCES "AdminUser"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE "FundingDecisionRecord" ADD CONSTRAINT "FundingDecisionRecord_workspaceId_fkey" FOREIGN KEY ("workspaceId") REFERENCES "ScholarshipWorkspace"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "FundingDecisionRecord" ADD CONSTRAINT "FundingDecisionRecord_admissionDecisionId_fkey" FOREIGN KEY ("admissionDecisionId") REFERENCES "ApplicationDecisionRecord"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "FundingDecisionRecord" ADD CONSTRAINT "FundingDecisionRecord_supersedesId_fkey" FOREIGN KEY ("supersedesId") REFERENCES "FundingDecisionRecord"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "FundingDecisionRecord" ADD CONSTRAINT "FundingDecisionRecord_evidenceId_fkey" FOREIGN KEY ("evidenceId") REFERENCES "OutcomeEvidenceAsset"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "FundingDecisionRecord" ADD CONSTRAINT "FundingDecisionRecord_verifiedById_fkey" FOREIGN KEY ("verifiedById") REFERENCES "AdminUser"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE "OutcomeEvidenceLink" ADD CONSTRAINT "OutcomeEvidenceLink_evidenceId_fkey" FOREIGN KEY ("evidenceId") REFERENCES "OutcomeEvidenceAsset"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "OutcomeEvidenceLink" ADD CONSTRAINT "OutcomeEvidenceLink_linkedByUserId_fkey" FOREIGN KEY ("linkedByUserId") REFERENCES "UserProfile"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "OutcomeVerificationEvent" ADD CONSTRAINT "OutcomeVerificationEvent_actorAdminId_fkey" FOREIGN KEY ("actorAdminId") REFERENCES "AdminUser"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
