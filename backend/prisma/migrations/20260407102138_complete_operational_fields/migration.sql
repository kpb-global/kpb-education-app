-- AlterTable
ALTER TABLE "Appointment" ADD COLUMN     "contactMethod" TEXT NOT NULL DEFAULT 'in_app',
ADD COLUMN     "notes" TEXT;

-- AlterTable
ALTER TABLE "Case" ADD COLUMN     "preferredContactMethod" TEXT NOT NULL DEFAULT 'in_app',
ADD COLUMN     "requestedCountryId" TEXT,
ADD COLUMN     "scheduledAt" TIMESTAMP(3),
ADD COLUMN     "source" TEXT NOT NULL DEFAULT 'mobile_app';

-- AlterTable
ALTER TABLE "PartnerLead" ADD COLUMN     "country" TEXT,
ADD COLUMN     "status" TEXT NOT NULL DEFAULT 'new';
