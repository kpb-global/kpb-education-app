# Phase 1 Stability Smoke Checklist

Use this checklist for every release candidate before promotion to production.
Run on at least one physical Android device and one physical iOS device.

## Pre-flight

- Install latest release candidate build.
- Confirm backend target points to production or staging as intended.
- Ensure at least one test user has existing cases and one test user has no cases.
- Prepare one push notification payload for `/cases/{id}` and one for `/search`.

## ⚠️ Android package visibility — NOT substitutable by a test

**Run this on a physical Android 13 or newer. No unit or widget test can stand
in for it**, because package visibility only exists on a real device.

Why it matters: `targetSdkVersion` is 36. From API 30, an app only "sees" the
packages it declares, and `canLaunchUrl` returns false for anything undeclared —
*even with a browser installed*. Neither our manifest nor `url_launcher_android`
declared a VIEW intent. The `<queries>` block in
`android/app/src/main/AndroidManifest.xml` fixes the cause and
`lib/app/core/utils/external_link.dart` makes the failure visible instead of
mute, but only a device proves it.

- [ ] Open a scholarship whose `applicationUrl` is a valid `https://…` and tap
      **« Formulaire officiel »** → the browser **must** open.
      → executable protocol: **D1**.
- [ ] Tap any WhatsApp CTA → WhatsApp **must** open. This is the app's only
      monetization path; there is deliberately no in-app payment.
      → executable protocol: **D2**.
- [ ] Same CTA on a phone **without** WhatsApp → a visible fallback, never
      silence. → executable protocol: **D3**.
- [ ] Record the phone model and Android version in the ticket.

If either is a silent no-op, or shows "impossible d'ouvrir WhatsApp" on a device
that clearly has WhatsApp, the `<queries>` block did not take effect — stop and
investigate before shipping.

## Critical flows

### 1) App bootstrap and onboarding

- Launch app from cold start.
- Verify no crash or red screen at startup.
- Verify intro/onboarding renders and can complete end-to-end.

### 2) Auth and profile access

- Open login/register/forgot-password flows.
- Verify form submission and validation do not dead-end.
- Verify profile tab opens from home avatar action.

### 3) Cases stability states

- Cases with active sync and empty data -> skeleton loading appears.
- Cases with sync failure and empty data -> error state with retry appears.
- Cases with existing data + transient sync failure -> existing list remains visible.

### 4) Case creation and detail navigation

- Create case from Cases tab CTA.
- Create case from scholarship CTA (`/new-case`).
- Open case detail from list item tap.

### 5) Push/deep-link route handling

- Trigger push route `/cases/{id}` -> opens matching case detail.
- Trigger push route `/search` -> opens search screen.
- Trigger legacy route `/cases/create` -> opens case-create route (`/new-case`).
- Trigger unsupported route -> app remains stable (no crash).

### 6) Offline/reconnect resilience

- Disable network and relaunch app.
- Verify app remains navigable and does not crash.
- Re-enable network and verify sync recovers without app restart.

### 7) Auth round-trip on a real device (LIV-T13)

- [ ] Google OAuth: tap Continuer avec Google → complete the account picker →
      land back in the app, signed in. A bounce to the browser that never
      returns is a fail. → executable protocols: **D4** (Android), **D5** (iOS).
- [ ] Magic link / OTP: request a code, wait for the mail/SMS, enter it.
      (Custom SMTP — IRR-T6 — is a prerequisite if OTP 429s.)

### 8) Push with the app killed (LIV-T13)

- [ ] Force-quit the app. Send a test push to `/cases/{id}` from OneSignal.
      Tapping the notification must cold-start the app on that case, not on
      a blank home. → executable protocol: **D6**; the `kpb://` deep link that
      follows is **D7**.

### 9) Camera invite, accept and decline (LIV-T13)

- [ ] Profile photo: tap to change, **Allow** camera → capture works.
- [ ] On a second device (or after resetting the permission): tap to change,
      **Don't Allow** → the app must show a visible failure, not a silent
      no-op.

---

# Partie D — Protocoles appareil (aucun test ne peut les remplacer)

> Rédigé en français, contrairement au reste du document : ces protocoles sont
> exécutés par le propriétaire ou un testeur qui n'a pas écrit le code, et
> chaque symptôme d'échec doit être lisible sans relire le dépôt. Chaque
> affirmation porte sa référence `fichier:ligne`.

Neuf protocoles, trois familles de risque :

| Id | Objet | Plateforme |
|----|-------|-----------|
| D1 | « Formulaire officiel » ouvre le navigateur | Android 13+ |
| D2 | CTA WhatsApp ouvre WhatsApp (WhatsApp **présent**) | Android 13+ |
| D3 | Le même CTA quand WhatsApp est **absent** : repli visible, pas de silence | Android 13+ |
| D4 | Aller-retour OAuth Google | Android |
| D5 | Aller-retour OAuth Google | iOS |
| D6 | Notification reçue **application tuée** → bonne route | Android + iOS |
| D7 | Lien profond `kpb://` (dont celui porté par une notification) | Android + iOS |
| D8 | Pages légales : les liens ouvrent bien `kpbeducation.cloud` | Android + iOS |
| D9 | Surfaces masquées **absentes** de l'écran, pas grisées | Android + iOS |

