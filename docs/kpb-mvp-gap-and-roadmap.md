# 🎯 KPB Education — Audit MVP & Roadmap de livraison

> Note 2026-07-07: ce document est un ancien audit et certaines observations
> sont maintenant périmées par les travaux récents et par le nouveau starter kit
> Karatou. Utiliser `docs/phase0-new-plan-alignment.md` comme source de vérité
> Phase 0 avant d'exécuter une tâche issue de cette roadmap.

**Date** : 23 mai 2026
**Référence spec** : `docs/App goal/00_CAHIER_DES_CHARGES_MASTER.md` + 6 annexes
**État actuel** : ~30 % du MVP livré (audit code complet)
**Objectif** : livrer un MVP testable bout-en-bout conforme à la spec, en **4 phases** sur ~3 semaines.

---

## 1. Synthèse de l'audit (statut actuel)

| Module | Statut | % livré | Bloqueur n°1 |
|--------|--------|---------|--------------|
| M1 Auth OTP | ❌ | 10 % | Pas d'OTP ; boot bypasse l'auth |
| M2 Onboarding 6 étapes | 🟠 | 25 % | 3 pages au lieu de 6 ; pas de série bac, pas de slider budget |
| M3 Profil | 🟡 | 40 % | Champs `Prénom/Nom` non séparés, pas de série bac, pas de photo |
| M4 Orientation IA | 🟡 | 35 % | Pas d'appel IA réel — scoring local statique |
| M5 Destinations | 🟡 | 30 % | 17 pays mock, **0 quiz éligibilité** |
| M6 Recherche universités | 🟡 | 25 % | 100 programmes au lieu de 809 ; pas de filtres |
| M7 France privé | ❌ | 5 % | Module dédié inexistant |
| M8 Demandes | 🟡 | 35 % | Tunnel 1 étape (bottom sheet) au lieu de 5 |
| M9 Commerciaux | 🟠 | 15 % | App mobile commerciale absente |
| M10 Coach IA | 🟠 | 25 % | Mock if/else, pas de Claude/GPT, pas de FAB global |
| M11 Simulateur budget | 🟠 | 20 % | Outil "coût de la vie", pas simulateur d'éligibilité spec |
| M12 Bourses | 🟠 | 15 % | McCall MacBain absent ; agrégateur scrapé hors-spec |
| M13 Notifs + Admin | 🟡 | 40 % | Segmentation campagnes incomplète |
| M14 Mes demandes | 🟡 | 45 % | Pas de temps réel ni badge non-lu |

### Écarts transverses critiques

1. **Boot bypasse l'auth** — `main.dart:175-179` envoie sur intro → onboarding sans login.
2. **Design KPB Orange `#E8593C` jamais implémenté** — palette bleue `#1E4C93` partout.
3. **i18n EN active** alors que la spec dit "100 % français au MVP".
4. **Scope creep V1.1/V2** déjà codé : forum, alumni, academy, salon, housing, travel — détourne l'effort du MVP.
5. **Auth JWT backend** existe mais l'app n'envoie aucun token → sync remote silencieusement en échec.
6. **OMNES xlsx** non importé — script template présent, fichier source absent.
7. **France = Campus France promu** dans `mock_catalog.dart:795-803` (contraire à la spec §5.5).

---

## 2. Stratégie d'attaque

**Principe** : à chaque fin de phase, l'app doit être **testable bout-en-bout** sur le périmètre couvert. Pas de feature en "presque fini".

**Ordre choisi** : Hygiène → Auth/Onboarding → Cœur métier → Intelligence/Commerciaux → QA. C'est l'ordre où chaque phase débloque la suivante.

| Phase | Durée | Livrable testable |
|-------|-------|-------------------|
| **0 — Hygiène & déblocage** | 1-2 jours | App propre, navigation spec, design orange, modules hors-MVP cachés |
| **1 — Auth & Onboarding spec** | 4-5 jours | Inscription téléphone+OTP, onboarding 6 étapes, profil aligné |
| **2 — Cœur métier (M5/M6/M7/M8/M14)** | 5-7 jours | 9 fiches pays + quiz, recherche 809 programmes, tunnel demande, timeline temps réel |
| **3 — Intelligence & commerciaux (M4/M9/M10/M11/M12/M13)** | 5-7 jours | Orientation+coach IA réels, app commerciale 3 onglets, simulateur budget conforme, McCall MacBain, admin segmenté |
| **4 — QA & launch** | 2-3 jours | Smoke tests bout-en-bout, perf 3G, monitoring, build store |

