# Rapport — Études en France, build 54 : ce qui est fait, ce qui reste

> Mis à jour le 01/10/2026 à 23 h 45 (production vérifiée à 23 h 05).
>
> **Pour la mise à jour du 02/10 au matin : `docs/mise-a-jour-54-checklist.md`** — la
> liste pas à pas (vérifications, Android, iOS, préflight, consoles, soumission).
>
> **Le catalogue Études en France est publié.** 10 029 formations dans 84 établissements,
> par l'action `eef-publish` (#299) : essai sur l'UTT (5 formations) à 21 h 24, puis le
> reste (10 024) à 21 h 25, 0 échec. Tampon « Aminou Laouali (publication déléguée) », une
> trace d'audit par établissement. 473 formations restent **en attente** (page-source
> morte, toutes des masters « Trouver mon master » 2021). Catalogue des autres espaces
> **inchangé** (69 / 634), mesuré avant et après par le workflow.
>
> **Backend en production : `33c5a51`** (#299 publication déléguée, #300 cartes d'aide
> WhatsApp et synonymes santé, #301 « médecine » → PASS / L.AS seulement, badge
> `healthAccess`).
>
> **L'espace reste fermé** : `eefSpace=false`, `eef=false`, `eefTeaser=true`. Aucune build ne
> montre ce catalogue ; l'API publique `/etudes-en-france/search` le sert. Rien n'est soumis
> aux stores, aucune notification n'est partie.
>
> **Prêt, en PR, à fusionner avant l'archivage** : l'intégration de #287 (plus aucun
> pourcentage d'admission) et #288 (délai IA de 90 s), plus le libellé « Études de santé »
> du filtre — voir la checklist, étape 0.

## 1. Où on en est, en trois phrases

- Le code de la build **2.3.0 (54)** est complet pour le périmètre « ouverture sûre +
  hub v1 » : **tout ce qu'on peut faire sans toi est fait et vérifié** (voir §5).
- La 54 part avec l'espace réel **éteint** : à l'approbation, un utilisateur voit la
  vitrine de la 53 (plus ses liens officiels). L'espace s'ouvre ensuite par une
  opération serveur, sans nouvelle soumission.
