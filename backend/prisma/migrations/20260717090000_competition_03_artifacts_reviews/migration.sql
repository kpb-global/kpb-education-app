-- CreateEnum
CREATE TYPE "ApplicationArtifactKind" AS ENUM ('cv', 'motivation_letter', 'essay', 'recommendation_letter', 'transcript', 'diploma', 'language_test', 'passport', 'portfolio', 'other');

-- CreateEnum
CREATE TYPE "ArtifactProcessingStatus" AS ENUM ('pending_upload', 'uploaded', 'scanning', 'clean', 'rejected', 'extraction_failed', 'deleted');

-- CreateEnum
CREATE TYPE "StudyReviewStatus" AS ENUM ('draft', 'submitted', 'triaged', 'more_information_needed', 'call_offered', 'scheduled', 'converted_to_case', 'autonomy_recommended', 'declined', 'closed');

-- CreateTable
CREATE TABLE "ApplicationArtifact" (
    "id" TEXT NOT NULL,
    "workspaceId" TEXT NOT NULL,
    "kind" "ApplicationArtifactKind" NOT NULL,
    "title" TEXT NOT NULL,
    "currentVersionId" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "ApplicationArtifact_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ApplicationArtifactVersion" (
    "id" TEXT NOT NULL,
    "artifactId" TEXT NOT NULL,
    "versionNumber" INTEGER NOT NULL,
    "storageKey" TEXT,
    "originalFileName" TEXT NOT NULL,
    "mimeType" TEXT NOT NULL,
    "sizeBytes" INTEGER NOT NULL,
    "sha256" TEXT NOT NULL,
    "processingStatus" "ArtifactProcessingStatus" NOT NULL DEFAULT 'pending_upload',
    "extractedText" TEXT,
    "rejectionCode" TEXT,
    "uploadedAt" TIMESTAMP(3),
    "deletedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ApplicationArtifactVersion_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "ApplicationArtifactVersion_positive_version_check" CHECK ("versionNumber" > 0),
    CONSTRAINT "ApplicationArtifactVersion_positive_size_check" CHECK ("sizeBytes" > 0),
    CONSTRAINT "ApplicationArtifactVersion_sha256_check" CHECK ("sha256" ~ '^[0-9a-f]{64}$'),
    CONSTRAINT "ApplicationArtifactVersion_clean_key_check" CHECK ("processingStatus" <> 'clean' OR "storageKey" IS NOT NULL)
);

-- CreateTable
CREATE TABLE "StudyReviewRequest" (
    "id" TEXT NOT NULL,
    "workspaceId" TEXT NOT NULL,
    "requestNumber" INTEGER NOT NULL,
    "version" INTEGER NOT NULL DEFAULT 1,
    "status" "StudyReviewStatus" NOT NULL DEFAULT 'draft',
    "assignedCounsellorId" TEXT,
    "studentMessage" TEXT,
    "preferredContact" TEXT,
    "timezone" TEXT NOT NULL DEFAULT 'UTC',
    "availability" JSONB,
    "triageSummary" TEXT,
    "missingItems" JSONB,
    "submittedAt" TIMESTAMP(3),
    "triagedAt" TIMESTAMP(3),
    "closedAt" TIMESTAMP(3),
    "resultingCaseId" TEXT,
    "resultingPurchaseId" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "StudyReviewRequest_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "StudyReviewRequest_positive_number_check" CHECK ("requestNumber" > 0),
    CONSTRAINT "StudyReviewRequest_positive_version_check" CHECK ("version" > 0)
);

-- CreateTable
CREATE TABLE "StudyReviewArtifactShare" (
    "id" TEXT NOT NULL,
    "reviewRequestId" TEXT NOT NULL,
    "artifactVersionId" TEXT NOT NULL,
    "consentReceiptId" TEXT NOT NULL,
    "grantedByUserId" TEXT NOT NULL,
    "grantedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "revokedAt" TIMESTAMP(3),

    CONSTRAINT "StudyReviewArtifactShare_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "ApplicationArtifact_currentVersionId_key" ON "ApplicationArtifact"("currentVersionId");
CREATE INDEX "ApplicationArtifact_workspaceId_kind_idx" ON "ApplicationArtifact"("workspaceId", "kind");
CREATE UNIQUE INDEX "ApplicationArtifact_workspaceId_kind_title_key" ON "ApplicationArtifact"("workspaceId", "kind", "title");

-- CreateIndex
CREATE UNIQUE INDEX "ApplicationArtifactVersion_storageKey_key" ON "ApplicationArtifactVersion"("storageKey");
CREATE INDEX "ApplicationArtifactVersion_artifactId_createdAt_idx" ON "ApplicationArtifactVersion"("artifactId", "createdAt");
CREATE INDEX "ApplicationArtifactVersion_processingStatus_idx" ON "ApplicationArtifactVersion"("processingStatus");
CREATE UNIQUE INDEX "ApplicationArtifactVersion_artifactId_versionNumber_key" ON "ApplicationArtifactVersion"("artifactId", "versionNumber");

-- CreateIndex
CREATE UNIQUE INDEX "StudyReviewRequest_resultingCaseId_key" ON "StudyReviewRequest"("resultingCaseId");
CREATE UNIQUE INDEX "StudyReviewRequest_resultingPurchaseId_key" ON "StudyReviewRequest"("resultingPurchaseId");
CREATE INDEX "StudyReviewRequest_status_submittedAt_idx" ON "StudyReviewRequest"("status", "submittedAt");
CREATE INDEX "StudyReviewRequest_assignedCounsellorId_status_idx" ON "StudyReviewRequest"("assignedCounsellorId", "status");
CREATE UNIQUE INDEX "StudyReviewRequest_workspaceId_requestNumber_key" ON "StudyReviewRequest"("workspaceId", "requestNumber");

-- Database-level concurrency guard: at most one non-closed request per workspace.
CREATE UNIQUE INDEX "one_open_review_request_per_workspace"
ON "StudyReviewRequest" ("workspaceId") WHERE "status" <> 'closed';

-- CreateIndex
CREATE INDEX "StudyReviewArtifactShare_artifactVersionId_revokedAt_idx" ON "StudyReviewArtifactShare"("artifactVersionId", "revokedAt");
CREATE UNIQUE INDEX "StudyReviewArtifactShare_reviewRequestId_artifactVersionId_key" ON "StudyReviewArtifactShare"("reviewRequestId", "artifactVersionId");

-- AddForeignKey
ALTER TABLE "ApplicationArtifact" ADD CONSTRAINT "ApplicationArtifact_workspaceId_fkey" FOREIGN KEY ("workspaceId") REFERENCES "ScholarshipWorkspace"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "ApplicationArtifact" ADD CONSTRAINT "ApplicationArtifact_currentVersionId_fkey" FOREIGN KEY ("currentVersionId") REFERENCES "ApplicationArtifactVersion"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "ApplicationArtifactVersion" ADD CONSTRAINT "ApplicationArtifactVersion_artifactId_fkey" FOREIGN KEY ("artifactId") REFERENCES "ApplicationArtifact"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "StudyReviewRequest" ADD CONSTRAINT "StudyReviewRequest_workspaceId_fkey" FOREIGN KEY ("workspaceId") REFERENCES "ScholarshipWorkspace"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "StudyReviewRequest" ADD CONSTRAINT "StudyReviewRequest_assignedCounsellorId_fkey" FOREIGN KEY ("assignedCounsellorId") REFERENCES "Counsellor"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "StudyReviewRequest" ADD CONSTRAINT "StudyReviewRequest_resultingCaseId_fkey" FOREIGN KEY ("resultingCaseId") REFERENCES "Case"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "StudyReviewRequest" ADD CONSTRAINT "StudyReviewRequest_resultingPurchaseId_fkey" FOREIGN KEY ("resultingPurchaseId") REFERENCES "ServicePurchase"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "StudyReviewArtifactShare" ADD CONSTRAINT "StudyReviewArtifactShare_reviewRequestId_fkey" FOREIGN KEY ("reviewRequestId") REFERENCES "StudyReviewRequest"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "StudyReviewArtifactShare" ADD CONSTRAINT "StudyReviewArtifactShare_artifactVersionId_fkey" FOREIGN KEY ("artifactVersionId") REFERENCES "ApplicationArtifactVersion"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "StudyReviewArtifactShare" ADD CONSTRAINT "StudyReviewArtifactShare_consentReceiptId_fkey" FOREIGN KEY ("consentReceiptId") REFERENCES "ConsentReceipt"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
