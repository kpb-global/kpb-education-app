-- Scheduling primitives are additive. Every Appointment column is nullable so
-- the historical direct-appointment flow keeps its existing contract.
CREATE TYPE "AvailabilitySlotStatus" AS ENUM ('available', 'blocked', 'exhausted', 'cancelled');
CREATE TYPE "SlotOfferStatus" AS ENUM ('offered', 'selected', 'expired', 'withdrawn');

CREATE EXTENSION IF NOT EXISTS btree_gist WITH SCHEMA public;

CREATE TABLE "CounsellorAvailabilitySlot" (
    "id" TEXT NOT NULL,
    "counsellorId" TEXT NOT NULL,
    "startsAt" TIMESTAMP(3) NOT NULL,
    "endsAt" TIMESTAMP(3) NOT NULL,
    "timezone" TEXT NOT NULL,
    "capacity" INTEGER NOT NULL DEFAULT 1,
    "bookedCount" INTEGER NOT NULL DEFAULT 0,
    "status" "AvailabilitySlotStatus" NOT NULL DEFAULT 'available',
    "version" INTEGER NOT NULL DEFAULT 1,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "CounsellorAvailabilitySlot_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "CounsellorAvailabilitySlot_dates_check" CHECK ("endsAt" > "startsAt"),
    CONSTRAINT "CounsellorAvailabilitySlot_capacity_check" CHECK ("capacity" > 0),
    CONSTRAINT "CounsellorAvailabilitySlot_booked_count_check" CHECK ("bookedCount" >= 0 AND "bookedCount" <= "capacity"),
    CONSTRAINT "CounsellorAvailabilitySlot_version_check" CHECK ("version" > 0)
);

CREATE TABLE "StudyReviewSlotOffer" (
    "id" TEXT NOT NULL,
    "reviewRequestId" TEXT NOT NULL,
    "slotId" TEXT NOT NULL,
    "offeredAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "expiresAt" TIMESTAMP(3) NOT NULL,
    "status" "SlotOfferStatus" NOT NULL DEFAULT 'offered',
    "selectedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "StudyReviewSlotOffer_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "StudyReviewSlotOffer_expiry_check" CHECK ("expiresAt" > "offeredAt"),
    CONSTRAINT "StudyReviewSlotOffer_selection_check" CHECK (
      ("status" = 'selected' AND "selectedAt" IS NOT NULL)
      OR ("status" <> 'selected' AND "selectedAt" IS NULL)
    )
);

ALTER TABLE "Appointment"
ADD COLUMN "counsellorId" TEXT,
ADD COLUMN "reviewRequestId" TEXT,
ADD COLUMN "slotId" TEXT,
ADD COLUMN "slotOfferId" TEXT,
ADD COLUMN "endsAt" TIMESTAMP(3),
ADD COLUMN "timezone" TEXT,
ADD COLUMN "bookingKey" TEXT;

ALTER TABLE "Appointment"
ADD CONSTRAINT "Appointment_review_dates_check"
CHECK ("endsAt" IS NULL OR "endsAt" > "startsAt");

CREATE UNIQUE INDEX "CounsellorAvailabilitySlot_counsellorId_startsAt_endsAt_key"
ON "CounsellorAvailabilitySlot"("counsellorId", "startsAt", "endsAt");
CREATE INDEX "CounsellorAvailabilitySlot_counsellorId_status_startsAt_idx"
ON "CounsellorAvailabilitySlot"("counsellorId", "status", "startsAt");

ALTER TABLE "CounsellorAvailabilitySlot"
ADD CONSTRAINT "CounsellorAvailabilitySlot_no_active_overlap"
EXCLUDE USING GIST (
  "counsellorId" WITH =,
  tsrange("startsAt", "endsAt", '[)') WITH &&
)
WHERE ("status" IN ('available', 'blocked', 'exhausted'));

CREATE UNIQUE INDEX "StudyReviewSlotOffer_reviewRequestId_slotId_key"
ON "StudyReviewSlotOffer"("reviewRequestId", "slotId");
CREATE INDEX "StudyReviewSlotOffer_reviewRequestId_status_expiresAt_idx"
ON "StudyReviewSlotOffer"("reviewRequestId", "status", "expiresAt");
CREATE INDEX "StudyReviewSlotOffer_slotId_expiresAt_idx"
ON "StudyReviewSlotOffer"("slotId", "expiresAt");

CREATE UNIQUE INDEX "Appointment_slotOfferId_key" ON "Appointment"("slotOfferId");
CREATE UNIQUE INDEX "Appointment_bookingKey_key" ON "Appointment"("bookingKey");
CREATE INDEX "Appointment_counsellorId_startsAt_idx" ON "Appointment"("counsellorId", "startsAt");
CREATE INDEX "Appointment_reviewRequestId_status_idx" ON "Appointment"("reviewRequestId", "status");
CREATE INDEX "Appointment_slotId_status_idx" ON "Appointment"("slotId", "status");

CREATE UNIQUE INDEX "one_active_appointment_per_review_request"
ON "Appointment"("reviewRequestId")
WHERE "reviewRequestId" IS NOT NULL
  AND "status" IN ('scheduled', 'confirmed', 'in_progress');

ALTER TABLE "CounsellorAvailabilitySlot"
ADD CONSTRAINT "CounsellorAvailabilitySlot_counsellorId_fkey"
FOREIGN KEY ("counsellorId") REFERENCES "Counsellor"("id")
ON DELETE CASCADE ON UPDATE CASCADE;

-- Counsellors are archived through isActive=false. Once a slot has offer
-- history, the RESTRICT FK below intentionally prevents destructive deletion.

ALTER TABLE "StudyReviewSlotOffer"
ADD CONSTRAINT "StudyReviewSlotOffer_reviewRequestId_fkey"
FOREIGN KEY ("reviewRequestId") REFERENCES "StudyReviewRequest"("id")
ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "StudyReviewSlotOffer"
ADD CONSTRAINT "StudyReviewSlotOffer_slotId_fkey"
FOREIGN KEY ("slotId") REFERENCES "CounsellorAvailabilitySlot"("id")
ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE "Appointment"
ADD CONSTRAINT "Appointment_counsellorId_fkey"
FOREIGN KEY ("counsellorId") REFERENCES "Counsellor"("id")
ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE "Appointment"
ADD CONSTRAINT "Appointment_reviewRequestId_fkey"
FOREIGN KEY ("reviewRequestId") REFERENCES "StudyReviewRequest"("id")
ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE "Appointment"
ADD CONSTRAINT "Appointment_slotId_fkey"
FOREIGN KEY ("slotId") REFERENCES "CounsellorAvailabilitySlot"("id")
ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE "Appointment"
ADD CONSTRAINT "Appointment_slotOfferId_fkey"
FOREIGN KEY ("slotOfferId") REFERENCES "StudyReviewSlotOffer"("id")
ON DELETE SET NULL ON UPDATE CASCADE;
