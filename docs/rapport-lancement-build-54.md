# Rapport — Études en France, build 54 : ce qui est fait, ce qui reste

> Établi le 01/10/2026 sur la branche `claude/campus-france-space-98orw9`
> (derniers commits : `ac54037`). **Aucune PR n'est ouverte et rien n'est fusionné** :
> tout est commité et poussé sur la branche, en attendant ton feu vert.
> Rien n'est déployé, rien n'est soumis aux stores, aucun établissement n'est publié,
> `KPB_EEF_ENABLED` n'est posé nulle part.

## 1. Où on en est, en trois phrases

- Le code de la build **2.3.0 (54)** est complet pour le périmètre « ouverture sûre +
  hub v1 » : **tout ce qu'on peut faire sans toi est fait et vérifié** (voir §5).
- La 54 part avec l'espace réel **éteint** : à l'approbation, un utilisateur voit la
  vitrine de la 53 (plus ses liens officiels). L'espace s'ouvre ensuite par une
  opération serveur, sans nouvelle soumission.
- Ce qui reste est **humain** : valider le juridique, tester sur un appareil (Xcode),
  archiver, remplir les consoles, soumettre, publier un premier établissement.

## 2. Ce qui est fait

**Backend (déjà fusionné : #293, #295)** — frontière du catalogue (les 10 502 formations
importées ne fuient ni dans Explorer, ni dans les correspondances, ni dans la file de
vérification), publication par établissement (plan → simulation → application),
recherche serveur sans accents (par nom, sigle, ville, niveau), `catalogPublished`,
`PATCH` du profil sans redonner le consentement, clé `features.eefSpace`.

**Cette branche — application** (`lib/`, 25 fichiers) :
- **Socle** : version `2.3.0+54` ; en-têtes `X-KPB-App-Version/Build` sur chaque
  requête ; bandeau doux « une mise à jour est disponible » ; liens officiels servis
  (plateforme, source de la suspension) ; mention de la Licence Ouverte servie.
- **Catalogue** : carte qui nomme l'université, la ville et la procédure ; « le
  catalogue arrive » ≠ « ta recherche est trop étroite » ; page suivante en panne qui
  garde la liste ; « Tout effacer » vide le champ ; retour en haut après un filtre ;
  mentions (paternité, non-affiliation, suspension) en fin de liste et à un geste.
- **Hub** : héros honnête (la suspension remplace la date), catalogue, CV / lettres /
  entretien, conseiller WhatsApp ; **Mon profil Études en France** (niveaux, domaines
  d01–d12 préremplis, Modifier par `PATCH`, Me retirer) ; parents et partenaires voient
  « un espace pour les étudiants » ; plus aucun module « en préparation ».
- **Retiré** : la jauge « 85 % » codée en dur sur les fiches d'établissement (avec un
  garde qui interdit tout score littéral) ; « Un espace communautaire » des CGU.
- **Mesure** : 5 événements (vue de l'espace, tuiles, catalogue vu / cherché / en
  panne) — des comptes, **jamais le texte tapé**.

