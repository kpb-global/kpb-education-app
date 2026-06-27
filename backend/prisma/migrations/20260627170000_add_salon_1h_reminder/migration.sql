-- KPB-78: track the 1h-before salon reminder separately from the 24h one
-- (existing remindedAt) so each fires exactly once.
ALTER TABLE "SalonRegistration" ADD COLUMN     "reminded1hAt" TIMESTAMP(3);