## D0 — Préconditions de build, communes à D1–D9

Ces préconditions ne sont pas du confort : sans elles, D2, D3, D6, D7 et D9
échouent pour une raison qui n'est pas celle qu'on croit — et un échec mal
attribué coûte plus cher qu'un échec.

- [ ] **Deux appareils physiques** : un Android **13 ou plus récent** (le
      filtrage de visibilité des paquets existe depuis API 30 et
      `targetSdkVersion` vaut 36 — `android/app/build.gradle:79`), et un iPhone.
      Aucun émulateur, aucun simulateur.
- [ ] **Build `profile` ou `release`, jamais `debug`.** Le plugin iOS de
      `app_links` **annule son propre enregistrement** en DEBUG quand le
      `registrar` n'a pas de `messenger`
      (`~/.pub-cache/hosted/pub.dev/app_links-7.0.0/ios/app_links/Sources/app_links/AppLinksIosPlugin.swift:43-52`,
      version épinglée par `pubspec.lock:19`). En debug, `kpb://` est donc mort
      côté iOS et D7 « échouerait » sans que le code soit en cause. Le
      simulateur est exclu pour une raison d'outillage non vérifiable depuis ce
      dépôt : la règle opérationnelle retenue est appareil physique + profile ou
      release.
- [ ] **Aucun `--dart-define` sur les cinq drapeaux de masquage.** Les valeurs
      par défaut attendues : `KPB_MVP_ONLY=true` (`lib/app/core/config/app_config.dart:93-96`),
      `KPB_AI_TOOLS_ENABLED=false` (`app_config.dart:149-154`),
      `KPB_DOCUMENT_UPLOAD_ENABLED=false` (`app_config.dart:182-187`),
      `KPB_AMBASSADOR_CASH_ENABLED=false` (`app_config.dart:105-108`),
      `KPB_FLIGHT_ESTIMATOR_ENABLED=false` (`app_config.dart:116-119`).
- [ ] **Coller la commande de build exacte dans le ticket.** Un testeur ne peut
      pas lire un `--dart-define` sur un écran : la commande est la seule preuve
      que D9 a été exécuté sur la bonne build.
- [ ] **Backend visé** : sans `KPB_API_BASE_URL`, `KPB_APP_ENV` vaut `prod` et
      l'app parle à `https://api.kpbeducation.cloud/api`
      (`app_config.dart:8-11` et `app_config.dart:248-250`). Le noter.
- [ ] **Langue** : les libellés cités ci-dessous sont ceux du français, la
      langue par défaut (`main.dart:238` — `fallbackLocale: Locale('fr')`).
      L'équivalent anglais de chaque chaîne est indiqué quand il est utile.
- [ ] **Push** : aucun `--dart-define` n'est requis, l'App ID OneSignal a une
      valeur par défaut compilée (`app_config.dart:58-61`).
- [ ] Pour D2 et D3, prévoir **deux téléphones Android** — un avec WhatsApp, un
      sans — ou accepter de désinstaller WhatsApp **et** WhatsApp Business sur
      l'appareil de test.

---

## D1 — Android 13+ : « Formulaire officiel » ouvre le navigateur

**Ce qu'aucun test ne couvre.** La visibilité des paquets n'existe que sur un
appareil : un test unitaire ou de widget ne fait jamais résoudre une intention
`VIEW` par le système. Le code a remplacé la précondition `canLaunchUrl` par une
**tentative** (`lib/app/core/utils/external_link.dart:36-46`) et le manifeste
déclare désormais les intentions `VIEW` `https` et `http`
(`android/app/src/main/AndroidManifest.xml:96-102`) — les deux se couvrent, mais
seul l'appareil prouve que la résolution aboutit.

**Préconditions.**
- D0 tenu, appareil Android 13+, **au moins un navigateur installé et activé**.
- Un compte de test capable d'atteindre l'onglet **Bourses**.

**Gestes exacts.**
1. Lancer l'app, aller sur l'onglet **Bourses** (3ᵉ icône de la barre du bas,
   libellé « Bourses », `lib/app/features/shell/app_shell.dart:209-215`).
2. Ouvrir une bourse de la liste (un tap sur la carte —
   `lib/app/features/scholarships/live_scholarships_screen.dart:477`).
3. Faire défiler jusqu'au bas de la fiche.
4. Si un bouton bleu pleine largeur **« Formulaire officiel »** est présent
   (`lib/app/features/scholarships/scholarship_detail_screen.dart:359-363`,
   libellé FR à `lib/app/core/translations/app_translations.dart:1107`, EN
   « Official application form » à `app_translations.dart:3888`), appuyer dessus.
   **S'il est absent, ce n'est PAS un échec de D1** : le bouton n'est rendu que
   si l'URL de la bourse est réellement ouvrable (schéma `http`/`https` + hôte
   non vide — `external_link.dart:64-73`). Le catalogue contient des
   `applicationUrl` sans schéma. Revenir en arrière et essayer une autre bourse,
   puis noter dans le ticket le titre de la bourse retenue.

