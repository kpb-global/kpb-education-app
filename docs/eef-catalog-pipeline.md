# Catalogue « Études en France » — le pipeline de données

Phase 1 du plan `docs/etudes-en-france-space-implementation-plan.md`, § 5.
Ce document dit **ce qui est livré**, **ce qui est délibérément absent**, et
**ce qu'il reste à faire** avant que la première ligne soit visible par un
étudiant.

Rédigé le 20/09/2026.

---

## 1. Ce qui est livré

**84 établissements publics, 10 502 formations**, collectées depuis
les données ouvertes de l'État, versionnées dans le dépôt, validées par une
machine, et importables en base — **inactives**.

Le noyau reste les 70 universités à typologie MESR. Le 21 septembre 2026, quatorze établissements diplômants sans cette typologie ont été ajoutés (universités de technologie, Sciences Po, INALCO, CNAM, EHESS, ENS de Lyon, Muséum, ENSSIB, Arts et Métiers). L'UTTOP n'a pas de formation joignable et n'a pas de fichier. Les profils d'admission Parcoursup 2025 et les logos Commons réutilisables sont décrits dans `backend/src/modules/etudes-en-france/catalog/data/README.md`.

| | |
|---|---|
| Établissements | 84 (70 universités à typologie, plus 14 établissements diplômants ajoutés le 21/09/2026) |
| Formations | 10 502 |
| dont entrée en 1re année | 4 124 (L1, BUT, PASS, DEUST, IEP, cycles ingénieur) |
| dont 2e et 3e années de licence | 3 134 |
| dont mentions de master | 3 244 |
| Par procédure | `eef` 7 260 · `dap_blanche` 3 133 · `dap_jaune` 29 · `hors_eef` 80 |
| Classement de domaine par repli | 2,28 % (plafond CI : 8 %) |
| Profils d'admission Parcoursup 2025 | 3 525 formations |
| Logos Commons réutilisables | 40 établissements |
| Sources | jeux MESR en **Licence Ouverte v2.0**, logos sous la licence de chaque fichier |

Le détail des jeux, leurs millésimes et leurs limites sont dans
`backend/src/modules/etudes-en-france/catalog/data/README.md`.

### Le chemin, de bout en bout

```
données ouvertes MESR
  → scripts/fetch-eef-catalog.ts       (réseau ; ne décide de rien)
  → eef-catalog.builder.ts             (pur ; décide de tout, et dit ce qu'il refuse)
  → data/universites/*.json            (70 fichiers versionnés, relisibles en diff)
  → eef-catalog.validator.ts           (portes strictes ; CI + avant import)
  → scripts/import-eef-catalog.ts      (--dry-run | --apply, jamais de défaut)
  → Institution / Program, isActive = false
  → outil de publication en admin      ← le seul endroit où une ligne devient visible
                                         (À CONSTRUIRE ; en attendant, l'API :
                                         PATCH /admin/catalog/…/:id { isActive })
  → file /verification en admin        ← ne liste que les lignes DÉJÀ publiées, à leur cadence (§ 2ter)
```

La file `/verification` n'a jamais été le chemin de publication : valider une
ligne y pose le tampon de vérification (`lastVerifiedAt`, `verifiedByName`),
jamais `isActive`. Une ligne importée qu'on y « validait » sortait donc de la
file sans devenir visible.

C'est, trait pour trait, le pipeline des bourses
(`backend/src/modules/scholarships-index/data/`). Le dépôt l'a déjà éprouvé, et
il a déjà encaissé les deux accidents qui justifient chacune de ses étapes.

---

## 2. Les six décisions qui méritent d'être discutées

### 2.1 Données ouvertes, pas recherche IA

Le plan (§ 5.2) exige **une source HTTPS officielle par affirmation publiée**.
À 10 247 formations, une recherche IA produirait autant d'affirmations qu'aucun
humain ne vérifiera avant la campagne — c'est exactement ainsi que
« Bourse McCall MacBain », qui n'existe nulle part, a atteint un appareil de
production (`lib/app/core/data/catalog_source.dart:1-9`).

