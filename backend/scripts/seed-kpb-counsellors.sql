-- Commercial round-robin seed (Jojo -> Richard).
-- Donald a quitté l'équipe : il n'est plus inséré, et un ancien seed est désactivé.
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
    'josphindieuaimeagbessi@gmail.com',
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
    'counsellor-richard',
    'Richard',
    'richardahogle@gmail.com',
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

-- Donald a quitté l'équipe. Désactive la fiche si un seed précédent l'a créée,
-- sans effacer les dossiers déjà rattachés.
UPDATE "Counsellor"
SET "isActive" = false, "updatedAt" = now()
WHERE "id" = 'counsellor-donald'
   OR lower("email") = 'bokod246@gmail.com';
