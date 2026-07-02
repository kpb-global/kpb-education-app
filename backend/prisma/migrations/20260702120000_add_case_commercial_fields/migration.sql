-- M9 commercial ops fields on "Case".
-- These columns exist in schema.prisma (added in commit 9197e01) but were never
-- captured in a migration, so `prisma migrate deploy` provisioned a schema
-- without them and every query on Case failed with "column ... does not exist".
ALTER TABLE "Case"
  ADD COLUMN "leadTag" TEXT,
  ADD COLUMN "discussionMotive" TEXT,
  ADD COLUMN "lastCommercialInteractionAt" TIMESTAMP(3);

-- Supports the commercial pipeline groupBy/filter on leadTag
-- (admin-dashboard.service.ts: groupBy where leadTag IS NOT NULL).
CREATE INDEX "Case_leadTag_idx" ON "Case"("leadTag");