**Résultat attendu.**
- L'app **passe en arrière-plan** et le navigateur système s'ouvre sur l'URL de
  la bourse. Le mode est `LaunchMode.externalApplication`
  (`external_link.dart:38`) : une vue web *dans* l'app serait une régression de
  mode, à consigner.
- Le retour arrière du système ramène sur la fiche de la bourse, intacte.

**Symptôme précis de l'échec.**
- **Rien ne se passe du tout** — pas de navigateur, pas de bandeau : échec
  bloquant. Le code prévoit toujours un message dans ce cas
  (`scholarship_detail_screen.dart:115-140`), donc un silence total signifie que
  même le repli n'a pas été rendu. Joindre une vidéo.
- **Bandeau « Impossible d'ouvrir ce lien »** (`app_translations.dart:765-768`)
  avec un bouton **« Demander le lien »** : le lancement a été refusé par le
  système. Sur un téléphone qui a un navigateur, c'est le signe que le bloc
  `<queries>` n'a pas pris effet dans l'APK/AAB installé — **arrêter la
  livraison** et vérifier le manifeste fusionné du binaire, pas celui du dépôt.
- Le navigateur s'ouvre sur une page d'erreur du site distant : ce n'est pas un
  échec de D1 (le lancement a marché) mais un défaut de donnée catalogue. Noter
  l'URL et l'identifiant de la bourse, ne pas bloquer la livraison sur ce point.

**Preuve.** Enregistrement d'écran du tap jusqu'au navigateur, modèle et version
d'Android, titre de la bourse.

---

## D2 — Android 13+ : le CTA WhatsApp ouvre WhatsApp (WhatsApp présent)

**Ce qu'aucun test ne couvre.** C'est l'**unique** chemin de monétisation de
l'app : il n'y a aucun paiement in-app, tout passe par ce renvoi
(`AndroidManifest.xml:78-84`). La cible est une URL `https://wa.me/…`
(`lib/app/core/utils/whatsapp_utils.dart:77`) ; les deux `<package>` déclarés
(`AndroidManifest.xml:110-111`) servent à ce que le lien ouvre **directement**
WhatsApp au lieu de faire un détour par le navigateur. Seul un appareil avec
WhatsApp installé départage les deux.

**Préconditions.**
- D0 tenu ; WhatsApp (ou WhatsApp Business) **installé et configuré** sur
  l'appareil.
- Connaître le numéro conseiller attendu : `+33768674292` par défaut
  (`app_config.dart:45-48`), sauf `--dart-define=KPB_WHATSAPP_NUMBER=…` — dans
  ce cas c'est ce numéro-là qui est attendu.

**Gestes exacts.**
1. Onglet **Profil** → section **Accès rapide** → **« Services KPB (Dossier
   prêt) »** (`lib/app/features/profile/profile_screen.dart:1297-1301`, libellé
   à `app_translations.dart:1536`).
2. Sur n'importe quelle carte de service, appuyer sur **« Contacter un
   conseiller »** (`lib/app/features/services/service_packages_screen.dart:230-233`,
   libellé à `app_translations.dart:1970`).
3. Une feuille de confirmation « conseiller vérifié » s'ouvre
   (`lib/app/core/ui/components/verified_advisor_sheet.dart:14-37`). **Lire et
   noter** : le numéro affiché (`verified_advisor_sheet.dart:65-70`) et le
   message pré-rempli montré avant le départ (`verified_advisor_sheet.dart:191-219`).
4. Appuyer sur **« Ouvrir WhatsApp »** (`verified_advisor_sheet.dart:236-242`,
   libellé à `app_translations.dart:2083`, EN « Open WhatsApp » à
   `app_translations.dart:4826`).

**Résultat attendu.**
- WhatsApp (ou WhatsApp Business) s'ouvre **directement**, sur une conversation
  avec le numéro affiché à l'étape 3, le message de l'étape 3 déjà saisi dans la
  zone de texte et **non envoyé**.
- Le numéro dans WhatsApp est **identique** à celui de la feuille. Une
  divergence est un défaut anti-fraude, pas un détail : la feuille existe pour
  que l'utilisateur reconnaisse un imposteur (`verified_advisor_sheet.dart:8-13`).

**Symptôme précis de l'échec.**
- **Toast/bandeau « Impossible d'ouvrir WhatsApp. Vérifiez que l'app est
  installée. »** (`whatsapp_utils.dart:122-128`, texte à
  `app_translations.dart:759-760`) sur un téléphone où WhatsApp est
  manifestement installé : échec **bloquant**, le renvoi commercial est mort.
- **Rien ne se passe** après « Ouvrir WhatsApp » : échec bloquant, joindre une
  vidéo.
- **Le navigateur s'ouvre sur la page `wa.me`** au lieu de WhatsApp : échec
  **partiel** à consigner. Le renvoi reste praticable (un tap de plus), mais les
  déclarations `<package>` (`AndroidManifest.xml:110-111`) n'ont pas eu d'effet
  sur cet appareil. Noter le modèle et la variante de WhatsApp installée.

**Preuve.** Capture de la feuille conseiller (numéro + message visibles) et
capture de la conversation WhatsApp pré-remplie.

---

## D3 — Android 13+ : WhatsApp absent, et navigateur désactivé — le repli doit être VISIBLE