**Total réaliste** : **17 à 24 jours-homme** pour un dev senior. Avec deux développeurs en parallèle (mobile + backend) : ~2,5 semaines calendaires.

---

## 3. Phase 0 — Hygiène & déblocage (1-2 jours)

**Objectif** : remettre le rail sur la voie du cahier des charges.

### Mobile

- [ ] **Switch palette → KPB Orange** : `KpbColors.primary = orange` (`#E8593C`), `primaryLight = #FFE8E2`. Mettre à jour `app_theme.dart` (seed orange) et auditer chaque écran qui hard-code `KpbColors.blue`.
- [ ] **Navigation 5 onglets étudiant** : refactor `AppShell` → `[HomeScreen, DestinationsScreen, UniversitiesScreen, CasesScreen, ProfileScreen]`.
  - Extraire l'onglet pays de `ExploreScreen` → `DestinationsScreen` autonome.
  - Extraire programmes/écoles → `UniversitiesScreen` avec filtres.
- [ ] **Shell commercial 3 onglets** : `if (controller.isCommercial) → CommercialShell([LeadsInbox, ConversationsScreen, ProfileScreen])`. Squelette vide acceptable en P0.
- [ ] **i18n FR-only** : retirer `Locale('en')` de `supportedLocales` ; supprimer la moitié EN de `app_translations.dart` (ou la garder mais désactiver le toggle profil).
- [ ] **Cacher modules hors-MVP** : feature flag `KPB_MVP_ONLY=true` qui masque (sans supprimer le code) : forum, alumni, academy, salon, housing, travel, live scholarships scrapés.
- [ ] **France = privé uniquement** : éditer la fiche France du mock pour parler des écoles privées et masquer les références Campus France ; ajouter un badge "Campus France — Bientôt disponible (Sept 2026)".

### Backend

- [ ] **Nettoyer la DB** : supprimer les pays legacy en double (`france`, `canada`, `uk`) → garder uniquement les ID 3 lettres ISO ; vérifier les FK (programmes/scholarships).
- [ ] **Vérifier les guards** : tous les endpoints sensibles (`/cases`, `/profiles/me`, `/saved-items`, `/device-tokens`) protégés par `@UseGuards(StudentAuthGuard)`.

### Critère de fin de phase 0

- App lance, montre **5 onglets orange en français**.
- Forum/alumni/etc. invisibles côté étudiant.
- Pas de référence à Campus France dans la fiche France.
- DB pays propre (9 lignes uniques).

---

## 4. Phase 1 — Auth & Onboarding spec (4-5 jours)

**Objectif** : un nouvel utilisateur peut s'inscrire en téléphone+OTP, traverser les 6 étapes de l'onboarding et arriver authentifié sur l'accueil.

### Backend

- [ ] **Schéma `OtpCode`** Prisma : `phoneE164`, `code`, `expiresAt`, `attempts`, `consumedAt`.
- [ ] **Endpoint** `POST /auth/otp/request` (3 req/min/IP, 1/min/téléphone) → Twilio Verify ou stub local en dev.
- [ ] **Endpoint** `POST /auth/otp/verify` → JWT (access 1h + refresh 30j) + création/réutilisation user.
- [ ] **Endpoint** `POST /auth/email/magic-link` (fallback) → Resend.
- [ ] **Endpoint** `POST /auth/refresh` (rotation refresh token).
- [ ] Tests unitaires : 3 essais max → blocage 15 min ; OTP TTL 5 min ; renvoi possible après 30 s.

### Mobile

