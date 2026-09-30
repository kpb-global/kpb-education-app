# Dossier juridique — les logos d'universités dans l'espace « Études en France » (LIV-29 / CAT-18)

*Établi le 29/09/2026. Destinataire : le conseil juridique de KPB Education (ou la personne qui
en tient lieu). **Ce document expose des faits et des questions ; il ne conclut pas en droit.**
Les options techniques de la fin disent seulement ce que le code sait faire.*

## Pourquoi c'est une question, alors que les fichiers sont sous licence libre

Une licence libre (domaine public, CC0, CC BY, CC BY-SA) porte sur le **droit d'auteur du
fichier**. Elle ne dit rien du **droit des marques** : le logo d'une université peut être libre
comme image et protégé comme signe. L'app est **commerciale** (accompagnement payant) ; afficher
le logo d'un établissement public sur une fiche de formation peut se lire comme une simple
identification — ou suggérer un partenariat. L'audit du 29/09 rattache le sujet à la règle 5.2.1 des
App Store Review Guidelines et à la politique d'usurpation d'identité de Google Play ; **ces
références sont à vérifier par le juridique**, je ne les ai pas relues à la source.

## Ce que contient le catalogue (mesuré sur `data/universites/`)

- **84 établissements**, dont **40 portent un logo** ; les 44 autres n'en ont pas, volontairement
  (Lille, Grenoble, Nantes… : pas d'UAI sur l'élément Wikidata, ou pas de fichier sous une
  licence réutilisable → « pas d'image plutôt qu'un logo sous copyright », `data/README.md`).
- Un logo n'est retenu que si Wikidata (P154) pointe un fichier Commons en **domaine public, CC0,
  CC BY ou CC BY-SA**. Aucune licence « non commerciale » n'est acceptée (test dédié).
- **Licences des 40 logos :** 31 domaine public, 1 CC0, 8 CC BY / CC BY-SA.
- **Marques :** **23 logos sur 40 sont signalés `trademarked`** par Commons. Tous les 23 sont en
  domaine public *comme fichier* : le signal dit « libre comme image, protégé comme signe ». Ils
  couvrent 3 106 des 5 682 formations des établissements à logo.
- **Format :** 26 des 40 fichiers sont des SVG, que l'app affiche sous forme de miniature PNG
  générée par Commons (largeur 330 px). La miniature est un **dérivé raster** du fichier.
- **Aucun auteur n'est conservé** dans les fichiers de données : seuls `licence` et `sourceUrl`
  (la page du fichier sur Commons, où figure l'auteur) le sont.

Les 23 établissements dont le logo est signalé `trademarked` :
Institut national des langues et civilisations orientales, Sciences Po, Sciences Po Bordeaux, Université Bordeaux Montaigne, Université Bretagne Sud, Université Jean Moulin - Lyon 3, Université Le Havre Normandie, Université Lumière - Lyon 2, Université Paris 8, Université Paris Cité, Université Paris Nanterre, Université Paris-Saclay, Université Sorbonne Nouvelle, Université d'Artois, Université de Bordeaux, Université de Caen Normandie, Université de Corse Pasquale Paoli, Université de Haute-Alsace, Université de Limoges, Université de Lorraine, Université de Versailles Saint-Quentin-en-Yvelines, Université de technologie de Compiègne, Université du Littoral Côte d'Opale.

Les 8 logos sous CC BY / CC BY-SA (crédit exigé par la licence) :

| Établissement | Licence | Page du fichier |
| --- | --- | --- |
| Institut national universitaire Jean-François Champollion | CC BY-SA 4.0 | <https://commons.wikimedia.org/wiki/File:LOGO_CHAMPOLLION.png> |
| Le Mans Université | CC BY-SA 4.0 | <https://commons.wikimedia.org/wiki/File:LogoLEMANSUNIVERSITE.jpg> |
| Université Côte d'Azur | CC BY 2.5 | <https://commons.wikimedia.org/wiki/File:Logo_universit%C3%A9_c%C3%B4te_azur.png> |
| Université Gustave Eiffel | CC BY-SA 4.0 | <https://commons.wikimedia.org/wiki/File:Universit%C3%A9_Gustave_Eiffel_logo.png> |
| Université Sorbonne Paris Nord | CC BY-SA 3.0 | <https://commons.wikimedia.org/wiki/File:Logo-UP13-noirS.png> |
| Université de Pau et des Pays de l'Adour | CC BY 3.0 | <https://commons.wikimedia.org/wiki/File:Logo_Uppa.jpg> |
| Université de Picardie Jules Verne | CC BY-SA 4.0 | <https://commons.wikimedia.org/wiki/File:Logoupjv-bleu.png> |
| Université de Poitiers | CC BY-SA 3.0 | <https://commons.wikimedia.org/wiki/File:Blason_divers_fr_Universit%C3%A9_Poitiers.svg> |

## Ce que fait l'app aujourd'hui

- Le logo n'est rendu que par `lib/app/features/explore/explore_screen.dart` (fiche d'un
  établissement du catalogue général). **Les établissements de l'import en sont exclus côté
  serveur** : aucun de ces 40 logos n'est affiché aujourd'hui, et rien ne les affichera tant
  qu'un écran de l'espace « Études en France » ne les demande pas (`docs/eef-catalog-pipeline.md` § 4).
