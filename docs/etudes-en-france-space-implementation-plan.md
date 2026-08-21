# Espace Campus France — plan d'implémentation

Statut : **proposition**. Aucune ligne de production n'a été écrite. Ce document
dit ce qu'on construit, dans quel ordre, et surtout **ce que le code existant
donne déjà gratuitement** — parce que la moitié de la demande est déjà dans le
dépôt, éteinte derrière un drapeau.

Rédigé le 21/08/2026. Campagne Campus France annoncée à J+5 (≈ 26/08/2026).

---

## 1. Le constat, avant toute proposition

### 1.1 Ce qui existe déjà et qu'il ne faut PAS réécrire

| Besoin exprimé | Ce qui est déjà dans le dépôt | État |
|---|---|---|
| Générer un CV | `lib/app/features/tools/cv_generator_screen.dart` (750 l.) + `POST /tools/cv-summary` | Écrit, **masqué** |
| Modèles de lettres de motivation | `lib/app/features/tools/motivation_letters_screen.dart` (591 l.) + `motivation_letter_templates.dart` (184 l.) + `POST /tools/personalize-letter` | Écrit, **masqué** |
| Préparer les entretiens | `lib/app/features/tools/interview_simulator_screen.dart` (766 l.) + `/tools/interview/questions`, `/tools/interview/feedback` | Écrit, **masqué** |
| Rechercher des universités par profil | `backend/src/modules/matches/` (`matching.ts`, `match-recompute.service.ts`), `orientation-scorer.ts`, `lib/app/core/services/program_filter_service.dart` | Vivant |
| Catalogue établissements / formations | `InstitutionModel` / `ProgramModel` (`lib/app/core/models/catalog.dart`), endpoints `/catalog/*`, `catalog_remote_sync.dart` + cache Hive | Vivant |
| Candidature de A à Z | domaine `Case` (dossier + messages + timeline + tâches), `deadline_calendar_screen.dart`, `my_plan_engine.dart`, `roadmap_engine.dart` | Vivant |
| Pipeline d'import d'un catalogue vérifié | `backend/src/modules/scholarships-index/data/` + `scholarship-catalog.importer.ts` + `backend/src/cli/scholarships-catalog.cli.ts` | Vivant, éprouvé |
| Drapeaux de fonctionnalité pilotés serveur | `GET /config/app` → `features: {…}` + `successLabRollout.percent` | Vivant |
| Enveloppe d'accès par utilisateur (gratuit/payant) | `SuccessLabAccess` + `lib/app/core/data/success_lab_api_codec.dart` (`enabled` / `reasons` / `limits` / `features`) | Vivant, **patron à copier** |
| Rails de paiement | CinetPay + PayDunya, `PaymentIntent`, `ServicePurchase`, `ServicePackage`, webhooks | Vivant |
| France, écoles privées | `lib/app/features/france/france_private_admission_screen.dart` (M7) | Vivant, **distinct** |

Conséquence directe : les trois quarts du travail « lettres / CV / entretiens »
consistent à **allumer et contextualiser**, pas à écrire.

### 1.2 Les quatre choses que le dépôt n'a PAS

1. **Aucun Premium.** `lib/app/features/premium/premium_screen.dart:13-22` le dit
   noir sur blanc : il n'existe ni produit, ni prix, ni abonnement, ni
   encaissement, nulle part dans l'app ni dans le backend. La seule limite
   gratuit/payant réelle et vérifiable aujourd'hui est le quota hebdomadaire du
   coach IA (`CoachService`). « Réservé au plan KPB Premium » suppose donc de
   construire un droit d'accès serveur — c'est le plus gros morceau neuf.
2. **Les outils IA sont éteints en production.** `AppConfig.aiToolsEnabled`
   vaut `false` par défaut (`app_config.dart:146-152`), et son commentaire fixe
   la condition de bascule : IA-T1 en prod **et** la build 49 chez les
   testeurs. La basculer avant renvoie 403 aux testeurs de la 48.