**Ce qu'aucun test ne couvre, et le piège de ce protocole.** Le repli n'est pas
celui qu'on croit, parce que la cible est une URL `https`
(`whatsapp_utils.dart:77`) : sans WhatsApp mais **avec** un navigateur, le lien
`wa.me` est légitimement ouvert par le navigateur. Le bandeau d'échec n'apparaît
que quand **plus rien** ne peut résoudre l'intention. Un testeur qui attendrait
le message d'erreur avec un navigateur actif noterait un faux échec. Ce
protocole force donc les deux cas, dans l'ordre.

**Préconditions.**
- D0 tenu. Un appareil Android **sans WhatsApp ni WhatsApp Business** (désinstaller
  les deux si nécessaire).

**Gestes exacts — phase 1 (sans WhatsApp, navigateur actif).**
1. Refaire D2, gestes 1 à 4.
2. **Résultat attendu :** le **navigateur** s'ouvre sur la page `wa.me`
   (page « continuer vers le chat » / téléchargement de WhatsApp). C'est le
   comportement correct, pas un échec.
3. **Symptôme d'échec :** rien du tout — ni navigateur, ni message. C'est
   exactement le défaut muet que le lot a supprimé ; échec bloquant.

**Gestes exacts — phase 2 (sans WhatsApp *et* sans navigateur).**
4. Désactiver le navigateur : *Paramètres → Applications → Chrome (et tout autre
   navigateur) → Désactiver*. Vérifier qu'aucun navigateur ne reste activé.
