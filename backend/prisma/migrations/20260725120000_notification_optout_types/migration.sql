-- KPB-169: collapse the per-type notification opt-out booleans into one
-- extensible column of stable keys. A third opt-out family ("récit de la
-- semaine") is the point at which one column per preference stops scaling.
--
-- Expand-only on purpose: the two boolean columns are backfilled FROM, not
-- dropped. A rollback to the previous image therefore still finds its data
-- intact (opt-outs recorded after this migration would be lost, which is the
-- acceptable half of the trade). KPB-174 drops them once the release sticks.

ALTER TABLE "UserProfile"
  ADD COLUMN "disabledNotificationTypes" TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[];

UPDATE "UserProfile"
SET "disabledNotificationTypes" = ARRAY_REMOVE(
      ARRAY[
        CASE WHEN "dailyScholarshipOptOut" THEN 'daily_scholarship' END,
        CASE WHEN "weeklyDigestOptOut" THEN 'weekly_digest' END
      ],
      NULL
    )
WHERE "dailyScholarshipOptOut" OR "weeklyDigestOptOut";
