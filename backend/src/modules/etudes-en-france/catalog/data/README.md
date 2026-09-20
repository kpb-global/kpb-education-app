# Catalogue « Études en France » — données versionnées

70 universités publiques françaises, 10 247 formations. Un fichier JSON par
université dans `universites/`, plus `manifest.json` qui déclare d'où vient
chaque ligne.

> **Ces lignes ne sont pas publiables en l'état.** L'import les crée
> `isActive = false`. Elles attendent la file de vérification `/verification`,
> et la Phase 1 reste bloquée tant que cette file n'a pas un propriétaire
> nommé — une personne réelle, pas un rôle (plan § 12.1).

## D'où viennent les données

| Couche | Jeu de données | Millésime | Licence |
| --- | --- | --- | --- |
| Les 70 universités | `fr-esr-principaux-etablissements-enseignement-superieur` | 2025 | Licence Ouverte v2.0 |
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
  l'intitulé. Taux de repli actuel : **3,3 %**, plafonné à 8 % par le
  validateur.

Ce que les lignes ne contiennent **pas**, et n'inventent donc pas : le niveau
de français exigé formation par formation, les frais de dossier, les dates de
campagne (servies par `/config/app`), et toute prose dans les fichiers de
données — les phrases sont dérivées une seule fois par `eef-catalog.copy.ts`.

## Commandes

```bash
npm run eef:fetch               # recollecte depuis les données ouvertes
npm run eef:validate:structure  # porte rapide de CI
npm run verify:eef              # portes strictes (volume, repli, sources)
npm run eef:import:dry-run      # ce qui SERAIT créé, en lisant la base
npm run eef:import              # --apply, créations seules, lignes inactives
```

`eef:fetch` réécrit `universites/` de zéro : une université disparue du
référentiel disparaît du dépôt. `eef:import` ne met **jamais** à jour une ligne
existante — une correction faite dans l'admin ne doit pas être écrasée par une
collecte.

## Ce qui reste à faire sur ces données

1. **Les 2e et 3e années de BUT**, non couvertes : seule l'entrée en BUT 1
   figure au catalogue.
2. **Le doctorat.** `fr-esr-les-ecoles-doctorales-historique-annuel` couvre les
   écoles doctorales ; aucune ligne n'est encore produite.
3. **Les masters à jour.** À re-sourcer établissement par établissement, ou à
   reprendre si le ministère reprend ses exports.
4. **Les droits d'inscription réels**, université par université, qui est un
   travail de vérification et non de collecte.
