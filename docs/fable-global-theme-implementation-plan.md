# Plan Fable — Déployer le thème KPB Intelligence dans toute l'application Flutter

Statut : prêt à exécuter par phases  
Date : 16 juillet 2026  
Périmètre : application Flutter étudiante, parent et commerciale  
Hors périmètre : backend NestJS, admin Next.js, contenu métier, dark mode et déploiement production

## 1. Résultat attendu

Transformer le design « KPB Intelligence » déjà validé sur l'écran d'entrée en
véritable système visuel global, visible aussi par un utilisateur déjà connecté.

À la fin :

- tous les écrans Flutter utilisent une même palette sémantique ;
- les composants Material et KPB ont les mêmes formes, espacements et états ;
- Inter est la police du corps et de l'interface ;
- Plus Jakarta Sans est la police des titres ;
- aucun écran principal ne recrée sa propre palette locale ;
- le fonctionnement, les routes, les données, les alertes et les CTA restent
  inchangés ;
- le thème est vérifié sur une installation neuve et sur un compte déjà connecté ;
- l'APK livré est reconstruit depuis le bon checkout après les changements.

Ce travail n'est pas une simple modification de `ThemeData`. Le dépôt contient
463 couleurs hexadécimales locales, 115 utilisations directes de
`KpbColors.blue` et plusieurs composants qui fixent leurs propres couleurs.
L'implémentation doit donc combiner thème global, primitives réutilisables et
migration progressive des écrans.

## 2. Diagnostic confirmé dans le dépôt

### Ce qui existe déjà

- le point d'entrée Flutter est `lib/main.dart` ;
- `GetMaterialApp` charge `AppTheme.buildTheme()` ;
- le runtime est forcé en `ThemeMode.light` ;
- le thème global actuel reste le thème historique bleu clair dans
  `lib/app/core/ui/app_theme.dart` ;
- les couleurs KPB Intelligence existent partiellement dans
  `lib/app/core/ui/app_tokens.dart` :
  - navy `#0F172A` ;
  - action blue `#2563EB` ;
  - canvas `#F8FAFC` ;
  - border `#E2E8F0` ;
  - muted `#64748B` ;
- `AuthWelcomeScreen` utilise déjà cette direction ;
- la navigation principale et le guide des bourses en utilisent quelques
  éléments ;
- `KpbThemeColors` existe, mais duplique encore plusieurs anciens hex ;
- le kit `lib/app/core/ui/components/` existe, mais certaines primitives
  fixent encore `KpbColors.blue`, `KpbColors.bgCard` ou leurs propres styles.

### Ce qui manque

- la palette KPB Intelligence n'est pas la palette sémantique du `ThemeData` ;
- la typographie validée n'est pas présente dans cette branche ;
- les fichiers Inter et Plus Jakarta Sans sont disponibles dans l'objet Git
  `0db3c40`, mais ce commit n'est pas dans l'ancêtre de la branche actuelle ;
- les écrans déjà connectés sautent `AuthWelcomeScreen`, donc ils ne voient pas
  le nouveau design d'entrée ;
- plusieurs écrans ont des styles locaux ou des variantes dark inutiles alors
  que le lancement est light-only ;
- aucun test dédié ne verrouille la palette, les polices ou les principaux
  composants du thème ;
- l'APK présent dans le dossier `build` peut être antérieur au design.

## 3. Source visuelle à respecter

La direction visuelle est celle documentée dans `design-qa.md` :

| Rôle | Valeur cible |
| --- | --- |
| Texte et marque navy | `#0F172A` |
| Action principale | `#2563EB` |
| Fond de page | `#F8FAFC` |
| Surface/card | `#FFFFFF` |
| Bordure | `#E2E8F0` |
| Texte secondaire | `#475569` |
| Texte muted | `#64748B` |
| Succès | `#047857` |
| Avertissement | `#B45309` |
| Erreur | `#B91C1C` |
| Accent premium/bourse | `#F59E0B` |
| Police corps/UI | Inter |
| Police titres | Plus Jakarta Sans |

Le bleu historique `#004AAD` peut rester comme couleur de marque héritée pour
un logo ou un visuel explicitement validé, mais il ne doit plus être l'action
principale par défaut.

## 4. Règles de travail obligatoires pour Fable

1. Travailler depuis la racine exacte :
   `/Users/aminou/Documents/Coding/kpb-education-new-app-aminoudev Global`.
2. Vérifier `git status --short` avant chaque phase.
3. Le worktree est déjà modifié : ne jamais effectuer de reset, checkout
   destructif, suppression globale ou réécriture non liée.
