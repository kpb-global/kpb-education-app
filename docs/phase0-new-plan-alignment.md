# KPB Education - Phase 0 New Plan Alignment

Date: 2026-07-07 (verified against code same day; see "Verification Pass" note below)
Source kit: `/Users/aminou/Downloads/kpb arangefiles`
Repo: `/Users/aminou/Documents/Coding/kpb-education-new-app-aminoudev Global`

## Verification Pass (2026-07-07)

Every claim below was checked against the actual backend and mobile code (not
re-derived from memory). Corrections and net-new findings from that pass:

- **Exact route matches are 2, not 3.** `POST /alumni/apply` is actually
  `POST /me/alumni/apply` (`alumni.controller.ts` base path is `me/alumni`).
  Only `GET /profiles/me` and `GET /health` match the kit path exactly.
- **`/config/app` already exists** (`app-config.controller.ts`). The
  Utilities row below was wrong at 1/2 — it is 2/2 done.
- **Prisma has 49 models, not 48** (`grep -c '^model ' schema.prisma` = 49).
- **The 2026-07-04 scholarship portage is already committed**:
  `Scholarship.applicationRequirement` and `ScholarshipApplicationStep` exist,
  with migration `20260704120000_add_scholarship_application_requirement`
  present (hand-written; not yet applied to a real database — no local DB in
  this sandbox, same constraint as when it was authored).
- **`KPB_MVP_ONLY` is asymmetric between mobile and backend.** Mobile's
  `AppConfig.mvpOnly` (`app_config.dart`) hides ~8 surfaces (community,
  alumni, academy, salon, housing, travel, blog, live scholarships). The
  backend reads the env var in exactly **one** place —
  `scholarships-index.service.ts`, to skip the scraper refresh cron. No other
  backend route is gated. P0-C's "confirm behavior" task is bigger than it
  looks: routes for surfaces mobile hides are still fully exposed server-side.
- **No local DB in this sandbox.** `PrismaService` (`prisma.service.ts`)
  already accounts for this: `client` is `null` when `DATABASE_URL` is unset,
  and `tryExecute()` swallows failures and returns `null` so callers fall
  back to in-memory mock data (see `catalog.service.ts`). Any new
  read endpoint (including `matches`) should use this pattern so it works
  in this sandbox and degrades safely in production if the DB hiccups.
- **The kit's matching inputs don't exist as structured fields yet.**
  `Program` has only free-text `tuitionFr/En` and `languageFr/En`, no
  `minGpaRequired`, `tuitionMinEur`, or `applicationDeadline`. `UserProfile`
  has no numeric `gpa` (only a bucketed `gradeRange` string like `"15-17"`)
  and a single `languageLevel` (not per-language FR/EN as the kit assumes).
  `Institution.studyLevels[]` *does* already exist and can drive the kit's
  "incompatible level" guardrail without new fields.
  This means P0-D's first slice must add a small set of additive, nullable
  Program fields before real scores are possible — see the revised P0-D plan.
- **No `ExchangeRate` model is needed for v1.** `UserProfile.monthlyBudgetEur`
  is already EUR-denominated (the kit's donor schema assumed an FCFA
  budget field converted via `ExchangeRate`; this repo normalizes budget to
  EUR at profile-save time already). Budget-vs-tuition scoring can compare
  EUR to EUR directly. Treat `ExchangeRate`/BCEAO-rate persistence as
  deferred, not required.
- **Field-adjacency data (`field_adjacency.json`) does not exist.** V1 should
  score field match as binary (exact `fieldId` membership vs. no match) and
  defer the kit's "adjacent field = 0.6" tier until that mapping is authored.

## Goal

Start Phase 0 by turning the new Karatou starter-kit plan into an implementation map for the current KPB Education repo.

This is intentionally an alignment phase, not a rewrite phase. The current repo already has a working Flutter app, NestJS backend, Prisma schema, and Next.js admin. The new plan should be adapted into this repo through compatible contracts and additive migrations instead of replacing the existing app structure.

## Inputs Reviewed

