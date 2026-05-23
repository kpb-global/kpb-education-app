# KPB M1-M14 Conformity Audit

This audit maps the current repository state to the product target defined in:
- `docs/App goal/00_CAHIER_DES_CHARGES_MASTER.md`
- `docs/App goal/01_ANNEXE_PERSONAS_USER_STORIES.md`
- `docs/App goal/02_ANNEXE_MODELE_DONNEES.md`
- `docs/App goal/06_ANNEXE_API_ENDPOINTS.md`

## Summary

- Strong foundations on mobile UX shell, offline sync patterns, and case timeline screens.
- Major launch blockers remain on the end-to-end business loop:
  - auth entrypoint and role routing
  - round-robin + commercial operations
  - push token registration and transactional push coverage
  - real IA flows (orientation explanations + coach quotas)
  - full data ingestion for countries/quizzes/partners/programs

## Module matrix

| Module | Status | Evidence | Critical gap |
|---|---|---|---|
| M1 Auth OTP | Partial | `lib/app/features/auth/*`, `backend/src/modules/auth/*` | Main app bootstrap still bypasses explicit auth flow and OTP-first UX is not enforced end-to-end in mobile entry routing. |
| M2 Onboarding | Partial | `lib/app/features/onboarding/*` | Not all profile fields from target flow are captured with strict step parity. |
| M3 Profil | Partial | `lib/app/features/profile/*`, `backend/src/modules/profiles/*` | Profile completeness and docs management are not fully aligned with target model. |
| M4 Orientation IA | Partial | `lib/app/features/orientation/*` | Local flow exists but needs stronger result quality/persistence parity with target acceptance criteria. |
| M5 Destinations | Partial | `lib/app/features/explore/*` | Country eligibility quizzes and country-level conversion CTAs are not fully wired as specified. |
| M6 Recherche universites | Partial | `lib/app/features/search/*` | Program search and partner-first controls need final parity with spec filters/sorting and loaded catalog depth. |
| M7 Admission France prive | Missing/partial | scattered in country/program flows | Dedicated France-private admission tunnel not complete. |
| M8 Demandes | Partial | `lib/app/features/cases/*`, backend `cases` module | End-to-end request creation to remote assignment path needs stronger operational linkage. |
| M9 Commerciaux | Partial | backend cases/admin | Round-robin + 10h reassignment + commercial mobile workspace are incomplete. |
| M10 Coach IA | Partial | `lib/app/features/ai_advisor/*` | Quota, guardrails, and production IA backend integration need completion. |
| M11 Simulateur budget | Partial | `lib/app/features/budget/*` | Needs strict output model and integration with search/save flows. |
| M12 Bourses | Partial | scholarships screens/backend indexing | MVP seed and eligibility-centric flow still incomplete for full launch target. |
| M13 Push + Admin cloud | Partial | `push_notification_service.dart`, backend notifications | Device token registration and campaign/transaction loops require final hardening. |
| M14 Mes demandes timeline | Partial | `lib/app/features/cases/*` | Realtime signaling and unread badge semantics need finalization. |

## Priority order used for execution

1. Foundations (M1-M3) + device token + route reliability
2. Data seed/injection parity
3. Core conversion flow (M5-M8-M14)
4. Commercial operations (M9-M13)
5. IA + budget + scholarship quality (M4/M10/M11/M12)
6. Release gate and launch controls
