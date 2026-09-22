-- Donald a quitté l'équipe commerciale. Il ne reçoit plus de dossiers.
-- Les dossiers encore ouverts passent à Jojo et Richard. La fiche est
-- désactivée, pas supprimée, pour garder l'historique déjà rattaché.

INSERT INTO "CaseTimelineEvent" ("id", "caseId", "status", "title", "description", "createdAt")
SELECT
  'donald-left-' || c.id,
  c.id,
  c.status::text,
  'Commercial retiré',
  'Donald a quitté l''équipe. Le dossier a été réattribué.',
  CURRENT_TIMESTAMP
FROM "Case" AS c
WHERE c."counsellorId" IN (
  SELECT "id"
  FROM "Counsellor"
  WHERE "id" = 'counsellor-donald'
     OR lower("email") = 'bokod246@gmail.com'
)
  AND c.status::text NOT IN ('completed', 'rejected', 'cancelled')
  AND EXISTS (SELECT 1 FROM "Counsellor" WHERE "id" = 'counsellor-jojo')
  AND EXISTS (SELECT 1 FROM "Counsellor" WHERE "id" = 'counsellor-richard')
  AND NOT EXISTS (
    SELECT 1
    FROM "CaseTimelineEvent" AS event
    WHERE event."id" = 'donald-left-' || c.id
  );

UPDATE "Case" AS c
SET
  "counsellorId" = CASE
    WHEN c.seq % 2 = 0 THEN 'counsellor-richard'
    ELSE 'counsellor-jojo'
  END,
  "assignedAdvisorName" = CASE
    WHEN c.seq % 2 = 0 THEN COALESCE(
      (SELECT "fullName" FROM "Counsellor" WHERE "id" = 'counsellor-richard'),
      'Richard'
    )
    ELSE COALESCE(
      (SELECT "fullName" FROM "Counsellor" WHERE "id" = 'counsellor-jojo'),
      'Jojo'
    )
  END,
  "updatedAt" = CURRENT_TIMESTAMP
WHERE c."counsellorId" IN (
  SELECT "id"
  FROM "Counsellor"
  WHERE "id" = 'counsellor-donald'
     OR lower("email") = 'bokod246@gmail.com'
)
  AND c.status::text NOT IN ('completed', 'rejected', 'cancelled')
  AND EXISTS (SELECT 1 FROM "Counsellor" WHERE "id" = 'counsellor-jojo')
  AND EXISTS (SELECT 1 FROM "Counsellor" WHERE "id" = 'counsellor-richard');

UPDATE "Counsellor"
SET "isActive" = false, "updatedAt" = CURRENT_TIMESTAMP
WHERE "id" = 'counsellor-donald'
   OR lower("email") = 'bokod246@gmail.com';
