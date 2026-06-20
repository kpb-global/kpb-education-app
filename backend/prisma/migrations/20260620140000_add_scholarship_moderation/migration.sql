-- Sprint 3: moderation gate for scraped scholarships. Curated/seeded rows
-- backfill to 'approved' (stay visible); scraper inserts will set 'pending'.
CREATE TYPE "ScholarshipModeration" AS ENUM ('pending', 'approved', 'rejected');

ALTER TABLE "Scholarship" ADD COLUMN     "moderationStatus" "ScholarshipModeration" NOT NULL DEFAULT 'approved';

CREATE INDEX "Scholarship_moderationStatus_idx" ON "Scholarship"("moderationStatus");
