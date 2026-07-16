# Progression — Thème global KPB Intelligence

Référentiels : `docs/fable-global-theme-implementation-plan.md` (processus) ·
`docs/fable-global-theme-architecture.md` (spécification technique, lots)

Environnement de référence : Flutter 3.44.1 stable (rev 924134a44c) · Node 26.0.0

---

## Lot 0bis — Réconciliation Git + baseline (option A) — ✅ terminé le 16/07/2026

### Décision

Option A retenue (validée par Aminou) : atterrir le WIP d'abord, puis implémenter
le thème depuis `main` à jour.

### Actions réalisées

- [x] **Sanctuarisation du WIP** : commit `c4d140d` sur `codex/production-launch`
      — 130 fichiers (+14 594 / −1 273) : entrée KPB Intelligence validée
      (design-qa.md), tokens `engagement*`, bourses V2 (détail, guide, vidéos,
      alertes), backend scholarships-index, migrations Prisma, admin, CI, config
      release iOS/Android, docs. Seul `tmp/` (scratch) exclu.
- [x] **Fusion `origin/main` → branche** : commit `c71c77b` — 16 commits
      réconciliés (#129→#145, dont polices #134, polish KPB Intelligence #139,
      déploiement Hostinger/Traefik #144, fix onboarding #145).
- [x] **7 conflits résolus** (détail dans le message du commit `c71c77b`) :
      | Fichier | Résolution |
      |---|---|
      | `.github/workflows/flutter-ci.yml` | pipeline AAB signé (WIP) + commentaire domaine `.cloud` (main) |
      | `docker-compose.yml` | healthcheck (WIP) **et** labels Traefik #144 (main) — complémentaires |
      | `docs/DEPLOYMENT.md` | domaine `admin.kpbeducation.cloud` (main) + `KPB_TRUST_PROXY_HOPS=1` (requis par `backend/src/main.ts`) |
      | `lib/app/core/config/app_routes.dart` | route `scholarshipDetail` V2 (WIP) + commentaire main ; import `app_models` conservé |
      | `lib/app/features/shell/app_shell.dart` | structure nav WIP (pill KPB Intelligence, labels toujours visibles) + `FittedBox` anti-troncature (main) |
      | `lib/app/features/home/home_screen.dart` | header redessiné WIP (copilote = entrée KPB Intelligence) ; chips search/saved/`_KpbIntelligenceChip` de #139 retirés (doublon fonctionnel ; classe orpheline supprimée) |
      | `test/features/scholarships/live_scholarships_screen_test.dart` | sémantique WIP (action d'alerte réelle) + libellé localisé `J-days` (main) |
- [x] **Baseline validée** :
      - `flutter analyze` : **0 issue** ;
      - `flutter test --dart-define=KPB_ENABLE_REMOTE_SYNC=false` : **293 tests verts** ;
      - backend `npm test` : **38 suites / 226 tests verts** ;
      - `dart format lib test` : **0 changement** (306 fichiers conformes).
- [x] Polices Inter + Plus Jakarta Sans désormais présentes dans l'arbre
      (via la fusion de #134) — l'étape « restauration depuis 0db3c40 » du plan
      §7.1 est **caduque**.

### Écarts visuels volontaires introduits par la réconciliation

- Header Home : les chips AppBar search/saved/KPB-Intelligence de #139 sont
  remplacés par le header du redesign WIP (cloche + copilote + profil).
  Recherche et favoris restent accessibles (Quick Actions, onglets, routes).
- Nav bar : labels toujours visibles (WIP) au lieu de « sélectionné seulement »
  (#140), avec le correctif `FittedBox` anti-troncature conservé.

### Reste à faire avant le lot 1

- [ ] **Push + PR vers `main`** : voir section PR ci-dessous.
- [ ] **Captures baseline** (plan §6) : entrée non connectée, onboarding, accueil
      connecté, bourses, universités, dossiers, profil — 360×800 + iPhone,
      text scale 1.0 et 1.3. À prendre sur l'état **post-fusion** (c'est lui la
      référence avant le big-bang du lot 1). Nécessite simulateur/appareil.

## Lot 1 — Tokens + ThemeData + extension + ratchet — ⬜ non démarré

## Lot 2 — Primitives KPB — ⬜ non démarré

## Lot 3 — Entrée + onboarding + shell — ⬜ non démarré

## Lots 4–9 — ⬜ non démarrés
