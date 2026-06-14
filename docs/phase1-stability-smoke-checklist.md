# Phase 1 Stability Smoke Checklist

Use this checklist for every release candidate before promotion to production.
Run on at least one physical Android device and one physical iOS device.

## Pre-flight

- Install latest release candidate build.
- Confirm backend target points to production or staging as intended.
- Ensure at least one test user has existing cases and one test user has no cases.
- Prepare one push notification payload for `/cases/{id}` and one for `/search`.

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