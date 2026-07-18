-- CreateEnum
CREATE TYPE "ScholarshipWorkspaceStatus" AS ENUM ('started', 'preparing', 'ready_for_review', 'review_requested', 'submitted', 'decision_received', 'archived');

-- CreateEnum
CREATE TYPE "WorkspaceStepStatus" AS ENUM ('not_started', 'in_progress', 'completed', 'not_applicable');

-- CreateEnum
CREATE TYPE "WorkspaceStepCategory" AS ENUM ('profile_eligibility', 'documents', 'form_and_essays', 'review_and_submission');

-- CreateTable
CREATE TABLE "ScholarshipWorkspace" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "scholarshipId" TEXT NOT NULL,
    "scholarshipCycleId" TEXT NOT NULL,
    "status" "ScholarshipWorkspaceStatus" NOT NULL DEFAULT 'started',
    "version" INTEGER NOT NULL DEFAULT 1,
    "readinessPercent" INTEGER NOT NULL DEFAULT 0,
    "startedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "lastActivityAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "submittedAt" TIMESTAMP(3),
    "decisionReceivedAt" TIMESTAMP(3),
    "archivedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "ScholarshipWorkspace_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ScholarshipWorkspaceStep" (
    "id" TEXT NOT NULL,
    "workspaceId" TEXT NOT NULL,
    "sourceStepId" TEXT,
    "code" TEXT NOT NULL,
    "titleFr" TEXT NOT NULL,
    "titleEn" TEXT NOT NULL,
    "category" "WorkspaceStepCategory" NOT NULL,
    "weight" INTEGER NOT NULL,
    "isRequired" BOOLEAN NOT NULL DEFAULT true,
    "templateVersion" TEXT NOT NULL,
    "status" "WorkspaceStepStatus" NOT NULL DEFAULT 'not_started',
    "notApplicableReason" TEXT,
    "completedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "ScholarshipWorkspaceStep_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "ScholarshipWorkspace_userId_status_lastActivityAt_idx" ON "ScholarshipWorkspace"("userId", "status", "lastActivityAt");

-- CreateIndex
CREATE INDEX "ScholarshipWorkspace_scholarshipCycleId_status_idx" ON "ScholarshipWorkspace"("scholarshipCycleId", "status");

-- CreateIndex
CREATE UNIQUE INDEX "ScholarshipWorkspace_userId_scholarshipId_scholarshipCycleI_key" ON "ScholarshipWorkspace"("userId", "scholarshipId", "scholarshipCycleId");

-- CreateIndex
CREATE INDEX "ScholarshipWorkspaceStep_workspaceId_status_idx" ON "ScholarshipWorkspaceStep"("workspaceId", "status");

-- CreateIndex
CREATE UNIQUE INDEX "ScholarshipWorkspaceStep_workspaceId_code_key" ON "ScholarshipWorkspaceStep"("workspaceId", "code");

-- AddForeignKey
ALTER TABLE "ScholarshipWorkspace" ADD CONSTRAINT "ScholarshipWorkspace_userId_fkey" FOREIGN KEY ("userId") REFERENCES "UserProfile"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ScholarshipWorkspace" ADD CONSTRAINT "ScholarshipWorkspace_scholarshipId_fkey" FOREIGN KEY ("scholarshipId") REFERENCES "Scholarship"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ScholarshipWorkspace" ADD CONSTRAINT "ScholarshipWorkspace_scholarshipCycleId_fkey" FOREIGN KEY ("scholarshipCycleId") REFERENCES "ScholarshipCycle"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ScholarshipWorkspaceStep" ADD CONSTRAINT "ScholarshipWorkspaceStep_workspaceId_fkey" FOREIGN KEY ("workspaceId") REFERENCES "ScholarshipWorkspace"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ScholarshipWorkspaceStep" ADD CONSTRAINT "ScholarshipWorkspaceStep_sourceStepId_fkey" FOREIGN KEY ("sourceStepId") REFERENCES "ScholarshipApplicationStep"("id") ON DELETE SET NULL ON UPDATE CASCADE;
