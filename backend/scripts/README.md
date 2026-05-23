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

This generates:

- `backend/scripts/output/omnes-programs-normalized.json`

The script is validation-first and does **not** write to DB directly.

## Prerequisites

- `DATABASE_URL` must be exported in your shell before running `seed:countries`.
- For importer runs, pass an absolute path to the OMNES `.xlsx` source file.
