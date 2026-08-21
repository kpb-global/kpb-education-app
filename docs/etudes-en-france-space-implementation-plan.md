# Espace « Études en France » — plan d'implémentation

Statut : **Phase 0 livrée**, décisions produit prises (§ 2). Les phases 1 à 5
restent à faire. Ce document dit ce qu'on construit, dans quel ordre, et surtout
**ce que le code existant donne déjà gratuitement** — parce que la moitié de la
demande est déjà dans le dépôt, éteinte derrière un drapeau.

> **Phase 0 — état réel.** Livrée et validée : modèle `EefInterest` + migration,
> module `etudes-en-france` (POST/GET authentifiés, échec fermé), drapeaux
> `features.eefTeaser` / `features.eef` et fenêtre de campagne servis par
> `/config/app`, back-office avec export CSV, `RemoteFeatureFlags` côté client,
> `EefCalendar`, la vitrine, la coquille de l'espace, l'arbitrage `EefEntry`, la
> route `/etudes-en-france` avec sa liste blanche de liens profonds, les quatre
> points d'entrée, 59 clés FR/EN, et les trois événements analytiques.
>
> Validé : `prisma generate`, lint backend, `nest build`, **926 tests backend** ;
> `flutter analyze` sans problème, `dart format`, **963 tests mobiles** sur
> Flutter 3.44.1 (la version épinglée par la CI) ; lint admin, `next build`,
> **50 tests admin**. Deux échecs mobiles subsistent
> (`privacy_disclosure_parity`, `theme_gallery_golden`) : **préexistants**,
> vérifiés en rejouant les deux fichiers sur l'arbre propre avant ce lot.
>
> Le numéro de build n'a **pas** été incrémenté : 49 est encore le courant et
> n'a pas été livrée, donc ce lot monte dedans. La commande de bascule du jour J
> est dans `docs/release-ledger.md`.

Rédigé le 21/08/2026. **Dates arrêtées depuis** : la campagne ouvre le
**1er octobre 2026**, pas à J+5 — voir
`docs/eef-campaign-calendar-2027-2028-research.md` et § 12.

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
4. **Aucun espace dédié à la procédure française publique.** Le module France
   existant traite les **écoles privées partenaires** (procédure directe,
   dossier + entretien école). La campagne visée ici, c'est **Études en France /
   DAP / Parcoursup** vers le public et le privé conventionné. Ce sont deux
   produits, pas deux onglets du même.

---

## 2. Décisions arrêtées

Trois questions bloquaient la Phase 0. Elles sont tranchées.

| # | Décision | Retenu |
|---|---|---|
| 1 | **Nom de l'espace** | **« Études en France »** — on nomme la procédure, pas l'agence. Campus France n'apparaît que dans le corps du texte, comme la plateforme concernée. |
| 2 | **Ligne gratuit / Premium** | **Catalogue gratuit, accompagnement payant.** Détail en § 8.2. |
| 3 | **Activation du Premium** | **`ServicePackage` + conseiller** : pack vendu par le tunnel CinetPay/PayDunya existant, droit accordé au webhook `paid`. |

### 2.1 Ce que la décision n° 1 règle, et ce qu'il reste à tenir

Elle écarte le risque principal : « Campus France » est un opérateur de l'État
français, et **rien dans le dépôt n'atteste d'un partenariat** — le seul endroit
qui le cite comme partenaire est un commentaire
(`backend/src/modules/partners/partners.service.ts:12`). Nommer un espace
commercial d'après l'agence laissait croire à l'étudiant qu'il est sur un canal
officiel.

Honnêteté sur le gain : « Études en France » est aussi le nom de la plateforme de
candidature opérée par Campus France. Le risque baisse fortement — c'est une
tournure descriptive, faiblement distinctive, et **on a le droit de nommer la
procédure qu'on accompagne** — mais il ne tombe pas à zéro. Trois règles le
tiennent, et elles coûtent peu :

- **usage descriptif seulement** : on dit qu'on accompagne la procédure, jamais
  qu'on est un guichet de la procédure ;
- **aucun emprunt d'identité visuelle** : pas de logo, pas de bleu institutionnel
  Campus France, pas de mise en page qui imite le portail ;
- **mention de non-affiliation** visible dans l'espace, portée par le module
  `legal` déjà présent.

Identifiants techniques retenus, cohérents avec le nom public et sans exposition
de marque nulle part — y compris dans les variables d'environnement que
l'exploitation lit et dans les événements analytiques :

