-- CreateEnum
CREATE TYPE "FundingType" AS ENUM ('fully_funded', 'partially_funded', 'unknown');

-- DropForeignKey
ALTER TABLE "CounsellorReview" DROP CONSTRAINT "CounsellorReview_counsellorId_fkey";

-- DropForeignKey
ALTER TABLE "ParentChildLink" DROP CONSTRAINT "ParentChildLink_childId_fkey";

-- DropForeignKey
ALTER TABLE "ParentChildLink" DROP CONSTRAINT "ParentChildLink_parentId_fkey";

-- DropForeignKey
ALTER TABLE "PaymentIntent" DROP CONSTRAINT "PaymentIntent_userId_fkey";

-- DropForeignKey
ALTER TABLE "SalonRegistration" DROP CONSTRAINT "SalonRegistration_sessionId_fkey";

-- DropForeignKey
ALTER TABLE "SalonRegistration" DROP CONSTRAINT "SalonRegistration_userId_fkey";

-- DropForeignKey
ALTER TABLE "SalonSession" DROP CONSTRAINT "SalonSession_eventId_fkey";

-- AlterTable
ALTER TABLE "AdminUser" ADD COLUMN     "passwordHash" TEXT,
ADD COLUMN     "refreshToken" TEXT;

-- AlterTable
ALTER TABLE "Scholarship" ADD COLUMN     "academyCourseId" TEXT,
ADD COLUMN     "advantagesEn" TEXT[] DEFAULT ARRAY[]::TEXT[],
ADD COLUMN     "advantagesFr" TEXT[] DEFAULT ARRAY[]::TEXT[],
ADD COLUMN     "countryNameEn" TEXT NOT NULL DEFAULT '',
ADD COLUMN     "countryNameFr" TEXT NOT NULL DEFAULT '',
ADD COLUMN     "descriptionEn" TEXT NOT NULL DEFAULT '',
ADD COLUMN     "descriptionFr" TEXT NOT NULL DEFAULT '',
ADD COLUMN     "eligibilityEn" TEXT[] DEFAULT ARRAY[]::TEXT[],
ADD COLUMN     "eligibilityFr" TEXT[] DEFAULT ARRAY[]::TEXT[],
ADD COLUMN     "fundingType" "FundingType" NOT NULL DEFAULT 'unknown';

