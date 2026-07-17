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

## Lot 1 — Tokens + ThemeData + extension + ratchet — ✅ terminé le 16/07/2026

Branche : `claude/theme-lot1-foundations` (depuis `main` post-#146). Zéro écran
touché : le re-skin global passe par le re-pointage des tokens.

### Fichiers

- `lib/app/core/ui/app_tokens.dart` — rôles sémantiques canoniques
  (`brandNavy`, `actionPrimary[Pressed|Soft]`, `canvas`, `surface[Muted]`,
  `border[Strong]`, `text*`, `decorSky`, `whatsapp`, `actionOnDark`…) ;
  **re-pointage** des noms historiques (`blue → #2563EB`, `navy → #0F172A`,
  neutres gray → échelle slate, `bgPage → #F8FAFC`…) ; `brandBlueLegacy`
  conserve #004AAD pour la marque héritée ; aliases `engagement*`/`primary`
  maintenus ; `KpbColorsDark` (valeurs sombres regroupées, non conçues) ;
  `KpbMotion` ; `KpbTypography` (typedef) + `bodyFamily` + styles titres
  complémentaires (`displayXs`, `headlineLg`, `headlineSm`, `titleSm`).
- `lib/app/core/ui/app_theme.dart` — `ColorScheme` explicite (plus de
  `fromSeed` en light), `surfaceTint` transparent, `InkRipple`, extension
  enregistrée, sous-thèmes complets : AppBar, Card (bordure), Chips, Inputs,
  Filled/Elevated/Outlined/Text buttons (52 px), NavigationBar, Divider,
  ListTile, IconTheme, BottomSheet, **Dialog, SnackBar (navy), TabBar,
  Tooltip, PopupMenu, Drawer, FAB, Radio, SegmentedButton, Badge** (nouveaux),
  Switch/Checkbox, Progress, TextTheme 15 slots. Zéro hexadécimal.
- `lib/app/core/ui/kpb_theme_ext.dart` — `KpbThemeColors` devient une
  **`ThemeExtension`** (instances const `light`/`dark` lues depuis les
  tokens) ; API des 370 call-sites inchangée (`context.kpb`, `.of()`) ;
  les styles `ts*` retrouvent leurs familles de polices. Zéro hexadécimal.
- Tests : `test/core/ui/app_tokens_test.dart` (valeurs, re-pointages, aliases,
  familles, **contrastes WCAG calculés**), `app_theme_test.dart` (palette,
  typo, extension, composants, cible tactile ≥ 48 dp),
  `color_audit_test.dart` + `color_budget.dart` — **ratchet** : budget par
  fichier (49 fichiers, 623 hex à date), interdiction de toute nouvelle
  couleur en dur, budgets décroissants only, L1/L2 verrouillés à 0 hex.
- `docs/theme-color-allowlist.md` créée (aucune exception permanente à date).

### Validation

- `flutter analyze` : 0 issue ; `dart format` : conforme ;
- `flutter test --dart-define=KPB_ENABLE_REMOTE_SYNC=false` : **328 tests
  verts** (293 existants — aucun cassé par le re-pointage — + 35 nouveaux).

### Écarts vs architecture (documentés)

- `iconTheme` global : couleur `textSecondary` appliquée, mais **pas** la
  taille 22 (§7.2) — éviter un décalage de layout global au lot 1.
- `context.kpb.textMuted` passe de `#9CA3AF` (2,5:1, échec AA) à `#64748B`
  (4,76:1) : les textes atténués foncent légèrement partout — voulu,
  aligné sur le précédent du repo (« WCAG AA tuned »).

### Reste (repris au lot 3/9)

- Captures avant/après sur simulateur (baseline post-#146 → lot 1).
- Revue visuelle humaine des 5 onglets (gate du plan §8).

## Lot 2 — Primitives KPB — ✅ terminé le 16/07/2026

Branche : `claude/theme-lot2-primitives` (depuis `main` post-#147).

### Composants mis à niveau (architecture §9)

- **`KpbButton`** : refondu en façade sur FilledButton/OutlinedButton/TextButton
  — enum `KpbButtonVariant {primary, secondary, tertiary, destructive}`,
  états pressed/disabled/focus et hauteurs (52/48 px) hérités du thème, plus
  aucune couleur locale. Compat totale : `secondary:` mappe sur la variante,
  `bgColor/backgroundColor/textColor` restent fonctionnels (dette listée),
  `label/text` et `onTap/onPressed` conservés. Hors `fullWidth`, le bouton
  épouse son contenu (le thème impose sinon une min-width infinie).
- **`KpbCard`** : variantes `standard / interactive` (press-scale + haptique via
  KpbPressable) `/ highlighted` (bordure action + fond soft) ; défauts
  sentinelles conservés.
- **`KpbStatusChip`** *(nouveau)* : `KpbStatus {success, warning, error, info,
  neutral}` → fg/bg/bordure/icône ; icône + libellé toujours présents (jamais
  la couleur seule).
- **`MatchBadge`** : tiers accessibles — ≥80 `success`, ≥60 `warning`
  (gold 2,15:1 échouait), sinon `actionPrimary` (sky 2,14:1 échouait).
- **`SectionHeader`** : ternaire mort corrigé — action `actionPrimary`, et
  `actionOnDark` sur hero sombre (9,9:1 sur navy).
- **Bannières** offline / sample-data : fond via `context.kpb.warningLight`
  (theme-aware) ; sync-error : cible tactile du « réessayer » élargie (+8 px).
- **Skeletons** : `skeleton.dart` (4 hex → tokens ext), `skeleton_loader.dart`
  (fill blanc → `cardBg`).
- **`KpbInputDecoration`** : délègue au `inputDecorationTheme` global
  (signature conservée).
- **`VerifiedAdvisorSheet`** : 4 verts inline → `successLight`/`success`/
  `textPrimary` (normalisation AA §10.2) ; CTA WhatsApp → token
  `KpbColors.whatsapp`.
- **`AdmissionMeter`** : piste claire → `textFaint` α 0,2 (au lieu de noir 6 %).
- **Barrel `kpb_components.dart`** : 8 exports manquants ajoutés (status chip,
  bannières, badges vérifiés, advisor sheet, anti-fraude, coming soon,
  source link) ; 4 imports directs devenus redondants retirés des écrans.
- Auto-repointés sans modification : KpbBadge, KpbBadgeLight, KpbRefresh,
  KpbEmptyState/ErrorState, QuickActionTile, CountryCard, drawer, CoachFab.
  Mini-cards hero (institution/scholarship) déjà sur tokens dark — allowlist
  « surface immersive ».

### Ratchet

`color_budget.dart` régénéré : **47 fichiers / 614 hex** (−9 : advisor sheet
5→0, skeleton 4→0). `core/ui` entier = 0 hex hors `app_tokens.dart` (76).

### Validation

- `flutter analyze` : 0 issue ; `dart format` : conforme ;
- `flutter test --dart-define=KPB_ENABLE_REMOTE_SYNC=false` : **352 tests
  verts** (328 précédents + 24 nouveaux : variantes/états KpbButton, variantes
  KpbCard, statuts KpbStatusChip, tiers MatchBadge, bannière).

### Écarts documentés

- Pas d'annotations `@Deprecated` sur les params de compat (elles créeraient
  des infos analyzer à chaque call-site hérité → CI rouge) ; compat documentée
  en commentaire, dette suivie par l'allowlist.
- Bouton secondaire : rendu passe de « fond gris » à « blanc + bordure »
  (spec §7.2) — 1 seul call-site `secondary:` concerné.
- `KpbPageScaffold`/`KpbPageHeader`/`KpbSectionCard` : différés jusqu'à
  démonstration de répétition au lot 4 (règle du plan §9).

## Lot 3 — Entrée + onboarding + shell — ✅ terminé le 17/07/2026

Branche : `claude/theme-lot3-shell-auth` (depuis `main` post-#148).

### Fichiers migrés

- **`auth_welcome_screen.dart`** (entrée validée) : les 8 refs `engagement*`
  passent aux rôles canoniques (`canvas`, `brandNavy`, `textMuted`,
  `actionPrimary`, `border`) — valeurs identiques, **rendu strictement
  inchangé** ; 3 hex → tokens (`googleBlue` nouveau token marque externe,
  `textFaint`, `gray700`). Actions Google/email intactes.
- **`onboarding_screen.dart`** : classe `_Palette` locale (12 hex, 63 usages)
  **supprimée** → tokens centraux (mapping §10.2). Normalisations AA :
  `red #DC2626→error`, `green #16A34A→success`, `greenSoft→successLight`,
  `amberSoft #FEF3C7→warningLight`.
- **`app_shell.dart`** (nav flottante) : `engagement*` → rôles ; pill
  sélectionnée `#DBEAFE → actionPrimarySoft` (spec §9.5) ; icônes/labels au
  repos `textDarkSecondary #94A3B8 → textMuted #64748B` (icônes porteuses de
  sens ⇒ ≥ 3:1). Clé de test `kpb_shell_nav_bar`, 5 onglets et ordre
  inchangés ; aucun blur ajouté.
- **`app_tokens.dart`** : + `googleBlue #4285F4` (marque externe, comme
  `whatsapp`).

### Vérifiés — aucun travail nécessaire

`magic_link_email/verify`, `app_lock` (déjà `context.kpb`/tokens),
`app_boot_screen`, `app_root_shell`, `commercial_shell` (aucune couleur),
`kpb_tools_drawer` (accents auto-repointés, bg canvas),
`connectivity_service` (déjà sémantique warning/success).

### Ratchet

`color_budget.dart` : **44 fichiers / 599 hex** (−15 : onboarding 12→0,
auth_welcome 3→0, app_shell 1→0).

### Validation

- `flutter analyze` : 0 issue ; `dart format` : conforme ;
- **352 tests verts** (dont `onboarding_screen_test` et
  `shell_navigation_test` inchangés).

### Écarts visuels volontaires (documentés)

- Nav : pill sélectionnée un cran plus claire (blue-100 → blue-50, spec §9.5) ;
  repos plus foncé (2,56:1 → 4,76:1).
- Onboarding : 4 normalisations sémantiques AA listées ci-dessus.

## Lots 4–9 — ⬜ non démarrés
