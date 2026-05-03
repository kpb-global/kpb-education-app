# Security & compliance (engineering)

Companion to **Phase 4** in [`production-readiness-plan.md`](production-readiness-plan.md). This document is for builders and reviewers; end-user wording lives in the app (**Politique de confidentialité**).

## Credential storage

| Data                                 | Where                                                                                                  | Notes                                                                                                                                     |
| ------------------------------------ | ------------------------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------- |
| Access token, refresh token, user id | `FlutterSecureStorage` via [`kpbFlutterSecureStorage`](../lib/app/core/config/kpb_secure_storage.dart) | Android: Keystore + AES-GCM (package defaults). iOS: Keychain, `first_unlock_this_device`, not iCloud-synced.                             |
| REST calls                           | `AppApiClient` + `_AuthInterceptor`                                                                    | Same storage instance as [`AuthService`](../lib/app/core/services/auth_service.dart) — identical options so reads/writes stay consistent. |

Passwords are never stored locally beyond OS-level secure credential flows during login.

## Local snapshot (`SharedPreferences`)

[`LocalAppRepository`](../lib/app/core/repositories/local_app_repository.dart) persists a JSON snapshot (preferences, catalog mirrors, cases metadata, etc.). **Email, phone, and WhatsApp are not written** to disk (loaded from API on sync). Tokens are **not** in this blob.

## Hive boxes

Catalog cache and message outbox hold non-auth payloads (cached JSON, queued actions). Treat devices as trusted-enough for UX caching; rely on HTTPS and auth headers for origin data.

## App lock (`SecurityService`)

Biometric / device PIN unlock after resume — see class doc on [`SecurityService`](../lib/app/core/services/security_service.dart). Not a banking-grade isolation layer.

## Platform permissions

### Android (`AndroidManifest.xml`)

| Permission             | Purpose                                                                                                                                                   |
| ---------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `INTERNET`             | API, Firebase                                                                                                                                             |
| `ACCESS_NETWORK_STATE` | Connectivity checks                                                                                                                                       |
| `POST_NOTIFICATIONS`   | Show FCM notifications (Android 13+); requested at runtime in [`push_notification_service.dart`](../lib/app/core/services/push_notification_service.dart) |
| `USE_BIOMETRIC`        | Local auth for app lock                                                                                                                                   |

### iOS (`Info.plist`)

Usage descriptions are limited to **camera** and **photo library** (document upload / image picker). Location, microphone, and invalid/custom keys were removed where unused to align prompts with actual APIs.

## Privacy disclosure alignment

In-app policy screens ([`legal_pages.dart`](../lib/app/features/legal/legal_pages.dart)) mention Firebase Analytics, push messaging, and — after Phase 4 — **Crashlytics** and **aggregated sync telemetry** (Analytics events), consistent with [`AnalyticsService`](../lib/app/core/services/analytics_service.dart) / [`sync_telemetry.dart`](../lib/app/core/services/sync_telemetry.dart). For dashboard and event naming details, see [`observability-dashboards.md`](observability-dashboards.md) and [`analytics-event-contract.md`](analytics-event-contract.md).

## Periodic review

Re-run this checklist after adding sensors, new Firebase products, or new persisted fields.
