# Catalogue « Études en France » — données versionnées

70 universités publiques françaises, 7 113 formations. Un fichier JSON par
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
| Mentions de master | `fr-esr-tmm-…-mentions-de-master` | **2021** | Licence Ouverte v2.0 |
| Parcours de master | `fr-esr-tmm-…-parcours-de-format` | **2021** | Licence Ouverte v2.0 |
| Table des fusions d'universités | `fr-esr-principaux-diplomes-et-formations-prepares-etablissements-publics` | 2024 | Licence Ouverte v2.0 |

Tout vient de `data.enseignementsup-recherche.gouv.fr`. La collecte est
rejouable : `manifest.json` conserve la requête exacte et le nombre de lignes
rapportées par chaque jeu.

**L'Onisep est volontairement écarté.** Ses jeux « Idéo » couvriraient mieux
l'offre, mais ils sont en **ODbL** — partage à l'identique. Les mélanger
imposerait de republier le catalogue KPB dérivé sous la même licence. La
Licence Ouverte v2.0, elle, autorise la réutilisation commerciale avec simple
mention de la source.

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

1. **Les licences 2e et 3e année.** La cartographie Parcoursup ne décrit que
   l'entrée en 1re année. Un candidat qui vise une L2 ou une L3 par la
   procédure Études en France ne trouve pas sa ligne ici.
2. **Le doctorat.** `fr-esr-les-ecoles-doctorales-historique-annuel` couvre les
   écoles doctorales ; aucune ligne n'est encore produite.
3. **Les masters à jour.** À re-sourcer établissement par établissement, ou à
   reprendre si le ministère reprend ses exports.
4. **Les droits d'inscription réels**, université par université, qui est un
   travail de vérification et non de collecte.
