-- KPB-163: per-user opt-out for the Monday weekly digest (push + email).
-- Independent of every other notification type. Default false = opted in.
ALTER TABLE "UserProfile" ADD COLUMN "weeklyDigestOptOut" BOOLEAN NOT NULL DEFAULT false;
