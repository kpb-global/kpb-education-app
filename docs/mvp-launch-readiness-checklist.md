# MVP Launch Readiness Checklist

This checklist operationalizes the `release-gate` todo from the final KPB roadmap.

## Automated verification run (2026-05-29)

Executed from workspace root (`/Users/aminou/Documents/Coding/kpb-education-new-app-aminoudev Global`):

- [x] `flutter analyze lib/` — **0 issues**
- [x] `flutter test` — **118 tests passing** (incl. eligibility engine 7, commercial models 6)
- [x] `npm --prefix backend run build` — **0 errors**
- [x] Prisma migrations applied locally through `20260529130000_add_orientation_sessions`
- [x] `npx prisma generate` succeeds (client v6.19.3)
- [ ] `DATABASE_URL` for **staging/prod** seed not yet executed from this shell
- [ ] OMNES source file not yet imported into staging

## 0) Scope locked for launch (decisions)

- [x] **Auth = Supabase Auth** (Google sign-in + email OTP). Supabase "KPB" project is **auth-only** — no migrations on its public schema; all business data stays in Prisma/Postgres. The anon key in `app_config.dart` is the public publishable key (safe to ship).
- [x] **AI = Groq** (`llama-3.3-70b-versatile`) for orientation + coach.
- [x] **Brand primary = blue `#004AAD`**.
- [x] **App launches FR-only + light theme only** (EN + dark deferred to V2).
- [x] Non-MVP modules gated behind `KPB_MVP_ONLY=true` (forum, alumni, academy, salon, housing, travel, scraped scholarships).

## 1) Quality gates

- [x] `flutter analyze` passes on app workspace.
- [x] `flutter test` passes (118).
- [x] Backend compiles (`npm --prefix backend run build`).
- [ ] Physical smoke tests completed on Android + iOS devices.

## 2) Security gates

- [x] Supabase JWT verified server-side (`SupabaseAuthGuard` → JWK → `createPublicKey`).
- [x] Supabase token → local `UserProfile` mapping via `supabaseUserId`.
- [x] Sensitive endpoints behind guards (`/cases`, `/profiles/me`, `/saved-items`, `/device-tokens`).
- [x] Admin/commercial endpoints behind `AdminAuthGuard` + `RolesGuard` (incl. new `/admin/dashboard`, `/commercial/performance`).
- [ ] Final production secrets review (`KPB_JWT_SECRET`, Supabase service keys, Groq key, Firebase, storage keys).

## 3) Core operational gates

- [x] Auto-assignment on case creation (round-robin MVP when active counselors exist).
- [x] Auto-reassignment cron for stale counselor-owned cases (10h policy).
- [x] WhatsApp CTA fallback centralized and configurable via environment.
- [x] AI coach weekly quota (5 messages/week) enforced backend-side.
- [x] **M4** — Orientation IA sessions persisted to Postgres (`OrientationSession`), in-memory fallback when DB disabled.
- [x] **M9** — Commercial app: leads inbox (filters + color-coded tags + ancienneté + unread count), conversations, "Moi" stats tab (`/commercial/stats`). Performance overview for admins (`/commercial/performance`).
- [x] **M11** — Eligibility simulator (5 inputs → 🟢/🟡/🔴 verdict × 9 countries + PDF export). Fully client-side, offline-capable.
- [x] **M13** — Admin dashboard KPIs (`/admin/dashboard`), campaign segmentation (account_type / study_level / country_of_residence + existing), campaign delivery stats (`/admin/notifications/campaigns/:id/stats`).

## 4) Data gates

- [x] 9-country SQL seed script added.
- [x] OMNES normalization import template added with schema validation.
- [x] France fiche scrubbed of Campus France promotion (privé-only positioning + "Sept 2026" badge).
- [ ] OMNES source import executed and QA validated in staging.

## 5) Controlled rollout plan

1. Internal canary (team + advisors)
2. Closed beta cohort
3. Progressive rollout
4. Daily KPI review and hotfix lane

## 6) Launch KPIs

- New accounts/day
- Cases submitted/day
- Median time to first counselor response (now surfaced via `/commercial/stats.avgFirstResponseMinutes`)
- Lead conversion rate (`/admin/dashboard.leads.conversionRate`)
- Crash-free sessions (Crashlytics)
- Push delivery/open rates (`/admin/notifications/campaigns/:id/stats`)
- Conversion from key CTAs (country/program/case)

## 7) Required manual actions (priority order)

1. **Apply migrations + seed on target DB**
   ```bash
   cd backend
   export DATABASE_URL="postgresql://<user>:<pass>@<host>:<port>/<db>?schema=public"
   npx prisma migrate deploy        # includes coach + orientation session tables
   npm run seed:countries
   ```
   Verify with:
   ```bash
   psql "$DATABASE_URL" -c 'select id, "nameFr" from "Country" order by id;'
   psql "$DATABASE_URL" -c '\dt "OrientationSession"'
   ```
2. **Configure Supabase auth project (auth-only)**
   - Enable Google provider + email OTP in the Supabase "KPB" dashboard.
   - Confirm `app_config.dart` points at the correct project URL + publishable anon key.
   - Do **not** run any migration against the Supabase public schema.
3. **Run OMNES normalization with real source file**
   ```bash
   npm --prefix backend run import:omnes -- "/absolute/path/to/OMNES_FALL_26_TOUT_PROGRAMME_030426.xlsx"
   ```
   Output expected at `backend/scripts/output/omnes-programs-normalized.json`. QA ≥10 rows before ingestion.
4. **Physical device smoke tests (Android + iOS)**
   - Supabase sign-in (Google + email OTP) / onboarding completion
   - Case submission (5-step tunnel) + timeline rendering
   - Eligibility simulator → verdict → PDF share
   - Commercial login → leads inbox → tag change → stats tab
   - WhatsApp CTA open flow
   - AI coach weekly quota behavior (5 messages/week)
5. **FCM + rollout checks**
   - Validate device token registration reaches backend after login/startup.
   - Send one transactional push (case update) and one segmented campaign push (e.g. `study_level`) to test devices.
   - Confirm Crashlytics + push delivery/open dashboards during staged rollout.
6. **Dependency hygiene (pre-prod)**
   - `npm --prefix backend audit` flagged 33 vulnerabilities (3 low / 23 moderate / 7 high) in transitive deps. Triage before production.
