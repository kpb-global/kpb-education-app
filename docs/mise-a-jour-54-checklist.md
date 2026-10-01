# Mise à jour 2.3.0 (54) — la checklist du 02/10/2026 au matin

> **Ce que ce fichier est.** L'ordre exact des opérations pour archiver, vérifier et
> soumettre la 54, avec les commandes. Les textes à coller sont dans
> `docs/release-54-store-pack.md` ; la recette appareil dans
> `docs/device-qa-build54.md`. **État de départ vérifié le 01/10 à 23 h 05** :
> `main` = `33c5a51`, production = `33c5a51`, catalogue publié (10 029), espace
> fermé (`eefSpace=false`).
>
> **Ce que la mise à jour ne fait PAS** : ouvrir l'espace, envoyer une notification.
> Les deux viennent après, quand la 54 est en vente et adoptée
> (`docs/runbook-ouverture-espace-reel.md`).

## 0. ~~Une décision avant tout~~ — fait le 01/10 : #302 fusionnée, backend déployé

**Rien à faire à cette étape.** #302 (fusionnée le 01/10 à 23 h 40) a ajouté à la 54 :

- **#287** — plus aucun pourcentage d'admission dans l'app (les « 40 % » de repli des
  Universités et de Comparer, les « 74 % » de la fiche formation) ; un palier « match
  profil » calculé, absent sans profil. Puce de ville du Logement lisible.
- **#288** — délai de 90 s sur la génération IA (lettres, CV, entretien…) au lieu de
  15 s : la personnalisation des lettres n'échoue plus sur « vérifiez votre
  connexion ». Côté serveur : 503 au lieu d'un modèle vierge, raisonnement caché
  coupé.
- le filtre du cycle santé renommé « Études de santé » (le badge garde « Accès
  santé »).

