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
  → file /verification en admin        ← le seul endroit où une ligne devient visible
```

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
| `GET /catalog/programs` | `isActive: true`, jamais optionnel |
| `GET /catalog/institutions` | `isActive: true`, jamais optionnel |
| `MatchesService` (recommandations) | `isActive: true` |
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

## 3. Ce que la CI vérifie

| Porte | Quand | Ce qu'elle juge |
|---|---|---|
| `eef:validate:structure` | chaque PR (`backend-ci.yml`) | forme : sources HTTPS, identifiants uniques, référentiels fermés, cohérence du manifeste |
| `eef-catalog.data.spec.ts` | suite de tests | les 70 fichiers réels passent les portes **strictes** |
| `catalog-active-gate.spec.ts` | suite de tests | les surfaces publiques ne servent que du relu, `programIds` compris |
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

7. **La recherche paginée côté serveur.** Le plan (§ 5.1) l'annonce comme le
   point d'architecture à ne pas repousser : `AppController` tient aujourd'hui
   la totalité du catalogue en mémoire, et 10 247 formations ne s'y tiennent
   pas. `GET /etudes-en-france/search` avec facettes et curseur reste à écrire.
8. **L'écran `eef_catalog_screen.dart`** et les facettes de procédure.
9. **Exposer les colonnes de procédure** (`procedureType`, `selectivity`,
   `campusCity`, `formationCode`, `institutionType`, `uaiCode`) dans
   `catalog.mapper.ts` et le modèle Flutter. La migration les crée et l'import
   les écrit ; rien ne les lit encore. `isActive`, lui, est bien lu (§ 2bis).
10. **La file de vérification en admin** ne propose pas encore de bouton
   « publier » : le champ est accepté par l'API, l'interface reste à câbler.

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
