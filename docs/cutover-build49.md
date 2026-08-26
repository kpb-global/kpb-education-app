# Bascule couplée — build mobile 49 + déploiement backend

Runbook opératoire. Il se suit **ligne à ligne**, dans l'ordre. Chaque étape dit
sa commande exacte, **ce qu'on observe** pour savoir qu'elle a pris, et son
retour arrière. Aucune étape ne se valide sur « ça devrait marcher ».

## Convention de lecture

Les numéros de ligne cités renvoient à `main` au commit **`3729ba13ad2b`** pour
les trois fichiers que la branche `docs/store-pack` porte encore en version
antérieure : `.github/workflows/deploy.yml`,
`.github/workflows/release-preflight.yml` et
`backend/src/modules/orientation/orientation.service.ts`. Tous les autres
fichiers cités sont identiques sur les deux refs.

Quatre SHA courts sont utilisés tout du long, gelés ici :

| SHA court | Commit | Ce qu'il apporte |
|---|---|---|
| `ce999fb4389c` | #213 | `AiConsentGuard` devant /tools, /document-review, /orientation |
| `55551116fe36` | #216 | la projection close de l'invite d'orientation (fin de la fuite du nom) |
| `3729ba13ad2b` | #218 | tête de `main` au moment d'écrire ce runbook |
| `30957dd1b064` | #194 | `2.1.0+48` — la build **qui est chez les testeurs** |

---

## 1. La contrainte, noir sur blanc

L'ordre habituel est écrit dans `docs/DEPLOYMENT.md:131-137` : **le backend
d'abord, le mobile ensuite**, parce qu'un téléphone déjà mis à jour ne revient
pas en arrière alors qu'un backend, si.

**Cette bascule est l'exception, et elle est inversée.**

`main` pose `AiConsentGuard` devant :

- `/tools/cv-summary`, `/tools/personalize-letter`, `/tools/interview/questions`,
  `/tools/interview/feedback` — `backend/src/modules/tools/tools.controller.ts:12-13`
- `/document-review` — `backend/src/modules/document-review/document-review.controller.ts:11-12`
- `/orientation/sessions` et `/orientation/submit` — `backend/src/modules/orientation/orientation.controller.ts:28-29`, `:36-37`

La garde répond **403 `ai_consent_required`** dès que `aiConsentedAt` est nul en
base (`backend/src/modules/ai/ai-consent.guard.ts:32-41`,
`backend/src/modules/ai/ai-consent.service.ts:43`).

La build 48 n'a **aucun masquage** de ces surfaces : `AppConfig.aiToolsEnabled`
n'existe pas dans son code (introduit en #208 `542d02f1029b`, après #194), et son
traitement d'un 403 est faux sur les quatre écrans :

| Écran de la 48 | Ce qu'il affiche sur 403 | Preuve |
|---|---|---|
| Lettres de motivation | « Erreur IA — vérifiez votre connexion » | `30957dd:lib/app/features/tools/motivation_letters_screen.dart:230-233` + `app_translations.dart:914-915` |
| Simulateur d'entretien | idem, aux deux appels | `30957dd:…/interview_simulator_screen.dart:111-115`, `:141-144` |
| Générateur de CV | « Reconnecte-toi pour utiliser l'IA. » | `30957dd:…/cv_generator_screen.dart:246-248` + `app_translations.dart:920-921` |
| Relecture de document | `doc_review_unavailable` | `30957dd:lib/app/features/cases/document_review_screen.dart:134-135` |

Aucun ne parle de consentement. Le mapping honnête d'un 403 n'arrive qu'avec
`lib/app/core/utils/ai_error_message.dart`, créé par #213 (`ce999fb4389c`) —
donc **absent de la 48**.

La 49 masque ces quatre outils côté client
(`lib/app/core/config/app_config.dart:149-154`, `student_tools_screen.dart:34`,
`kpb_tools_drawer.dart:162`, `:195`, `case_detail_screen.dart:444`, `:495`), donc
elle **tourne sans dommage contre l'ANCIEN backend**.

