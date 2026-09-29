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

## Courant

- `53` — **`2.2.0 (53)`. Rigoureusement le même code applicatif que la 52.**

  Entre `b6d8d769cc71` (la 52) et cette build, un seul fichier applicatif a
  changé, et il est côté SERVEUR : `health.controller.ts`, qui expose
  `push: { configured }`. Rien dans `lib/`, rien dans `ios/`, rien dans
  `android/`. La 53 n'est donc pas une nouvelle version du produit — c'est la
  52 sous un autre numéro de version marketing.

  **Pourquoi la construire alors.** Parce que `AppVersionGate` compare la
  version MARKETING au `minVersion` du serveur et que `isVersionBelow` coupe
  la chaîne au `+` : le numéro de build est ignoré. Les 48, 49, 50 et 52
  s'appelant toutes « 2.1.0 », aucune valeur de `KPB_MIN_APP_VERSION` ne
  pouvait en distinguer une seule. Soumettre la 52 en 2.1.0 aurait donc coûté
  une revue de plus pour obtenir, plus tard, une porte de mise à jour qui
  fonctionne. La 53 fait les deux en une soumission.

  **Ce que « même code » NE dispense PAS de faire.** Une première rédaction de
  cette entrée affirmait que la vérification sur appareil de la 52 restait
  valable pour la 53. C'était faux, et dangereusement : elle disait à un
  opérateur de sauter un contrôle que le dépôt rend obligatoire
  (`docs/phase1-stability-smoke-checklist.md` — « every release candidate »,
  sur un appareil physique de chaque plateforme — et la checklist du contrat de
  soumission, qui exige le smoke sur la build SOUMISE).

  Trois raisons, dont la deuxième est la raison d'être de cette build :

  - **la 53 est un artefact NEUF**, reconstruit et re-signé. Une source
    identique ne rend pas deux archives identiques : empaquetage, signature,
    profil, installation et premier démarrage peuvent échouer indépendamment
    du code ;
  - **le comportement de la porte de mise à jour DIFFÈRE** à l'exécution —
    `isVersionBelow` compare « 2.2.0 » au lieu de « 2.1.0 ». C'est précisément
    ce qu'on est venu chercher, donc c'est précisément ce qu'il faut voir
    tourner ;
  - un artefact non installé n'a jamais été vu par personne.

  Ce que « même code » dispense de faire, en revanche : re-parcourir les neuf
  points de la revue du build 49 fonction par fonction. Ils ont été vérifiés
  sur la 52 et aucun code applicatif n'a bougé depuis.

  Reste, comme pour la 52, le seul contrôle que le dépôt ne peut pas rendre :
  la réception effective d'une notification, qui seule prouve l'environnement
  APNs de l'artefact livré.

  **Couplage backend : `tolerates-old`.** Aucune route nouvelle, aucun champ
  nouveau envoyé par l'app. `push.configured` est une LECTURE que l'app ne
  fait pas ; le déploiement qui l'a livrée est déjà en production
  (`0ec1c1e42b6d`). La 53 tourne indifféremment contre ce backend ou contre
  le précédent.

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

  À l'ouverture réelle de l'espace, plus tard :

  ```bash
  KPB_EEF_ENABLED=true               # retire la vitrine TOUT SEUL
  ```

  `eef` désactive `eefTeaser` côté serveur : il n'y a rien à éteindre dans un
  second temps. C'est volontaire — l'oubli inverse afficherait « en préparation »
  à côté d'un espace vivant, et personne ne voit ça depuis un tableau de bord.

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

**Catalogue de bourses relu le 29/09/2026 (version 1.4.0) — un seul blocage
reste.** Le validateur refuse toute source contrôlée il y a plus de 30 jours :
les 34 fiches, relues en une passe le 24/08/2026, étaient périmées depuis le
23/09 et ce seul test (`scholarship-catalog.validator.spec.ts › reste importable
à la date du jour`) tenait `Backend CI` rouge sur `main`. 33 fiches sur 34 ont
été rouvertes sur leurs pages officielles le 29/09 ; leur `checkedAt` est
l'heure réelle de la lecture, propre à chaque fiche, et le contenu a été
corrigé là où la page disait autre chose. Les preuves (extraits mot pour mot,
statuts HTTP, ce qui n'a PAS pu être lu) sont dans
`docs/catalog-verification-2026-09-29.md` et
`docs/evidence/catalog-2026-09-29/`.

- **Reste `up_mastercard_scholars_2027`** (Université de Pretoria) : le site
  répond par un écran anti-robot (Cloudflare) qu'on ne contourne pas ; sa date
  reste celle du 24/08 et le test de fraîcheur échoue donc **tant qu'une personne
  n'a pas relu ses 5 pages dans un navigateur ordinaire** (la clôture est le
  30/09/2026). Il faut aussi y réconcilier les écarts entre le PDF et la page.
  Si la fiche ne peut pas être relue à temps, la retirer du catalogue est une
  décision légitime ; repousser sa date sans lecture ne l'est pas.
- **Trois clôtures proches** : UP (30/09), Chevening et Knight-Hennessy
  (06/10). Le workflow quotidien `catalog-freshness.yml` (issue #270) les
  signale ; `catalog:publish` saute les fiches périmées.
- **La production ne bénéficie pas de ces corrections toute seule.**
  Les lignes de bourses en base datent de l'import d'août (catalogue 1.3.0 mesuré le 31/08) : après le déploiement,
  lancer `publish-catalog` (VPS ops) — `import` → `reconcile` → `switch`, dans
  cet ordre — pour les réaligner. `import` seul ne corrige rien.
- Tant que ce test est rouge, aucun déploiement backend ne part
  (`deploy.yml` exige un `Backend CI` vert sur le SHA exact) et la CI **saute**
  les étapes sur Postgres (migrations sur base neuve, suites d'intégration,
  semis, démarrage) : un run rouge pour cette raison n'est pas un run qui a
  exercé la migration.
