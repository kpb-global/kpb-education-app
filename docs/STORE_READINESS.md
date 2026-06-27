# Store readiness — privacy declarations, age rating & performance budget

> **Issue:** KPB-68 (Epic 8 — IA responsable, conformité & store-readiness).
> **Status of dependencies:** the data-minimization and account-deletion
> behaviours described here are delivered by PRs **#58** (KPB-66 — PII
> minimization + AI consent), **#59** and **#60** (KPB-67 — account deletion,
> data export, minor/guardian consent). This document assumes those have
> merged. Keep it updated whenever a data flow or third-party changes.

This is the source of truth for the **App Store Privacy "nutrition labels"**,
the **Google Play Data Safety** form, the **age rating**, and the **measured
performance budget**. Copy the relevant sections into App Store Connect / the
Play Console at submission time.

---

## 1. Data collection inventory

What the app collects and where it lives.

| Data | Collected | Stored in | Notes |
|---|---|---|---|
| Name (full name) | Onboarding | Own backend (Postgres) | **Not** sent to Groq (pseudonymized — #58) |
| Email | Onboarding / OAuth | Supabase Auth + Postgres | |
| Phone + WhatsApp | Onboarding | Postgres | Not persisted to device storage |
| Country of residence | Onboarding | Postgres + local | |
| Birth date | Onboarding (students) | Postgres + local | Age gate (#60) |
| Guardian name/contact + consent | Onboarding (declared minors) | Postgres (+ name/consent local) | Guardian **contact** not persisted on device |
| Academic profile (level, field, target countries, grades, budget) | Onboarding | Postgres + local | Budget sent to Groq only as a **range** (#58) |
| Cases: messages, uploaded documents (passport, transcripts), timeline | In-app | Postgres + file storage | Documents referenced by URL |
| Saved items, orientation answers, search history | In-app | Postgres + local | |
| Coach (AI) messages | In-app | Postgres; **forwarded to Groq (US)** | Free text — see §2 |
| Push token | Runtime | OneSignal | |
| App interaction events | Runtime | Firebase Analytics | Event names + non-PII params; **search term is free text** |
| Crash diagnostics | On crash | Firebase Crashlytics | Stack traces, device model, OS, app version |

**No advertising SDKs. No cross-app tracking. No data brokers.**

---

## 2. Third-party processors

| Processor | Region | Receives | Purpose | Linked to user | Used for tracking |
|---|---|---|---|---|---|
| **Own backend (NestJS/Postgres)** | (deploy region) | All app data above | App functionality | Yes | No |
| **Supabase Auth** | (project region) | Email, Google OAuth identity, session tokens | Authentication | Yes | No |
| **Groq** (LLM) | **United States** | **Pseudonymized** profile (level, target countries, budget *range* — **no name**) + the user's free-text coach messages | Generate AI coach replies | No (pseudonymized) | No |
| **OneSignal** | US | Push token, external id (`UserProfile.id`) | Push notifications | Yes | No |
| **Firebase Analytics** | Google | App-instance id, device/OS, coarse region, interaction events; **search terms** | Product analytics | Yes (app-instance) | No |
| **Firebase Crashlytics** | Google | Crash stack traces, device model, OS, app version | Stability/diagnostics | Pseudonymous | No |
| **Embedded web (WebView)** | external sites | Whatever the loaded site sees (e.g. Kayak flight search) | Price comparison, content | n/a (external) | per that site |

> **Action before submission:** confirm the Supabase project region and the
> backend deploy region, and confirm Firebase Analytics `logSearch` search
> terms are acceptable to declare as "User Content / Search History" (they can
> contain free text). If not, drop the search term from the event.

---

## 3. App Store — Privacy "nutrition labels"

For each type: **Linked to the user? Used for tracking? Purpose.**
Tracking is **No** everywhere (no ad/attribution SDKs, no data sharing for ads).

| Apple data type | Collected | Linked | Tracking | Purpose |
|---|---|---|---|---|
| Contact Info — Name, Email, Phone | Yes | Yes | No | App Functionality |
| Sensitive Info — *none* | No | — | — | — |
| User Content — Photos/Docs (uploads), Customer Support (case + coach messages), Other (orientation answers) | Yes | Yes | No | App Functionality |
| Identifiers — User ID; Device ID (OneSignal/Firebase instance) | Yes | Yes | No | App Functionality, Analytics |
| Usage Data — Product Interaction, Search History | Yes | Yes | No | Analytics, App Functionality |
| Diagnostics — Crash Data, Performance Data | Yes | No | No | App Functionality (stability) |
| Health, Financial, Location (precise), Browsing History, Contacts | No | — | — | — |

> "Budget" is a self-reported figure for guidance, stored as profile data
> (Usage/Other), **not** a financial account — declare under App Functionality,
> not "Financial Info".

---

## 4. Google Play — Data Safety form

- **Does your app collect or share user data?** Yes (collect). **Share:** only
  with processors acting on our behalf (Groq, OneSignal, Firebase, Supabase) —
  Play treats processor transfers as collection, **not** "sharing" for ads.
- **Is all data encrypted in transit?** Yes (HTTPS/TLS everywhere).
- **Can users request data deletion?** **Yes** — in-app (Profile → "Mes données"
  → Supprimer mon compte) and via account deletion URL (see §6). Export also
  available in-app.
- **Data types — collected, processed ephemerally?, required/optional, purpose:**

| Play data type | Collected | Purpose |
|---|---|---|
| Personal info — Name, Email, Phone, Other (birth date, guardian) | Yes | App functionality, Account management |
| Financial info | No | — (self-reported budget is App functionality, not a financial account) |
| Messages — in-app (cases), other (coach) | Yes | App functionality |
| Photos / Files — uploaded documents | Yes | App functionality |
| App activity — interactions, search history | Yes | Analytics, App functionality |
| App info & performance — crash logs, diagnostics | Yes | App functionality (stability) |
| Device / other IDs | Yes | Analytics, Push notifications |

> Mark **Name/Email/Phone** as *Required*; documents/budget/guardian as
> *Optional* where the flow allows skipping.

---

## 5. Age rating

- The Terms of Service set a **16+ minimum**; under-18s require **guardian
  consent** collected at onboarding (#60).
- The app has **user-generated content** (coach chat, community) → expect
  **Apple 12+** ("Infrequent/Mild" none; UGC present) and **Google "Teen"**
  on the content questionnaire. UGC also requires a **report/block** path —
  partially covered by the anti-fraud "report" action (KPB-53); confirm a
  content-report path exists for the community before submission.
- No gambling, no mature content, no unrestricted web access (WebView targets
  are fixed partner/price-comparison URLs).

**Recommended:** Apple **12+**, Google **Teen** — verify against the final
questionnaire.

---

## 6. Account deletion & data export (store requirement)

Both are **delivered** (KPB-67):

- **In-app:** Profile → "Mes données / RGPD" → **Exporter mes données** /
  **Supprimer mon compte** (irreversible; purges Postgres + best-effort Supabase
  auth identity — see ops note below).
- **Account deletion URL** (Apple/Play require a discoverable web path too):
  publish a page describing the in-app steps + a contact, and link it as the
  app's "Account deletion" URL in both consoles.

> **Ops follow-up (required for full compliance):** set
> `SUPABASE_SERVICE_ROLE_KEY` + `SUPABASE_URL` in the backend deploy env so
> deletion also removes the Supabase **auth identity**. Without it, all user
> data is purged but the login record survives (logged as a warning).

---

## 7. Performance budget (measured)

The airtime/low-end-device moat must be **measured, not asserted**. Reference
device: an entry-level Android with **~2 GB RAM** (e.g. a device matching the
target market). Fill in and keep these in the PR description for the award.

### How to measure

```bash
# APK size (per-ABI, release)
flutter build apk --release --split-per-abi
ls -lh build/app/outputs/flutter-apk/*.apk        # arm64-v8a is the headline number
# (or App Bundle delivered size)
flutter build appbundle --release

# Cold start (app fully closed → first frame), on the reference device:
adb shell am force-stop org.karatou.app   # use the real applicationId
adb shell am start-activity -W -n org.karatou.app/.MainActivity | grep -E 'TotalTime|WaitTime'
# average of 5 cold starts

# Bytes/session — capture a representative session (open app, browse, 1 coach turn):
#   Settings → Apps → KPB → Data usage   (before/after), or
adb shell dumpsys netstats detail | grep -A3 org.karatou.app   # uid totals
```

### Results (to fill in on the reference device)

| Metric | Target | Measured | Device / build |
|---|---|---|---|
| APK size (arm64, release) | ≤ 25 MB | _TBD_ | |
| App Bundle delivered size | ≤ 20 MB | _TBD_ | |
| Cold start (TotalTime, avg of 5) | ≤ 2.5 s | _TBD_ | |
| Bytes / typical session | ≤ 500 KB | _TBD_ | |

### Quick wins already applied / recommended
- ✅ Removed the unused `google_fonts` dependency (this PR).
- ☐ Defer non-critical startup work (OneSignal init, quick-actions) off the
  first frame (e.g. `addPostFrameCallback` / after first paint).
- ☐ Audit catalog image sizes; the data-saver mode (already present) should be
  the default on metered connections.

---

## 8. CI — coverage floor on critical modules (AC3)

Sync/merge/outbox correctness must not regress silently. Calibrate the floors
to **current** coverage first (`npx jest --coverage` / `flutter test
--coverage`), then set the floor at-or-just-below it so CI ratchets.

**Backend (`backend/jest.config` or `package.json` jest block):**

```jsonc
"coverageThreshold": {
  "global": { "statements": 60, "branches": 50, "functions": 60, "lines": 60 }
  // tighten after measuring; never set above current coverage (breaks CI).
}
```

**Flutter (CI step) — floor the sync/merge/outbox modules:**

```bash
flutter test --coverage
# Fail if the critical modules drop below the floor (uses lcov):
lcov --extract coverage/lcov.info \
  '*/services/sync_*' '*/services/*merge*' '*/services/case_message_outbox.dart' \
  -o coverage/critical.info
lcov --summary coverage/critical.info   # parse the % and fail under the floor
```

Wire both into the existing `Analyze & test` workflow.

---

_Last updated: 2026-06-27. Owner: keep in sync with any new SDK, data flow, or
third-party processor._