3. **Aucun mécanisme de déclaration d'intérêt.** Ni liste d'attente, ni
   « ça m'intéresse », ni sondage produit. À construire pour la vitrine.
4. **Aucun espace Campus France.** Le module France existant traite les **écoles
   privées partenaires** (procédure directe, dossier + entretien école). Campus
   France, c'est la procédure **Études en France / DAP / Parcoursup** vers le
   public et le privé conventionné. Ce sont deux produits, pas deux onglets du
   même.

---

## 2. Le pari architectural : la mise à jour de J+5 ne doit pas passer par les stores

C'est la décision qui structure tout le reste.

La build en attente est `2.1.0+49` (`pubspec.yaml:24`, `docs/release-ledger.md`).
Une revue App Store prend 1 à 3 jours et peut refuser — le dépôt en porte les
cicatrices (`pubspec.yaml:74-85`, le retrait de `webview_flutter` pour un signal
de revue). **Faire dépendre l'ouverture de l'espace du jour J d'une soumission
store, c'est parier la campagne sur Apple.**

Le dépôt a déjà la réponse : `GET /config/app` sert un bloc `features` piloté par
variables d'environnement, avec kill switch et pourcentage de déploiement
(`backend/src/modules/config/app-config.controller.ts:52-70`).

**Donc :**

- La build qu'on publie bientôt embarque **la vitrine visible ET la coquille de
  l'espace, éteinte** (écrans, routes, décodeurs, entrées de navigation).
- Le jour J : `KPB_CAMPUS_FRANCE_ENABLED=true` côté serveur. L'espace apparaît.
  Aucun store, aucun délai, retour arrière en une variable.
- Le contenu (catalogue, formations, dates) arrive par `/catalog/*` et
  `/campus-france/*`, donc **sans binaire neuf** — c'est exactement ce que
  `catalog_remote_sync.dart` fait déjà pour le catalogue existant.

Ce qui suit est découpé pour maximiser ce qui est basculable côté serveur.

---

## 3. Phase 0 — La vitrine + la coquille (à embarquer dans la build imminente)

Objectif : mesurer la demande, constituer une liste de prospects réelle, et
poser les rails pour que la suite s'allume sans store.

### 3.1 Drapeaux

`lib/app/core/config/app_config.dart` — ajouter, sur le patron exact de
`aiToolsEnabled` (getter + `_override` `@visibleForTesting`, **pas** un
`bool.fromEnvironment` nu : un masquage sans contre-épreuve ne prouve rien, cf.
`app_config.dart:120-133`) :

```dart
static bool get campusFranceTeaserEnabled => …   // vitrine
static bool get campusFranceEnabled => …         // espace réel
```

`backend/src/modules/config/app-config.controller.ts` — ajouter à `features` :

```ts
campusFranceTeaser: enabled(process.env.KPB_CAMPUS_FRANCE_TEASER_ENABLED),
campusFrance: enabled(process.env.KPB_CAMPUS_FRANCE_ENABLED),
```

Le client doit **lire ces drapeaux serveur** — aujourd'hui `app_version_gate.dart`
ne lit que `minVersion`. C'est le petit chantier de plomberie qui rend tout le
reste basculable : un `RemoteFeatureFlags` chargé au boot, avec repli sur les
constantes de compilation quand l'appel échoue (fail closed).

### 3.2 Écrans

Nouveau dossier `lib/app/features/campus_france/` :

- `campus_france_teaser_screen.dart` — la vitrine. Ce qu'elle dit :
  ce que l'espace fera, ce qui sera **gratuit**, ce qui sera **Premium**, la
  fenêtre de campagne, et **une** action : « Ça m'intéresse ».
- `campus_france_home_screen.dart` — la coquille de l'espace réel, éteinte.

Règles de contenu, non négociables dans ce dépôt :

