\set ON_ERROR_STOP on

BEGIN;

INSERT INTO "AdminUser" (
  "id", "fullName", "email", "role", "isActive", "languageScope",
  "workload", "createdAt", "updatedAt"
) VALUES (
  'cr017-admin', 'CR017 Admin', 'cr017-admin@example.test', 'admin', true,
  ARRAY['fr'], 0, now(), now()
);

INSERT INTO "UserProfile" (
  "id", "accountType", "preferredLanguage", "fullName", "email", "phone",
  "countryOfResidence", "preferredCurrency", "createdAt", "updatedAt"
) VALUES (
  'cr017-user', 'student', 'fr', 'CR017 Student',
  'cr017-student@example.test', '+22700000000', 'NE', 'XOF', now(), now()
);

INSERT INTO "Scholarship" (
  "id", "nameFr", "nameEn", "countryId", "countryNameFr", "countryNameEn",
  "levelEligibleFr", "levelEligibleEn", "typeOfFundingFr", "typeOfFundingEn",
  "deadlineLabelFr", "deadlineLabelEn", "keyRequirementsFr",
  "keyRequirementsEn", "relatedFieldIds", "createdAt", "updatedAt"
) VALUES (
  'cr017-scholarship', 'Bourse CR017', 'CR017 Scholarship', 'NE', 'Niger',
  'Niger', 'Master', 'Master', 'Complète', 'Full', 'Test', 'Test',
  ARRAY[]::text[], ARRAY[]::text[], ARRAY[]::text[], now(), now()
);

INSERT INTO "ScholarshipCycle" (
  "id", "scholarshipId", "academicYear", "status", "dateConfidence",
  "createdAt", "updatedAt"
) VALUES (
  'cr017-cycle', 'cr017-scholarship', '2026-2027', 'forecast', 'estimated',
  now(), now()
);

INSERT INTO "ScholarshipWorkspace" (
  "id", "userId", "scholarshipId", "scholarshipCycleId", "status",
  "version", "readinessPercent", "startedAt", "lastActivityAt", "createdAt",
  "updatedAt"
) VALUES (
  'cr017-workspace', 'cr017-user', 'cr017-scholarship', 'cr017-cycle',
  'submitted', 1, 100, now(), now(), now(), now()
);

INSERT INTO "ConsentNotice" (
  "id", "purpose", "version", "languageCode", "contentHash", "effectiveAt",
  "createdAt"
) VALUES (
  'cr017-notice', 'outcome_evidence', 'outcome-evidence-v1', 'fr',
  repeat('a', 64), now(), now()
);

INSERT INTO "ConsentReceipt" (
  "id", "userId", "purpose", "noticeId", "languageCode", "channel",
  "grantedAt", "createdAt"
) VALUES (
  'cr017-receipt', 'cr017-user', 'outcome_evidence', 'cr017-notice', 'fr',
  'sql_verification', now(), now()
);

INSERT INTO "OutcomeEvidenceAsset" (
  "id", "workspaceId", "ownerUserId", "consentReceiptId", "kind",
  "storageKey", "originalFileName", "mimeType", "sizeBytes", "sha256",
  "processingStatus", "version", "uploadedAt", "createdAt", "updatedAt"
) VALUES (
  'cr017-evidence', 'cr017-workspace', 'cr017-user', 'cr017-receipt',
  'submission_confirmation',
  '2026-07-17/00000000-0000-4000-8000-000000000017.pdf',
  'confirmation.pdf', 'application/pdf', 120, repeat('b', 64), 'clean', 2,
  now(), now(), now()
);

INSERT INTO "ApplicationSubmission" (
  "id", "workspaceId", "version", "lockVersion", "submittedAt",
  "applicationRefHash", "evidenceId", "createdAt", "updatedAt"
) VALUES (
  'cr017-submission', 'cr017-workspace', 1, 1, now(), repeat('c', 64),
  'cr017-evidence', now(), now()
);