- New kit:
  - `README.md`
  - `CLAUDE.md`
  - `USER_STORIES.md`
  - `API_CONTRACTS.md`
  - `PRISMA_SCHEMA.prisma`
  - `PROJECT_STRUCTURE.md`
  - `docs/matching_algorithm.md`
  - `docs/rls_policies.md`
  - `docs/seed_spec.md`
- Current repo:
  - `backend/prisma/schema.prisma`
  - `backend/src/modules/**/*`
  - `lib/app/**/*`
  - `admin/app/**/*`
  - `docs/api-contracts.md`
  - `docs/kpb-mvp-gap-and-roadmap.md`
  - `docs/kpb-m1-m14-conformity-audit.md`

## Workspace Safety Note

The working tree already contains many modified and untracked app files. Phase 0 should avoid broad formatting, cleanup, or schema replacement until those changes are understood. New work should be isolated to clearly named files or narrowly scoped patches.

## Current High-Level State

The target kit defines 47 user stories and 106 REST endpoints across 20 modules. The current backend exposes ~195 route handlers, but only 2 target endpoints match exactly:

- `GET /profiles/me`
- `GET /health`

(`POST /alumni/apply` is close but not exact — the real path is `POST /me/alumni/apply`.)

That does not mean the app is empty. It means the current app already has many equivalent capabilities under different names:

- `School` target maps mostly to current `Institution` plus `Program`.
- `Application` target maps mostly to current `Case`.
- `Conversation` / `Message` target maps to current `CoachConversation` / `CoachMessage`.
- `SavedSchool` target maps to current generic `SavedItem`.
- `PushCampaign` target maps to current `NotificationCampaign`.

## Phase 0 Decisions

| Decision | Choice | Rationale |
|---|---|---|
| D0 - Repo structure | Keep current structure: Flutter at repo root, `backend/`, `admin/`. Do not move to `apps/mobile` and `apps/backend` now. | Moving folders would create a huge diff without improving the user flows. |
| D1 - Prisma strategy | Do not copy `PRISMA_SCHEMA.prisma` over `backend/prisma/schema.prisma`. Use additive migrations and adapters. | Current schema has 49 models already tied to implemented modules. Replacement would break data and code. |
| D2 - Public API strategy | Add kit-compatible endpoints as adapters where useful. Keep internal services initially. | Lets mobile/admin migrate incrementally while preserving working code. |
| D3 - Product vocabulary | Use kit vocabulary for user-facing and public contracts: User, Profile, School, Application, Document, Copilote. Internally, map to current models where needed. | Aligns the plan without forced renames. |
| D4 - MVP flag | Keep `KPB_MVP_ONLY` as the launch guard for out-of-scope surfaces. | Current code already uses the concept for live scholarships and related modules. |
| D5 - Auth | Keep Supabase Auth as the primary mobile auth layer. Add `/auth/session` only if a Nest JWT bridge is still required after reviewing deployment. | Current mobile already signs in with Google/email OTP via Supabase and backend verifies Supabase tokens. |
| D6 - Test gates | Use current repo gates: Flutter, backend, admin separately. | This matches existing CI/repo reality. |
| D7 - Match granularity | Score at `Program` granularity (GPA/field/tuition/deadline vary per program within a school). `GET /matches/school/:institutionId` scores that institution's programs and returns the best one; `/matches/aha-moment` returns a top-N slice across relevant programs. | Matches D-decision above that `/schools` = Institution + best/default Program. Scoring per-Institution alone would ignore the data that actually varies. |
| D8 - Missing match inputs | Reuse existing fields where possible (`gradeRange` midpoint instead of a new `gpa` field, `monthlyBudgetEur` directly instead of `ExchangeRate`, binary field match instead of an adjacency table) and add only 4 new nullable `Program` fields (`minGpaRequired`, `tuitionMinEur`, `applicationDeadline`, `teachingLanguages`). Lean on the kit algorithm's own missing-data rule (neutral 0.5 + `isEstimate`, capped at 0.65 with ≥2 missing factors) rather than blocking on a data-backfill pass. | Ships a real, explainable score now; real institution data (GPA cutoffs, deadlines) is a seeding/ops task, not a code blocker. |

## Current Validation Gates

- Flutter: `flutter analyze`, `flutter test`
- Backend: from `backend/`, `npm run lint`, `npm test -- --runInBand`, `npm run build`
- Admin: from `admin/`, `npm run lint`, `npm run build`, `npm audit --omit=dev`

