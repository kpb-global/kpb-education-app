# MVP Launch Readiness Checklist

This checklist operationalizes the `release-gate` todo from the final KPB roadmap.

## Automated verification run (2026-05-22)

Executed from workspace root (`/Users/aminou/Documents/Coding/kpb-education-new-app-aminoudev Global`):

- [x] `flutter analyze`
- [x] `flutter test`
- [x] `npm --prefix backend run build`
- [x] Script command availability checked (`psql`, `npx`)
- [x] OMNES importer dependency fixed (`xlsx` added to `backend/package.json`)
- [x] OMNES importer runtime check (`npm --prefix backend run import:omnes -- "/tmp/OMNES_FALL_26_TOUT_PROGRAMME_030426.xlsx"` now fails only on missing file path, which is expected)
- [ ] `DATABASE_URL` not found in current shell, so DB seed was not executed
- [ ] OMNES source file not found in repository/local workspace

## 1) Quality gates

- [x] `flutter analyze` passes on app workspace.
- [x] `flutter test` passes on app workspace.
- [x] Backend compiles (`npm --prefix backend run build`).
- [ ] Physical smoke tests completed on Android + iOS devices.

## 2) Security gates

- [x] JWT auth interceptor + refresh flow enforced on API client.
- [x] Device token registration path implemented on mobile startup.
- [x] Case file upload path uses authenticated API endpoint.
- [ ] Final production secrets review (`KPB_JWT_SECRET`, Firebase, storage keys).

## 3) Core operational gates

- [x] Auto-assignment on case creation (round-robin MVP when active counselors exist).
- [x] Auto-reassignment cron for stale counselor-owned cases (10h policy).
- [x] WhatsApp CTA fallback centralized and configurable via environment.
- [x] AI coach weekly local quota (5 messages/week).

## 4) Data gates

- [x] 9-country SQL seed script added.
- [x] OMNES normalization import template added with schema validation.
- [ ] OMNES source import executed and QA validated in staging.

## 5) Controlled rollout plan

1. Internal canary (team + advisors)
2. Closed beta cohort
3. Progressive rollout
4. Daily KPI review and hotfix lane

## 6) Launch KPIs

- New accounts/day
- Cases submitted/day
- Median time to first counselor response
- Crash-free sessions
- Push delivery/open rates
- Conversion from key CTAs (country/program/case)

## 7) Required manual actions (priority order)

1. **Seed launch countries on target DB**
   ```bash
   export DATABASE_URL="postgresql://<user>:<pass>@<host>:<port>/<db>?schema=public"
   npm --prefix backend run seed:countries
   ```
   Verify with:
   ```bash
   psql "$DATABASE_URL" -c 'select id, "nameFr" from "Country" order by id;'
   ```
2. **Run OMNES normalization with real source file**
   ```bash
   npm --prefix backend run import:omnes -- "/absolute/path/to/OMNES_FALL_26_TOUT_PROGRAMME_030426.xlsx"
   ```
   Output expected at `backend/scripts/output/omnes-programs-normalized.json`.
3. **QA the generated OMNES payload**
   - Confirm row count, school count, and key fields (`programName`, `language`, `paymentUpfront`, `intakeDate`).
   - Spot-check at least 10 representative rows before any DB ingestion step.
4. **Physical device smoke tests (Android + iOS)**
   - Sign-in / onboarding completion
   - Case submission + timeline rendering
   - WhatsApp CTA open flow
   - AI chat weekly quota behavior (5 messages/week)
5. **FCM + rollout checks**
   - Validate device token registration reaches backend after login/startup.
   - Send one transactional push (case update) and one campaign push to test devices.
   - Confirm Crashlytics and push delivery/open dashboards during staged rollout.
