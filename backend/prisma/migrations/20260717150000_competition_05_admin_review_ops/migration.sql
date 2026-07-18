-- Link an authenticated admin account to at most one counsellor profile.
-- Nullable by design: existing accounts are not linked automatically because
-- operational identity matches must be reviewed by KPB.
ALTER TABLE "Counsellor" ADD COLUMN "adminUserId" TEXT;

CREATE UNIQUE INDEX "Counsellor_adminUserId_key" ON "Counsellor"("adminUserId");

ALTER TABLE "Counsellor"
ADD CONSTRAINT "Counsellor_adminUserId_fkey"
FOREIGN KEY ("adminUserId") REFERENCES "AdminUser"("id")
ON DELETE SET NULL ON UPDATE CASCADE;
