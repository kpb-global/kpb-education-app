-- Indicative monthly budget (EUR). Powers eligibility scoring + coach budget
-- anchoring; the field that lets profile completion reach 100%. Nullable.
ALTER TABLE "UserProfile" ADD COLUMN     "monthlyBudgetEur" INTEGER;
