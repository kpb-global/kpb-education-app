-- CreateEnum
CREATE TYPE "AiDiagnosticStatus" AS ENUM ('pending', 'running', 'succeeded', 'deterministic_fallback', 'failed', 'blocked');

-- CreateTable
CREATE TABLE "AiDiagnostic" (
    "id" TEXT NOT NULL,
    "workspaceId" TEXT NOT NULL,
    "artifactVersionId" TEXT,
    "entitlementKey" TEXT NOT NULL,
    "status" "AiDiagnosticStatus" NOT NULL DEFAULT 'pending',
    "documentKind" "ApplicationArtifactKind",
    "generatedLanguage" TEXT,
    "strength" TEXT,
    "priorityImprovement" TEXT,
    "rationale" TEXT,
    "nextAction" TEXT,
    "criterionReferences" JSONB,
    "inputFingerprint" TEXT,
    "workspaceVersion" INTEGER,
    "criteriaVersion" TEXT,
    "artifactSha256" TEXT,
    "provider" TEXT,
    "model" TEXT,
    "promptVersion" TEXT NOT NULL,
    "fallbackReason" TEXT,
    "startedAt" TIMESTAMP(3),
    "completedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "AiDiagnostic_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "AiUsageAttempt" (
    "id" TEXT NOT NULL,
    "diagnosticId" TEXT,
    "actorKey" TEXT,
    "attemptKey" TEXT NOT NULL,
    "attemptNumber" INTEGER NOT NULL,
    "feature" TEXT NOT NULL,
    "provider" TEXT NOT NULL,
    "model" TEXT NOT NULL,
    "promptVersion" TEXT NOT NULL,
    "priceVersion" TEXT,
    "usageSource" TEXT,
    "inputTokens" INTEGER,
    "cachedInputTokens" INTEGER,
    "outputTokens" INTEGER,
    "totalTokens" INTEGER,
    "latencyMs" INTEGER,
    "estimatedCostMicrosUsd" BIGINT,
    "providerRequestId" TEXT,
    "outcome" TEXT NOT NULL,
    "errorCode" TEXT,
    "lockedBy" TEXT,
    "leaseExpiresAt" TIMESTAMP(3),
    "startedAt" TIMESTAMP(3),
    "completedAt" TIMESTAMP(3),
    "nextAttemptAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "AiUsageAttempt_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "AiUsageAttempt_positive_attempt_check" CHECK ("attemptNumber" > 0),
    CONSTRAINT "AiUsageAttempt_nonnegative_usage_check" CHECK (
      ("inputTokens" IS NULL OR "inputTokens" >= 0) AND
      ("cachedInputTokens" IS NULL OR "cachedInputTokens" >= 0) AND
      ("outputTokens" IS NULL OR "outputTokens" >= 0) AND
      ("totalTokens" IS NULL OR "totalTokens" >= 0) AND
      ("estimatedCostMicrosUsd" IS NULL OR "estimatedCostMicrosUsd" >= 0)
    )
);

CREATE TABLE "AiQuotaBucket" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "feature" TEXT NOT NULL,
    "periodKey" TEXT NOT NULL,
    "quotaLimit" INTEGER NOT NULL,
    "used" INTEGER NOT NULL DEFAULT 0,
    "resetsAt" TIMESTAMP(3) NOT NULL,
    "version" INTEGER NOT NULL DEFAULT 1,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "AiQuotaBucket_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "AiQuotaBucket_bounds_check" CHECK ("quotaLimit" >= 0 AND "used" >= 0 AND "used" <= "quotaLimit")
);

CREATE TABLE "AiBudgetPeriod" (
    "id" TEXT NOT NULL,
    "feature" TEXT NOT NULL,
    "periodKey" TEXT NOT NULL,
    "budgetMicrosUsd" BIGINT NOT NULL,
    "reservedMicrosUsd" BIGINT NOT NULL DEFAULT 0,
    "spentMicrosUsd" BIGINT NOT NULL DEFAULT 0,
    "version" INTEGER NOT NULL DEFAULT 1,
    "startsAt" TIMESTAMP(3) NOT NULL,
    "endsAt" TIMESTAMP(3) NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "AiBudgetPeriod_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "AiBudgetPeriod_bounds_check" CHECK (
      "budgetMicrosUsd" >= 0 AND "reservedMicrosUsd" >= 0 AND "spentMicrosUsd" >= 0 AND
      "reservedMicrosUsd" + "spentMicrosUsd" <= "budgetMicrosUsd"
    ),
    CONSTRAINT "AiBudgetPeriod_dates_check" CHECK ("endsAt" > "startsAt")
);

