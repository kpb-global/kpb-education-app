-- MVP commercial round-robin seed (Jojo -> Donald -> Richard)
-- Usage:
--   bash backend/scripts/seed-countries.sh  # loads DATABASE_URL from backend/.env if exported
--   psql "$PSQL_URL" -f backend/scripts/seed-kpb-counsellors.sql

INSERT INTO "Counsellor" (
  "id",
  "fullName",
  "email",
  "phone",
  "whatsApp",
  "countryOfResidence",
  "specialties",
  "languagesSpoken",
  "bioFr",
  "bioEn",
  "yearsExperience",
  "hourlyRateXOF",
  "commissionBps",
  "kycStatus",
  "isActive",
  "createdAt",
  "updatedAt"
)
VALUES
  (
    'counsellor-jojo',
    'Jojo',
    'jojo@kpb-education.com',
    '+22790000001',
    '+22790000001',
    'NE',
    ARRAY['admissions', 'france-private'],
    ARRAY['fr'],
    'Conseiller KPB specialise admissions France prive.',
    'KPB counselor specialized in France private admissions.',
    5,
    15000,
    1500,
    'approved',
    true,
    now(),
    now()
  ),
  (
    'counsellor-donald',
    'Donald',
    'donald@kpb-education.com',
    '+22790000002',
    '+22790000002',
    'NE',
    ARRAY['admissions', 'canada'],
    ARRAY['fr', 'en'],
    'Conseiller KPB specialise Canada et bourses.',
    'KPB counselor specialized in Canada and scholarships.',
    4,
    15000,
    1500,
    'approved',
    true,
    now(),
    now()
  ),
  (
    'counsellor-richard',
    'Richard',
    'richard@kpb-education.com',
    '+22790000003',
    '+22790000003',
    'NE',
    ARRAY['admissions', 'orientation'],
    ARRAY['fr'],
    'Conseiller KPB specialise orientation et suivi dossier.',
    'KPB counselor specialized in orientation and case follow-up.',
    6,
    15000,
    1500,
    'approved',
    true,
    now(),
    now()
  )
ON CONFLICT ("id") DO UPDATE SET
  "fullName" = EXCLUDED."fullName",
  "email" = EXCLUDED."email",
  "phone" = EXCLUDED."phone",
  "whatsApp" = EXCLUDED."whatsApp",
  "isActive" = true,
  "kycStatus" = 'approved',
  "updatedAt" = now();
