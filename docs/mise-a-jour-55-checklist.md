# Mise à jour 2.3.0 (55) — la checklist du 03/10/2026

> **Ce que ce fichier est.** L'ordre exact des opérations pour archiver, vérifier et
> soumettre la 55, avec les commandes. Il **remplace** `docs/mise-a-jour-54-checklist.md` :
> la 54 n'a jamais été envoyée aux boutiques (constat du 03/10/2026, `docs/release-ledger.md`),
> et on envoie **une seule build**, `2.3.0 (55)`, qui en porte tout le contenu plus les filtres
> du catalogue (#314) et les aides à la demande de dossier. Les textes à coller sont dans
> `docs/release-55-store-pack.md` ; la recette appareil dans `docs/device-qa-build54.md` §A et
> §B (toujours valables : lire `2.3.0 (55)` là où la fiche écrit `(54)` ; son §B-filtres couvre
> les filtres du catalogue, #314) **et** `docs/device-qa-build55.md` (les nouveautés : aides,
> retrait, Niger, anglais — pas les filtres).
>
> **État de départ au 03/10/2026** : production = `0641601` (en ligne depuis 17 h 06 UTC),
> `features` = `eef=false`, `eefTeaser=true`, `eefSpace=false`, catalogue publié (10 029
> formations). **Aucune build 2.3.0 n'existe dans les boutiques** : dernier envoi iOS
> `2.2.0 (53)`, dernier bundle Android 53. La branche `feat/eef-aide-dossier-55` n'est pas
> fusionnée : le SHA à archiver n'existe pas encore (étape 0).
>
> **🔒 = étape de distribution.** Archive, AAB importé, IPA envoyée, soumission : **aucune
> ne se fait sans le feu vert explicite du propriétaire, donné pour cette étape.** Le reste
> (lire, comparer, lancer un préflight en lecture seule) se fait librement.
>
> **Ce que la mise à jour ne fait PAS** : ouvrir l'espace, envoyer une notification. Les deux
> viennent après, quand la 55 est en vente et adoptée
> (`docs/runbook-ouverture-espace-reel.md`).

## Ce qui change par rapport à la checklist de la 54

- **L'étape « une décision avant tout » disparaît** : la 55 part espace fermé (XC-03, état A),
  décidé le 03/10. Elle est remplacée par l'étape 0 (ce qui doit être vrai avant d'archiver).
- **Version attendue : `2.3.0 (55)`** partout (`pubspec.yaml`, les deux préflights).
- **`backend_coupling=tolerates-old`** au préflight de release, et non `requires-new` : le SHA
  de release ne sera pas celui que la production sert (`0641601`), et la 55 tolère un backend
  plus ancien (`docs/release-ledger.md`, « Couplage backend de la 55 »).
- **L'AAB du 02/10 (54) ne s'importe pas** (étape 2).
- La recette ajoute `docs/device-qa-build55.md` (aides, retrait, Niger, anglais) et le
  §B-filtres de `docs/device-qa-build54.md` (les quatre boutons de filtre du catalogue).
- L'étape 0 contrôle qu'aucune dépendance native ni aucun manifeste n'a changé depuis la
  production, et l'étape 1 crée la copie propre de `RELEASE` **avant** le préflight de l'AAB
  (le script épingle la version attendue du commit où on le lance).

## 0. Ce qui doit être vrai avant d'archiver

Rien n'est à décider ici ; c'est de l'état à constater. Dans la suite, **`RELEASE`** = le SHA
complet (40 caractères) de `main` au moment d'archiver.

1. **La branche `feat/eef-aide-dossier-55` est fusionnée dans `main`** (le bouton « Demander de
   l'aide », la ligne d'aide sous les filtres, l'aide « Préparer mon dossier », le lien
   « Me retirer » dans la feuille) **et la préparation de la 55 aussi** (`version: 2.3.0+55`,
   registre, préflights, ces documents). Les deux par PR vers `main`.
