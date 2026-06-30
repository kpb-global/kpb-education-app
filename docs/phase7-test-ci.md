# Phase 7 — Test & CI gates

This document tracks **Phase 7** in [`production-readiness-plan.md`](production-readiness-plan.md): what runs in CI, how to run tests locally, and how we expand coverage over time.

## 1. CI merge gate (GitHub Actions)

Workflow: [`.github/workflows/flutter-ci.yml`](../.github/workflows/flutter-ci.yml)

| Job | What it does |
|-----|----------------|
| **Analyze & test** | `flutter pub get` → `flutter analyze` → `flutter test --dart-define=KPB_ENABLE_REMOTE_SYNC=false` |
| **Build Android APK** | Release APK after quality passes (signing: upload keystore when secrets set; else debug keystore fallback in Gradle). |
| **Build iOS (no codesign)** | `flutter build ios --release --no-codesign` — compile gate, not store-ready IPA. |

Triggers on `push` / `pull_request` to `master` or `main` when paths change under `lib/`, `test/`, `docs/`, `pubspec*`, `analysis_options.yaml`, `android/`, `ios/`, or the workflow file.

## 2. Local commands (match CI)

```bash
flutter pub get
flutter analyze
flutter test --dart-define=KPB_ENABLE_REMOTE_SYNC=false
```

Format gate:

```bash
dart format --output=none --set-exit-if-changed lib test
```

## 3. Test inventory (baseline)

| Area | Files (examples) |
|------|------------------|
| Routes / navigation | `test/core/config/app_routes_test.dart` |
| Sync / merge / snapshot | `test/core/services/sync_conflict_merge_test.dart`, `app_snapshot_format_test.dart` |
| Search | `test/core/services/app_search_service_test.dart` |
| Errors / observability | `test/core/utils/user_facing_sync_error_test.dart`, `test/core/observability/analytics_event_contract_test.dart` |
| App controller | `test/core/controllers/app_controller_test.dart` |
| Widgets | `test/features/shell_navigation_test.dart`, `home_screen_test.dart`, `onboarding_screen_test.dart`, `cases_screen_stability_test.dart`, `salon_screen_test.dart` |
| API client | `test/core/repositories/app_api_client_test.dart` |

## 4. Ongoing coverage (prioritized backlog)

1. **More widget tests** for screens that own async data loads (empty / error / retry), using optional DI where needed (see `SalonScreen.apiClient`).  
2. **Golden tests** for stable empty/error layouts (optional, after visual freeze).  
3. **Integration / E2E** (e.g. Patrol) for login → home → case flow on device farm — add when you want release-blocking device automation beyond unit/widget.

## 5. Definition of “Phase 7 done enough to ship”

- CI green on default branch for **analyze + test + both mobile compile jobs**.  
- Phase 1 smoke checklist executed manually on **real devices** each RC.  
- No open **P0** test gaps on auth, paywall (if any), and offline sync paths identified in triage.
