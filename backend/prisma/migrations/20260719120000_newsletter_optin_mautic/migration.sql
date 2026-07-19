-- Scholarship-newsletter opt-in (Mautic sync).
-- newsletterOptIn: current desired state (checkbox).
-- newsletterConsentedAt: timestamped proof of the latest opt-in (GDPR).
-- newsletterSyncedOptIn: last state pushed to Mautic (NULL = never synced);
--   the reconciliation cron syncs rows where desired != synced.
ALTER TABLE "UserProfile"
  ADD COLUMN "newsletterOptIn" BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN "newsletterConsentedAt" TIMESTAMP(3),
  ADD COLUMN "newsletterSyncedOptIn" BOOLEAN;
