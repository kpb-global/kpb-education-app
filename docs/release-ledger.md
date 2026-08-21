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

  Bascule côté serveur, le jour J — **une seule variable** :

  ```bash
  KPB_EEF_TEASER_ENABLED=true        # la vitrine
  KPB_EEF_CAMPAIGN_OPENS_AT=…        # ISO 8601, optionnel
  KPB_EEF_CAMPAIGN_CLOSES_AT=…       # ISO 8601, optionnel
  ```

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
