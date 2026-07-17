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

## Lot 4 — Parcours de découverte (browse) — ✅ terminé le 17/07/2026

Branche : `claude/theme-lot4-browse` (depuis `main` post-#149).
**311 substitutions** sur 10 écrans ; 6 classes `_Palette` supprimées.

### Fichiers migrés (mapping §10.2)

- **Home** (13 hex) : `_Palette` → tokens ; divider ambre `#FDE68A` →
  `warning` α 0,3.
- **Recherche** : accents par type de résultat → field accents **exacts**
  (`financeGreen`, `lawPurple`, `businessSky`, `gold` — zéro changement) ;
  `match_explanation_sheet` : couleurs de score normalisées
  (≥85 `success`, ≥50 `warning` — cohérent avec MatchBadge).
- **Universités** (18 hex) : `_Palette` → tokens ; ombre `0x0A0F172A` →
  `KpbShadow.softNavy` (nouveau token) ; `chipBorder #BFDBFE` →
  `actionPrimary` α 0,3.
- **Explore / Pays / Programme** (45 hex) : `gradientEnd #1E3A8A` →
  `KpbColors.heroIndigo` (nouveau token, partagé avec `heroGradient`) ;
  `heading #1E40AF` → `actionPrimaryPressed` ; `cloud` → `borderStrong` ;
  `heartPink #FCA5A5` conservé (`kpb-allow-color`, allowlist) ;
  verts/ambres normalisés AA.
- **Comparaison** (17 hex) : `sheetShadow 0x400F172A` → `KpbShadow.scrimNavy`
  (nouveau token) ; `lineSoft` → `canvas`.
- **Destinations** (1 hex) : `_navy` → `brandNavy`. **Enregistrés** : 0 hex,
  vérifié.
- Ratchet durci : ne scanne plus que les fichiers **suivis par git** (les
  brouillons non commités d'une session concurrente ne cassent plus les runs
  locaux).

### Ratchet

`color_budget.dart` : **35 fichiers / 499 hex** (−100).

### Validation

- `flutter analyze` : 0 issue sur mes fichiers (2 infos restantes =
  fichiers Success Lab non trackés d'une session concurrente) ;
- `flutter test` : suite verte **hors 3 échecs préexistants causés par les
  modifications non commitées de la session concurrente**
  (`app_routes_test` : 16 routes vs 14 attendues — routes Success Lab ;
  2 tests logout de `app_controller_test`) — aucun de ces fichiers n'est
  dans le lot ; la CI de la PR (arbre committé) fait foi ;
- `dart format` : conforme.

### Écarts visuels volontaires

- Normalisations sémantiques AA habituelles (`green→success`, `red→error`,
  `amberBg→warningLight`, `redBg→errorLight`) ;
- `heading` pays : `#1E40AF` → `#1D4ED8` (léger éclaircissement) ;
- bordures de chips bleues : `#BFDBFE`/`#DBEAFE` → `actionPrimary` α 0,3/0,2 ;
- scores match : ≥50 passe de `gold` à `warning` (lisibilité icône/texte).

## Lot 5 — Bourses (V2 complète) — ✅ terminé le 17/07/2026

Branche : `claude/theme-lot5-scholarships` (depuis `main` post-#150).

### Fichiers migrés (49 hex → 0)

- **`live_scholarships_screen.dart`** (20 hex) : classe `_Palette` supprimée →
  tokens §10.2 ; `amberSolid → gold`, `cardShadow → KpbShadow.softNavy`,
  gradient promo guide → `[actionPrimarySoft, surface]` ; normalisations AA
  (`green→success`, `red→error`, fonds soft → rôles Light).
- **`scholarship_detail_screen.dart`** (15 hex inline) : canvas/brandNavy/
  border/textMuted/textFaint/gray700/success/actionPrimary/lawPurple ;
  scrim du bouton play vidéo `#D9000000 → Colors.black87` (standard Flutter).
- **`scholarship_guide_info_screen.dart`** (8 hex) : hero
  `[actionPrimaryPressed, brandNavy]`, intro sur navy `#DBEAFE → actionOnDark`,
  carte info `actionPrimarySoft` + bordure α 0,3, `heroIndigo`.
- **`widgets/how_to_apply_sheet.dart`** (2 hex) et
  **`widgets/scholarship_alert_button.dart`** (4 hex, états off/on/loading
  préservés — locals repointés sur les tokens) : + imports `app_tokens`.
- Vérifiés sans travail : `scholarship_eligibility_screen`,
  `scholarship_video_player_screen` (fond sombre immersif conservé, chrome sur
  tokens auto-repointés), `scholarships_controller`,
  `widgets/application_*`, `widgets/roadmap_timeline_view` (KpbColors auto).

### Statuts métier

`windowStatus` open/closingSoon/closed → success/warning/error : sémantique
intacte (tests `scholarship_eligibility_test` + badge verts).

### Ratchet

`color_budget.dart` : **30 fichiers / 448 hex** (−45). Feature bourses = 0 hex.

### Validation

- `flutter analyze` : 0 issue ; `dart format` : conforme ;
- périmètre bourses + thème : **75 tests verts** (liste restylée avec action
  d'alerte réelle, sheet détail, CTA guide, éligibilité, timeline, badges) ;
- suite globale : 362 verts + 2 échecs **hors périmètre** (logout
  d'`app_controller_test`, causés par les modifications non commitées de la
  session concurrente Success Lab sur `app_controller.dart` — la CI de la PR,
  qui ne contient que les fichiers du lot, fait foi).

### Écarts visuels volontaires

- `green #16A34A→success`, `red #DC2626→error`, fonds soft → rôles Light ;
- intro du guide sur navy : `#DBEAFE → actionOnDark` (blue-200 → blue-300) ;
- scrim play vidéo 85 % → `Colors.black87` (87 %, imperceptible).

## Lot 6 — Dossiers + notifications + profil — ✅ terminé le 17/07/2026

Branche : `claude/theme-lot6-cases` (depuis `main` post-#151).

### Fichiers migrés (117 hex → 0, 421 substitutions + 5 inline)

10 fichiers, 10 classes `_Palette` supprimées : `cases_screen` (16),
`case_detail_screen` (23 — dont bordure ambre → `warning` α 0,3, inline
`borderStrong`), `case_status_timeline` (12 — statuts d'étapes
acceptée/refusée → `success`/`error`, sémantique intacte), `case_tunnel_flow`
(5), `case_create_screen` (1), `document_review_screen` (4 — verdicts métier
approuvé/rejeté/en attente → `success`/`error`/`warning`),
`document_viewer_screen` (1), `post_decision_screen` (18),
`notifications_screen` (16 — bordure non-lu → `actionPrimary` α 0,3),
`profile_screen` (21 — `rose→medRed`, `blueText→actionPrimaryPressed`,
ombres → `KpbShadow.softNavy`).

**Première entrée d'allowlist permanente** : `#FDE68A` (second stop du dégradé
premium du profil, décoratif) — `// kpb-allow-color` + `theme-color-allowlist.md`.

### Ratchet

`color_budget.dart` : **20 fichiers / 331 hex** (−117).

### Validation

- `flutter analyze` : 0 issue ; `dart format` : conforme ;
- contamination croisée : `git diff origin/main` sur les cibles = zéro
  fragment Success Lab (garde-fou post-incident lot 5) ;
- périmètre (cases, notifications, parent, thème) : **65 tests verts** —
  les échecs transitoires observés pendant les sauvegardes de la session
  concurrente disparaissent en re-run isolé/complet ; CI de la PR fait foi.

### Écarts visuels volontaires

Normalisations AA habituelles : `green #16A34A→success`, `red #DC2626→error`,
fonds soft → rôles Light ; `bodyBlue/blueText #1E40AF→#1D4ED8` ;
bordures bleu-clair (`#BFDBFE`) → `actionPrimary` α 0,3.

## Lot 7 — Simulateurs, outils et contenu — ✅ terminé le 17/07/2026

Branche : `claude/theme-lot7-tools-content` (depuis `main` post-#152).

### Fichiers migrés (139 hex → 0, ~310 substitutions, 12 classes palette supprimées)

budget_calculator (12), flight_estimator (8 — gradients hero clair/sombre →
`KpbColors.heroGradient[Dark]`, quasi identiques), aha_moment (8),
community_screen (22 — fonds de catégories normalisés sur les rôles Light,
`sky #0EA5E9→businessSky`), forum_category (12), parcours_screen (8) et
parcours_story (3 — classes `_P`), premium_screen (19 — dégradé premium →
même allowlist `#FDE68A` que le profil, `cardTextOnNavy→gray200`,
`#4ADE80→successOnDark` nouveau token, ombre 12 % → `KpbShadow.mediumNavy`
nouveau token), salon (2 — badge LIVE `#E53935→error`, contraste blanc
3,7:1 → 6,5:1), ai_chat (15 — hero `[actionPrimary, decorSky]` reconstruit
en tokens), interview_simulator (18), motivation_letters (12).

Nouveaux tokens : `KpbColors.successOnDark` (#4ADE80, succès sur navy),
`KpbShadow.mediumNavy` (0x1F0F172A).

### Vérifiés sans travail (0 hex, auto-repointés)

housing, eligibility, deadlines, orientation ×2, france, academy ×2,
referral_screen, services, student_tools, cv_generator, document_scanner,
impact_dashboard, coach_fab.

### Ratchet

`color_budget.dart` : **8 fichiers / 194 hex** (−137). Restent : app_tokens
(~80) + lot 8 (commercial 38, ambassador 37, parent ~22) + divers ≤ 5.

### Validation

- `flutter analyze` : propre sur les fichiers trackés (1 warning résiduel dans
  un brouillon non tracké de la session concurrente, hors branche) ;
- périmètre (thème, parcours, home, aha, salon, communauté) : **70 tests verts** ;
- contamination croisée : zéro fragment Success Lab (diff origin/main vérifié).

### Écarts visuels volontaires

Normalisations AA habituelles + badge LIVE assombri (contraste amélioré) ;
fonds de catégories communauté sur les rôles Light (indigo-50→blue-50,
green-50 unifié, rose-50→red-50) ; hero sombre du vol `#0B1220→#0B1120`
(imperceptible). Branches `isDark` locales conservées (dead code light-only,
retrait au lot 9 pour limiter la surface de ce lot).

## Lot 8 — Parent, commercial, ambassadeur — ✅ terminé le 17/07/2026

Branche : `claude/theme-lot8-roles` (depuis `main` post-#153).

### Fichiers migrés (94 hex → 0, 3 classes palette supprimées)

- **`parent_surface_screen`** (21) + **`parent_dashboard`** (1) : classe `_P`
  → tokens ; `ink→textPrimary`, `blueSoft→actionPrimarySoft`, carte info
  `actionPrimarySoft`/`actionPrimaryPressed`.
- **`commercial_surface_screen`** (35) : classe `_C` → tokens ; **statuts de
  leads préservés** (converted/qualified/new → success/businessSky/error, tags
  on-dark via `successOnDark`/`decorSky`/`errorOnDark`) ; verdicts de review
  documentaire → bordures `error`/`warning` α ; helper `avatar()` catégoriel
  restauré en tokens (hash déterministe identique).
- **`ambassador_screen`** (37) : classe `_Amb` → tokens ; **sémantique cash
  préservée** (statuts filleuls application/quiz/premium/churned →
  actionPrimary/businessSky/lawPurple/error) ; identité indigo du leaderboard
  → nouveaux tokens `decorIndigo`/`decorIndigoLight` ; verre du code de
  parrainage → `glassBorder`/`glassBg` (normalisations 25→20 %/7→10 %) ;
  fond récompense `#FFF7ED→goldLight`.

Nouveaux tokens : `errorOnDark` (#FCA5A5), `decorIndigo` (#6366F1),
`decorIndigoLight` (#A5B4FC).

### Ratchet

`color_budget.dart` : **4 fichiers / 100 hex** — plus AUCUN écran avec couleur
en dur. Restent : `app_tokens.dart` (84, L0 légitime) + 3 fichiers data
(`fields_data` 12 — accents domaines d01..d12 côté données, `catalog` 2,
`app_api_client` 2) à trancher au lot 9 (tokens ou allowlist).

### Validation

- `flutter analyze` : 0 issue ; `dart format` : conforme ;
- périmètre (parent, commercial, referral, thème) : **61 tests verts** ;
- contamination croisée : zéro fragment Success Lab.

### Écarts visuels volontaires

Normalisations AA habituelles ; `blueSoft #DBEAFE→actionPrimarySoft` (comme la
nav) ; tags qualified on-dark `#BAE6FD→decorSky` ; statut premium
`#6D28D9→lawPurple` ; verres blancs sur navy alignés sur les tokens glass.

## Lot 9 — QA finale — ✅ terminé le 17/07/2026

Branche : `claude/theme-lot9-final-qa` (depuis `main` post-#154).

### Dette finale éteinte

- **Aliases retirés** : `engagement*` (5), `primary`, `primaryLight` — les
  5 dernières références migrées (guide bourses ×4, carrousel Home ×1).
  `brandBlueLegacy` conservé (marque héritée documentée).
- **Nav du shell** : branches `isDark` mortes inlinées (light-only).
  Les branches `isDark` de flight/housing/deadlines/academy_course sont
  **conservées à dessein** : elles traversent des signatures entières, ne
  référencent que des tokens, et forment la couture du futur mode sombre —
  refactor = risque sans gain visible (écart documenté vs plan §12/6A).
- **Data** : fallback catalogue → `KpbColors.csBlue` (import via la
  bibliothèque `app_models`) ; snackbar d'erreur de l'api_client →
  `errorLight`/`error` ; les 12 accents de `fields_data` allowlistés
  (données, miroir des seeds backend).

### Ratchet — état final du chantier

`color_budget.dart` : **1 fichier / 84 hex = `app_tokens.dart` uniquement.**
Toute la dette visuelle mesurable est éteinte (623 → 84, tous dans le foyer
légitime de la palette).

### Harnais de QA ajouté

- `test/flutter_test_config.dart` : Inter + Plus Jakarta Sans chargées dans
  TOUS les tests widget (rendu réel, plus d'Ahem).
- `test/goldens/theme_gallery_golden_test.dart` (tag `golden`) : galerie de
  référence du système (boutons, cartes, statuts, formulaire) 390×844 —
  `theme_gallery.png` committée ; runbook dans l'en-tête du fichier.
  CI : `--exclude-tags=golden` (rendu Linux ≠ macOS).
- `test/core/ui/a11y_scale_test.dart` : kit sans overflow à 360×800 en
  text scale 1.0 **et 1.3** (clamp app).

### Validation

- `flutter analyze` : 0 issue ; `dart format` : conforme ;
- **406 tests verts** (goldens et audit d'échelle inclus) ;
- APK **debug prod** (`--dart-define=KPB_APP_ENV=prod` + numéro WhatsApp)
  buildé et horodaté (artefact d'installation du plan §17) ;
- APK **release** : bloqué localement par le garde-fou volontaire du
  production-launch — « Release signing configuration is missing » — le
  keystore d'upload (`android/key.properties`) n'existe que côté humain et
  dans les secrets CI (job « Produce signed Android App Bundle » sur main).
  Non contourné, à dessein.

### Reste côté humain (Definition of Done, plan §17–18)

- [ ] Revue visuelle sur simulateur/appareil : entrée, 5 onglets, une fiche
      bourse, un dossier (jamais faite depuis le lot 1 — dernière gate).
- [ ] Installation de l'APK fraîchement buildé sur appareil : entrée non
      connectée → connexion → shell → session persistante (plan §17).
- [ ] Captures avant/après jointes à ce rapport.
