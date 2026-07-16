-- Remap legacy field ids to the canonical d01..d12 catalogue ids.
-- Partner programs were seeded with business/computer_science/engineering
-- while the orientation quiz and the rest of the catalogue use d-ids, so the
-- "partner + field" filter always returned 0 results.
--   computer_science → d01 (Informatique & Intelligence Artificielle)
--   business         → d02 (Commerce & Management)
--   engineering      → d03 (Ingénierie & Sciences)

UPDATE "Program" SET "fieldId" = 'd01' WHERE "fieldId" = 'computer_science';
UPDATE "Program" SET "fieldId" = 'd02' WHERE "fieldId" = 'business';
UPDATE "Program" SET "fieldId" = 'd03' WHERE "fieldId" = 'engineering';

UPDATE "UserProfile"
SET "fieldIds" = array_replace("fieldIds", 'computer_science', 'd01')
WHERE 'computer_science' = ANY ("fieldIds");
UPDATE "UserProfile"
SET "fieldIds" = array_replace("fieldIds", 'business', 'd02')
WHERE 'business' = ANY ("fieldIds");
UPDATE "UserProfile"
SET "fieldIds" = array_replace("fieldIds", 'engineering', 'd03')
WHERE 'engineering' = ANY ("fieldIds");

-- Countries denormalize popular field ids for the explore page.
UPDATE "Country"
SET "popularFieldIds" = array_replace(array_replace(array_replace(
      "popularFieldIds", 'computer_science', 'd01'),
      'business', 'd02'),
      'engineering', 'd03')
WHERE "popularFieldIds" && ARRAY['computer_science', 'business', 'engineering'];

-- Drop the now-orphaned legacy Field rows (duplicates of d01/d02/d03).
DELETE FROM "Field" WHERE id IN ('computer_science', 'business', 'engineering');
