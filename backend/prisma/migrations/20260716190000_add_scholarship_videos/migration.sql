-- Curated YouTube explainers attached to scholarship detail pages.
CREATE TABLE "ScholarshipVideo" (
    "id" TEXT NOT NULL,
    "scholarshipId" TEXT NOT NULL,
    "youtubeVideoId" TEXT NOT NULL,
    "titleFr" TEXT NOT NULL,
    "titleEn" TEXT NOT NULL,
    "descriptionFr" TEXT NOT NULL DEFAULT '',
    "descriptionEn" TEXT NOT NULL DEFAULT '',
    "thumbnailUrl" TEXT,
    "durationSeconds" INTEGER,
    "languageCode" TEXT NOT NULL DEFAULT 'fr',
    "youtubePublishedAt" TIMESTAMP(3),
    "status" "PublicationStatus" NOT NULL DEFAULT 'draft',
    "isFeatured" BOOLEAN NOT NULL DEFAULT false,
    "displayOrder" INTEGER NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "ScholarshipVideo_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "ScholarshipVideo_scholarshipId_youtubeVideoId_key"
ON "ScholarshipVideo"("scholarshipId", "youtubeVideoId");

CREATE INDEX "ScholarshipVideo_scholarshipId_status_displayOrder_idx"
ON "ScholarshipVideo"("scholarshipId", "status", "displayOrder");

ALTER TABLE "ScholarshipVideo"
ADD CONSTRAINT "ScholarshipVideo_scholarshipId_fkey"
FOREIGN KEY ("scholarshipId") REFERENCES "Scholarship"("id")
ON DELETE CASCADE ON UPDATE CASCADE;