**Cette branche — serveur et exploitation** :
- `/config/app` sert `recommendedVersion`, `platformUrl`, `suspendedSources`, `eefCatalog`.
- **Audiences de campagne** `eef_interest` et `all_students_except_countries`, avec le
  jeton `eef_suspended` (la liste des pays suspendus servie à l'app) ; un filtre mal
  formé donne **zéro** destinataire ; l'aperçu dit les pays exclus. Admin web, MCP et
  agent mis à jour.
- `vps-ops` : `recommended-version-set` ; `eef-space-on` refuse d'ouvrir sans le bon
  backend et le workflow le prouve depuis l'extérieur.

**Documents prêts à l'emploi** : `docs/release-ledger.md` (entrée 54),
`docs/release-54-store-pack.md` (notes de version FR/EN, notes de revue Apple, phrases
Google Play), `docs/runbook-ouverture-espace-reel.md`, `docs/device-qa-build54.md`,
`docs/eef-consent-v1.md` (texte de consentement archivé + questions juridiques),
`docs/CONSOLE_ANSWERS.md` §0quater (déclarations de console).

## 3. À faire par toi / par un humain, dans l'ordre

| # | Quoi | Pourquoi / où |
|---|---|---|
| 1 | **Dire « ouvre la PR »**, relire, puis fusionner | Les builds de release partent de `main`. **Aucun CI n'a encore tourné sur les 7 commits de la 54** (le CI ne démarre qu'à l'ouverture d'une PR) : tout est vérifié en local, le premier vrai passage CI aura lieu à l'ouverture. Voir aussi §6 « PR ouvertes qui chevauchent ». |
| 2 | **Déployer le backend** (`deploy.yml`, `scope=full`) au commit de fusion, puis `GET /api/health/version` | Sans lui : pas d'audience « sans le Niger » pour la notification du jour J, pas de `eefCatalog`. Migration additive. |
| 3 | **Notification du 01/10** : audience `all_students_except_countries` + `{"exceptCountries":["eef_suspended"]}`, route **`/etudes-en-france`** (jamais `/catalogue`) ; **lire l'aperçu** (pays exclus, comptes retirés) ; feu vert humain | `docs/runbook-ouverture-espace-reel.md` §« Annoncer ». Sans backend récent : texte neutre pour le Niger. |
| 4 | **Décider A ou B** (espace éteint ou allumé pendant la revue) | Recommandation **A** (éteint, déclaré dans les notes de revue) : aucun établissement n'est publié. `docs/release-54-store-pack.md` §1. |
| 5 | **Valider le juridique** : phrase sur Campus France dans le héros, mention de non-affiliation, finalités « Marketing » dans les consoles, annonce d'ouverture couverte par le consentement ?, date et information sur la politique | `docs/eef-consent-v1.md`, `CONSOLE_ANSWERS.md` §0quater. |
| 6 | **Test Xcode** sur un iPhone : fiche A de `docs/device-qa-build54.md` ; pour voir le hub, la voie B (tunnel HTTPS vers un backend local) | L'app n'affiche pas sa version : lire `2.3.0 (54)` dans TestFlight. |
| 7 | **Archiver** : iOS dans Xcode Organizer avec la vraie clé `phc_…` + `scripts/preflight-ios-archive.sh` + dSYM ; Android : Flutter CI `release_android=true` ou tag `v2.3.0` | `docs/mobile-store-submission-contract.md`. |
| 8 | **Préflight de release** : `backend_coupling=tolerates-old` (ou `requires-new` si état B) ; dérogation de stabilité 24 h ; rafraîchir le heartbeat de sauvegarde | LIV-06. |
| 9 | **Consoles** : questionnaire d'âge (4+ affiché alors que 16 ans et 6 surfaces d'IA), Data Safety / App Privacy, « Government apps », Wikimedia | `CONSOLE_ANSWERS.md` §0quater. |
| 10 | **Soumettre** : « Nouveautés » et notes de revue du pack, revue accélérée Apple, publication progressive iOS, Play par paliers 5 / 20 / 100 % | **L'approbation pour le 01/10 n'est pas garantie** (1 à 3 jours). |
| 11 | **Budget de performance** (taille AAB, démarrage à froid, octets) sur l'appareil de référence | `docs/STORE_READINESS.md`, 4 lignes « _TBD_ ». |
| 12 | **Ouvrir l'espace** — seulement après : 54 en vente et adoptée, backend récent, `eef-import`, **un établissement relu et publié sous le nom d'un vérificateur réel** | Runbook complet. Retour arrière : `eef-space-off`. |

## 4. Ce que je n'ai PAS fait (et pourquoi)

- **Rien d'irréversible ni d'extérieur** : pas de PR, pas de déploiement, pas d'envoi de
  notification, pas de soumission, pas de saisie dans les consoles.
