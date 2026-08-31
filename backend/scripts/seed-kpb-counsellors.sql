-- MVP commercial round-robin seed (Jojo -> Donald -> Richard)
--
-- Les trois `createdAt` sont ECRITS EN DUR et espaces d'une seconde, et ce
-- n'est pas cosmetique : l'affectation en round-robin trie les conseillers sur
-- `createdAt` (departage par `id`). Avec `now()`, les trois lignes recevaient
-- l'horodatage de la TRANSACTION -- identique a la milliseconde -- et l'ordre
-- annonce sur la premiere ligne de ce fichier n'etait porte par rien : le
-- departage par `id` aurait rendu Donald -> Jojo -> Richard, alphabetique et
-- faux. L'ordre voulu est desormais DANS LES DONNEES, la ou le tri le lit.
--
-- Un 4e conseiller cree depuis l'admin recevra un `createdAt` posterieur et
-- prendra donc la fin de la rotation, ce qui est le comportement attendu.
-- Garde : backend/src/modules/cases/counsellor-seed-order.spec.ts.
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
    TIMESTAMP '2026-08-29 00:00:01',  -- rotation 1 : Jojo
    now()
  ),
  (
    'counsellor-donald',
    'Donald',
    'bokod246@gmail.com',
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
    TIMESTAMP '2026-08-29 00:00:02',  -- rotation 2 : Donald
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
    TIMESTAMP '2026-08-29 00:00:03',  -- rotation 3 : Richard
    now()
  )
ON CONFLICT ("id") DO UPDATE SET
  "fullName" = EXCLUDED."fullName",
  "email" = EXCLUDED."email",
  "phone" = EXCLUDED."phone",
  "whatsApp" = EXCLUDED."whatsApp",
  "isActive" = true,
  -- Repare une execution anterieure qui avait pose trois horodatages
  -- identiques : sans cette ligne, rejouer la seed ne corrigeait pas la rotation.
  "createdAt" = EXCLUDED."createdAt",
  "kycStatus" = 'approved',
  "updatedAt" = now();