**Conclusion opératoire : le déploiement SUIT la build.** Le correctif de la
fuite du nom (#216, `55551116fe36`) part dans le **même** déploiement — il n'y a
pas deux fenêtres à ouvrir.

### Le rayon d'exposition, mesuré et non minimisé

Entre l'étape 8 et la mise à jour de chaque appareil resté en 48, les quatre
outils de la 48 affichent un message faux. Ce n'est pas réductible à zéro, c'est
réductible à « le temps que les testeurs mettent à se mettre à jour ».

Deux atténuations, prouvées :

- un testeur 48 qui a **déjà** accepté le consentement via le FAB du coach
  (`lib/app/features/ai_advisor/coach_fab.dart:7`,
  `lib/app/features/ai_advisor/ai_consent.dart:32-34`) a `aiConsentedAt` posé en
  base : il ne voit **aucun** 403. Le rayon se limite aux testeurs 48 qui n'ont
  jamais consenti ;
- le questionnaire d'orientation ne casse pas, en 48 comme en 49 : sur n'importe
  quelle erreur réseau, `submitOrientation` **retombe sur le moteur local** et
  rend quand même des recommandations
  (`lib/app/core/controllers/app_controller.dart:846-860` ; déjà présent en 48,
  `30957dd:app_controller.dart:741-749`). Le 403 y est **silencieux** : il part
  en non-fatal Crashlytics (`reason: 'submitOrientation'`) et l'écran se contente
  d'arrêter son spinner (`lib/app/features/orientation/orientation_screen.dart:294-297`).

### Ce que la bascule ne change PAS

- **Le coach IA.** `/coach` n'est pas sous la nouvelle garde
  (`backend/src/modules/coach/coach.controller.ts:19` : `StudentAuthGuard` seul),
  et son propre contrôle de consentement existait déjà dans le backend de la 48
  (`30957dd:backend/src/modules/coach/coach.service.ts:352`).
- **Le nom civil ne cesse pas de quitter le téléphone.** Le client poste toujours
  `fullName` vers l'API KPB (`lib/app/core/controllers/app_controller.dart:829`).
  #216 ferme la projection **vers Groq** uniquement
  (`orientation.service.ts:166-179`, `:190-194` — la liste est close, `fullName`
  n'y est pas). Hébergement KPB = UE ; c'est le sous-traitant US qui cesse de
  recevoir le nom.
- **Mautic.** Le défaut connu (`backend/src/modules/newsletter/mautic.service.ts:76`
  appelle `upsertContact` avant de brancher sur `optIn` ;
  `newsletter-sync.service.ts:48` compare un `newsletterSyncedOptIn` nul par
  défaut) reste **inerte** tant que Mautic n'est pas configuré. Ce déploiement ne
  le corrige pas et ne l'active pas. **Ne pas renseigner les `MAUTIC_*` du `.env`
  pendant cette bascule.**
- **`auth_welcome_screen.dart:143`** annonce toujours « lettre, entretien »
  (`app_translations.dart:2020-2021`, `:4763-4764`) alors que ces deux outils sont
  masqués en 49. Dette de copie assumée, non bloquante, à traiter hors bascule.

### LA surprise du plan : démasquer exige une NOUVELLE build

`AppConfig.aiToolsEnabled` est un `bool.fromEnvironment` — **une constante de
compilation**, lue au `--dart-define` du BUILD, jamais à l'exécution
(`lib/app/core/config/app_config.dart:151-154`). Il n'existe **aucun** réglage
serveur qui rallume les quatre outils : `/api/config/app` ne renvoie que
`minVersion` et les URLs de store
(`backend/src/modules/config/app-config.controller.ts:43-46`), et le seul kill
switch IA du backend, `KPB_AI_DIAGNOSTIC_KILL_SWITCH`
(`…/config/app-config.controller.ts:43`), concerne le Success Lab, pas cette
garde.

**Donc : rallumer les outils IA après cette bascule = construire et distribuer
une build 50.** Ce n'est pas un oubli du plan, c'est son cadre. Ne promettre à
personne un « on rallumera demain sans rien redéployer ».

### 1 bis. Ce que la 49 embarque en plus depuis que ce runbook a été écrit

La **Phase 0 de l'espace « Études en France »** : la vitrine, la coquille de
l'espace, la route `/etudes-en-france`, `POST/GET /etudes-en-france/interest`, le
back-office avec export CSV, et une migration (étape 1).

**Cela ne change pas le sens du couplage, et voici pourquoi — c'est la seule
question qui compte pour l'étape 3.** La 49 lit `/config/app` au démarrage. Sur
l'ANCIEN backend, les clés `features.eefTeaser`, `features.eef` et `eefCampaign`
sont **absentes** :

- `RemoteFeatureFlags._readFeatures` ne retient que les entrées booléennes et
  ignore ce qu'elle ne trouve pas ; `_flag` retombe alors sur la constante de
  compilation, qui vaut `false` ;
- `EefCampaignWindow.fromJson(null)` rend la fenêtre vide ;
- `EefEntry.isVisible` rend donc `false`, et **trois** des quatre points
  d'entrée se masquent (carte d'accueil, tiroir, boîte à outils). Le quatrième
  est la route elle-même, qui reste joignable par construction —
  cf. la phrase suivante. La route reste joignable — elle doit l'être pour une notification —
  mais elle rend `ComingSoonScreen`.

La 49 tourne donc **sans erreur visible** contre le backend d'avant, exactement
comme elle le fait pour les outils IA. `tolerates-old` reste la bonne
déclaration, et le déploiement couplé reste **dû** — désormais pour deux raisons
au lieu d'une : `AiConsentGuard`, et la table `EefInterest` sans laquelle une
déclaration d'intérêt échoue.
Le code exact dépend de ce qui manque, et le savoir évite de chercher au mauvais
endroit à l'étape 10 : **404** contre l'ancienne image, qui n'a pas la route ;
**500** de schéma si l'image est neuve mais la migration non appliquée ; le
**503** est réservé au cas où `DATABASE_URL` est absente.

Ce que ça ajoute au plan : l'**étape 9 bis**, plus les amendements de l'étape 1,
du § 3, de l'étape 10 et du résumé — chacun signalé là où il se trouve.

---

## 2. Feux verts du propriétaire — la liste courte

**Cinq** étapes ne se lancent **pas** sans accord explicite du propriétaire.
Le tableau en liste quatre ; la cinquième est l'étape 12, marquée « feu vert
propriétaire » dans le corps et dans le résumé. Un décompte qui ne correspond
pas au corps fait douter de la liste entière :

| Étape | Pourquoi |
|---|---|
| **2** — geler le ref et le ledger | fige le contenu de la release |
| **3** — préflight en `tolerates-old` | c'est la **déclaration** que la prod restera en retard |
| **6** — distribuer la 49 | **point de non-retour** : TestFlight / Play |
| **8** — déploiement couplé `scope=full` | c'est lui qui 403 les testeurs restés en 48 |

`run_seed` **doit rester `false`** à l'étape 8. Sa valeur par défaut l'est déjà
(`deploy.yml:52-56`) ; passé à `true` il exécute `npm run prisma:seed`
(`deploy.yml:252-255`), réservé à une **première installation**
(`docs/DEPLOYMENT.md:361-377`) : sur une base vivante il réécrit les comptes
admin et du contenu de démo.

---

## 3. Réversible / irréversible

| Objet | Statut | Comment on revient |
|---|---|---|
| Image Docker `api` / `admin` | **RÉVERSIBLE** | ré-épingler le tag précédent (étape 8, retour arrière) — l'image est déjà sur le VPS |
| Conteneur `kpb_web` / `nginx.conf` | **RÉVERSIBLE** | redéployer le ref précédent ; le fichier neuf est validé dans un conteneur jetable avant qu'on y touche (`deploy.yml:172-174`, `:323-325`) |
| Migration Prisma | **IRRÉVERSIBLE** (forward-only) — **et elle s'applique** | aucun retour de schéma. `docs/DEPLOYMENT.md:120-124`. Le dump pré-déploiement (`deploy.yml:237-247`) ne se restaure qu'en cas de corruption avérée. Cette bascule porte `20260821120000_eef_interest` : additive, une table neuve, rien à défaire (voir étape 1) |
| Build 49 distribuée | **IRRÉVERSIBLE** | un téléphone mis à jour ne redescend pas. Le seul retour est une build 50. Play : suspendre le déploiement n'a jamais désinstallé personne |
| Numéro de build 49 | **IRRÉVERSIBLE** | consommé à vie une fois téléversé (`docs/release-ledger.md:3-5`, `:7-10`) |
| `KPB_MIN_APP_VERSION` | réversible mais **piégé** | hors périmètre de cette soirée — voir étape 12 |

---

## 4. La séquence

### Étape 0 — Mesurer l'état réel de la production (lecture seule)

```bash
curl -fsS https://api.kpbeducation.cloud/api/health/version
```

**On observe** : `{"sha":"<12 caractères>","startedAt":"…"}`. Noter ce SHA comme
`PREV_SHA` — il sert au retour arrière de l'étape 8.
(`backend/src/modules/health/health.controller.ts:51-56`.)

Puis, depuis le dépôt :

```bash
git fetch --all --tags
git merge-base --is-ancestor ce999fb4389c <PREV_SHA> \
  && echo "STOP — la garde est DÉJÀ en production" \
  || echo "OK — la garde n'est pas encore en production"
```

**On observe** l'une des trois issues :

- `OK — la garde n'est pas encore en production` → la prémisse du runbook tient,
  continuer ;
- `STOP — la garde est DÉJÀ en production` → les testeurs 48 sont **déjà** en
  403. Ce runbook n'est plus une précaution mais une réparation :
  **arrêter et replanifier** (soit distribuer la 49 en urgence, soit revenir au
  tag précédent par le retour arrière de l'étape 8) ;
- `sha` vaut `unknown` → la prod n'a pas été livrée par `deploy.yml`
  (`health.controller.ts:54`). Le préflight refusera de toute façon
  (`release-preflight.yml:80-84`). Redéployer avant d'aller plus loin.

**Retour arrière** : aucun, lecture seule.

---

### Étape 1 — Mesurer l'état du schéma (lecture seule, SSH)

C'est cette étape, et elle seule, qui dit si la bascule contient une opération
irréversible.

```bash
ssh "$VPS_USER@$VPS_HOST" \
  "cd $VPS_PATH && KPB_IMAGE_TAG=<PREV_SHA> docker compose run --rm --no-deps api npx prisma migrate status"
```

`KPB_IMAGE_TAG` est **obligatoire** dans cette ligne : `docker-compose.yml:20`
résout `kpb-backend:${KPB_IMAGE_TAG:-local}`, et sans lui la commande démarre
une image `:local` absente ou périmée. C'est le « piège du tag perdu » de
`docs/DEPLOYMENT.md:115-117`.

**On observe** :

> **⚠ Cette étape a changé de sens.** Le runbook a été écrit quand il n'y avait
> rien à migrer. Ce n'est plus vrai : la Phase 0 de l'espace « Études en France »
> ajoute `backend/prisma/migrations/20260821120000_eef_interest`. **Le
> `migrate deploy` de l'étape 8 n'est donc PLUS un no-op**, et la ligne
> « Migration Prisma » du § 3 s'applique désormais pleinement.

**On observe** — issue attendue aujourd'hui :

- **exactement une migration `pending`, `20260821120000_eef_interest`.** Lue
  avant d'être appliquée, elle est **purement additive** : `CREATE TABLE
  "EefInterest"`, trois index, une clé étrangère vers `UserProfile` en
  `ON DELETE CASCADE`. Aucun `ALTER` sur une table existante, aucun backfill,
  aucune colonne ajoutée ailleurs — donc rien qui puisse échouer sur les
  données en place. Le seul verrou pris hors de la table neuve est celui que
  Postgres prend brièvement sur `UserProfile` pour valider la clé étrangère.
  Forward-only comme toutes les autres : il n'y a pas de retour de schéma, mais
  il n'y a rien à défaire — une table vide ne dérange personne ;
- `Database schema is up to date!` → alors la prod a **déjà** cette migration, ce
  qui n'est possible que si un déploiement l'a précédée. Vérifier lequel avant de
  continuer ;
- **toute autre** migration `pending` que celle nommée ci-dessus → **la nommer,
  la lire, et seulement ensuite continuer.** C'est un point irréversible que ce
  runbook n'a pas prévu.

**Retour arrière** : aucun. `migrate status` n'applique rien ; `run --rm` détruit
le conteneur.

---

### Étape 2 — Geler le ref et le ledger  *(feu vert propriétaire)*

> **⚠ AVANT de geler quoi que ce soit : le travail « Études en France » doit
> être SUR le ref.** Il vit sur `claude/campus-france-space-98orw9` et aucune
> étape de ce runbook ne fusionne rien. Geler `main` sans lui produirait le pire
> désalignement possible : la build 49 construite à l'étape 4 porte le client
> EEF, le backend déployé à l'étape 8 l'ignore, le contrôle 5 du portail échoue
> à l'étape 9, l'étape 9 bis n'a aucun effet — et on découvre tout cela après
> l'étape 6, qui est le point de non-retour.
>
> Vérification, avant de lire la commande ci-dessous :
>
> ```bash
> git rev-parse --short=12 main
> git ls-tree -r main --name-only | grep -c etudes.en.france   # doit être > 0
> ```
>
> Un `0` signifie que la fusion n'a pas eu lieu. **S'arrêter là.**

```bash
git rev-parse --short=12 main     # → RELEASE_SHA, à geler
```

Puis remplacer le texte d'attente de `docs/release-ledger.md:14`
(« `49` — SHA de la branche release, à remplir le jour J ») par le
`RELEASE_SHA`, en conservant le `49` et le format `- \`49\` — …`.

```bash
flutter test test/release/build_number_test.dart
```

**On observe** : le test passe. Il lit `docs/release-ledger.md`, exige que `48`
reste listé sous **Consommés** et que le `+build` de `pubspec.yaml` (`49`,
`pubspec.yaml:22`) égale le numéro sous **Courant**
(`test/release/build_number_test.dart:17-45`).

**Retour arrière** : entièrement réversible, c'est une édition de dépôt.

---

### Étape 3 — Préflight en `tolerates-old`  *(feu vert propriétaire)*

Actions → **« Release preflight (backend before mobile) »** → Run workflow :

- `ref` = `RELEASE_SHA`
- `backend_coupling` = **`tolerates-old`**

C'est ici que la direction du couplage est **déclarée** pour cette release. Par
défaut l'entrée vaut `requires-new` (`release-preflight.yml:36-42`) ;
`tolerates-old` n'est pas « saute la vérification » : la prod peut être en
retard, mais uniquement sur **l'histoire de ce ref**.

**On observe**, dans le log :

- l'avertissement `production is N commit(s) BEHIND the mobile build, and that is
  the declared intent … The coupled deploy is now OWED: run « Deploy backend
  (VPS) » with scope=full on <ref> once this build is in testers' hands — not
  before` (`release-preflight.yml:114-119`) ;
- le verdict `Xcode Organizer is safe to open. The coupled backend deploy is OWED
  afterwards.` (`release-preflight.yml:141-143`) ;
- `<WEB_URL>/app serves the store-redirect page ✅` (`:121-135`).

Trois issues qui **arrêtent** la bascule :

- `backend is on <SHA> ✅` (`:87-90`) → la prod est déjà sur le ref de release :
  retourner à l'étape 0, la garde est déjà en ligne ;
- `production reports <SHA>, which is not a commit in this repository's fetched
  history` (`:104-107`) ;
- `production (<SHA>) is NOT an ancestor of the mobile build` (`:108-112`) → prod
  divergente ou en avance. Territoire inconnu, on ne distribue pas.

**Retour arrière** : aucun, le workflow est en lecture seule (deux `curl` et un
`git rev-parse`).

---

### Étape 4 — Construire la 49, sans rien distribuer

```bash
# POSTHOG_API_KEY : clé publique phc_… réelle, ou VIDE = PostHog désactivé (état
# valide et documenté). Ne collez JAMAIS « phc_… » littéral : il passe le préflight
# (qui n'exige que le préfixe phc_) mais livre une clé morte — télémétrie de prod
# perdue en silence. L'expansion retombe sur « vide = désactivé », jamais un faux positif.
export POSTHOG_API_KEY="${POSTHOG_API_KEY-}"
flutter build ios --release \
  --dart-define=KPB_APP_ENV=prod \
  --dart-define=KPB_WHATSAPP_NUMBER=+33768674292 \
  --dart-define=POSTHOG_API_KEY="$POSTHOG_API_KEY"
```

(`docs/DEPLOYMENT.md:441-451`.) **Ne pas** ajouter
`--dart-define=KPB_AI_TOOLS_ENABLED=true` : c'est exactement ce que la bascule
interdit ce soir (§1, dernière sous-section).

`flutter build ipa --release` **échoue à l'export sur cette machine** (« Copy
failed », espace dans le chemin du dépôt) — `docs/DEPLOYMENT.md:452-456`. La voie
réelle est Xcode → Product → Archive → Organizer.

Puis, sur l'archive (ne construit rien) :

```bash
scripts/preflight-ios-archive.sh \
  --xcconfig ios/Flutter/Generated.xcconfig \
  --archive-plist <Archive>.xcarchive/Products/Applications/Runner.app/Info.plist
```

**On observe** les cinq assertions de `docs/DEPLOYMENT.md:466-469` :
`FLUTTER_BUILD_NUMBER` / `CFBundleVersion` = **49** ; `DART_DEFINES` décodés
portant `POSTHOG_API_KEY`, `KPB_APP_ENV=prod`, `KPB_WHATSAPP_NUMBER` ;
orientations = portrait ; `UIBackgroundModes` = `remote-notification` ;
`CFBundleLocalizations` = `fr`.

Android, si la piste Play est de la partie : l'AAB signé est produit par la CI
sur un tag `v*` ou par `workflow_dispatch` avec `release_android`
(`.github/workflows/flutter-ci.yml:203-207`, build à `:286`), et le job **assère
que l'AAB est signé par la clé d'upload installée**, empreinte calculée des deux
côtés (`:301-316`). Un artefact de CI n'est pas une distribution.

**Taille du binaire : TBD.** Elle n'est **pas mesurable ici** :
`flutter build apk --release` refuse sans `android/key.properties`, garde
volontaire de `android/app/build.gradle:29`, `:47`. Ne pas inventer ce chiffre.

**Retour arrière** : total. Rien n'a quitté la machine ; supprimer l'archive.

---

### Étape 5 — Téléverser les dSYM, AVANT de distribuer

Le `pbxproj` n'a **aucune** phase `upload-symbols`
(`docs/DEPLOYMENT.md:471-474`). Téléverser les dSYM depuis Organizer, ou via
`FirebaseCrashlytics/upload-symbols`.

**On observe** : Firebase Crashlytics → Paramètres → dSYM : la version `2.1.0
(49)` apparaît comme reçue.

**Pourquoi ici et pas après** : l'étape 10 se vérifie en partie sur des non-fatals
Crashlytics. Sans dSYM, ces traces sont illisibles au moment précis où on en a
besoin.

**Retour arrière** : sans objet (ajout d'un symbole, aucun effet produit).

---

### Étape 6 — POINT DE NON-RETOUR : distribuer la 49  *(feu vert propriétaire)*

Organizer → Distribute → TestFlight. Et/ou Play Console → téléverser l'AAB sur
la piste retenue.

**On observe** :

- TestFlight : la build **49** en « Ready to Test », et le groupe de testeurs
  notifié ;
- Play : la release visible sur la piste ;
- au moins **un appareil réel** sur la 49.

**Retour arrière : AUCUN pour le binaire.** Un téléphone mis à jour ne redescend
pas (`docs/DEPLOYMENT.md:131-137`). Le numéro 49 est consommé à vie
(`docs/release-ledger.md:3-5`, `:7-10`) ; le seul retour est de livrer une **50**.
Suspendre un déploiement Play n'a jamais désinstallé personne.

Après cette étape, inscrire `49` sous **Consommés** dans
`docs/release-ledger.md` lors du prochain relèvement de numéro.

---

### Étape 7 — Attendre que la 49 soit CHEZ les testeurs, pas seulement traitée

Il n'existe **aucune** commande ici. C'est une observation humaine, et c'est le
verrou de toute la bascule : la production ne sait pas distinguer un appareil 48
d'un appareil 49.

**On observe**, sur un appareil réel en 49 :

- la boîte à outils **n'affiche plus** les quatre outils IA (le masquage est
  vivant) ;
- le questionnaire d'orientation se termine et rend des recommandations.

**Ne pas** enchaîner sur l'étape 8 avant ces deux constats. Tant qu'ils
manquent, la bascule ne peut que nuire.

**Retour arrière** : sans objet — attendre est l'action.

---

### Étape 8 — Le déploiement couplé  *(feu vert propriétaire)*

Actions → **« Deploy backend (VPS) »** → Run workflow :

- `ref` = `RELEASE_SHA`
- `scope` = **`full`** (`deploy.yml:44-51`) — il republie aussi `web`, donc pas de
  déploiement `scope=web` séparé à prévoir
- `run_seed` = **`false`** (voir §2)

**On observe**, dans cet ordre, dans le log du run :

| Repère attendu | Ligne |
|---|---|
| `backup ok: <taille> backups/predeploy-…dump` | `deploy.yml:247` — un dump vide arrête le déploiement (`:243-246`) |
| `── migrate ──` | `:249-250` |
| `running: kpb-backend:<RELEASE_SHA>` | `:279` — l'assertion de release (`:272-278`) : « quelque chose répond » n'est pas « la nouvelle version sert » |
| le portail de santé passe (≤ 20 tentatives × 5 s) | `:281-289` |
| `kpb_web recreated with the current nginx.conf` | `:322-326` |
| l'état du schéma imprimé (`prisma migrate status`) | `:330-331` |
| `"source":"database"` sur `/api/catalog/scholarships` | `:360-361` |
| `/app served directly ✅` avec `id1128659292` | `:375-383` |
| `<n> published files served byte-for-byte from this ref ✅` | `:488` — la porte octet-pour-octet, après le portail d'attente de l'arête (`:418-430`) |

Quatre échecs à lire correctement, la porte web les distingue exprès
(`deploy.yml:445-476`) : `000` = **transport**, aucune réponse HTTP (`:446-450`) ;
un statut ≠ 200 = le fichier existe dans le ref et **n'est pas servi**
(`:451-455`) ; « served the HOME PAGE, not itself » = le fichier **n'est pas sur
le VPS**, nginx est retombé par `error_page 404 /index.html` (`:466-470`) ;
« DIFFERENT bytes » = `kpb_web` est **périmé** (`:471-476`). Quatre réparations
différentes, quatre messages différents — ne pas les confondre.

**Retour arrière — RÉVERSIBLE, c'est une image :**

1. *Automatique* : si le portail de santé échoue, le workflow ré-épingle seul le
   tag précédent et publie les 80 dernières lignes de logs de l'API
   (`deploy.yml:291-301`).
2. *Manuel* (le plus rapide, l'image est déjà sur le VPS) :

```bash
ssh "$VPS_USER@$VPS_HOST" \
  "cd $VPS_PATH && KPB_IMAGE_TAG=<PREV_SHA> KPB_BUILD_SHA=<PREV_SHA_COMPLET> \
   docker compose up -d --no-deps api admin"
```

**Les deux variables sont obligatoires.** `KPB_IMAGE_TAG` choisit l'image
(`docker-compose.yml:20`, `:229`) ; `KPB_BUILD_SHA` est ce que lit
`/api/health/version` (`docker-compose.yml:33`,
`backend/src/modules/health/health.controller.ts:54`). L'oublier fait répondre
`sha:"unknown"` à une prod pourtant saine — et le préflight refusera alors de
passer (`release-preflight.yml:80-84`), sur un symptôme qui n'a rien à voir.

**On observe après un retour arrière** : `/api/health/version` renvoie
`PREV_SHA`, et `git merge-base --is-ancestor ce999fb4389c <PREV_SHA>` échoue de
nouveau (la garde n'est plus en ligne).

**Ce que le retour arrière NE défait pas** : une migration appliquée
(`docs/DEPLOYMENT.md:120-124`). Si l'étape 1 a dit « up to date », il n'y en a
pas eu et le retour arrière est complet.

---

### Étape 9 — Prouver que la garde est en ligne, et ce qui n'est pas prouvable

```bash
curl -fsS https://api.kpbeducation.cloud/api/health/version
git merge-base --is-ancestor ce999fb4389c <sha_renvoyé> && echo "garde en prod ✅"
git merge-base --is-ancestor 55551116fe36 <sha_renvoyé> && echo "projection close en prod ✅"
bash scripts/delivery-gate.sh
```

**On observe** : `sha` == `RELEASE_SHA`, les deux `merge-base` réussissent, et
`delivery-gate.sh` imprime `LIV-T14 OK` après ses **cinq** contrôles de
production (six appels `curl`) — le cinquième étant celui qui prouve que le
module EEF est monté, donc tout l'intérêt de l'étape 9 bis
(`scripts/delivery-gate.sh:1-6`, `:11-54`).

**NON PROUVÉ de l'extérieur, et il ne faut pas prétendre le contraire :**

- un `POST` anonyme sur `/api/tools/cv-summary` renvoie **401**, jamais 403 :
  `StudentAuthGuard` passe avant
  (`backend/src/common/guards/student-auth.guard.ts:30`,
  `backend/src/modules/ai/ai-consent.guard.ts:14`). On ne constate donc pas la
  garde par un appel non authentifié ;
- **aucune** route n'expose l'invite envoyée à Groq. La preuve que le nom civil
  ne part plus est l'ascendance du SHA ci-dessus **plus** le test
  `backend/src/modules/orientation/orientation.prompt-privacy.spec.ts` vert en
  CI. Un test unitaire ne prouve pas la production ; le SHA, si.

À savoir aussi : la garde est **fail-open** si la base est injoignable
(`backend/src/modules/ai/ai-consent.service.ts:16-20`, `:42`). Une absence de 403
pendant un incident PostgreSQL ne prouve donc pas que la garde est absente.

**Retour arrière** : aucun, lecture seule.

---

### Étape 9 bis — Allumer la vitrine « Études en France »  *(après le déploiement, jamais avant)*

La build 49 embarque la vitrine **éteinte**. Elle ne s'allume pas toute seule :
c'est `/config/app` qui la déclare, et seule l'image déployée à l'étape 8 sait
lire ces variables. Les poser avant le déploiement n'aurait aucun effet — pas un
effet dangereux, un effet nul, ce qui est plus traître : on croit avoir agi.

**Pourquoi c'est une étape séparée et pas une ligne de l'étape 8.** Parce que
l'étape 8 fait déjà commencer les 403 pour les testeurs restés en 48. Ajouter au
même instant une surface neuve chez ceux qui sont en 49, c'est se priver du
moyen de dire lequel des deux changements a produit ce qu'on observe. Une chose,
puis on regarde, puis la suivante.

**L'étape 9 a déjà fait la moitié du travail.** Le contrôle 5 de
`scripts/delivery-gate.sh` prouve que le module est monté : les clés EEF
présentes dans `/config/app`, et `GET /etudes-en-france/interest` qui répond
**401 et non 404** — la seule façon de distinguer « route gardée » de « module
absent » sans détenir de session étudiante. Si l'étape 9 est passée, il ne reste
ici qu'à poser les variables.

Sur le VPS, dans le `.env` du service `api` :

```bash
KPB_EEF_TEASER_ENABLED=true
KPB_EEF_CAMPAIGN_OPENS_AT=2026-10-01
KPB_EEF_SUSPENDED_COUNTRIES=Niger,NE
# KPB_EEF_CAMPAIGN_CLOSES_AT : NE PAS POSER — les clôtures divergent par pays
# (Maroc 15/11, Rwanda et Maurice 15/12). Une clôture globale ferait manquer la
# campagne à un étudiant marocain. Voir docs/release-ledger.md.
```

puis redémarrer le seul service concerné :

```bash
ssh "$VPS_USER@$VPS_HOST" "cd $VPS_PATH && docker compose up -d --no-deps api"
```

**On observe** :

```bash
curl -fsS "https://api.kpbeducation.cloud/api/config/app" | jq '.features, .eefCampaign'
```

- `features.eefTeaser` → `true` ;
- `eefCampaign.opensAt` → `"2026-10-01"`, **un jour nu, sans heure**. Deux
  lectures à faire de cette ligne :
  - **si elle rend `null`, la variable est mal écrite.** `campaignDay` rend
    `null` sur une valeur illisible plutôt qu'une date de repli, et l'app
    n'annoncera alors AUCUNE date au lieu d'en annoncer une fausse. C'est le
    comportement voulu ; ici c'est le signe qu'il faut relire la ligne du
    `.env` ;
  - **si elle porte une heure**, le déploiement est antérieur au correctif de
    format. Un instant sur le fil se reprojette dans le fuseau du lecteur : une
    valeur écrite en heure de Paris ferait afficher « 30 septembre » à Dakar,
    Bamako, Abidjan, Niamey et Douala. Ne pas basculer : déployer d'abord une
    image portant `campaignDay` ;
- `eefCampaign.suspendedCountries` → `["Niger","NE"]` ;
- `eefCampaign.closesAt` → `null`, et c'est voulu (voir plus haut) ;
- `features.eef` → `false`. **Il doit rester à `false`** : c'est le drapeau de
  l'espace RÉEL, dont le catalogue n'existe pas encore. Le poser à `true`
  retirerait la vitrine tout seul (`app-config.controller.ts` : `eefTeaser` vaut
  `!eef && …`) et afficherait un espace vide.

**Retour arrière** : total et immédiat. Retirer `KPB_EEF_TEASER_ENABLED` ou la
passer à `false`, redémarrer `api`. Aucun store, aucune build. C'est précisément
ce que cette architecture achète.

**Ce qui n'est PAS prouvé par ce `curl`** : qu'un étudiant puisse déclarer son
intérêt. Le `POST /api/etudes-en-france/interest` exige une session étudiant et
la table créée à l'étape 8 — ça se vérifie à l'étape 10, sur un appareil, et
c'est la seule preuve qui compte.

---

### Étape 10 — Vérifier sur un appareil réel en 49

**On observe** :

- boîte à outils : les quatre outils IA absents. Le scanner de documents doit
  rester présent — c'est ce que le masquage M2 annonce garder ouvert
  (`app_config.dart:175-177`), et il ne fait aucun appel réseau ;
- questionnaire d'orientation : il aboutit et affiche des recommandations. Si le
  compte n'a jamais consenti, ces recommandations viennent du **moteur local**
  (`app_controller.dart:846-860`) et un non-fatal
  `reason: 'submitOrientation'` apparaît dans Crashlytics. **C'est le
  comportement attendu, pas une panne.** Si les recommandations n'apparaissent
  pas du tout, ce n'est pas la garde : lire l'erreur ;
- coach IA : inchangé (§1, « Ce que la bascule ne change PAS ») ;
- **vitrine « Études en France »** — la seule preuve qui vaille, parce qu'elle
  traverse toute la chaîne (drapeau servi → écran → session étudiant → table
  créée à l'étape 8) :
  - la carte apparaît sur l'accueil et l'entrée est **en première position** dans
    le tiroir des outils ;
  - elle annonce « À partir du 1er octobre 2026 », suivi de la ligne disant que
    les clôtures varient selon le pays. Si aucune date n'apparaît, c'est
    `KPB_EEF_CAMPAIGN_OPENS_AT` qu'il faut relire, pas l'app ;
  - **déclarer un intérêt, pour de vrai, avec un compte de test.** Le bouton doit
    confirmer, et la ligne doit apparaître dans le back-office
    (`/etudes-en-france`). Un 2xx ne suffit pas : le client traite une réponse
    dont le corps ne dit pas `declared: true` comme un ÉCHEC, donc une
    confirmation à l'écran prouve l'écriture en base ;
  - avec un profil dont le pays de résidence est **le Niger** : la mise en garde
    de suspension **remplace** la date, et ne s'affiche pas à côté d'elle.

**Retour arrière** : celui de l'étape 8 si le constat est mauvais. Pour la seule
vitrine, celui de l'étape 9 bis — une variable, sans toucher au reste.

---

### Étape 11 — Remettre le préflight en `requires-new`

Rien à éditer : `requires-new` est la valeur par défaut de l'entrée
(`release-preflight.yml:36-42`). `tolerates-old` est une **déclaration par
release**, pas un réglage. La prochaine build repasse par le cas normal —
backend d'abord.

**On observe** : au prochain préflight, l'entrée affiche `requires-new` sans
qu'on y touche.

---

### Étape 12 — `KPB_MIN_APP_VERSION` : PAS ce soir  *(feu vert propriétaire, séance séparée)*

Relever `KPB_MIN_APP_VERSION` forcerait toutes les builds antérieures sur un
écran de mise à jour **non refermable**, dont l'unique bouton est grisé si une
URL de store est vide ou morte (`docs/DEPLOYMENT.md:156-183`). C'est le seul
interrupteur à distance du produit, et le relever le soir d'une bascule
mélangerait deux causes de panne.

Le jour où ce sera décidé : poser `KPB_ANDROID_STORE_URL` et `KPB_IOS_STORE_URL`
dans le `.env` du VPS, **constater les deux URLs correctes** dans la réponse
réelle de `curl -fsS https://api.kpbeducation.cloud/api/config/app`, et
seulement ensuite relever la version.

---

## 5. Résumé d'une page

| # | Étape | Feu vert | Retour arrière |
|---|---|---|---|
| 0 | `/api/health/version` → `PREV_SHA` ; la garde est-elle déjà en prod ? | — | lecture seule |
| 1 | `prisma migrate status` (avec `KPB_IMAGE_TAG`) — **une migration attendue**, `20260821120000_eef_interest` | — | lecture seule |
| 2 | geler `RELEASE_SHA` + ledger + `build_number_test` | **oui** | édition de dépôt |
| 3 | préflight `backend_coupling=tolerates-old` | **oui** | lecture seule |
| 4 | `flutter build ios` + `preflight-ios-archive.sh` | — | total |
| 5 | dSYM → Crashlytics | — | sans objet |
| 6 | **distribuer la 49** — point de non-retour | **oui** | **aucun** (→ build 50) |
| 7 | attendre la 49 sur un appareil réel | — | sans objet |
| 8 | `Deploy backend (VPS)` · `scope=full` · `run_seed=false` | **oui** | image (auto + manuel) |
| 9 | prouver la garde par le SHA + `delivery-gate.sh` | — | lecture seule |
| 9 bis | poser les 3 `KPB_EEF_*` + `up -d --no-deps api` | — | **total** (une variable) |
| 10 | vérifier sur appareil 49 — outils IA absents ET vitrine EEF vivante | — | celui de l'étape 8 |
| 11 | préflight de nouveau `requires-new` | — | sans objet |
| 12 | `KPB_MIN_APP_VERSION` — séance séparée | **oui** | hors périmètre |
