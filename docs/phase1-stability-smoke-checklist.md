# Phase 1 Stability Smoke Checklist

Use this checklist for every release candidate before promotion to production.
Run on at least one physical Android device and one physical iOS device.

## Pre-flight

- Install latest release candidate build.
- Confirm backend target points to production or staging as intended.
- Ensure at least one test user has existing cases and one test user has no cases.
- Prepare one push notification payload for `/cases/{id}` and one for `/search`.

## ⚠️ Android package visibility — NOT substitutable by a test

**Run this on a physical Android 13 or newer. No unit or widget test can stand
in for it**, because package visibility only exists on a real device.

Why it matters: `targetSdkVersion` is 36. From API 30, an app only "sees" the
packages it declares, and `canLaunchUrl` returns false for anything undeclared —
*even with a browser installed*. Neither our manifest nor `url_launcher_android`
declared a VIEW intent. The `<queries>` block in
`android/app/src/main/AndroidManifest.xml` fixes the cause and
`lib/app/core/utils/external_link.dart` makes the failure visible instead of
mute, but only a device proves it.

- [ ] Open a scholarship whose `applicationUrl` is a valid `https://…` and tap
      **« Formulaire officiel »** → the browser **must** open.
- [ ] Tap any WhatsApp CTA → WhatsApp **must** open. This is the app's only
      monetization path; there is deliberately no in-app payment.
- [ ] Record the phone model and Android version in the ticket.

If either is a silent no-op, or shows "impossible d'ouvrir WhatsApp" on a device
that clearly has WhatsApp, the `<queries>` block did not take effect — stop and
investigate before shipping.

## Critical flows

### 1) App bootstrap and onboarding

- Launch app from cold start.
- Verify no crash or red screen at startup.
- Verify intro/onboarding renders and can complete end-to-end.

### 2) Auth and profile access

- Open login/register/forgot-password flows.
- Verify form submission and validation do not dead-end.
- Verify profile tab opens from home avatar action.

### 3) Cases stability states

- Cases with active sync and empty data -> skeleton loading appears.
- Cases with sync failure and empty data -> error state with retry appears.
- Cases with existing data + transient sync failure -> existing list remains visible.

### 4) Case creation and detail navigation

- Create case from Cases tab CTA.
- Create case from scholarship CTA (`/new-case`).
- Open case detail from list item tap.

### 5) Push/deep-link route handling

- Trigger push route `/cases/{id}` -> opens matching case detail.
- Trigger push route `/search` -> opens search screen.
- Trigger legacy route `/cases/create` -> opens case-create route (`/new-case`).
- Trigger unsupported route -> app remains stable (no crash).

### 6) Offline/reconnect resilience

- Disable network and relaunch app.
- Verify app remains navigable and does not crash.
- Re-enable network and verify sync recovers without app restart.

## Required evidence

- Screenshot or screen recording per section.
- Crashlytics screenshot proving no new fatal crash spike after smoke run.
- Short release note with pass/fail status and any known non-blocking issue.

## Sign-off

- QA sign-off: ________
- Engineering sign-off: ________
- Product sign-off: ________