2. **`docs/device-qa-build55.md` et `docs/analytics-event-contract.md` (avec ses nouveaux
   événements) sont sur `main`.** Ils arrivent avec la branche d'aide : **la fusionner AVANT la
   préparation de la 55 (ou dans la même PR)**. Dans l'ordre inverse, les renvois de
   `docs/device-qa-build54.md`, de cette checklist, du pack et du registre pointent vers un
   fichier absent de `main`.
3. Les quatre CI sont vertes **sur le SHA exact** : Backend CI, Admin CI, Flutter CI,
   Release safeguards CI (exécutions `push` de `main`, GitHub → Actions, filtrer sur le commit).
4. `RELEASE` = le dernier commit de `main`, et **plus rien ne se fusionne sur `main`** jusqu'à la
   fin de l'étape 4 : le workflow Flutter CI de l'étape 2 partage son groupe de concurrence avec
   les exécutions de `main` (le lancement serait annulé), et le préflight vérifie les CI du SHA
   exact.
5. **Ni dépendance native ni manifeste n'a changé depuis la production.** Un
   `pubspec_overrides.yaml` temporaire (non suivi), utilisé en local, remplace les
   `dependency_overrides` de `pubspec.yaml` — qui épinglent `connectivity_plus` en 6.x et
   `device_info_plus` en 11.x tant que le Xcode du CI est trop ancien — et réécrit
   `pubspec.lock`. La relecture du 03/10 l'a relevé dans le dossier de travail de la branche
   d'aide (`connectivity_plus` 6.1.5 → 7.3.1, `device_info_plus` 11.5.0 → 12.4.0, deux plugins
   natifs) : un `git add -A` les aurait embarqués. Aucun test du dépôt ne le garde
   (`test/release` ne lit `pubspec.lock` que pour `webview_flutter`). Le commit de la branche
   observé le 03/10 (`93a823c`) ne touche ni `pubspec.*`, ni `ios/`, ni `android/` ; le risque est
   dans ce qu'on ajoute au moment de committer. Les commandes ci-dessous le détectent, et
   **elles font foi pour les phrases « ni dépendance, ni manifeste » du §6 et du pack (§3)** :
   à vérifier sur le SHA final, pas à croire. Si l'une d'elles affiche autre chose que
   l'attendu, **ne pas archiver** : faire restaurer `pubspec.lock` et supprimer
   `pubspec_overrides.yaml` par le porteur de la branche, puis recommencer l'étape 0.

```bash
git fetch origin
RELEASE=$(git rev-parse origin/main) && echo "$RELEASE"
git show "$RELEASE:pubspec.yaml" | grep '^version:'        # version: 2.3.0+55
git log --oneline 0641601.."$RELEASE"                        # la branche d'aide et la préparation y figurent

# Ni dépendance native ni manifeste n'a bougé depuis la production :
git diff --stat 0641601 "$RELEASE" -- pubspec.lock ios/Podfile.lock ios/Runner/Info.plist \
  ios/Runner/PrivacyInfo.xcprivacy android/app/src/main/AndroidManifest.xml android/app/build.gradle   # ne doit RIEN afficher
git ls-tree -r --name-only "$RELEASE" | grep -c '^pubspec_overrides.yaml$'   # 0 : le fichier ne doit pas être suivi
git diff -U0 0641601 "$RELEASE" -- pubspec.yaml | grep '^[+-]' | grep -v '^[+-]#' | grep -v '^+++\|^---'
#   exactement deux lignes : -version: 2.3.0+54  puis  +version: 2.3.0+55
git show "$RELEASE:pubspec.lock" | grep -A7 -E '^  (connectivity_plus|device_info_plus):$' | grep '^    version:'
#   "6.1.5" puis "11.5.0" (les épinglages de pubspec.yaml)
```

## 1. Vérifications de départ (5 min)

```bash
# Le backend de production est-il bien celui que la 55 suppose ?
curl -fsS https://api.kpbeducation.cloud/api/health/version      # sha : commence par 0641601
git merge-base --is-ancestor 0641601 "$RELEASE" && echo "production = ancêtre de RELEASE : OK"
git diff --stat 0641601 "$RELEASE" -- backend admin docker-compose.yml   # ne doit RIEN afficher
# L'espace est-il bien fermé ?
curl -fsS https://api.kpbeducation.cloud/api/config/app | jq '.features | {eef, eefTeaser, eefSpace}'   # false, true, false
```

