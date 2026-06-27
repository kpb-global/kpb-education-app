-- Multi-campus formations: store per-campus price/intake on a single Program
-- row instead of duplicating the program once per campus (OMNES). Nullable;
-- existing single-campus programs stay NULL.
ALTER TABLE "Program" ADD COLUMN     "campusOfferings" JSONB;