- Pour les seuls logos sous licence exigeant un crédit (`logoRequiresAttribution`), l'app affiche
  « Logo · <licence> · Wikimedia Commons », cliquable vers la page du fichier. **Pas de nom
  d'auteur, pas de lien vers le texte de la licence.**
- La mention de non-affiliation (`eef_affiliation_notice`) dit : « KPB Education est un organisme
  privé d'accompagnement, sans lien ni affiliation avec Campus France ni avec aucune
  administration française ». **Elle ne parle pas des universités.**
- Le signal `trademarked` est conservé dans les données mais **ne pilote rien** : ni l'affichage,
  ni le crédit.

## Les questions à trancher

1. **Identification.** Afficher le logo d'une université publique à côté de ses formations, dans
   une app commerciale, est-il acceptable comme simple identification de l'établissement ? La
   réponse change-t-elle pour les **23 logos signalés `trademarked`** ?
2. **Non-affiliation.** Faut-il étendre la mention aux établissements (« les logos et noms des
   établissements sont utilisés pour les identifier ; KPB n'est affilié à aucun d'eux »), et où
   l'afficher — sur chaque fiche ou une fois dans l'espace ?
3. **Attribution CC BY / CC BY-SA (8 logos).** « Logo · CC BY-SA 4.0 · Wikimedia Commons » avec un
   lien vers la page du fichier suffit-il, sans nom d'auteur ni lien vers la licence ? La réponse
   diffère-t-elle entre les versions 2.5 et 3.0 (Université Côte d'Azur, Université de Pau,
   Poitiers, Sorbonne Paris Nord) et 4.0 ?
4. **Dérivé.** La miniature PNG d'un SVG sous **CC BY-SA** est-elle une adaptation qui impose le
   partage à l'identique ? (6 logos sont sous CC BY-SA ; le PNG n'est pas republié par KPB, il
   est chargé depuis Commons.)
5. **Réclamation.** Quelle procédure si un établissement demande le retrait de son logo ? Côté
   technique, un retrait ne demande qu'un déploiement du backend (voir plus bas), pas une nouvelle
   build de l'app.

## Options, et ce que chacune coûte

| Option | Logos affichés | Formations concernées | Coût technique |
| --- | ---: | ---: | --- |
| **A. Tout afficher, avec le crédit actuel** | 40 | 5 682 | nul |
| **B. Seulement les non-signalés `trademarked`** (domaine public/CC0 : 9 ; CC BY / BY-SA : 8) | 17 | 2 576 | petit : le serveur omet `logoUrl` pour `trademarked` |
| **C. Seulement domaine public / CC0 ET non signalés** | 9 | 1 444 | petit : idem, sans avoir à gérer de crédit |
| **D. Aucun logo dans la vague 1** (monogramme de repli) | 0 | 0 | nul : ne pas les demander dans l'écran |
| **E. Demander une autorisation écrite à chaque établissement** | selon réponses | — | hors code, délai long |

Les 9 établissements de l'option C : Aix-Marseille Université, Conservatoire national des arts et métiers, La Rochelle Université, Sorbonne Université, Université Paris 1 - Panthéon Sorbonne, Université de Reims Champagne-Ardenne, Université de Strasbourg, Université de Toulon, École normale supérieure de Lyon.

**Ce que le code sait faire dès la décision :** omettre le logo d'un établissement est un
changement d'une ligne dans le mapper serveur (`catalog.mapper.ts`, comme pour la largeur de
miniature) — donc réversible sans nouvelle build de l'app. Étendre le crédit (nom d'auteur, lien
de licence) demande de conserver l'auteur dans les données (collecte Commons `extmetadata`) et une
modification du client.

**Recommandation d'ingénierie, non juridique :** tant que le juridique n'a pas répondu, ne pas
afficher de logo signalé `trademarked` (option B au plus large, C au plus prudent), et ne pas
bloquer la vague 1 sur cette question : l'espace fonctionne sans logo. Elle ne vaut que si le
juridique ne dit rien d'ici la première publication.

## Réponses

| Question | Réponse | Par | Date |
| --- | --- | --- | --- |
| 1. Identification | ☐ oui ☐ non ☐ sous conditions : | | |
| 2. Non-affiliation | ☐ inchangée ☐ étendue à : | | |
| 3. Attribution CC BY* | ☐ suffisante ☐ ajouter : | | |
| 4. Dérivé BY-SA | ☐ sans effet ☐ impose : | | |
| 5. Retrait sur demande | procédure : | | |
| Option retenue | ☐ A ☐ B ☐ C ☐ D ☐ E | | |