5. Refaire D2, gestes 1 à 4.
   **Résultat attendu :** un toast/bandeau **« Impossible d'ouvrir WhatsApp.
   Vérifiez que l'app est installée. »** (`whatsapp_utils.dart:122-128`, texte à
   `app_translations.dart:759-760`). **À consigner tel quel dans le ticket :**
   c'est le seul repli offert sur ce chemin — le code ne propose ici aucun autre
   canal (pas d'e-mail, pas de numéro à copier), puisque le conseiller *est* sur
   WhatsApp.
6. Toujours sans navigateur, refaire **D1** (Bourses → une bourse →
   « Formulaire officiel »).
   **Résultat attendu :** le bandeau **« Impossible d'ouvrir ce lien »** / « Ton
   téléphone n'a pas pu ouvrir cette page. Un conseiller KPB peut t'envoyer le
   lien directement. » avec le bouton d'action **« Demander le lien »**
   (`scholarship_detail_screen.dart:115-140`, textes à
   `app_translations.dart:765-770`). Appuyer sur **« Demander le lien »** : le
   renvoi conseiller part avec un message citant le titre de la bourse
   (`app_translations.dart:769-770`). Sans WhatsApp ni navigateur, ce renvoi
   aboutira lui-même au toast de l'étape 5 — c'est attendu ; ce qui est vérifié
   ici, c'est que **le bouton de repli existe et réagit**.
7. **Réactiver le navigateur** avant de rendre l'appareil.

**Symptôme précis de l'échec (phase 2).**
- Aucun bandeau après le tap sur « Formulaire officiel » : le repli conseiller
  n'est pas rendu — échec bloquant, c'est le défaut d'origine.
- Le bandeau apparaît mais **sans** le bouton « Demander le lien » : le repli est
  dégradé en simple message d'erreur ; à consigner comme régression.
- Le bandeau disparaît avant qu'on puisse appuyer : sa durée est de 6 secondes
  (`scholarship_detail_screen.dart:124`) — refaire la manipulation, filmer.

**Preuve.** Vidéo des deux phases, liste des navigateurs désactivés, confirmation
écrite de leur réactivation.

---

## D4 — Aller-retour OAuth Google, Android

**Ce qu'aucun test ne couvre.** Le retour de session passe par un lien profond
`io.supabase.kpbeducation://login-callback/` (`app_config.dart:210-213`,
intent-filter à `AndroidManifest.xml:44-49`) : aucun test ne fait sortir puis
rentrer le processus. La complétion n'est pas signalée par la valeur de retour de
`signInWithGoogle` mais par l'événement `signedIn` observé à
`lib/app/features/auth/auth_welcome_screen.dart:37-48`.

**Préconditions.**
- D0 tenu.
- **Précondition ops, non vérifiable dans le code :** `io.supabase.kpbeducation://login-callback/`
  doit figurer dans la liste blanche « Redirect URLs » du tableau de bord
  Supabase. Le noter comme vérifié, par qui et quand.
- Appareil **déconnecté** de l'app : installation fraîche, ou Profil →
  déconnexion, de sorte que l'écran d'accueil d'authentification s'affiche
  (`lib/app/core/navigation/app_boot_screen.dart:18-31`).
- Un compte Google déjà présent sur le téléphone.

**Gestes exacts.**
1. Sur l'écran d'accueil, appuyer sur **« Continuer avec Google »**
   (`auth_welcome_screen.dart:154`, libellé à `app_translations.dart:2028`).
2. Choisir le compte dans le sélecteur, accorder le consentement s'il est
   demandé.
3. Ne rien toucher ensuite : observer.
4. Une fois dans l'app, **tuer l'app** (récents → balayer la carte) puis la
   relancer.

**Résultat attendu.**
- L'écran de consentement s'ouvre dans le **navigateur système** (application
  Chrome, pas une vue web interne) : le mode est épinglé à
  `LaunchMode.externalApplication` (`lib/app/core/services/auth_service.dart:80-97`).
- Après le choix du compte, **l'app revient au premier plan d'elle-même**, sans
  tap supplémentaire, et atterrit sur l'**onboarding** si le profil n'est pas
  encore complété, sur la coquille d'accueil sinon
  (`auth_welcome_screen.dart:312-324`).
- Après le geste 4, l'app est **toujours connectée** : la session est stockée
  dans le magasin sécurisé de la plateforme (`main.dart:85-91`).

**Symptôme précis de l'échec.**
- Le navigateur reste sur une page blanche affichant
  `io.supabase.kpbeducation://login-callback/…` : le lien de retour n'est pas
  reconnu — liste blanche Supabase ou intent-filter. Échec bloquant.
- L'app revient mais **reste sur l'écran d'accueil, bouton Google en attente** :
  l'événement `signedIn` n'est pas arrivé jusqu'à l'écouteur
  (`auth_welcome_screen.dart:37-48`). Échec bloquant.
- Bandeau **« Connexion Google impossible. Réessayez. »**
  (`app_translations.dart:2029`, levé à `auth_welcome_screen.dart:64-69`) :
  l'appel a levé une exception. Noter s'il est immédiat ou après le retour.
- Le consentement s'ouvre dans une vue web **interne** à l'app : régression de
  `oauthLaunchMode` ; Google refuse aussi les vues web intégrées
  (`auth_service.dart:95-96`). À consigner même si la connexion aboutit.
- Déconnecté après le geste 4 : échec de persistance de session, à consigner.

**Preuve.** Vidéo continue du tap jusqu'au retour dans l'app (la continuité est
la preuve : une coupure au montage cache exactement le défaut recherché).

---

## D5 — Aller-retour OAuth Google, iOS

**Ce qu'aucun test ne couvre, et le défaut précis à surveiller.** Ce bug a été
reproduit sur TestFlight (iPhone / iOS 26) : `signInWithOAuth` ouvrait par défaut
une feuille Safari interne, `supabase_flutter` créait bien la session depuis le
lien profond mais ne fermait jamais la feuille — la connexion réussissait, l'app
naviguait **derrière**, et l'utilisateur restait sur la page de redirection
blanche à devoir appuyer sur « Terminé »
(`auth_service.dart:80-92`). Deux garde-fous ont été posés : le navigateur système
(`auth_service.dart:97`) et une fermeture de secours de toute vue web résiduelle
(`auth_service.dart:113-121`, appelée à `auth_welcome_screen.dart:43`). Aucun test
ne peut voir une feuille Safari posée par-dessus l'app.

**Préconditions.**
- D0 tenu, iPhone physique, build profile/release (TestFlight convient).
- Schéma de retour déclaré : `ios/Runner/Info.plist:115-127`.
- Mêmes préconditions de compte et de liste blanche Supabase que D4.

**Gestes exacts.** Identiques à D4, gestes 1 à 4.

**Résultat attendu.**
- Le consentement s'ouvre dans **Safari, l'application** (barre d'onglets et
  d'adresse complètes), pas dans une feuille modale posée sur l'app.
- Après le choix du compte, l'app revient d'elle-même **au premier plan** et
  **aucune feuille Safari ne reste visible** par-dessus.
- Atterrissage : onboarding ou coquille d'accueil, comme en D4.

**Symptôme précis de l'échec.**
- Une feuille Safari reste posée sur l'app, affichant la page de redirection,
  pendant que l'app a déjà navigué derrière : **régression exacte** du défaut
  ci-dessus. Échec bloquant, capture d'écran obligatoire.
- L'utilisateur doit appuyer sur « Terminé »/« Done » pour voir l'app : même
  défaut, même verdict.
- Safari reste sur `io.supabase.kpbeducation://login-callback/…` sans revenir :
  liste blanche Supabase ou `CFBundleURLTypes` (`Info.plist:115-127`).
- iOS peut demander une confirmation d'ouverture d'application : l'accepter, et
  noter qu'elle est apparue.

**Preuve.** Vidéo continue, plus une capture de l'écran d'atterrissage.

---

## D6 — Notification reçue application TUÉE, et la route qu'elle porte

**Ce qu'aucun test ne couvre.** Le routage se fait dans un écouteur de clic
OneSignal (`lib/app/core/services/onesignal_service.dart:102-132`), branché au
démarrage (`onesignal_service.dart:34`) ; un test ne peut ni tuer le processus,
ni faire naître une notification système, ni la faire taper.

**Préconditions (celle sur la permission est la plus souvent oubliée).**
- D0 tenu.
- **La permission de notification doit avoir été accordée sur cet appareil.**
  Android 13+ l'exige (`AndroidManifest.xml:5`) et l'app ne la demande pas au
  démarrage : elle la demande à la **fin de l'onboarding**
  (`lib/app/features/onboarding/onboarding_screen.dart:578`), depuis *Profil →
  Notifications* (`lib/app/features/notifications/notifications_screen.dart:792-796`)
  ou en activant une alerte de bourse
  (`lib/app/features/scholarships/widgets/scholarship_alert_button.dart:54`).
  Sans ce geste, **aucune notification n'arrivera jamais** et D6 échouerait pour
  la mauvaise raison. Vérifier aussi l'autorisation dans les réglages du
  système.
- Utilisateur **connecté** : l'identifiant externe OneSignal est l'identifiant de
  profil (`onesignal_service.dart:52-72`) — c'est la cible d'envoi.
- Un dossier existant, avec son identifiant exact sous la main.

**Gestes exacts.**
1. Relever l'identifiant externe (identifiant de profil) de l'appareil de test.
2. **Tuer l'application** — Android : récents → balayer la carte ; iOS : balayer
   vers le haut depuis le bas, maintenir, puis balayer la carte. Attendre
   10 secondes. Ne pas se contenter d'un passage en arrière-plan : c'est
   précisément la différence que ce protocole mesure.
3. Depuis le tableau de bord OneSignal, envoyer un message ciblé sur cet
   identifiant externe, avec en **Additional Data** la paire
   `route` = `/cases/<identifiant du dossier>` — c'est la clé que le code lit
   (`onesignal_service.dart:103-104`).
4. Sans déverrouiller autre chose, **taper la notification**.
5. Répéter les gestes 2 à 4 avec `route` = `/scholarships` **et**
   `scholarshipId` = `<identifiant d'une bourse>` (deux paires) — le code
   remplace alors la liste par la fiche
   (`onesignal_service.dart:109-119`).
6. Répéter les gestes 2 à 4 avec `route` = `/cases/` (barre finale, sans
   identifiant), qui est un cas explicitement rejeté
   (`lib/app/core/config/app_routes.dart:99-104`).

**Résultat attendu.**
- Geste 4 : l'app **démarre à froid** et affiche le **détail de ce dossier**
  (`onesignal_service.dart:124`).
- Geste 5 : la **fiche de la bourse**, pas la liste des bourses.
- Geste 6 : l'app démarre et affiche l'**accueil**, sans plantage — le repli est
  volontaire (`onesignal_service.dart:121-122` et `onesignal_service.dart:126-131`).

**Symptôme précis de l'échec.**
- La notification **n'arrive jamais** : permission non accordée, ou identifiant
  externe non lié (`onesignal_service.dart:52-72`). Vérifier les deux avant de
  conclure quoi que ce soit sur le routage.
- L'app démarre sur l'**accueil** au geste 4 ou 5 : la route a été rejetée. Deux
  causes à distinguer dans le ticket — mauvaise clé dans la charge utile (le code
  lit `route`, pas `url` ni `deeplink`), ou identifiant vide/imbriqué
  (`app_routes.dart:102`). Recopier la charge utile exacte envoyée.
- L'app affiche la **liste** des bourses au geste 5 : la remontée d'ancienne
  charge utile (`onesignal_service.dart:109-119`) n'a pas joué ; consigner.
- L'app **plante** au démarrage à froid depuis la notification : bloquant, joindre
  la trace Crashlytics.
- L'app démarre mais reste sur l'écran d'accueil d'authentification : le compte
  n'était pas connecté sur cet appareil — refaire dans les préconditions.

**Preuve.** Copie de la charge utile envoyée (les trois variantes), vidéo du tap
jusqu'à l'écran atteint, capture de l'état « application absente des récents »
avant l'envoi.

---

## D7 — Le lien profond `kpb://`

**Ce qu'aucun test ne couvre.** Le test existant couvre la **résolution de
route** (`test/core/services/deep_link_service_test.dart:57-166`) et la
navigation quand on lui **donne** l'URI
(`deep_link_service_test.dart:168-224`) : il appelle `handleUri` directement. Ce
qu'il ne peut pas prouver, c'est que le système remette un jour cette URI —
l'enregistrement natif du schéma et la remise du lien de démarrage. Avant ce
service, `kpb://…` ne faisait que
ramener l'app au premier plan sans naviguer
(`lib/app/core/services/deep_link_service.dart:13-16`). Et le plugin iOS ne
s'enregistre pas en debug (voir D0) : **ce protocole est le seul moyen de savoir
si `kpb://` marche.**

**Préconditions.**
- D0 tenu, build **profile/release** sur appareil physique.
- **Compte déjà onboardé** sur l'appareil. Sinon l'écran cible s'empile
  par-dessus l'écran d'accueil d'authentification : le premier écran est résolu
  par `app_boot_screen.dart:18-31` et la navigation externe **empile** au lieu de
  remplacer (`lib/app/core/navigation/app_navigation.dart:20`). Ce n'est pas un
  bug à ouvrir, c'est une précondition à tenir.
- Un identifiant de dossier valide.

**Gestes exacts — Android.**
1. App **tuée** (récents → balayer). Puis, machine reliée en USB :
   `adb shell am start -a android.intent.action.VIEW -d "kpb://cases/<id>"`
   (schéma déclaré à `AndroidManifest.xml:35-40`).
2. Refaire avec l'app **en arrière-plan** (bouton d'accueil, pas balayage).
3. Refaire avec `kpb://` nu.

**Gestes exacts — iOS.**
4. App **tuée**. Écrire `kpb://cases/<id>` dans une note (application Notes),
   puis taper le lien devenu cliquable (schéma déclaré à
   `Info.plist:105-113`). Accepter la confirmation système si elle apparaît.
5. Refaire avec l'app en arrière-plan.

**Résultat attendu.**
- Gestes 1, 2, 4, 5 : l'app s'ouvre (à froid ou revient) et **le détail du
  dossier est affiché**, empilé au-dessus de la coquille
  (`deep_link_service.dart:68-78` puis `app_navigation.dart:20`). Le retour
  arrière ramène sur la coquille.
- Geste 3 : l'app s'ouvre sur l'accueil et **rien ne s'empile** — c'est
  volontaire (`deep_link_service.dart:74-76`).

**Symptôme précis de l'échec.**
- L'app **passe au premier plan sans naviguer** : c'est le symptôme historique
  exact (`deep_link_service.dart:13-16`). Sur iOS, vérifier **d'abord** que la
  build n'est pas en debug (guard `#if DEBUG`, D0) — sinon le verdict est faux.
  Sur une build profile/release, échec bloquant.
- Rien ne se passe du tout, l'app ne s'ouvre même pas : le schéma n'est pas
  enregistré dans le binaire installé (manifeste fusionné / `Info.plist` de la
  build, pas ceux du dépôt).
- L'écran cible s'affiche par-dessus l'onboarding ou l'écran d'authentification :
  précondition « compte onboardé » non tenue, refaire.

**Preuve.** Commande `adb` exacte utilisée, vidéo côté iOS, et la mention
explicite du type de build (profile ou release) dans le ticket.

---

## D8 — Les pages légales, depuis l'app, ouvrent bien `kpbeducation.cloud`

**Pourquoi c'est ici.** Ces liens sont le seul chemin par lequel l'utilisateur
peut atteindre l'éditeur nommé dans la politique, et ils dépendent du même
mécanisme de lancement externe que D1 (`lib/app/features/legal/legal_pages.dart:270`).
Un lien légal muet est un défaut de conformité, pas d'ergonomie.

**Préconditions.** D0 tenu, navigateur activé, une application de messagerie
installée pour les adresses e-mail.

**Gestes exacts.**
1. Onglet **Profil** → section **« Informations légales »**
   (`profile_screen.dart:1341`, libellé à `app_translations.dart:125`).
2. **« Politique de confidentialité »** (`profile_screen.dart:1347-1352`, libellé
   à `app_translations.dart:1540`).
3. Dans le **§1**, vérifier que l'éditeur nommé est **KPB Global L.L.C-FZ**,
   licence **2537631.01**, Meydan Free Zone
   (`app_translations.dart:623-628`), puis taper le lien souligné
   **`https://kpbeducation.cloud`** (`app_translations.dart:627`).
4. Revenir, puis taper l'adresse **`privacy@kpbeducation.com`** du §8
   (`app_translations.dart:686`).
5. Revenir en arrière deux fois, ouvrir **« Conditions d'utilisation »**
   (`profile_screen.dart:1353-1358`, libellé à `app_translations.dart:1541`) et,
   dans le **§11**, taper **`https://kpbeducation.cloud`**
   (`app_translations.dart:703`).
6. Depuis un navigateur, ouvrir **`https://kpbeducation.cloud/app`** — le lien de
   téléchargement collé dans les messages de parrainage
   (`app_config.dart:226-231`).

**Résultat attendu.**
- Gestes 3 et 5 : le navigateur s'ouvre sur `kpbeducation.cloud` et la page
  **se charge** (ni 404, ni page de parking, ni certificat invalide).
- Geste 4 : le composeur d'e-mail s'ouvre, destinataire pré-rempli.
- Geste 6 : la page redirige vers la fiche du magasin correspondant au téléphone
  utilisé, et propose les deux liens en repli sans JavaScript
  (`app_config.dart:226-230`).

**Symptôme précis de l'échec.**
- Rien ne se passe au tap sur un lien : **il n'y a aucun message de repli sur cet
  écran** — la valeur de retour du lancement est ignorée
  (`legal_pages.dart:268-271`), contrairement à la fiche de bourse. Le silence
  est donc le seul symptôme possible ; à consigner comme bloquant pour un lien
  `https`, et comme défaut à corriger (pas bloquant) pour une adresse e-mail sur
  un téléphone sans application de messagerie.
- Le navigateur s'ouvre mais la page renvoie 404 ou une page de parking : la
  politique de confidentialité pointe vers un site qui ne répond pas — bloquant
  pour un dépôt de formulaire légal de magasin.
- Le lien est affiché sans soulignement et n'est pas cliquable : le détecteur de
  liens n'a pas reconnu la chaîne (`legal_pages.dart:240-242` — il ne reconnaît
  que `https://…` et les adresses e-mail ; un `http://` ou un domaine nu ne
  serait pas cliquable). Noter la chaîne exacte concernée.

