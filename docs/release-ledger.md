# Release ledger

Un numéro listé sous **Consommés** ne peut plus figurer dans `pubspec.yaml`.
Le numéro sous **Courant** est le seul autorisé. Le test
`test/release/build_number_test.dart` lit ce fichier.

## Consommés

- `46` — AAB CI du 31/07/2026, jamais téléversé sur Play
- `48` — consommé sur TestFlight le 12/08/2026

## Courant

- `49` — SHA de la branche release, à remplir le jour J

### Ce que 49 embarque en plus

- **Espace « Études en France » — Phase 0.** La vitrine ET la coquille de
  l'espace, toutes deux **éteintes à la compilation**. Rien n'apparaît tant que
  `/config/app` ne les allume pas.

  Le numéro de build n'est PAS incrémenté : 49 est encore le courant et n'a pas
  été livrée. Ce lot monte dedans.

  Bascule côté serveur — **valeurs arrêtées** (campagne 2027-2028, voir
  `docs/eef-campaign-calendar-2027-2028-research.md`) :

  ```bash
  KPB_EEF_TEASER_ENABLED=true
  KPB_EEF_CAMPAIGN_OPENS_AT=2026-10-01T00:00:00Z
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