Do not use `next lint`; this repo uses the checked-in ESLint CLI setup.

## P0 User Story Mapping

| US | Target | Current status | Current evidence | Phase 0 action |
|---|---|---|---|---|
| US-001 | Google OAuth or magic link | Partial | `lib/app/core/services/auth_service.dart`, `lib/app/features/auth/*`, `backend/src/modules/auth/supabase-auth.service.ts` | Decide whether `/auth/session` is required. If yes, add it as a bridge, not a replacement. |
| US-002 | 12-question profile quiz | Partial | `lib/app/features/onboarding/onboarding_screen.dart`, `UserProfile` fields | Define canonical 12-question JSON and mapping to current profile fields. Add missing persistence objects only if needed. |
| US-003 | AHA moment after quiz | Missing | Home has local recommendations, but no `GET /matches/aha-moment` | Add `matches` module plan and route contract. Build after US-004 scoring exists. |
| US-004 | Admission probability per school | Partial/local only | `AppSearchService.institutionMatch`, match badges in mobile | Move/duplicate scoring to backend `matches` service using kit algorithm. Keep local score as fallback. |
| US-005 | Hub 5 tabs | Partial | `AppShell` has Accueil, Destinations, Universites, Demandes, Moi; Coach is FAB | Decide whether to keep this stronger current nav or change to kit tabs. Recommendation: keep current nav and surface Copilote via FAB/tools. |
| US-006 | Explore schools | Partial | `UniversitiesScreen`, `ProgramDetailScreen`, `/catalog/institutions`, `/catalog/programs` | Add `/schools` adapter over Institution/Program or document current `/catalog` as canonical. |
| US-007 | Eligible scholarships | Partial | `/scholarships`, scraper/moderation, `Scholarship` model | Add `eligible` route and MVP curated seed/rules. Keep scraper as V1.1 behind flag. |
| US-008 | Create/follow application | Partial strong | `Case`, `CaseTimelineEvent`, `CaseTask`, `CasesController` | Treat `Case` as current Application backend. Add 10-step template/progress semantics. |
| US-009 | Upload documents | Partial | `CaseDocument`, multipart upload under `/cases/:id/documents/upload` | Decide adapter route `/documents/upload-url`; add validation/OCR statuses additively. |
| US-010 | French AI copilote chat | Partial strong | `AiChatScreen`, `CoachController`, `CoachService`, persisted `CoachConversation` | Add `/copilote` aliases/adapters or update API contract to `/coach`. Ensure action suggestions. |
| US-011 | Motivation letter AI | Partial | `MotivationLettersScreen`, `/tools/personalize-letter` | Add persistent `Letter`/`LetterVersion` or map to generated tool outputs first. |
| US-012 | Qualified WhatsApp lead | Partial | WhatsApp utilities, service package WhatsApp purchase, case assignment | Add `WhatsAppLead`/`LeadAssignment` or equivalent tracking. Create `POST /leads/whatsapp`. |

## V1/V2 Story Grouping

| Story range | Theme | Current repo reality | Implementation stance |
|---|---|---|---|
| US-013 to US-018 | Alerts, budget/flight, interview, school summary, save, share card | Several tools/screens exist; alerts/share card are missing or not target-aligned. | Pull only pieces that support P0 conversion; keep nice-to-have flows behind MVP flag. |
| US-019 to US-027 | Retention, Diambar, live/community, parent, compare, counselor panel | Parent, compare, admin/cases partly exist. Streak/Diambar are missing. | Add after P0 path is stable. |
| US-028 to US-031 | Alumni certification, DM, lives, testimonials | Alumni apply/directory/admin exist partly; DM/lives/testimonials are not target-complete. | Keep directory/apply; defer growth loops. |
| US-032 to US-035 | Ambassador referrals and withdrawals | Current referral credits are no-cash, not cash commission/KYC/withdrawal. | Do not mix cash commissions into MVP until fraud rules are designed. |
| US-036 to US-043 | Parents, premium, admin analytics, partners | Payments/admin/reports/partners partly exist but contracts differ. | Add adapters only after P0/P1 data model is stable. |
| US-044 to US-047 | Quiz redo, counselor docs/messages, alumni loyalty | Current cases/messages can support parts. | Backlog after Application/Document alignment. |