**Preuve.** Captures : §1 avec l'éditeur et la licence visibles, la page web
chargée, le composeur d'e-mail, et la redirection de `/app`.

---

## D9 — Les surfaces masquées sont ABSENTES de l'écran, pas grisées

**Ce que le test couvre déjà, et ce qu'il ne couvre pas.** Le rendu est testé
drapeau à FAUX **et** à VRAI (contre-épreuves incluses :
`test/core/masquage_ai_tools_test.dart:220-311` et
`test/core/masquage_documents_test.dart:194-451`). Ce qui n'est pas testable :
que la build installée **sur ce téléphone** soit bien celle sans `--dart-define`
(voir D0), et qu'aucune trace visuelle ne subsiste à l'écran (espace vide,
séparateur orphelin, badge « bientôt »).

**Critère d'acceptation, à appliquer littéralement.** « Absent » signifie : pas de
ligne, pas de carte, pas d'onglet, pas d'icône. **Une entrée grisée est un
échec.** Une entrée qui ouvre un écran « bientôt disponible » est un échec. Un
séparateur qui subsiste sans ligne au-dessus est un défaut à consigner.

**Gestes exacts et résultat attendu, écran par écran.**

1. **Tiroir d'outils** — depuis n'importe quel onglet, taper l'icône ☰ en haut à
   gauche (`app_shell.dart:386-388`).
   Attendu : **exactement quatre** outils, dans cet ordre — « Scanner de
   documents », « Calculateur de budget », « Estimateur de logement », « Tableau
   d'impact » (`lib/app/features/shell/kpb_tools_drawer.dart:156-230`, libellés à
   `app_translations.dart:57-65`).
   Absents : « CV », « Lettre de motivation », « Simulateur d'entretien »,
   « Relecture IA » (masqués par `app_config.dart:149-154`) et « Estimateur de
   vol » (masqué par `app_config.dart:116-119`).
