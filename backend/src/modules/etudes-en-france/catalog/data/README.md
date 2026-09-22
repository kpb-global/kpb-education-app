# Catalogue « Études en France » — données versionnées

84 établissements publics, 10 502 formations. Un fichier JSON par
établissement dans `universites/`, plus `manifest.json` qui déclare d'où vient
chaque ligne.

Les 70 universités du filtre « typologie renseignée » sont toujours là. Quatorze
établissements diplômants sans cette typologie les rejoignent (UTC, UTT,
Sciences Po Paris, Aix, Bordeaux, Lyon et Toulouse, INALCO, CNAM, EHESS, ENS de
Lyon, Muséum, ENSSIB, Arts et Métiers). L'UTTOP est dans la liste cherchée et
n'a aucune formation joignable dans les jeux utilisés : elle n'a pas de fichier.

> **Ces lignes ne sont pas publiables en l'état.** L'import les crée
> `isActive = false` — **établissements compris** — et les surfaces publiques
> (`/catalog/*`, recommandations, `Institution.programIds`) filtrent sur ce
> drapeau. Elles attendent la file de vérification `/verification`,
> et la Phase 1 reste bloquée tant que cette file n'a pas un propriétaire
> nommé — une personne réelle, pas un rôle (plan § 12.1).

## D'où viennent les données

| Couche | Jeu de données | Millésime | Licence |
| --- | --- | --- | --- |
| Les établissements | `fr-esr-principaux-etablissements-enseignement-superieur` | 2025 | Licence Ouverte v2.0 |
| Profil des admis Parcoursup (mentions, pas une moyenne minimale) | `fr-esr-parcoursup` | 2025 | Licence Ouverte v2.0 |
| Logos | Wikidata P154 + fichier Commons | — | licence du fichier, une par établissement (domaine public, CC0, CC BY, CC BY-SA seulement) |
| Premier cycle (L1, BUT, PASS, DEUST, LP) | `fr-esr-cartographie_formations_parcoursup` | 2026 | Licence Ouverte v2.0 |
| 2e et 3e années de licence | `fr-esr-principaux-diplomes-et-formations-prepares-etablissements-publics` | 2024 | Licence Ouverte v2.0 |
| Mentions de master | `fr-esr-tmm-…-mentions-de-master` | **2021** | Licence Ouverte v2.0 |
| Parcours de master | `fr-esr-tmm-…-parcours-de-format` | **2021** | Licence Ouverte v2.0 |
| Table des fusions d'universités | (même jeu, agrégé autrement) | 2024 | Licence Ouverte v2.0 |

Tout vient de `data.enseignementsup-recherche.gouv.fr`. La collecte est
rejouable : `manifest.json` conserve la requête exacte et le nombre de lignes
rapportées par chaque jeu.

**L'Onisep est volontairement écarté.** Ses jeux « Idéo » couvriraient mieux
l'offre, mais ils sont en **ODbL** — partage à l'identique. Les mélanger
imposerait de republier le catalogue KPB dérivé sous la même licence. La
Licence Ouverte v2.0, elle, autorise la réutilisation commerciale avec simple
mention de la source.

## Les 2e et 3e années ne sont pas déduites des 1res

Parcoursup ne décrit que l'entrée en **première** année. Or un candidat qui
passe par la procédure Études en France vise très souvent une L2 ou une L3 —
c'est même le cas le plus courant pour qui a déjà commencé des études chez lui.

« Une licence dure trois ans, donc toute L1 implique une L2 et une L3 » est vrai
en général et faux en particulier : PASS n'a pas de L2 du même nom, les portails
pluridisciplinaires se scindent, des mentions ferment une année sans fermer
l'autre, et certaines L3 n'existent que sur un campus secondaire. Déduire
produirait des fiches plausibles et invérifiables.

Les 3 131 lignes de L2 et L3 viennent donc du jeu des **diplômes réellement
préparés** : le ministère y publie, par établissement et par année d'étude, les
diplômes où des étudiants étaient inscrits à la rentrée 2024. Une L3 y figure
parce que quelqu'un l'a suivie — c'est une preuve d'existence, et elle porte
l'implantation exacte, donc le bon campus.