4. Ne pas cherry-pick `0db3c40` en bloc. Extraire seulement les polices, leur
   licence, la déclaration `pubspec.yaml` et les lignes de typographie utiles.
5. Ne modifier ni `backend/` ni `admin/`.
6. Ne changer aucune route, contrat API, condition d'éligibilité ou logique
   métier pour résoudre un problème visuel.
7. Exécuter une seule phase à la fois.
8. Après chaque phase : format, analyse et tests ciblés.
9. Ne pas stage, commit ou push sans demande explicite.
10. Maintenir `docs/fable-global-theme-implementation-progress.md` avec les
    cases terminées, les fichiers modifiés, les tests et les écarts visuels.

## 5. Architecture cible

```text
KpbColors / KpbTypography / KpbSpacing / KpbRadius
                         │
                         ▼
                 AppTheme.buildTheme()
                         │
          ┌──────────────┼───────────────┐
          ▼              ▼               ▼
   Material widgets  KPB primitives  context.kpb
          │              │               │
          └──────────────┴───────────────┘
                         │
                         ▼
       Auth + Shell + écrans métier + états système
```

Les écrans ne doivent pas décider directement quelle nuance utiliser pour un
bouton primaire, une carte, une bordure ou un texte. Ils demandent un rôle au
thème ou utilisent une primitive KPB.

## 6. Phase 0 — Baseline et protection du worktree

### Actions

- relever la branche, le HEAD et les fichiers modifiés ;
- lancer une baseline Flutter avant modification ;
- capturer les écrans suivants dans leur état actuel :
  - entrée non connectée ;
  - onboarding ;
  - accueil connecté ;
  - liste des bourses ;
  - universités ;
  - dossiers ;
  - profil ;
- utiliser au minimum deux viewports :
  - Android compact `360 × 800` ;
  - iPhone récent ou simulateur équivalent ;
- vérifier avec un texte système à `1.0` puis `1.3` ;
- créer le fichier de progression sans toucher aux sources métier.

### Commandes

```bash
git status --short
flutter pub get
flutter analyze
flutter test --dart-define=KPB_ENABLE_REMOTE_SYNC=false
```

### Gate

- baseline documentée ;
- aucune modification existante perdue ;
- les erreurs préexistantes, si présentes, sont distinguées des nouvelles.

## 7. Phase 1 — Polices et tokens sémantiques

### 7.1 Restaurer les polices sans cherry-pick global

Depuis l'objet Git `0db3c40`, restaurer précisément :

- `assets/fonts/Inter-Regular.ttf` ;
- `assets/fonts/Inter-Medium.ttf` ;
- `assets/fonts/Inter-SemiBold.ttf` ;
- `assets/fonts/Inter-Bold.ttf` ;
- `assets/fonts/Inter-ExtraBold.ttf` ;
- `assets/fonts/PlusJakartaSans-SemiBold.ttf` ;
- `assets/fonts/PlusJakartaSans-Bold.ttf` ;
- `assets/fonts/PlusJakartaSans-ExtraBold.ttf` ;
- `assets/fonts/README.md` avec la licence.

Déclarer les familles `Inter` et `PlusJakartaSans` dans `pubspec.yaml`.

### 7.2 Refaire les tokens autour de rôles

Modifier `lib/app/core/ui/app_tokens.dart` :

- ajouter les noms canoniques :
  - `brandNavy` ;
  - `brandBlueLegacy` ;
  - `actionPrimary` ;
  - `actionPrimaryHover` ou pressed ;
  - `canvas` ;
  - `surface` ;
  - `surfaceMuted` ;
  - `border` ;
  - `borderStrong` ;
  - `textPrimary` ;
  - `textSecondary` ;
  - `textMuted` ;
- conserver temporairement `engagementNavy`, `engagementBlue`, etc. comme
  aliases vers les nouveaux rôles afin de ne pas casser l'écran d'entrée ;
- conserver les couleurs sémantiques succès, warning et erreur ;
- séparer explicitement couleur métier et couleur décorative ;
- ajouter `KpbTypography.bodyFamily = 'Inter'` et
  `KpbTypography.headingFamily = 'PlusJakartaSans'` ;
- faire utiliser `headingFamily` par les styles display/headline/title ;
- faire utiliser Inter par body/label/caption.

### 7.3 Éliminer la duplication dans l'extension

