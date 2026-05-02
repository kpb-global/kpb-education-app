# Observability dashboards (Firebase)

Operational guide for **Crashlytics**, **Google Analytics (GA4)**, and release health using signals already emitted by the app.

## Crashlytics — crash-free users / stability

1. Open [Firebase Console](https://console.firebase.google.com) → your project → **Crashlytics**.
2. Use the built-in **crash-free users** trend for release comparisons (standard metric).
3. **Non-fatal handled errors** from [`safeRecordError`](../lib/app/core/services/safe_crashlytics.dart) appear as issues; classify using custom keys:

| Custom key | Typical values | Use |
|------------|----------------|-----|
| `obs_domain` | `sync`, `cases`, `saved_items`, `profile` | Filter by product area (same constants as [`CrashlyticsObsDomain`](../lib/app/core/observability/crashlytics_observability.dart)). |
| `obs_operation` | e.g. `sync_remote_data`, `create_remote_case` | Narrow to a specific failure site. |
| `obs_report_kind` | `non_fatal_handled`, `explicit_fatal` | Separate handled catches from explicit fatals. |

4. **Sync lifecycle keys** (from [`SyncTelemetry`](../lib/app/core/services/sync_telemetry.dart)): `sync_full_last_success`, `sync_full_last_elapsed_ms`, `sync_catalog_hive_fallback_last`, plus `obs_domain = sync` on the latest sync — useful when correlating user reports with last sync state.

**Suggested segment:** Non-fatals where `obs_domain == sync` → backlog for API / connectivity issues without user-visible crashes.

## GA4 — sync failure rate & funnel health

1. **Analytics** → **Events** — confirm `sync_full_complete`, `sync_conflict_resolved`, `sync_catalog_hive_fallback` appear after real traffic.
2. **Explore** → Blank exploration:
   - **Sync failure rate:** Event `sync_full_complete`, filter `success` equals `0`; denominator: same event without filter (or `success` = `1` + `0`).
   - **Catalog degradation:** Event `sync_catalog_hive_fallback`, break down by `resource`.
3. Wire **BigQuery export** (optional) — event names and params match [`analytics-event-contract.md`](analytics-event-contract.md).

## Release checklist (manual)

| Signal | Where | Pass criteria (example) |
|--------|--------|-------------------------|
| Crash-free rate | Crashlytics overview | No regression vs previous release |
| Sync failures | GA4 `sync_full_complete` | Failure ratio within SLO |
| Handled sync errors | Crashlytics `obs_domain=sync` | Volume stable or explained |

## Phase 7 follow-up

Automate **analyze + test** in CI ([`production-readiness-plan.md`](production-readiness-plan.md)); optionally add a scheduled BigQuery SQL or Data Studio / Looker Studio board off exported GA4 tables.
