# PostHog — product analytics & session replay

PostHog runs **alongside** Firebase Analytics (it does not replace it). The
Flutter SDK (`posthog_flutter`) is wired in `lib/main.dart` and
`lib/app/core/services/analytics_service.dart`.

## What it captures

- **Events** — every event in [`analytics-event-contract.md`](analytics-event-contract.md)
  is mirrored to PostHog under the same name/params (`AnalyticsService._mirror`).
- **Screen views** — via `PosthogObserver` on the GetX navigator.
- **Autocapture** — taps and interactions, via the `PostHogWidget` wrapper.
- **Session replay** — screenshots of navigation, with **all text and images
  masked** (`maskAllTexts` + `maskAllImages`). The app shows passports,
  transcripts and personal data; masking means none of it is recorded.
- **Identity** — on login the backend user id (a UUID, not PII) is sent via
  `identify`; `logout` calls `reset`. `personProfiles` is `identifiedOnly`, so
  anonymous sessions create no person profile until login.

## Configuration

All compile-time, via `--dart-define` (see `AppConfig.posthog*`):

| Define | Default | Meaning |
|---|---|---|
| `POSTHOG_API_KEY` | *(empty)* | Project key (`phc_…`). **Empty disables PostHog entirely** — the app runs on Firebase alone. |
| `POSTHOG_HOST` | `https://us.i.posthog.com` | Ingestion host (KPB org is on US cloud). |

The key is a client-side key (safe to ship) but is kept out of the repo. CI
injects it from the `POSTHOG_API_KEY` GitHub secret in `flutter-ci.yml`
(debug APK, release AAB, iOS). Local run:

```bash
flutter run --dart-define=POSTHOG_API_KEY=phc_xxx
```

## Consent / opt-out

Users toggle **Profil → « Analyse d'usage »** (`AppController.setAnalyticsAllowed`),
which flips both Firebase and PostHog collection at runtime and persists the
choice; it is re-applied on every boot (`applyAnalyticsConsent`). The privacy
policy (in-app `legal_pages.dart` §9 and `web/public/confidentialite.html`)
documents this.

## Provisioning checklist (one-time, PostHog side)

1. Create the dedicated **"KPB Education"** project in PostHog (the MCP cannot
   create projects; do it in the UI). Copy its project API key.
2. Set the `POSTHOG_API_KEY` GitHub Actions secret to that key.
3. In **PostHog → Project settings → Replay**, enable **"Record user
   sessions"** — replay stays off server-side until this is on, even with
   `sessionReplay: true` in the app.
4. Declare session replay in the stores (see `STORE_READINESS.md` §2–§4).