- **Aucune date en dur.** `IntakeCalendar`
  (`lib/app/core/data/intake_calendar.dart`) existe précisément parce que
  « rentrée septembre 2026 » écrit dans huit chaînes de traduction devenait un
  mensonge le 1er octobre, incorrigible sans store. Créer
  `CampusFranceCalendar` sur le même patron (horloge injectable
  `@visibleForTesting`), et faire servir la fenêtre de campagne par
  `/config/app` — la date du jour J est une variable d'environnement, pas une
  constante de binaire.
- **Aucune promesse de fonctionnalité au présent.** « bientôt », « en
  préparation », jamais « disponible ».
- **FR/EN**, comme tout le reste (`app_translations.dart`, 4 228 clés).

### 3.3 La déclaration d'intérêt — un vrai enregistrement, pas un événement

Deux options ont été pesées :

| Option | Ce qu'elle donne | Ce qu'elle ne donne pas |
|---|---|---|
| Sondage PostHog seul | un taux, en une heure de travail | **aucun nom à rappeler** |
| `POST /campus-france/interest` en base | une liste exportable, segmentée | ~1 jour de travail |

**Recommandation : la base.** L'objectif commercial est de rappeler ces gens
quand l'espace ouvre ; un événement analytique n'est pas un fichier de
prospects. Modèle Prisma :

```prisma
model CampusFranceInterest {
  id            String   @id @default(cuid())
  userId        String
  currentLevel  String?     // terminale, L2, L3, M1…
  targetLevel   String?
  fieldIds      String[]  @default([])
  wantsPremium  Boolean  @default(false)
  consentedAt   DateTime    // preuve horodatée, patron newsletterConsentedAt
  createdAt     DateTime @default(now())
  user          UserProfile @relation(…)
  @@unique([userId])
}
```

Deux exigences tirées des cicatrices du dépôt :

- **L'échec doit être visible à l'écran.** Le masquage `documentUploadEnabled`
  existe parce qu'un écran cochait « fourni ✓ » avant l'appel réseau puis
  avalait l'échec dans Crashlytics (`app_config.dart:160-186`). Ici : pas de
  « merci ! » optimiste — l'accusé vient de la réponse serveur.
- **Consentement horodaté**, sur le patron `newsletterOptIn` /
  `newsletterConsentedAt` (`schema.prisma:366-373`). Un « ça m'intéresse » n'est
  pas un consentement de prospection : le libellé doit dire qu'on rappellera.

Sortie admin : un écran `admin/app/campus-france/` listant les intéressés
(niveau, filières, Premium oui/non) + export CSV. Sans ça la liste n'existe que
dans Postgres et personne ne la rappelle.

### 3.4 Analytique

Ajouter à `lib/app/core/observability/analytics_event_contract.dart` **et** à
`docs/analytics-event-contract.md` (les deux sont tenus en synchronisation) :

| Événement | Paramètres | Ce qu'il mesure |
|---|---|---|
| `campus_france_teaser_viewed` | `source` | portée de la vitrine |
| `campus_france_interest_declared` | `current_level`, `field_count`, `wants_premium` | **la question posée** : y a-t-il une demande, et pour le payant ? |
| `campus_france_interest_failed` | `reason` | un envoi qui échoue silencieusement serait lu comme un désintérêt |

Le troisième n'est pas du zèle : sans lui, un backend en panne le jour du
lancement se lit dans les tableaux de bord comme « personne n'est intéressé ».

### 3.5 Points d'entrée

- Carte sur `home_screen.dart` (haut de page pendant la campagne).
- Entrée dans `kpb_tools_drawer.dart` **et** `student_tools_screen.dart` — le
  tiroir n'est pas la seule porte, et ne garder qu'une porte rejoue le défaut
  PARC-05 déjà commenté dans `student_tools_screen.dart:30-34`.