CREATE TABLE "AiBudgetTransaction" (
    "id" TEXT NOT NULL,
    "budgetPeriodId" TEXT NOT NULL,
    "diagnosticId" TEXT,
    "dedupeKey" TEXT NOT NULL,
    "reason" TEXT NOT NULL,
    "reservedDeltaMicrosUsd" BIGINT NOT NULL DEFAULT 0,
    "spentDeltaMicrosUsd" BIGINT NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "AiBudgetTransaction_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "AiModelPrice" (
    "id" TEXT NOT NULL,
    "priceVersion" TEXT NOT NULL,
    "provider" TEXT NOT NULL,
    "model" TEXT NOT NULL,
    "inputMicrosUsdPerM" BIGINT NOT NULL,
    "cachedInputMicrosUsdPerM" BIGINT,
    "outputMicrosUsdPerM" BIGINT NOT NULL,
    "effectiveAt" TIMESTAMP(3) NOT NULL,
    "retiredAt" TIMESTAMP(3),
    "sourceUrl" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "AiModelPrice_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "AiModelPrice_nonnegative_rates_check" CHECK (
      "inputMicrosUsdPerM" >= 0 AND
      ("cachedInputMicrosUsdPerM" IS NULL OR "cachedInputMicrosUsdPerM" >= 0) AND
      "outputMicrosUsdPerM" >= 0
    )
);

CREATE TABLE "AiInvoiceReconciliation" (
    "id" TEXT NOT NULL,
    "provider" TEXT NOT NULL,
    "periodKey" TEXT NOT NULL,
    "calculatedMicrosUsd" BIGINT NOT NULL,
    "invoicedMicrosUsd" BIGINT NOT NULL,
    "varianceBps" INTEGER NOT NULL,
    "invoiceReference" TEXT,
    "reconciledByAdminId" TEXT,
    "reconciledAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "AiInvoiceReconciliation_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "AiInvoiceReconciliation_nonnegative_cost_check" CHECK ("calculatedMicrosUsd" >= 0 AND "invoicedMicrosUsd" >= 0)
);

-- CreateIndex
CREATE UNIQUE INDEX "AiDiagnostic_entitlementKey_key" ON "AiDiagnostic"("entitlementKey");
CREATE INDEX "AiDiagnostic_workspaceId_createdAt_idx" ON "AiDiagnostic"("workspaceId", "createdAt");
CREATE INDEX "AiDiagnostic_status_createdAt_idx" ON "AiDiagnostic"("status", "createdAt");

CREATE UNIQUE INDEX "AiUsageAttempt_attemptKey_key" ON "AiUsageAttempt"("attemptKey");
CREATE UNIQUE INDEX "AiUsageAttempt_diagnosticId_attemptNumber_key" ON "AiUsageAttempt"("diagnosticId", "attemptNumber");
CREATE INDEX "AiUsageAttempt_feature_createdAt_idx" ON "AiUsageAttempt"("feature", "createdAt");
CREATE INDEX "AiUsageAttempt_provider_model_createdAt_idx" ON "AiUsageAttempt"("provider", "model", "createdAt");
CREATE INDEX "AiUsageAttempt_outcome_createdAt_idx" ON "AiUsageAttempt"("outcome", "createdAt");
CREATE INDEX "AiUsageAttempt_outcome_nextAttemptAt_idx" ON "AiUsageAttempt"("outcome", "nextAttemptAt");

CREATE UNIQUE INDEX "AiQuotaBucket_userId_feature_periodKey_key" ON "AiQuotaBucket"("userId", "feature", "periodKey");
CREATE INDEX "AiQuotaBucket_feature_resetsAt_idx" ON "AiQuotaBucket"("feature", "resetsAt");

CREATE UNIQUE INDEX "AiBudgetPeriod_feature_periodKey_key" ON "AiBudgetPeriod"("feature", "periodKey");
CREATE INDEX "AiBudgetPeriod_feature_endsAt_idx" ON "AiBudgetPeriod"("feature", "endsAt");

CREATE UNIQUE INDEX "AiBudgetTransaction_dedupeKey_key" ON "AiBudgetTransaction"("dedupeKey");
CREATE INDEX "AiBudgetTransaction_budgetPeriodId_createdAt_idx" ON "AiBudgetTransaction"("budgetPeriodId", "createdAt");
CREATE INDEX "AiBudgetTransaction_diagnosticId_idx" ON "AiBudgetTransaction"("diagnosticId");

CREATE UNIQUE INDEX "AiModelPrice_priceVersion_key" ON "AiModelPrice"("priceVersion");
CREATE INDEX "AiModelPrice_provider_model_effectiveAt_idx" ON "AiModelPrice"("provider", "model", "effectiveAt");

CREATE UNIQUE INDEX "AiInvoiceReconciliation_provider_periodKey_key" ON "AiInvoiceReconciliation"("provider", "periodKey");

-- AddForeignKey
ALTER TABLE "AiDiagnostic" ADD CONSTRAINT "AiDiagnostic_workspaceId_fkey" FOREIGN KEY ("workspaceId") REFERENCES "ScholarshipWorkspace"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "AiDiagnostic" ADD CONSTRAINT "AiDiagnostic_artifactVersionId_fkey" FOREIGN KEY ("artifactVersionId") REFERENCES "ApplicationArtifactVersion"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "AiUsageAttempt" ADD CONSTRAINT "AiUsageAttempt_diagnosticId_fkey" FOREIGN KEY ("diagnosticId") REFERENCES "AiDiagnostic"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "AiQuotaBucket" ADD CONSTRAINT "AiQuotaBucket_userId_fkey" FOREIGN KEY ("userId") REFERENCES "UserProfile"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "AiBudgetTransaction" ADD CONSTRAINT "AiBudgetTransaction_budgetPeriodId_fkey" FOREIGN KEY ("budgetPeriodId") REFERENCES "AiBudgetPeriod"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