| Objet | Valeur |
|---|---|
| Dossier Flutter | `lib/app/features/etudes_en_france/` |
| Route | `/etudes-en-france` |
| Module backend | `backend/src/modules/etudes-en-france/` |
| Drapeaux serveur | `KPB_EEF_TEASER_ENABLED`, `KPB_EEF_ENABLED` |
| Préfixe d'événements | `eef_*` |

---

## 3. Le pari architectural : l'ouverture ne doit pas passer par les stores

C'est la décision qui structure tout le reste.

> Écrit quand la campagne était annoncée à cinq jours. Les dates ont bougé —
> l'ouverture est au 1er octobre 2026 — et le pari n'a pas seulement survécu :
> **c'est ce déplacement qui l'a validé**. Une date d'ouverture compilée dans la
> build 49 serait fausse aujourd'hui, et fausse sans recours, puisqu'elle vivrait
> dans le binaire. Servie, elle a coûté une variable d'environnement.

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
- Le jour J : `KPB_EEF_ENABLED=true` côté serveur. L'espace apparaît. Aucun
  store, aucun délai, retour arrière en une variable.
- Le contenu (catalogue, formations, dates) arrive par `/catalog/*` et
  `/etudes-en-france/*`, donc **sans binaire neuf** — c'est exactement ce que
  `catalog_remote_sync.dart` fait déjà pour le catalogue existant.

Ce qui suit est découpé pour maximiser ce qui est basculable côté serveur.

---

## 4. Phase 0 — La vitrine + la coquille (à embarquer dans la build imminente)

Objectif : mesurer la demande, constituer une liste de prospects réelle, et
poser les rails pour que la suite s'allume sans store.

### 4.1 Drapeaux

`lib/app/core/config/app_config.dart` — ajouter, sur le patron exact de
`aiToolsEnabled` (getter + `_override` `@visibleForTesting`, **pas** un
`bool.fromEnvironment` nu : un masquage sans contre-épreuve ne prouve rien, cf.
`app_config.dart:120-133`) :

```dart
static bool get eefTeaserEnabled => …   // vitrine
static bool get eefEnabled => …         // espace réel
```

`backend/src/modules/config/app-config.controller.ts` — ajouter à `features` :

```ts
eefTeaser: enabled(process.env.KPB_EEF_TEASER_ENABLED),
eef: enabled(process.env.KPB_EEF_ENABLED),
```

Le client doit **lire ces drapeaux serveur** — aujourd'hui `app_version_gate.dart`
ne lit que `minVersion`. C'est le petit chantier de plomberie qui rend tout le
reste basculable : un `RemoteFeatureFlags` chargé au boot, avec repli sur les
constantes de compilation quand l'appel échoue (fail closed).

### 4.2 Écrans

Nouveau dossier `lib/app/features/etudes_en_france/` :

- `eef_teaser_screen.dart` — la vitrine. Ce qu'elle dit : ce que l'espace fera,
  ce qui sera **gratuit**, ce qui sera **Premium** (§ 8.2, mot pour mot), la
  fenêtre de campagne, la mention de non-affiliation, et **une** action :
  « Ça m'intéresse ».
- `eef_home_screen.dart` — la coquille de l'espace réel, éteinte.

Règles de contenu, non négociables dans ce dépôt :

- **Aucune date en dur.** `IntakeCalendar`
  (`lib/app/core/data/intake_calendar.dart`) existe précisément parce que
  « rentrée septembre 2026 » écrit dans huit chaînes de traduction devenait un
  mensonge le 1er octobre, incorrigible sans store. Créer `EefCalendar` sur le
  même patron (horloge injectable `@visibleForTesting`), et faire servir la
  fenêtre de campagne par `/config/app` — la date du jour J est une variable
  d'environnement, pas une constante de binaire.
- **Aucune promesse de fonctionnalité au présent.** « bientôt », « en
  préparation », jamais « disponible ».
- **FR/EN**, comme tout le reste (`app_translations.dart`, 4 228 clés).

### 4.3 La déclaration d'intérêt — un vrai enregistrement, pas un événement

Deux options ont été pesées :

| Option | Ce qu'elle donne | Ce qu'elle ne donne pas |
|---|---|---|
| Sondage PostHog seul | un taux, en une heure de travail | **aucun nom à rappeler** |
| `POST /etudes-en-france/interest` en base | une liste exportable, segmentée | ~1 jour de travail |