Modifier `lib/app/core/ui/kpb_theme_ext.dart` afin que chaque getter lise les
tokens ou le `ColorScheme`, sans recopier d'hexadécimaux.

Le mode sombre peut rester compilable, mais il n'est pas à concevoir ni à
exposer dans cette livraison.

### Tests à ajouter

Créer `test/core/ui/app_tokens_test.dart` :

- valeurs de la palette cible ;
- aliases de compatibilité ;
- familles de polices ;
- contraste texte principal/surface et action/texte.

### Gate

- polices chargées hors ligne ;
- aucune erreur `Unable to load asset` ;
- tokens accessibles sans changement métier ;
- tests de tokens verts.

## 8. Phase 2 — Rebrancher le thème global

Modifier `lib/app/core/ui/app_theme.dart`.

### `ThemeData` cible

- `fontFamily: 'Inter'` ;
- titres AppBar et grands titres en Plus Jakarta Sans ;
- `ColorScheme.light` ou `fromSeed` configuré explicitement avec :
  - primary `#2563EB` ;
  - surface `#FFFFFF` ;
  - onSurface `#0F172A` ;
  - error `#B91C1C` ;
- scaffold `#F8FAFC` ;
- AppBar transparent sur canvas, navy pour texte/icônes ;
- cards blanches, bordure `#E2E8F0`, radius cohérent et ombre légère ;
- boutons primaires bleus, hauteur minimale 52–56 px ;
- boutons secondaires blancs avec bordure ;
- boutons texte sans fond ;
- champs blancs, label/hint lisibles, focus bleu ;
- chips sélectionnées bleues, non sélectionnées sur surface muted ;
- bottom sheets et dialogs avec radius haut de gamme ;
- SnackBar, tooltip, menu, switch, radio, checkbox et progress harmonisés ;
- navigation claire et compacte, sans palette locale concurrente.

Modifier `lib/main.dart` uniquement si nécessaire pour :

- conserver `theme: AppTheme.buildTheme()` ;
- conserver `ThemeMode.light` pour cette livraison ;
- ne pas réactiver un thème sombre incomplet ;
- ne pas modifier le bootstrap, l'auth ou les routes.

### Tests à ajouter

Créer `test/core/ui/app_theme_test.dart` :

- brightness light ;
- primary, scaffold et surface conformes ;
- Inter global ;
- titre AppBar en Plus Jakarta Sans ;
- FilledButton, OutlinedButton, Card, Input et Chip conformes ;
- taille tactile minimale.

### Gate

Un widget Material standard sans style local doit déjà afficher le nouveau
thème.

## 9. Phase 3 — Solidifier les primitives KPB

Mettre à niveau les composants de `lib/app/core/ui/components/` avant de migrer
les écrans.

### Composants prioritaires

- `kpb_button.dart`
  - remplacer `secondary: bool` par des variantes explicites tout en gardant
    la compatibilité : primary, secondary, tertiary, destructive ;
  - gérer loading, disabled, leading icon et full-width ;
  - prendre les couleurs depuis le thème ;
- `kpb_card.dart`
  - surface, bordure et ombre depuis `context.kpb` ;
  - variantes standard, interactive et highlighted ;
- `section_header.dart`
  - titres Plus Jakarta Sans ;
  - action secondaire cohérente ;
- `kpb_badge.dart`, `kpb_badge_light.dart`, `match_badge.dart` et
  `scholarship_status_badge.dart`
  - variantes sémantiques, jamais une couleur arbitraire ;
- `kpb_empty_state.dart`, `kpb_error_state.dart`, `skeleton_loader.dart`
  - même canvas, hiérarchie et CTA ;
- `kpb_input_decoration.dart`
  - déléguer au thème global ;
- `kpb_offline_banner.dart`, `kpb_sync_error_banner.dart` et
  `kpb_sample_data_banner.dart`
  - conserver la sémantique et harmoniser l'apparence ;
- `country_card.dart`, `field_card.dart`, `program_catalog_card.dart` et
  `scholarship_mini_card.dart`
  - utiliser KpbCard et les tokens sémantiques.

### Nouveaux composants autorisés si nécessaires

- `KpbPageScaffold` : canvas, SafeArea, padding standard et slot bottom nav ;
- `KpbPageHeader` : titre, sous-titre et actions ;
- `KpbStatusChip` : success/warning/error/info/neutral ;
- `KpbSectionCard` : section standard avec titre et contenu.

Ne pas créer une primitive si un composant existant peut être étendu proprement.

### Gate

- tests widget des variantes ;
- tous les états pressed, disabled, loading et focus sont visibles ;
- cibles tactiles d'au moins 48 dp.

