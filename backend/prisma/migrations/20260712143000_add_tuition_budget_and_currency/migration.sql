-- Tuition budget is annual and stored canonically in EUR. Preserve existing
-- profiles by translating their previous monthly capacity into an annual value.
ALTER TABLE "UserProfile"
  ADD COLUMN "annualTuitionBudgetEur" INTEGER,
  ADD COLUMN "preferredCurrency" TEXT NOT NULL DEFAULT 'XOF';

UPDATE "UserProfile"
SET "annualTuitionBudgetEur" = "monthlyBudgetEur" * 12
WHERE "annualTuitionBudgetEur" IS NULL
  AND "monthlyBudgetEur" IS NOT NULL;
