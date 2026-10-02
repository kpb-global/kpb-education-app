# Dossier de relecture — le partage DAP / Études en France (CAT-10)

*Établi le 29/09/2026. Destinataire : la personne qui connaît les procédures Campus France
(conseiller·ère ou responsable de l'accompagnement) ; à défaut, le propriétaire du produit.
Le code ne peut pas trancher ce qui suit : il l'applique.*

## Pourquoi ce dossier, et pourquoi avant la première publication

Chaque formation de l'import porte un `procedureType` — `dap_blanche`, `dap_jaune`, `eef`
ou `hors_eef` — qui décide **du calendrier et du parcours** que l'app montrera à
l'étudiant. Se tromper de procédure envoie un candidat sur la mauvaise échéance : c'est
la seule erreur de ce catalogue qui coûte une campagne entière.

La règle est appliquée par une table fermée (`PARCOURSUP_FAMILIES`,
`backend/src/modules/etudes-en-france/catalog/eef-catalog.normalize.ts`) et sa source est
la page Campus France
<https://www.campusfrance.org/fr/dap-demande-admission-prealable-france>. Le code dit
lui-même qu'elle « mérite une relecture métier » (`docs/eef-catalog-pipeline.md` § 2.6).

**Le moment compte.** Tant qu'aucune ligne n'est publiée, corriger une règle coûte une
régénération des fichiers puis `eef:purge-pending` et `eef:import`. Après la première
publication, il faudra un `eef:reconcile` qui n'existe pas encore, et des étudiants
auront déjà enregistré des formations.

## Ce que le code affirme aujourd'hui

| Ce que dit Parcoursup (famille) | Cycle retenu | Procédure | Sélectivité | Lignes |
| --- | --- | --- | --- | ---: |
| Licence / Licence sélective / LPE / CMI / IAE / Sciences Po (IEP) / arts, design / sport | `licence1` | `dap_blanche` | selon la famille | 2 483 |
| Architecture, paysage, patrimoine | `licence1` | `dap_jaune` | sélective | 29 |
| Études de santé (PASS, L.AS) | `sante` | `dap_blanche` | **non sélective** | 650 |
| BUT | `but1` | `eef` | sélective | 834 |
| DEUST | `deust` | `eef` | sélective | 48 |
| Écoles d'ingénieurs (cycle de cinq ans) | `ingenieur` | `hors_eef` | sélective | 80 |
| L2 (1 497), L3 (1 637), masters (3 244) | `licence2`, `licence3`, `master` | `eef` | sélective | 6 378 |

Total 10 502. Comptes mesurés sur les fichiers versionnés (`data/universites/`), pas
recopiés d'un rapport.

## Ce qu'il faut trancher

Pour chaque point : la règle actuelle, pourquoi on doute, ce qui arrive si elle est fausse,
et la case de décision. Les exemples sont en annexe.

### 1. Sciences Po (Paris) en 1re année — 39 formations en `dap_blanche`

La famille Parcoursup « Sciences Po — Instituts d'études politiques » est rangée en
1re année de licence, donc en dossier blanc. Dans nos données, seule l'entité « Sciences
Po » (Paris) porte des L1 ; les instituts de région (Bordeaux, Lyon, Toulouse, Aix) n'ont que
des masters et une L3, en `eef`.
**Question :** un candidat international à Sciences Po Paris en 1re année passe-t-il par la
DAP blanche, ou par la procédure propre de l'établissement ?
**Si c'est faux :** 39 fiches promettent un dossier DAP à des candidats qui doivent déposer
ailleurs.
☐ confirmé  ☐ à corriger : ______________________

### 2. Les autres familles rangées en 1re année de licence

Le jeu Parcoursup regroupe sous « 1re année de licence » des formations de nature
différente : CMI (50 lignes repérables par l'intitulé), LPE — licence professorat des
écoles (44), CUPGE (17), DCG (1) ; les IAE, les formations d'art et de design et les
métiers du sport ne sont pas isolables par l'intitulé (la famille Parcoursup n'est pas
conservée dans les fichiers).
**Question :** toutes suivent-elles la DAP blanche pour un candidat étranger ? Le DCG
(diplôme de comptabilité) est cité par plusieurs pages pays de Campus France comme relevant
de **Parcoursup** au même titre que le BTS et les CPGE (Congo-Brazzaville, Côte d'Ivoire).
**Si c'est faux :** mauvais calendrier pour ces filières.
☐ confirmé  ☐ à corriger : ______________________

### 3. Les 705 « Licences sélectives » en `dap_blanche`

Une L1 marquée sélective par Parcoursup reste en `dap_blanche` (elle est seulement marquée
`selective`). Or la page de Campus France Madagascar, reprise dans la recherche du
21/08/2026, liste **« Parcoursup (Licence 1 sélective, BTS, CPGE) »** comme procédure
distincte (`docs/eef-campaign-calendar-2027-2028-research.md`, ligne « Madagascar »).
Le modèle n'a **pas** de valeur `parcoursup` : les familles BTS et CPGE sont rejetées à
l'import, et la L1 sélective est rangée avec la DAP.
**Question :** pour les pays visés (Niger suspendu à part), une L1 sélective se candidate-t-elle
par la DAP blanche ou par Parcoursup ? Faut-il une quatrième valeur de procédure ?
**Si c'est faux :** c'est la plus grosse zone de doute — jusqu'à 705 fiches, dont celles de
la première liste ci-dessus.
☐ confirmé  ☐ à corriger : ______________________

### 4. Les 834 BUT en 1re année classés `eef`

Règle : « tout le reste de l'offre universitaire — BUT, DEUST, licence professionnelle,
master — relève de la procédure Études en France ». Trois pages pays de la recherche du
21/08/2026 vont dans ce sens : Congo-Brazzaville (« Études en France - Hors DAP (L2, L3, M1,
M2, BUT) »), Maurice (« Procédure Études en France (Hors DAP - BUT, L2, L3, Master) ») et
Rwanda (« Études en France — Licence, Bachelor, Master et BUT »). Elle n'est donc
appuyée que sur ces trois pays.
**Question :** vaut-elle pour tous les pays où KPB accompagne des étudiants ?
☐ confirmé  ☐ à corriger : ______________________

### 5. Les 650 PASS / L.AS en `dap_blanche`, non sélectives

Le code range les études de santé en 1re année de licence (donc dossier blanc) et les marque
**non sélectives** : c'est une règle du code (`PARCOURSUP_FAMILIES`), pas une donnée du jeu.
Un candidat étranger qui lit « non sélective » sur un PASS peut en tirer une idée fausse de ses
chances.
**Question :** la procédure est-elle bien la DAP blanche, et l'app doit-elle afficher la
mention « non sélective » pour les études de santé ?
☐ confirmé  ☐ à corriger : ______________________

### 6. Les 80 cycles d'écoles d'ingénieurs en `hors_eef`

« La sélection appartient à l'école (ou au concours commun) : ce n'est pas la procédure Études
en France » (commentaire du code). Ces fiches n'ont donc ni DAP ni Études en France.
**Question :** que doit dire l'app à un étudiant qui ouvre une de ces fiches — un renvoi vers
le site de l'école, un accompagnement KPB spécifique, ou ne pas les publier dans la première
vague ?
☐ garder  ☐ retirer de la vague 1  ☐ autre : ______________________

### 7. Le « repère d'admission » (3 525 formations)

Pour les formations Parcoursup, le catalogue écrit « aucune moyenne minimale officielle » puis,
si au moins 15 admis en 2025, la borne basse de la mention la plus fréquente parmi les
néo-bacheliers (12, 14, 16 ou 18/20). **Ce chiffre est le plancher de cette mention au bac
français, pas un seuil Études en France** (`data/README.md`). Un étudiant au baccalauréat
étranger n'appartient pas à la population qui a produit ce chiffre.
**Question :** cette phrase aide-t-elle l'étudiant visé, ou l'induit-elle en erreur ? La garder,
la reformuler, ou ne rien afficher ?
☐ garder  ☐ reformuler : ______________________  ☐ retirer

## Ce qui change dans le code selon les réponses

| Décision | Ce qu'on modifie | Coût |
| --- | --- | --- |
| Corriger la procédure d'une famille | `PARCOURSUP_FAMILIES` (une entrée) + régénération des fichiers | petit |
| Ajouter une procédure `parcoursup` (point 3) | type `EefProcedureType`, validateur, filtre de recherche, client Flutter (libellés, calendrier) | moyen |
| Sortir des fiches de la vague 1 (points 1, 6) | ne pas les publier : l'écran de publication accepte une liste de formations | nul |
| Reformuler ou retirer le repère (point 7) | `eef-catalog.copy.ts`, `eef-admission-signals.ts` + régénération | petit |

Toute règle changée **avant** la première publication se répercute ainsi : régénérer les
fichiers → `eef:purge-pending` (simulation d'abord) → `eef:import`, depuis l'action
**VPS ops** du même nom. Le domaine des formations a été réaligné de cette façon le 29/09
(`docs/eef-catalog-pipeline.md` § 2.7).

## Réponses de recherche du 02/10/2026 — à valider

Recherche documentaire sur les sources officielles (Campus France national et pages pays,
sites des établissements, documentation du jeu ouvert Parcoursup), pour un candidat **hors
UE résidant dans un pays à procédure Études en France**, campagne 2027-2028.
**parcoursup.gouv.fr et enseignementsup-recherche.gouv.fr n'ont pas pu être lus** (403) : la
FAQ « Étudiants internationaux » de Parcoursup reste à relire dans un navigateur. Rien de ce
qui suit n'est encore appliqué : le catalogue publié porte toujours les règles du tableau
« Ce que le code affirme aujourd'hui ».

| # | Réponse | Confiance | Source principale | Correction recommandée | Lignes |
|---|---|---|---|---|---:|
| 1 | **Sciences Po Paris** (1re année) a sa **propre voie internationale**, sur son portail : ni DAP, ni Parcoursup. Études en France ne sert qu'après l'admission, pour le visa. (Les IEP de région recrutent par Parcoursup, mais n'ont que des masters et une L3 dans nos données.) | établi | sciencespo.fr/admissions/fr/bachelor/bacheliers-secondaires-etrangers (rentrée 2027) : « la procédure d'admission à Sciences Po n'est pas prévue dans le dispositif Campus France » | `dap_blanche` → **`hors_eef`** | 39 |
| 2a | **DCG** : par **Parcoursup**, avec BTS, CPGE et IFSI | établi | senegal.campusfrance.org/inscription-sur-parcoursup (19/01/2026) ; mêmes listes Mali, Côte d'Ivoire | `dap_blanche` → **`parcoursup`** (valeur déjà connue de l'app) | 1 |
| 2b | **CUPGE** : Études en France **hors DAP** (comme le BUT), selon les pays | probable | fiche Campus France Burkina 2024-2025 ; Université Paris Cité | `dap_blanche` → **`eef`** | 17 |
| 2c | **CMI, STAPS, licences d'art / design, L1 d'IAE** : DAP, comme toute L1 universitaire. **LPE** : non établi (formation ouverte en 2026) | établi à probable ; LPE non établi | campusfrance.org/fr/candidature-enseignement-superieur-france (25/09/2026) ; pages STAPS Strasbourg, CMI Savoie | aucune ; LPE à confirmer | — |
| 3 | **L1 sélectives** : aucune source ne les fait passer par Parcoursup pour un résident d'un pays Études en France ; la mention « Licence 1 sélective » de Madagascar n'a **pas** été retrouvée (la page cite BTS, BTSA, CPGE) | probable | universite-paris-saclay.fr (candidats d'un pays EEF renvoyés vers Études en France) ; madagascar.campusfrance.org | **garder** `dap_blanche` ; confirmer par téléphone auprès de 3–4 Espaces Campus France | 705 |
| 4 | **BUT** : Études en France hors DAP (Maroc : via ADIUT Maroc). **DEUST** : même règle | BUT établi ; DEUST probable | cameroun.campusfrance.org (« exclusivement sur Etudes en France ») ; maroc.campusfrance.org ; univ-littoral.fr | **garder** `eef` ; ajouter plus tard la mention Maroc | 882 |
| 5 | **PASS / L.AS** : bien la DAP blanche. Mais **« non sélective » est faux pour un candidat DAP** : l'université examine le dossier, exige son niveau de français (C1 à Bordeaux), et peut ne pas ouvrir de campagne DAP | établi | document MEAE publié par Campus France Mali (2026) ; sante.u-bordeaux.fr | **reformuler la ligne de sélectivité pour toutes les L1 en DAP** (pas seulement la santé) | 2 428 lignes « non sélective » en DAP, dont 650 santé |
| 6 | **Cycles d'ingénieurs** : pas de règle unique (INSA : plateforme propre ; UT : Parcoursup + Campus France ; Polytech : Études en France pour 3 PeiP A). Le texte actuel « ne se demande pas par la procédure Études en France » est **faux pour Polytech et trompeur en général** (le visa passe toujours par Études en France) | établi pour INSA, UT, Polytech | polytech-reseau.org (guide international) ; insa-hautsdefrance.fr ; groupe-ut.fr | **reformuler la ligne `hors_eef`** ; aucune PeiP Polytech dans notre catalogue | 80 |
| 7 | **Repère de mention** : le chiffre ne décrit que des élèves de **terminale française** ; les candidats DAP sont évalués à part et le taux d'accès les exclut. « Vise au moins X/20 » induit en erreur | établi | documentation du jeu fr-esr-parcoursup (« néo-bacheliers = élèves inscrits en terminale française… » ; taux d'accès « seuls les candidats scolarisés en France ou de nationalité européenne ») | **reformuler**, retirer « vise au moins X/20 » | 3 525 |

**Formulations proposées** (à valider, FR ; l'anglais suivra le même sens) :

- *Point 5 — ligne de sélectivité d'une L1 en DAP* : « Classée non sélective sur Parcoursup,
  pour les élèves de terminale française. Pour une candidature par la demande d'admission
  préalable, l'université examine ton dossier et peut le refuser ; le niveau de français
  exigé et l'ouverture aux candidats DAP varient selon l'université. »
- *Point 6 — ligne `hors_eef`* : « Admission propre à l'école (concours ou plateforme dédiée),
  parfois en parallèle d'Études en France. Une fois admis, le visa passe par Études en France
  (« Je suis déjà accepté »). Vérifie la page des admissions internationales de l'école. »
- *Point 7 — repère* : « Aucune moyenne minimale officielle n'est publiée. Repère de
  concurrence uniquement : sur Parcoursup {session}, la mention la plus fréquente chez les {n}
  admis issus de terminale française était {mention}. Ces chiffres n'incluent pas les
  candidats à bac étranger : ton dossier est examiné à part, et ce repère n'est pas un seuil
  pour toi. »

**Ce que ces corrections demandent.** Les textes et procédures sont calculés par le serveur
(`eef-catalog.normalize.ts`, `eef-catalog.copy.ts`) et écrits sur chaque formation à
l'import : **aucune build mobile n'est nécessaire**. Mais les formations sont déjà
publiées, et les rattrapages existants ne comblent que des champs vides : il faut d'abord
construire **`eef:reconcile`** (réaligner `procedureType` et les textes des lignes publiées
sur les fichiers régénérés, simulation d'abord). Voir `docs/ouverture-espace-eef.md`.

## Annexe — lignes à contrôler, tirées des fichiers versionnés

**Point 1 — Sciences Po Paris, 1re année**

| Établissement | Formation | Cycle | Procédure | Sélectivité | Source |
| --- | --- | --- | --- | --- | --- |
| Sciences Po | L1 - Histoire | `licence1` | `dap_blanche` | `selective` | <https://dossierappel.parcoursup.fr/Candidats/public/fiches/afficherFicheFormation?g_ta_cod=32552&typeBac=0&originePc=0> |
| Sciences Po | L1 - Mathématiques | `licence1` | `dap_blanche` | `selective` | <https://dossierappel.parcoursup.fr/Candidats/public/fiches/afficherFicheFormation?g_ta_cod=32563&typeBac=0&originePc=0> |
| Sciences Po | Sciences Po / Instituts d'études politiques - Sciences Humaines et Sociales - Grade Licence | `licence1` | `dap_blanche` | `selective` | <https://dossierappel.parcoursup.fr/Candidats/public/fiches/afficherFicheFormation?g_ta_cod=34465&typeBac=0&originePc=0> |
| Sciences Po | L1 - Lettres | `licence1` | `dap_blanche` | `selective` | <https://dossierappel.parcoursup.fr/Candidats/public/fiches/afficherFicheFormation?g_ta_cod=32556&typeBac=0&originePc=0> |

**Point 2 — CMI, LPE, CUPGE, DCG**

| Établissement | Formation | Cycle | Procédure | Sélectivité | Source |
| --- | --- | --- | --- | --- | --- |
| Aix-Marseille Université | C.M.I - Sciences de la vie et de la terre | `licence1` | `dap_blanche` | `selective` | <https://dossierappel.parcoursup.fr/Candidats/public/fiches/afficherFicheFormation?g_ta_cod=18403&typeBac=0&originePc=0> |
| Avignon Université | C.M.I - Sciences de la vie et de la terre | `licence1` | `dap_blanche` | `selective` | <https://dossierappel.parcoursup.fr/Candidats/public/fiches/afficherFicheFormation?g_ta_cod=14978&typeBac=0&originePc=0> |
| CY Cergy Paris Université | L1 - Professorat des Ecoles | `licence1` | `dap_blanche` | `selective` | <https://dossierappel.parcoursup.fr/Candidats/public/fiches/afficherFicheFormation?g_ta_cod=52048&typeBac=0&originePc=0> |
| Le Mans Université | CUPGE - Cycle Universitaire Préparatoire aux Grandes Écoles de commerce | `licence1` | `dap_blanche` | `selective` | <https://dossierappel.parcoursup.fr/Candidats/public/fiches/afficherFicheFormation?g_ta_cod=20801&typeBac=0&originePc=0> |
| Nantes Université | C.M.I - Mathématiques | `licence1` | `dap_blanche` | `selective` | <https://dossierappel.parcoursup.fr/Candidats/public/fiches/afficherFicheFormation?g_ta_cod=29134&typeBac=0&originePc=0> |
| Sorbonne Université | C.M.I - Electronique, énergie électrique, automatique | `licence1` | `dap_blanche` | `selective` | <https://dossierappel.parcoursup.fr/Candidats/public/fiches/afficherFicheFormation?g_ta_cod=17972&typeBac=0&originePc=0> |

**Point 3 — L1 sélectives (hors familles des points 1 et 2)**

| Établissement | Formation | Cycle | Procédure | Sélectivité | Source |
| --- | --- | --- | --- | --- | --- |
| Aix-Marseille Université | L1 - Sciences et Humanités | `licence1` | `dap_blanche` | `selective` | <https://dossierappel.parcoursup.fr/Candidats/public/fiches/afficherFicheFormation?g_ta_cod=12621&typeBac=0&originePc=0> |
| Avignon Université | L1 - Information et communication | `licence1` | `dap_blanche` | `selective` | <https://dossierappel.parcoursup.fr/Candidats/public/fiches/afficherFicheFormation?g_ta_cod=10454&typeBac=0&originePc=0> |
| CY Cergy Paris Université | L1 - Physique | `licence1` | `dap_blanche` | `selective` | <https://dossierappel.parcoursup.fr/Candidats/public/fiches/afficherFicheFormation?g_ta_cod=39831&typeBac=0&originePc=0> |
| Institut national des langues et civilisations orientales | L1 - Langues, littératures et civilisations étrangères et régionales | `licence1` | `dap_blanche` | `selective` | <https://dossierappel.parcoursup.fr/Candidats/public/fiches/afficherFicheFormation?g_ta_cod=30370&typeBac=0&originePc=0> |
| La Rochelle Université | L1 - Histoire | `licence1` | `dap_blanche` | `selective` | <https://dossierappel.parcoursup.fr/Candidats/public/fiches/afficherFicheFormation?g_ta_cod=44130&typeBac=0&originePc=0> |

**Point 4 — BUT**

| Établissement | Formation | Cycle | Procédure | Sélectivité | Source |
| --- | --- | --- | --- | --- | --- |
| Aix-Marseille Université | BUT - Mobilité et supply chain connectées | `but1` | `eef` | `selective` | <https://dossierappel.parcoursup.fr/Candidats/public/fiches/afficherFicheFormation?g_ta_cod=2705&typeBac=0&originePc=0> |
| Avignon Université | BUT - Business développement et management de la relation client | `but1` | `eef` | `selective` | <https://dossierappel.parcoursup.fr/Candidats/public/fiches/afficherFicheFormation?g_ta_cod=10469&typeBac=0&originePc=0> |
| CY Cergy Paris Université | BUT - Développement web et dispositifs interactifs | `but1` | `eef` | `selective` | <https://dossierappel.parcoursup.fr/Candidats/public/fiches/afficherFicheFormation?g_ta_cod=11663&typeBac=0&originePc=0> |
| La Rochelle Université | BUT - Administration, gestion et exploitation des données | `but1` | `eef` | `selective` | <https://dossierappel.parcoursup.fr/Candidats/public/fiches/afficherFicheFormation?g_ta_cod=3053&typeBac=0&originePc=0> |

**Point 5 — PASS / L.AS**

| Établissement | Formation | Cycle | Procédure | Sélectivité | Source |
| --- | --- | --- | --- | --- | --- |
| Aix-Marseille Université | L1 - Sciences de la vie | `sante` | `dap_blanche` | `non_selective` | <https://dossierappel.parcoursup.fr/Candidats/public/fiches/afficherFicheFormation?g_ta_cod=39247&typeBac=0&originePc=0> |
| Avignon Université | L1 - Sciences de la vie et de la terre | `sante` | `dap_blanche` | `non_selective` | <https://dossierappel.parcoursup.fr/Candidats/public/fiches/afficherFicheFormation?g_ta_cod=31749&typeBac=0&originePc=0> |
| CY Cergy Paris Université | L1 - Informatique | `sante` | `dap_blanche` | `non_selective` | <https://dossierappel.parcoursup.fr/Candidats/public/fiches/afficherFicheFormation?g_ta_cod=48006&typeBac=0&originePc=0> |
| Institut national des langues et civilisations orientales | L1 - Langues, littératures et civilisations étrangères et régionales | `sante` | `dap_blanche` | `non_selective` | <https://dossierappel.parcoursup.fr/Candidats/public/fiches/afficherFicheFormation?g_ta_cod=29612&typeBac=0&originePc=0> |

**Point 6 — écoles d'ingénieurs**

| Établissement | Formation | Cycle | Procédure | Sélectivité | Source |
| --- | --- | --- | --- | --- | --- |
| Aix-Marseille Université | Formation d'ingénieur Bac + 5 | `ingenieur` | `hors_eef` | `selective` | <https://dossierappel.parcoursup.fr/Candidats/public/fiches/afficherFicheFormation?g_ta_cod=372&typeBac=0&originePc=0> |
| Conservatoire national des arts et métiers | Formation d'ingénieur Bac + 5 | `ingenieur` | `hors_eef` | `selective` | <https://dossierappel.parcoursup.fr/Candidats/public/fiches/afficherFicheFormation?g_ta_cod=317&typeBac=0&originePc=0> |
| CY Cergy Paris Université | Formation d'ingénieur Bac + 5 | `ingenieur` | `hors_eef` | `selective` | <https://dossierappel.parcoursup.fr/Candidats/public/fiches/afficherFicheFormation?g_ta_cod=31237&typeBac=0&originePc=0> |
| Institut national universitaire Jean-François Champollion | Formation d'ingénieur Bac + 5 | `ingenieur` | `hors_eef` | `selective` | <https://dossierappel.parcoursup.fr/Candidats/public/fiches/afficherFicheFormation?g_ta_cod=248&typeBac=0&originePc=0> |