## 10. Phase 4 — Entrée, onboarding et shell

Migrer d'abord les surfaces qui encadrent toute l'expérience.

### Fichiers

- `lib/app/features/auth/auth_welcome_screen.dart` ;
- `lib/app/features/auth/magic_link_email_screen.dart` ;
- `lib/app/features/auth/magic_link_verify_screen.dart` ;
- `lib/app/features/auth/app_lock_screen.dart` ;
- `lib/app/features/onboarding/onboarding_screen.dart` ;
- `lib/app/core/navigation/app_boot_screen.dart` ;
- `lib/app/features/shell/app_root_shell.dart` ;
- `lib/app/features/shell/app_shell.dart` ;
- `lib/app/features/shell/commercial_shell.dart` ;
- `lib/app/features/shell/kpb_tools_drawer.dart` ;
- `lib/app/core/services/connectivity_service.dart`.

### Règles

- préserver le design validé de l'entrée ;
- remplacer ses couleurs `engagement*` par les aliases canoniques sans modifier
  le rendu ;
- harmoniser tous les écrans auth avec la même hiérarchie ;
- conserver exactement les actions Google, email et sessions existantes ;
- ne pas réintroduire l'ancien slideshow dans le boot ;
- faire apparaître le nouveau thème dans le shell d'un utilisateur connecté ;
- conserver les cinq onglets et leur ordre actuel ;
- unifier nav, drawer, badge, Coach FAB, offline et sample-data banners ;
- ne pas utiliser blur/glass lourd sur les appareils Android économiques.

### Tests

- utilisateur non connecté → écran KPB Intelligence ;
- utilisateur connecté et profil complet → shell directement ;
- navigation cinq onglets inchangée ;
- drawer et Coach FAB fonctionnels ;
- texte à 1.3 sans overflow.

## 11. Phase 5 — Parcours étudiant principal

Migrer ces écrans dans cet ordre. Chaque lot doit être validé avant le suivant.

### Lot 5A — Acquisition et découverte

| Surface | Fichiers principaux | Résultat visuel attendu |
| --- | --- | --- |
| Accueil | `home/home_screen.dart`, composants Home | hero navy, sections sur canvas, CTA bleu |
| Recherche | `search/search_screen.dart`, `match_explanation_sheet.dart` | filtres/chips et résultats cohérents |
| Universités | `universities/universities_screen.dart`, widgets | cartes, filtres et états unifiés |
| Explorer | `explore/explore_screen.dart` | hiérarchie claire sans couleurs locales concurrentes |
| Pays | `explore/country_detail_screen.dart` | hero, métriques et CTA cohérents |
| Programme | `explore/program_detail_screen.dart` | détails et actions conformes au thème |
| Comparaison | `compare/institution_compare_screen.dart` | tableaux lisibles et accents maîtrisés |
| Enregistrés | `saved/saved_screen.dart` | tabs, cartes et empty state communs |

### Lot 5B — Bourses

| Surface | Fichiers principaux | Résultat visuel attendu |
| --- | --- | --- |
| Liste | `scholarships/live_scholarships_screen.dart` | cartes sur canvas, filtres et alertes unifiés |
| Détail | `scholarships/scholarship_detail_screen.dart` | sections, avantages, critères et CTA cohérents |
| Éligibilité | `scholarships/scholarship_eligibility_screen.dart` | questions et résultats sémantiques |
| Guide | `scholarships/scholarship_guide_info_screen.dart` | conserver le style KPB Intelligence |
| Postuler | `scholarships/widgets/how_to_apply_sheet.dart` | bottom sheet thémée |
| Alertes | `scholarships/widgets/scholarship_alert_button.dart` | états off/on/loading accessibles |

Le lecteur YouTube peut conserver un fond sombre immersif. Son AppBar, sa liste
et son fallback doivent cependant employer les tokens du système.

### Lot 5C — Dossiers et communication

- `cases/cases_screen.dart` ;
- `cases/case_create_screen.dart` ;
- `cases/case_detail_screen.dart` ;
- `cases/case_tunnel_flow.dart` ;
- `cases/case_status_timeline.dart` ;
- `cases/document_review_screen.dart` ;
- `cases/post_decision_screen.dart` ;
- `notifications/notifications_screen.dart` ;
- `profile/profile_screen.dart`.

Préserver les statuts métier. Le thème peut modifier leur rendu, jamais leur
signification.

### Gate de chaque lot