2. **Écran « Outils étudiants »** — Accueil, puis la carte qui y mène
   (`lib/app/features/home/home_screen.dart:2307`, titre à
   `app_translations.dart:147`).
   Attendu : aucune carte CV, lettre de motivation ni simulateur d'entretien
   (`lib/app/features/tools/student_tools_screen.dart:34-68`). Cet écran est une
   **seconde porte** vers les mêmes outils : le vérifier séparément du tiroir.
3. **Profil → Accès rapide** (`profile_screen.dart:1264-1319`).
   Absents : « Simulateur de Vols (Kayak) » (`profile_screen.dart:1264-1270`),
   « Logement Étudiant (France) » (`profile_screen.dart:1272-1279`), les entrées
   communauté, mentors alumni, devenir mentor et salon virtuel
   (`profile_screen.dart:1280-1287` et `profile_screen.dart:1303-1319`).
   Présents : « Services KPB (Dossier prêt) » (`profile_screen.dart:1297-1301`)
   et les informations légales (D8).
4. **Détail d'un dossier** — onglet **Dossiers** → un dossier.
   Absents : le conseil photo/PDF (`lib/app/features/cases/case_detail_screen.dart:435-441`),
   la carte « simulateur d'entretien » (`case_detail_screen.dart:444-457`), la
   carte de relecture IA (`case_detail_screen.dart:495-508`).
   Présent et **redirigé** : sur une pièce demandée, le bouton d'envoi ne
   disparaît pas — il ouvre le renvoi WhatsApp au lieu du sélecteur de fichier
   (`case_detail_screen.dart:486-489`). Le vérifier en tapant dessus : la feuille
   conseiller doit s'ouvrir (comme en D2). Un sélecteur de fichiers qui s'ouvre
   est un échec.
