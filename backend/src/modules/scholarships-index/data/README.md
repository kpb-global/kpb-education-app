# Versioned scholarship catalog

`scholarship-catalog.v1.ts` is the only bulk-import input for scholarships.
Its `records` collection accepts only opportunities checked against current,
official HTTPS sources. The legacy mock catalog is tracked under `backlog` and
is not considered verified or importable.

Required evidence per record:

- bilingual title, description, benefits, eligibility and requirements;
- structured level (`secondary`, `bachelor`, `master`);
- ordered bilingual application steps;
- an estimated or confirmed annual application cycle;
- official HTTPS sources for overview, eligibility, benefits, application and
  cycle dates;
- a named verifier and a verification timestamp no older than 30 days.

Commands:

```bash
npm run scholarships:validate:structure
npm run verify:scholarships
npm run scholarships:import:dry-run
npm run scholarships:import
```

Catalog version `1.2.0` contains 25 distinct opportunities and meets every
launch target: at least 25 unique records, 3 secondary, 12 Bachelor and 19
Master matches (multi-level records count once in each applicable level). The
validator checks the unique-record minimum separately, so one multi-level
opportunity cannot artificially satisfy the total-volume gate. A cycle copied forward from a prior
official call is always `forecast` + `estimated`, and its copy explicitly says
that confirmation is still required. Announced future cycles are `forecast` +
`confirmed`; only calls currently accepting applications may be `open` +
`confirmed`.

The strict validator fails on a missing volume target or any record-level
quality issue. The structure-only command remains the fast CI check, while the
dry-run command verifies the exact import set without writing to the database.

Imports are create-only: existing database ids are reported as skipped and are
never updated. Imported records are inactive and pending moderation, so an
admin must review and publish them.
