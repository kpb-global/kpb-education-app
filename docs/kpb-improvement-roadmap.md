# 🚀 KPB Education — Roadmap d'amélioration "Best App"

**Date** : 30 mai 2026
**Auteur** : audit de code complet (Flutter mobile + NestJS backend + Next.js admin)
**Objectif** : transformer le MVP fonctionnel en **la meilleure app possible** — qualité de données, expérience utilisateur, autonomie de l'équipe (back-office), et contenu vivant.

Ce document part de l'état réel du code (références `fichier:ligne`) et priorise par **impact × effort**.

---

## 0. Synthèse exécutive — les 3 demandes prioritaires

| # | Demande | Constat code | Priorité |
|---|---------|--------------|----------|
| **A** | Uniformiser les niveaux d'études (« B1 » → « Bachelor 1 ») | 2 vocabulaires divergents : onboarding (`L1 / Bachelor 1`…) vs OMNES (`Bachelor · Bac+3`, `MSc · Bac+5`…). Aucune normalisation. | **P0** |
| **B** | Modifier/ajouter formations, universités, bourses via la web app | Admin Next.js existe (`admin/`) mais **catalogue 100 % lecture seule**. Aucun endpoint CREATE/UPDATE/DELETE pour Program/Institution/Scholarship. | **P0** |
| **C** | Vidéos « parcours » depuis la playlist YouTube | 5 vidéos Academy codées en dur dans `mock_catalog.dart`, toutes en placeholder (rickroll). `youtube_player_flutter` déjà installé. | **P1** |

> Au-delà de ces 3 points, ce document liste **tous** les chantiers qualité/UX/perf identifiés pour atteindre le niveau « best app ».

---

## 1. CHANTIER A — Uniformisation des niveaux d'études (P0)

### Problème
Deux référentiels incompatibles cohabitent :

- **Onboarding / profil** (`lib/app/features/onboarding/onboarding_m2_constants.dart:3-11`) :
  `Terminale · L1 / Bachelor 1 · L2 / Bachelor 2 · L3 / Bachelor 3 · M1 · M2 · Doctorat`
- **Formations OMNES** (généré par `backend/scripts/seed-omnes-programs.ts:88-92`) :
  `Bachelor · Bac+3` / `MSc · Bac+5` / `BBA · Bac+4` / `Grande Ecole · Bac+5` / `PGE · Bac+5` / `Visa (Bac +5) · Bac+5` …

Résultat : l'utilisateur voit des libellés bruts incohérents, et il n'existe **aucun lien** entre le niveau qu'il déclare et les formations affichées. Le filtre (`lib/app/core/services/program_filter_service.dart:159-186`) ne tient que par du *substring matching* fragile.