Le backend a été déployé sur le dernier commit de `main` : la production sert
normalement **le commit à archiver** (à vérifier à l'étape 1). Notes de version : pack
§2.1 **tel quel**. #287 et #288 ont été fermées (contenu intégré par #302).

Dans la suite, **`RELEASE`** = le SHA complet de `main` au moment d'archiver.

## 1. Vérifications (5 min)

```bash
git fetch origin && git rev-parse origin/main          # → RELEASE
curl -fsS https://api.kpbeducation.cloud/api/health/version   # sha = 12 premiers caractères de RELEASE (sinon : coupling tolerates-old)
curl -fsS https://api.kpbeducation.cloud/api/config/app | jq '.features | {eef, eefTeaser, eefSpace}'   # false, true, false
```

GitHub → Actions : sur **ce commit exact**, **Backend CI**, **Admin CI**, **Flutter CI**
et **Release safeguards CI** sont verts (exécutions `push` de `main`).

## 2. Android — l'AAB signé (≈ 15 min, sans toi)

1. Actions → **Flutter CI** → *Run workflow* → branche `main`, cocher
   **`release_android`**. **Ne pas pousser de tag `v2.3.0`** : l'exécution sur tag est
   rouge par construction, et le préflight lit la dernière exécution du commit.
   Ne rien fusionner sur `main` pendant ce temps (même groupe de concurrence : le
   lancement serait annulé).
2. Dans le journal « Verify App Bundle signature », relever l'empreinte SHA-256 et la
   comparer à Play Console → Intégrité de l'app → **certificat de la clé
   d'importation**. Le CI ne compare qu'à son propre keystore.
3. Télécharger l'artefact **`app-release-android-aab`**. Aucun envoi vers Play n'est
   fait par le CI : c'est toi qui l'importes (étape 6).

## 3. iOS — l'archive (sur le Mac)

```bash
git checkout main && git pull --ff-only
test "$(git rev-parse HEAD)" = "<RELEASE>" && git status --porcelain     # rien à afficher
flutter --version                                       # 3.44.1, comme le CI
flutter pub get && (cd ios && pod install)
read -rs POSTHOG_API_KEY && export POSTHOG_API_KEY      # la vraie clé phc_ du projet
flutter build ios --release \
  --dart-define=KPB_APP_ENV=prod \
  --dart-define=KPB_WHATSAPP_NUMBER=+33768674292 \
  --dart-define=POSTHOG_API_KEY="$POSTHOG_API_KEY"
grep -E '^FLUTTER_BUILD_(NAME|NUMBER)=' ios/Flutter/Generated.xcconfig   # 2.3.0 / 54
```

- **Aucun autre `flutter build` ni `flutter run` ensuite** (ils réécrivent
  `Generated.xcconfig`). Ne pas ajouter `KPB_API_BASE_URL` ni `KPB_EEF_SPACE_ENABLED`.
- Ouvrir Xcode avec un PATH propre :
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
  certificat Apple Distribution ». Tout échec **avant** celui-là : recommencer le
  `flutter build ios`.
- Organizer → *Distribute App* → *Custom* → *App Store Connect* → *Export*, puis :
  ```bash
  unzip -q Runner.ipa -d ipa
  scripts/preflight-ios-archive.sh --xcconfig ios/Flutter/Generated.xcconfig --app ipa/Payload/Runner.app
  # → « Préflight iOS OK — 2.3.0 (54) »
  ```
  Envoyer **cette** IPA par Transporter.

## 4. Préflight de release (≈ 5 min)

Actions → **Release preflight** :

- `ref` = `<RELEASE>` (le SHA complet, pas `main`) ;
- `backend_coupling` = **`requires-new`** si la production sert `RELEASE` (étape 1),
  sinon **`tolerates-old`** (la 54 tolère un backend plus ancien) ;
- `require_24h_stability` = `true`. Si **seule** l'étape de disponibilité 24 h échoue
  (backend redéployé il y a moins de 24 h), relancer avec `false` : la dérogation est
  journalisée.

Deux pièges : le **heartbeat de sauvegarde** (≤ 8 h) ne se rafraîchit pas à la main
— il tourne toutes les 6 h à h+23 UTC, attendre le prochain si besoin ; l'**exercice de
restauration** doit dater de moins de 90 jours (sinon *Backup restore drill*, exécution
réelle, avec l'approbation de l'environnement de production).

## 5. Recette sur appareil (TestFlight + Play Internal)

1. Installer **la build envoyée** (TestFlight ; Play → Tests internes avec l'AAB de
   l'étape 2).
2. Dérouler le **§A** de `docs/device-qa-build54.md` (vitrine, Niger, déclaration,
   plus de « % », lettres IA, notifications, CGU, état A étanche…).
3. *Facultatif mais recommandé* — **fenêtre de recette du hub (voie 2)** : tant que la
   54 n'est que chez les testeurs, `vps-ops` → `eef-space-on` (simulation, puis
   application) n'ouvre le hub qu'à eux. Dérouler le §B et le §B-aide (« médecine »,
   badge « Accès santé », cartes WhatsApp, Niger). Tuer et relancer l'app après chaque
   bascule. **Puis `eef-space-off`**, et vérifier `eefSpace: false` (commande de
   l'étape 1) **avant** de soumettre.
4. Un ✗ non résolu bloque la soumission (§D de la fiche).

## 6. Consoles

| Quoi | Où | Note |
|---|---|---|
| Questionnaire d'âge (App Store **et** IARC) | `store-listing-copy.md` §9 (D2) | Garder la preuve des réponses |
| App Privacy / Data Safety | `CONSOLE_ANSWERS.md` | **Inchangés pour la 54** : les cartes d'aide n'ajoutent aucun type de donnée |
| Finalités « Marketing » (XC-06) | `CONSOLE_ANSWERS.md` §0quater | La politique publiée dit que l'équipe commerciale lit les déclarations : à déclarer, sauf avis contraire du juridique |
| Play → *Government apps* : « non » ; non-affiliation en fin de description longue | Pack §4 | |
| Compte de démonstration étudiant, **exclu des listes d'appel** | Pack §3 | La note de revue le promet |

## 7. Soumettre

- **App Store** : « Nouveautés » = pack §2.1 ; *Notes for Review* = bloc de
  `store-listing-copy.md` §7.1 **+ l'addendum du pack §3** ; publication progressive.
  Revue accélérée : inutile en état A (l'espace reste fermé après l'approbation).
- **Google Play** : production par paliers 5 / 20 / 100 % ; notes de version = pack
  §2.1 (bloc Google Play).
- Conserver les preuves du pack §5 (sorties des préflights, `phc_` = 1, dSYM,
  questionnaires, captures **sans** hub ni catalogue).

## 8. Après la soumission — ne pas faire tout de suite

- `eef-space-on` pour tous : seulement quand la 54 est **en vente et adoptée** et que
  les 7 questions de procédure sont tranchées (`docs/eef-dossier-relecture-procedures.md`).
- L'annonce (`eef_interest` ou `all_students_except_countries` + `eef_suspended`,
  route `/etudes-en-france`) : après l'ouverture seulement.
- `recommended-version-set` : utile pour les passages 54 → 55, sans effet sur la 53.
