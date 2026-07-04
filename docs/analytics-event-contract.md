# Firebase Analytics event contract

Single source of truth for **custom event names** and **parameter keys** is [`lib/app/core/observability/analytics_event_contract.dart`](../lib/app/core/observability/analytics_event_contract.dart) (`AnalyticsEventName`, `AnalyticsParamKey`). Implementations must use these constants so GA4 / BigQuery exports stay stable.

## Conventions

| Rule | Detail |
|------|--------|
| Event names | `snake_case`, prefer ≤ 40 characters (GA4 limit). |
| Parameter keys | `snake_case`; reuse shared keys (`item_id`, `case_id`, …). |
| Booleans in Analytics | Use integers `0` / `1` where GA4 typing is ambiguous (see `success` on sync). |
| Screens | Use [`AnalyticsService.logScreen`](../lib/app/core/services/analytics_service.dart) (`logScreenView`) — screen class names are passed as Firebase expects. |

## Custom events (app-defined)

| Event (`AnalyticsEventName`) | Parameters | Purpose |
|------------------------------|------------|---------|
| `logout` | — | Session end |
| `orientation_start` | — | Quiz started |
| `orientation_complete` | `total_questions`, `match_count` | Quiz finished |
| `save_item` / `unsave_item` | `item_id`, `item_type` | Saved list |
| `compare_institutions` | `count`, `ids` | Compare flow |
| `case_created` | `case_type` | New dossier |
| `case_viewed` | `case_id` | Detail open |
| `document_uploaded` | `case_id` | Upload |
| `case_message_sent` | `case_id` | Messaging |
| `profile_updated` | — | Profile saved |
| `theme_toggled` | `theme` (`dark` / `light`) | Theme switch |

## Conversion & funnel

| Event | Parameters | Purpose |
|-------|------------|---------|
| `whatsapp_handoff` | `source` (call site, e.g. `program_detail`), `context_type` (e.g. `program`, `destination`, `case`, `fraud_report`, `community_group`), `success` (0/1) | Lead→advisor-contact hand-off; `success = 0` means WhatsApp could not be opened (lost conversion) |
| `referral_invite_shared` | — | Invite shared via WhatsApp (KPB-69) |
| `referral_redeemed` | — | Referral code redeemed by a referee (KPB-69) |

## Sync & reliability (observability)

| Event | Parameters | Purpose |
|-------|------------|---------|
| `sync_full_complete` | `success` (0/1), `elapsed_ms`, `catalog_hive_fallback_count` | Full sync outcome |
| `sync_conflict_resolved` | `domain`, `resolution` | Merge / skip logic (profile, cases, saved_items) |
| `sync_catalog_hive_fallback` | `resource`, `attempts` | Catalog API exhausted retries; Hive used |

## Recommended GA4 / BigQuery checks

- **Hand-off failure rate:** Count `whatsapp_handoff` where `success = 0` / all `whatsapp_handoff` — spikes mean users can't reach the advisor (device without WhatsApp, broken link).
- **Hand-off mix:** Breakdown of `whatsapp_handoff` by `source` × `context_type` to see which screens actually convert.
- **Sync failure rate:** Count `sync_full_complete` where `success = 0` / all `sync_full_complete`.
- **Slow sync:** Distribution of `elapsed_ms` on successful runs.
- **Offline catalog pressure:** Sum `catalog_hive_fallback_count` or count `sync_catalog_hive_fallback`.

See also [`observability-dashboards.md`](observability-dashboards.md).
