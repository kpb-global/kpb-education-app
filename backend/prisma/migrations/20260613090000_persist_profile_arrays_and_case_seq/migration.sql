-- Persist per-user interest selections that previously lived in a shared
-- in-memory singleton (cross-tenant leak). Existing rows backfill to empty.
ALTER TABLE "UserProfile" ADD COLUMN     "fieldIds" TEXT[] DEFAULT ARRAY[]::TEXT[],
ADD COLUMN     "targetCountryIds" TEXT[] DEFAULT ARRAY[]::TEXT[],
ADD COLUMN     "availableDocuments" TEXT[] DEFAULT ARRAY[]::TEXT[];

-- DB-assigned monotonic counter for collision-free case reference codes.
-- SERIAL backfills existing rows sequentially and drives future inserts.
ALTER TABLE "Case" ADD COLUMN     "seq" SERIAL NOT NULL;

-- CreateIndex
CREATE UNIQUE INDEX "Case_seq_key" ON "Case"("seq");