Les jeux du ministère, eux, **sont** la source. Chaque formation porte le lien
de sa fiche officielle (Parcoursup, ou le site de l'université), et la collecte
est rejouable à l'identique : le manifeste garde la requête exacte.

### 2.2 Licence Ouverte seulement — l'Onisep est écarté

Les jeux « Idéo » de l'Onisep couvriraient mieux l'offre (28 580 actions de
formation dans le supérieur, mises à jour en juillet 2026). Ils sont en
**ODbL**, licence à partage à l'identique : les intégrer obligerait à
republier le catalogue KPB dérivé sous la même licence.

La Licence Ouverte v2.0 des jeux du MESR autorise la réutilisation
commerciale avec simple mention de la source. Le choix est juridique, pas
technique, et il doit rester explicite : **aucune ligne ODbL ne doit entrer
dans ce catalogue** sans une décision prise en connaissance de cause.

### 2.3 Les masters datent de 2021 — et ce n'est pas caché

Le portail Trouver Mon Master a cessé d'exporter en données ouvertes après la
campagne 2021, et l'API de `monmaster.gouv.fr` exige un compte candidat
(vérifié : `GET /api/candidat/formations` répond 401). Il n'existe donc **aucune
source ouverte à jour** de l'offre de master.

Ce qui en est tiré : la **structure** — quelle mention, dans quelle université,
avec quelles licences conseillées et quelle modalité de candidature.
Ce qui n'en est **pas** tiré : capacité d'accueil, dates de recrutement, aucun
chiffre daté. Le validateur avertit à chaque exécution, le README le dit, et
les lignes arrivent inactives : la vérification humaine tranche, université par
université.

Les données de 2021 ne désignent plus les mêmes établissements — Rennes-I et
Rennes-II ont fusionné, Bourgogne est devenue Bourgogne Europe. Une table de
correspondance, tirée du jeu des diplômes préparés, recale 430 mentions qui
seraient sinon orphelines.

### 2.4 Aucun prix n'est servi

Depuis 2019, une université peut appliquer des droits différenciés aux
étudiants extra-européens **ou** en exonérer. Les deux pratiques coexistent et
aucun jeu ouvert ne dit laquelle s'applique où. Annoncer un montant serait donc
faux pour une moitié du catalogue.

Les lignes portent la règle et renvoient à la fiche officielle ;
`tuitionMinEur` reste `null`, ce que le scoring de budget traite déjà comme un
facteur neutre (`Program.tuitionMinEur` est nullable exprès).

**Conséquence à assumer** : le filtre « budget » ne discrimine pas encore les
universités publiques. C'est un travail de vérification, pas de collecte, et il
est listé en § 4.

### 2.5 Les L2/L3 sont attestées, pas déduites

Parcoursup ne décrit que l'entrée en **première** année, alors qu'un candidat
passant par Études en France vise le plus souvent une L2 ou une L3 — c'est le
profil de quelqu'un qui a déjà commencé des études chez lui.

La tentation était de les déduire : une licence dure trois ans, donc toute L1
implique une L2 et une L3. C'est vrai en général et faux en particulier — PASS
n'a pas de L2 du même nom, les portails pluridisciplinaires se scindent, des
mentions ferment une année sans fermer l'autre, et certaines L3 n'existent que
sur un campus secondaire.

Elles viennent donc du jeu des **diplômes réellement préparés** (rentrée 2024) :
une L3 y figure parce que des étudiants y étaient inscrits. Preuve d'existence,
pas déduction — et l'implantation exacte vient avec, donc le bon campus. Chaque
fiche pointe sur sa propre ligne du jeu, filtrée sur le diplôme, l'établissement
et la rentrée.

Ce jeu publie ses intitulés **sans accents**. On ne les replace pas par règle —
c'est impossible en français (« cote », « côte », « coté », « côté ») : on
reconnaît l'intitulé sur celui que Parcoursup ou Trouver Mon Master écrit
correctement (78 sur 96), sinon sur une table fermée de 25 corrections, sinon
on garde le brut. Une fiche sans accent se repère ; une fiche accentuée au
hasard, non.

### 2.6 La procédure est déduite d'une règle, pas devinée ligne à ligne

La demande d'admission préalable ne concerne que la **1re année de licence**
(dossier blanc) et la **1re année en école d'architecture** (dossier jaune).
Tout le reste de l'offre universitaire — BUT, DEUST, licence professionnelle,
master — relève de la procédure Études en France.

Les L2, L3 et masters relèvent donc tous de la procédure Études en France :
7 125 formations sur 10 247. Cette règle est appliquée par une table fermée
(`PARCOURSUP_FAMILIES`), un test la verrouille, et la page qui en fait foi est
citée dans le code (`EEF_PROCEDURE_SOURCE_URL`). Une famille de formation
inconnue de la table n'est **pas** devinée : la ligne est écartée et comptée.

C'est le point le plus sensible du lot : se tromper de procédure envoie un
étudiant sur le mauvais calendrier. Il mérite une relecture métier avant la
publication.

---

## 2bis. La mise en attente est APPLIQUÉE, pas seulement écrite

Ajouté le 20/09/2026, après une revue de la PR #279. Le premier jet écrivait
`isActive: false` sur les formations importées et la documentation promettait
que rien ne s'afficherait avant relecture. **La promesse était fausse** : le
drapeau était écrit, et aucune lecture ne le lisait. `CatalogService` et
`MatchesService` construisaient leur filtre à partir des seuls paramètres de
requête — les 10 247 formations devenaient publiques à la seconde où l'import
se terminait, et occupaient au passage les 1 000 lignes de l'instantané
mobile.

Ce qui tient la promesse maintenant :

| Surface | Règle |
|---|---|
| `GET /catalog/programs` | `isActive: true`, jamais optionnel — et **aucune ligne EEF, publiée ou non** (§ 2ter) |
| `GET /catalog/institutions` | `isActive: true`, jamais optionnel — et **aucune ligne EEF, publiée ou non** (§ 2ter) |
| `MatchesService` (recommandations) | `isActive: true` — et **aucune ligne EEF** (§ 2ter) |
| `GET /etudes-en-france/search` et `/shortlist` | `isActive: true` **et établissement publié** (§ 2ter) |
| `Institution.programIds` servi | privé des identifiants connus comme inactifs |
| `PATCH /admin/catalog/programs/:id` et `/institutions/:id` | acceptent `isActive` — c'est le chemin de publication |

Deux points méritent d'être dits explicitement :

- **L'établissement est mis en attente lui aussi** (`Institution.isActive`,
  migration `20260920210000`). Sa fiche est une affirmation — texte de
  présentation, effectif daté — et son `programIds` renvoie vers des lignes non
  relues. Publier l'université, c'était publier ses 414 formations par
  référence, même avec la liste des formations filtrée.
