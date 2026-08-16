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

### Feature masking flags (build-time, default **off**)

Two features are hidden from the shipped build because they cannot be made
honest in time. Both are `--dart-define` booleans read through `AppConfig`, and
both are covered by a masking test with a counter-proof, so flipping them back
on is a one-line change whose effect is already measured.

| `--dart-define` | Default | What it hides, and what has to be true before flipping it on |
|-----------------|---------|--------------------------------------------------------------|
| `KPB_AI_TOOLS_ENABLED` | **`false`** | **M1** — the CV generator, motivation letters, interview simulator and AI document review (10 entry points across 4 screens). Lot 11 stripped the civil name from Groq prompts and added `AiConsentGuard` on those routes. **Keep the flag off until that backend is deployed with build 49** — flipping it while 48 testers still hit prod would 403 them. Guard: [`test/core/masquage_ai_tools_test.dart`](../test/core/masquage_ai_tools_test.dart). |
| `KPB_DOCUMENT_UPLOAD_ENABLED` | **`false`** | **M2** — in-app document upload. The case tunnel never transmitted a byte (it kept a local file path and wrote its name into the case description), and the one real upload path ticked `isProvided: true` *before* the network call, then swallowed the failure — while the server's antivirus container is down and the route fails closed. While off, documents go to the advisor on WhatsApp and the app stops fabricating the `doc-profile` request. Flip on **only after** the upload chain works end to end: antivirus alive, failure visible on screen, and "provided" set by the server's answer rather than by local optimism. Guard: [`test/core/masquage_documents_test.dart`](../test/core/masquage_documents_test.dart). |

```bash
# Re-enable one of them for a local check (never for a store build
# until its precondition above is actually met):
flutter run --dart-define=KPB_AI_TOOLS_ENABLED=true
```

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

- **Upload key:** keystore + `android/key.properties` locally (gitignored). The four CI secrets `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_PASSWORD`, `ANDROID_KEY_ALIAS` are **required** before creating a `v*` tag. The tag pipeline fails instead of producing a debug-signed release and uploads a signed AAB.
- **Play App Signing:** recommended; keep upload key in password manager + offline backup.
- **Store listing:** short/long description, screenshots (phone + 7" tablet if required), feature graphic, privacy policy URL, data safety form aligned with [`security-compliance.md`](security-compliance.md) and in-app legal copy.

#### Vérifier la chaîne de signature SANS créer de tag (KPB-154)

Le job `release-android` ne se déclenchait que sur un tag `v*`. Aucun tag n'ayant
jamais été poussé, il n'avait **jamais tourné** — et le secret
`ANDROID_KEYSTORE_BASE64` contenait 11 caractères (un placeholder). Autrement
dit : la capacité à signer n'avait jamais été prouvée. Un tag est une décision de
release ; vérifier qu'on *peut* signer ne doit pas en exiger un.

Procédure, dans l'ordre :

1. **Poser les 4 secrets** depuis le keystore local (`android/upload-keystore.jks`
   + `android/key.properties`, tous deux gitignorés). Le base64 ne doit jamais
   passer par un chat ni un ticket :

   ```bash
   base64 -i android/upload-keystore.jks | tr -d '\n' | pbcopy
   ```

   → coller dans `ANDROID_KEYSTORE_BASE64`. Puis `ANDROID_KEYSTORE_PASSWORD`,
   `ANDROID_KEY_PASSWORD`, `ANDROID_KEY_ALIAS` d'après `key.properties`.

2. **Lancer `Keystore info`** (Actions → Keystore info → Run workflow). Il
   affiche l'alias et les empreintes SHA-1/SHA-256 du certificat **sans** exposer
   la clé. Si le secret est encore un placeholder, il le dit explicitement.

3. **Comparer l'empreinte** à Play Console → *Test and release* → *Setup* →
   *App signing* → **Upload key certificate**. Les SHA-256 doivent être
   identiques. C'est le test qui décide de tout :

   | Résultat | Signification |
   |---|---|
   | Identiques | La continuité est établie ; on peut uploader. |
   | Différentes, Play App Signing **actif** | Demander une *upload key reset* dans Play Console : la clé d'app reste chez Google, les installs existantes continuent de se mettre à jour. Récupérable. |
   | Différentes, Play App Signing **inactif** | Aucune mise à jour de l'app publiée n'est possible. À traiter comme un incident, pas comme une tâche. |

4. **Produire l'AAB signé à la demande** : Actions → *Flutter CI* → *Run
   workflow* → cocher `release_android`. Le job échoue si le keystore est absent
   ou invalide, vérifie la signature avec `jarsigner -verify -strict`, publie
   l'empreinte du certificat de l'artefact, et attache l'AAB en artefact de run.

5. **Upload en piste interne** Play Console avec cet AAB. C'est seulement à ce
   moment que la chaîne est prouvée de bout en bout.

### iOS (App Store)

- **Distribution signing:** Apple Development / Distribution certificates, provisioning profiles, and **Release** `aps-environment=production` for push (configured in `RunnerRelease.entitlements`).
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
- [ ] Android CI secrets verified; the `v*` tag produces and verifies a signed AAB (never debug-signed).
- [ ] iOS archive uses an Apple Distribution certificate, provisioning profile and `RunnerRelease.entitlements`.
- [ ] Profile build smoke on **physical** Android + iOS (Phase 1 smoke + Phase 6 perf spot-check).  
- [ ] Store consoles updated; privacy / data safety answers match shipping build.

## 5. IRR-T6 — Custom SMTP on Supabase (prepare, do not execute)

Supabase's built-in email hits a 429 under OTP load. Custom SMTP is the
remedy (KPB-7). **Do not click Save in the dashboard from this lot.**

Procedure, when ops is ready:

1. Pick a transactional sender already in production (Resend is already a
   processor — see `docs/data-inventory.md`). Create an SMTP credential
   dedicated to auth mail, not campaign mail.
2. Supabase Dashboard → **Authentication → SMTP Settings → Enable custom SMTP**.
3. Fill host / port / user / password / sender name + address. Sender domain
   must match the SPF/DKIM already published for that provider.
4. Send a test magic-link / OTP to a throwaway inbox. Confirm the mail is
   not still branded "Supabase" and that a second send within a minute does
   **not** 429.
5. Record the date and the sender address in the release ticket. Do not
   paste the SMTP password anywhere in this repo.

## 6. LIV-T14 — Delivery gate (four curls, after a backend deploy)

`scripts/delivery-gate.sh` is the checklist. It talks to production; **do not
run it from a lot PR**. CAT-T4 (`dateConfidence` on catalog scholarships)
only becomes true after the backend that shipped that field is actually
serving — a green unit test is not a substitute.

