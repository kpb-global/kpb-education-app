# Ambassador cash programme — rollout & legal checklist (KPB-160)

The **cash** Ambassador programme (FCFA balances, city leaderboard, Wave
withdrawals, in-app self-activation) is **gated OFF by default**. This document
is the operating procedure for keeping it safe and for opening it once legal
clearance is obtained.

> The **no-cash** referral programme (credits → WhatsApp advisor voucher,
> `ReferralScreen`) is unaffected and remains the default surface.

## Why it is gated

- **Play policy** — cash-for-referral can read as *incentivized installs* /
  deceptive behavior.
- **AML / KYC / tax** — cross-border FCFA payouts (Wave) create identity,
  reporting and tax duties that differ per country.
- **Minors** — the app has under-18 users; paying minors is a distinct risk.
- **Fraud** — self-referral rings, fake placements.

## How the gate works

`AmbassadorScreen` shows the cash surface only when:

```
AppConfig.ambassadorCashEnabled == true   // global flag, build-time
  OR  dashboard.activated == true          // this user is an ops-activated ambassador
```

Otherwise it shows an **application screen** — no FCFA, no leaderboard, no
withdrawal, no self-activation — just a "contact an advisor" path and a link to
the free referral programme.

- **Flag:** `KPB_AMBASSADOR_CASH_ENABLED` (`--dart-define`), default `false`
  (`lib/app/core/config/app_config.dart`). Build-time; flipping it needs a
  release.
- **The profile entry stays visible** ("Devenir ambassadeur"); it routes to the
  screen, which self-gates. New/unverified users therefore never see cash
  mechanics and cannot self-activate.

## Activating an individual ambassador (whitelist, flag left OFF)

Active ambassadors keep full access regardless of the flag. Activation is
**server-side and manual** (ops), not self-serve:

1. Vet the person (18+, identity, payout account).
2. Mark their `Ambassador` record `activated = true` in the backend
   (admin/DB). From then on their app shows the full cash surface.
3. Payouts remain manual via Wave (no automated transfer API).

> There is no in-app "activate" button while gated — this is intentional so
> activation can only happen through the vetted ops path.

## Opening the programme to everyone

Only after the legal checklist below is cleared:

1. Set `KPB_AMBASSADOR_CASH_ENABLED=true` in the release build config.
2. Ship a store release.
3. Monitor fraud/withdrawal metrics.

## Legal / compliance checklist (to clear before opening)

- [ ] **Play / App Store**: confirm the cash-referral mechanic is compliant
      (incentivized-behavior, real-money, and gambling-adjacent policies).
- [ ] **Countries in scope**: list the countries where payouts will run; confirm
      money-transmission / referral-reward legality in each.
- [ ] **KYC**: what identity verification is required before a payout, per
      country, per threshold?
- [ ] **Payout thresholds & caps**: minimum withdrawal, per-period caps,
      lifetime caps.
- [ ] **Tax**: reporting/withholding obligations on rewards, per country.
- [ ] **Minors**: exclude under-18s from cash (enforced by age/guardian data)?
- [ ] **Fraud controls**: self-referral detection, velocity limits, payout
      audit trail, clawback policy.
- [ ] **Terms**: ambassador T&Cs, consent, data handling for payout accounts.
- [ ] **Wave / payment provider**: contractual terms for bulk payouts.

---

*Source: Diagnostic produit 22/07/2026 — cycle 1 (Sécuriser), KPB-160.*
