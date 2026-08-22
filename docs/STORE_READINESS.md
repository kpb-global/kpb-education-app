# Store readiness — privacy declarations, age rating & performance budget

> **Issue:** KPB-68 (Epic 8 — IA responsable, conformité & store-readiness).
> **Status of dependencies:** the data-minimization and account-deletion
> behaviours described here are delivered by PRs **#58** (KPB-66 — PII
> minimization + AI consent), **#59** and **#60** (KPB-67 — account deletion,
> data export, minor/guardian consent). This document assumes those have
> merged. Keep it updated whenever a data flow or third-party changes.

The **code-derived** inventory of processors and data types lives in
`[data-inventory.md](data-inventory.md)` (lot 9). This file remains the
copy-paste source for the store forms. If the two diverge, the inventory
(and the code it cites) wins.

This is the source of truth for the **App Store Privacy "nutrition labels"**,
the **Google Play Data Safety** form, the **age rating**, and the **measured
performance budget**. Copy the relevant sections into App Store Connect / the
Play Console at submission time.

---

## 1. Data collection inventory

Ce que l'app collecte, où ça vit, et — quand un tiers le voit aussi — qui le
reçoit.

**Responsable du traitement : KPB Global L.L.C-FZ**, société à responsabilité
limitée de zone franche immatriculée auprès de la Meydan Free Zone (Meydan City
Corporation, Émirat de Dubaï) sous la licence n° 2537631.01, siège Meydan
Grandstand, 6th floor, Meydan Road, Nad Al Sheba, Dubaï (EAU) ; KPB Education en
est un **service**, pas une entité. C'est l'identité que porte la politique
livrée dans l'app (`app_translations.dart:624-625`, EN `:3425-3426`) et la page
web (`web/public/confidentialite.html:17`) : les deux consoles doivent porter la
même, sinon la fiche et la politique liée se contredisent. Régime applicable :
**décret-loi fédéral EAU n° 45 de 2021**, autorité **UAE Data Office**
(`app_translations.dart:628`, EN `:3429`) — l'analyse de transferts est donc
**EAU → États-Unis**, pas UE → États-Unis.

| Data | Collected | Stored in | Notes |
|---|---|---|---|
| Name (full name) | Onboarding | Own backend (Postgres) | **Coach : jamais transmis** — `fullName` existe dans le contexte (`coach-prompt.builder.ts:4`) mais n'est interpolé dans aucune invite (`:103`, `:136`). **Outils :** `/tools/cv-summary` et `/tools/personalize-letter` acceptent encore `name` (le PDF l'imprime) sans le recopier dans l'invite (`tools.service.ts:73-74`, `:126`) ; les 4 écrans restent masqués (`app_config.dart:149`). **Orientation : la fuite était réelle**, fermée par **PR #216** (projection close `{currentLevel, targetCountryIds, fieldIds, preferredLanguage}`, garde `orientation.prompt-privacy.spec.ts`). ⚠️ Cette branche porte encore le code d'avant : `orientation.service.ts:143` lit `body.profile` et `:161-163` le sérialise **en entier** dans le message `user` du LLM, alors que le client y met `fullName` (`app_controller.dart:826-828`) — `git log --all -S"prompt-privacy"` ne rend rien ici. **La case « pas de nom chez Groq » n'est vraie que du backend qui porte #216 : ne la cocher qu'avec ce backend déployé.** Le nom transite aussi en paramètre d'URL vers notre propre backend pour le flux coach (`app_api_client.dart:940` → `coach.controller.ts:52`, `:62`), qui ne le relaie pas. |
| Email | Onboarding / OAuth | Supabase Auth + Postgres **+ OneSignal (US)** | ⚠️ **Partagée avec un tiers** : `OneSignal.User.addEmail` (`onesignal_service.dart:62-64`) reçoit `profile.email` (`app_controller.dart:1910`). Aucun consentement ne conditionne ce chemin (voir la ligne « Push identity »). |
| Phone + WhatsApp | Onboarding | Postgres | Jamais écrits dans `SharedPreferences` (`local_app_repository.dart:133`). Non transmis à OneSignal (`syncOneSignalIdentity`, `app_controller.dart:1902-1918`, ne les lit pas). |
| Country of residence | Onboarding | Postgres + local | Part aussi chez OneSignal comme étiquette `target_country` lorsqu'aucun pays visé n'est renseigné (`app_controller.dart:1905-1907`, `:1914`). |
| Birth date | Onboarding (students) | Postgres + local (`local_app_repository.dart:160`) | Blocage strict sous 16 ans (`onboarding_screen.dart:223`) ; tuteur exigé sous 18 (`:218`, `:430-436`). |
| Guardian name/contact + consent | Onboarding (declared minors) | Postgres ; nom + consentement aussi en local (`local_app_repository.dart:161`) | **Contact du tuteur jamais persisté sur l'appareil** : `guardianContact` n'apparaît nulle part dans `local_app_repository.dart`. |
| Profile photo | Profile | Backend storage — **objet privé**, aucune URL publique, flux authentifié (`profiles.controller.ts:63-66`) | Réduite à 512 px avant tout accès réseau (`app_api_client.dart:161-163`), scannée avant écriture (`profiles.service.ts:270` → `assertAvatarScannerReady`). En prod sans `CLAMAV_HOST`, la route **échoue fermé** (`profile-avatar.policy.ts:70-76`) : aucune photo n'entre. Condition d'ops — pas une raison de retirer la déclaration. |
| Voice dictation | Support / case request | **Aucun octet audio chez KPB** : seul `result.recognizedWords` est lu (`speech_input_service.dart:37-39`) et seul le texte devient un message | ⚠️ **« Sur l'appareil » est faux.** L'unique appel à `listen()` construit `SpeechListenOptions` **sans `onDevice`** (`speech_input_service.dart:40-44`), dont le défaut du paquet est `false` = « on device **ET** network recognition » (`speech_to_text_platform_interface-2.4.0/lib/speech_to_text_platform_interface.dart:78-83`). iOS ne met alors jamais `requiresOnDeviceRecognition` (`SpeechToTextPlugin.swift:557-559`) ; Android ne pose jamais `EXTRA_PREFER_OFFLINE` (`SpeechToTextPlugin.kt:687-689`). **L'audio peut donc partir au service de reconnaissance d'Apple ou de Google.** Surface atteignable sans drapeau : étape 3 du tunnel (`case_tunnel_flow.dart:357-358`, à comparer au `case 2` gardé `:345`), bouton non gardé (`:840-852`). Permissions : `RECORD_AUDIO` (`AndroidManifest.xml:7`), `NSMicrophoneUsageDescription` + `NSSpeechRecognitionUsageDescription` (`Info.plist:52-55`). |
| Academic profile (level, field, target countries, grades, budget) | Onboarding | Postgres + local | Budget envoyé à Groq **en tranche** seulement (`coach-prompt.builder.ts:28-40`). Niveau et pays visé partent aussi chez OneSignal comme étiquettes (`app_controller.dart:1911-1916`). |
| Cases: messages, timeline | In-app | Postgres + file storage | **L'app n'envoie aucun fichier en 49** (`app_config.dart:182`) : l'étape documents est remplacée par un renvoi WhatsApp (`case_tunnel_flow.dart:345-346`). Fichiers téléversés par des builds antérieures encore en stockage. |
| Saved items, orientation answers, search history | In-app | Postgres (`orientation.service.ts:200`) + local (`app_snapshot.dart:56`, `:63` ; `local_app_repository.dart:66`, `:105`) | Le **terme de recherche** part aussi à Firebase Analytics en texte libre (`analytics_service.dart:434-437`). |
| Coach (AI) messages | In-app | Postgres ; **transmis à Groq (US)** (`llm.service.ts:53`) | Texte libre — voir §2. Les routes IA sont derrière `AiConsentGuard` (`orientation.controller.ts:29`, `:37` ; `tools.controller.ts:13` ; `document-review.controller.ts:12`). |
| **Push identity** (ex-« Push token ») | Runtime, dès qu'un profil existe | OneSignal (US) | ⚠️ **Bien plus que le jeton** : identifiant de compte (`OneSignal.login`, `onesignal_service.dart:61` ← `app_controller.dart:1909`), **adresse e-mail** (`:62-64` ← `:1910`) et **4 étiquettes** `account_type / level / target_country / locale` (`:69` ← `:1911-1916`). Actif par défaut en 49 : App ID compilé non vide (`app_config.dart:58-64`, aucun `--dart-define` ne l'écrase dans les chaînes de build), `initialize()` inconditionnel (`main.dart:120`), envoi à trois points d'entrée (`main.dart:125-126` ; `app_controller.dart:554`, `:632`). **Aucun consentement** : `requestPermission()` rend `Future<void>` et jette son résultat (`onesignal_service.dart:43-50`) — un refus système n'empêche pas l'envoi ; `analyticsOptOut` ne route que vers Firebase + PostHog (`app_controller.dart:512-514` → `analytics_service.dart:96-108`). Périmètre négatif : ni nom, ni téléphone, ni WhatsApp, ni date de naissance, ni document (`user.dart:77`, `:78`, `:123`, `:127-128` — aucun n'est lu par `syncOneSignalIdentity`). |
| Newsletter bourses : consentement + coordonnées | Profil / onboarding | Postgres ; **Mautic auto-hébergé quand configuré** | ⚠️ Ce qui partirait n'est pas « l'e-mail après opt-in » : `upsertContact` envoie e-mail, **prénom + nom**, téléphone, WhatsApp, pays, langue (`mautic.service.ts:99`, `:105-109`), et il est appelé **avant** de brancher sur `optIn` (`:76` puis `:77`). Le client joint toujours `scholarshipNewsletterOptIn` à chaque PATCH profil (`app_controller.dart:2012`), ce qui déclenche la synchro (`profiles.service.ts:239-240`), et `newsletterSyncedOptIn` (`schema.prisma:373`, nullable) ≠ `newsletterOptIn` (`:371`, défaut `false`) n'arrête rien (`newsletter-sync.service.ts:48`) : un utilisateur **qui n'a jamais consenti** verrait ses coordonnées poussées puis mises en DNC. **Inerte aujourd'hui** — `isConfigured` faux → sortie immédiate (`mautic.service.ts:64-68`), variables vides par défaut (`docker-compose.yml:62-65`). **Ne pas configurer Mautic sans corriger l'ordre**, sinon la case « partagé » et la mention « après opt-in » deviennent fausses le même jour. |
| App interaction events | Runtime | Firebase Analytics ; **PostHog seulement si le build porte une clé** | Noms d'événements + paramètres non-PII, **sauf le terme de recherche** et **sauf `current_level`** (`eef_interest_declared`, ajouté par l'espace « Études en France »), qui est un attribut de profil académique et non un nom d'événement. Aucune case ne bascule pour autant — *App activity → App interactions* et *Usage Data → Product Interaction* sont déjà à « Yes » — mais la description ci-contre serait fausse sans cette réserve. Le miroir PostHog est sauté quand `posthogEnabled` est faux (`app_config.dart:87`). |
| Session recordings (screen replays) | Runtime | PostHog (US) — **conditionnel** | Captures de navigation, **tous les textes et images masqués** à la capture (`main.dart:71-75`) ; identité = UUID backend (`analytics_service.dart:69-73`), pas de PII. ⚠️ Tout le câblage PostHog est inerte quand `POSTHOG_API_KEY` est vide, ce qui est le **défaut compilé** (`app_config.dart:72-75`, `:87` ; `main.dart:66`) — voir « à trancher » ci-dessous. |
| Crash diagnostics | On crash | Firebase Crashlytics | Traces + clés de synchro non-PII (compteurs et horodatages : `sync_telemetry.dart:14-16`, `:29-35`, via `:96`). ⚠️ **Aucun opt-out** : `setCrashlyticsCollectionEnabled` n'existe nulle part dans le dépôt (0 occurrence), les collecteurs sont armés inconditionnellement (`main.dart:49-54`) **avant** la relecture du consentement (`main.dart:110`), et `setCollectionEnabled` ne touche que Firebase Analytics + PostHog (`analytics_service.dart:96-108`). **Non lié à l'utilisateur** : aucun `setUserIdentifier` — les 6 usages de l'instance sont tous des écritures (`main.dart:50`, `:52`, `:179` ; `app_logger.dart:39` ; `safe_crashlytics.dart:42` ; `sync_telemetry.dart:96`). |
| Identifiant publicitaire Android (`AD_ID`) | Runtime, **par défaut** | Firebase / Google (mesure) | Permission héritée de `firebase_analytics` (`pubspec.yaml:83`) via `play-services-measurement-api:23.2.0`, qui la déclare (`…/jetified-play-services-measurement-api-23.2.0/AndroidManifest.xml:25-27`) et à qui le merger l'attribue **seule** (`manifest-merger-blame-release-report.txt:146-148` ; OneSignal ne la déclare pas). Aucun opt-out posé : `grep -rn -i "AD_ID\|adid_collection\|ACCESS_ADSERVICES" android/` = 0 résultat. Collecte active par défaut (`app_controller.dart:149` ; `app_snapshot.dart:13` ; `local_app_repository.dart:46` → `main.dart:110` → `app_controller.dart:512-514`). ⚠️ **Réserve de preuve** : le manifeste fusionné et l'APK sur disque portent `versionCode="45"` / `com.kpbeducation.app` (`build/app/intermediates/packaged_manifests/release/processReleaseManifestForPackage/AndroidManifest.xml:3-4`, `:75-77`), donc **antérieurs** à la restauration d'identité (#165) : ils prouvent le mécanisme, pas le binaire 49. Ce qui rattache le constat à la 49 : la dépendance n'a pas bougé (`git log --since=2026-07-16 -S"firebase_analytics" -- pubspec.yaml pubspec.lock` = vide) et aucune exclusion Gradle n'existe. Non re-mesurable ici — `flutter build apk --release` refuse sans `android/key.properties`. |

