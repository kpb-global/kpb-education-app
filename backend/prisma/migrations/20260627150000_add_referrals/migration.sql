-- WhatsApp-native referral loop (KPB-69): stable per-student code + one row per
-- redeemed referral (referrer → referee) for attribution.
ALTER TABLE "UserProfile" ADD COLUMN     "referralCode" TEXT;

CREATE TABLE "Referral" (
    "id" TEXT NOT NULL,
    "referrerId" TEXT NOT NULL,
    "refereeProfileId" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "Referral_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "UserProfile_referralCode_key" ON "UserProfile"("referralCode");
CREATE UNIQUE INDEX "Referral_refereeProfileId_key" ON "Referral"("refereeProfileId");
CREATE INDEX "Referral_referrerId_idx" ON "Referral"("referrerId");

ALTER TABLE "Referral" ADD CONSTRAINT "Referral_referrerId_fkey" FOREIGN KEY ("referrerId") REFERENCES "UserProfile"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "Referral" ADD CONSTRAINT "Referral_refereeProfileId_fkey" FOREIGN KEY ("refereeProfileId") REFERENCES "UserProfile"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