## Target API Module Mapping

| Target module | Exact route matches | Current equivalent | Phase 0 decision |
|---|---:|---|---|
| Auth | 0/3 | `/auth/student/*`, Supabase mobile SDK, `StudentAuthGuard` | Keep Supabase auth; consider `/auth/session` bridge only if deployment needs Nest tokens. |
| Users | 0/6 | `UserProfile`, `/profiles/me`, account export/delete | Do not add full `/users` module yet. Add thin aliases only if mobile/web needs kit contract. |
| Profiles | 1/4 | `/profiles/me`, `/profiles/me/export`, onboarding update | Add quiz/progress routes after question schema is fixed. |
| Schools | 0/6 | `/catalog/institutions`, `/catalog/programs`, `SavedItem` | Build `/schools` as an adapter view over institutions/programs if we want kit compatibility. |
| Scholarships | 0/5 | `/catalog/scholarships`, `/scholarships`, admin moderation | Add `/scholarships/eligible` and alerts additively. |
| Matches | 0/5 | Local scoring in mobile only | New backend module required. |
| Applications | 0/5 | `/cases`, `/admin/cases` | Use `Case` as the internal model. Add application step/progress semantics. |
| Documents | 0/5 | `CaseDocument`, `/document-review`, multipart case uploads | New document adapter/status layer required. |
| Copilote | 0/11 | `/coach/*`, `/tools/*` | Add aliases/adapters and persistent letters/interviews later. |
| Simulator | 0/2 | budget, housing, flight mobile tools | Consolidate later under `/simulator`. |
| Community | 0/9 | forum taxonomy, WhatsApp community fallback, salon | Defer target in-app feed/forums unless needed for launch. |
| Retention | 0/2 | None equivalent | New module required. |
| Parents | 0/6 | `/parent-links/*` | Keep current link model; add permission fields if adopting target. |
| Alumni | 1/6 | `/alumni`, `/me/alumni`, `/admin/alumni` | Add `/alumni/directory` alias later. DM/lives/testimonials deferred. |
| Referrals | 0/7 | `/referrals/me`, `/referrals/redeem`, credits/voucher | Current no-cash system differs from ambassador commissions. Keep separate. |
| Monetization | 0/4 | `/payments/*`, `/service-packages/*` | Add WhatsApp lead first; premium subscriptions later. |
| Admin | 0/11 | `/admin/cases`, `/admin/reports`, `/admin/notifications`, `/admin/catalog` | Keep current admin routes; add kit aliases only when external contract requires them. |
| Partners | 0/3 | `/partners`, `/partner-leads` | Partner commission reports are new work. |
| Webhooks | 0/4 | `/payments/webhooks/:provider` | Add WhatsApp and provider aliases only when providers are configured. |
| Utilities | 2/2 | `/health`, `/config/app` | Done — no action needed. |

## Data Model Mapping

