# KPB Education - Production Readiness Plan

This is the execution checklist used to move the app from feature-complete to production-ready.

## Phase 1 - Stability (Complete in repo; device smoke still required per release)

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

## Phase 2 - Architecture Hardening (Complete)
- [x] Split oversized controller responsibilities by domain (remote DTO parsing + catalog sync extracted earlier; search/match cluster extracted to `AppSearchService`).
- [x] Standardize error handling + user messaging boundaries (sync errors: `user_facing_sync_error.dart`, Crashlytics on sync failure via `safe_crashlytics.dart` so tests run without Firebase init).
- [x] Centralize untrusted external navigation (`AppNavigation` + `AppRoutes.normalizeExternalRoute`).

### Phase 2 artifacts
- `lib/app/core/navigation/app_navigation.dart` — single entry for FCM / deep-link navigation.
- `lib/app/core/utils/user_facing_sync_error.dart` — locale-aware sync error copy for `AppController.syncError`.
- `lib/app/core/services/safe_crashlytics.dart` — wraps Crashlytics recording when no default Firebase app (unit/widget tests).
- `lib/app/core/data/case_api_codec.dart`, `profile_api_codec.dart`, `saved_item_api_codec.dart`, `json_parse_utils.dart` — REST ↔ domain mapping isolated from `AppController`.
- `lib/app/core/services/catalog_remote_sync.dart` — catalog fetch + Hive fallback shared helper.
- `lib/app/core/services/app_search_service.dart` — global search and profile-aware match scoring (delegated from `AppController`).
- `test/core/utils/user_facing_sync_error_test.dart` — regression tests for error mapping.

## Phase 3 - Data & Offline Reliability
- [x] Snapshot JSON format version + in-place migration hook (`app_snapshot_format.dart`, wired in `LocalAppRepository` load/save).
- [x] Hive catalog cache format version (clears box on mismatch; `CatalogCacheService`).
- [x] Bounded retries with exponential backoff for catalog API fetch before Hive fallback (`catalog_remote_sync.dart`).
- [x] Conflict resolution strategy for offline-to-online sync (`AppController.syncRemoteData`, `sync_conflict_merge.dart`): profile — skip overwriting from GET while `profileNeedsPush` (PATCH not yet confirmed); cases — merge by id with newer `updatedAt` wins and retain local-only ids; saved items — union of remote + local-only pairs; optional push of unsynced saves after merge.
- [x] Sync telemetry (`sync_telemetry.dart`, `AnalyticsService` `sync_*` events, Crashlytics custom keys on full sync): full sync success/failure + duration + catalog Hive fallback count; conflict resolutions logged as `sync_conflict_resolved`; catalog fallback as `sync_catalog_hive_fallback`.

## Phase 4 - Security & Compliance (Complete)
- [x] Secure storage review for sensitive values — tokens centralized in [`kpb_secure_storage.dart`](./security-compliance.md); snapshot excludes email/phone/WhatsApp from persistence.
- [x] Biometric/app-lock threat-model pass — documented on [`SecurityService`](../lib/app/core/services/security_service.dart); `persistAcrossBackgrounding` on unlock prompt.
- [x] Minimal permission audit (Android/iOS) — [`docs/security-compliance.md`](security-compliance.md); Android `POST_NOTIFICATIONS`; iOS plist trimmed to camera/photos + Face ID.
- [x] Privacy policy/data disclosure alignment — Crashlytics + sync telemetry called out in-app (`legal_pages.dart`) and in engineering doc above.

### Phase 4 artifacts
- [`docs/security-compliance.md`](security-compliance.md) — credential storage, permissions table, review triggers.

## Phase 5 - Observability (Complete)
- [x] Analytics event contract — [`analytics-event-contract.md`](analytics-event-contract.md); canonical names in [`analytics_event_contract.dart`](../lib/app/core/observability/analytics_event_contract.dart); [`AnalyticsService`](../lib/app/core/services/analytics_service.dart) uses constants.
- [x] Crashlytics non-fatal classification — [`safe_crashlytics.dart`](../lib/app/core/services/safe_crashlytics.dart) sets `obs_domain`, `obs_operation`, `obs_report_kind`; [`AppController`](../lib/app/core/controllers/app_controller.dart) passes domains for sync/cases/saved items/profile; [`SyncTelemetry`](../lib/app/core/services/sync_telemetry.dart) tags sync custom keys.
- [x] Dashboard guidance — [`observability-dashboards.md`](observability-dashboards.md) (crash-free rate, GA4 sync KPIs, Crashlytics filters).

### Phase 5 artifacts
- [`docs/analytics-event-contract.md`](analytics-event-contract.md), [`docs/observability-dashboards.md`](observability-dashboards.md).

## Phase 6 - Performance & UX
- Startup and screen render budget measurements.
- Jank hotspot optimization.
- Consistent loading/empty/error state quality.

## Phase 7 - Test & CI Gates (In progress)
- [ ] Unit/widget/integration coverage for critical paths (expand over time).
- [x] CI merge gate — GitHub Actions [`.github/workflows/flutter-ci.yml`](../.github/workflows/flutter-ci.yml): `flutter analyze`, `flutter test --dart-define=KPB_ENABLE_REMOTE_SYNC=false` on PRs/pushes to **`master`** / **`main`**; Android APK + iOS (no codesign) build after the quality job succeeds. (Optional: add `dart format --set-exit-if-changed lib test` after a repo-wide format commit.)
- **Local test runs:** use `flutter test --dart-define=KPB_ENABLE_REMOTE_SYNC=false` (and the same for targeted test files) so `AppController.hydrate()` does not start remote catalog sync; the default `KPB_ENABLE_REMOTE_SYNC` is `true` in non-CI runs and can cause network I/O during widget tests.

## Phase 8 - Release Operations
- Flavor/env separation (`dev`, `staging`, `prod`).
- Signing and store metadata readiness.
- Staged rollout + rollback criteria.