- aucun overflow à 360 px ;
- aucun texte important sous 4,5:1 de contraste ;
- empty/loading/error/offline vérifiés ;
- navigation et CTA fonctionnels ;
- tests ciblés verts.

## 12. Phase 6 — Simulateurs, outils et contenu

### Lot 6A — Décision et budget

- `budget/budget_calculator_screen.dart` ;
- `housing/housing_estimator_screen.dart` ;
- `travel/flight_estimator_screen.dart` ;
- `eligibility/eligibility_simulator_screen.dart` ;
- `deadlines/deadline_calendar_screen.dart` ;
- `orientation/orientation_screen.dart` ;
- `orientation/orientation_roadmap_screen.dart` ;
- `matches/aha_moment_screen.dart` ;
- `france/france_private_admission_screen.dart`.

Supprimer les `Theme.of(...).brightness` locaux inutiles pour la livraison
light-only lorsque cela simplifie le code sans casser une surface immersive.

### Lot 6B — Contenu et engagement

- `community/community_screen.dart` ;
- `community/forum_category_screen.dart` ;
- `parcours/parcours_screen.dart` ;
- `parcours/parcours_story_screen.dart` ;
- `academy/academy_course_screen.dart` ;
- `academy/academy_player_screen.dart` ;
- `premium/premium_screen.dart` ;
- `referral/referral_screen.dart` ;
- `salon/salon_screen.dart` ;
- `services/service_packages_screen.dart` ;
- `ai_advisor/ai_chat_screen.dart` ;
- `ai_advisor/coach_fab.dart`.

### Lot 6C — Outils étudiant

- `tools/student_tools_screen.dart` ;
- `tools/cv_generator_screen.dart` ;
- `tools/motivation_letters_screen.dart` ;
- `tools/interview_simulator_screen.dart` ;
- `tools/document_scanner_screen.dart` ;
- `tools/impact_dashboard_screen.dart`.

## 13. Phase 7 — Rôles parent et commercial

### Parent

- `parent/parent_surface_screen.dart` ;
- `parent/parent_dashboard_screen.dart` ;
- `parent/parent_case_view_screen.dart`.

### Commercial

- `commercial/commercial_surface_screen.dart` ;
- `shell/commercial_shell.dart`.

Ces rôles utilisent le même thème et les mêmes primitives. Une couleur locale
est autorisée uniquement pour une donnée ou un statut métier documenté.

## 14. Exceptions visuelles autorisées

Ces surfaces peuvent rester sombres ou spécifiques :

- lecteur vidéo plein écran ;
- viewer PDF/document ;
- overlays caméra/scanner ;
- contenu externe WebView ;
- illustrations et images de marque ;
- graphiques dont les séries ont besoin de couleurs distinctes.

Même dans ces cas : AppBar, CTA, erreurs, loading et accessibilité doivent rester
cohérents avec le système KPB.

Créer une allowlist commentée pour les couleurs locales restantes. Toute couleur
hors allowlist est une dette à corriger.

## 15. Règles de migration écran par écran

Pour chaque écran :

1. Lister les couleurs et styles locaux.
2. Identifier leur rôle : primary, surface, texte, border, semantic ou décoratif.
3. Remplacer les rôles communs par ThemeData/context.kpb/primitives.
4. Conserver uniquement les couleurs métier réellement nécessaires.
5. Remplacer les boutons/inputs/cards custom par les primitives communes.
6. Vérifier loading, empty, error, disabled et offline.
7. Vérifier 360 px, grand téléphone et text scale 1.3.
8. Vérifier les interactions avant de passer au fichier suivant.

Interdictions :

- remplacer aveuglément tous les hex par `actionPrimary` ;
- transformer une couleur de statut en couleur décorative ;
- modifier une action ou masquer une fonctionnalité pour simplifier le layout ;
- introduire une bibliothèque UI externe ;
- utiliser des gradients sur chaque carte ;
- multiplier les ombres lourdes, blur ou animations coûteuses.

## 16. Tests et QA visuelle

### Tests unitaires/widget minimums

- `test/core/ui/app_tokens_test.dart` ;
- `test/core/ui/app_theme_test.dart` ;
- tests des variantes KpbButton/KpbCard/KpbStatusChip ;
- auth welcome ;
- onboarding ;
- shell navigation ;
- Home ;
- bourses liste/détail ;
- universités ;
- dossiers ;
- profil ;
- notifications.

### Goldens ou captures de référence

Ajouter des références stables pour :

