# Release ledger

Un numéro listé sous **Consommés** ne peut plus figurer dans `pubspec.yaml`.
Le numéro sous **Courant** est le seul autorisé. Le test
`test/release/build_number_test.dart` lit ce fichier.

## Consommés

- `46` — AAB CI du 31/07/2026, jamais téléversé sur Play
- `48` — consommé sur TestFlight le 12/08/2026
- `49` — installée et revue par le propriétaire le 29/08/2026
  (`docs/device-qa-build49.md`). Cette revue a produit neuf demandes ; les
  correctifs montent dans la 50, donc la 49 ne repart pas.
- `50` — téléversée sur TestFlight le 30/08/2026 à 02h15. Elle porte sept des
  neuf points de la revue. Trois manques constatés par le propriétaire sur cet
  artefact : les outils CV/lettres restaient masqués (drapeau de COMPILATION,
  donc impossible à ouvrir sans binaire neuf), PostHog partait sans clé, et la
  prélude Campus France restait éteinte côté serveur. La 50 ne repart pas.
- `51` — **jamais archivée ni téléversée.** Le numéro a porté le dépôt du
  31/08 au 03/09/2026 — plusieurs PR fusionnées et des artefacts de CI
  l'ont embarqué — mais aucune archive n'a été produite. Son contenu monte
  intégralement dans la 52, qui y ajoute la liste d'attente Premium. Brûlée
  plutôt que réutilisée : « build 51 » désigne déjà quelque chose de précis
  dans les échanges avec le propriétaire, et faire porter ce nom à un autre
  artefact aurait rendu toute trace ultérieure ambiguë.

- `52` — **livrée aux deux plateformes le 03/09/2026.** Archive iOS
  téléversée sur App Store Connect à 11h22 (« Uploaded to Apple ») ; AAB
  Android signé et vérifié par la CI le même jour (run 33752445518,
  artefact `app-release-android-aab`).

  Premier artefact dont la télémétrie et la lisibilité des plantages sont
  PROUVÉES et non supposées :
  - clé PostHog présente dans le binaire iOS (`strings` : 1 occurrence ;
    la 50 en avait 0) et exigée par la garde du job AAB avant construction ;
  - 55 dSYM produits et envoyés à Crashlytics — le journal d'archivage
    porte « Successfully submitted symbols for architecture arm64 » sous
    l'identifiant de la phase `30944CAE…` ;
  - AAB signé par LA clé d'upload attendue, empreinte SHA-256 comparée à
    celle du keystore installé par le job lui-même.

  Backend au même SHA que la build (`b6d8d769cc71` au moment de l'archive),
  couplage `requires-new` satisfait et vérifié par le préflight de release.
  La 52 ne repart pas.

- `53` — **`2.2.0 (53)`, livrée aux deux stores : la 2.2.0 est EN VENTE sur
  l'App Store depuis le 13/09/2026** (vérifié le 29/09/2026 : la page de la fiche
  affiche « 2.2.0 », mise en ligne le 13/09/2026). Rigoureusement le même code
  applicatif que la 52 : sa raison d'être était la version marketing, qui seule
  permet à `isVersionBelow` de distinguer une build d'une autre. Le détail de sa
  construction et de sa vérification est dans l'historique git de ce fichier. La
  53 ne repart pas, et le train « 2.2.0 » est fermé : App Store Connect refuse
  toute build dont la version marketing n'est pas supérieure à 2.2.0.

## Courant

- `54` — **`2.3.0 (54)`. La build « ouverture sûre » de l'espace Études en
  France.** Le dépôt livrait `2.2.0+53` ; la 53 est en vente depuis le 13/09/2026,
  donc App Store Connect refuse toute build dont la version marketing n'est pas
  **strictement supérieure** à 2.2.0 (ITMS-90062). D'où `2.3.0`, et non `2.2.1` :
  c'est une build de fonctionnalités, pas un correctif.

  **Elle part avec l'espace réel ÉTEINT.** Tout ce que la 54 ajoute pour
  « Études en France » est derrière `features.eefSpace`, une clé que seul le
  serveur allume : à l'approbation, un utilisateur de la 54 voit la vitrine de la
  53 (avec en plus ses liens vers les sources officielles et un sélecteur de
  domaines dans la déclaration). L'ouverture est une opération serveur séparée
  (`docs/runbook-ouverture-espace-reel.md`), sans nouvelle soumission.

### Ce que 54 embarque

**1. Le hub de l'espace « Études en France » (derrière `eefSpace`).**
- Hub : héros (où se dépose la candidature, suspension qui remplace la date, lien
  vers la plateforme officielle), catalogue, CV / lettres / entretien (même masque
  `aiToolsEnabled` que la boîte à outils), conseiller WhatsApp. Plus aucun module
  « en préparation ».