- Route `/campus-france` dans `AppRoutes.pages` **et** dans la liste blanche de
  `normalizeExternalRoute` — sans quoi la notification push du jour J atterrit
  sur l'accueil.
- **Pas de sixième onglet.** Le shell étudiant en compte cinq
  (`shell_tabs.dart`) et le Success Lab a déjà tranché ce débat
  (`app_routes.dart:178-180`) : espace poussé et lien profond, pas onglet.

### 3.6 Tests exigés par ce dépôt

- **Géométrie d'en-tête mesurée, pas estimée** — `test/features/france/france_header_geometry_test.dart`
  existe parce qu'un en-tête débordait de 88 px à l'échelle de texte 1,0, et
  que la première correction « par somme de hauteurs raisonnables » laissait
  encore 26 px (un emoji drapeau est plus haut que `fontSize × 1,3`). Même test
  pour la vitrine.
- Drapeau à `false` → aucun point d'entrée nulle part ; à `true` → tous.
- Échec d'envoi de l'intérêt → message visible, aucun état de succès local.
- Ligne dans `docs/release-ledger.md` pour le numéro de build consommé
  (`test/release/build_number_test.dart` lit ce fichier).

**Charge Phase 0 : 4 à 6 jours.** C'est ce qui tient avant J+5.

---

## 4. Phase 1 — Le catalogue dense (le vrai travail)

### 4.1 La contrainte de volume, chiffrée

Le catalogue actuel est du Dart `const` compilé dans le binaire. La France seule
pèse 96 établissements (1 633 lignes) et 133 formations (2 438 lignes) ; tous
pays confondus, `institutions/` + `programs/` font déjà **416 Ko de source
const**.

