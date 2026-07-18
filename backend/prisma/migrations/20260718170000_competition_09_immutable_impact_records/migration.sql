-- CR-025 hardening: aggregate evidence is append-only. Corrections create a
-- new snapshot/export; they never rewrite the evidence used by a published
-- claim. Pilot protocols become immutable as soon as analysis is locked.

CREATE OR REPLACE FUNCTION "kpb_reject_immutable_impact_mutation"()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  RAISE EXCEPTION '% is append-only; create a correction instead', TG_TABLE_NAME
    USING ERRCODE = '55000';
END;
$$;

CREATE TRIGGER "ImpactSnapshot_append_only"
BEFORE UPDATE OR DELETE ON "ImpactSnapshot"
FOR EACH ROW
EXECUTE FUNCTION "kpb_reject_immutable_impact_mutation"();

CREATE TRIGGER "ImpactDataRoomExport_append_only"
BEFORE UPDATE OR DELETE ON "ImpactDataRoomExport"
FOR EACH ROW
EXECUTE FUNCTION "kpb_reject_immutable_impact_mutation"();

CREATE OR REPLACE FUNCTION "kpb_guard_partner_agreement_revision"()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    RAISE EXCEPTION 'PartnerAgreement revisions cannot be deleted'
      USING ERRCODE = '55000';
  END IF;

  -- The only in-place mutation closes the previous current revision. Prisma's
  -- @updatedAt may update the timestamp in that same statement.
  IF NOT (
    OLD."isCurrent" = TRUE
    AND NEW."isCurrent" = FALSE
    AND (to_jsonb(OLD) - ARRAY['isCurrent', 'updatedAt']) =
        (to_jsonb(NEW) - ARRAY['isCurrent', 'updatedAt'])
  ) THEN
    RAISE EXCEPTION 'PartnerAgreement is revisioned; create a new revision'
      USING ERRCODE = '55000';
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER "PartnerAgreement_revision_only"
BEFORE UPDATE OR DELETE ON "PartnerAgreement"
FOR EACH ROW
EXECUTE FUNCTION "kpb_guard_partner_agreement_revision"();

CREATE OR REPLACE FUNCTION "kpb_guard_locked_impact_pilot"()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    RAISE EXCEPTION 'ImpactPilot records cannot be deleted'
      USING ERRCODE = '55000';
  END IF;

  IF OLD."analysisLockedAt" IS NOT NULL THEN
    RAISE EXCEPTION 'Analysis-locked ImpactPilot records cannot be changed'
      USING ERRCODE = '55000';
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER "ImpactPilot_analysis_lock"
BEFORE UPDATE OR DELETE ON "ImpactPilot"
FOR EACH ROW
EXECUTE FUNCTION "kpb_guard_locked_impact_pilot"();
