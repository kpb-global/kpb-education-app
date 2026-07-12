-- Growth & Parrainage — Ambassadeur cash program (App-engagement handoff, US-032→035).
-- Hand-written (no local `prisma migrate dev`), mirroring the schema.prisma
-- changes of the same date. Additive: 5 enums + 4 tables.

-- CreateEnum
CREATE TYPE "ReferralStatus" AS ENUM ('signed_up', 'quiz_completed', 'application_created', 'premium_subscribed', 'placed', 'churned');
CREATE TYPE "CommissionReason" AS ENUM ('referral_signup', 'referral_premium', 'referral_placed', 'referral_scholarship', 'bonus_leaderboard');
CREATE TYPE "WithdrawalMethod" AS ENUM ('wave', 'money_fusion', 'orange_money', 'bank_transfer');
CREATE TYPE "WithdrawalStatus" AS ENUM ('requested', 'processing', 'completed', 'failed', 'rejected');
CREATE TYPE "KycStatus" AS ENUM ('pending', 'verified', 'rejected');

-- CreateTable
CREATE TABLE "Ambassador" (
    "id" TEXT NOT NULL,
    "userProfileId" TEXT NOT NULL,
    "code" TEXT NOT NULL,
    "displayName" TEXT NOT NULL DEFAULT '',
    "campus" TEXT NOT NULL DEFAULT '',
    "city" TEXT NOT NULL DEFAULT '',
    "payoutMethod" "WithdrawalMethod" NOT NULL DEFAULT 'wave',
    "payoutAccount" TEXT NOT NULL DEFAULT '',
    "kycStatus" "KycStatus" NOT NULL DEFAULT 'pending',
    "monthlyObjective" INTEGER NOT NULL DEFAULT 15,
    "monthlyBonusFCFA" INTEGER NOT NULL DEFAULT 10000,
    "totalReferrals" INTEGER NOT NULL DEFAULT 0,
    "totalCommissionsFCFA" INTEGER NOT NULL DEFAULT 0,
    "activatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Ambassador_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "AmbassadorReferral" (
    "id" TEXT NOT NULL,
    "ambassadorId" TEXT NOT NULL,
    "refereeProfileId" TEXT NOT NULL,
    "refereeName" TEXT NOT NULL DEFAULT '',
    "status" "ReferralStatus" NOT NULL DEFAULT 'signed_up',
    "note" TEXT NOT NULL DEFAULT '',
    "signedUpAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "quizCompletedAt" TIMESTAMP(3),
    "applicationCreatedAt" TIMESTAMP(3),
    "premiumSubscribedAt" TIMESTAMP(3),
    "placedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "AmbassadorReferral_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Commission" (
    "id" TEXT NOT NULL,
    "ambassadorId" TEXT NOT NULL,
    "referralId" TEXT,
    "amountFCFA" INTEGER NOT NULL,
    "reason" "CommissionReason" NOT NULL,
    "label" TEXT NOT NULL DEFAULT '',
    "earnedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "withdrawalId" TEXT,

    CONSTRAINT "Commission_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Withdrawal" (
    "id" TEXT NOT NULL,
    "ambassadorId" TEXT NOT NULL,
    "amountFCFA" INTEGER NOT NULL,
    "method" "WithdrawalMethod" NOT NULL DEFAULT 'wave',
    "destinationAccount" TEXT NOT NULL DEFAULT '',
    "status" "WithdrawalStatus" NOT NULL DEFAULT 'requested',
    "requestedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "processedAt" TIMESTAMP(3),
    "transactionId" TEXT,

    CONSTRAINT "Withdrawal_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "Ambassador_userProfileId_key" ON "Ambassador"("userProfileId");
CREATE UNIQUE INDEX "Ambassador_code_key" ON "Ambassador"("code");
CREATE INDEX "Ambassador_city_idx" ON "Ambassador"("city");
CREATE UNIQUE INDEX "AmbassadorReferral_refereeProfileId_key" ON "AmbassadorReferral"("refereeProfileId");
CREATE INDEX "AmbassadorReferral_ambassadorId_idx" ON "AmbassadorReferral"("ambassadorId");
CREATE INDEX "AmbassadorReferral_status_idx" ON "AmbassadorReferral"("status");
CREATE INDEX "Commission_ambassadorId_earnedAt_idx" ON "Commission"("ambassadorId", "earnedAt");
CREATE INDEX "Commission_withdrawalId_idx" ON "Commission"("withdrawalId");
CREATE INDEX "Withdrawal_ambassadorId_idx" ON "Withdrawal"("ambassadorId");
CREATE INDEX "Withdrawal_status_idx" ON "Withdrawal"("status");

-- AddForeignKey
ALTER TABLE "AmbassadorReferral" ADD CONSTRAINT "AmbassadorReferral_ambassadorId_fkey" FOREIGN KEY ("ambassadorId") REFERENCES "Ambassador"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "Commission" ADD CONSTRAINT "Commission_ambassadorId_fkey" FOREIGN KEY ("ambassadorId") REFERENCES "Ambassador"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "Commission" ADD CONSTRAINT "Commission_withdrawalId_fkey" FOREIGN KEY ("withdrawalId") REFERENCES "Withdrawal"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "Withdrawal" ADD CONSTRAINT "Withdrawal_ambassadorId_fkey" FOREIGN KEY ("ambassadorId") REFERENCES "Ambassador"("id") ON DELETE CASCADE ON UPDATE CASCADE;