- [ ] **Splash + bienvenue 3 slides** (Pourquoi KPB / Quoi de mieux ici / Lancement) avant intro existante.
- [ ] **Écran "Choix méthode"** : Téléphone OTP (principal) | Email magique (fallback affiché après 90 s d'attente).
- [ ] **Saisie téléphone** : préfixe pays auto-détecté + sélecteur 9 pays africains francophones + Niger pré-sélectionné.
- [ ] **Saisie OTP 6 chiffres** : auto-paste depuis SMS (iOS), 3 essais, renvoi après 30 s, blocage 15 min.
- [ ] **Stockage** : access token + refresh token via `kpbFlutterSecureStorage` (déjà installé).
- [ ] **Auth interceptor Dio** : refresh 401 + retry, deconnexion si refresh échoue.
- [ ] **Onboarding 6 étapes** :
  1. Tu es ? (Étudiant · Parent · Partenaire · Commercial)
  2. Niveau d'études (si étudiant) — Terminale / L1-B1 / L2-B2 / L3-B3 / M1 / M2 / Doctorat
  3. Série de bac (si Terminale ou L1) — A, A1, A4, A8, B, C, D, E, F, F1-F4, G, G1, G2, PRO, Tech, Autre
  4. Pays d'intérêt (multi-select, optionnel) — les 9 pays
  5. Budget mensuel (slider 200-2000 EUR, optionnel)
  6. Notifications push (autorisation OS)
- [ ] **Persistance progressive** : sauvegarder à chaque étape (pas tout à la fin), reprise au redémarrage.
- [ ] **Skip top-right** dès l'étape 2 ; étape 1 obligatoire.
- [ ] **Suppression `_skipOnboarding` qui crée un faux profil "Test User"** (`onboarding_screen.dart:226-251`) — non conforme spec.

### Profil (M3) — alignement champs

- [ ] Séparer `firstName` / `lastName` dans `UserProfile`.
- [ ] Ajouter : `bacSeries`, `monthlyBudget`, `birthDate`, `currentCity`, `originCountry`, `profilePhotoUrl`.
- [ ] Écran "Moi → Profil" éditable.
- [ ] Module "Mes documents" : upload CV, passeport, relevés (compression auto, max 10 MB).

### Critère de fin de phase 1

- Un nouvel utilisateur peut **créer un compte en < 60 s** via téléphone+OTP.
- L'onboarding 6 étapes fonctionne, skip OK sauf étape 1.
- Les screens authentifiés (cases, saved, profile) reçoivent le JWT et la sync remote remonte les données réelles.
- L'écran profil affiche tous les champs spec.

---

## 5. Phase 2 — Cœur métier (5-7 jours)

**Objectif** : un étudiant authentifié peut explorer un pays, faire le quiz d'éligibilité, trouver un programme et soumettre une demande complète qui apparaît dans la timeline.

### Données

- [ ] **Seed 9 pays officiels** (annexe 04) avec :
  - Hero (drapeau, image), tagline
  - Sections "Pourquoi", "Comment ça se passe", "Coûts", "Langue requise", "Écoles partenaires", "Bourses"
  - Quiz éligibilité **5-7 questions par pays** + scoring
- [ ] **Import OMNES 748 programmes** : exécuter `import-omnes.ts` avec le vrai xlsx que l'utilisateur fournira.
- [ ] **Import 61 partenaires** (annexe 05) : ICN, Schiller, ISMAGI, ESA Casa, BAU Istanbul, GBS Dubai, IGENSIA.

### M5 — Destinations

- [ ] `DestinationsScreen` = grille 9 pays avec drapeau + badge rentrée.
- [ ] `CountryDetailScreen` complet :
  - 7 sections de la spec §5.5
  - **Bouton "Faire le quiz d'éligibilité" en haut** (gros CTA orange)
  - **Bouton WhatsApp en bas** (pré-rempli selon pays)
  - CTA "Demander un accompagnement"
- [ ] **Quiz éligibilité** : nouvel écran `EligibilityQuizScreen(countryId)` :
  - 5-7 questions (annexe 04)
  - Verdict 3 niveaux : ✅ Éligible (vert) / 🟡 Sous conditions (jaune) / ❌ Pas éligible (rouge)
  - CTA contextuel selon verdict (demande / discuter / alternatives)

### M6 — Recherche universités

- [ ] `UniversitiesScreen` autonome avec :
  - Barre de recherche
  - Filtres : Pays · Budget annuel (slider 0-30k €) · Niveau · Domaine · Langue · Toggle "Partenaires KPB uniquement"
  - 2 onglets : "Partenaires KPB ⭐" (par défaut) / "Toutes les écoles"
  - Tri par défaut : Partenaires d'abord, puis budget croissant
- [ ] **Carte programme** : logo, nom, niveau+durée, frais EUR + FCFA (taux statique config), langue, badge partenaire, CTA "Voir détails".
- [ ] `ProgramDetailScreen` avec sections : Le programme, Frais, Conditions admission, Processus candidature, CTA "M'inscrire avec KPB".

### M7 — Admission France privé

- [ ] Module dédié accessible depuis fiche France et home :
  - Page intro "France privé vs public"
  - Stepper 6 étapes (Choix école → Dossier → Admission → Visa → Logement → Arrivée)
  - Liste partenaires France privé (OMNES, IGENSIA, ICN, Schiller)
  - Section Campus France grisée + "Notifie-moi quand ça ouvre" (créer entrée `notify_signups`)

### M8 — Demandes (tunnel 5 étapes)

- [ ] Refactor `case_composer_sheet` → `CaseComposerScreen` plein écran avec PageView 5 étapes :
  1. Type de demande (radio : Inscription école · Bourse · Visa · Logement · Autre)
  2. Contexte pré-rempli (pays/école/programme selon point d'entrée)
  3. Mes documents (upload optionnel à cette étape)
  4. Message libre + voice-to-text (`speech_to_text` package)
  5. Confirmation + récap
- [ ] Tous les CTA "Demander un accompagnement" / "M'inscrire avec KPB" / verdict quiz positif → préremplissent l'étape 2.

### M14 — Mes demandes (timeline)

- [ ] Timeline visuelle (10 statuts spec) : étapes ✅ passées + 🔄 en cours + ⏸ à venir.
- [ ] Badge rouge sur l'onglet "Demandes" + bottom nav si messages non lus.
- [ ] **Temps réel** : brancher `CaseSocketService` (WebSocket) au lieu de polling. Statut + messages mis à jour live.
- [ ] Compression auto des images uploadées (`flutter_image_compress`).

### Critère de fin de phase 2

- Tester le scénario : **inscription → onboarding → quiz France → verdict éligible → demande pré-remplie ECE Lyon → soumission → la demande apparaît dans "Mes demandes" avec timeline et statut "Soumise"**. Tout en moins de 5 minutes.

---

## 6. Phase 3 — Intelligence & commerciaux (5-7 jours)

**Objectif** : l'IA orientation/coach répond pour de vrai, les 3 commerciaux KPB peuvent travailler sur l'app mobile, l'admin pilote les campagnes.

### M4 — Orientation IA réelle

- [ ] Backend endpoint `POST /orientation/sessions` qui appelle **Anthropic Claude 3.5 Haiku** (ou GPT-4o-mini).
- [ ] System prompt = template du cahier §5.4.
- [ ] Réponse JSON strict : 3-5 filières + explication "pourquoi ce profil" + métiers + résilience IA + pays partenaires KPB.
- [ ] Questionnaire 10-12 questions (mocks actuels = 5 — étendre avec annexe).
- [ ] Stockage `user_orientation_results` avec session_id réutilisable.
- [ ] Lien filière recommandée → liste écoles dans M6 (filtre auto).

### M9 — Système commerciaux

- [ ] **Schéma DB** : `lead_tag` enum (qualified, not_qualified, awaiting_payment, converted, lost, to_follow_up), `discussion_motive` (string 100), `RoundRobinState` table (pour traçabilité).
- [ ] Endpoints commerciaux : `GET /commercial/leads`, `PATCH /cases/:id/tag`, `PATCH /cases/:id/motive`.
- [ ] **App mobile commerciale 3 onglets** :
  - **Onglet 1 — Mes Leads** : filtres (Tous / Nouveaux / Aujourd'hui / ⭐ Qualifiés). Carte = avatar + nom + âge + niveau + motif + statut + ancienneté.
  - **Onglet 2 — Conversations** : liste chats actifs, badge non-lu.
  - **Onglet 3 — Moi** : profil commercial + stats (temps moyen 1ère réponse, leads convertis 30j).
- [ ] **Chat in-app temps réel** : `CaseSocketService` côté client + `case-messaging.gateway.ts` côté serveur (déjà existant). Statuts envoyé/lu/répondu.
- [ ] **Réattribution 10 h** : déjà codée (`case-reassignment-cron.service.ts`) — tester avec scénario réel + notif aux 3 acteurs (ancien commercial, nouveau, admin).

### M10 — Coach IA conversationnel

- [ ] **FAB orange global** sur tous les écrans (sauf chat actif) — overlay au-dessus de la bottom nav.
- [ ] Backend `POST /coach/messages` avec streaming SSE (`text/event-stream`).
- [ ] System prompt + injection contexte utilisateur (prénom, niveau, pays intérêt, budget, demandes en cours).
- [ ] Quota 5 msg/sem reset lundi 00 h UTC (côté backend, pas local seulement).
- [ ] **Streaming Flutter** : afficher les tokens en live via `EventSource`.
- [ ] Bandeau "Premium bientôt dispo" quand quota atteint.
- [ ] Historique 90 jours en DB.

### M11 — Simulateur de budget conforme

- [ ] Refactor `BudgetCalculatorScreen` → `BudgetSimulatorScreen` :
  - 5 inputs : budget total annuel (slider 1k-30k €), durée études (1/2/3/5 ans), niveau visé (Bachelor/Master/Doctorat), tolérance prêt étudiant (oui/non/partiel), travail étudiant possible (oui/non/pas sûr).
  - Output : **9 cartes pays** avec verdict 🟢 Accessible / 🟡 Tendu mais possible / 🔴 Inaccessible.
  - Détail par pays : frais scolarité min/avg, coût vie mensuel, total année 1, total cursus, bourses pertinentes.
- [ ] Conversion FCFA auto (+ EUR) selon pays utilisateur.
- [ ] Sauvegarde dans le profil.
- [ ] Génération PDF "Mon plan de budget" (`pdf` + `printing` packages).

### M12 — Bourses + McCall MacBain

- [ ] Seed McCall MacBain Scholarship complet (McGill, Montréal, master tous domaines) avec :
  - Description longue
  - Critères d'éligibilité (texte + quiz dédié)
  - Test d'éligibilité spécifique (questions sur leadership, engagement, excellence)
  - CTA "Demander un accompagnement McCall MacBain"
- [ ] Onglet "Bourses" dans **Moi** (pas en accueil — focus business).
- [ ] Backend : table `Scholarship` avec status (Draft/Active/Expired), admin peut publier en 2 minutes.
- [ ] Notif push automatique aux profils éligibles (cron + matching profil ↔ critères).
- [ ] **Désactiver** `LiveScholarshipsScreen` (scraping) — non conforme spec.

### M13 — Admin web

- [ ] Compléter le 8 modules admin (déjà partiellement présents dans `admin/`) :
  1. Dashboard KPIs temps réel (websocket 30 s)
  2. Utilisateurs (filtres + fiche détaillée)
  3. Demandes (suivi + réassignation manuelle)
  4. Commerciaux (perf Jojo/Donald/Richard : temps réponse, taux conversion, étiquettes)
  5. Contenus (blog, vidéos, bourses)
  6. Notifications (composer + planifier + segmentation : tous, persona, niveau, pays intérêt, orientation)
  7. Établissements (gestion partenaires)
  8. Paramètres système
- [ ] Logs d'envoi/ouverture/clic des notifs.

### Critère de fin de phase 3

- Demander au coach IA "Quel pays pour 800 € de budget ?" → réponse cohérente en streaming.
- Faire l'orientation IA → 3-5 filières avec explications personnalisées.
- Soumettre une demande → un commercial la voit en push + dans son onglet Mes Leads + peut répondre via chat → push reçu côté étudiant.
- Admin envoie une campagne ciblée "Étudiants intéressés par Canada" → seuls eux reçoivent la notif.

---

## 7. Phase 4 — QA & launch (2-3 jours)

### Tests bout-en-bout

- [ ] **Scénario 1 — Inscription complète** : 5 personnes (3 étudiants, 2 parents) testent. Cible : taux complétion onboarding > 70 %.
- [ ] **Scénario 2 — Demande → conversion** : 30 demandes test → vérifier round-robin équitable (10 chacun à Jojo/Donald/Richard).
- [ ] **Scénario 3 — Réattribution 10 h** : créer une demande, ne rien faire 10 h → vérifier transfert auto + 3 notifs.
- [ ] **Scénario 4 — Coach IA QA** : 20 questions test → réponses cohérentes + redirection humain si besoin.
- [ ] **Scénario 5 — 3G dégradée** : tester sur Android entrée de gamme + simulateur réseau lent. Cible : Time-to-interactive < 3 s.

### Performance

- [ ] API p95 < 200 ms sur les 95 % des endpoints (mesurer avec Datadog ou logs nestjs-pino).
- [ ] Bundle Flutter < 30 MB (release build).
- [ ] Cache Hive : fiches pays consultées + favoris + demandes accessibles offline.

### Monitoring

- [ ] Sentry / Crashlytics pour erreurs.
- [ ] PostHog ou GA4 pour funnel onboarding + conversion demande.
- [ ] Dashboard admin avec heatmap usage + heures de pointe.

### Build & store

- [ ] Build Android signé + upload play store interne.
- [ ] Build iOS + TestFlight.
- [ ] Vérifier permissions (camera, photos, notifications, microphone pour voice-to-text).
- [ ] Mentions légales + politique confidentialité accessibles depuis "Moi".

---

## 8. Plan de bataille recommandé

### Si tu travailles seul

Suis l'ordre des phases. À chaque fin de phase, fais un commit/PR + un test bout-en-bout sur simulateur. Ne saute jamais sur la phase suivante tant que le critère de fin de phase actuelle n'est pas validé.

### Si tu peux paralléliser (idéal : 1 mobile + 1 backend)

| Jour | Mobile | Backend |
|------|--------|---------|
| 1 | Phase 0 (palette, nav, FR-only) | Phase 0 (cleanup DB) |
| 2-5 | Phase 1 (auth UI, onboarding 6) | Phase 1 (OTP, magic link) |
| 6-10 | Phase 2 (M5/M6/M7/M8/M14 UI) | Phase 2 (seed 9 pays + quiz, OMNES import) |
| 11-15 | Phase 3 (Coach UI streaming, app commerciale) | Phase 3 (Claude API, segmentation campagnes) |
| 16-18 | Phase 4 (QA mobile) | Phase 4 (perf, monitoring, déploiement) |

---

## 9. Ce qu'il NE faut PAS faire en MVP

- ❌ Ajouter du forum, alumni, academy, salon, housing, travel — c'est V1.1+ ou V2.
- ❌ Garder l'agrégateur de bourses scrapées (`LiveScholarshipsScreen`).
- ❌ Mettre en avant Campus France (privé uniquement).
- ❌ Garder le bouton "Skip" sur l'étape 1 de l'onboarding.
- ❌ Faire un back-office admin "expert" — l'admin doit pouvoir tout faire en 3 clics max.
- ❌ Coder la version anglaise — projet séparé V2.

---

## 10. Décisions à prendre maintenant

Pour démarrer la phase 0, j'ai besoin que tu confirmes :

1. **Couleur primaire orange** : `#E8593C` (spec) ou autre ?
2. **Stack OTP SMS** : Twilio Verify (recommandé spec) ou alternative (Africastalking, Vonage…) ?
3. **Modèle IA** : Claude 3.5 Haiku, Sonnet, ou GPT-4o-mini ? (Coût et latence variables)
4. **Fichier OMNES xlsx** : tu peux le poser dans `backend/scripts/data/omnes_fall_26.xlsx` ?
5. **Modules à supprimer ou cacher** : on les supprime du repo (clean) ou on les garde derrière un feature flag (réutilisables V1.1+) ?

Une fois ces 5 décisions prises, on commence la phase 0.