Un catalogue « ultra-dense » de l'offre Campus France est d'un autre ordre de
grandeur (milliers d'établissements, dizaines de milliers de formations).
**Il ne peut pas vivre dans le binaire** : poids, temps de démarrage, et surtout
aucune correction possible sans passer par les stores.

**Décision : le catalogue dense vit en Postgres et se sert par `/catalog/*`.**
Le client n'a rien à réinventer — `catalog_remote_sync.dart` fait déjà les
reprises bornées, l'écriture Hive, le repli hors ligne, et refuse les charges
marquées `source: "mock"` (`lib/app/core/data/catalog_source.dart`).
Le `mock_catalog` du binaire reste ce qu'il est : un échantillon derrière
`KpbSampleDataBanner`.

**Risque principal à traiter dans cette phase :** `AppController` tient
aujourd'hui la totalité du catalogue en listes mémoire. Un catalogue dense
impose une **recherche paginée côté serveur** (`GET /campus-france/search` avec
facettes + curseur) et un débounce côté client. C'est le point d'architecture à
ne pas repousser — l'ignorer donne une app qui rame le jour de la campagne.

### 4.2 Les recherches IA : elles produisent des *candidats*, jamais des lignes publiées

Le dépôt a déjà mangé ce plat. `catalog_source.dart:1-9` raconte comment
« Bourse McCall MacBain » et « Programme Mastercard Foundation Scholars » —
des fiches qui n'existent nulle part — ont atteint un appareil de production et
s'y sont installées. Et `docs/catalog-verification-sop.md:39-45` rappelle que
publier n'est pas déployer : 34 fiches vérifiées sont restées invisibles un mois
pendant que la production servait 11 fiches de démonstration.

Donc on réutilise **à l'identique** le pipeline des bourses :

```
recherches IA  →  fichiers de données versionnés dans le dépôt
               →  validateur de structure (CI)
               →  validateur strict (sources + vérificateur + fraîcheur)
               →  CLI import --dry-run  puis  --apply   (création seule)
               →  lignes INACTIVES, en attente de modération
               →  file /verification en admin  →  publication
```

Concrètement, en miroir de `backend/src/modules/scholarships-index/data/` :

- `backend/src/modules/campus-france/data/` — enregistrements versionnés
- `campus-france-catalog.importer.ts`, `.record-builder.ts`, `.types.ts`
- `backend/src/cli/campus-france-catalog.cli.ts` — `--dry-run` / `--apply`
  obligatoires, aucun mode par défaut
- scripts `campus-france:validate:structure`, `verify:campus-france`,
  `campus-france:import:dry-run`, `campus-france:import`

Exigences par enregistrement, reprises du README des bourses :

- FR **et** EN sur tous les champs rédigés ;
- niveau structuré ;
- **une source HTTPS officielle par affirmation** (site de l'établissement,
  Campus France, ministère) — un aggrégateur ne suffit pas ;
- `lastVerifiedAt` + vérificateur **nommé**, dans la cadence du SOP (180 jours
  pour établissements et formations) ;
- pas de source ⇒ la ligne reste `inactive`. Elle existe, elle ne s'affiche pas.

Ce n'est pas de la paperasse : c'est la seule chose qui empêche une recherche IA
mal cadrée de publier une formation qui n'existe pas, à trois jours d'une
campagne, dans une app qu'on ne peut pas corriger sans Apple.

### 4.3 Modèle de données — l'écart Campus France

`Institution` / `Program` couvrent le tronc commun. Champs à ajouter, propres à
la procédure :

- `campusFranceProcedure` : `eef` | `dap_blanche` | `dap_jaune` | `parcoursup` | `hors_eef`
- `institutionType` : université publique, école d'ingénieurs, BUT/IUT, BTS,
  école de commerce, privé conventionné…
- `applicationFeeEur`, `selectivity`, `admissionLevelAccepted`,
  `frenchLevelRequired` (B2/C1, TCF/DELF), `campusCity`, `formationCode`
- `intakeWindow` (ouverture / clôture de la campagne) — **servi**, jamais compilé

### 4.4 Client

`campus_france_catalog_screen.dart` : recherche + facettes, en réutilisant
`ProgramFilterService` / `ProgramFilterState` (à étendre des facettes CF),
`KpbSampleDataBanner`, `SourceLink`, `VerifiedBadge`, `KpbEmptyState`.
Une liste vide venue d'un serveur qui répond est un **fait**, pas une panne —
`catalog_remote_sync.dart` en fait déjà la distinction, l'écran doit la dire.

**Charge Phase 1 : 2 à 3 semaines** dont l'essentiel en collecte et
vérification de données, pas en code.

---

## 5. Phase 2 — « Les universités idéales pour mon profil »

Réutilise `backend/src/modules/matches/matching.ts`,
`match-recompute.service.ts` et `orientation-scorer.ts`. Ajouts :

- **Un scoreur Campus France** : série et mention du bac, niveau visé, budget
  (`annualTuitionBudgetEur`, déjà canonique en EUR), niveau de français,
  filière, éligibilité à la procédure, sélectivité vs profil.
- **Une liste à trois étages** — ambition / cible / sécurité. C'est la forme
  standard d'une shortlist d'admission, et c'est déjà ce que fait le skill
  `kpb-canada-shortlist` pour le Canada : on aligne le produit sur la méthode
  maison.
- **Un score explicable.** Chaque établissement dit *pourquoi* il est là. Le
  backend a déjà ce réflexe (`DECLARED_INTEREST_PERCENT`,
  `orientation-scorer.ts:55`). Un pourcentage opaque dans un produit payant se
  retourne au premier refus d'admission.

Écrans : réutiliser `AdmissionMeter`, `MatchBadge`, `aha_moment_screen.dart`, et
`share_card_service.dart` pour la carte de shortlist partageable — déjà
instrumentée par l'événement `share_card`.

**Charge : 1 à 2 semaines**, une fois le catalogue en place.

---

## 6. Phase 3 — Le dossier de A à Z

### 6.1 Ce qui n'est qu'à allumer

CV, lettres, entretiens : ~2 100 lignes déjà écrites et testées
(`test/features/tools/`). **Dépendance dure :** `aiToolsEnabled` ne bascule
qu'après le cutover de la build 49 (`docs/cutover-build49.md`) — garde
`AiConsentGuard` en prod **et** 49 chez les testeurs. Le pilier « outils » de
l'espace Campus France est donc **séquencé derrière cette bascule**, pas
derrière notre propre calendrier.

### 6.2 Ce qu'il faut vraiment écrire — le contenu spécifique

C'est là qu'est la valeur différenciante, et elle n'est pas dans le code :

- **Modèles de lettres par procédure** (EEF, DAP, Parcoursup, école privée).
- **Le « projet d'études »** — la pièce que l'entretien Campus France note
  réellement. Aujourd'hui absente du dépôt. À traiter comme un artefact à part
  entière, pas comme une variante de lettre de motivation.
- **Banque de questions d'entretien Campus France** pour
  `interview_simulator_screen.dart`, distincte des entretiens d'école privée.
- **Checklist et calendrier A→Z** : réutiliser `deadline_calendar_screen.dart`,
  `my_plan_engine.dart`, `roadmap_engine.dart`, et le domaine `Case` pour le
  relais conseiller.

**Charge : 1 à 2 semaines de code, plus la rédaction du contenu** (qui est du
travail éditorial KPB, à lancer dès maintenant en parallèle des phases 0-1).

---

## 7. Phase 4 — Gratuit vs Premium

### 7.1 Ce qu'il faut construire

Un **droit d'accès serveur**, sur le patron déjà éprouvé de `SuccessLabAccess` :

```
GET /campus-france/access
→ { enabled, reasons[], limits: {…}, features: { … } }
```

décodé par un `CampusFranceApiCodec` copié sur
`lib/app/core/data/success_lab_api_codec.dart` (valeurs inconnues tolérées,
aller-retour de cache sûr). Prisma : un modèle `Entitlement`
(`userId`, `plan`, `source`, `startsAt`, `endsAt`), alimenté par les
`ServicePurchase` / `PaymentIntent` existants.

**Le verrou est serveur, jamais seulement client.** Un bouton caché n'est pas un
paywall : `/campus-france/*` et `/tools/*` doivent refuser sans droit — c'est
exactement ce que fait déjà `AiConsentGuard`.

### 7.2 Découpage proposé (à valider)

| Gratuit | Premium |
|---|---|
| Vitrine, fenêtre de campagne, checklist en lecture | Shortlist complète à 3 étages, avec justification par établissement |
| Catalogue : recherche et filtres de base | Filtres avancés + comparaison + export PDF |
| **1** shortlist par profil, aperçu tronqué | Lettres, CV et projet d'études illimités |
| **1** modèle de lettre en aperçu | Simulateur d'entretien avec retour |
| Calendrier des échéances | Relecture de dossier par un conseiller + dossier suivi |

Deux principes : le gratuit doit être **réellement utile** (c'est le moteur
d'acquisition), et chaque verrou doit dire **pourquoi** il est là et **combien**
il coûte.

### 7.3 La décision qui bloque cette phase

Comment un droit s'active :

- **(a) Activation par conseiller** — un `ServicePackage` vendu par le tunnel
  existant (CinetPay/PayDunya), droit accordé au webhook `paid`. Réutilise tout,
  n'ouvre aucune surface de conformité store nouvelle. **Recommandé pour
  démarrer.**
- **(b) Abonnement encaissé dans l'app** par un prestataire tiers. **Risque
  store réel** : Apple et Google exigent leur achat intégré pour un abonnement
  *numérique*. Un abonnement Premium encaissé en CinetPay dans l'app est un
  motif de refus classique. Le contournement usuel est l'achat **hors app**
  (site web) ou la qualification en **prestation de service humaine**.

Vu l'historique de revue de ce dépôt, (a) d'abord, (b) seulement après avis.

**Charge : 2 à 3 semaines**, hors décision produit.

---

## 8. Phase 5 — Exploitation

- Ajouter les lignes Campus France à `docs/catalog-verification-sop.md` avec un
  **propriétaire réel nommé**. Le SOP signale lui-même que « Amina KPB » et
  « Fatou Admin » sont des personnages de jeu de test : sans propriétaire, la
  file de vérification reste verte sans que personne n'ait à la rouvrir.
- Admin : file `/verification` étendue + écran catalogue Campus France + export
  de la liste d'intérêt.
- Entonnoir à suivre : `teaser_viewed` → `interest_declared` → `catalog_search`
  → `shortlist_generated` → `premium_viewed` → `purchase`.

---

## 9. Risques, classés par ce qu'ils coûtent

| # | Risque | Traitement |
|---|---|---|
| 1 | **J+5 ne suffit pas** pour l'espace complet | Phase 0 seule au store ; le reste s'allume par drapeau serveur |
| 2 | **Volume du catalogue** vs listes mémoire de `AppController` | Recherche paginée serveur dès la Phase 1, pas après |
| 3 | **Données IA non vérifiées publiées** | Pipeline d'import + modération admin, non négociable |
| 4 | `aiToolsEnabled` **séquencé derrière la build 49** | Pilier outils planifié après le cutover, pas avant |
| 5 | **Conformité store** d'un abonnement numérique encaissé dans l'app | Activation par conseiller d'abord |
| 6 | **Dates de campagne périmées dans le binaire** | `CampusFranceCalendar` + fenêtre servie par `/config/app` |
| 7 | **Le nom « Campus France »** | voir ci-dessous |

### Le point 7 mérite une phrase de plus

Campus France est un opérateur de l'État français, pas un terme générique.
`backend/src/modules/partners/partners.service.ts:12` le cite comme partenaire,
mais **rien dans le dépôt n'atteste d'un partenariat**. Nommer un espace
commercial « Espace Campus France » sans convention expose à une réclamation, et
laisse croire à l'étudiant qu'il est sur un canal officiel.

Deux sorties : faire vérifier le droit d'usage, ou nommer l'espace par la
procédure et non par l'agence — « Études en France », « Campagne France
2026-2027 » — avec une mention de non-affiliation. L'app a déjà un module
`legal` et des mentions légales pour la porter. À trancher **avant** la build de
la vitrine, parce que le nom part dans les traductions et dans les captures
store.

---

## 10. Séquence

| Quand | Quoi | Store ? |
|---|---|---|
| J → J+4 | Phase 0 : vitrine + coquille + drapeaux + intérêt en base | **Oui**, une fois |
| J+5 | `KPB_CAMPUS_FRANCE_TEASER_ENABLED=true` | Non |
| J+5 → J+25 | Phase 1 : catalogue dense (collecte, vérification, import) | Non |
| en parallèle | Rédaction du contenu : projet d'études, lettres par procédure, questions d'entretien | Non |
| J+25 → J+35 | Phase 2 : matching et shortlist | Non si la coquille l'a prévu |
| après cutover 49 | Phase 3 : bascule `aiToolsEnabled` + contenu CF | Non |
| J+40 → J+60 | Phase 4 : droits d'accès + Premium | Selon (a) ou (b) |

---

## 11. Ce que j'attends comme décisions

1. **Le nom de l'espace** (risque n° 7) — bloquant pour la Phase 0.
2. **Le découpage gratuit/Premium** (§ 7.2) — la vitrine l'annonce, donc
   bloquant pour la Phase 0 aussi.
3. **Le mode d'activation du Premium** (§ 7.3) — bloquant pour la Phase 4
   seulement.
4. **Les dates réelles de la campagne** — non bloquant par construction, la
   fenêtre étant servie ; mais il faut la valeur pour la mettre en variable.
