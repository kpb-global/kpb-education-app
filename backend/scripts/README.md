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

## Prerequisites

- `DATABASE_URL` must be exported in your shell before running `seed:countries`.
- For importer runs, pass an absolute path to the OMNES `.xlsx` source file.