| Target model | Current model(s) | Status | Migration stance |
|---|---|---|---|
| `User`, `Profile` | `UserProfile` | Partial | Keep `UserProfile`; add fields for first/last name, target year, GPA, special case if needed. |
| `Session` | Supabase session, `StudentCredential`, `MagicLinkToken` | Partial/different | Do not duplicate unless Nest JWT session bridge is adopted. |
| `School` | `Institution` plus `Program` | Partial | Prefer adapter/view-model. Avoid introducing duplicate school rows until catalog ownership is settled. |
| `SavedSchool` | `SavedItem` | Partial | Keep generic saved item; add school-specific endpoint if target route is required. |
| `Match`, `MatchExplanation`, `MatchShareCard` | Local match scoring only (`AppSearchService.institutionMatch`, a heuristic country/field/level/grade-band affinity score, 0-98, not a probability) | Missing | Add `Match` (`probability`, `zone`, `algorithmVersion`, `isEstimate`, TTL 24h) + `MatchExplanation` (`factors` JSON, narrative) tables, relations on `UserProfile`/`Program`. `MatchShareCard` deferred (US-018, not P0). |
| `Application`, `ApplicationStep`, `ApplicationTimeline` | `Case`, `CaseTask`, `CaseTimelineEvent` | Partial | Extend `Case` with standard application workflow before creating a parallel `Application`. |
| `Document`, `DocumentValidation`, `DocumentReview` | `CaseDocument`, `DocumentReview` service | Partial | Add validation fields/statuses to case documents or introduce document table with relation to case. |
| `Conversation`, `Message` | `CoachConversation`, `CoachMessage` | Partial | Keep current names internally; expose `/copilote` if needed. |
| `Letter`, `LetterVersion` | Tool output only | Missing/persistent layer | Add when US-011 is implemented fully. |
| `InterviewSession`, `InterviewFeedback` | Interview tool output only | Missing/persistent layer | Add after US-015. |
| `CostEstimate`, `LivingCostBenchmark`, `ExchangeRate` | Budget data and tools; `UserProfile.monthlyBudgetEur` is already EUR-denominated | Partial/local | `ExchangeRate` not needed for match scoring (EUR-to-EUR comparison). Add `CostEstimate`/`LivingCostBenchmark` persistence only when `/simulator/cost` is implemented. |
| `Group`, `CommunityPost`, `Live` | `ForumCategory`, `ForumTopicTag`, `SalonEvent`, `SalonSession` | Partial/different | Defer until community becomes launch-critical. |
| `UserStreak`, `DiambarSnapshot` | None | Missing | Add after P0 conversion flow. |
| `ParentStudentLink`, `ParentPermission` | `ParentChildLink` | Partial | Add permissions fields if adopting target dashboard. |
| `Alumni`, `AlumniApplication` | flat alumni fields on `UserProfile` | Partial/different | Keep flat model unless alumni becomes a core growth loop. |
| `Ambassador`, `Commission`, `Withdrawal`, `KYCVerification` | no-cash `Referral`, `CreditTransaction` | Different | Do not merge cash and no-cash rewards without fraud/accounting design. |
| `Subscription`, `Payment` | `PaymentIntent`, `ServicePurchase` | Partial/different | Keep current purchase model for services; add subscription later. |
| `WhatsAppLead`, `LeadAssignment` | `Case.leadTag`, service WhatsApp purchase | Missing dedicated | Add for US-012 tracking. |
| `PushCampaign` | `NotificationCampaign` | Partial | Keep current model and expose target naming as needed. |
| `AnalyticsEvent` | `AnalyticsService` mobile, admin reports | Partial | Add backend event table or PostHog integration contract. |

## Phase 0 Implementation Backlog

### P0-A - Source of Truth

- [x] Create this alignment document.
- [x] Mark `docs/kpb-mvp-gap-and-roadmap.md` as superseded or update its stale claims.
- [x] Verify every claim in this document against current code (2026-07-07 — see "Verification Pass" above).
- [ ] Add a short pointer from `README.md` or docs index to this Phase 0 document.
- [ ] **Commit this document and the roadmap-superseded note.** Both currently exist only as uncommitted/untracked files in a dirty working tree (189 changed files on `codex/kpb-delivery-review`, no commits ahead of `main`). Until committed, this is not actually the team's source of truth — it is a local file only one person can see.
- [ ] **Triage the dirty working tree before it blocks anything.** Most of the diff is `dart format` churn, but there is real, non-whitespace content mixed in (~2,300 changed lines even ignoring whitespace, across 172 files, e.g. `app_config.dart` formatting plus behavior-adjacent files). Decide per-file: commit, discard, or split into a separate PR — do not let Phase 0 work land on top of an unreviewed pile.

### P0-B - Contract Decisions

- [ ] Decide: keep current student shell tabs or switch to kit tabs.
  - Recommendation: keep current tabs, because they map better to the implemented catalog and case flow.
- [ ] Decide: expose kit-compatible adapters (`/schools`, `/applications`, `/copilote`) or rewrite mobile to current endpoints.
  - Recommendation: expose adapters gradually. This keeps the kit and future docs readable while preserving current services.
- [ ] Decide: `School` equals `Institution`, or `School` equals `Institution + best/default Program`.
  - Recommendation: for API `/schools`, return institutions with top/relevant programs embedded. Keep `/catalog/programs` for program-level search.
