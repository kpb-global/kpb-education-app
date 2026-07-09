-- Chantier C: Parcours & Témoignages KPB.
-- Hand-written (no local `prisma migrate dev` in this environment), mirroring
-- the SQL Prisma generates for the schema.prisma changes of the same date.
-- Everything is additive: one new enum + one new table.

-- CreateEnum
CREATE TYPE "ParcoursKind" AS ENUM ('video', 'text');

-- CreateTable
CREATE TABLE "ParcoursStory" (
    "id" TEXT NOT NULL,
    "slug" TEXT NOT NULL,
    "kind" "ParcoursKind" NOT NULL DEFAULT 'video',
    "fieldId" TEXT,
    "tags" TEXT[] DEFAULT ARRAY[]::TEXT[],
    "personName" TEXT NOT NULL DEFAULT '',
    "roleFr" TEXT NOT NULL DEFAULT '',
    "roleEn" TEXT NOT NULL DEFAULT '',
    "titleFr" TEXT NOT NULL,
    "titleEn" TEXT NOT NULL,
    "hookFr" TEXT NOT NULL DEFAULT '',
    "hookEn" TEXT NOT NULL DEFAULT '',
    "summaryFr" TEXT NOT NULL DEFAULT '',
    "summaryEn" TEXT NOT NULL DEFAULT '',
    "thumbnailUrl" TEXT NOT NULL DEFAULT '',
    "photoUrl" TEXT NOT NULL DEFAULT '',
    "youtubeId" TEXT,
    "durationMinutes" INTEGER,
    "interviewFr" JSONB,
    "interviewEn" JSONB,
    "status" "PublicationStatus" NOT NULL DEFAULT 'published',
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "featured" BOOLEAN NOT NULL DEFAULT false,
    "displayOrder" INTEGER NOT NULL DEFAULT 0,
    "popularity" INTEGER NOT NULL DEFAULT 0,
    "source" TEXT NOT NULL DEFAULT 'manual',
    "publishedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "ParcoursStory_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "ParcoursStory_slug_key" ON "ParcoursStory"("slug");

-- CreateIndex
CREATE INDEX "ParcoursStory_kind_isActive_idx" ON "ParcoursStory"("kind", "isActive");

-- CreateIndex
CREATE INDEX "ParcoursStory_status_idx" ON "ParcoursStory"("status");

-- CreateIndex
CREATE INDEX "ParcoursStory_fieldId_idx" ON "ParcoursStory"("fieldId");

-- CreateIndex
CREATE INDEX "ParcoursStory_displayOrder_idx" ON "ParcoursStory"("displayOrder");