**Aucun SDK publicitaire, aucune attribution, aucun courtier de données, aucun
suivi inter-applications.** Ce qui ship côté identifiant publicitaire est
`play-services-ads-identifier:18.0.0` (`sdkDependencies.txt:944`), une
bibliothèque de **lecture** tirée par la chaîne de mesure Firebase, pas une
régie : rien dans le code ne lie ces données à des données tierces à des fins
publicitaires, donc « Used for tracking » reste **Non** partout. Le masquage du
replay est réel (`main.dart:74-75`) et l'identifiant envoyé à PostHog après
connexion est un UUID (`analytics_service.dart:69-73`). L'interrupteur
**Profil → « Analyse d'usage »** (`profile_screen.dart:735-745` →
`app_controller.dart:503-508`, persisté `local_app_repository.dart:46`, `:97`)
coupe **Firebase Analytics + PostHog, et rien d'autre** : ni Crashlytics
(ligne ci-dessus), ni OneSignal (`syncOneSignalIdentity` ne lit aucun drapeau).

> **Cases de formulaire dont la réponse change — avec la raison, en une ligne.**
>
> | Console → case | Réponse | Raison (adossée au code) |
> |---|---|---|
> | Play → Sécurité des données → Informations personnelles → **Adresse e-mail** | Collectée **et partagée**, finalité « Fonctionnalité de l'application » | `OneSignal.User.addEmail(profile.email)` — `onesignal_service.dart:62-64` ← `app_controller.dart:1910`. |
> | Play → Identifiants → **ID utilisateur** | Collecté **et partagé** | `OneSignal.login(profile.id)` — `onesignal_service.dart:61` ← `app_controller.dart:1909`. |
> | Play → Informations personnelles → **Autres informations** (ou Activité → Autres actions, selon la ventilation retenue) | Collectées **et partagées** | 4 étiquettes de ciblage `account_type / level / target_country / locale` — `app_controller.dart:1911-1916` → `onesignal_service.dart:69`. |
> | Play → App info & performance → **Journaux de plantage** | Collectés, **collecte FACULTATIVE** | Depuis le correctif 3 : `applyCrashlyticsConsent()` appelle `setCrashlyticsCollectionEnabled`, l'interrupteur « Analyse d'usage » coupe les trois collecteurs, l'état est appliqué au démarrage, et un refus purge la file des rapports non envoyés. Garde `test/core/services/analytics_consent_test.dart`. |
> | Play → Activité dans l'appli → **Interactions, historique de recherche** | Collectées, **optionnelles** | L'interrupteur coupe réellement les deux SDK — `analytics_service.dart:96-108` ← `profile_screen.dart:735-745`. |
> | Play → **Identifiants de l'appareil ou autres identifiants** | Collectés (Analyses), **désactivables** | Même interrupteur (`analytics_service.dart:98`). Que couper Analytics couvre aussi l'identifiant publicitaire relève du comportement du SDK Google — **NON PROUVÉ** par le dépôt. |
> | Play → Contenu de l'appli → **« L'appli utilise-t-elle un identifiant publicitaire ? »** | **OUI**, motif « mesure d'audience » (pas de publicité) | `com.google.android.gms.permission.AD_ID` est dans le manifeste fusionné et aucun opt-out n'est posé (ligne AD_ID du tableau). |
> | Play → **Audio → Enregistrements vocaux** | **À trancher** (voies A/B ci-dessous) ; ne peut pas rester vide si `onDevice` reste `false` | `SpeechListenOptions` sans `onDevice` — `speech_input_service.dart:40-44` : l'audio peut sortir de l'appareil. |
> | Apple → Contact Info → **Email Address** | Collected, **Linked to the user**, App Functionality, **not** used to track | Même envoi OneSignal (`onesignal_service.dart:62-64`). |
> | Apple → Identifiers → **User ID** | Collected, **Linked** | `OneSignal.login` (`onesignal_service.dart:61`). |
> | Apple → Diagnostics → **Crash Data** | Collected, **NOT linked to the user**, not for tracking | Aucun `setUserIdentifier` sur Crashlytics ; les 6 usages sont des écritures. |
> | Apple → **Audio Data** (User Content / Sensitive selon le questionnaire) | Même arbitrage que la case Play Audio | Idem `speech_input_service.dart:40-44`. |
> | Apple → **aucune case ne change du fait d'`AD_ID`** | — | Permission Android ; l'IDFA / ATT n'est pas déclenché par elle. Le volet iOS n'a pas été audité ici : **non vérifié**, pas « rien à déclarer ». |

> **Ne pas sur-déclarer pour autant.**
> - **L'audio dicté n'arrive jamais chez KPB ni sur son backend** et aucun octet
>   audio n'est stocké (`speech_input_service.dart:37-39`). La formulation juste
>   est « audio traité par le service de reconnaissance de la plateforme, texte
>   seul conservé » — **pas** « KPB collecte des enregistrements vocaux ».
> - **Aucune case Localisation.** Le module `OneSignalLocation` est lié, d'où
>   `NSLocationWhenInUseUsageDescription` (`Info.plist:56-63`, ITMS-90683), mais
>   il n'est jamais appelé : `OneSignal.Location` n'apparaît nulle part dans
>   `lib/`. La politique le dit déjà (`app_translations.dart:638`).
> - **Les enregistrements de session ne sont pas du « User Content »** : textes
>   et images sont masqués à la capture (`main.dart:74-75`).
> - **Aucun téléversement de document actif en 49** (`app_config.dart:182`,
>   `case_tunnel_flow.dart:345-346`) : la ligne Photos/Files de §4 couvre
>   l'avatar et les fichiers d'anciennes builds, pas un envoi in-app vivant.
> - **Lecteur YouTube embarqué** — hors tableau parce qu'il ne fait entrer
>   aucune donnée chez KPB, mais il en fait sortir : `youtube_player_flutter`
>   (`pubspec.yaml:82`) rend une WebView `flutter_inappwebview` qui charge
>   `youtube-nocookie.com` et `https://www.youtube.com/iframe_api` dès la
>   construction du widget (`raw_youtube_player.dart:77`, `:254`), et les
>   vignettes `img.youtube.com` (`parcours.dart:80`, `catalog.dart:913`) sont
>   rendues dès l'accueil, y compris pour un visiteur non connecté
>   (`home_screen.dart:238-243`). Google reçoit IP + user-agent. **Aucun type de
>   données Play ne bascule pour autant** (l'IP n'est pas un type déclarable) :
>   ce qui change est la ligne destinataire de §2 et la politique publiée.

> **À trancher avant de cocher — deux réponses ne sont pas déductibles du dépôt.**
>
> 1. **PostHog.** Les deux lignes PostHog (événements, replay) ne sont vraies
>    que si le binaire 49 porte `POSTHOG_API_KEY`. Défaut compilé **vide**
>    (`app_config.dart:72-75`) et tout le câblage est sauté quand vide (`:87`,
>    `main.dart:66`) ; la CI injecte un secret qui peut lui-même être vide
>    (`.github/workflows/flutter-ci.yml:286`, `:367`) ; le préflight d'archive
>    iOS ne vérifie que la **présence du nom** de la variable
>    (`scripts/preflight-ios-archive.sh:70`), donc `POSTHOG_API_KEY=` vide passe
>    le contrôle. Vérifier la valeur du build effectivement livré : déclarer
>    replay + analytique PostHog sur un binaire sans clé serait une
>    sur-déclaration ; l'omettre sur un binaire avec clé, une sous-déclaration.
> 2. **Dictée vocale.** *Voie A* — forcer `onDevice: true`
>    (`speech_input_service.dart:40-44`) : iOS échoue **fermé**
>    (`SpeechToTextPlugin.swift:507-515`, l'utilisateur voit
>    `case_message_dictation_unavailable_*`, `case_tunnel_flow.dart:817-826`)
>    mais Android retombe **en silence** sur le recognizer réseau si
>    `SDK_INT < S` ou si aucun modèle local n'est disponible
>    (`SpeechToTextPlugin.kt:623-637`) : on pourra écrire « sur l'appareil quand
>    l'appareil le permet », jamais « converted to text on device » sec.
>    *Voie B* — garder `false` et le dire : déclarer Audio dans les deux
>    consoles et **nommer le service de reconnaissance de la plateforme** parmi
>    les destinataires, aujourd'hui absent de la liste
>    (`app_translations.dart:652-664`, EN `:3453` ; `confidentialite.html:64-69`).
>    Dans les deux cas, la ligne « Voice dictation » ci-dessus et
>    `docs/data-inventory.md:41` doivent cesser d'affirmer le contraire du code.
> 3. **Taille du binaire** : non mesurable ici, `flutter build apk --release`
>    refuse sans `android/key.properties` (garde volontaire). Les cases de §7
>    restent _TBD_ — ne rien y inventer.

> **Ce que la CI garde, et ce qu'elle ne garde pas.** Trois fois sur ce projet,
> le défaut était caché par l'outil censé le détecter ; ces cases-ci reposent
> donc sur une relecture humaine jusqu'à correction du harnais.
> - **Aucun test** n'assert `SpeechListenOptions.onDevice` (aucun fichier de
>   `test/` ne mentionne `onDevice`).
> - `test/core/privacy_disclosure_parity_test.dart:35-44` ne compare que des
>   **noms** de sous-traitants, jamais la charge déclarée : il est vert alors que
>   la politique dit « OneSignal : jeton de notifications »
>   (`app_translations.dart:657`, EN `:3458`, `confidentialite.html:64`) pendant
>   que l'app y envoie aussi un identifiant de compte, un e-mail et 4 attributs.
> - Le même test range `youtube.com` parmi les **non-processeurs** (`:48-49`),
>   ce qui a autorisé l'omission du lecteur embarqué.
> - Rien ne garde le **manifeste fusionné** : `AD_ID` n'est vérifiable que sur le
>   binaire de release (`aapt2 dump xmltree --file AndroidManifest.xml <aab>`),
>   jamais sur le manifeste source.

> **Divergence avec `data-inventory.md`, qui d'après l'en-tête de ce fichier
> l'emporte (lignes 10-13).** Deux de ses lignes sont réfutées par le code et
> doivent être corrigées **avant** de servir de source à un formulaire :
> - `docs/data-inventory.md:41` — « Convertie en texte **localement** » :
>   réfuté par `speech_input_service.dart:40-44`.
> - `docs/data-inventory.md:44` — fusionne analytique + replay + crash sous un
>   seul « Opt-out : Profil → « Analyse d'usage » » : réfuté par
>   `analytics_service.dart:96-108`, qui ne touche pas Crashlytics. Remplir la
>   case Play depuis cette ligne produirait une **sous-déclaration** (crash
>   annoncé désactivable alors qu'il ne l'est pas).

> **Où « vit » réellement la donnée.** Le projet Supabase compilé par défaut est
> `hijzqsljasbobjrjotjy` (`app_config.dart:197-199`) et l'API de production est
> `https://api.kpbeducation.cloud/api` (`app_config.dart:250`), servie par le VPS
> KPB (la politique le nomme : `app_translations.dart:654`). Leurs **régions** ne
> sont pas lisibles dans le dépôt : Supabase en `eu-west-3` (Paris) et VPS
> Hostinger en France ont été vérifiés hors dépôt (console Supabase / whois) —
> **NON PROUVÉ par le code**, à confirmer avant de remplir §2. Hébergement UE,
> responsable du traitement aux EAU, sous-traitants US nommés à part : les trois
> se cumulent, aucun n'annule l'autre.

---

## 2. Third-party processors