**Retenu : la base.** L'objectif commercial est de rappeler ces gens quand
l'espace ouvre ; un événement analytique n'est pas un fichier de prospects.
Modèle Prisma :

```prisma
model EefInterest {
  id            String      @id @default(cuid())
  userId        String      @unique
  currentLevel  String?     // terminale, L2, L3, M1…
  targetLevel   String?
  fieldIds      String[]    @default([])
  wantsPremium  Boolean     @default(false)
  consentedAt   DateTime    // preuve horodatée, patron newsletterConsentedAt
  createdAt     DateTime    @default(now())
  user          UserProfile @relation(…)
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

Sortie admin : un écran `admin/app/etudes-en-france/` listant les intéressés
(niveau, filières, Premium oui/non) + export CSV. Sans ça la liste n'existe que
dans Postgres et personne ne la rappelle.

### 4.4 Analytique

Ajouter à `lib/app/core/observability/analytics_event_contract.dart` **et** à
`docs/analytics-event-contract.md` (les deux sont tenus en synchronisation) :

| Événement | Paramètres | Ce qu'il mesure |
|---|---|---|
| `eef_teaser_viewed` | `source` | portée de la vitrine |
| `eef_interest_declared` | `current_level`, `field_count`, `wants_premium` | **la question posée** : y a-t-il une demande, et pour le payant ? |
| `eef_interest_failed` | `reason` | un envoi qui échoue silencieusement serait lu comme un désintérêt |

Le troisième n'est pas du zèle : sans lui, un backend en panne le jour du
lancement se lit dans les tableaux de bord comme « personne n'est intéressé ».

### 4.5 Points d'entrée

- Carte sur `home_screen.dart` (haut de page pendant la campagne).
- Entrée dans `kpb_tools_drawer.dart` **et** `student_tools_screen.dart` — le
  tiroir n'est pas la seule porte, et ne garder qu'une porte rejoue le défaut
  PARC-05 déjà commenté dans `student_tools_screen.dart:30-34`.
- Route `/etudes-en-france` dans `AppRoutes.pages` **et** dans la liste blanche
  de `normalizeExternalRoute` — sans quoi la notification push du jour J
  atterrit sur l'accueil.
- **Pas de sixième onglet.** Le shell étudiant en compte cinq
  (`shell_tabs.dart`) et le Success Lab a déjà tranché ce débat
  (`app_routes.dart:178-180`) : espace poussé et lien profond, pas onglet.

### 4.6 Tests exigés par ce dépôt

- **Géométrie d'en-tête mesurée, pas estimée** — `test/features/france/france_header_geometry_test.dart`
  existe parce qu'un en-tête débordait de 88 px à l'échelle de texte 1,0, et
  que la première correction « par somme de hauteurs raisonnables » laissait
  encore 26 px (un emoji drapeau est plus haut que `fontSize × 1,3`). Même test
  pour la vitrine.
- Drapeau à `false` → aucun point d'entrée nulle part ; à `true` → tous.
- Échec d'envoi de l'intérêt → message visible, aucun état de succès local.
- Le nom « Campus France » n'apparaît dans aucune clé de titre ni dans aucun
  identifiant — un test de traduction le vérifie, parce que la décision § 2 se
  perd sinon au premier ajout de chaîne.
- Ligne dans `docs/release-ledger.md` pour le numéro de build consommé
  (`test/release/build_number_test.dart` lit ce fichier).

**Charge Phase 0 : 4 à 6 jours.** Mesurée : livrée en un jour de travail
continu, ce qui laisse le calendrier au catalogue plutôt qu'à la coquille.

---

## 5. Phase 1 — Le catalogue dense (le vrai travail)

### 5.1 La contrainte de volume, chiffrée

Le catalogue actuel est du Dart `const` compilé dans le binaire. La France seule
pèse 96 établissements (1 633 lignes) et 133 formations (2 438 lignes) ; tous
pays confondus, `institutions/` + `programs/` font déjà **416 Ko de source
const**.

Un catalogue « ultra-dense » de l'offre française est d'un autre ordre de
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
impose une **recherche paginée côté serveur** (`GET /etudes-en-france/search`
avec facettes + curseur) et un débounce côté client. C'est le point
d'architecture à ne pas repousser — l'ignorer donne une app qui rame le jour de
la campagne.

### 5.2 Les recherches IA : elles produisent des *candidats*, jamais des lignes publiées

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

- `backend/src/modules/etudes-en-france/data/` — enregistrements versionnés
- `eef-catalog.importer.ts`, `.record-builder.ts`, `.types.ts`
- `backend/src/cli/eef-catalog.cli.ts` — `--dry-run` / `--apply` obligatoires,
  aucun mode par défaut
- scripts `eef:validate:structure`, `verify:eef`, `eef:import:dry-run`,
  `eef:import`

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

### 5.3 Modèle de données — l'écart procédure

`Institution` / `Program` couvrent le tronc commun. Champs à ajouter, propres à
la procédure :

- `procedureType` : `eef` | `dap_blanche` | `dap_jaune` | `parcoursup` | `hors_eef`
- `institutionType` : université publique, école d'ingénieurs, BUT/IUT, BTS,
  école de commerce, privé conventionné…
- `applicationFeeEur`, `selectivity`, `admissionLevelAccepted`,
  `frenchLevelRequired` (B2/C1, TCF/DELF), `campusCity`, `formationCode`
- `intakeWindow` (ouverture / clôture de la campagne) — **servi**, jamais compilé

### 5.4 Client

`eef_catalog_screen.dart` : recherche + facettes, en réutilisant
`ProgramFilterService` / `ProgramFilterState` (à étendre des facettes de
procédure), `KpbSampleDataBanner`, `SourceLink`, `VerifiedBadge`,
`KpbEmptyState`. Une liste vide venue d'un serveur qui répond est un **fait**,
pas une panne — `catalog_remote_sync.dart` en fait déjà la distinction, l'écran
doit la dire.

**Charge Phase 1 : 2 à 3 semaines** dont l'essentiel en collecte et
vérification de données, pas en code.

---

## 6. Phase 2 — « Les universités idéales pour mon profil »

Réutilise `backend/src/modules/matches/matching.ts`,
`match-recompute.service.ts` et `orientation-scorer.ts`. Ajouts :

- **Un scoreur propre à la procédure** : série et mention du bac, niveau visé,
  budget (`annualTuitionBudgetEur`, déjà canonique en EUR), niveau de français,
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

## 7. Phase 3 — Le dossier de A à Z

### 7.1 Ce qui n'est qu'à allumer

CV, lettres, entretiens : ~2 100 lignes déjà écrites et testées
(`test/features/tools/`). **Dépendance dure :** `aiToolsEnabled` ne bascule
qu'après le cutover de la build 49 (`docs/cutover-build49.md`) — garde
`AiConsentGuard` en prod **et** 49 chez les testeurs. Le pilier « outils » de
l'espace est donc **séquencé derrière cette bascule**, pas derrière notre propre
calendrier.

### 7.2 Ce qu'il faut vraiment écrire — le contenu spécifique

C'est là qu'est la valeur différenciante, et elle n'est pas dans le code :

- **Modèles de lettres par procédure** (EEF, DAP, Parcoursup, école privée).
- **Le « projet d'études »** — la pièce que l'entretien de la procédure note
  réellement. Aujourd'hui absente du dépôt. À traiter comme un artefact à part
  entière, pas comme une variante de lettre de motivation.
- **Banque de questions d'entretien** propre à la procédure, distincte des
  entretiens d'école privée, pour `interview_simulator_screen.dart`.
- **Checklist et calendrier A→Z** : réutiliser `deadline_calendar_screen.dart`,
  `my_plan_engine.dart`, `roadmap_engine.dart`, et le domaine `Case` pour le
  relais conseiller.

**Charge : 1 à 2 semaines de code, plus la rédaction du contenu** (qui est du
travail éditorial KPB, à lancer dès maintenant en parallèle des phases 0-1).

---

## 8. Phase 4 — Gratuit vs Premium

### 8.1 Ce qu'il faut construire

Un **droit d'accès serveur**, sur le patron déjà éprouvé de `SuccessLabAccess` :

```
GET /etudes-en-france/access
→ { enabled, reasons[], limits: {…}, features: { … } }
```

décodé par un `EefApiCodec` copié sur
`lib/app/core/data/success_lab_api_codec.dart` (valeurs inconnues tolérées,
aller-retour de cache sûr). Prisma : un modèle `Entitlement`
(`userId`, `plan`, `source`, `startsAt`, `endsAt`).

**Le verrou est serveur, jamais seulement client.** Un bouton caché n'est pas un
paywall : `/etudes-en-france/*` et `/tools/*` doivent refuser sans droit — c'est
exactement ce que fait déjà `AiConsentGuard`.

### 8.2 Le découpage — arrêté

**Catalogue gratuit, accompagnement payant.** Le gratuit doit rester réellement
utile : c'est le moteur d'acquisition, et un étudiant qui n'a rien goûté
n'achète pas.

| Gratuit | Premium |
|---|---|
| Vitrine, fenêtre de campagne, mentions | Shortlist complète à 3 étages, **avec la justification par établissement** |
| Catalogue : recherche + filtres de base | Filtres avancés, comparaison, export PDF |
| **1** shortlist par profil, aperçu tronqué | Lettres, CV et projet d'études illimités |
| **1** modèle de lettre en aperçu | Simulateur d'entretien avec retour |
| Calendrier des échéances | Relecture de dossier par un conseiller + dossier suivi |

Chaque verrou doit dire **pourquoi** il est là et **combien** il coûte. Un cadenas
muet est une fuite, pas une conversion.

### 8.3 L'activation — arrêtée

**`ServicePackage` + conseiller.** Un pack vendu par le tunnel de paiement déjà
en place (CinetPay / PayDunya, XOF en unités mineures entières, webhooks), et le
droit `Entitlement` accordé à la réception du webhook `paid`. Réutilise
`PaymentIntent` / `ServicePurchase` / `ServicePackage` sans rien inventer.

Pourquoi c'est aussi le choix le plus sûr côté boutiques : Apple et Google
exigent leur achat intégré pour un **abonnement numérique**. Un abonnement
encaissé par un prestataire tiers *dans* l'app est un motif de refus classique.
Le pack vendu comme **prestation d'accompagnement humaine**, avec relecture
conseiller et dossier suivi, ne tombe pas dans cette case — et c'est de toute
façon ce que KPB vend réellement. Vu l'historique de revue de ce dépôt, on ne
s'approche pas de la ligne.

Point à ne pas laisser filer : le droit doit être **révocable et daté**
(`endsAt`), et sa perte doit se lire à l'écran comme une fin d'abonnement, pas
comme une panne.

**Charge : 2 à 3 semaines.**

---

## 9. Phase 5 — Exploitation

- Ajouter les lignes « Études en France » à `docs/catalog-verification-sop.md`
  avec un **propriétaire réel nommé**. Le SOP signale lui-même que « Amina KPB »
  et « Fatou Admin » sont des personnages de jeu de test : sans propriétaire, la
  file de vérification reste verte sans que personne n'ait à la rouvrir.
- Admin : file `/verification` étendue + écran catalogue + export de la liste
  d'intérêt.
- Entonnoir à suivre : `eef_teaser_viewed` → `eef_interest_declared` →
  `eef_catalog_search` → `eef_shortlist_generated` → `premium_viewed` →
  `purchase`.

---

## 10. Risques, classés par ce qu'ils coûtent

| # | Risque | Traitement | État |
|---|---|---|---|
| 1 | **Le délai ne suffit pas** pour l'espace complet | Phase 0 seule au store ; le reste s'allume par drapeau serveur | traité — et le report au 01/10 l'a confirmé |
| 2 | **Volume du catalogue** vs listes mémoire de `AppController` | Recherche paginée serveur dès la Phase 1, pas après | à traiter en Phase 1 |
| 3 | **Données IA non vérifiées publiées** | Pipeline d'import + modération admin, non négociable | traité par le pipeline |
| 4 | `aiToolsEnabled` **séquencé derrière la build 49** | Pilier outils planifié après le cutover | contrainte acceptée |
| 5 | **Conformité store** d'un abonnement numérique | Pack d'accompagnement + activation conseiller (§ 8.3) | **arrêté** |
| 6 | **Dates de campagne périmées dans le binaire** | `EefCalendar` + fenêtre servie par `/config/app` | traité |
| 7 | **Marque « Campus France »** | Espace nommé d'après la procédure + non-affiliation + aucun emprunt visuel (§ 2.1) | **arrêté** |

---

## 11. Séquence — en dates réelles

Les repères relatifs (« J+5 ») ont été remplacés par des dates : la campagne
n'ouvre pas à J+5 mais le **1er octobre 2026**, et raisonner en jours relatifs
dans un document qu'on relit trois semaines plus tard est exactement la faute
que `IntakeCalendar` porte en commentaire.

| Quand | Quoi | Store ? |
|---|---|---|
| **fait** | Phase 0 : vitrine + coquille + drapeaux + intérêt en base | — |
| dès que possible | Publier la build 49, vitrine embarquée **éteinte** | **Oui**, une fois |
| après déploiement | `prisma migrate deploy`, puis les 3 variables `KPB_EEF_*` (voir `docs/release-ledger.md`) | Non |
| 21/08 → **23/09** | **Phase 1 : le catalogue dense** (collecte, vérification, import) | Non |
| en parallèle | Rédaction du contenu : projet d'études, lettres par procédure, questions d'entretien | Non |
| **01/10/2026** | Ouverture de la campagne → `KPB_EEF_ENABLED=true` | Non |
| 01/10 → mi-oct | Phase 2 : matching et shortlist | Non si la coquille l'a prévu |
| après cutover 49 | Phase 3 : bascule `aiToolsEnabled` + contenu spécifique | Non |
| mi-oct → fin oct | Phase 4 : `Entitlement` + pack Premium | Non (pack = prestation) |

### 11.1 Ce que « opérationnel le 23 septembre » veut dire, exactement

La date de 23/09 a été posée comme cible produit. Elle ne peut pas être une
bascule de drapeau, et il vaut mieux l'écrire ici que de le découvrir ce jour-là :

- **La vitrine, elle, peut s'allumer maintenant.** Elle est dans la build 49,
  éteinte ; une variable suffit. Rien n'oblige à attendre le 23/09 pour
  commencer à collecter les intérêts — au contraire, chaque jour d'avance est un
  jour de liste.
- **L'espace réel est une coquille vide.** `KPB_EEF_ENABLED=true` le 23/09
  afficherait un espace sans catalogue, sans matching et sans contenu. Le
  drapeau existe, la matière non.
- Donc **le 23/09 est une date de livraison de la Phase 1**, pas une bascule.
  C'est un engagement de production de données : ~4 semaines et demie pour
  collecter, sourcer et faire vérifier le catalogue. Le § 12 dit ce qui manque
  pour la démarrer.
- **La bascule, elle, tombe le 01/10** — le jour où la campagne ouvre
  réellement. Livrer la Phase 1 une semaine avant est la bonne marge : elle
  laisse le temps de la vérification humaine, qui est le vrai goulot.

---

## 12. Ce qui reste ouvert

Les dates de campagne, qui étaient le seul point ouvert à la rédaction, sont
**réglées** : ouverture globale au 1er octobre 2026, aucune clôture globale
servie (les clôtures divergent trop — voir
`docs/eef-campaign-calendar-2027-2028-research.md` et le registre de release).
Ce qui reste :

### 12.1 Bloquant pour démarrer la Phase 1

**Le propriétaire nommé de la file de vérification du catalogue.** Une personne
réelle, pas un rôle. Le pipeline des bourses impose un vérificateur nommé par
affirmation publiée, et la SOP existante signale elle-même « Amina KPB » et
« Fatou Admin » comme des personas de test. Sans ce nom, la Phase 1 produit des
candidats que personne n'a le droit de publier — c'est-à-dire rien.

### 12.2 Non bloquant, mais à trancher avant le 01/10

- **La mention de non-affiliation** mérite une relecture juridique. Elle est
  rédigée et un test verrouille ses deux moitiés (ne pas se présenter comme
  Campus France, nommer Campus France dans l'avertissement), mais valider un
  texte qui parle d'un établissement public français n'est pas une décision
  d'ingénierie.
- **Aucune notification push du jour J n'est construite.** La route
  `/etudes-en-france` est joignable drapeaux éteints précisément pour pouvoir en
  recevoir une, mais aucune campagne n'est planifiée. Prévenir la base le
  1er octobre est un lot à part.
- **Les clôtures par pays.** 91 couples pays × procédure ne sont pas publiés à
  ce jour. Elles arrivent avec le catalogue de la Phase 1, déjà structuré par
  pays ; en attendant l'app dit que les clôtures varient, ce qui est vrai.

### 12.3 Une limite assumée de la vitrine

La déclaration d'intérêt exige un **compte**. Un invité voit tout le contenu,
mais son bouton devient « créer mon compte ». C'est délibéré — une déclaration
sans identité n'est pas rappelable, et la liste sert à rappeler des gens. La
conséquence à connaître avant de lire l'entonnoir : `eef_interest_declared`
mesure aussi la friction d'inscription, pas seulement l'appétence. Capter les
invités supposerait d'accepter des lignes sans contact, ce qui n'est plus la
même liste.