- Ce qui reste est **humain** : valider le juridique, tester sur un appareil (Xcode),
  archiver, remplir les consoles, soumettre. Le catalogue, lui, est publié (01/10).

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
| 1 | ~~Ouvrir la PR, fusionner~~ — **fait** (#293, #295, #299, #300, #301 sur `main`) | La PR d'intégration de #287 / #288 reste à décider : checklist, étape 0. |
| 2 | ~~Déployer le backend~~ — **fait** : `33c5a51` en production depuis le 01/10 à 23 h 02 | Si la PR d'intégration est fusionnée : redéployer (backend de #288), avant ou après l'archivage. |
| 3 | ~~Notification du 01/10~~ — **reportée** : après `eef-space-on` (§7, points 6 et 7) | Envoyée avant, elle mènerait à la vitrine. |
| 4 | **Décider A ou B** (espace éteint ou allumé pendant la revue) | Recommandation **A** : le catalogue est publié, mais les procédures (§7.1) et le juridique ne sont pas tranchés. `docs/release-54-store-pack.md` §1. |
| 5 | **Valider le juridique** — bloquant pour la soumission : finalités « Marketing » des consoles (XC-06), tranche d'âge (D2), non-affiliation et « Government apps » (XC-04). Bloquant pour l'ouverture seulement : phrase sur Campus France dans le héros | `docs/eef-consent-v1.md`, `CONSOLE_ANSWERS.md` §0quater. |
| 6 | **Test sur appareil** : fiche A de `docs/device-qa-build54.md` ; le hub par la **voie 2** (fenêtre de recette `eef-space-on` tant que la 54 n'est que chez les testeurs, puis `eef-space-off` avant de soumettre) | L'app n'affiche pas sa version : lire `2.3.0 (54)` dans TestFlight. |
| 7 | **Archiver** : Android par Flutter CI `release_android=true` (**pas** de tag `v2.3.0`) ; iOS dans Xcode avec la vraie clé `phc_…` + `scripts/preflight-ios-archive.sh` + dSYM | Pas à pas : `docs/mise-a-jour-54-checklist.md`. |
| 8 | **Préflight de release** : `backend_coupling=requires-new` si la production sert le commit archivé, sinon `tolerates-old` ; le heartbeat de sauvegarde ne se rafraîchit pas à la main (toutes les 6 h à h+23) | LIV-06. |
| 9 | **Consoles** : questionnaire d'âge, Data Safety / App Privacy (inchangées pour la 54), « Government apps », Wikimedia | `CONSOLE_ANSWERS.md` §0quater. |
| 10 | **Soumettre** : « Nouveautés » et notes de revue du pack, publication progressive iOS, Play par paliers 5 / 20 / 100 % | Soumission le 02/10 ; approbation en 1 à 3 jours, non garantie. |
| 11 | **Budget de performance** (taille AAB, démarrage à froid, octets) sur l'appareil de référence | `docs/STORE_READINESS.md`, 4 lignes « _TBD_ » ; commandes dans la fiche QA §C. |
| 12 | **Ouvrir l'espace** — seulement après : 54 en vente et adoptée ; catalogue publié (**fait**) ; 7 questions de procédure tranchées ; juridique du héros validé | Runbook complet. Retour arrière : `eef-space-off`. |

## 4. Ce que je n'ai PAS fait (et pourquoi)

- **Rien d'irréversible ni d'extérieur** : pas de PR, pas de déploiement, pas d'envoi de
  notification, pas de soumission, pas de saisie dans les consoles.
- **Aucune validation juridique** : tout texte « à valider » est marqué comme tel.
- ~~**Aucun établissement publié**~~ — dépassé : publication déléguée du 01/10
  (10 029 formations, §5 bis).
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

## 5 bis. Audit final du catalogue (01/10/2026, base de production, lecture seule)

| Contrôle | Résultat |
|---|---|
| Intégrité des 84 établissements (`db-info.sql` §12) | source HTTPS, site HTTPS, nom, ville, UAI, pays : **0 manque** ; 0 code UAI en double ; 0 établissement sans formation ; 44 sans logo (assumé : pas de marque sous copyright) |
| Intégrité des 10 502 formations | source HTTPS, procédure, cycle, domaine d01–d12, nom, établissement parent, pays : **0 manque, 0 orpheline** ; **10 502 passent le plan de publication** |
| Catalogue général (autres espaces) | **69 établissements, 634 formations**, inchangés |
| Sites des 84 universités | **76 répondent** ; 2 bloquent les robots (403) ; 6 non vérifiables depuis mon poste (certificat mal servi par le site, ou coupure) — pas de preuve qu'ils soient morts |
| Pages-sources des formations (2 150 pages d'établissement, 1 559 adresses, deux passages) | **1 034 répondent ; 341 sont mortes (404/410/renvoi à l'accueil) = 473 formations, toutes des masters du jeu « Trouver mon master » de 2021, dans 63 établissements ; 184 incertaines** (deux passages complets ont donné 470 puis 473 : quelques pages sont instables) |
| Fiches Parcoursup (4 140), Mon Master (1 078), jeu du ministère (3 134) | non contrôlées une à une (portails) ; échantillons : 40 fiches Parcoursup sur 40 répondent, et une relecture indépendante en a trouvé une générique sur 380 |
| Titres identiques | 669 groupes (2 323 lignes) portent le même intitulé, le même cycle et la même ville, **avec des fiches Parcoursup distinctes** (codes différents) : ce ne sont pas des doublons de données, mais l'étudiant verra des cartes qui se ressemblent |

**Conséquence :** la publication déléguée publie **10 029 formations** et laisse **473 en
attente** (page-source morte). Aucune ne disparaît : elles restent importées, inactives.

**À savoir avant d'ouvrir l'espace :** la recherche publique (`/etudes-en-france/search`) est lisible sans
session dès la publication, même si aucune build n'affiche encore le catalogue. Et une règle de
procédure fausse ne se corrige pas en masse après publication avec les outils actuels (pas de
`eef:reconcile`) : voir `docs/eef-publication-deleguee.md` § « Retour arrière ».

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

## 7. Prochaines étapes après la publication du 01/10 (ordre recommandé)

| # | Quoi | Qui | Pourquoi |
|---|---|---|---|
| 1 | **Faire trancher les 7 questions de procédure** (`docs/eef-dossier-relecture-procedures.md`) par une personne qui connaît Campus France | humain | Les lignes sont désormais publiées et tamponnées : une règle fausse ne se corrige plus en masse (`eef:reconcile` n'existe pas). Retirer un établissement reste possible. |
| 2 | **Construire `eef:reconcile`** (réaligner les lignes publiées sur le catalogue régénéré, simulation d'abord) | code | Sans lui, la réponse au point 1 ne peut pas atteindre la production. |
| 3 | ~~**Fusionner les cartes d'aide WhatsApp**~~ — **fait** (#300, sur `main` le 01/10) ; à inclure dans l'archive de la 54 | code + toi | Elles ne s'affichent que dans l'espace réel : sans effet tant que `eefSpace` est faux. |
| 4 | ~~**Synonymes de recherche**~~ — **fait** (#300 puis #301, déployés en `33c5a51`) : « médecine », « pharmacie », « kiné », « L.AS »… → une 1re année PASS ou L.AS **seulement** ; « santé » → toute la famille ; « PASS » → les PASS, par leur intitulé | code | Mesuré le 01/10 : `q=medecine` rendait 0 résultat. #300 (déployé le 01/10 à 22 h 20) l'a mené aux 650 formations du cycle `sante`, dont **61 diplômes paramédicaux** (orthophoniste, orthoptiste…) qui passaient EN TÊTE (tri par intitulé) : aucune PASS ni L.AS dans les 50 premiers résultats, et le badge « Accès santé » sur un certificat d'orthophoniste. Corrigé par #301 (`eef-health-access.ts`, champ `healthAccess`), en production depuis le 01/10 à 23 h 02. |
| 5 | **Test sur appareil** (Xcode) de la 54 pointée sur la production, puis soumission | toi | `docs/device-qa-build54.md`, A et B (B-aide pour les cartes). |
| 6 | **Ouvrir l'espace** : `eef-space-on` (simulation, puis application) — seulement 54 en vente et adoptée, et point 1 tranché | toi + moi | `docs/runbook-ouverture-espace-reel.md`. Retour arrière : `eef-space-off`. |
| 7 | **Annonce** (audience `eef_interest` / `all_students_except_countries` + `eef_suspended`, route `/etudes-en-france`) | toi | Après le point 6 seulement : sinon la notification mène à la vitrine. |
| 8 | **Session admin qui expire au bout d'une heure** sans renouvellement (le 401 de la page Rapports) | code | Défaut préexistant de l'admin, sans lien avec la publication. |
| 9 | Refaire `eef:check-sources` **toutes les deux semaines** et republier ce qui revient | code / ops | Le rapport a 14 jours de validité ; 184 adresses sont « incertaines ». |

