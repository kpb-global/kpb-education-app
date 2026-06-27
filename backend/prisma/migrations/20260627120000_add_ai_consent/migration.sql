-- Separate, explicit consent for third-party AI processing (Groq). Distinct
-- from the general onboarding consent (`consentedAt`) so we can gate the AI
-- coach specifically and evidence AI consent independently. Nullable: existing
-- users have not consented to AI processing until they opt in.
ALTER TABLE "UserProfile" ADD COLUMN     "aiConsentedAt" TIMESTAMP(3);