5. **Tunnel de création de dossier** — Dossiers → créer un dossier → avancer
   jusqu'à l'étape « Documents ».
   Attendu : un écran qui explique par où passent les pièces
   (`lib/app/features/cases/case_tunnel_flow.dart:345-347`). Trois sélecteurs de
   fichiers, ou une pièce jointe qui semble acceptée, sont un échec : rien n'était
   réellement téléversé (`app_config.dart:162-181`).
6. **Ambassadeur** (si l'écran est atteignable depuis le compte de test).
   Attendu, pour un compte non activé par les opérations : l'écran de
   candidature, **sans** solde en FCFA, **sans** classement, **sans** retrait
   (`lib/app/features/referral/ambassador_screen.dart:166-172`).

**Symptôme précis de l'échec.**
- Une entrée masquée apparaît, même grisée : soit la build a été faite avec le
  drapeau à vrai (comparer avec la commande de build collée au titre de D0), soit
  un point d'entrée a été oublié. **Noter le libellé exact et l'écran** — c'est
  ce qui permet de retrouver le site d'appel.
- Une entrée apparaît et ouvre un écran fonctionnel : idem, et bloquant si c'est
  un outil IA ou un téléversement de document (deux masquages posés pour des
  motifs de conformité, `app_config.dart:136-148` et `app_config.dart:162-181`).
- Un séparateur ou un espace vide subsiste là où une entrée a disparu : défaut
  visuel à consigner, non bloquant.

**Preuve.** Une capture par écran des six points, plus la commande de build.

---

## Required evidence

- Screenshot or screen recording per section.
- Crashlytics screenshot proving no new fatal crash spike after smoke run.
- Short release note with pass/fail status and any known non-blocking issue.

## Sign-off

- QA sign-off: ________
- Engineering sign-off: ________
- Product sign-off: ________