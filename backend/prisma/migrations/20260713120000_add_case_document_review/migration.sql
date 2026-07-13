-- Commercial per-document review (App-engagement handoff, Feature D).
-- Hand-written (no local `prisma migrate dev`), mirroring the schema.prisma
-- changes of the same date. Additive: 3 nullable columns on "CaseDocument".
-- Counsellor verdict on an uploaded document:
--   "reviewStatus" ∈ 'validated' | 'redo' | 'doubtful' (NULL = pending review).

-- AlterTable
ALTER TABLE "CaseDocument" ADD COLUMN "reviewStatus" TEXT;
ALTER TABLE "CaseDocument" ADD COLUMN "reviewedByName" TEXT;
ALTER TABLE "CaseDocument" ADD COLUMN "reviewedAt" TIMESTAMP(3);
