-- CreateEnum
CREATE TYPE "ScholarshipCycleStatus" AS ENUM ('forecast', 'open', 'closed', 'suspended');

-- CreateEnum
CREATE TYPE "ScholarshipDateConfidence" AS ENUM ('estimated', 'confirmed');

-- CreateTable
CREATE TABLE "ScholarshipCycle" (
    "id" TEXT NOT NULL,
    "scholarshipId" TEXT NOT NULL,
    "academicYear" TEXT NOT NULL,
    "status" "ScholarshipCycleStatus" NOT NULL DEFAULT 'forecast',
    "dateConfidence" "ScholarshipDateConfidence" NOT NULL DEFAULT 'estimated',
    "estimatedOpenAt" TIMESTAMP(3),
    "estimatedCloseAt" TIMESTAMP(3),
    "opensAt" TIMESTAMP(3),
    "closesAt" TIMESTAMP(3),
    "sourceUrl" TEXT,
    "verifiedAt" TIMESTAMP(3),
    "activatedAt" TIMESTAMP(3),
    "activationKey" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "ScholarshipCycle_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ScholarshipAlertSubscription" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "scholarshipId" TEXT NOT NULL,
    "pushEnabled" BOOLEAN NOT NULL DEFAULT true,
    "inAppEnabled" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "ScholarshipAlertSubscription_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "UserNotification" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "scholarshipId" TEXT,
    "kind" TEXT NOT NULL,
    "dedupeKey" TEXT NOT NULL,
    "titleFr" TEXT NOT NULL,
    "titleEn" TEXT NOT NULL,
    "bodyFr" TEXT NOT NULL,
    "bodyEn" TEXT NOT NULL,
    "route" TEXT NOT NULL,
    "data" JSONB,
    "readAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "UserNotification_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "ScholarshipCycle_activationKey_key" ON "ScholarshipCycle"("activationKey");
CREATE UNIQUE INDEX "ScholarshipCycle_scholarshipId_academicYear_key" ON "ScholarshipCycle"("scholarshipId", "academicYear");
CREATE INDEX "ScholarshipCycle_scholarshipId_status_idx" ON "ScholarshipCycle"("scholarshipId", "status");
CREATE INDEX "ScholarshipCycle_estimatedOpenAt_idx" ON "ScholarshipCycle"("estimatedOpenAt");
CREATE INDEX "ScholarshipCycle_opensAt_idx" ON "ScholarshipCycle"("opensAt");
CREATE INDEX "ScholarshipCycle_closesAt_idx" ON "ScholarshipCycle"("closesAt");
CREATE UNIQUE INDEX "ScholarshipAlertSubscription_userId_scholarshipId_key" ON "ScholarshipAlertSubscription"("userId", "scholarshipId");
CREATE INDEX "ScholarshipAlertSubscription_userId_idx" ON "ScholarshipAlertSubscription"("userId");
CREATE INDEX "ScholarshipAlertSubscription_scholarshipId_idx" ON "ScholarshipAlertSubscription"("scholarshipId");
CREATE UNIQUE INDEX "UserNotification_dedupeKey_key" ON "UserNotification"("dedupeKey");
CREATE INDEX "UserNotification_userId_createdAt_idx" ON "UserNotification"("userId", "createdAt");
CREATE INDEX "UserNotification_userId_readAt_idx" ON "UserNotification"("userId", "readAt");
CREATE INDEX "UserNotification_scholarshipId_idx" ON "UserNotification"("scholarshipId");

-- AddForeignKey
ALTER TABLE "ScholarshipCycle" ADD CONSTRAINT "ScholarshipCycle_scholarshipId_fkey" FOREIGN KEY ("scholarshipId") REFERENCES "Scholarship"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "ScholarshipAlertSubscription" ADD CONSTRAINT "ScholarshipAlertSubscription_userId_fkey" FOREIGN KEY ("userId") REFERENCES "UserProfile"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "ScholarshipAlertSubscription" ADD CONSTRAINT "ScholarshipAlertSubscription_scholarshipId_fkey" FOREIGN KEY ("scholarshipId") REFERENCES "Scholarship"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "UserNotification" ADD CONSTRAINT "UserNotification_userId_fkey" FOREIGN KEY ("userId") REFERENCES "UserProfile"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "UserNotification" ADD CONSTRAINT "UserNotification_scholarshipId_fkey" FOREIGN KEY ("scholarshipId") REFERENCES "Scholarship"("id") ON DELETE SET NULL ON UPDATE CASCADE;