- [ ] Decide: add Nest `/auth/session` bridge or document Supabase-token auth as the canonical path.
  - Recommendation: keep Supabase-token auth unless admin/web requires a unified Nest JWT.

### P0-C - MVP Scope Lock

- [ ] Confirm `KPB_MVP_ONLY=true` behavior across mobile and backend.
  - Correction: today this flag only gates mobile UI (~8 surfaces via `AppConfig.mvpOnly`) and one backend cron (`scholarships-index` scraper refresh). Every backend route for the hidden mobile surfaces (community, alumni, academy, salon, housing/travel) is still fully reachable server-side (e.g. via admin, direct API calls, or a future web client). Decide whether that's acceptable pre-launch or whether backend gating is needed too.
- [ ] Hide or de-emphasize out-of-scope launch surfaces in the student path:
  - live scholarship scraper
  - academy
  - salon
  - alumni growth features
  - housing/travel extras unless used by the selected demo flow
- [ ] Keep high-conversion extras visible only when they support the P0 flow:
  - France private admission
  - service packages / WhatsApp advisor CTA
  - case timeline/messages

### P0-D - First Implementation Slice

Recommended first code slice after this doc (revised after code verification —
the naive "just add a matches service" plan undersold the schema work):

1. **Schema (additive only, nullable, no backfill required to ship)**:
   - `Program`: add `minGpaRequired Float?`, `tuitionMinEur Int?`,
     `applicationDeadline DateTime?`, `teachingLanguages String[] @default([])`.
   - New `Match` model (`userProfileId`, `programId`, `probability`, `zone`
     enum `green|yellow|blue`, `algorithmVersion` default `"v1"`,
     `isEstimate`, `expiresAt` for the 24h TTL) + `MatchExplanation`
     (`factors` JSON, `narrativeFr`/`narrativeEn`), with relations added to
     `UserProfile` and `Program`.
   - Hand-write the migration SQL (no local DB in this sandbox — same
     constraint noted in the 2026-07-04 scholarship migration); leave
     `prisma migrate deploy` to be run by whoever has DB access.
2. Add a backend `matches` service implementing the 5-factor deterministic
   scoring from `docs/matching_algorithm.md` (kit), adapted to available data:
   - Academic: parse `UserProfile.gradeRange` midpoint vs `Program.minGpaRequired`.
   - Field: binary match on `fieldId` (no adjacency table yet).
   - Language: single `UserProfile.languageLevel` vs whether
     `Program.teachingLanguages` is non-empty (documented v1 simplification —
     no per-language FR/EN granularity yet).
   - Budget: `monthlyBudgetEur * 12` vs `tuitionMinEur`, both already EUR (no
     `ExchangeRate` needed).
   - Timing: `applicationDeadline` vs now.
   - Any missing input → neutral 0.5 + `isEstimate = true` per the kit's own
     rule; ≥2 missing factors caps probability at 0.65. Guardrails: target
     level not in `Institution.studyLevels` caps at 0.20; deadline passed
     caps at 0.10.
   - Use `PrismaService.tryExecute()` (existing fallback convention) so the
     endpoint degrades safely with no DB configured, consistent with how
     `catalog.service.ts` already behaves.
3. Add `GET /matches/school/:institutionId` (best-scoring program for that
   institution) and `GET /matches/aha-moment` (top-N across the user's
   target countries/fields).
4. Add tests for each score factor, the missing-data cap, and both guardrails.
5. Wire mobile AHA moment after onboarding completion (separate slice, once
   the response shape is stable — do not build both at once).

Why this first: it creates the key product promise from the new plan and can be built additively without disturbing existing case/admin/commercial work. It is more schema work than originally scoped, but still fully additive.

## Phase 0 Exit Criteria

Phase 0 is complete when:

- The team agrees on the data/API mappings above.
- Stale roadmap claims are either updated or explicitly superseded.
- The next coding slice is selected and testable.
- No destructive Prisma replacement is planned.
- Validation gates are confirmed before the first code PR.

## Recommended Next Command

Start P0-D with:

```bash
# Backend first: implement deterministic match scoring + API adapters.
cd backend
npm run lint
npm test -- --runInBand
```

Then add the mobile integration once the response shape is stable.
