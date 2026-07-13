# Phase 8 — Release operations

Execution guide for **environment separation**, **store signing**, **metadata**, and **rollout / rollback**. Linked from [`production-readiness-plan.md`](production-readiness-plan.md).

## 1. Environment separation (`dev` · `staging` · `prod`)

Resolved in [`lib/app/core/config/app_config.dart`](../lib/app/core/config/app_config.dart).

| `--dart-define` | Purpose |
|-----------------|--------|
| `KPB_APP_ENV` | `dev` \| `staging` \| `prod` (default **`prod`**). Chooses default API base when `KPB_API_BASE_URL` is unset. |
| `KPB_API_BASE_URL` | When non-empty, **overrides** env defaults (full REST prefix ending in `/api`). |
| `KPB_ENABLE_REMOTE_SYNC` | `true` / `false` — set `false` in widget/unit tests to avoid network during `hydrate()`. |
| `KPB_REQUEST_TIMEOUT` | Optional override (seconds). |

**Default API bases** (only when `KPB_API_BASE_URL` is empty):

| `KPB_APP_ENV` | Base URL |
|---------------|----------|
| `dev` | `http://127.0.0.1:4000/api` |
| `staging` | `https://api.vps-planethoster.com/api` (adjust in code or always use `KPB_API_BASE_URL` for your real staging host) |
| `prod` | `https://api.kpbeducation.cloud/api` |

**Examples**

```bash
# Local backend
flutter run --dart-define=KPB_APP_ENV=dev

# Explicit URL (wins over KPB_APP_ENV)
flutter run --dart-define=KPB_API_BASE_URL=https://api.example.com/api

# Production release build (defaults are enough)
flutter build appbundle --release
```

**Note:** `storageNamespace` stays a single value so switching env on the same install does not silently fork local caches; use separate installs or clear app data when changing backends.

## 2. Signing & store metadata readiness

### Android (Google Play)

- **Upload key:** keystore + `android/key.properties` locally (gitignored). CI optional secrets: `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_PASSWORD`, `ANDROID_KEY_ALIAS` — see comments in [`.github/workflows/flutter-ci.yml`](../.github/workflows/flutter-ci.yml).
- **Play App Signing:** recommended; keep upload key in password manager + offline backup.
- **Store listing:** short/long description, screenshots (phone + 7" tablet if required), feature graphic, privacy policy URL, data safety form aligned with [`security-compliance.md`](security-compliance.md) and in-app legal copy.

### iOS (App Store)

- **Distribution signing:** Apple Development / Distribution certificates, provisioning profiles, **Release** `aps-environment` for push (not `development`).
- **ASC metadata:** privacy policy URL, export compliance, age rating, screenshots per device class.
- **CI today:** `flutter build ios --no-codesign` validates compile only; produce IPA via Xcode archive / Fastlane for upload.

## 3. Staged rollout & rollback

### Rollout

1. **Internal testing** (Play internal / TestFlight internal) on commit tagged for release.  
2. **Closed beta** small cohort → watch Crashlytics + Analytics (`sync_*`, crash-free users).  
3. **Staged production** (e.g. 5% → 20% → 100%) if Play supports phased release; App Store uses phased release over 7 days when enabled.

### Rollback criteria (examples — tune for your org)

- Crash-free users **drop** more than agreed threshold vs prior build **and** attributable new crashes in top frames.  
- **P0** bug: auth broken, data loss, payments (if any), or sync corrupting profile/cases without recovery.

### Rollback actions

- **Play:** halt rollout, revert to previous release track, ship hotfix with bumped `versionCode`.  
- **App Store:** stop phased release; expedite hotfix review if needed.  
- **Backend:** feature flags or API versioning if failures are server-driven.

## 4. Release checklist (minimal)

- [ ] Version bump in `pubspec.yaml` (`version: x.y.z+build`).  
- [ ] `flutter analyze` + `flutter test --dart-define=KPB_ENABLE_REMOTE_SYNC=false` green.  
- [ ] Profile build smoke on **physical** Android + iOS (Phase 1 smoke + Phase 6 perf spot-check).  
- [ ] Store consoles updated; privacy / data safety answers match shipping build.
