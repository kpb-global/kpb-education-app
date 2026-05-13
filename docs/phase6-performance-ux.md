# Phase 6 — Performance & UX (release baseline)

This document closes **Phase 6** in [`production-readiness-plan.md`](production-readiness-plan.md): measurable budgets, how to verify them, jank hygiene, and consistent **loading / empty / error** patterns across the app.

## 1. Performance budgets (targets, not hard CI gates)

| Area | Target | How to measure |
|------|--------|----------------|
| Cold start to first frame | ≤ 3 s on a **mid-tier** Android device (e.g. 4 GB RAM) after install | `flutter run --profile`, DevTools **Performance** timeline: app start → first `Frame` after `MaterialApp` |
| Time to interactive (Home tab usable) | ≤ 5 s same device, warm cache | Manual stopwatch + ensure no blocking spinner past first paint without reason |
| Scroll jank | No sustained **red** frames during vertical scroll on Home / Cases / Scholarships lists | DevTools **Performance** → enable “Track widget rebuilds” sparingly; prefer **CPU Profiler** for heavy build methods |
| Shader / first-frame hitch | Acceptable on first install; document “second open” smoothness | Profile mode cold vs warm launch |

**Interpretation:** Budgets are **release checklist** items. If a release regresses by >25% vs previous RC, block the rollout until fixed or waived with a written reason.

## 2. Tools & commands

- **Profile locally:** `flutter run --profile` (Android or iOS device preferred over simulator for GPU/CPU realism).
- **DevTools:** Performance, Memory, and CPU tabs; capture a 10–20 s trace while repeating the worst user path (e.g. Home → Search → open detail → back).
- **Size (optional):** `flutter build appbundle --analyze-size` to spot unexpected assets or dependencies before store upload.

## 3. Jank hotspot hygiene (engineering rules)

1. **Avoid heavy work in `build`:** no I/O, no large `List.where` on huge lists without memoization; prefer `Obx`/`GetBuilder` scoped to the smallest subtree.
2. **Lists:** use lazy builders (`ListView.builder`, slivers); avoid unbounded `Column` with many children for long feeds.
3. **Images:** use `cached_network_image` (already in app) with reasonable `memCacheWidth` where large bitmaps caused jank (add per-screen if profiling shows decode pressure).
4. **RepaintBoundary:** use selectively after profiling shows unnecessary repaints (do not blanket-wrap without evidence).

## 4. Loading / empty / error — canonical patterns

Use the shared widgets in [`lib/app/core/ui/kpb_components.dart`](../lib/app/core/ui/kpb_components.dart) and skeleton helpers in [`lib/app/core/ui/skeleton_loader.dart`](../lib/app/core/ui/skeleton_loader.dart) / [`skeleton.dart`](../lib/app/core/ui/skeleton.dart).

| Situation | Pattern |
|-----------|---------|
| Initial load of a full screen | Prefer **skeleton** (`SkeletonLoader`, screen-specific skeleton) for content-shaped wait; a centered **spinner** is acceptable for short secondary loads. |
| No data (successful load, empty list) | **`KpbEmptyState`** — icon, title, optional subtitle, optional CTA. |
| Hard failure (no usable cached data) | **`KpbErrorState`** — title + subtitle + **Réessayer** via `onRetry`. |
| Data shown but sync failed (stale catalog) | **`KpbSyncErrorBanner`** + `onRetry` (see `AppController`-driven screens). |
| Pull-to-refresh | **`KpbRefresh`** or `RefreshIndicator`; child scroll view must use **`AlwaysScrollableScrollPhysics`** when content can be shorter than the viewport so pull-to-refresh still works. |

**Reference implementations:** `CasesScreen` (skeleton → error → list + `KpbRefresh`), `HomeScreen` (profile null + sync error).

## 5. Pre-release UX pass (manual, each RC)

1. Airplane mode on/off: Home, Cases, Scholarships still open; banners/errors match expectations.  
2. Slow network (Chrome throttling / network link conditioner on iOS): no infinite spinners without copy.  
3. Largest font / accessibility: no critical `RenderFlex` overflows on Home and Cases (spot-check).  
4. Repeat Phase 1 smoke checklist: [`phase1-stability-smoke-checklist.md`](phase1-stability-smoke-checklist.md).

## 6. Ongoing work (post–Phase 6)

- Expand automated widget tests for empty/error branches on more screens.  
- Add optional CI step: `flutter test` already runs; consider golden tests for key empty states after design stabilizes.
