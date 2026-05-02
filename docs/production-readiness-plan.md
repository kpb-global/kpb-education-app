# KPB Education - Production Readiness Plan

This is the execution checklist used to move the app from feature-complete to production-ready.

## Phase 1 - Stability (In Progress)

### Goals
- Ensure critical flows do not crash or dead-end.
- Guarantee navigation targets are valid for quick actions and push notifications.
- Add repeatable smoke checks before each release.

### Work Items
- [x] Centralize external route normalization in `AppRoutes.normalizeExternalRoute()`.
- [x] Harden push routing to ignore invalid payload routes safely.
- [x] Add route normalization unit tests (`test/core/config/app_routes_test.dart`).
- [x] Add release smoke-test suite (manual + automated hybrid).
- [x] Add explicit fallback UI checks for network/offline states on critical screens.

### Release Smoke Tests (must pass on Android + iOS)
1. First launch -> intro/onboarding path opens and completes.
2. Login/register/forgot password screens open and submit without crash.
3. Home tab renders dynamic sections and can navigate to major destinations.
4. Search query returns results and opens details.
5. Create case flow submits successfully from:
   - Cases tab CTA
   - Scholarship CTA (`/new-case`)
6. Case detail opens from:
   - In-app list
   - Push route payload `/cases/{id}`
7. Document viewer opens a supported file and exits cleanly.
8. App lock (when enabled) shows on resume and can unlock.
9. Offline mode:
   - app keeps opening
   - outbox queues actions
   - reconnect drains queue
10. Push tap from background routes to intended page with no GetX exception.

### Implemented artifacts
- `docs/phase1-stability-smoke-checklist.md` - release candidate smoke checklist.
- `test/core/config/app_routes_test.dart` - route normalization regression tests.
- `test/features/cases_screen_stability_test.dart` - fallback-state widget stability tests.

## Phase 2 - Architecture Hardening
- Split oversized controller responsibilities by domain.
- Standardize error handling + user messaging boundaries.
- Keep navigation as one source of truth.

## Phase 3 - Data & Offline Reliability
- Snapshot schema versioning + migrations.
- Conflict resolution strategy for offline-to-online sync.
- Retries/backoff and sync telemetry.

## Phase 4 - Security & Compliance
- Secure storage review for sensitive values.
- Biometric/app-lock threat-model pass.
- Minimal permission audit (Android/iOS).
- Privacy policy/data disclosure alignment.

## Phase 5 - Observability
- Analytics event contract for key funnels.
- Crashlytics custom keys and non-fatal classification.
- Release dashboards (crash-free rate, startup time, sync failure rate).

## Phase 6 - Performance & UX
- Startup and screen render budget measurements.
- Jank hotspot optimization.
- Consistent loading/empty/error state quality.

## Phase 7 - Test & CI Gates
- Unit/widget/integration coverage for critical paths.
- CI: analyze + test + build checks as required merge gate.

## Phase 8 - Release Operations
- Flavor/env separation (`dev`, `staging`, `prod`).
- Signing and store metadata readiness.
- Staged rollout + rollback criteria.