> **Responsable du traitement (à recopier tel quel dans les deux consoles, PR #214).**
> L'éditeur et le responsable du traitement est **KPB Global L.L.C-FZ**, société
> à responsabilité limitée de zone franche immatriculée auprès de la **Meydan
> Free Zone** (Meydan City Corporation, Émirat de Dubaï) sous la licence
> **n° 2537631.01**, siège Meydan Grandstand 6th floor, Meydan Road, Nad Al
> Sheba, Dubaï, EAU. **KPB Education est un service de cette société, pas une
> entité.** Publié dans l'app et sur le web : `app_translations.dart:624` (FR),
> `:3425` (EN), `web/public/confidentialite.html:17` ; CGU/loi applicable
> `app_translations.dart:696`, `:700`.
> — **raison** : la console et la politique liée doivent nommer la même entité,
> sinon la fiche est incohérente avec l'URL de politique qu'elle référence.
> Régime applicable : **décret-loi fédéral EAU n° 45 de 2021**, autorité **UAE
> Data Office**, for de Dubaï. L'analyse de transferts est donc **EAU → États-Unis**
> pour les sous-traitants US, alors que **l'hébergement est en UE** (voir les deux
> premières lignes du tableau).

| Processor | Region | Receives | Purpose | Linked to user | Used for tracking |
|---|---|---|---|---|---|
| **Own backend (NestJS/Postgres)** | **France** — VPS Hostinger, `api.kpbeducation.cloud` (`app_config.dart:250` ; `docs/DEPLOYMENT.md:11`) | All app data above | App functionality | Yes | No |
| **Supabase Auth** | **eu-west-3 (Paris)** — projet `hijzqsljasbobjrjotjy` (`app_config.dart:197-200`) | Email, Google OAuth identity, session tokens | Authentication | Yes | No |
| **Groq** (LLM) | **United States** (`llm.service.ts:53`) | **Deux surfaces, deux charges.** Coach : profil pseudonymisé sans nom + budget en **tranche** (`coach-prompt.builder.ts:28`, `:103-108`) + les messages libres de l'étudiant. Orientation : **projection close** `{currentLevel, targetCountryIds, fieldIds, preferredLanguage}` + les réponses au questionnaire (`orientation.service.ts:166-179`, `:190-194`, numérotation post-#216) — **plus jamais l'objet `profile` du client** | Generate AI coach replies / orientation explanations | No (pseudonymized) | No |
| **OneSignal** | US | Push token, external id = `UserProfile.id` (`onesignal_service.dart:61`), ~~l'adresse e-mail~~ (**retirée par le correctif 2** : `addEmail` supprimé, argument retiré du site d'appel `app_controller.dart`, garde `test/core/services/onesignal_no_email_test.dart`), et **4 étiquettes de profil** : `account_type`, `level`, `target_country`, `locale` (`:69` ; charge construite en `app_controller.dart:1908-1918`) | Push notifications **+ segmentation** | Yes | No |
| **Firebase Analytics** | Google (US) | App-instance id, device/OS, coarse region, interaction events ; **search terms** (`analytics_service.dart:434-436`) ; **+ identifiant publicitaire Android** — permission `AD_ID` dans le manifeste fusionné, aucun opt-out déclaré (voir note « AD_ID ») | Product analytics | Yes (app-instance) | No |
| **PostHog** | **United States** — `https://us.i.posthog.com` par défaut (`app_config.dart:79-82`) | Interaction events + screen views ; **le terme de recherche en clair**, miroité depuis Firebase (`analytics_service.dart:437`) ; backend user id (UUID) après login (`app_controller.dart:558-561`) ; **content-masked** session recordings ; device/OS. **Inerte si `POSTHOG_API_KEY` est vide** (`app_config.dart:72-87` ; garde `analytics_service.dart:45-46`) | Product analytics, session replay | Yes (UUID after login) | No |
| **Firebase Crashlytics** | Google (US) | Crash stack traces, device model, OS, app version. Aucun `setUserIdentifier` dans le dépôt | Stability/diagnostics | Pseudonymous | No |
| **Reconnaissance vocale de la plateforme — Apple / Google** | Apple, Google (US/global) | **L'audio dicté**, quand l'utilisateur touche « dicter » dans le tunnel de dossier. Le plugin ne rend à l'app que du **texte** (`speech_input_service.dart:37-39`) ; **aucun octet audio n'atteint KPB ni son backend**, et aucun identifiant KPB ne part avec l'audio | Dictée du message de demande d'accompagnement | No (aucun identifiant KPB transmis) | No |
| **Resend** | **United States** | Adresse e-mail (`to`) + objet + corps du message (`campaign-mail.service.ts:18-40`) | Transactional / campaign email | Yes | No |
| **Mautic** (self-hosted) | KPB VPS (France) | **7 champs, pas seulement l'e-mail** : e-mail, `firstname`/`lastname` découpés depuis `fullName`, `phone`, `mobile` (= numéro WhatsApp), `country` (pays de résidence), `preferred_locale` (`mautic.service.ts:99-115`) | Scholarship newsletter — **et depuis le correctif 6, SEULEMENT après consentement** : `resolveNewsletterAction` distingue « jamais consenti » (aucun appel) de « consentement retiré » (désinscription nécessaire), là où `null === false` faisait partir les données d'un utilisateur qui n'avait jamais dit oui | Yes | No |
| **CinetPay** | (provider region) | Intent id, montant, devise, description **+ `customer_email`, `customer_phone_number`, `customer_name`** (`cinetpay.adapter.ts:48-62`) | Paid accompaniment (checkout serveur, non atteignable depuis l'app 49) | Yes | No |
| **PayDunya** | (provider region) | Facture : description, montant, `intent_id` — **aucune donnée client** (`paydunya.adapter.ts:61-82`, aucune occurrence de `customer`) | Paid accompaniment (idem) | Pseudonymous (intent id) | No |
| **Embedded web — lecteur YouTube IFrame (Google)** | Google (US/global) | **Adresse IP + user-agent + identifiant de la vidéo**, à chaque ouverture du lecteur (`youtube-nocookie.com` et `https://www.youtube.com/iframe_api`) et à chaque chargement de vignette (`img.youtube.com`) | Lecture vidéo (Parcours, vidéos de bourses) et vignettes | Pseudonymous (IP) | per Google |
| **WhatsApp / Meta** — remise externe, **pas un sous-traitant de KPB** | Meta (US/global) | L'URL `wa.me` ouverte par l'app : numéro du conseiller + **texte prérempli de contexte catalogue** (référence de dossier, programme, école, pays, service — **jamais le nom ni l'e-mail** : `whatsapp_utils.dart:18-61`, `:64-81`). **Ensuite, ce que l'étudiant y envoie lui-même**, dont ses documents depuis M2 | Contact conseiller ; **canal de remise des pièces** depuis le masquage du téléversement | n/a (external) | per Meta |

> ✅ **Lot 11 — le serveur ne recopie plus le nom civil dans les invites Groq.**
> `POST /tools/cv-summary` et `POST /tools/personalize-letter` *acceptent* encore
> un champ `name` (le PDF l'imprime) mais `tools.service.ts` n'interpole plus
> `Nom : ${dto.name}`. Ces routes, plus document-review et les deux alias POST
> d'orientation, sont derrière `AiConsentGuard` (403 `ai_consent_required` /
> `guardian_consent_required` ; `orientation.controller.ts:28-29`, `:36-37`).
> **Ne pas déployer ce backend en production avant que la build 49 soit chez les
> testeurs** — la 48 renverrait 403 avec « vérifiez votre connexion ». Le masque
> client `KPB_AI_TOOLS_ENABLED=false` reste en place jusqu'à ce basculement couplé.

> ✅ **#216 — la surface orientation a été refermée, et une garde la verrouille.**
> Le lot 11 n'avait nettoyé que `/tools` : `orientation.service.ts` recopiait
> encore l'objet `profile` du client — **nom civil inclus** — dans l'invite, alors
> que l'écran de consentement affiché juste avant promet le contraire mot pour mot
> (« Ton nom civil n'est pas recopié dans l'invite »). Corrigé : la charge est
> désormais une **liste close** (`orientation.service.ts:166-179`) reprise telle
> quelle en `:190-194`, et le test `orientation.prompt-privacy.spec.ts` échoue si
> un champ ajouté au corps de la requête atteint l'invite.
> — **raison de la case « Groq — Linked to user : No (pseudonymized) »** : après
> #216 aucune des deux surfaces atteignables n'envoie d'identité ; avant #216
> cette case était fausse.
> À ne pas confondre : le **client** poste toujours `fullName` vers **notre**
> backend (`app_controller.dart:826-834`). C'est un traitement KPB, pas un
> transfert au tiers — la ligne 1 du §1 reste exacte.
> ⚠️ Numérotation post-#216 (commit `5555111`, présent sur `main`, **absent de la
> branche docs** où ce document est rédigé).

> 🎙️ **Dictée vocale — la ligne du §1 est fausse et doit être corrigée avec cette section.**
> L'unique appel à `listen()` du dépôt ne passe pas `onDevice`
> (`speech_input_service.dart:36-45`) ; le défaut du paquet est `false`
> (`speech_to_text_platform_interface-2.4.0/lib/speech_to_text_platform_interface.dart:78-83`,
> transmis au natif en `method_channel_speech_to_text.dart:109`), et `false`
> signifie explicitement « on device **et** network recognition » : côté iOS
> `requiresOnDeviceRecognition` n'est jamais mis à vrai
> (`speech_to_text-7.4.0/darwin/.../SpeechToTextPlugin.swift:557-559`), côté
> Android `EXTRA_PREFER_OFFLINE` n'est jamais posé et le recognizer réseau par
> défaut est utilisé (`SpeechToTextPlugin.kt:687-689`, `:623-637`). Paquet
> réellement embarqué : `pubspec.yaml:74` → `pubspec.lock` 7.4.0,
> `ios/Podfile.lock:272`.
> Atteignable **sans aucun drapeau** en 49 : `case_tunnel_flow.dart:53-59`
> (étape 3 = message), `:357` (`case 3:` sans condition, à comparer au `case 2:`
> documents gardé en `:345`), `:762`, `:775`, `:844` ; permissions déclarées des
> deux côtés (`ios/Runner/Info.plist:52-55` ; `android/app/src/main/AndroidManifest.xml:7`).
> **À corriger dans le même passage :** `docs/STORE_READINESS.md:35` (« Converted
> to text **on device** ») et `docs/data-inventory.md:41` (« Convertie en texte
> **localement** ») affirment un fait que le code démentirait devant un
> examinateur. En revanche la politique publiée, elle, ne promet rien de tel
> (`app_translations.dart:635`, `:3436` ; `web/public/confidentialite.html:31`
> disent seulement « le micro convertit votre voix en texte ») — l'erreur est
> **documentaire**, pas contractuelle.
> **VOIE A RETENUE par le correctif 1.** L'app demande désormais la
> reconnaissance LOCALE (`onDevice: true`) et, quand la plateforme la refuse,
> elle ne bascule pas en silence : la session échoue et l'envoi au service du
> téléphone n'a lieu qu'après un accord explicite de l'étudiant
> (`allowPlatformService`). Garde `test/core/services/speech_input_on_device_test.dart`.
> Donc : **par défaut, aucun audio ne quitte l'appareil.**
> · Play → Data Safety → **Audio → Voice or sound recordings : NON collecté par
> défaut.** Si vous préférez déclarer le cas de l'accord explicite, cochez
> « collecté, transfert FACULTATIF pour l'utilisateur ».
> · **RÉSERVE, à écrire noir sur blanc :** la garantie n'est pas égale sur les
> deux plateformes. Sur iOS le greffon refuse la session si la reconnaissance
> locale n'est pas disponible — contrat dur. Sur Android, `onDevice` n'est
> qu'une préférence (`EXTRA_PREFER_OFFLINE`) et le repli réseau est INVISIBLE
> depuis Dart. Ne pas écrire « jamais transmis » : écrire « la reconnaissance
> locale est demandée à votre téléphone ».
> État d'avant le correctif, conservé parce qu'il dit d'où venait le risque :
> l'audio quittait l'appareil vers le recognizer de la plateforme, et
> l'exemption « on device » n'était adossée à aucun code.
> · Apple → App Privacy → **Audio Data : collectée, non liée à l'utilisateur, pas
> de tracking** — raison : même transmission, mais aucun identifiant KPB ne
> l'accompagne.
> · Politique §5 (`app_translations.dart:652`, EN `:3453`) : **nommer le service de
> reconnaissance vocale d'Apple / de Google** — raison : il ne figure aujourd'hui
> sous aucun titre dans la liste des destinataires.
> **Ne pas sur-déclarer** : la formulation correcte est « audio traité par le
> service de reconnaissance de la plateforme, texte seul conservé », **pas** « KPB
> collecte des enregistrements vocaux » (`speech_input_service.dart:37-39` ne lit
> que `result.recognizedWords`, aucun octet audio n'est stocké).
> Alternative assumée : forcer `onDevice: true` rendrait vraie la phrase déjà
> écrite — mais iOS échouerait fermé (`SpeechToTextPlugin.swift:507-515`) et
> Android retomberait **silencieusement** sur le recognizer réseau sous Android 12
> ou sans modèle local (`SpeechToTextPlugin.kt:623-637`) : la phrase devrait alors
> dire « sur l'appareil quand l'appareil le permet », pas « on device » sec.

> 📣 **OneSignal — la ligne « jeton de notifications » est fausse par omission.**
> Le chemin est actif par défaut dans la 49 : App ID compilé non vide
> (`app_config.dart:58-64`), `initialize()` inconditionnel (`main.dart:120`), puis
> `syncOneSignalIdentity()` déclenché en trois points — `main.dart:125-126`
> (démarrage à froid d'un utilisateur connecté), `app_controller.dart:554`
> (chaque connexion), `:632` (fin d'onboarding). **Aucun consentement ne le
> conditionne** : `setCollectionEnabled` ne touche que Firebase et PostHog
> (`analytics_service.dart:97-108`), et un refus de l'invite système n'arrête rien
> (`onesignal_service.dart:43-50` rend `Future<void>` et jette le résultat).
> Cases qui changent :
> · Play → **Informations personnelles → Adresse e-mail : « Partagée »**, finalité
> « Fonctionnalité de l'application » — raison : `OneSignal.User.addEmail`
> (`onesignal_service.dart:62-64`) transmet `profile.email` à un tiers.
> · Play → **Identifiants → ID utilisateur : « Collecté » ET « Partagé »** —
> raison : `OneSignal.login(profile.id)` (`:61`).
> · Play → rattacher les **4 étiquettes** (`account_type`, `level`,
> `target_country`, `locale`) à « Informations personnelles → Autres informations »
> — raison : ce sont des attributs de profil transmis à un tiers
> (`app_controller.dart:1911-1916`).
> · Apple → **Contact Info → Email Address** et **Identifiers → User ID**, « Linked
> to the user », « App Functionality » — raison : mêmes appels.
> · **Aucune case « Localisation »** — raison : le module OneSignalLocation est lié
> (d'où `NSLocationWhenInUseUsageDescription`, `ios/Runner/Info.plist:56-63`) mais
> jamais appelé ; aucune occurrence de `OneSignal.Location` dans `lib/`.
> · **Ne pas cocher « Used to Track You »** — raison : rien ne lie ces données à
> des données tierces à des fins publicitaires cross-app.
> Politique à réécrire en conséquence : `app_translations.dart:657` (« jeton de
> notifications ») et `:3458` — sinon la fiche Play et la politique se
> contredisent, motif de rejet « Data Safety declaration inconsistent with privacy
> policy ». Le serveur, lui, n'envoie aucune PII supplémentaire
> (`onesignal-sender.service.ts:61-68` : `include_aliases.external_id` seulement) —
> la charge prouvée est **côté client**, avec un App ID compilé : elle ne dépend
> d'aucune variable d'environnement.

> ✉️ **Mautic — « (email) after opt-in » est faux deux fois.**
> (1) La charge est de 7 champs (`mautic.service.ts:99-115`), pas l'e-mail seul.
> (2) L'envoi **précède** le test d'opt-in : `syncContact` appelle `upsertContact`
> en `:76`, **avant** le branchement `if (optIn)` en `:77` ; et
> `newsletter-sync.service.ts:48` compare `newsletterSyncedOptIn ===
> newsletterOptIn` alors que le champ est **nullable sans défaut**
> (`schema.prisma:373`, contre `newsletterOptIn @default(false)` en `:371`) — donc
> `null === false` échoue et un utilisateur **qui n'a jamais consenti** voit ses
> 7 champs partir chez Mautic, puis être mis en DNC.
> **Inerte aujourd'hui** : `isConfigured` exige 4 variables
> (`mautic.service.ts:49-53`) qui ne sont posées nulle part dans le dépôt
> (`docker-compose.yml:62-65`, `.env.example:67-70` toutes vides) et la méthode
> sort en `:63-64`. — **raison de garder la ligne au tableau** : le code est livré,
> une seule variable d'environnement l'active ; mais **ne pas** écrire « after
> opt-in » dans le formulaire tant que `:76` précède `:77`.

> 💳 **PayDunya / CinetPay — à garder, avec le motif exact.**
> La build 49 ne peut joindre aucun des deux : `PaymentsController` /
> `AdminPaymentsController` ne sont **pas** enregistrés (`app.module.ts:95-98`), la
> méthode cliente de checkout a été retirée (`app_api_client.dart:1555-1557`),
> l'app n'appelle que `POST /me/purchases/whatsapp` (`:1565`) et `GET /me/purchases`
> (`:1576`), et le CTA est WhatsApp (`service_packages_screen.dart:17-18`).
> **Mais le motif « aucun contrôleur enregistré » est incomplet** : `POST /me/purchases`
> **est** enregistré (`app.module.ts:215` ; `service-packages.controller.ts:50`,
> `:57-79`) et mène à `createIntent` avec **`'cinetpay'` en défaut**
> (`service-packages.service.ts:148-150`), après avoir construit un client
> `{email, phone, fullName}` (`:126-130`). Ce qui bloque réellement est la **garde
> d'environnement** (`payments.service.ts:87-91` ; clés exigées en
> `cinetpay.adapter.ts:28-38` et `paydunya.adapter.ts:26-43`, déclarées nulle part
> dans le dépôt) — barrière renversable par une variable, sans toucher à l'app.
> Cases :
> · **« Achats intégrés » (Apple 3.1.1 / 3.1.3, équivalent Play) : ne PAS y faire
> figurer ces deux prestataires** — raison : aucun SDK d'achat au `pubspec.yaml`,
> aucun checkout client, remise conseiller par WhatsApp ; `docs/store-listing-copy.md:437`
> répond déjà « Aucun ».
> · **« Destinataires / sous-traitants » : les GARDER** — raison : les adaptateurs
> sont livrés dans le backend déployé et la route appelante est enregistrée avec
> `'cinetpay'` en défaut ; en outre `test/core/privacy_disclosure_parity_test.dart:42-43`
> fait échouer la CI si les mentions disparaissent tant que les adaptateurs vivent
> dans `backend/src`.
> · Colonne « Receives » **dissociée** — raison : CinetPay reçoit e-mail, téléphone
> et nom (`cinetpay.adapter.ts:58-60`), PayDunya ne reçoit **aucune** donnée client
> (`paydunya.adapter.ts:61-82`). Les fusionner sur-déclarait PayDunya et
> sous-déclarait CinetPay.
> Défaut annexe (hors formulaire) : la ligne `ServicePurchase` est créée en
> `service-packages.service.ts:133` **avant** `createIntent` en `:148` — un 400
> « not configured » laisse une ligne orpheline `pending_payment`.

> ▶️ **Embedded web — la ligne se trompait de tiers dans les deux sens.**
> **Sur-déclaration** : `webview_flutter` est déclaré (`pubspec.yaml:72`) mais n'a
> **aucun** site d'appel dans `lib/` ; Kayak n'est pas embarqué, c'est un **proxy
> serveur** (`backend/src/modules/kayak/kayak.controller.ts:9-11` : « the Kayak
> secret and affiliate tracking stay server-side ») et la surface est de toute
> façon masquée (`app_config.dart:116-119`, défaut `false` ; entrée profil gardée
> en `profile_screen.dart:1264`).
> **Sous-déclaration** : la seule vue web réellement embarquée est le **lecteur
> YouTube** (`pubspec.yaml:82` → `youtube_player_flutter`, qui rend un
> `InAppWebView` : `youtube_player_flutter-9.1.3/lib/src/player/raw_youtube_player.dart:72`,
> `baseUrl` `youtube-nocookie.com` en `:77`, script `www.youtube.com/iframe_api`
> chargé dès la construction du widget en `:254` — **ouvrir l'écran suffit**, sans
> toucher « play »). Trois chaînes sans drapeau : `parcours_screen.dart:796`/`:832`,
> `parcours_feed_screen.dart:191`/`:258`, `scholarship_video_player_screen.dart:40`/`:87`
> (depuis `scholarship_detail_screen.dart:147-157`). Vignettes dérivées en
> `parcours.dart:77-82` et `catalog.dart:913`, rendues jusque sur l'accueil pour un
> **visiteur non connecté** (`home_screen.dart:238-243`, commentaire « Shown to
> guests too » ; `story_of_week_card.dart:100`) lorsque le récit ne porte pas de
> vignette propre.
> Cases :
> · Apple → **Third-Party Partners / contenu tiers embarqué : déclarer Usage Data /
> Identifiers via partenaire** — raison : le lecteur transmet IP et user-agent à
> Google à l'ouverture.
> · Apple → classification d'âge, « accès web illimité » : **la réponse reste NON**,
> mais son fondement change — raison : l'embed est **figé sur YouTube**, pas sur des
> « partner/price-comparison URLs ». **`§5` lignes 159-160 est à corriger en
> conséquence** (hors périmètre de cette section).
> · Play → **aucune case de type de données ne bascule** — raison : l'adresse IP
> n'est pas un type déclarable dans la taxonomie Play et l'embed n'ajoute aucun
> type collecté. Ne rien cocher de plus.
> · **Kayak ne doit apparaître nulle part** comme destinataire de l'app — raison :
> secret et tracking affilié restent serveur, surface masquée.

> 🟢 **WhatsApp / Meta — nommé comme remise externe, pas comme sous-traitant.**
> C'est le canal de sortie de la 49 et, depuis M2, le remplaçant du téléversement
> (`app_config.dart:182-188`, `KPB_DOCUMENT_UPLOAD_ENABLED` défaut `false`) ; la
> politique in-app le dit déjà (`app_translations.dart:636`). Le texte prérempli ne
> porte que du contexte catalogue (`whatsapp_utils.dart:18-61`) — **ni nom, ni
> e-mail**.
> — **raison de la ligne** : c'est désormais Meta qui reçoit les pièces du dossier ;
> l'omettre laisserait croire que les documents ne quittent jamais l'app.
> — **raison de ne PAS le compter comme sous-traitant** : l'app ne transmet à Meta
> qu'une URL ouverte par l'OS ; tout le reste est envoyé par l'étudiant lui-même
> dans sa propre conversation. **Ne pas** lui attribuer de finalité de traitement
> KPB, et **ne pas** cocher de type de données Play à ce titre.

> 📊 **PostHog — la ligne est exacte OU sur-déclarée, selon un fait non lisible ici.**
> Tout le câblage (setup, observateur de navigation, enveloppe de replay, chaque
> miroir) est sauté quand la clé est vide, et **le défaut compilé est vide**
> (`app_config.dart:72-75`, `:87` ; garde `analytics_service.dart:45-46`, `:55-56`).
> La CI injecte `secrets.POSTHOG_API_KEY` (`.github/workflows/flutter-ci.yml:189`,
> `:286`, `:367`) mais le dépôt ne dit pas si le secret est renseigné, et le
> préflight iOS ne vérifie que **la présence du nom** de la variable
> (`scripts/preflight-ios-archive.sh:70` : `POSTHOG_API_KEY=` vide passe le
> contrôle).
> — **raison de trancher avant de cocher** : déclarer le replay sur un binaire où
> PostHog est inerte est une **sur-déclaration**, l'omettre sur un binaire où la clé
> est posée est une **sous-déclaration**. Vérifier la valeur effective du secret
> pour le binaire 49, puis cocher.
> Une fois la clé posée : provisionner le projet « KPB Education », et activer
> **PostHog → project settings → « Record user sessions »** (le replay est dark
> côté serveur sans cela, même avec `sessionReplay: true`). Masquage activé par
> défaut — le garder pour cette app.

> 🆔 **AD_ID (Android) — une case de la fiche Play change, pas une ligne du tableau.**
> `firebase_analytics` (`pubspec.yaml:83`) fait entrer
> `com.google.android.gms.permission.AD_ID` (+ `ACCESS_ADSERVICES_AD_ID`,
> `ACCESS_ADSERVICES_ATTRIBUTION`) dans le manifeste fusionné, attribué par le
> merger au seul `play-services-measurement-api:23.2.0`
> (`build/app/intermediates/manifest_merge_blame_file/release/processReleaseMainManifest/manifest-merger-blame-release-report.txt:146-148`)
> et présent dans le manifeste empaqueté
> (`build/app/intermediates/packaged_manifests/release/processReleaseManifestForPackage/AndroidManifest.xml:75-77`).
> Aucun opt-out : `android/app/src/main/AndroidManifest.xml` ne contient que deux
> `meta-data` (`:27-29`, `:53-55`), pas de `google_analytics_adid_collection_enabled`,
> pas de `tools:node="remove"`.
> · Play → « Contenu de l'application » → **Identifiant publicitaire : OUI**,
> motif « mesure d'audience / analytics » — raison : Play détecte la permission dans
> le bundle et refuse une réponse « non ».
> · Play → Data Safety → **Identifiants de l'appareil ou autres identifiants :
> collecté, non partagé, finalité Analyses, et « les utilisateurs peuvent choisir »
> COCHÉ** — raison : l'interrupteur de profil coupe réellement la collecte
> (`profile_screen.dart:741` → `app_controller.dart:503-507` →
> `analytics_service.dart:98`). Ne pas déclarer cette donnée comme *obligatoire*.
> · **Aucune case Apple ne change de ce fait** — raison : la permission est Android
> seulement ; le volet IDFA/ATT n'a pas été audité ici (donc : non vérifié, pas
> « rien à déclarer »).
> ⚠️ **Réserve de preuve** : les artefacts lus portent `versionCode="45"` et
> `package="com.kpbeducation.app"` (lignes 3-4), antérieurs à la restauration
> d'identité (#165) : ils prouvent le mécanisme, pas le binaire 49. Rattachement au
> 49 : dépendance inchangée depuis, aucune exclusion Gradle, aucun opt-out ajouté.
> La re-preuve exigerait `flutter build apk --release`, **impossible sans
> `android/key.properties`** (garde volontaire) — non lancé.

> 💥 **Crashlytics — l'interrupteur « Analyse d'usage » ne le coupe pas.**
> `setCrashlyticsCollectionEnabled` n'existe **nulle part** dans le dépôt (0
> occurrence), ni en Dart, ni dans `AndroidManifest.xml`, ni dans `Info.plist` ;
> `setCollectionEnabled` ne touche que Firebase Analytics et PostHog
> (`analytics_service.dart:97-108`), et les collecteurs sont armés
> inconditionnellement au démarrage (`main.dart:49-54`) **avant** la relecture du
> consentement (`main.dart:110`).
> · Play → « Journaux de plantage » → **collecte OBLIGATOIRE, « les utilisateurs ne
> peuvent pas désactiver »** — raison : aucun interrupteur n'existe dans le code.
> · Play → « Interactions dans l'appli » / « Historique de recherche » →
> **OPTIONNELLE** — raison : `analytics_service.dart:97-108` +
> `profile_screen.dart:741`. Les deux lignes doivent donc répondre **différemment** :
> une fiche qui coche « obligatoire » partout, ou « optionnel » partout, est fausse.
> · Apple → **Diagnostics → Crash Data, « non liée à l'utilisateur », pas de
> tracking** — raison : aucun `setUserIdentifier` dans le dépôt.
> Ambiguïté rédactionnelle à lever dans la politique : `app_translations.dart:667`
> propose de « refuser l'analytique » juste après avoir nommé « Firebase / Google
> (Analytics, **Crashlytics**) » en `:658`. La copie in-app, elle, ne sur-promet pas
> (`:1520-1522` ne mentionne que l'usage et les enregistrements) ; c'est
> `docs/data-inventory.md:44` qui affirme à tort un opt-out crash.

> **Action before submission (mise à jour).**
> · Régions : **répondu** — Supabase `eu-west-3` (Paris), backend VPS Hostinger en
> France, Mautic sur le même VPS. Les sous-traitants US restent nommés à part
> (Groq, PostHog, OneSignal, Resend, Firebase/Google, YouTube). L'analyse de
> transferts est **EAU → US** (responsable émirien), pas UE → US.
> · Termes de recherche : si l'équipe refuse de déclarer « User Content / Search
> History », **il faut DEUX suppressions, pas une** —
> `analytics_service.dart:436` (Firebase) **et** `:437` (miroir PostHog avec
> `search_term` brut). Le §1 note en outre une persistance locale de l'historique :
> à traiter au §1, hors de cette section.

> 🧪 **Gardes manquantes — à poser avec ces corrections (motif déjà vu trois fois
> sur ce dépôt : l'outil censé détecter cachait le défaut).**
> · `test/core/privacy_disclosure_parity_test.dart:49` classe `youtube.com` parmi
> les **non-processeurs**, et le commentaire `:46-47` y range explicitement
> « WebView » — c'est l'affirmation fausse qui a autorisé l'omission ; la garde
> saute alors l'exigence en `:199`. À déplacer vers `_processorSuffixToToken`
> (`:35-44`).
> · Le scanner ne lit que `lib` + `backend/src` : `youtube-nocookie.com`, déclaré
> **dans le paquet pub**, lui est structurellement invisible.
> · La parité ne compare que des **noms** de destinataires, jamais la **charge**
> déclarée : d'où une ligne OneSignal verte alors qu'elle omet e-mail, id
> utilisateur et 4 étiquettes.
> · Aucun test n'assert `SpeechListenOptions.onDevice` ; aucun test ne garde le
> manifeste fusionné (AD_ID) ; aucun spec n'assure que `PaymentsController` reste
> non enregistré ni qu'aucune route enregistrée n'atteigne `createIntent` (le seul
> spec existant couvre la branche WhatsApp : `service-packages.service.spec.ts:64`).

## 3. App Store — Privacy "nutrition labels"

For each type: **Linked to the user? Used for tracking? Purpose.**
Tracking is **No** everywhere — raison : aucun SDK publicitaire, d'attribution ou
de MMP n'est déclaré dans `pubspec.yaml` (ni `google_mobile_ads`, `appsflyer`,
`adjust`, `branch`, `facebook_app_events`, `applovin`), et rien dans `lib/` ne
joint nos données à des données tierces à des fins publicitaires. La permission
Android `AD_ID` est un sujet **Play** (§4) et ne déclenche pas l'ATT d'Apple ; la
surface IDFA iOS n'a pas été réauditée dans cette passe, donc cette ligne repose
sur l'absence de tout SDK publicitaire, pas sur un audit du `Info.plist`.

Chaque ligne porte la **raison** de la réponse, pour que le prochain lecteur
sache pourquoi la case est cochée ainsi.

| Apple data type | Collected | Linked | Tracking | Purpose | Pourquoi cette réponse (code) |
|---|---|---|---|---|---|
| Contact Info — Name, Email | Yes | Yes | No | App Functionality, Account management | `app_controller.dart:1996-1999` pousse `fullName` + `email` ; les deux sont **obligatoires** à l'inscription (`onboarding_screen.dart:1106,1115,1127`, validateur `_req`). |
| Contact Info — Phone number (+ WhatsApp) | Yes | Yes | No | App Functionality | `app_controller.dart:1999-2000`. **Optionnel**, pas requis : le champ téléphone n'a aucun validateur et `_buildProfile` retombe sur la valeur existante ou `''` quand il est vide (`onboarding_screen.dart:396-398`). |
| Contact Info — **Other User Contact Info (nom + contact du tuteur)** | Yes | Yes | No | App Functionality (consentement du tuteur pour mineur déclaré) | **Ligne ajoutée** : ce sont les coordonnées d'un **tiers**. `app_controller.dart:2021-2023` transmet `guardianName` et `guardianContact` ; stockés en colonnes dédiées (`backend/prisma/schema.prisma:388-390`) ; exigés pour un mineur déclaré (`onboarding_screen.dart:483-486`). §4 le portait déjà, §3 l'omettait. |
| Sensitive Info — *none* | No | — | — | — | Aucun champ origine / religion / orientation / santé dans le modèle de profil (`lib/app/core/models/user.dart:73-112`). |
| User Content — Photos or Videos (photo de profil) | Yes | Yes | No | App Functionality | **Le seul envoi de fichier prouvé et inconditionnel** de la 49 : `profile_screen.dart:440` → `profile_avatar.dart:409` → `app_api_client.dart:171-190` (`POST /profiles/me/avatar`), sans aucun drapeau. Pas d'EXIF/GPS : `requestFullMetadata: false` (`profile_avatar.dart:387`). |
| User Content — Customer Support (messages de dossier) | Yes | Yes | No | App Functionality | Messages de dossier envoyés au backend et persistés ; l'étape « message » du tunnel est atteignable sans drapeau (`case_tunnel_flow.dart:357-362`). |
| User Content — Other (messages au coach IA → Groq, US) | Yes | Yes | No | App Functionality | Chat atteignable en 49, mais **derrière un consentement explicite** : `ai_consent.dart:58-63` n'ouvre l'écran qu'après `ensureAiConsent`. Groq ne reçoit **aucun identifiant** : ni nom (`backend/src/modules/coach/coach.service.ts:208-216`) et budget réduit à une tranche (`coach-prompt.builder.ts:25-40`, appelé `:94,:127`). |
| User Content — **Audio Data (dictée vocale)** | Yes — *sous réserve du choix A/B, voir la note « Audio »* | No | No | App Functionality | **Ligne ajoutée.** Le bouton « dicter » est atteignable sans aucun drapeau (`case_tunnel_flow.dart:357-362` puis `:762` et `:843`), et l'unique appel `listen()` du dépôt ne passe pas `onDevice` (`speech_input_service.dart:36-45`) : le défaut du paquet est `false`, c'est-à-dire « reconnaissance sur l'appareil **et** réseau », donc l'audio peut partir vers le service de reconnaissance d'Apple ou de Google. Linked = **No** : aucun identifiant KPB ne l'accompagne, KPB ne lit que `result.recognizedWords` (`:37-39`) et ne stocke aucun octet audio. |
| User Content — Other (documents de dossier / fichiers) | **No en build 49**, sauf Success Lab — voir la note « Fichiers » | — | — | — | L'envoi de pièces de dossier est masqué à **deux** niveaux : interface (`case_tunnel_flow.dart:345` remplace l'étape par un renvoi WhatsApp ; `case_detail_screen.dart:435,486-487`) **et** point d'étranglement du contrôleur (`app_controller.dart:1317` sort avant `_uploadRemoteCaseDocument`, `:1920-1928`). Le scanner reste local : partage par la feuille de l'OS (`document_scanner_screen.dart:69-71`) et `document_upload_service.dart` n'a aucun appel réseau. |
| Identifiers — User ID | Yes | Yes | No | App Functionality, Analytics | `OneSignal.login(profile.id)` (`onesignal_service.dart:61` ← `app_controller.dart:1909`) et `Posthog().identify` (`analytics_service.dart:72`). **Transmis en plus à un tiers** — voir la note « OneSignal ». |
| Identifiers — Device ID | Yes | Yes | No | App Functionality, Analytics | Identifiant d'instance Firebase (`pubspec.yaml:83`) + identifiant d'abonnement OneSignal : `main.dart:120` initialise OneSignal **sans condition** et l'App ID compilé par défaut n'est pas vide (`app_config.dart:58-64`). |
| Usage Data — Product Interaction, Search History | Yes | Yes | No | Analytics, App Functionality | La recherche est du texte libre : `analytics_service.dart:434-437` (`logSearch` + miroir `search_term`) appelé par `app_controller/search.dart:44`. Désactivable : `profile_screen.dart:735-745` → `app_controller.dart:503-508` → `analytics_service.dart:96-108`. |
| Diagnostics — Crash Data, Performance Data | Yes | **No (non lié)** | No | App Functionality (stabilité) | **Changement** : aucun `setUserIdentifier` dans tout `lib/` → le rapport ne porte pas d'identifiant KPB (seules écritures : `main.dart:50,52`, `app_logger.dart:39`, `sync_telemetry.dart:96`). Et la collecte **n'est pas désactivable** : `main.dart:49-54` arme les collecteurs avant toute lecture de consentement (relu seulement `:110`), et `setCrashlyticsCollectionEnabled` n'existe nulle part dans le dépôt. |
| Health, Financial Info, Location (precise/coarse), Browsing History, Contacts | No | — | — | — | Aucun moyen de paiement collecté : `POST /referrals/withdraw` part **sans corps** (`app_api_client.dart:825`), le compte de retrait n'est qu'**affiché masqué** depuis le serveur (`ambassador_screen.dart:822-825`), aucun SDK d'achat dans `pubspec.yaml`, contrôleurs de paiement non enregistrés (`backend/src/app.module.ts:95-98`). Aucun appel de géolocalisation dans `lib/` — la chaîne iOS existe seulement parce que le module de localisation OneSignal est lié, et le dit (`ios/Runner/Info.plist:62-63`). Aucune permission contacts (`android/app/src/main/AndroidManifest.xml:1-7`). |

> "Budget" is a self-reported figure for guidance, stored as profile data
> (`app_controller.dart:2008,2015-2016`), **not** a financial account — declare
> under App Functionality, not "Financial Info". Ce qui part vers Groq n'est
> qu'une **tranche** (`coach-prompt.builder.ts:25-40`).
>
> **Session replay (PostHog) — déclaration CONDITIONNELLE.** Ne la déclarez que
> si la 49 livrée porte une `POSTHOG_API_KEY` non vide. `posthogEnabled` vaut
> `posthogApiKey.trim().isNotEmpty` avec un défaut compilé **vide**
> (`app_config.dart:72-87`) ; `main.dart:66` saute la configuration et `:176` ne
> monte `PostHogWidget` (autocapture + rejeu) que si le drapeau est vrai. La CI
> passe `--dart-define=POSTHOG_API_KEY=${{ secrets.POSTHOG_API_KEY }}`
> (`.github/workflows/flutter-ci.yml:189,286,367`) : un secret non défini donne
> une valeur **vide**, et le préflight iOS ne vérifie que la présence du NOM
> (`scripts/preflight-ios-archive.sh:70`, `grep -q 'POSTHOG_API_KEY='`), donc une
> valeur vide passe le contrôle. Le dépôt ne peut pas trancher : celui qui
> construit la 49 doit le dire. **Si la clé est posée :** déclarer sous **Usage
> Data — Product Interaction** (Apple n'a pas de type « enregistrement d'écran »),
> Linked Yes, Tracking No ; le contenu est masqué (`main.dart:78-80`,
> `maskAllTexts` + `maskAllImages`) donc ce n'est pas du "User Content" ;
> désactivable (`analytics_service.dart:102-106`).
>
> **OneSignal reçoit plus qu'un jeton de notification.** À déclarer comme
> collecté **par un tiers** : Contact Info → Email Address et Identifiers →
> User ID, finalité App Functionality (ajouter Product Personalization si les
> campagnes segmentent sur les étiquettes). Code : `onesignal_service.dart:61-70`
> envoie `login(userId)`, `addEmail(email)` et
> `addTags{account_type, level, target_country, locale}`, alimentés par
> `app_controller.dart:1909-1916` ; trois points d'entrée sans consentement —
> démarrage à froid (`main.dart:125-126`), connexion (`app_controller.dart:554`),
> fin d'onboarding (`:632`) — et l'interrupteur d'analyse ne touche pas OneSignal
> (`analytics_service.dart:96-108`). Ne **pas** cocher « Used to Track You » :
> rien ne joint ces données à des données tierces pour la publicité. Retirer
> `addEmail` (`onesignal_service.dart:62-64`) supprimerait purement la case
> Email.
>
> **Audio — le pack boutique affirme aujourd'hui un fait que le code démentirait.**
> §1 ligne 35 (« Converted to text **on device** ») et `docs/data-inventory.md:41`
> (« convertie en texte **localement** ») ne correspondent pas à
> `speech_input_service.dart:36-45`. Deux voies exclusives, à trancher avant de
> remplir : **(A)** passer `onDevice: true` — mais iOS échoue alors fermé quand
> le modèle local manque (l'utilisateur voit
> `case_message_dictation_unavailable_*`, `case_tunnel_flow.dart:817-826`) et
> Android peut retomber sur le service réseau sous API 31, donc la phrase devra
> être **qualifiée**, pas restaurée telle quelle ; **(B)** garder le comportement
> actuel et déclarer Audio Data comme dans le tableau. Dans les deux cas, ne
> jamais écrire « KPB collecte des enregistrements vocaux » : aucun octet audio
> n'atteint KPB ni son backend.
>
> **Contenu tiers embarqué — Google / YouTube.** Les lecteurs vidéo Parcours et
> bourses sont un embed YouTube dans une WebView (`pubspec.yaml:82`
> `youtube_player_flutter` → transitif `flutter_inappwebview`,
> `pubspec.lock:473-474`), et les vignettes tapent `img.youtube.com`
> (`lib/app/core/models/parcours.dart:80`, `catalog.dart:913`), y compris sur la
> carte d'accueil visible **sans connexion** (`home_screen.dart:236-243`,
> « Shown to guests too »). Google reçoit donc IP + user-agent + identifiant de
> vidéo. À déclarer au titre du contenu / des partenaires tiers (Usage Data /
> Identifiers via partenaire). ⚠️ Hors périmètre de cette section mais à corriger
> avec : §2 ligne 67 et §5 lignes 159-160 décrivent encore une WebView Kayak qui
> n'existe pas (aucun `WebViewController`/`WebViewWidget` dans `lib/`, et
> l'estimateur de vols est masqué, `app_config.dart:116-119`).
>
> **Fichiers (Success Lab) — case à trancher côté ops, pas dans le dépôt.**
> Les envois d'artefacts et de pièces de preuve existent et ne sont pas masqués
> côté client (`success_lab_repository.dart:317-386` et `:670`), mais chaque
> entrée revérifie une décision **serveur** et échoue fermé
> (`live_scholarships_screen.dart:250-263`,
> `scholarship_detail_screen.dart:159-171`). Si, au dépôt du binaire, l'accès
> Success Lab est ouvert à de vrais utilisateurs en production → déclarer
> **User Content — Other (documents)** = Yes ; sinon = No. _TBD (ops)_ — ne pas
> deviner.

---

## 4. Google Play — Data Safety form

- **Does your app collect or share user data?** Yes (collect). **Share :** les
  transferts vers des sous-traitants agissant pour notre compte (Groq, Firebase,
  Supabase, **PostHog**, Resend, Mautic, PayDunya, CinetPay) sont traités par
  Play comme de la collecte, **pas** comme du « partage » publicitaire.
  **Deux exceptions à cocher « Partagée », pour une raison tirée du code :**
  (a) **OneSignal** reçoit une identité et des attributs de profil, pas une
  simple instruction de traitement — `onesignal_service.dart:61-70` envoie
  identifiant de compte, adresse e-mail et 4 étiquettes de ciblage
  (`app_controller.dart:1909-1916`) ; par contraste **Groq** ne reçoit aucun
  identifiant (`coach.service.ts:208-216`, budget en tranche
  `coach-prompt.builder.ts:25-40`), d'où « No » pour lui ;
  (b) le **service de reconnaissance vocale de la plateforme** (Apple / Google)
  reçoit l'audio de la dictée tant que `onDevice` n'est pas forcé
  (`speech_input_service.dart:36-45`) — il doit être nommé comme destinataire.
  **PayDunya / CinetPay restent dans la liste** : les adaptateurs sont livrés
  dans le backend déployé, la route `POST /me/purchases` **est** enregistrée
  (`backend/src/app.module.ts:215`, `service-packages.controller.ts:57-68`) avec
  `'cinetpay'` en défaut (`service-packages.service.ts:148-150`), et
  `test/core/privacy_disclosure_parity_test.dart:42-43` casse si la mention
  disparaît tant que les adaptateurs vivent dans `backend/src`. **Mautic** reste
  aussi, mais ⚠️ ne l'activez pas avant correction : `mautic.service.ts:76`
  appelle `upsertContact` **avant** de brancher sur `optIn`, ce qui rendrait
  fausse la réponse « e-mail transféré seulement après opt-in ».
- **Identifiant publicitaire (section « Contenu de l'application ») : NON**,
  depuis le correctif 4 (PR « huit correctifs de conformité »). Le manifeste
  source porte `<uses-permission android:name="com.google.android.gms.permission.AD_ID"
  tools:node="remove"/>` et la méta-donnée d'opt-out de collecte du SDK de
  mesure ; garde exécutable `test/release/android_manifest_test.dart`.
  **À REVÉRIFIER SUR L'AAB DE LA 49** avant de répondre — le manifeste source
  exprime une intention, seul le fusionné prouve le résultat :
  `aapt2 dump xmltree --file AndroidManifest.xml <aab> | grep -i ad_id`.
  Les deux permissions Privacy Sandbox du même AAR
  (`ACCESS_ADSERVICES_AD_ID`, `ACCESS_ADSERVICES_ATTRIBUTION`) sont laissées en
  place délibérément : Google ne documente `tools:node="remove"` que pour AD_ID.
  <br>Ce qui suit décrit l'état AVANT le correctif, conservé parce qu'il
  explique d'où venait la permission : le manifeste fusionné portait
  `com.google.android.gms.permission.AD_ID`,
  apporté par `firebase_analytics` (`pubspec.yaml:83`) via
  `com.google.android.gms:play-services-measurement-api:23.2.0` — attribution
  unique confirmée par le blame du merger
  (`build/app/intermediates/manifest_merge_blame_file/release/processReleaseMainManifest/manifest-merger-blame-release-report.txt:75`),
  et rien ne la retire (`android/app/src/main/AndroidManifest.xml:1-7` n'a ni
  `xmlns:tools`, ni `tools:node="remove"`, ni `google_analytics_adid_collection_enabled` ;
  aucun `tools:node` dans tout `android/`). Motif à cocher : mesure d'audience,
  pas de publicité ciblée. **Réserve d'honnêteté :** le manifeste fusionné et
  l'APK présents sur disque portent `android:versionCode="45"`
  (`build/app/intermediates/packaged_manifests/release/processReleaseManifestForPackage/AndroidManifest.xml:4,75-77`) —
  ils prouvent le mécanisme, pas le binaire 49. À revérifier sur l'AAB de la 49
  (`aapt2 dump xmltree --file AndroidManifest.xml <aab>`) avant de répondre.
- **Session replay (PostHog) :** à déclarer sous **App activity → App
  interactions** — **seulement si** la 49 livrée porte une `POSTHOG_API_KEY` non
  vide (même démonstration qu'en §3 : `app_config.dart:72-87`, `main.dart:66,176`,
  `scripts/preflight-ios-archive.sh:70`). Contenu masqué (`main.dart:78-80`),
  désactivable en app (`analytics_service.dart:102-106`), jamais utilisé pour la
  publicité. Play n'a pas de type « enregistrement d'écran ».
- **Is all data encrypted in transit?** Yes — raison : l'hôte prod par défaut est
  `https://api.kpbeducation.cloud/api` (`app_config.dart:249`, `appEnv` par
  défaut `prod` `:8-11`), l'ATS iOS interdit les chargements arbitraires
  (`ios/Runner/Info.plist:41-45`, `NSAllowsArbitraryLoads=false`), et le
  manifeste Android ne pose aucun `usesCleartextTraffic`.
- **Can users request data deletion?** **Yes** — en app (`profile_screen.dart:160`
  et `:1386` → `app_api_client.dart:106,112`, `GET /profiles/me/export` et
  suppression de compte) et via l'URL de suppression de compte (§6).
- **Data types — collected? shared? required or user-controllable? purpose:**

| Play data type | Collected | Shared | Requis / choix de l'utilisateur | Purpose | Pourquoi cette réponse (code) |
|---|---|---|---|---|---|
| Personal info — Name | Yes | No | **Requis** | App functionality, Account management | `app_controller.dart:1997` ; validateur `_req` sur prénom/nom (`onboarding_screen.dart:1106,1115`). |
| Personal info — Email address | Yes | **Yes (OneSignal)** | **Requis** | App functionality | `app_controller.dart:1998` ; validateur `_req` (`onboarding_screen.dart:1127`). Partage : `onesignal_service.dart:62-64` (`addEmail`) ← `app_controller.dart:1910`. |
| Personal info — Phone number | Yes | No | **Optionnel** | App functionality | **Correction** : aucun validateur sur le champ, `_buildProfile` retombe sur `''` si vide (`onboarding_screen.dart:396-398`) — l'ancienne note « Phone requis » était fausse. |
| Personal info — User IDs | Yes | **Yes (OneSignal)** | **Requis — aucun réglage ne le coupe** | App functionality, Analytics | `OneSignal.login(profile.id)` (`onesignal_service.dart:61` ← `app_controller.dart:1909`) ; l'interrupteur d'analyse ne touche que Firebase + PostHog (`analytics_service.dart:96-108`). |
| Personal info — Other info (date de naissance, nom + contact du tuteur) | Yes | No | Requis pour un mineur déclaré | App functionality (contrôle d'âge, consentement du tuteur) | `app_controller.dart:2019-2023` ; colonnes `schema.prisma:388-390` ; blocage à l'inscription `onboarding_screen.dart:460-486`. |
| Financial info | **No** | — | — | — | Aucun moyen de paiement collecté : `app_api_client.dart:825` poste `/referrals/withdraw` sans corps, compte de retrait seulement affiché masqué (`ambassador_screen.dart:822-825`), aucun SDK d'achat, contrôleurs de paiement non enregistrés (`backend/src/app.module.ts:95-98`). Le budget auto-déclaré est de l'App functionality, pas un compte financier. |
| Messages — In-app messages (dossiers) | Yes | No | Requis pour utiliser la fonction | App functionality | Étape « message » du tunnel sans garde (`case_tunnel_flow.dart:357-362`). |
| Messages — Other in-app messages (coach IA → Groq, US) | Yes | No (sous-traitant, aucun identifiant transmis) | **Optionnel — consentement explicite** | App functionality | `ai_consent.dart:58-63` ; pas de nom dans l'invite (`coach.service.ts:208-216`). |
| Photos and videos — Photos | Yes | No | **Optionnel** | App functionality | Avatar seulement, non masqué (`profile_avatar.dart:409` → `app_api_client.dart:171-190`) ; sans EXIF/GPS (`profile_avatar.dart:387`). |
| Files and docs | _TBD (ops)_ — Yes **seulement si** l'accès Success Lab est ouvert en prod ; sinon No | No | Optionnel | App functionality | **Correction** : l'ancienne ligne fusionnée « Photos / Files — uploaded documents = Yes » sur-déclarait. Les pièces de dossier sont impossibles en 49 (`case_tunnel_flow.dart:345`, `case_detail_screen.dart:435,486-487`, chokepoint `app_controller.dart:1317`) ; le seul chemin fichier restant est Success Lab (`success_lab_repository.dart:317-386`, `:670`), atteignable uniquement si le serveur répond `enabled: true`, et fermé sinon (`live_scholarships_screen.dart:250-263`, `scholarship_detail_screen.dart:159-171`). |
| Audio — Voice or sound recordings | **Yes** (voie B) / **No** (voie A) — voir la note « Audio » de §3 | À trancher : le destinataire est le service de reconnaissance de la plateforme (Apple/Google), **pas KPB** | Optionnel (bouton « dicter », par usage) | App functionality | **Ligne ajoutée.** `speech_input_service.dart:36-45` ne passe pas `onDevice` (défaut `false` = « sur l'appareil **et** réseau ») ; dictée atteignable sans drapeau (`case_tunnel_flow.dart:357-362`, `:762`, `:843`) ; permissions `android/app/src/main/AndroidManifest.xml:7` et `ios/Runner/Info.plist:52-55`. KPB ne conserve que le texte (`speech_input_service.dart:37-39`) : ne pas déclarer un stockage d'enregistrements. |
| App activity — App interactions | Yes | No | **Optionnel** — l'utilisateur peut couper | Analytics, App functionality | `profile_screen.dart:735-745` → `app_controller.dart:503-508` → `analytics_service.dart:96-108` (Firebase + PostHog), rejoué au démarrage (`main.dart:110`, `app_controller.dart:512-514`). |
| App activity — Search history | Yes | No | **Optionnel** — même interrupteur | Analytics | Texte libre : `analytics_service.dart:434-437` ← `app_controller/search.dart:44`. |
| App activity — Other user-generated actions (étiquettes de ciblage OneSignal : `account_type`, `level`, `target_country`, `locale`) | Yes | **Yes (OneSignal)** | **Requis — aucun réglage ne le coupe** | App functionality (+ personnalisation si les campagnes segmentent) | `app_controller.dart:1911-1916` → `onesignal_service.dart:65-70` (`addTags`) ; hors périmètre de l'interrupteur d'analyse (`analytics_service.dart:96-108`). |
| App info & performance — Crash logs | Yes | No | **FACULTATIVE — « les utilisateurs peuvent choisir de ne pas fournir ces données »** | App functionality (stabilité) | **Case retournée par le correctif 3** (`applyCrashlyticsConsent`, garde `analytics_consent_test.dart`). État d'avant, conservé pour mémoire : `setCrashlyticsCollectionEnabled` n'existe nulle part dans le dépôt, et les collecteurs sont armés avant toute lecture de consentement (`main.dart:49-54`, consentement relu seulement `:110`) ; les non-fatales partent sans garde (`app_logger.dart:37-45`, `safe_crashlytics.dart:41-60`). Non éphémère : les rapports persistent en console. |
| App info & performance — Diagnostics | Yes | No | Obligatoire (même raison) | App functionality (stabilité) | Clés de diagnostic de synchronisation posées sans condition (`sync_telemetry.dart:92-98`, `setCustomKey`). |
| Device or other IDs | Yes | **Yes (OneSignal)** | **Requis** — le jeton part même sans réglage d'analyse | Analytics, Push notifications | `main.dart:120` initialise OneSignal sans condition, App ID compilé non vide (`app_config.dart:58-64`) ; l'identifiant d'instance Firebase, lui, suit l'interrupteur (`analytics_service.dart:96-108`). |

> **Requis / optionnel — la note précédente était incomplète et fausse sur un
> point.** Name et Email sont *Required* (validateurs `_req`,
> `onboarding_screen.dart:1106,1115,1127`) ; **Phone est *Optional*** (aucun
> validateur, `:396-398`) ; documents/budget/tuteur restent *Optional* là où le
> parcours permet de passer, sauf le tuteur d'un mineur déclaré
> (`onboarding_screen.dart:483-486`). Les deux lignes analytiques
> (App interactions, Search history) répondent **Optionnel**, tandis que
> Crash logs, Diagnostics, User IDs, étiquettes OneSignal et Device IDs
> répondent **Obligatoire** : une fiche qui coche « optionnel » partout, ou
> « obligatoire » partout, est fausse.
>
> **Traitement éphémère : Non** pour toutes les lignes cochées — le backend, la
> console Crashlytics et les outils d'analyse persistent leurs données ; l'audio
> de la dictée est le seul cas indéterminable (il est traité par le service de la
> plateforme, pas par nous) : ne pas cocher « éphémère » faute de preuve.
>
> **Ce qu'il ne faut PAS cocher, pour éviter la faute symétrique.**
> (a) Aucune case **Localisation** : aucun appel de géolocalisation dans `lib/`,
> la chaîne iOS ne vient que du module OneSignal lié et le dit
> (`ios/Runner/Info.plist:62-63`), et l'avatar est lu sans métadonnées
> (`profile_avatar.dart:387`).
> (b) L'embed YouTube ne fait basculer **aucun** type Play : il envoie IP +
> user-agent à Google (`pubspec.yaml:82`, vignettes `parcours.dart:80`,
> `catalog.dart:913`, carte visible sans connexion `home_screen.dart:236-243`),
> et l'adresse IP n'est pas un type déclarable de la taxonomie Play. Il doit en
> revanche figurer dans la politique de confidentialité et côté Apple (§3).
> (c) Aucune case « achats intégrés » : pas de SDK d'achat dans `pubspec.yaml`,
> méthode de checkout retirée du client (`app_api_client.dart:1555-1557`), CTA
> WhatsApp (`service_packages_screen.dart:66-90`).

---

## 5. Age rating

The two rating questionnaires (Apple's in App Store Connect, the IARC one in the
Play Console) ask about **surfaces**, not about intentions. Every answer below
carries, on one line, the code that decides it — and where the repository cannot
decide, the row says **NON PROUVÉ** rather than guessing.

| Questionnaire item | Answer | Reason (from the code) |
|---|---|---|
| Contractual minimum age | **16** | ToS `web/public/conditions.html:29`; in-app copy `lib/app/core/translations/app_translations.dart:704-706` |
| Unrestricted web access | **No** | The only embedded browser is the YouTube IFrame player, and it cannot navigate: `IgnorePointer(ignoring: true)` around the WebView, `pointer-events: none` on its document, player vars `controls: 0`, `fs: 0`, `rel: 0` (`youtube_player_flutter` 9.1.3 — `lib/src/player/raw_youtube_player.dart:70,245,265-271`; resolved version `pubspec.lock:2093-2100`). Every outbound link leaves through `LaunchMode.externalApplication` (`lib/app/core/utils/external_link.dart:38`; all 6 `launchUrl` call sites in `lib/` are external) |
| Users interact with each other | **No** in build 49 | The three `CommunityScreen` entries sit behind `!AppConfig.mvpOnly`, default `true` (`home_screen.dart:388,405`, `home_screen.dart:1831`, `profile_screen.dart:1281-1287`; `app_config.dart:93-96`); the shell ships 5 tabs and no Community (`app_shell.dart:63-70`); the two public forum routes 404 under `MvpGuard` (`community.controller.ts:25-35`, `mvp.guard.ts:17-22`, deployed default `docker-compose.yml:48`) |
| User-generated content | **Yes — staff-facing, never public** | Three writes ship; see the note below |
| In-app content report / user block | **None exists** | `ForumModerationAction` has **zero writers** in `backend/src` (only `community.service.ts:269` and `reports.service.ts:228` read it); the single « Signaler » button opens WhatsApp with a prefilled *fraud* message (`anti_fraud_notice.dart:52-59`, `verified_advisor_sheet.dart:250-256`; strings `app_translations.dart:2072-2074` / `:4815-4817`) |
| Generative AI, free text in and out | **Yes — two surfaces** | Coach chat, pill mounted on 4 of the 5 tabs (`app_shell.dart:141`, `coach_fab.dart:15-38`), and the orientation test (`orientation_screen.dart:288` → `POST /orientation/submit` → `orientation.service.ts:126,152` → `llm.service.ts:53`, `api.groq.com`) |
| App shares the user's location | **No** | No location plugin in `pubspec.yaml`; no `OneSignal.Location` call anywhere in `lib/`; `ios/Runner/Info.plist:56-63` declares the string only because `onesignal_flutter` links `OSFlutterLocation.m` |
| Gambling / wagering | **No** | Exhaustive absence over `lib/`: `casino|wager|gambl` → 0 hits, `lottery|loterie` → 0 hits |
| In-app purchases (IARC asks) | **No** | No purchase SDK in `pubspec.yaml`; the client checkout method was removed (`app_api_client.dart:1555-1557`); paid packages route to WhatsApp (`service_packages_screen.dart:17-18`). **PayDunya / CinetPay belong in §2 (processors), never in this box** |
| Editorial "mature content" | **NON PROUVÉ** | Parcours stories and scholarships are typed in the back office (`parcours.controller.ts:49-50`, behind `AdminAuthGuard`), so the answer rests on editorial review, not on the binary |

> **The 16+ floor is a client-side form check, not an enforced rule.** The ToS
> text says 16 and onboarding does refuse a younger declared birth date
> (`onboarding_screen.dart:221-223` + `:471-481`, after requiring the date at
> `:463-470`). Nothing else enforces it: `UpdateProfileDto` accepts any
> `birthDate` with `@IsOptional() @IsDateString()` and **no age check**
> (`backend/src/modules/profiles/dto/update-profile.dto.ts:112-115`), and the
> first authenticated request auto-creates a `UserProfile` **with no birth date
> at all** (`supabase-auth.service.ts:243-262`) — so an account can exist with no
> declared age. A null birth date is then deliberately read as adult
> (`ai-consent.service.ts:50-58`). Declare the 16 floor as a **terms-of-use
> commitment**, not as a technical age gate.

> **Guardian consent is self-declared, and its only server effect is a 403.** The
> app collects a name, a contact and a checkbox (`onboarding_screen.dart:482-498`)
> and pushes a `guardianConsentedAt` timestamp
> (`app_controller.dart:2024-2025`). Server-side it is read only by
> `AiConsentService.consentBlockCode` (`ai-consent.service.ts:43-47`), which 403s
> the Groq routes — and that check **fails open** when the profile read returns
> null (`:16-20,42`). The stronger record the schema offers,
> `GuardianAuthorization` (verified authorization + evidence), has **zero
> writers** anywhere in `backend/src`: the only statements against it are deletes
> (`profiles.service.ts:726-728`) and reads. So "under-18s require guardian
> consent (#60)" is true of the *form*, not of a verified authorization.
>
> A second, **lower** AI floor exists in the repository — 13, from
> `KPB_AI_DIAGNOSTIC_MIN_AGE` (`competition-readiness/diagnostics/ai-consent.service.ts:227-232`,
> `common/feature-access.service.ts:117-120`) — but it governs a surface that is
> **off** in build 49: the client fails closed on `/success-lab/access`
> (`live_scholarships_screen.dart:250-262,265-269`) and the server needs
> `KPB_COMPETITION_READINESS_ENABLED` + `KPB_SUCCESS_LAB_ENABLED` +
> `KPB_AI_DIAGNOSTIC_ENABLED` with the kill switch off, all shipped the other way
> (`docker-compose.yml:90-93`). **Do not write 13 on any questionnaire**; do not
> claim it can never come back either.

> **The UGC that actually ships — three writes, none of them public.**
>
> | Write | Who else can read it | Proof |
> |---|---|---|
> | Case messages + timeline | The assigned KPB staff, through the back office (`admin/cases`, `AdminAuthGuard` + Counselor/Commercial/Admin/SuperAdmin roles); and **one linked parent, read-only, per case, only if the student flips the switch** (default `false`) | `admin-cases.controller.ts:27-34,41-44`; `parent-links.controller.ts:47-70` (GET only) + `:71-80`; `schema.prisma:566`; toggle surfaced at `case_detail_screen.dart:560` |
> | Counsellor review — rating, free text **and the student's civil name** (`reviewerName: profile.fullName`) | Nobody, in build 49: rows are created `isPublished: false` (`counsellors.service.ts:245-247`) and an admin can flip that (`counsellors.controller.ts:94`), but the public carousel *additionally* requires an active `public_testimonial` consent receipt that **no code path writes** (`impact.service.ts:252-259,292-309`), and `/impact/reviews` is feature-disabled by default (`impact.service.ts:312-319`; `docker-compose.yml:90,123`) | client write `case_detail_screen.dart:300-306` |
> | Coach chat | Nobody — reads are scoped to the author's id | `coach.controller.ts:42-44` |
>
> No public feed, no profile-to-profile visibility, no comments. The only content
> a stranger sees is editorial (`content/parcours`, catalog).

> **⚠️ This is the section's open blocker, and the old action item is now
> answered.** "Confirm a content-report path exists for the community" resolves
> to: **there is none — for any surface.** Both consoles ask for it (Apple
> reviews UGC for filtering + reporting + blocking; Play asks for an in-app way
> to report objectionable output on apps with generative-AI features — verify the
> current wording in each console). With the code as it stands, neither question
> can be answered "yes", and the anti-fraud WhatsApp button is not a content
> report: it is a fraud tip line whose prefilled text says so
> (`app_translations.dart:2073-2074`). Decide before submission: ship a report /
> block path, or submit knowing these two answers are "no".

> **The web-access bullet was wrong in both directions, and the fix is in §2.**
> `webview_flutter` is declared (`pubspec.yaml:72`) with **zero call sites** in
> `lib/`; the Kayak / price-comparison screen is masked
> (`app_config.dart:116-119`, entry point `profile_screen.dart:1264-1270`) and
> even unmasked it opens links in the system browser
> (`flight_estimator_screen.dart:149-176`). The surface that *does* ship is the
> YouTube IFrame player, reachable **without an account**: the home « Récit de la
> semaine » card is mounted with no guest guard (`home_screen.dart:236-242`,
> comment *"Shown to guests too"*) and opens the player
> (`story_of_week_card.dart:55-63` → `parcours_feed_screen.dart:191-194,258`);
> Parcours is also reachable from `home_screen.dart:2462` and
> `profile_screen.dart:1245-1249`. The rating answer stays **No** (the player
> cannot navigate — see the table), but §2's "Embedded web (WebView)" row must
> name Google/YouTube (`youtube-nocookie.com`, `www.youtube.com/iframe_api`,
> `img.youtube.com`) instead of a price comparator.

**Recommended:** enter the answers above and let each questionnaire compute the
band. Do **not** carry the old "Apple 12+ / Google Teen" pair forward: it was
derived from a community module that does not ship and without the two
generative-AI surfaces. Two answers must be settled first, because they are
review-guideline requirements and not merely form fields — the missing
report/block path, and the fact that the 16 floor lives only in a client form.

---

## 6. Account deletion & data export (store requirement)

Both are **delivered** (KPB-67). Three gaps below must not be papered over by the
form wording.

- **In-app:** Profile → **« Mes données »** / "My data" → **« Exporter mes
  données »** / **« Supprimer mon compte »** (`app_translations.dart:2341,2342,2346`
  / EN `:5066,5067,5071`; card `profile_screen.dart:1367-1396`, mounted
  `:159-163`). *The label is « Mes données » — there is no "/ RGPD" string in the
  app; §4 already quotes it correctly.* Deletion is **immediate and hard**: one
  Prisma transaction over an explicit table list plus schema cascades, ending in
  `userProfile.delete` (`profiles.service.ts:547-733`), then best-effort erasure
  of the objects in storage — case documents, artifact versions, outcome
  evidence, guardian evidence and the avatar (`:758-773`). No soft-delete, no
  grace period. It is **not** a blanket "purge of Postgres": what is not named
  and not reached by a cascade survives (see the table below).
- **Account deletion URL — already shipped; only the console entry remains.**
  `web/public/suppression-compte.html` gives the in-app steps (`:16-24`) and a
  fallback address (`:26-31`), is served by the `web` nginx container behind the
  `kpbeducation.cloud` Traefik router (`docker-compose.yml:249-266`), is linked
  from the three other legal pages (`index.html:21`, `confidentialite.html:100`,
  `conditions.html:73`) and is probed **by title every 15 minutes**
  (`.github/workflows/uptime.yml:143-146`, cron `:20-21`). Whether the container
  is actually up on the VPS is not provable from the repository.

| Console field | Answer | Reason (from the code) |
|---|---|---|
| Play → *Can users request that their data be deleted?* | **Yes — in-app and via a web URL** | `profile_screen.dart:271-301` → `app_controller.dart:678-700` → `DELETE /profiles/me` (`profiles.controller.ts:116-120`) |
| Play / Apple → **Account deletion URL** | `https://kpbeducation.cloud/suppression-compte.html` | page + router + uptime probe cited above |
| Data export offered | **Yes — in-app, JSON shared from the app** | `GET /profiles/me/export` (`profiles.controller.ts:110-113` → `profiles.service.ts:823-1237`), handed to the OS share sheet as text (`profile_screen.dart:251-269`) |
| Deletion is immediate (no retention window declared) | **Yes** | Single transaction, no soft-delete flag (`profiles.service.ts:547-733`); the web page's "sous 30 jours" is an outer bound, not the implementation |

> **Ops follow-up (required) — and its consequence is worse than "the login
> record survives".** Without `SUPABASE_URL` + `SUPABASE_SERVICE_ROLE_KEY` (the
> key ships empty, `docker-compose.yml:54`), `deleteSupabaseAuthUser` logs and
> returns false (`profiles.service.ts:786-799`). Because that identity still
> authenticates, the **next authenticated request re-creates a profile** with the
> same email (`supabase-auth.service.ts:216-262`) — a store reviewer who deletes
> the account and reopens the app sees a working account. The app cannot even
> tell: `deleteAccount()` is `Future<void>` over `_dio.delete<void>`
> (`app_api_client.dart:112-114`), so the `authIdentityRemoved` flag the endpoint
> returns (`profiles.service.ts:775-778`) is discarded and the UI reports success
> either way (`profile_screen.dart:283-295`). Set both secrets before submission,
> or the deletion claim is false on the reviewer's own device.

> **What survives `DELETE /profiles/me` today.** Three families — none of them a
> cascade the schema will fix on its own.
>
> | Surviving data | Why the purge misses it | Store consequence |
> |---|---|---|
> | `CounsellorReview`: the student's **civil name** (`reviewerName`, sent as `profile.fullName` — `case_detail_screen.dart:305`) + free-text body | No relation to `UserProfile` (`schema.prisma:1380-1394`: only `counsellorId`; `reviewerUserId` is a bare string), so no cascade reaches it and the transaction never names it | The page's "Ce qui est supprimé" list (`suppression-compte.html:33-39`) is not true of this row. Either delete it in the transaction or stop storing the civil name |
> | Ambassador ledger — `Ambassador` (display name, city, **full payout account**), `AmbassadorReferral` (referee name), `Commission`, `Withdrawal` | `userProfileId` / `refereeProfileId` are plain strings with no `@relation` (`schema.prisma:1848-1935`) and none of the four appears in the transaction | Bites only ops-created ambassadors in build 49 — no caller of `activateAmbassador` exists in `lib/` (`app_api_client.dart:811-816` is unused) — but the rows hold payout data |
> | The **Mautic contact**: email, first/last name, phone, mobile (WhatsApp), country, language (`mautic.service.ts:99-113`) | **No deletion request is ever sent to a processor.** `deleteMe` never calls `NewsletterSyncService`, the newsletter module has no delete path, and reconciliation is profile-driven — a deleted profile simply stops being seen (`newsletter-sync.service.ts:28-48,71-90`) | Inert while Mautic is unconfigured (`docker-compose.yml:62-65` ship empty; `mautic.service.ts:49-53`), a hard erasure gap the day it is configured. Note also that `syncContact` upserts the contact **before** branching on the opt-in (`mautic.service.ts:63-95`) |
>
> The only processor signal the client does send is `OneSignal.logout()`
> (`app_controller.dart:682`), which unlinks the **device**, not the contact.

> **`EefInterest` EST exporté** depuis que la déclaration d'intérêt « Études en
> France » a été branchée dans `exportMe` (niveaux, `wantsPremium`,
> `consentVersion`, `consentedAt`). La suppression l'était déjà par la cascade.
> Elle a figuré un temps dans la liste ci-dessous des enregistrements absents :
> documenter une omission n'est pas la réparer quand le champ manquant est la
> preuve de consentement.
>
> **Export scope — the honest wording for the forms.** `GET /profiles/me/export`
> returns 15 top-level keys (`profiles.service.ts:1213-1228`) and is **not
> exhaustive of the caller's own records**. Absent although the same user owns
> them, and although the purge explicitly deletes them: `PaymentIntent` (`:565`),
> `Referral` (`:577-580`), `CreditTransaction` (`:581`), `DeviceToken` (`:729`),
> `PartnerLead` (`:730`), `StudentCredential` (`:731`) — plus the cascade-owned
> `Match`, `ScholarshipAlertSubscription` and `UserNotification`
> (`schema.prisma:1063-1077,1193-1206,1211-1240`) — and `CounsellorReview`, which
> is neither exported nor deleted. And it is **not a file**: the client hands the
> pretty-printed JSON to the OS share sheet as `text`
> (`profile_screen.dart:254-262`). Declare "export available in-app (JSON, shared
> from the app)", not "downloadable archive".
>
> The export's analytics slice, like the purge's, is env-conditional on
> `KPB_ANALYTICS_ACTOR_SECRET` (`profiles.service.ts:584-591`, `:1186-1193`,
> `:1249-1254`; empty by default, `docker-compose.yml:114`) — but this narrows
> nothing in build 49: the single `AnalyticsEvent` writer always sets
> `actorKey: null` (`domain-event-analytics-projector.service.ts:47-56`). The
> actor key that is really written lives on `AiUsageAttempt`
> (`ai-budget.service.ts:258,378-382`), and the purge nulls it
> (`profiles.service.ts:705-712`). Do not declare an analytics-erasure gap that
> the code does not have; do re-read this the day the Success Lab analytics chain
> is switched on.

> **Harness note** (the recurring defect on this repo: the tool meant to catch it
> hid it). The only test that proves erasure end-to-end is
> `backend/src/modules/profiles/profiles.postgres.spec.ts` — it does run in CI
> (`.github/workflows/backend-ci.yml:112`) — and it seeds **no `CounsellorReview`
> and no ambassador row**, so it cannot fail on either gap above. Extending the
> purge without extending that spec would leave exactly the blind spot that
> produced this section's earlier wording. Same for the export: assert the set of
> top-level keys, not just that it serializes.

---

## 7. Performance budget (measured)

The airtime/low-end-device moat must be **measured, not asserted**. Reference
device: an entry-level Android with **~2 GB RAM** (e.g. a device matching the
target market). Fill in and keep these in the PR description for the award.

### How to measure

```bash
# APK size (per-ABI, release)
flutter build apk --release --split-per-abi
ls -lh build/app/outputs/flutter-apk/*.apk        # arm64-v8a is the headline number
# (or App Bundle delivered size)
flutter build appbundle --release

# Cold start (app fully closed → first frame), on the reference device:
adb shell am force-stop org.karatou.app   # use the real applicationId
adb shell am start-activity -W -n org.karatou.app/.MainActivity | grep -E 'TotalTime|WaitTime'
# average of 5 cold starts

# Bytes/session — capture a representative session (open app, browse, 1 coach turn):
#   Settings → Apps → KPB → Data usage   (before/after), or
adb shell dumpsys netstats detail | grep -A3 org.karatou.app   # uid totals
```

### Results (to fill in on the reference device)

| Metric | Target | Measured | Device / build |
|---|---|---|---|
| APK size (arm64, release) | ≤ 25 MB | _TBD_ | |
| App Bundle delivered size | ≤ 20 MB | _TBD_ | |
| Cold start (TotalTime, avg of 5) | ≤ 2.5 s | _TBD_ | |
| Bytes / typical session | ≤ 500 KB | _TBD_ | |

### Quick wins already applied / recommended
- ✅ Removed the unused `google_fonts` dependency (this PR).
- ☐ Defer non-critical startup work (OneSignal init, quick-actions) off the
  first frame (e.g. `addPostFrameCallback` / after first paint).
- ☐ Audit catalog image sizes; the data-saver mode (already present) should be
  the default on metered connections.

---

## 8. CI — coverage floor on critical modules (AC3)

Sync/merge/outbox correctness must not regress silently. Calibrate the floors
to **current** coverage first (`npx jest --coverage` / `flutter test
--coverage`), then set the floor at-or-just-below it so CI ratchets.

**Backend (`backend/jest.config` or `package.json` jest block):**

```jsonc
"coverageThreshold": {
  "global": { "statements": 60, "branches": 50, "functions": 60, "lines": 60 }
  // tighten after measuring; never set above current coverage (breaks CI).
}
```

**Flutter (CI step) — floor the sync/merge/outbox modules:**

```bash
flutter test --coverage
# Fail if the critical modules drop below the floor (uses lcov):
lcov --extract coverage/lcov.info \
  '*/services/sync_*' '*/services/*merge*' '*/services/case_message_outbox.dart' \
  -o coverage/critical.info
lcov --summary coverage/critical.info   # parse the % and fail under the floor
```

Wire both into the existing `Analyze & test` workflow.

---

_Last updated: 2026-08-18 (revue contradictoire des déclarations contre la build 49 ;
sections 1 à 6 réécrites). Owner: keep
in sync with any new SDK, data flow, or third-party processor._