- Si `git diff` affiche quelque chose, **le backend de la release n'est pas en production** : le
  couplage `tolerates-old` ne dit plus la vérité. Ne pas continuer : déployer (`deploy.yml`,
  `scope=full`, sur `RELEASE`) puis revoir l'étape 4 (`requires-new` redevient possible).
- Si la production ne répond plus `0641601…` (un autre déploiement a eu lieu), relire
  `docs/release-ledger.md` avant toute chose : le préflight exige que la production soit un
  **ancêtre** de `RELEASE`, jamais en avance (un run du 02/10 a échoué ainsi).
- Sur le Mac, avant l'étape 3 :

```bash
flutter --version          # 3.44.1, comme le CI
python3 --version          # doit afficher une version
xcodebuild -version
```

  Observé le 03/10/2026 sur le Mac où ce document a été préparé : `/usr/bin/python3` répondait
  « You have not agreed to the Xcode license agreements. Please run 'sudo xcodebuild -license' »
  (alors que `xcodebuild -version` répondait « Xcode 27.0 »). `scripts/preflight-ios-archive.sh`
  appelle `python3` : sans licence acceptée, il échouerait. Le même défaut bloque `flutter test`
  (le hook natif du paquet `objective_c` appelle `xcrun` : « Building native assets failed ») et
  bloquerait `flutter build ios`. **Accepter la licence est une action du propriétaire, dans un
  Terminal** (`sudo xcodebuild -license`) ; elle n'a pas été faite.

**Copie propre de `RELEASE`** — à créer maintenant : le préflight de l'AAB (étape 2, point 5) et
l'archive iOS (étape 3) se font **dans cette copie**, pas dans le dossier de travail habituel. Les
deux scripts de préflight épinglent la version attendue du commit où on les lance : depuis un
dossier resté à `0641601` (`EXPECTED_VERSION_CODE="54"`), `scripts/preflight-android-aab.sh`
rejetterait l'AAB 55 (« versionCode différent de 54 »).

```bash
git worktree add ../kpb-release-55 "$RELEASE" && cd ../kpb-release-55
test "$(git rev-parse HEAD)" = "$RELEASE" && git status --porcelain     # rien à afficher
```

## 2. Android — l'AAB signé (≈ 15 min, sans toi) 🔒

1. Actions → **Flutter CI** → *Run workflow* → branche `main`, cocher **`release_android`**.
   **Ne pas pousser de tag `v2.3.0`** : l'exécution sur tag est rouge par construction, et le
   préflight lit la dernière exécution du commit. Vérifier en tête de l'exécution que le commit
   est bien `RELEASE`.
2. Dans le journal « Verify App Bundle signature », relever l'empreinte SHA-256 et la comparer à
   Play Console → Intégrité de l'app → **certificat de la clé d'importation**. Le CI ne compare
   qu'à son propre keystore : c'est cette comparaison-là qui prouve que Play acceptera le bundle.
3. Le journal « Run strict Android store-artifact preflight » doit finir par
   `Préflight Android OK — 2.3.0 (55), com.karatou.android, SDK 36, …`.
4. Télécharger l'artefact **`app-release-android-aab`** de **cette** exécution.
   **Ne pas utiliser l'AAB du run 36945000021** (02/10, commit `47a1295`) : c'est la 54, sans les
   nouveautés de la 55, et Play l'accepterait (54 > 53) — l'importer enverrait une build
   obsolète. Aucun envoi vers Play n'est fait par le CI : c'est le propriétaire qui importe
   (étape 5).
