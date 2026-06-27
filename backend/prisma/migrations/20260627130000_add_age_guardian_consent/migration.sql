-- Age gate + self-attested guardian consent for declared minors (<18).
-- All nullable: existing users have no declared birth date until they provide
-- one; guardianConsentedAt gates data sync + AI processing for minors.
ALTER TABLE "UserProfile" ADD COLUMN     "birthDate" TIMESTAMP(3);
ALTER TABLE "UserProfile" ADD COLUMN     "guardianName" TEXT;
ALTER TABLE "UserProfile" ADD COLUMN     "guardianContact" TEXT;
ALTER TABLE "UserProfile" ADD COLUMN     "guardianConsentedAt" TIMESTAMP(3);