Deux conséquences visibles dans les données :

- **Chaque fiche pointe sur SA ligne** du jeu, filtrée sur le diplôme,
  l'établissement et la rentrée. Un `sourceUrl` partagé par 3 000 fiches
  renverrait le vérificateur sur 530 000 lignes, c'est-à-dire nulle part.
- **Les intitulés sont réaccentués**, parce que ce jeu les publie sans accents
  (« Langues, litteratures et civilisations etrangeres… »). On ne devine pas :
  on reconnaît l'intitulé sur celui que Parcoursup ou Trouver Mon Master écrit
  correctement (78 sur 96), sinon sur une table fermée de 25 corrections.
  Ce qui ne tombe dans ni l'un ni l'autre garde son intitulé brut — une fiche
  sans accent se repère et se corrige, une fiche accentuée au hasard ne se
  repère pas.

PSL est la seule université sans L2/L3 : son offre de licence est portée par
Dauphine et le CPES, qui ont leur propre identifiant au référentiel et ne
remontent pas sous l'université. Un test verrouille « au plus une exception ».

## Les deux limites à connaître avant de publier

**1. Les masters datent de 2021.** Le portail Trouver Mon Master a cessé
d'exporter en données ouvertes après la campagne 2021, et l'API de
`monmaster.gouv.fr` exige un compte candidat. On en tire donc la **structure**
de l'offre — quelle mention, dans quelle université, avec quelles licences
conseillées et quelle modalité de candidature — et **aucun chiffre daté** :
ni capacité d'accueil, ni dates de recrutement, qui ne sont pas importées. Le
validateur émet un avertissement à chaque exécution pour que ce ne soit jamais
un oubli. Une mention peut avoir fermé depuis : c'est ce que la vérification
humaine doit trancher, université par université.

**2. Aucun prix n'est servi.** Depuis 2019 une université peut appliquer des
droits différenciés aux étudiants extra-européens **ou** en exonérer ; les deux
pratiques coexistent et aucun jeu ouvert ne dit laquelle s'applique où.
Annoncer un montant serait donc faux pour une moitié du catalogue. Les lignes
portent la règle et renvoient à la fiche officielle ; `tuitionMinEur` est
`null`, et le scoring budget traite un montant absent comme neutre.

## Ce que chaque ligne garantit

