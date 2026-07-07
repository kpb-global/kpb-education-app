-- Phase 0 / P0-D: admission-probability matches (kit US-003/US-004).
-- Hand-written (no local `prisma migrate dev` in this environment), mirroring
-- the SQL Prisma generates for the schema.prisma changes of the same date.
-- Everything is additive: nullable Program columns + two new tables.

-- CreateEnum
CREATE TYPE "MatchZone" AS ENUM ('green', 'yellow', 'blue');

-- AlterTable
ALTER TABLE "Program" ADD COLUMN     "minGpaRequired" DOUBLE PRECISION,
ADD COLUMN     "tuitionMinEur" INTEGER,
ADD COLUMN     "applicationDeadline" TIMESTAMP(3),
ADD COLUMN     "teachingLanguages" TEXT[] DEFAULT ARRAY[]::TEXT[];

-- CreateTable
CREATE TABLE "Match" (
    "id" TEXT NOT NULL,
    "userProfileId" TEXT NOT NULL,
    "programId" TEXT NOT NULL,
    "institutionId" TEXT NOT NULL,
    "probability" DOUBLE PRECISION NOT NULL,
    "zone" "MatchZone" NOT NULL,
    "algorithmVersion" TEXT NOT NULL DEFAULT 'v1',
    "isEstimate" BOOLEAN NOT NULL DEFAULT false,
    "expiresAt" TIMESTAMP(3) NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Match_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "MatchExplanation" (
    "id" TEXT NOT NULL,
    "matchId" TEXT NOT NULL,
    "factors" JSONB NOT NULL,
    "narrativeFr" TEXT NOT NULL DEFAULT '',
    "narrativeEn" TEXT NOT NULL DEFAULT '',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "MatchExplanation_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "Match_userProfileId_idx" ON "Match"("userProfileId");

-- CreateIndex
CREATE INDEX "Match_programId_idx" ON "Match"("programId");

-- CreateIndex
CREATE INDEX "Match_expiresAt_idx" ON "Match"("expiresAt");

-- CreateIndex
CREATE UNIQUE INDEX "Match_userProfileId_programId_key" ON "Match"("userProfileId", "programId");

-- CreateIndex
CREATE UNIQUE INDEX "MatchExplanation_matchId_key" ON "MatchExplanation"("matchId");

-- AddForeignKey
ALTER TABLE "Match" ADD CONSTRAINT "Match_userProfileId_fkey" FOREIGN KEY ("userProfileId") REFERENCES "UserProfile"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "MatchExplanation" ADD CONSTRAINT "MatchExplanation_matchId_fkey" FOREIGN KEY ("matchId") REFERENCES "Match"("id") ON DELETE CASCADE ON UPDATE CASCADE;
