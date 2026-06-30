-- KPB-56: track WhatsApp-originated service sales without creating PaymentIntent.

ALTER TABLE "ServicePurchase"
  ADD COLUMN IF NOT EXISTS "source" TEXT NOT NULL DEFAULT 'checkout';

CREATE INDEX IF NOT EXISTS "ServicePurchase_caseId_idx" ON "ServicePurchase"("caseId");
CREATE INDEX IF NOT EXISTS "ServicePurchase_source_idx" ON "ServicePurchase"("source");

UPDATE "ServicePurchase" sp
SET "caseId" = NULL
WHERE sp."caseId" IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM "Case" c WHERE c."id" = sp."caseId"
  );

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'ServicePurchase_caseId_fkey'
  ) THEN
    ALTER TABLE "ServicePurchase"
      ADD CONSTRAINT "ServicePurchase_caseId_fkey"
      FOREIGN KEY ("caseId") REFERENCES "Case"("id") ON DELETE SET NULL ON UPDATE CASCADE;
  END IF;
END $$;
