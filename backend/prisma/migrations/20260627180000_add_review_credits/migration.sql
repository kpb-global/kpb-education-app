-- No-cash referral rewards (KPB-77): a denormalized credit balance on the
-- profile + an append-only, signed-amount ledger. Earns (+N) fire when a
-- referee reaches the first-case milestone; spends (−N) redeem into a WhatsApp
-- advisor voucher. `dedupeKey` is UNIQUE → idempotent earns and spends.
ALTER TABLE "UserProfile" ADD COLUMN     "reviewCredits" INTEGER NOT NULL DEFAULT 0;

CREATE TYPE "CreditReason" AS ENUM ('referralFirstCase', 'reviewVoucherRedeemed', 'adminAdjust');

CREATE TABLE "CreditTransaction" (
    "id" TEXT NOT NULL,
    "profileId" TEXT NOT NULL,
    "amount" INTEGER NOT NULL,
    "reason" "CreditReason" NOT NULL,
    "dedupeKey" TEXT NOT NULL,
    "metadata" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "CreditTransaction_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "CreditTransaction_dedupeKey_key" ON "CreditTransaction"("dedupeKey");
CREATE INDEX "CreditTransaction_profileId_idx" ON "CreditTransaction"("profileId");

ALTER TABLE "CreditTransaction" ADD CONSTRAINT "CreditTransaction_profileId_fkey" FOREIGN KEY ("profileId") REFERENCES "UserProfile"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
