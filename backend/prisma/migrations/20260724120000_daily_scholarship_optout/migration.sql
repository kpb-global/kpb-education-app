-- KPB-162: per-user opt-out for the daily "Bourse du jour" push (the
-- "opportunités" notification type). Opting out never affects other
-- notifications. Default false = opted in.
ALTER TABLE "UserProfile" ADD COLUMN "dailyScholarshipOptOut" BOOLEAN NOT NULL DEFAULT false;