### Solution cible
Créer **un référentiel unique et canonique** de niveaux + un helper de formatage, appliqué partout (onboarding, profil, simulateur d'éligibilité, catalogue, filtres, import).

**Référentiel proposé** (clé stable → libellé FR affiché) :
| Clé canonique | Libellé FR | Équivalents bruts à mapper |
|---|---|---|
| `terminale` | Terminale | Terminale, Bac |
| `bachelor_1` | Bachelor 1 | L1, B1, Bac+1 |
| `bachelor_2` | Bachelor 2 | L2, B2, Bac+2 |
| `bachelor_3` | Bachelor 3 | L3, B3, Bachelor, Bac+3, Licence |
| `bachelor_4` | Bachelor 4 (BBA) | BBA, Bac+4 |
| `master_1` | Master 1 | M1, Bac+4 (Master) |
| `master_2` | Master 2 | M2, MSc, MScCGE, PGE, Grande Ecole, Bac+5, Visa Bac+5 |
| `mba` | MBA / DBA | MBA, DBA |
| `doctorat` | Doctorat | Doctorat, PhD, Bac+8 |

### Tâches
1. **Créer `lib/app/core/utils/study_level.dart`** : enum/clés canoniques + `labelFr(key)` + `normalizeRaw(String) → key` (table de correspondance robuste, insensible à la casse/accents).
2. **Onboarding** : remplacer la liste libre par les clés canoniques (stocker la clé, afficher le libellé). Migrer `currentLevel` (string libre) → clé.
3. **Import OMNES** (`backend/scripts/seed-omnes-programs.ts`, `import-omnes-template.ts`) : normaliser `levelFr/levelEn` vers le libellé canonique **au moment du seed** (la donnée en base devient propre — pas de patch d'affichage).
4. **Affichage** : tous les points listés ci-dessous lisent déjà `program.level` ; une fois la base propre, ils sont corrects automatiquement. Ajouter un fallback `normalizeRaw()` côté Flutter pour la donnée legacy non re-seedée :
   - `lib/app/features/universities/widgets/program_catalog_card.dart:79`
   - `lib/app/features/explore/program_detail_screen.dart:120`
   - `lib/app/features/saved/saved_screen.dart:262`
   - `lib/app/features/explore/explore_screen.dart:443,570`
5. **Filtres** (`program_filter_service.dart:58-186`) : faire matcher sur la **clé canonique** plutôt que substring.
6. **Tests** : `normalizeRaw` (table exhaustive), round-trip onboarding↔filtre.

**Effort** : 1–1,5 j · **Impact** : élevé (qualité perçue + cohérence funnel).

---

## 2. CHANTIER B — Back-office catalogue (CRUD web) (P0)

### Problème
- Web admin Next.js 15 existe : `admin/app/{users,cases,content,notifications,reports,community}/page.tsx`.
- **Aucune page** pour programmes / universités / pays / bourses.
- Backend `catalog.controller.ts` = **GET uniquement**. Données servies depuis Prisma avec fallback `mock-catalog.ts`.
- Bourses (`admin-scholarships.controller.ts`) : seulement `POST /admin/scholarships/refresh` (scraping) — **pas d'édition manuelle**.
- Auth admin déjà prête : `AdminAuthGuard` + `RolesGuard` + `@Roles(Admin, SuperAdmin, ContentManager)`.

### Solution cible
Donner à l'équipe l'autonomie totale sur le catalogue via la web app.

### Tâches — Backend (NestJS)
1. **`POST/PATCH/DELETE /admin/programs`** + DTOs (validation class-validator). Service Prisma `tryExecute`.
2. **`POST/PATCH/DELETE /admin/institutions`** (universités).
3. **`POST/PATCH/DELETE /admin/scholarships`** (édition manuelle en plus du scraping ; champ `source` = `manual` vs `scraped` pour ne pas écraser à chaque refresh).
4. **`POST/PATCH/DELETE /admin/countries`** + **`/admin/fields`** (gestion fine, optionnel V1.1).
5. Tous gardés par `@UseGuards(AdminAuthGuard, RolesGuard) @Roles(Admin, SuperAdmin, ContentManager)`.
6. **Invalidation cache** : si le catalogue mobile est caché (Hive), prévoir un `updatedAt`/version pour forcer le refresh côté app.

### Tâches — Frontend (Next.js `admin/`)
1. Pages `admin/app/programs/page.tsx`, `institutions/page.tsx`, `scholarships/page.tsx` (liste + recherche + pagination).
2. Formulaires create/edit (drawer ou page dédiée) avec les champs bilingues (fr/en), niveau **via le référentiel canonique du Chantier A** (dropdown, pas de texte libre — résout le « B1 » à la source).
3. Suppression avec confirmation + soft-guards (empêcher suppression d'une université qui a des programmes liés).
4. Liaisons : sélecteur université ↔ pays ↔ filière (FK).
5. Upload logo/visuel (réutiliser `StorageService` existant).

### Tâches — Données
- Migration : ajouter `source` (manual/scraped) + `updatedAt` déjà présent sur Scholarship.
- S'assurer que `CatalogService` lit la DB en priorité (déjà le cas) pour que les ajouts admin soient visibles immédiatement.

**Effort** : 3–4 j (backend 1,5 + front 2) · **Impact** : très élevé (autonomie équipe, contenu frais sans dev).

---

## 3. CHANTIER C — Vidéos depuis la playlist YouTube (P1)

### Problème
- 5 leçons Academy codées en dur dans `mock_catalog.dart:8517-8589`, **toutes** en placeholder `dQw4w9WgXcQ`.
- Lecteur déjà fonctionnel : `lib/app/features/academy/academy_player_screen.dart` (`youtube_player_flutter` ^9.1.1).
- Aucune intégration YouTube Data API / playlist.

### Solution cible
Les vidéos proviennent dynamiquement de la playlist
`PLpk-LrNodqDjKAEF8B1WwWuMsmK4s2-zD` (chaîne KPB), sans ré-déploiement à chaque nouvelle vidéo.

### Architecture recommandée
**Proxy backend + YouTube Data API v3** (clé côté serveur, jamais dans l'app) :
1. **Backend** : `GET /content/youtube-playlist?playlistId=…` → appelle `playlistItems.list` (Data API v3) → renvoie `[{videoId, title, thumbnail, duration, publishedAt}]`. Clé `YOUTUBE_API_KEY` en env. Cache 6–24 h (la playlist change rarement) pour rester sous le quota gratuit (10k unités/j).
2. **Flutter** : nouveau `YoutubePlaylistService` qui consomme l'endpoint, cache Hive, et alimente une **section « Parcours / Témoignages »** (nouvel écran ou onglet) + remplace les leçons placeholder de l'Academy.
3. **Lecture** : conserver `youtube_player_flutter` (déjà OK avec un videoId dynamique).

> Alternative sans clé API : `youtube_explode_dart` (scrape) — **déconseillé** (fragile, peut casser sans préavis). Préférer la Data API officielle.

### Tâches
1. Backend endpoint + service + cache + `YOUTUBE_API_KEY` (doc `.env.example`).
2. `YoutubePlaylistService` (Flutter) + modèle `YoutubeVideo` + cache Hive offline.
3. Écran « Parcours KPB » (grille de vidéos : thumbnail, titre, durée) → tap → `academy_player_screen` (ou un player générique).
4. Brancher l'Academy sur la playlist (ou garder Academy pour les cours payants et créer « Parcours » pour les témoignages gratuits — **à clarifier**).
5. Retirer les 5 entrées rickroll de `mock_catalog.dart`.
6. Empty/error states (playlist indisponible → message + retry).

**Effort** : 1,5–2 j · **Impact** : élevé (preuve sociale, contenu vivant, crédibilité).
**Décision à prendre** : « Parcours » = nouvel onglet/section dédiée, OU remplacement direct des vidéos Academy ?

---

## 4. CHANTIER D — Dette UX/UI restante (P1) — ✅ EN GRANDE PARTIE FAIT

Issus de la revue de code de ce sprint :

1. ✅ **Onglet Conversations commercial** : pull-to-refresh + error state distinct + tri non-lus d'abord (`commercial_conversations_screen.dart`).
2. ✅ **Carte lead — chips de tag** : remplacés par un bouton « Changer le statut » → bottom-sheet color-codé (`commercial_leads_screen.dart`).
3. ✅ **Couleurs hardcodées** : `Color(0xFFDC2626)` → `KpbColors.error` (app_shell, cases_screen, eligibility_quiz, conversations). Audit token complet restant à étendre.
4. 🟡 **États vides/erreur uniformes** : généralisés sur le commercial + Parcours ; reste à passer les écrans plus anciens en revue.
5. ⏳ **Accessibilité** : tooltips ajoutés sur boutons icône commercial ; **pass a11y complet (tailles cible, contrastes AA, textScaleFactor) reste à faire**.
6. ✅ **Double-fetch au démarrage** : guard `isLoadingCommercialLeads` dans `fetchCommercialLeads`.

**Reste** : audit design-system exhaustif + pass accessibilité complet.

---

## 5. CHANTIER E — Temps réel & engagement (P2)

1. **WebSocket cases/chat** : `CaseSocketService` côté client + `case-messaging.gateway.ts` (existe backend) — remplacer le polling. Statut + messages live, badge non-lu temps réel (déjà câblé côté nav).
2. **Coach IA FAB global** : présent (`coach_fab.dart`) — vérifier streaming SSE token-par-token + quota serveur (5/sem).
3. **Push transactionnels** : confirmer livraison (case update) + campagnes segmentées (les segments `account_type`/`study_level`/`country` ont été ajoutés ce sprint).

**Effort** : 3–4 j · **Impact** : élevé (rétention).

---

## 6. CHANTIER F — Performance & offline (P2)

1. **Cache Hive complet** : fiches pays + favoris + demandes + **catalogue** consultables hors-ligne (versionné via `updatedAt` du Chantier B).
2. **Bundle < 30 MB** (release) ; lazy-load des gros assets.
3. **3G dégradée** : Time-to-interactive < 3 s sur Android entrée de gamme ; skeletons partout.
4. **Pagination catalogue** : 809 programmes → pagination/scroll infini (l'endpoint accepte `limit/offset`).

**Effort** : 2–3 j · **Impact** : élevé (marché cible = réseaux lents).

---

## 7. CHANTIER G — Qualité, sécurité, observabilité (P1 transverse)

1. **Vulnérabilités npm** : `npm --prefix backend audit` = 33 vulns (3 low / 23 moderate / 7 high) → trier avant prod.
2. **Couverture de tests** : ajouter widget tests pour les écrans neufs (simulateur éligibilité UI, commercial leads/profile, admin catalogue). Backend : tests unitaires CRUD catalogue.
3. **Secrets prod** : revue `KPB_JWT_SECRET`, clés Supabase/Groq/Firebase, `YOUTUBE_API_KEY`.
4. **Monitoring** : Crashlytics + Analytics déjà câblés → instrumenter le funnel (onboarding, soumission demande, conversion CTA) + dashboards.
5. **CI** : pipeline `flutter analyze` + `flutter test` + `npm build` + `prisma validate` sur chaque PR.

**Effort** : 2–3 j · **Impact** : élevé (fiabilité lancement).

---

## 8. Séquencement recommandé

| Sprint | Contenu | Pourquoi cet ordre |
|--------|---------|--------------------|
| **S1** | **Chantier A** (niveaux) + base **Chantier B** backend (endpoints CRUD) | A nettoie la donnée à la source ; le dropdown canonique du back-office (B) en dépend. |
| **S2** | **Chantier B** front (pages admin programmes/universités/bourses) | L'équipe devient autonome sur le contenu. |
| **S3** | **Chantier C** (playlist YouTube) + **Chantier D** (finition UX) | Contenu vivant + polish visible. |
| **S4** | **Chantier E** (temps réel) + **Chantier G** (qualité/sécu) | Rétention + durcissement avant montée en charge. |
| **S5** | **Chantier F** (perf/offline) + QA finale | Optimisation marché réseaux lents. |

**Total estimé** : ~15–19 jours-homme.

---

## 9. Décisions à confirmer

1. **Référentiel niveaux** : valides-tu le tableau canonique du §1 (libellés « Bachelor 1/2/3 », « Master 1/2 », « MBA/DBA », « Doctorat ») ?
2. **Périmètre back-office V1** : programmes + universités + bourses suffisent, ou on inclut aussi pays + filières dès S2 ?
3. **« Parcours » YouTube** : nouvel onglet/section dédiée aux témoignages, OU remplacement direct des vidéos de l'Academy ?
4. **YouTube Data API** : tu peux fournir une `YOUTUBE_API_KEY` (Google Cloud, gratuit) ? Sinon je prévois le fallback.
5. **Migration données legacy** : on re-seed OMNES proprement (niveaux normalisés) ou on ajoute juste le fallback d'affichage ?