- Catalogue (serveur, #280 puis cette build) : recherche par nom d'université,
  sigle, ville, sans accents ; filtres Niveau et Procédure ; carte qui nomme
  l'université, la ville et la procédure (DAP blanche / jaune, Études en France,
  Parcoursup, hors procédure) ; « le catalogue arrive » distinct de « ta
  recherche est trop étroite » ; une page suivante en panne garde la liste ;
  « Tout effacer » vide aussi le champ ; la barre de facettes n'a plus de hauteur
  fixe.
- Mentions : paternité de la Licence Ouverte 2.0 (producteur, licence, date de
  mise à jour **servis** par `/config/app`), non-affiliation avec lien vers la
  plateforme officielle, mise en garde de suspension avec sa source.
- Profil « Mon profil Études en France » : niveaux + domaines d01–d12 (préremplis
  depuis le profil par une table fermée), **Modifier par `PATCH`** (ni
  consentement redemandé, ni intérêt Premium effacé), **Me retirer** — la promesse
  « depuis cet écran » du texte de consentement est tenue. Texte
  `eef-consent-v1` **inchangé**, archivé dans `docs/eef-consent-v1.md`.
- Parents et partenaires arrivés par lien : « un espace pour les étudiants » (pas
  un 403 traduit en « reconnecte-toi »). Invité : catalogue public, invitation à
  créer un compte pour le profil.
- Mesure : `eef_space_viewed`, `eef_hub_tile_opened`, `eef_catalog_viewed`,
  `eef_catalog_searched`, `eef_catalog_failed` — des comptes, **jamais le texte
  tapé** (`docs/analytics-event-contract.md`).