-- CreateTable
CREATE TABLE "AcademyCourse" (
    "id" TEXT NOT NULL,
    "titleFr" TEXT NOT NULL,
    "titleEn" TEXT NOT NULL,
    "descriptionFr" TEXT NOT NULL,
    "descriptionEn" TEXT NOT NULL,
    "coverImageUrl" TEXT,
    "priceXOF" INTEGER NOT NULL,
    "priceEUR" DOUBLE PRECISION NOT NULL,
    "status" "PublicationStatus" NOT NULL DEFAULT 'draft',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "AcademyCourse_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "AcademyLesson" (
    "id" TEXT NOT NULL,
    "courseId" TEXT NOT NULL,
    "titleFr" TEXT NOT NULL,
    "titleEn" TEXT NOT NULL,
    "videoUrl" TEXT NOT NULL,
    "durationSeconds" INTEGER NOT NULL,
    "order" INTEGER NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "AcademyLesson_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "AcademyPurchase" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "courseId" TEXT NOT NULL,
    "transactionId" TEXT,
    "amountPaid" DOUBLE PRECISION NOT NULL,
    "currency" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "AcademyPurchase_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "Appointment_userId_idx" ON "Appointment"("userId");

-- CreateIndex
CREATE INDEX "Appointment_caseId_idx" ON "Appointment"("caseId");

-- CreateIndex
CREATE INDEX "Case_userId_idx" ON "Case"("userId");

-- CreateIndex
CREATE INDEX "Case_status_idx" ON "Case"("status");

-- CreateIndex
CREATE INDEX "Case_createdAt_idx" ON "Case"("createdAt");

-- CreateIndex
CREATE INDEX "Case_type_idx" ON "Case"("type");

-- CreateIndex
CREATE INDEX "CaseDocument_caseId_idx" ON "CaseDocument"("caseId");

-- CreateIndex
CREATE INDEX "CaseInternalNote_caseId_idx" ON "CaseInternalNote"("caseId");

-- CreateIndex
CREATE INDEX "CaseMessage_caseId_idx" ON "CaseMessage"("caseId");

-- CreateIndex
CREATE INDEX "CaseMessage_createdAt_idx" ON "CaseMessage"("createdAt");

-- CreateIndex
CREATE INDEX "CaseTask_caseId_idx" ON "CaseTask"("caseId");

-- CreateIndex
CREATE INDEX "CaseTimelineEvent_caseId_idx" ON "CaseTimelineEvent"("caseId");

-- CreateIndex
CREATE INDEX "DeviceToken_userProfileId_idx" ON "DeviceToken"("userProfileId");

-- CreateIndex
CREATE INDEX "Institution_countryId_idx" ON "Institution"("countryId");

-- CreateIndex
CREATE INDEX "NotificationDelivery_campaignId_idx" ON "NotificationDelivery"("campaignId");

-- CreateIndex
CREATE INDEX "NotificationDelivery_recipientId_idx" ON "NotificationDelivery"("recipientId");

-- CreateIndex
CREATE INDEX "Program_institutionId_idx" ON "Program"("institutionId");

-- CreateIndex
CREATE INDEX "Program_countryId_idx" ON "Program"("countryId");

-- CreateIndex
CREATE INDEX "Program_fieldId_idx" ON "Program"("fieldId");

-- CreateIndex
CREATE INDEX "Scholarship_countryId_idx" ON "Scholarship"("countryId");

-- CreateIndex
CREATE INDEX "Scholarship_fundingType_idx" ON "Scholarship"("fundingType");

-- CreateIndex
CREATE INDEX "UserProfile_accountType_idx" ON "UserProfile"("accountType");

-- CreateIndex
CREATE INDEX "UserProfile_createdAt_idx" ON "UserProfile"("createdAt");

-- AddForeignKey
ALTER TABLE "Scholarship" ADD CONSTRAINT "Scholarship_academyCourseId_fkey" FOREIGN KEY ("academyCourseId") REFERENCES "AcademyCourse"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "AcademyLesson" ADD CONSTRAINT "AcademyLesson_courseId_fkey" FOREIGN KEY ("courseId") REFERENCES "AcademyCourse"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "AcademyPurchase" ADD CONSTRAINT "AcademyPurchase_userId_fkey" FOREIGN KEY ("userId") REFERENCES "UserProfile"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "AcademyPurchase" ADD CONSTRAINT "AcademyPurchase_courseId_fkey" FOREIGN KEY ("courseId") REFERENCES "AcademyCourse"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CounsellorReview" ADD CONSTRAINT "CounsellorReview_counsellorId_fkey" FOREIGN KEY ("counsellorId") REFERENCES "Counsellor"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ParentChildLink" ADD CONSTRAINT "ParentChildLink_parentId_fkey" FOREIGN KEY ("parentId") REFERENCES "UserProfile"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ParentChildLink" ADD CONSTRAINT "ParentChildLink_childId_fkey" FOREIGN KEY ("childId") REFERENCES "UserProfile"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "PaymentIntent" ADD CONSTRAINT "PaymentIntent_userId_fkey" FOREIGN KEY ("userId") REFERENCES "UserProfile"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "SalonSession" ADD CONSTRAINT "SalonSession_eventId_fkey" FOREIGN KEY ("eventId") REFERENCES "SalonEvent"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "SalonRegistration" ADD CONSTRAINT "SalonRegistration_sessionId_fkey" FOREIGN KEY ("sessionId") REFERENCES "SalonSession"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "SalonRegistration" ADD CONSTRAINT "SalonRegistration_userId_fkey" FOREIGN KEY ("userId") REFERENCES "UserProfile"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
