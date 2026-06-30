ALTER TABLE "ServicePurchase"
  ADD COLUMN "source" TEXT NOT NULL DEFAULT 'checkout';

CREATE INDEX "ServicePurchase_caseId_idx"
  ON "ServicePurchase"("caseId");

CREATE INDEX "ServicePurchase_source_idx"
  ON "ServicePurchase"("source");

DELETE FROM "ServicePurchase"
WHERE "caseId" IS NOT NULL
  AND NOT EXISTS (
    SELECT 1
    FROM "Case"
    WHERE "Case"."id" = "ServicePurchase"."caseId"
  );

ALTER TABLE "ServicePurchase"
  ADD CONSTRAINT "ServicePurchase_caseId_fkey"
  FOREIGN KEY ("caseId") REFERENCES "Case"("id")
  ON DELETE SET NULL ON UPDATE CASCADE;