5. *Recommandé* — recouper localement, **depuis la copie propre `../kpb-release-55`** (étape 1),
   avec l'empreinte **de Play Console** (le script ne rouvre aucun keystore) :
   ```bash
   # JDK 17+ requis (JAVA_HOME) ; bundletool-all 1.18.1, la version qu'utilise le CI :
   # https://github.com/google/bundletool/releases/download/1.18.1/bundletool-all-1.18.1.jar
   BUNDLETOOL_JAR=/chemin/bundletool-all-1.18.1.jar scripts/preflight-android-aab.sh \
     --aab app-release.aab --expected-cert-sha256 "<empreinte SHA-256 de Play Console>"
   # → « Préflight Android OK — 2.3.0 (55), … certificat Play concordant, AD_ID absent. »
   ```

## 3. iOS — l'archive (sur le Mac) 🔒

Partir de la **copie propre** de `RELEASE` créée à l'étape 1 : le dossier de travail habituel
contient du travail en cours (`git status`), et le contrôle ci-dessous exige une arborescence vide.

```bash
cd ../kpb-release-55
test "$(git rev-parse HEAD)" = "$RELEASE" && git status --porcelain     # rien à afficher
flutter pub get && (cd ios && pod install)
read -rs POSTHOG_API_KEY && export POSTHOG_API_KEY      # la vraie clé phc_ du projet (jamais dans le dépôt, jamais collée dans un chat)
flutter build ios --release \
  --dart-define=KPB_APP_ENV=prod \
  --dart-define=KPB_WHATSAPP_NUMBER=+33768674292 \
  --dart-define=POSTHOG_API_KEY="$POSTHOG_API_KEY"
grep -E '^FLUTTER_BUILD_(NAME|NUMBER)=' ios/Flutter/Generated.xcconfig   # FLUTTER_BUILD_NAME=2.3.0 / FLUTTER_BUILD_NUMBER=55
```

- **Aucun autre `flutter build` ni `flutter run` ensuite** (ils réécrivent
  `Generated.xcconfig`). Ne pas ajouter `KPB_API_BASE_URL` ni `KPB_EEF_SPACE_ENABLED`.
- Ouvrir Xcode avec un PATH propre (un « Copy failed » est le conflit `rsync` / PATH) :
  `env PATH="/usr/bin:/bin:/usr/sbin:/sbin" /Applications/Xcode.app/Contents/MacOS/Xcode ios/Runner.xcworkspace`
  → *Any iOS Device* → **Product → Archive**. Le journal doit montrer
  « Successfully submitted symbols » (dSYM).
- Contrôler l'archive :
  ```bash
  A="<chemin>.xcarchive/Products/Applications/Runner.app"
  scripts/preflight-ios-archive.sh --xcconfig ios/Flutter/Generated.xcconfig --archive-plist "$A/Info.plist"
  strings "$A/Frameworks/App.framework/App" | grep -c '^phc_'     # doit afficher 1
  ```
  Signature automatique : l'échec attendu à ce stade est « n'est pas signée avec un
  certificat Apple Distribution ». Tout échec **avant** celui-là (version, build, clé PostHog,
  orientations) : recommencer le `flutter build ios`.
- Organizer → *Distribute App* → *Custom* → *App Store Connect* → *Export*, puis :
  ```bash
  unzip -q Runner.ipa -d ipa
  scripts/preflight-ios-archive.sh --xcconfig ios/Flutter/Generated.xcconfig --app ipa/Payload/Runner.app
  # → « Préflight iOS OK — 2.3.0 (55) »
  ```
  Envoyer **cette** IPA par Transporter — seulement avec le feu vert du propriétaire.
- Rejets connus : **90474** (un bundle iPad doit déclarer les quatre orientations) et **90101**
  (on ne retire pas l'iPad d'une app publiée) — le préflight les contrôle ; **ITMS-90062**
  (version marketing non supérieure à celle en vente) ne se produit pas : 2.3.0 > 2.2.0.

## 4. Préflight de release (≈ 5 min, lecture seule)

Actions → **Release preflight (backend before mobile)** — ou, en ligne de commande :

```bash
gh workflow run release-preflight.yml --ref main \
  -f ref="$RELEASE" -f backend_coupling=tolerates-old -f require_24h_stability=true
```

Les trois champs du workflow :

