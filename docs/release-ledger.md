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

- `53` — rien encore. Le numéro est ouvert parce que la 52 est consommée :
  Apple refuse un `CFBundleVersion` déjà téléversé, et un archivage reparti
  sur 52 aurait échoué au moment du Distribute, c'est-à-dire le plus tard
  possible.

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