- **Aucune validation juridique** : tout texte « à valider » est marqué comme tel.
- **Aucun établissement publié** : il faut le nom d'un vérificateur réel et ta décision
  sur le périmètre de la première vague (L1, PASS/L.AS, DAP d'abord).
- **Build 55** (fiche formation, onglet Universités, sélection, checklist, projet
  d'études, favoris) et **forum** (build dédiée) : hors périmètre convenu.
- **Pas testé sur un appareil réel** : tout est vérifié par tests automatisés, pas à la
  main. C'est précisément l'objet de ton test Xcode.

## 5. Vérifications effectuées

| Contrôle | Résultat |
|---|---|
| `flutter analyze`, `dart format` | propres |
| Suite Flutter (mode CI : sans `golden` ni `known-defect`) | **1 326 tests verts**. Le golden `theme_gallery` échoue aussi sur `main` (rendu de police Linux) et est exclu de la CI. |
| Backend : unitaires | **2 014 verts** ; `tsc` propre |
| Backend : intégration sur vrai PostgreSQL (provenance, publication, recherche, profil, **audiences**) | **83 verts** |
| Admin web | 142 verts |
| Mutations | chaque garde ajoutée a été cassée volontairement : le test correspondant devient rouge (échappement `ILIKE`, variantes d'accents, retour en haut, bandeau muet, lecture en échec, porte de l'espace…) |
| Relectures indépendantes (2 agents, lecture seule) | **aucun défaut bloquant** ; une quinzaine de défauts réels (filtre d'exclusion qui ignorait une faute de frappe, `ILIKE` et jokers, liste non remontée, docs fausses…) **tous corrigés** dans `ac54037` |

## 6. Points d'attention connus

- **Le héros du hub** ne prétend plus que toute candidature passe par « Études en France »
  (le catalogue compte ~3 100 formations en DAP blanche, 29 en DAP jaune, 80 hors procédure).
- **Un compte sans pays renseigné** (profil non complété) ne peut pas être exclu d'une
  campagne « sans le Niger » : il reçoit l'annonce.
- **Aucune action `vps-ops` pour `KPB_EEF_SUSPENDED_SOURCES` / `KPB_EEF_PLATFORM_URL`**
  (le port 22 est injoignable) : le Niger et la plateforme ont des valeurs par défaut
  vérifiées ; un *nouveau* pays suspendu n'aurait pas de lien tant qu'une PR n'ajoute pas
  sa source.
- **Les en-têtes de version** sont posés par l'app mais **lus nulle part côté serveur** :
  ils servent à la 55 (ex. servir des lignes aux seules builds qui les affichent).
- **Un parent ou un partenaire** qui ouvre le lien `/etudes-en-france` voit désormais
  « un espace pour les étudiants » même en mode vitrine (en 53 il voyait la vitrine puis
  un 403 traduit en « reconnecte-toi »). Écart assumé.
- `recommended-version-set` ne touche **que** les builds 54 et suivantes ; pour amener les
  utilisateurs de la 53 vers la 54, il n'y a que la mise à jour du store ou une
  notification.
- **PR ouvertes qui chevauchent la 54** (essai de fusion à sec, rien n'a été poussé ni touché
  sur ces branches ; `main` n'a pas bougé depuis `95440db`) :
  - **#287** (`fix/profile-fit-no-admission-pct`) — **conflit** dans
    `lib/app/features/explore/explore_screen.dart`. Les deux retirent le « 85 % » codé en dur
    de la fiche établissement : la 54 supprime la jauge, #287 la remplace par un badge
    « match profil » (et retire aussi les pourcentages des cartes de liste, de la comparaison,
    de la fiche formation, etc.). **Ordre conseillé : fusionner #287 d'abord**, puis fusionner
    `main` dans la branche de la 54 et, sur ce seul fichier, **garder la version de #287**
    (elle contient la mienne). Le garde `admission_meter_guard_test` reste valable (aucun
    score littéral). `home_screen.dart`, `profile_screen.dart` et `app_translations.dart` se
    fusionnent seuls. #287 modifie aussi le golden `theme_gallery.png` (hors CI).
  - **#251** (`fix/counsellor-rotation-tiebreak`) — **conflits** dans
    `.github/workflows/backend-ci.yml`, `backend/package.json` et
    `backend/scripts/seed-kpb-counsellors.sql` (la 54 a ajouté la suite
    `campaign-audience.postgres.spec.ts` au script `test:integration:eef-provenance`). Hors
    périmètre de la 54 ; à rebaser par son auteur si elle doit partir.
  - **#288, #289, #290** — se fusionnent sans conflit avec la 54 (en touchant les mêmes
    fichiers : `app_config.dart`, `app_api_client.dart`, `app_translations.dart`,
    `docker-compose.yml`, `.env.example`, contrat analytique). Si l'un part avant la 54, relancer
    les tests Flutter après la fusion de `main` (le test `config_env_relay_test` lit
    `docker-compose.yml` et `.env.example`).
