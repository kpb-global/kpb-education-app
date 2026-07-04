-- CreateEnum
CREATE TYPE "ApplicationRequirement" AS ENUM ('automatic', 'separate_application');

-- AlterTable
ALTER TABLE "Scholarship" ADD COLUMN     "applicationRequirement" "ApplicationRequirement" NOT NULL DEFAULT 'separate_application';

-- CreateTable
CREATE TABLE "ScholarshipApplicationStep" (
    "id" TEXT NOT NULL,
    "scholarshipId" TEXT NOT NULL,
    "stepNumber" INTEGER NOT NULL,
    "titleFr" TEXT NOT NULL,
    "titleEn" TEXT NOT NULL,
    "descriptionFr" TEXT NOT NULL DEFAULT '',
    "descriptionEn" TEXT NOT NULL DEFAULT '',
    "estimatedDurationDays" INTEGER,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "ScholarshipApplicationStep_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "ScholarshipApplicationStep_scholarshipId_idx" ON "ScholarshipApplicationStep"("scholarshipId");

-- CreateIndex
CREATE UNIQUE INDEX "ScholarshipApplicationStep_scholarshipId_stepNumber_key" ON "ScholarshipApplicationStep"("scholarshipId", "stepNumber");

-- AddForeignKey
ALTER TABLE "ScholarshipApplicationStep" ADD CONSTRAINT "ScholarshipApplicationStep_scholarshipId_fkey" FOREIGN KEY ("scholarshipId") REFERENCES "Scholarship"("id") ON DELETE CASCADE ON UPDATE CASCADE;
