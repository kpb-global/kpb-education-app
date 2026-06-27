-- Throttle for the profile-completion re-engagement nudge (KPB-76).
ALTER TABLE "UserProfile" ADD COLUMN     "profileNudgedAt" TIMESTAMP(3);
