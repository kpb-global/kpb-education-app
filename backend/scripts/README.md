# Backend data scripts (KPB roadmap)

## 1) Countries launch seed

```bash
npm --prefix backend run seed:countries
```

Seeds the 9 launch countries required by the KPB product scope.

## 2) OMNES import template

```bash
npm --prefix backend run import:omnes -- "/absolute/path/to/OMNES_FALL_26_TOUT_PROGRAMME_030426.xlsx"
```

Bundled workbook (repo):

```bash
npm --prefix backend run import:omnes:bundled
```

This generates:

- `backend/scripts/output/omnes-programs-normalized.json` (747 programmes)

## 3) Full catalog seed (M5 countries + OMNES programs)

```bash
npm --prefix backend run seed:catalog
```

Runs `seed:countries-m5`, then `seed:omnes` (747 programmes), then `seed:partners` (76 programmes annexe 05).

Total attendu en base : **~825 programmes** (747 OMNES + 76 partenaires).

## 4) Partner schools only (annexe 05)

```bash
npm --prefix backend run seed:partners
```

## 5) Verify catalog country references

```bash
npm --prefix backend run verify:catalog
```

Checks that every destination country reference points to an **active**
`Country` — `Institution.countryId`, `Program.countryId`,
`SupportDestination.countryId` and `ServiceOffer.destinationIds[]` (these are
plain indexes, not FKs, so nothing enforces this in the DB). Exits non-zero on
any orphan — safe to use as a CI gate after a seed. Scholarships are excluded on
purpose: a scholarship may target a country KPB does not actively place students
in (e.g. Japan).

> Note: countries are owned by `seed:countries-m5` (run via `seed:catalog`).
> `prisma:seed` no longer upserts countries — doing so would clobber the rich M5
> content or fail on the required unique `Country.code`.

## Prerequisites

- `DATABASE_URL` must be exported in your shell before running `seed:countries`.
- For importer runs, pass an absolute path to the OMNES `.xlsx` source file.