DO $verify$
BEGIN
  BEGIN
    INSERT INTO "ApplicationSubmission" (
      "id", "workspaceId", "version", "lockVersion", "submittedAt",
      "evidenceId", "createdAt", "updatedAt"
    ) VALUES (
      'cr017-submission-duplicate', 'cr017-workspace', 1, 1, now(),
      'cr017-evidence', now(), now()
    );
    RAISE EXCEPTION 'workspace/version duplicate was accepted';
  EXCEPTION WHEN unique_violation THEN
    NULL;
  END;

  BEGIN
    INSERT INTO "ApplicationSubmission" (
      "id", "workspaceId", "version", "lockVersion", "submittedAt",
      "applicationRefHash", "evidenceId", "createdAt", "updatedAt"
    ) VALUES (
      'cr017-submission-bad-hash', 'cr017-workspace', 2, 1, now(), 'plaintext',
      'cr017-evidence', now(), now()
    );
    RAISE EXCEPTION 'plaintext reference hash was accepted';
  EXCEPTION WHEN check_violation THEN
    NULL;
  END;

  BEGIN
    UPDATE "ApplicationSubmission"
    SET "verificationStatus" = 'verified'
    WHERE "id" = 'cr017-submission';
    RAISE EXCEPTION 'verified outcome without actor/time was accepted';
  EXCEPTION WHEN check_violation THEN
    NULL;
  END;
END
$verify$;

UPDATE "ApplicationSubmission"
SET "verificationStatus" = 'verified', "verifiedAt" = now(),
    "verifiedById" = 'cr017-admin'
WHERE "id" = 'cr017-submission';

INSERT INTO "ApplicationDecisionRecord" (
  "id", "workspaceId", "version", "lockVersion", "isCurrent",
  "issuedByName", "admissionDecision", "receivedAt", "evidenceId",
  "createdAt", "updatedAt"
) VALUES (
  'cr017-admission', 'cr017-workspace', 1, 1, true, 'University', 'admitted',
  now(), 'cr017-evidence', now(), now()
);

DO $verify$
BEGIN
  BEGIN
    INSERT INTO "ApplicationDecisionRecord" (
      "id", "workspaceId", "version", "lockVersion", "isCurrent",
      "issuedByName", "admissionDecision", "receivedAt", "evidenceId",
      "createdAt", "updatedAt"
    ) VALUES (
      'cr017-admission-second-current', 'cr017-workspace', 2, 1, true,
      'University', 'waitlisted', now(), 'cr017-evidence', now(), now()
    );
    RAISE EXCEPTION 'second current admission was accepted';
  EXCEPTION WHEN unique_violation THEN
    NULL;
  END;
END
$verify$;

-- A full/partial award may be known before its exact amount.
INSERT INTO "FundingDecisionRecord" (
  "id", "workspaceId", "version", "lockVersion", "isCurrent",
  "issuedByName", "fundingDecision", "receivedAt", "evidenceId",
  "createdAt", "updatedAt"
) VALUES (
  'cr017-funding', 'cr017-workspace', 1, 1, true, 'Foundation', 'full', now(),
  'cr017-evidence', now(), now()
);

DO $verify$
BEGIN
  BEGIN
    UPDATE "FundingDecisionRecord"
    SET "fundingAmountMinor" = 1000
    WHERE "id" = 'cr017-funding';
    RAISE EXCEPTION 'half-filled funding amount/currency was accepted';
  EXCEPTION WHEN check_violation THEN
    NULL;
  END;

  BEGIN
    UPDATE "FundingDecisionRecord"
    SET "fundingCurrency" = 'XOF'
    WHERE "id" = 'cr017-funding';
    RAISE EXCEPTION 'currency without funding amount was accepted';
  EXCEPTION WHEN check_violation THEN
    NULL;
  END;

  BEGIN
    INSERT INTO "OutcomeEvidenceLink" (
      "id", "evidenceId", "entityType", "entityId", "isPrimary",
      "linkedByUserId", "linkedAt"
    ) VALUES
      ('cr017-link-1', 'cr017-evidence', 'submission', 'cr017-submission', true,
       'cr017-user', now()),
      ('cr017-link-2', 'cr017-evidence', 'submission', 'cr017-submission', true,
       'cr017-user', now());
    RAISE EXCEPTION 'second primary evidence link was accepted';
  EXCEPTION WHEN unique_violation THEN
    NULL;
  END;

  BEGIN
    DELETE FROM "AdminUser" WHERE "id" = 'cr017-admin';
    RAISE EXCEPTION 'verifiedBy admin was deletable';
  EXCEPTION WHEN foreign_key_violation THEN
    NULL;
  END;
END
$verify$;

-- Both a funded decision with unknown amount and a non-funded decision with
-- null amount/currency are valid states.
UPDATE "FundingDecisionRecord"
SET "fundingDecision" = 'none', "fundingAmountMinor" = NULL,
    "fundingCurrency" = NULL
WHERE "id" = 'cr017-funding';

UPDATE "FundingDecisionRecord"
SET "fundingDecision" = 'full'
WHERE "id" = 'cr017-funding';

\if :{?KEEP_FIXTURES}
COMMIT;
\else
ROLLBACK;
\endif

SELECT 'CR-017 outcome SQL invariants passed' AS result;