- une **fiche officielle HTTPS** par formation (Parcoursup, ou le site de
  l'établissement pour un master) — refusée sinon ;
- un **UAI** sur l'établissement, qui est la clé de re-vérification ;
- une **procédure** explicite : `dap_blanche` pour une 1re année de licence et
  pour PASS, `dap_jaune` pour l'architecture, `eef` pour BUT / DEUST / licence
  professionnelle / master, `hors_eef` pour les cycles d'ingénieur ;
- un **domaine** du référentiel `d01..d12`, avec `fieldIsFallback` qui avoue
  quand il vient du repli par grand domaine plutôt que d'un mot-clé de
  l'intitulé. Taux de repli actuel : **2,3 %**, plafonné à 8 % par le
  validateur.

Sur les masters, deux listes **publiées par l'établissement** en plus :

- `recommendedBachelors` — les licences conseillées à l'entrée. 2 955 masters
  sur 3 112 en déclarent, et **302 publient « Toutes licences »**, ce qui est
  une information d'admission et non une mention manquante. C'est la seule
  exigence d'admission NOMINATIVE que les données ouvertes fournissent.
- `admissionModes` — `Dossier` (2 899), `Entretien` (1 628), `Examen` (203),
  `Concours` (83). 2 914 masters en déclarent.

Ces deux listes portent le classement de la shortlist, parce que `selectivity`
est constante à l'intérieur d'un cycle — tous les masters, toutes les L2,
toutes les L3, tous les BUT et tous les DEUST sont `selective` — et ne classe
donc rien. Le validateur refuse qu'une valeur y reste jointe par des barres
verticales : le portail publie `for_lic_conseille` tantôt en tableau, tantôt
en une seule chaîne, et 501 entrées portaient une « mention » du genre
« Droit|Economie|Gestion|Toutes licences » — un libellé que personne ne publie
et qu'aucun appariement ne pouvait reconnaître.

Ce que les lignes ne contiennent **pas**, et n'inventent donc pas : le niveau
de français exigé formation par formation, les frais de dossier, les dates de
campagne (servies par `/config/app`), une moyenne minimale Campus France, et
toute prose dans les fichiers de données — les phrases sont dérivées une seule
fois par `eef-catalog.copy.ts`.

## Description, repère de moyenne, logo

La description d'une formation et le repère de moyenne sont produits à
l'import par `programSummary` et `admissionGuidance`. Ils atterrissent dans
`requirementsFr` / `requirementsEn`. Le fichier JSON, lui, ne garde que les
faits.

Pour 3 525 formations Parcoursup, le fait est le profil des néo-bacheliers qui
ont accepté une place en **2025** (`admissionCohort` : effectifs par mention,
taux d'accès). La phrase dit « aucune moyenne minimale officielle », puis, si
au moins 15 admis, la borne basse de la mention la plus fréquente (12, 14, 16
ou 18/20). Ce chiffre est le plancher de cette mention au bac français, pas un
seuil Études en France. En dessous de 15 admis, ou pour un master et une L2/L3
(aucune statistique publiée), la phrase s'arrête à « pas de seuil vérifiable ».
`minGpaRequired` reste vide : le scoring ne doit pas traiter ce repère comme
une note plancher.

Le logo n'est posé que si Wikidata (P154, joint par l'UAI P3202) pointe un
fichier Commons en domaine public, CC0, CC BY ou CC BY-SA. 40 établissements
en ont un. Les 44 autres, dont Lille, Grenoble ou Nantes, n'ont pas d'UAI sur
l'élément Wikidata ou pas de fichier sous une de ces licences : pas d'image
plutôt qu'un logo sous copyright. `trademarked` est conservé quand Commons le
signale : on identifie l'établissement, on ne se présente pas comme lui.

## Commandes

```bash
npm run eef:fetch               # recollecte depuis les données ouvertes
npm run eef:enrich              # ajoute établissements, profils d'admission, logos
npm run eef:validate:structure  # porte rapide de CI
npm run verify:eef              # portes strictes (volume, repli, sources)
npm run eef:import:dry-run      # ce qui SERAIT créé, en lisant la base
npm run eef:import              # --apply, créations seules, lignes inactives
npm run eef:backfill:cycle      # comble les `cycle` NULL des lignes d'avant la colonne
npm run eef:backfill:admission  # comble les signaux d'admission, idem
npm run eef:backfill -- --dry-run  # logos + repère d'admission sur l'existant
npm run eef:backfill -- --apply
```

Les deux rattrapages ne comblent que les trous et sont **rejouables** : un
import neuf écrit déjà ces colonnes, donc ils rendent `filled: 0`.

`eef:fetch` réécrit `universites/` de zéro : une université disparue du
référentiel disparaît du dépôt. `eef:import` ne met **jamais** à jour une ligne
existante — une correction faite dans l'admin ne doit pas être écrasée par une
collecte. `eef:backfill` comble ensuite logo (colonnes encore nulles) et
exigences (lignes encore inactives et non vérifiées) sans publier.

## Ce qui reste à faire sur ces données

1. **Les 2e et 3e années de BUT**, non couvertes : seule l'entrée en BUT 1
   figure au catalogue.
2. **Le doctorat.** `fr-esr-les-ecoles-doctorales-historique-annuel` couvre les
   écoles doctorales ; aucune ligne n'est encore produite.
3. **Les masters à jour.** À re-sourcer établissement par établissement, ou à
   reprendre si le ministère reprend ses exports.
4. **Les droits d'inscription réels**, université par université, qui est un
   travail de vérification et non de collecte.
