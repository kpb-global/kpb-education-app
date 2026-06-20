-- Data-trust signal (Sprint 1): record when each catalog fact was last verified
-- and its source. Nullable; existing rows stay NULL ("À confirmer") until a human
-- confirms them via the admin verification tool (Sprint 2).
ALTER TABLE "Country" ADD COLUMN     "lastVerifiedAt" TIMESTAMP(3),
ADD COLUMN     "sourceUrl" TEXT;

ALTER TABLE "Institution" ADD COLUMN     "lastVerifiedAt" TIMESTAMP(3),
ADD COLUMN     "sourceUrl" TEXT;

ALTER TABLE "Program" ADD COLUMN     "lastVerifiedAt" TIMESTAMP(3),
ADD COLUMN     "sourceUrl" TEXT;