- `ref` = `RELEASE` (le SHA complet, pas `main`) ;
- `backend_coupling` = **`tolerates-old`**. `requires-new` exigerait que la production serve
  `RELEASE` (12 premiers caractères), ce qui n'est pas le cas. `tolerates-old` exige que la
  production soit un ancêtre de `RELEASE` (vérifié à l'étape 1) et laisse un avertissement
  « le déploiement couplé est dû » : il ne l'est pas ici, `backend/` n'ayant pas changé depuis
  `0641601` ;
- `require_24h_stability` = `true`. Le backend a été redéployé le 03/10 à 17 h 06 UTC : une
  sonde ratée pendant ce redéploiement peut faire échouer l'étape 24 h jusqu'au 04/10 vers
  17 h 06 UTC. Si **seule** cette étape échoue, relancer avec `false` : la dérogation est
  journalisée.

Ce que le workflow vérifie (il échoue, il ne devine pas) : le SHA est atteignable depuis
`main` ; les quatre CI sont vertes sur ce SHA ; `VPS_HEALTH_URL` répond ; la page `/app` sert la
redirection vers la fiche de l'App Store (`id1128659292`) ; la porte de livraison publique
passe ; un **heartbeat de sauvegarde** de moins de 8 h ; un **exercice de restauration isolé**
de moins de 90 jours ; 24 h de sondes de disponibilité.

Deux pièges : le heartbeat de sauvegarde ne se rafraîchit pas à la main — il tourne toutes les
6 h à h+23 UTC, attendre le prochain si besoin ; l'exercice de restauration doit dater de moins
de 90 jours (sinon *Backup restore drill*, exécution réelle, avec l'approbation de
l'environnement de production).

## 5. Recette sur appareil (TestFlight + Play Internal) 🔒

Installer **la build envoyée** impose de l'envoyer d'abord aux pistes de test : IPA par Transporter
→ TestFlight ; AAB → Play Console → **Tests internes**. Ces deux envois sont des étapes de
distribution : feu vert du propriétaire.

1. Installer la build depuis TestFlight / Play Internal (pas un build de debug : le contrat de
   soumission exige que la preuve vienne de l'artefact). L'app n'affiche pas sa version : lire
   `2.3.0 (55)` dans TestFlight, et `versionCode` 55 côté Android (A1 de la fiche).
2. Dérouler le **§A** de `docs/device-qa-build54.md` (vitrine, Niger, déclaration, plus de « % »,
   lettres IA, notifications, CGU, état A étanche…).
3. *Facultatif mais recommandé* — **fenêtre de recette du hub (voie 2)** : tant que la 55 n'est
   que chez les testeurs, `vps-ops` → `eef-space-on` (simulation, puis application) n'ouvre le hub
   qu'à eux (les 49 à 53 ignorent `eefSpace`). Dérouler le §B, le §B-filtres (les quatre boutons de
   filtre du catalogue, #314) et le §B-aide de `docs/device-qa-build54.md`, puis
   **`docs/device-qa-build55.md`** (aides à la demande de dossier, « Me retirer », Niger,
   anglais). Le cas « repli » de Filtres-8 (route `/cities` indisponible) ne se teste pas contre
   la production : voie 1 ou voie 3 du §B. Tuer et relancer l'app après chaque bascule.
   **Puis `eef-space-off`**, et vérifier `eefSpace: false` (commande de l'étape 1) **avant**
   de soumettre **et avant toute promotion Play vers la production**.
4. Un ✗ non résolu bloque la soumission (§D de la fiche).

## 6. Consoles

| Quoi | Où | Note |
|---|---|---|
| Questionnaire d'âge (App Store **et** IARC) | `store-listing-copy.md` §9 (D2) | Garder la preuve des réponses. D2 n'est pas tranchée dans le dépôt |
| App Privacy / Data Safety | `CONSOLE_ANSWERS.md` | **Inchangés pour la 55 sous réserve** : les aides n'ouvrent que WhatsApp avec un message préécrit, et les filtres n'envoient rien de nouveau. **À vérifier sur le SHA final** : ni dépendance ni manifeste n'a changé (les commandes de l'étape 0, point 5, ne doivent rien afficher — sinon « inchangés » tombe) ; le message des nouveaux boutons (il nomme la formation, l'université, la ville, les filtres posés ou l'outil : pack §3, point 1) ; les nouveaux événements (`docs/analytics-event-contract.md`) |
| Contrôles qui dépendent de l'artefact (clé `phc_` = 1, `AD_ID` absent) | `CONSOLE_ANSWERS.md`, en-tête | L'en-tête dit « refaire sur l'archive 54 » : **lire 55** — les refaire sur l'archive et l'AAB de la 55 avant de changer l'en-tête |
| Finalités « Marketing » (XC-06) | `CONSOLE_ANSWERS.md` §0quater | La politique publiée dit que l'équipe commerciale lit les déclarations : à déclarer, sauf avis contraire du juridique (**non tranché dans le dépôt**) |
| Play → *Government apps* : « non » ; non-affiliation en fin de description longue | Pack §4 | |
| Compte de démonstration étudiant, **exclu des listes d'appel** | Pack §3 | La note de revue le promet |

## 7. Soumettre 🔒

- **App Store** : créer la version **2.3.0** et y rattacher la build 55 (une fois traitée par
  TestFlight) ; « Nouveautés » = pack §2.1 ; *Notes for Review* = bloc de `store-listing-copy.md`
  §7.1 **+ l'addendum du pack §3** (après avoir contrôlé ses points) ; publication progressive.
  **Compter les caractères du texte final avant de coller : le champ est limité à 4 000
  caractères (à vérifier à la saisie dans App Store Connect).** Mesuré le 03/10 : le bloc §7.1
  fait 2 923 caractères (marqueurs `<ADRESSE>` et `<MÉTHODE…>` non remplacés), l'addendum 1 025,
  soit 3 950 avec la ligne qui les sépare ; l'adresse du compte de démonstration et sa méthode de
  lecture du code s'y ajoutent (pack §3, point 4). Revue accélérée : inutile en état A (l'espace
  reste fermé après l'approbation).
- **Google Play** : production par paliers 5 / 20 / 100 % ; notes de version = pack §2.1 (bloc
  Google Play).
- Avant d'appuyer : `curl … | jq '.features | {eef, eefTeaser, eefSpace}'` → `false, true, false`.
- Conserver les preuves du pack §5 (sorties des préflights, `phc_` = 1, dSYM, questionnaires,
  captures **sans** hub ni catalogue).

## 8. Après la soumission — ne pas faire tout de suite

- `eef-space-on` pour tous : seulement quand la 55 est **en vente sur les deux stores et
  adoptée** (seuil d'adoption à fixer : `docs/ouverture-espace-eef.md` § 6) ; les corrections de
  procédure sont déjà appliquées et le juridique est tranché.
- L'annonce d'ouverture : après l'ouverture seulement, vers **tous les étudiants, Niger compris**,
  texte neutre (`docs/ouverture-espace-eef.md` § 4). L'audience `eef_interest` reste inutilisée.
  **L'outillage dit encore le contraire** : l'agent `kpb-notifications` ordonne d'exclure les pays
  suspendus et `kpb_draft_notification` avertit si on ne le fait pas. L'avertissement est attendu
  (décision du 03/10) ; lui donner la consigne explicitement et ne pas ajouter `exceptCountries`
  (`docs/ouverture-espace-eef.md` § 4, « Ce que l'outillage dit encore »).
- **`KPB_MIN_APP_VERSION=2.3.0`** : jamais avant que la 2.3.0 soit réellement téléchargeable sur
  les deux stores et déployée à 100 % (elle enferme sinon tout le monde derrière un écran sans
  sortie) ; en pratique, pas pour cette build.
- `recommended-version-set` : sans effet sur la 53 (elle ne lit pas la clé) ; utile pour les
  passages **après** la 55.
- Ne jamais poser `KPB_EEF_ENABLED=true` (il retire la vitrine aux builds 49 à 53).
- Aucun tag `v2.3.0`, aucune notification.