**2. Le socle qui rend les builds suivantes pilotables.**
- **En-têtes `X-KPB-App-Version` / `X-KPB-App-Build`** sur chaque requête (CAT-03) :
  avant, le serveur ne pouvait pas distinguer une 53 d'une 54. Ils ne cassent
  jamais une requête (lecture mémorisée, échec = pas d'en-tête).
- **Bandeau doux « une mise à jour est disponible »** piloté par
  `recommendedVersion` (XC-09), fermable, masqué sans lien de store. C'est le
  levier des passages 54 → 55 → forum sans relever `minVersion` (qui bloque l'app).
  `vps-ops` → `recommended-version-set`.
- **Liens officiels servis** (XC-05) : `eefCampaign.platformUrl`,
  `suspendedSources` (https seulement, sans identifiants) ; `eefCatalog`
  (attribution, gardée contre `manifest.json` par un spec).

**3. Embarqué depuis la 53 (déjà sur `main`).** Lien profond `/parcours/<slug>` du
push « récit de la semaine » (#284) ; étiquettes OneSignal normalisées (#286) ;
email manquant qui bloquait la synchro du profil (#291) ; logos Wikimedia Commons
avec crédit de licence (#281, 330 px — MISS-01) ; client de recherche serveur
(#280).

**4. Conformité.**
- MISS-02 : la jauge « 85 % » **codée en dur** disparaît de la fiche
  établissement, avec un garde qui interdit tout score littéral.
- FOR-M05 : « Un espace communautaire » retiré des CGU (web et app) tant que le
  forum n'est pas livré. LIV-28 : « Dernière mise à jour : septembre 2026 »
  (politique et CGU, web et app).
- Wikimedia déclaré comme destinataire dans les réponses de console
  (`CONSOLE_ANSWERS.md` §5).

**Ce que la 54 ne contient PAS** (et qu'aucun texte de fiche ne doit vanter) : la
fiche formation, l'onglet Universités, la sélection en trois étages, la checklist,
le projet d'études, les favoris synchronisés (build 55) ; le forum (build dédiée) ;
tout logo visible (aucun établissement actif n'en a) ; un catalogue non vide
(rien n'est publié au 01/10).

### Couplage backend de la 54 : `tolerates-old`

La 54 ne **dépend** d'aucun backend récent pour fonctionner : chaque appel neuf est
soit derrière `eefSpace` (que seul un backend récent peut allumer), soit tolérant à
une clé absente (`recommendedVersion`, `eefCatalog`, `platformUrl`,
`suspendedSources`, `catalogPublished` — lue « publié » quand elle manque). Un
backend en retard se traduit par **moins de choses affichées**, jamais par une
erreur : c'est la définition de `tolerates-old`. Le préflight se lance donc avec
`backend_coupling=tolerates-old` (`113cc55` tournait en production à l'audit du
29/09 et est un ancêtre de la release ; relire `GET /api/health/version` avant de
lancer le préflight : un déploiement de `main` depuis a pu le faire avancer).

⚠️ **Mais l'OUVERTURE de l'espace exige le backend de cette build** — le commit de
fusion de la branche, **pas `95440db`** (qui porte la recherche et le `PATCH`
mais ni la mention de paternité `eefCatalog`, ni les liens officiels, ni les
audiences de campagne) : `PATCH /etudes-en-france/interest`, `catalogPublished`,
la recherche par `searchText`, la migration
`20260930120000_eef_search_text_and_acronym`, l'import indexé, `eefCatalog`,
`platformUrl`, `suspendedSources`. Si l'espace doit être allumé À L'APPROBATION
(état B du pack de soumission), ce backend doit être en ligne AVANT la soumission
et le préflight se lance en `requires-new` : le catalogue ne doit jamais s'afficher
sans sa mention. L'ordre — déploiement backend `scope=full`, `eef-import`,
publication du pilote, **puis** `eef-space-on` — est dans
`docs/runbook-ouverture-espace-reel.md`. `eef-space-on` refuse d'écrire tant
qu'aucune formation n'est publiée **ou** que le conteneur ne porte pas ce backend
(`eef-catalog-attribution.js`), et le workflow vérifie après coup que
`/config/app` sert `eefCatalog` et `platformUrl`.

### Ce qui reste à faire par un humain avant la soumission

Voir `docs/release-54-store-pack.md` (notes de version, notes de revue, décision
XC-03), `docs/device-qa-build54.md` (QA appareil, budget de performance),
`docs/CONSOLE_ANSWERS.md` §0quater (déclarations de console) et
`docs/eef-consent-v1.md` (questions juridiques ouvertes).

### Ce que 52 embarque

- **Liste d'attente Karatou Premium (PR #258).** Point 8 de la revue du build
  49 : un bouton d'inscription gratuite, pour que l'équipe puisse compter la
  demande avant de construire le Pass. Table DÉDIÉE `PremiumWaitlistEntry`, et
  non un drapeau de plus sur `EefInterest` — ce dernier est un registre de
  consentement, et y cocher un intérêt Premium aurait fabriqué un consentement
  « Études en France » que l'étudiant n'a jamais donné.

  L'écran présente enfin le Pass pour ce qu'il est : une candidature accompagnée
  de bout en bout. Toujours **aucun prix, aucun tunnel d'achat, aucun verbe
  d'abonnement** (App Store 3.1.1) — et cette règle est désormais exécutable,
  un test balayant toutes les clés `premium_pitch_*` et `premium_waitlist_*`.

- **dSYM envoyés à Crashlytics (PR #257).** Le projet Xcode n'avait aucune phase
  `upload-symbols` : les plantages de la 50 sont arrivés en adresses mémoire
  brutes, inexploitables. La phase ne tourne QUE pendant un archivage
  (`ACTION=install`), et l'absence de dSYM y est fatale plutôt qu'avertie.

- **Garde PostHog côté Android (PR #257).** Le job AAB substituait le secret
  sans jamais le regarder — le défaut exact qui a envoyé la 50 iOS sans
  télémétrie. Mêmes trois règles des deux côtés désormais, appliquées AVANT la
  construction.

**Couplage backend : `requires-new`.** Deux raisons, et la première suffit :

1. La liste d'attente appelle `/premium/waitlist`, absente d'un backend
   antérieur — le bouton tomberait dans le vide.
2. `consentVersion` est validé contre une **liste fermée** côté serveur
   (`premium-waitlist-consent.ts`). Une app qui enverrait une version que le
   backend ne connaît pas se verrait refuser l'inscription en 400.

**Ce couplage est DÉJÀ satisfait** : le backend a été déployé le 03/09/2026 à
02h15 UTC au SHA `e9576c0831ab`, migration `20260903090000_premium_waitlist`
appliquée (« All migrations have been successfully applied »), et
`GET /premium/waitlist` est passé de 404 à 401 vu de l'extérieur.

<!-- Historique de la 50, conservé : -->
- ~~`50`~~ — revue du build 49 : jauge de progression, boîte à outils limitée à
  l'accueil, catalogue hors-ligne repassé en français, checklist de profil
  réparée, champs orphelins rouverts à l'édition (dont le budget), mesure
  d'audience active par défaut + clause CGU, bourses « à venir ».

  **Couplage backend : `requires-new`, et ce n'est PAS le cas de la 49.**
  La 49 était `tolerates-old` : contre un backend en retard, ses drapeaux
  retombaient sur `false` et ses entrées se masquaient. La 50 n'a pas cette
  propriété, pour une raison précise et vérifiable : `main.ts:68-71` monte la
  `ValidationPipe` avec `forbidNonWhitelisted: true`, et le profil envoie
  désormais `bacSeries` à chaque `PATCH /profiles/me`. Contre un backend sans
  ce champ au DTO, la requête ne perd pas un champ — elle est **rejetée en
  400**, donc TOUTE sauvegarde de profil échoue.

  Le backend doit donc être déployé AVANT la distribution, migration
  `20260829140000_profile_bac_series` comprise (additive : une colonne
  nullable, sans défaut ni reprise).

### Ce que 49 embarque en plus

- **Notice IA : OpenRouter nommé (PR #239, 26/08/2026).** Le consentement
  KPB Intelligence et la divulgation des outils (FR/EN) nomment désormais
  OpenRouter aux côtés de Groq, en cohérence avec la bascule du provider LLM
  (deepseek-v4-flash, routage épinglé zdr + data_collection=deny). Le backend
  et la politique web sont déjà en prod avec ce texte ; la 49 aligne l'app.
  Le numéro de build n'est PAS incrémenté : ce lot monte dans la 49, comme
  le lot EEF ci-dessous.

- **Espace « Études en France » — Phase 0.** La vitrine ET la coquille de
  l'espace, toutes deux **éteintes à la compilation**. Rien n'apparaît tant que
  `/config/app` ne les allume pas.

  Le numéro de build n'est PAS incrémenté : 49 est encore le courant et n'a pas
  été livrée. Ce lot monte dedans.

  Bascule côté serveur — **valeurs arrêtées** (campagne 2027-2028, voir
  `docs/eef-campaign-calendar-2027-2028-research.md`) :

  ```bash
  KPB_EEF_TEASER_ENABLED=true
  KPB_EEF_CAMPAIGN_OPENS_AT=2026-10-01
  KPB_EEF_SUSPENDED_COUNTRIES=Niger,NE
  # KPB_EEF_CAMPAIGN_CLOSES_AT — DÉLIBÉRÉMENT NON POSÉE (voir plus bas)
  ```

  **Pourquoi pas de clôture globale.** Les clôtures divergent : Maroc
  15 novembre 2026 (confirmé), Rwanda et Maurice 15 décembre (estimé), Algérie
  « information à venir », 91 couples pays × procédure non publiés. Une clôture
  globale ferait manquer la campagne à un étudiant marocain qui croirait avoir
  jusqu'en décembre. L'app affiche donc « À partir du 1er octobre 2026 » plus
  une ligne disant que les clôtures varient selon le pays. Les clôtures par
  pays arrivent avec le catalogue de la Phase 1, déjà structuré par pays.

  **Pourquoi le Niger est dans la liste des suspendus.** La page officielle de
  l'ambassade indique que la dénonciation de la convention du centre qui
  hébergeait Campus France rend impossible le traitement des dossiers
  d'étudiants nigériens. L'ouverture nationale de la plateforme reste exacte et
  sans effet pour eux ; la vitrine remplace donc la date par une mise en garde
  et un relais conseiller. `Niger` et `NE` sont tous deux listés parce que
  `countryOfResidence` est un nom saisi au clavier, pas un code. Une
  réouverture se traite en retirant la valeur — pas en passant au store.

  À l'ouverture réelle de l'espace, plus tard — **ne plus poser
  `KPB_EEF_ENABLED`** (corrigé le 30/09/2026, voir l'entrée « Build 54 —
  backend ») :

  ```bash
  KPB_EEF_SPACE_ENABLED=true         # action vps-ops « eef-space-on »
  ```

  `KPB_EEF_ENABLED` désactive `eefTeaser` côté serveur, et les builds 49 à 53
  le lisent : le poser leur retire leur vitrine et leur montre une coquille
  vide. `features.eefSpace` est une clé NOUVELLE, que seule la build 54 écoute ;
  elle ne touche ni à `eef` ni à `eefTeaser`.

  Sans variable posée, l'app **n'annonce aucune date** : une date mal
  configurée vaut `null`, jamais un repli. Retour arrière : remettre la variable
  à `false`, sans passer par les stores.

  Vérification après bascule : `GET /config/app` doit répondre
  `features.eefTeaser: true`. La liste des intéressés se lit sur
  `GET /admin/etudes-en-france/interest` (résumé, liste, `export.csv`).

  **Les variables atteignent bien le conteneur, désormais.** Elles étaient
  documentées ici et dans le runbook, et absentes du bloc `environment:` de
  `docker-compose.yml` : le `.env` ne sert qu'à l'interpolation, donc les poser
  n'avait AUCUN effet. Corrigé, et `test/release/config_env_relay_test.dart`
  interdit la répétition — il compare les variables lues par `/config/app` au
  relais compose et à `.env.example`.

  **Où se pose réellement cette bascule** : `docs/cutover-build49.md`, étape
  9 bis. Ce n'est pas une redondance — ce runbook est ce qu'on suit ligne à
  ligne le soir de la livraison, et il dit AUSSI pourquoi ces variables ne se
  posent qu'après le déploiement couplé, et non avant.

  **Une migration s'applique désormais.** Ce lot ajoute
  `backend/prisma/migrations/20260821120000_eef_interest`, appliquée par le
  `prisma migrate deploy` du déploiement `scope=full`. Elle est additive — une
  table neuve, trois index, une clé étrangère — donc sans effet sur les données
  en place. Le runbook affirmait qu'il n'y avait rien à migrer : c'était vrai
  quand il a été écrit, et l'étape 1 a été corrigée.

  **Le sens du couplage ne change pas.** La 49 reste `tolerates-old` au
  préflight : contre l'ancien backend, les clés `eefTeaser` / `eef` /
  `eefCampaign` sont absentes, les drapeaux retombent sur `false`, et les quatre
  points d'entrée se masquent — même mécanique que le masquage des outils IA. Le
  déploiement couplé reste dû, maintenant pour deux raisons : `AiConsentGuard`
  et la table `EefInterest`.

## Déploiements backend sans build

Un déploiement du backend seul ne consomme aucun numéro de build : il n'a donc
pas de ligne sous **Consommés**, ni sous le numéro courant. Il est consigné ici
pour que l'ordre de livraison (`docs/DEPLOYMENT.md`, « le backend d'abord, le
mobile ensuite ») reste lisible.

### 29/09/2026 — frontière de l'import « Études en France » et auteur des avis conseillers

**État : prêt, PAS déployé.** Sur la branche `claude/campus-france-space-98orw9`,
non fusionné, sans PR : la CI ne se déclenche que sur `main` et sur les PR vers
`main`, elle n'a donc PAS encore tourné sur ces commits (le dernier run de la
branche date du 22/08/2026). La production tourne au SHA `113cc55a39cf` (démarrée le
22/09/2026) ; trois commits de `main` n'y sont pas non plus (#285, #286 —
étiquettes OneSignal pour la segmentation —, #291 — l'email manquant bloquait
toute la synchro du profil).

**Couplage : `tolerates-old` côté mobile.** Aucune route nouvelle, aucun champ
que les builds installées (49 à 53) devraient envoyer. **Côté admin, le
déploiement est couplé** : voir la file `/verification` ci-dessous.

- `GET /catalog/institutions`, `GET /catalog/programs` et `/matches/*` cessent de
  servir des lignes de l'import « Études en France ». **Aucune n'est publiée
  aujourd'hui : rien ne change à l'écran.** La garde est posée AVANT la première
  publication, ce qui est tout son sens (voir `docs/eef-catalog-pipeline.md`,
  § 2ter).
- `GET /etudes-en-france/search` et `/shortlist` ne servent plus QUE les lignes de
  l'import (même définition que l'exclusion ci-dessus) : une formation d'école
  partenaire que l'exploitation qualifierait d'une procédure resterait dans le
  catalogue général, et n'entrerait pas dans l'espace. Aucune ligne n'est publiée
  aujourd'hui : rien ne change à l'écran.
- `POST /counsellors/:id/reviews` : l'auteur vient du jeton. Le corps
  qu'envoient les builds 49 à 53 (`rating`, `body`, `reviewerName`, `caseId`) est
  **accepté tel quel** — `reviewerName` est déclaré et ignoré, sans quoi la
  validation globale (`forbidNonWhitelisted`) répondrait 400 à tous leurs avis.
  Un texte trop long est **tronqué à 1 000 caractères** (sans couper un emoji en
  deux) et non refusé : le champ de saisie de l'app n'a aucune limite, un 400 lui
  ferait perdre le texte. Ce qui change de leur point de vue : un avis sur un
  dossier qui n'est pas terminé (409), qui n'est pas le leur (404), qu'un autre
  conseiller a traité (403) ou qui est déjà noté (409) est refusé, alors qu'il
  était enregistré. L'app ne propose de noter qu'un dossier terminé, traité par
  son conseiller, une fois : ces refus ne correspondent à aucun parcours de
  l'app. « Un avis par dossier » est une garde au mieux-effort — aucune contrainte
  d'unicité en base.
- `GET /counsellors/:id` ne sert plus la clé de rattachement (`reviewerUserId`,
  `caseId`) des avis publiés, et ne sert que ceux dont l'auteur a un reçu
  `public_testimonial` actif — la porte de `/impact/reviews`. Aucun client de
  l'app n'appelle cette fiche.
- `PATCH /cases/:id` **côté étudiant est supprimé** (404). Il laissait le
  propriétaire fixer `status`, `assignedAdvisorName` et le texte de la prochaine
  étape de son propre dossier — donc se déclarer « terminé » et ouvrir le droit de
  noter un conseiller. Le client de l'app définissait `updateCase` sans qu'aucun
  écran ni test ne l'appelle (constaté sur l'historique disponible, qui remonte
  au 23/08/2026 : les builds antérieures ne peuvent pas être relues d'ici) ;
  l'équipe passe par `PATCH /admin/cases/:id`, inchangé. Si une build installée
  l'appelait, elle recevrait un 404.
- `GET /profiles/me/export` gagne un champ `counsellorReviews` (les avis que
  l'utilisateur a laissés) ; la suppression de compte efface ses avis, signés ou
  restés sans auteur mais posés sur l'un de ses dossiers. Additif.
- `GET /admin/catalog/verification-due` : les lignes de l'import « Études en
  France » **encore inactives** en sortent, ainsi que du compteur du tableau de
  bord et de l'alerte de 07 h — elles n'ont jamais été publiées, ce ne sont pas
  des fiches à REvérifier. Si l'import a été appliqué en production (le plan de
  livraison en mesure 10 247 formations, inactives), le code actuel les y liste
  comme « jamais vérifiées » : la page et l'alerte s'allègent d'autant le jour du
  déploiement. `total` et `truncated` s'ajoutent ; la file est plafonnée à
  500 éléments **sans qu'aucune catégorie soit affamée** (chacune de celles qui
  ont des lignes reçoit au moins 500 ÷ leur nombre de places — 125 avec les
  quatre) et triée dans un ordre total (jamais-vérifiés et plus périssables
  d'abord, puis échéance la plus ancienne). Les quatre catégories (pays,
  établissements, formations, bourses) partagent désormais UNE définition avec le
  compteur du tableau de bord et l'alerte de 07 h.

  **L'admin doit partir avec l'API (`scope=full`).** Un admin qui ne serait pas
  redéployé ignore `total` et `truncated` : il afficherait « 500 ouvertes »
  sans le moindre avertissement, alors qu'il en reste davantage. C'est le seul
  couplage de ce lot ; la page `/verification` de l'admin fourni ici affiche le
  nombre de lignes montrées sur le total réel, et invite à recharger une fois le
  lot validé.

- **Nouvelles routes admin de publication de l'import** (`admin/etudes-en-france/
  publication/*`, `admin` et `super_admin` seulement) : publier ou retirer un
  établissement et ses formations, simulation par défaut, relecteur = la session.
  Aucun client de l'app ne les appelle ; aucune ligne n'est publiée tant que
  personne ne s'en sert. Détail : `docs/api-contracts.md`. **Couplage admin :** le
  nouvel écran « Publication EEF » de l'admin appelle ces routes, donc le backend
  part AVANT l'admin (un admin plus ancien n'a simplement pas l'écran). L'écran a
  été exercé dans un navigateur contre un faux serveur qui réutilise le vrai plan
  du backend (parcours complet, refus, retrait), pas contre une base de production.
- **Publication de l'import : trois failles fermées après la revue automatique de la
  PR.** (1) `PATCH`/`POST /admin/catalog/…` ne peuvent plus ACTIVER une ligne de
  l'import (409) : la publication passe uniquement par « Publication EEF » ; les
  autres usages de ces routes sont inchangés. (2) Activer un établissement
  revalide ses formations déjà actives ; l'une invalide refuse l'établissement
  (`institution_has_invalid_active_program`, `plan.programs.activeInvalid`) — un
  motif de refus de plus, que l'écran affiche. (3) La transaction d'écriture est en
  `RepeatableRead` : une modification concurrente annule la publication (409) au
  lieu d'être publiée et signée. **Couplage admin :** un admin plus ancien
  ne connaît pas le nouveau motif et l'afficherait en clé brute ; le backend part
  AVANT l'admin, comme pour le reste du lot.
- **Documentation des sources corrigée, deux dossiers de décision ouverts.** La SOP
  et le pipeline affirmaient « chaque ligne porte sa fiche officielle » : c'est faux
  pour 4 212 lignes sur 10 502 (portail Mon Master, jeu de données ouvert) —
  `docs/eef-catalog-pipeline.md` § 2.8. L'écran de publication compte ces lignes
  avant de demander la signature (`programs.genericSource`). À faire trancher :
  `docs/eef-dossier-relecture-procedures.md` (partage DAP / Études en France) et
  `docs/eef-dossier-juridique-logos.md`.
- **Logos des établissements : 320 px → 330 px.** Wikimedia refuse les largeurs
  hors liste standard (HTTP 400) : les 26 logos SVG de l'import ne s'affichaient
  pas. Le serveur sert désormais 330 px, y compris pour une ligne importée avec
  l'ancien 320 px. Les builds installées affichent l'URL du serveur telle quelle :
  elles en profitent sans mise à jour ; le client Flutter est aligné pour la
  prochaine build. Détail : `docs/eef-catalog-pipeline.md` § 2.6bis.
- **Domaines de l'import « Études en France » réalignés sur l'orientation.**
  Dix domaines sur douze de l'import portaient le nom d'un autre (`d03` était
  « Finance », `d05` « Ingénierie »…). Les 10 502 formations versionnées sont
  réécrites (3 134 changent) et la recherche, le validateur et le classement de la
  shortlist ne parlent plus qu'une liste. Aucun effet à l'écran aujourd'hui
  (rien n'est publié). **Les lignes déjà importées en production gardent
  l'ancien domaine** : avant toute publication, `eef-purge-pending` puis
  `eef-import` (VPS ops, dry-run d'abord), après avoir lu `db-info` section 10.
  Détail et choix à confirmer : `docs/eef-catalog-pipeline.md` § 2.7.

**Une migration s'applique :** `20260929120000_counsellor_review_author_backfill`.
Des DONNÉES seulement — un `UPDATE` qui rattache les avis déjà enregistrés sans
auteur au propriétaire du dossier noté — sans changement de schéma,
idempotente, sur une table de quelques lignes. Appliquée par le
`prisma migrate deploy` du déploiement `scope=full`. L'ordre entre la migration
et le remplacement des conteneurs est sans conséquence, avec une réserve : entre
les deux — et après tout retour à l'ancien code — l'ancien service peut encore
créer un avis sans auteur ; rejouer le SQL de la migration (idempotent) le
rattache. Ce n'est pas un trou d'effacement : la suppression de compte et l'export
retrouvent aussi les avis sans auteur par le dossier de l'utilisateur.

**Avis orphelins — une décision à prendre, avec son chiffre.** Un avis dont le
dossier n'existe plus (compte déjà supprimé) ou n'a jamais été renseigné n'a plus
d'auteur retrouvable ; il peut porter un nom civil. Le compter avant de décider
(anonymiser `reviewerName`, ou supprimer) :

```sql
SELECT count(*) AS orphelins,
       count(*) FILTER (WHERE r."isPublished") AS dont_publies
FROM "CounsellorReview" AS r
WHERE r."reviewerUserId" IS NULL
  AND NOT EXISTS (SELECT 1 FROM "Case" AS c WHERE c."id" = r."caseId");
```

Validée à la main sur PostgreSQL 16 — les 64 migrations sur base neuve (puis
« No pending migrations to apply » au second passage), et un `migrate deploy` sur
une base peuplée de 7 avis (2 rattachés, 4 laissés à `NULL` faute de
correspondance, 1 déjà attribué et non écrasé), rejeu à `UPDATE 0`, et trois
mutants de la clause `WHERE` tous détectés — parce que la CI ne l'exécute pas
tant que son pas unitaire est rouge (voir ci-dessous). La CI, elle, tourne sur
PostgreSQL 15 et Node 20 : ces deux versions n'ont pas pu être exercées ici.

**Catalogue de bourses relu le 29/09/2026 — blocage levé par #292, version
1.4.0.** Le validateur refuse toute source contrôlée il y a plus de 30 jours : les
34 fiches, relues le 24/08, étaient périmées depuis le 23/09 et un seul test
(`scholarship-catalog.validator.spec.ts › reste importable à la date du jour`)
tenait `Backend CI` rouge sur `main`, donc bloquait `deploy.yml`, qui exige un run
vert sur le SHA exact. **#292 l'a levé le 29/09** (Backend CI vert sur `51a620a`) :
34 fiches relues, dont UP Mastercard relue au navigateur par l'équipe — le site
bloque les robots (Cloudflare), qu'on ne contourne pas.

Cette branche portait une **seconde relecture indépendante** des mêmes fiches
(`docs/catalog-verification-2026-09-29.md`, rapports bruts dans
`docs/evidence/catalog-2026-09-29/`). Comparée champ par champ à #292 avant la
fusion, elle y ajoute **58 champs sur 15 fiches**, dont deux qui changent ce que
l'étudiant lit sur le financement : en Licence la bourse Türkiye–IsDB est un
**prêt** à rembourser, et la demande d'aide ALU est un **dossier distinct**. Le
catalogue passe en 1.4.0. Le détail, et ce qui a été écarté, est dans le journal.

- **Trois clôtures proches** : UP **le 30/09** (le cycle doit passer en `closed`
  aujourd'hui), Chevening et Knight-Hennessy le 06/10. `catalog-freshness.yml`
  (issue #270) les signale ; `catalog:publish` saute les fiches périmées.
- **La production ne bénéficie pas de ces corrections toute seule.** Les lignes de
  bourses en base datent de l'import d'août (catalogue 1.3.0 mesuré le 31/08) :
  après le déploiement, lancer `publish-catalog` (VPS ops) — `import` →
  `reconcile` → `switch`, dans cet ordre. `import` seul ne corrige rien.
- **À revérifier** : la source « éligibilité » d'IsDB (`/scholarshipsprograms`) ne
  contient pas IsDB dans son HTML statique ; les écarts entre les formulaires PDF
  2027 d'UP et ses pages HTML (facultés, Master de première année seulement,
  moyenne minimale de 70 %).

### 30/09/2026 — backend de la build 54 : ouverture de l'espace, recherche, profil

**État : prêt, PAS déployé.** Sur la branche `claude/campus-france-space-98orw9`,
au-dessus de la fusion de la PR #293. Aucun client n'appelle encore ce qui est
nouveau ; rien n'est publié, `KPB_EEF_ENABLED` reste faux.

**Couplage : `tolerates-old` côté mobile.** Que des ajouts : une clé dans
`/config/app`, des champs dans les items de la recherche et de la shortlist, une
clé dans la réponse de la recherche, une route `PATCH`. Les builds 49 à 53 les
ignorent et continuent de tout lire. **Une migration** :
`20260930120000_eef_search_text_and_acronym` — deux colonnes nulles, aucune
réécriture de table, aucun index, aucune extension.

- **`features.eefSpace` : l'ouverture de l'espace pour la seule build 54.**
  `KPB_EEF_ENABLED` ne peut plus être le commutateur : les builds 49 à 53 le
  lisent, et pour elles il retire la vitrine et montre une coquille vide. La
  nouvelle clé (`KPB_EEF_SPACE_ENABLED`) n'est lue que par la 54, et ne touche ni
  à `eef` ni à `eefTeaser`. `eef` l'allume aussi. Relayée dans
  `docker-compose.yml`, documentée dans `.env.example`, gardée par
  `config_env_relay_test` et `delivery-gate.sh`.
- **Trois actions vps-ops.** `eef-space-on` (simulation par défaut ; refuse tant
  qu'aucune formation de l'import n'est publiée, refuse si `KPB_EEF_ENABLED=true`
  est posé ; le workflow PROUVE ensuite `features.eefSpace` depuis l'extérieur et
  que `eef` est resté faux), `eef-space-off` (le retour arrière, sans simulation) et
  `eef-campaign-set` (ouverture, clôture, pays suspendus — valeurs écrites dans le
  script, donc relues en PR, sans dépendre de `eef-teaser-on`). Exercées contre un
  faux `docker` (10 scénarios) et la requête de décompte contre un vrai Postgres.
- **Recherche libre : sans accents, par université, par niveau.** « genie » trouve
  508 formations au lieu d'1 (mesuré sur les 10 502 lignes : identique à « génie »),
  « sorbonne » 605, « UPEC » 215, « master droit rennes » 10. Mesuré sur la même
  base : le coût d'une requête ne change pas (~25 ms le `count`). Jamais moins de
  résultats qu'avant : une ligne sans texte normalisé retombe sur la comparaison
  brute. Détail : `docs/api-contracts.md`.
- **Chaque item nomme son établissement** (recherche et shortlist) et porte la
  procédure, le cycle, la sélectivité, la ville, le code de formation — de quoi
  afficher une carte utilisable. Le logo est servi avec sa licence.
- **`catalogPublished`** dans la réponse de la recherche : « rien n'est publié »
  se distingue enfin de « ta recherche est trop étroite ».
- **`PATCH /etudes-en-france/interest`** : modifier ses niveaux et ses domaines
  sans réécrire le consentement commercial ni effacer l'intérêt Premium. Sans
  déclaration préalable : 404, jamais une création.

**Après le déploiement, avant d'ouvrir quoi que ce soit :**

1. `eef-import` (simulation, puis application) : il comble maintenant
   `searchText` et `acronym` sur les lignes déjà en base (`eef:backfill:search`,
   rejouable : comble les vides et répare les textes périmés, par
   comparaison-échange, sans jamais écraser une modification concurrente).
   10 502 lignes en ~7 s sur une base de test. Renommer une formation dans l'admin
   recalcule son texte cherchable.
2. `db-info` section 11 : `sans_texte_cherchable` doit valoir 0. Tant qu'il ne
   l'est pas, « genie » ne trouve pas « Génie civil » sur ces lignes.
3. L'ouverture de l'espace réel : `eef-space-on` (simulation d'abord), jamais
   `KPB_EEF_ENABLED`.

**Ce qui n'est pas fait ici, et relève de la build 54 (section F)** : lire ces
champs côté Flutter, afficher l'établissement sur la carte, l'état vide « le
catalogue arrive » (`catalogPublished`), l'appel au `PATCH`, et lire `eefSpace`
dans `RemoteFeatureFlags` / `EefEntry`.