- **`programIds` est nettoyé au service, pas en base.** Le tableau est
  dénormalisé et `syncInstitutionProgramIds` le remplit sans regarder
  `isActive` ; on retire donc à la lecture les identifiants CONNUS comme
  inactifs, et rien d'autre — une référence orpheline reste servie comme avant,
  parce que la nettoyer serait un changement de comportement sans rapport avec
  la relecture.

Mesuré sur une base neuve après `eef:import --apply` : 70 établissements et
10 247 formations en base, **0 servi**, 0 identifiant de formation servi. Après
publication d'une université et d'une de ses formations : 1 établissement,
1 formation, et `programIds` en sert **1** au lieu de 414.

---

## 2ter. La frontière : ce que le catalogue général ne sert JAMAIS

Ajouté le 29/09/2026, la veille de l'ouverture de la campagne. § 2bis garantissait
que l'inactif ne se sert pas. Restait ce qui se passe **après publication** :
`isActive` ne dit pas d'où vient une ligne, et le catalogue général n'a que ce
drapeau.

### Le défaut

Chaque build installée charge le catalogue d'un seul appel —
`GET /catalog/programs?limit=1000`, trié par nom — et le serveur ne voit aucun
en-tête de version pour distinguer les clients. Le débordement commence à
**367 lignes EEF actives** (1 000 moins les 634 formations partenaires servies
aujourd'hui), alors qu'une seule université en compte jusqu'à 414. Mesuré : avec
les 10 502 lignes actives, il ne reste que **121 des 634** formations
partenaires (OMNES, ICN, Mundiapolis) dans l'instantané. Personne n'aurait vu
d'erreur : des fiches disparaissent, c'est tout — dans l'app de tout le monde,
sans mise à jour possible côté client.

### La règle

Le catalogue général, les recommandations (`MatchesService`, y compris son repli
`loadPrograms({})` quand le profil est inexploitable) et — pour la file de
revérification — les lignes en attente **excluent la provenance EEF**. Elle se
reconnaît à l'identifiant que l'import écrit : `eef-univ-…` pour les
établissements, `eef-prog-…` pour les formations. Une formation dont
l'ÉTABLISSEMENT porte `eef-univ-…` en est aussi, même saisie à la main
(identifiant généré, active par défaut) : sans cela elle serait servie par le
catalogue général sur une carte sans école, l'école étant, elle, exclue. Les deux
préfixes et les clauses qui les excluent vivent dans **un seul fichier**,
`backend/src/common/eef-provenance.ts`, importé aussi par le constructeur de
l'import.

Pourquoi le préfixe et non la procédure : le code connaissait déjà trois façons
de dire « ceci est une ligne EEF » (`procedureType IS NOT NULL`, `cycle IN (…)`,
l'identifiant). Le préfixe est la seule qui ne dépende d'aucune décision future :
le schéma prévoit `hors_eef`, qualifier un jour les 133 formations partenaires
(aujourd'hui `NULL`) est plausible, et un établissement privé partenaire a lui
aussi un code UAI. Le seed OMNES délimite déjà ses lignes de la même façon
(`omnes-`, `omnes-p-`).

| Surface | Provenance EEF | Établissement non publié |
|---|---|---|
| `/catalog/institutions`, `/catalog/programs` | jamais servie | — |
| `/matches/aha-moment`, `/matches/school/:id` | jamais chargée | — |
| `/etudes-en-france/search`, `/shortlist` | servie | formation **non servie** |
| file `/verification`, SLA de 07 h, compteur du tableau de bord | comptée **si publiée**, pas si en attente | — |

### L'établissement publié

`Program` n'a aucune relation vers `Institution`. Sans garde, une formation
activée sous une université que personne n'a relue était recherchée et
recommandée, avec pour établissement une fiche non vérifiée. La recherche et la
shortlist lisent donc une fois les établissements publiés du pays, puis
appliquent `institutionId IN (…)` à la page, au total, aux facettes et à chaque
étage. Une liste vide se lit « rien », jamais « tout » — et la liste n'est jamais
omise de la clause. Cette propriété est prouvée DIRECTEMENT sur une base réelle,
lignes en place : sur une base neuve « rien » et « pas de filtre » donnent tous
deux zéro, et sur une base semée la liste n'est jamais vide.

**La liste contient les établissements ACTIFS du pays, partenaires compris**
(ESSEC, OMNES…), pas seulement ceux de l'import. Ce n'est pas elle qui garde
leurs formations hors de l'espace : c'est la **provenance**, posée dans la
recherche comme dans la shortlist (`eefProgramWhere`, la clause dont
`notEefProgram` est le contraire). Il n'y a donc qu'**une définition de
« EEF »**, dans les deux sens : le catalogue général exclut les lignes de
l'import, cet espace ne sert QUE ces lignes. Avant, l'exclusion se faisait par
préfixe et l'inclusion par `procedureType` / `cycle` : le jour où l'exploitation
aurait qualifié une formation partenaire, elle serait entrée dans l'espace ET
restée dans le catalogue général. Prouvé sur une base réelle : une formation
partenaire active, dotée d'une procédure, d'un cycle et d'une modalité, sous un
établissement partenaire présent dans la liste des publiés, n'est ni cherchée ni
recommandée — et reste servie par `/catalog/programs`. `procedureType IS NOT
NULL` subsiste comme garde-fou de données (une ligne de l'import sans procédure
n'est pas servie), plus comme définition.

### La file de revérification

La règle « à revérifier » existait en **deux copies** (la file admin et le
compteur du tableau de bord) qui devaient rester identiques sans que rien ne le
garantisse. Elle vit désormais dans `verification-due.ts` et exclut les lignes
EEF **en attente** : l'import en dépose 10 500 « jamais vérifiées », dont la
revue est le flux de PUBLICATION. Sans cela la page admin aurait rendu un champ
et deux boutons par ligne (elle sert aussi à revérifier les bourses) et
l'alerte de 07 h aurait annoncé chaque matin « 10 5xx never verified ». Une
ligne publiée y entre normalement, à sa cadence. La réponse est plafonnée à 500
éléments, avec `total` et `truncated` — et le plafond **n'affame aucune
catégorie** : deux universités publiées d'un coup (`updateProgram` ne pose pas
`lastVerifiedAt`) ajoutent plus de 800 formations « jamais vérifiées », qui
passaient devant les bourses en retard et les chassaient de la page. L'ordre est
total (jamais-vérifiés d'abord, puis échéance la plus ancienne, puis identifiant),
et les quatre catégories partagent une seule définition.

### Ce que ça ne fait pas, et ce qui reste ouvert

- **Publier une université ne la fait pas apparaître dans Explore des builds
  actuelles.** C'est voulu : son espace est `/etudes-en-france/*`. Qu'elle
  apparaisse un jour dans Explore, le comparateur ou le « moment aha » est une
  décision produit, qui se prendra dans `eef-provenance.ts`, en un endroit.
- La page `/verification` n'a pas de pagination : elle avertit quand la file est
  tronquée. Valider des lignes puis recharger fait apparaître les suivantes.
- **L'admin ne liste plus les lignes de l'import.** Ses pages catalogue lisent les
  routes publiques `/catalog/*`, qui les excluent : une ligne EEF PUBLIÉE ne s'y
  affiche plus, et une ligne en attente ne s'y est jamais affichée. Il n'existe
  donc aucun écran pour retrouver, corriger ou DÉPUBLIER une ligne de l'import ;
  seuls la file `/verification` (plafonnée) ou un `PATCH` par identifiant y
  mènent. L'outil de publication à construire doit lister ces lignes, publier
  ET dépublier.
- **Les cartes de l'espace n'ont pas le nom de l'établissement.** La recherche et
  la shortlist servent des formations dont l'`institutionId` renvoie à un
  établissement que `/catalog/institutions` ne sert plus. L'écran de l'espace
  doit donc recevoir l'établissement (nom, ville, logo) avec la formation, ou par
  une route dédiée : c'est une dépendance de l'écran, pas un défaut de la
  frontière.
- Une **nouvelle surface** qui lirait `Program` ou `Institution` sans portée
  ferait échouer `eef-provenance.doors.spec.ts` (voir § 3), qui lit le code par
  son arbre syntaxique.

---

## 3. Ce que la CI vérifie

| Porte | Quand | Ce qu'elle juge |
|---|---|---|
| `eef:validate:structure` | chaque PR (`backend-ci.yml`) | forme : sources HTTPS, identifiants uniques, référentiels fermés, cohérence du manifeste |
| `eef-catalog.data.spec.ts` | suite de tests | les 70 fichiers réels passent les portes **strictes** |
| `catalog-active-gate.spec.ts` | suite de tests | les surfaces publiques ne servent que du relu, `programIds` compris, et aucune ligne EEF |
| `eef-provenance.spec.ts` | suite de tests | l'import n'écrit que des identifiants que les clauses reconnaissent, sur les vrais fichiers de données |
| `eef-provenance.doors.spec.ts` | suite de tests | **aucune méthode ne lit `program` ni `institution` sans APPELER sa fonction de portée** : lecture du code par son arbre syntaxique (pas par des expressions régulières — un `/*` cité dans un commentaire de ligne avalait le code et rendait le catalogue général et la recherche invisibles), registre explicite fichier → méthode → fonction, nombre d'accès épinglé, alias / déstructuration / SQL brut refusés. Le scanner se teste lui-même. |
| `verification-due.spec.ts`, `verification-due.consumers.spec.ts` | suite de tests | les quatre prédicats « à revérifier » (coupure, cadence, actif / approuvé), l'ordre de la file, le plafond équitable — et que la file et le compteur envoient à la base les MÊMES clauses, sur une horloge figée |
| `eef-provenance.postgres.spec.ts` | `Backend CI`, étape « PostgreSQL Études en France provenance integration » | sur un vrai Postgres : catalogue, recommandations, recherche, shortlist, file, SLA et compteur — `NOT`, `AND`, `IN ()` sont acceptés par Prisma **et filtrent** |
| `verify:eef` | avant tout import | planchers de volume, plafond de repli, couverture |

Le plafond de repli mérite un mot : le domaine d'une formation (`d01..d12`) est
déduit de mots-clés de son intitulé. Tant que le taux de repli reste bas, la
déduction est marginale ; s'il monte, c'est que la source a changé de
vocabulaire et que le classement ne veut plus rien dire. Le plafond est à 8 %,
la valeur actuelle est 3,28 % — la marge est volontairement étroite pour que la
dérive fasse du bruit tôt.

---

## 4. Ce qui reste à faire

### Bloquant avant toute publication

1. **Le propriétaire nommé de la file de vérification.** Inchangé depuis le
   plan (§ 12.1) : une personne réelle. Sans elle, ces 10 247 lignes restent
   inactives pour toujours, ce qui est le comportement correct mais pas le
   comportement utile.
2. **La relecture métier du partage DAP / Études en France** (§ 2.5).

### Dans le catalogue

3. **Les 2e et 3e années de BUT**, non couvertes : seule l'entrée en BUT 1
   figure au catalogue.
4. **Le doctorat.** `fr-esr-les-ecoles-doctorales-historique-annuel` existe ;
   aucune ligne n'est produite.
5. **Les masters à jour**, à re-sourcer ou à reprendre si le ministère reprend
   ses exports.
6. **Les droits d'inscription réels**, université par université (§ 2.4).

### Dans le produit

7. ~~La recherche paginée côté serveur.~~ **Livrée** :
   `GET /etudes-en-france/search`, curseur + six facettes, publique.
   Contrat complet dans `docs/api-contracts.md`. Mesurée sur les 10 247
   lignes : traversée intégrale en 205 pages, aucun doublon, aucun saut, coût
   constant (page 1 et page 205 au même prix). Reste à **brancher le client** :
   `AppController` tient toujours la totalité du catalogue en mémoire, et
   10 247 formations ne s'y tiennent pas.
8. **L'écran `eef_catalog_screen.dart`** et les facettes de procédure.
9. **Exposer les colonnes de procédure** (`procedureType`, `selectivity`,
   `campusCity`, `formationCode`, `institutionType`, `uaiCode`) dans
   `catalog.mapper.ts` et le modèle Flutter. La migration les crée et l'import
   les écrit ; rien ne les lit encore. `isActive`, lui, est bien lu (§ 2bis).
10. **La file de vérification en admin** ne propose pas encore de bouton
   « publier » : le champ est accepté par l'API, l'interface reste à câbler.
   Depuis le 29/09/2026 elle ne liste plus les lignes en attente (§ 2ter) : le
   flux de publication en masse reste donc **un outil à construire**, pas une
   page à filtrer.

---

## 5. Exploitation

```bash
# En local, après un changement de code de collecte
npm run eef:fetch
npm run verify:eef

# En production, dans le conteneur api
docker compose exec -T api npm run eef:import:dry-run
docker compose exec -T api npm run eef:import
docker compose exec -T api npm run eef:backfill -- --dry-run
docker compose exec -T api npm run eef:backfill -- --apply
```

`eef:import` est **création seule** : une ligne dont l'identifiant existe déjà
n'est jamais mise à jour, parce qu'un administrateur a pu la corriger à la
main. Le compteur s'appelle `existingNotUpdated` et non `skipped` — le dépôt a
appris que « sauté : 34 » se lit « rien à faire » alors qu'il veut dire
« 34 lignes potentiellement périmées » (`docs/catalog-verification-sop.md`).

`eef:backfill` est l'acte distinct pour le catalogue 1.2 : il pose le logo
Commons (si les trois colonnes sont encore vides) et réécrit description +
repère d'admission sur les formations encore inactives, jamais vérifiées, et
dont la prose de procédure est encore celle de l'import. Il n'écrit ni
`isActive` ni `lastVerifiedAt`.

Il n'existe **pas encore** de `eef:reconcile` général, équivalent de
`catalog:reconcile` pour les bourses. `eef:backfill` ne couvre que les champs
nouveaux de cette version. Une correction d'intitulé ou de procédure dans le
dépôt n'atteint toujours pas une ligne déjà créée.