- entrée non connectée ;
- onboarding ;
- Home connecté ;
- liste et détail bourse ;
- universités ;
- dossiers ;
- profil ;
- état vide ;
- état erreur/offline.

Chaque référence doit être validée en français et au moins les surfaces
critiques en anglais.

### Accessibilité

- contraste WCAG AA pour texte normal ;
- cible tactile 48 dp ;
- labels Semantics sur actions icon-only ;
- focus visible ;
- ne jamais porter une information uniquement par la couleur ;
- text scale 1.3 sans contenu inaccessible ;
- tailles minimales lisibles sur Android économique.

## 17. Commandes de validation finale

Depuis la racine du dépôt :

```bash
dart format --set-exit-if-changed lib test
flutter analyze
flutter test --dart-define=KPB_ENABLE_REMOTE_SYNC=false
flutter build apk --debug \
  --dart-define=KPB_APP_ENV=prod \
  --dart-define=KPB_WHATSAPP_NUMBER=+33768674292
```

Puis, uniquement après validation :

```bash
flutter clean
flutter pub get
flutter build apk --release --split-per-abi \
  --dart-define=KPB_APP_ENV=prod
```

Noter le chemin et l'heure exacte du nouvel artefact. Ne pas installer un APK
antérieur resté dans `build/app/outputs/`.

### Vérification appareil

1. Désinstaller l'ancienne application ou effacer ses données.
2. Installer le nouvel APK.
3. Vérifier l'entrée non connectée.
4. Se connecter et vérifier le shell principal.
5. Fermer et rouvrir l'app pour tester la session persistante.
6. Vérifier que le thème reste visible lorsque l'écran d'entrée est sauté.
7. Tester navigation, bourses, universités, dossiers et profil.

## 18. Definition of Done

Le thème est réellement terminé lorsque :

- `AppTheme.buildTheme()` utilise la palette KPB Intelligence ;
- Inter et Plus Jakarta Sans sont embarquées et utilisées hors ligne ;
- un utilisateur connecté voit immédiatement le nouveau thème ;
- les cinq onglets principaux et leurs écrans ont été migrés ;
- tous les autres écrans actifs sont migrés ou inscrits dans une allowlist
  justifiée ;
- aucun écran principal n'emploie un ancien bleu comme action primaire ;
- les composants KPB tirent leurs couleurs du thème ;
- toutes les couleurs hex locales restantes sont auditées ;
- les parcours auth, onboarding, guest, étudiant, parent et commercial restent
  fonctionnels ;
- les états loading/empty/error/offline sont cohérents ;
- les tests, analyze et build Android sont verts ;
- le nouvel APK a une date postérieure à l'implémentation ;
- les captures avant/après sont jointes au rapport de progression ;
- aucune modification backend/admin ou métier non autorisée n'a été faite.

## 19. Ordre recommandé des livraisons Fable

```text
PR/lot 1 : fonts + tokens + ThemeData + tests de thème
PR/lot 2 : primitives KPB
PR/lot 3 : auth + onboarding + shell
PR/lot 4 : Home + recherche + universités/explore
PR/lot 5 : bourses
PR/lot 6 : dossiers + notifications + profil
PR/lot 7 : simulateurs + outils + contenu
PR/lot 8 : parent + commercial + exceptions
PR/lot 9 : QA, goldens, accessibilité et build final
```

Ne pas fusionner un lot si ses tests ciblés et ses captures ne sont pas validés.

## 20. Prompt initial à donner à Fable

```text
Implémente le plan docs/fable-global-theme-implementation-plan.md phase par
phase dans le dépôt courant.

Commence uniquement par les phases 0, 1 et 2. Le worktree contient déjà des
modifications utilisateur : préserve-les et ne fais aucun reset, checkout,
commit ou push.

La source visuelle est le thème KPB Intelligence documenté dans design-qa.md :
navy #0F172A, action #2563EB, canvas #F8FAFC, surface blanche, border #E2E8F0,
Inter pour l'interface et Plus Jakarta Sans pour les titres.

Le commit 0db3c40 contient les assets de police de référence, mais ne le
cherry-pick pas en bloc. Restaure uniquement les fichiers et déclarations utiles.

Ne modifie ni backend/, ni admin/, ni les routes, ni les contrats API, ni la
logique métier. Maintiens un rapport dans
docs/fable-global-theme-implementation-progress.md.

À la fin de chaque phase, exécute le format, flutter analyze et les tests
ciblés. Arrête-toi après la phase 2 avec le diff, les tests et les captures pour
validation avant de migrer les écrans.
```

