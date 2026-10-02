# Ouverture de l'espace « Études en France » — dossier de préparation

> Établi le 02/10/2026, après la soumission de la 2.3.0 (54). Complète
> `docs/runbook-ouverture-espace-reel.md` (le mode opératoire) : ce fichier dit **où on
> en est, ce qui manque, dans quel ordre**. Rien n'est ouvert : `eefSpace=false`.

## 1. Où on en est

| | État |
|---|---|
| Build 54 | **Soumise** le 02/10 (archive de `47a1295`). En attente d'approbation (1 à 3 jours) |
| Backend | `ebec041` en production (#305, déployé le 02/10 à 13 h 29 UTC) |
| Catalogue | **Publié** : 10 029 formations, 84 établissements ; 473 en attente (page-source morte) |
| Espace | **Fermé** (`eefSpace=false`, `eef=false`, `eefTeaser=true`) ; recette sur appareil faite le 02/10 (fenêtre 10 h 23 – 10 h 35 UTC) |
| Actions `eef-space-on` / `-off` | Fonctionnent, mais **se marquent en échec** à tort (course au redémarrage) : corrigé par **#304**, à fusionner |
| Questions de procédure | **Tranchées** le 02/10 (« tout valider ») et **appliquées en production** le 02/10 : `eef-reconcile` a réaligné 3 834 formations publiées dans 70 établissements (run 37014663792), dont 57 changements de procédure ; simulation de contrôle : 0 à réaligner |

## 2. Ce qui bloque l'ouverture

### 2.1 Les 7 questions de procédure — **tranchées, corrigées en production**

La recherche du 02/10 (`docs/eef-dossier-relecture-procedures.md`, § « Réponses de
recherche ») établit que **cinq points du catalogue publié sont faux ou trompeurs**. Le
propriétaire a tout validé le 02/10 ; les corrections sont dans le code (#305) et
attendent `eef-reconcile` pour atteindre la production :

| # | Ce qui est faux | Lignes | Correction |
|---|---|---:|---|
| 1 | Sciences Po Paris L1 présentée en DAP : Sciences Po a sa propre voie internationale | 39 | procédure → `hors_eef` |
| 2a | DCG présenté en DAP : il passe par Parcoursup | 1 | procédure → `parcoursup` |
| 5 | « Formation non sélective » sur des L1 en DAP (dont les 650 PASS / L.AS) : faux pour un candidat DAP | 2 428 | reformuler la ligne |
| 6 | « ne se demande pas par la procédure Études en France » (cycles d'ingénieurs) : faux pour certaines écoles, et le visa passe toujours par Études en France | 80 | reformuler la ligne |
| 7 | « Vise au moins X/20 » : chiffre tiré des seuls élèves de terminale française | 3 525 | reformuler, retirer la consigne |

Les deux points **probables** sont acceptés : 2b (CUPGE → `eef`, 17 lignes), 3 (L1
sélectives : la DAP est conservée, 705 lignes). La LPE reste en DAP faute de source. Un
appel à 3 ou 4 Espaces Campus France reste recommandé pour les points 3 et 4.

**Ces corrections sont serveur seulement** — aucune build mobile.

### 2.2 `eef:reconcile` — construit (#305), à lancer après le déploiement

Ce que fait l'outil (`backend/src/modules/etudes-en-france/catalog/eef-catalog.reconcile.ts`) :

1. les fichiers versionnés portent les règles corrigées (catalogue 1.3.0 : 57 procédures
   changées, prose réécrite) ;
2. pour chaque formation de l'import **publiée ou en attente**, il compare `procedureType`,
   `selectivity`, `requirementsFr/En` à ce que les règles donnent — **simulation par
   défaut**, qui compte les différences par champ, par procédure et par établissement, et
   n'écrit rien ;
3. il n'écrit qu'avec le **total saisi** (comme `eef-publish`), une transaction et une trace
   d'audit (`eef.catalog.reconciled`) par établissement. Le passage d'écriture refait sa
   propre simulation, l'imprime, refuse si son total n'est pas celui saisi, puis applique
   exactement SES listes : chaque formation n'est réécrite que si la base porte encore ce que
   cette simulation a lu. Le journal de l'écriture dit donc ligne pour ligne ce qui a été
   écrit. Il ne touche ni au tampon de vérification, ni à `isActive`, ni à l'intitulé.
   Une ligne **retouchée dans l'admin** est reconnue à sa prose — elle n'est plus, au
   caractère près, celle qu'un import a écrite — et **signalée, pas écrasée** ;
4. le workflow prouve depuis l'extérieur que le catalogue général (69 / 634) **et** le total de
   la recherche Études en France n'ont pas bougé, et affiche le décompte par procédure.

**Le séquencement**, chaque étape sur ton feu vert :

1. fusionner #305, puis déployer le backend (`deploy.yml`, `scope=full`) — c'est le code du
   conteneur qui calcule le plan ;
2. `vps-ops` → `eef-reconcile`, **`dry_run` coché** : la simulation doit annoncer **3 834
   formations à réaligner** (dont 57 changements de procédure : 39 Sciences Po → `hors_eef`,
   17 CUPGE → `eef`, 1 DCG → `parcoursup`) et **0 signalée**. Un autre nombre se lit dans les
   lignes « signalées » : ce sont des retouches faites dans l'admin, à regarder avant d'écrire ;
3. `vps-ops` → `eef-reconcile`, `dry_run` décoché, `expected_programs` = le total « À
   RÉALIGNER » de la simulation ;
4. contrôle : relancer la simulation → 0 à réaligner ; `GET
   /api/etudes-en-france/search?procedureType=parcoursup` → le DCG s'il est publié.

Essai possible sur un seul établissement : `institution_id` (ex. `eef-univ-0753431x`,
Sciences Po). Mesuré sur une base de test chargée des 10 502 formations : 9 s, sous la
limite mémoire du conteneur.

### 2.3 Les autres préconditions du runbook

| Précondition | État |
|---|---|
| Corrections de procédure appliquées en production (`eef-reconcile`) | ✅ 02/10 : 3 834 réalignées, 0 signalée ; recherche servie DAP blanche 3 076 · DAP jaune 29 · Études en France 6 804 · Parcoursup 1 · hors procédure 119 (total 10 029 inchangé, catalogue général 69 / 634 inchangé) |
| 54 en vente sur les deux stores | ⏳ soumise |
| Backend porteur de la build 54 (`eef-catalog-attribution.js`) | ✅ `ebec041` |
| Catalogue publié, recherche qui répond | ✅ 10 029 |
| Héros du hub (`eef_hub_hero_body`) validé par le juridique | ⏳ |
| « depuis cet écran » (retrait) | ⏳ validé tel quel, ou lien « Me retirer » ajouté dans la feuille (sans nouvelle version de consentement) |
| #304 fusionnée — **avant `eef-space-on`** : sans elle, l'étape « Prouver l'état de l'espace » ne peut pas s'exécuter (une apostrophe coupe son programme Python), donc rien ne prouve l'ouverture | ⏳ |

**Quand ouvrir ?** Ouvrir ne touche **que** la 54 : les 49 à 53 gardent la vitrine. Il n'y
a donc pas besoin d'attendre que la 54 soit majoritaire pour **ouvrir** — seulement qu'elle
soit **en vente** et que les corrections du § 2.1 soient appliquées. C'est l'**annonce**
qui doit attendre l'adoption (§ 4).

## 3. Le jour J — séquence

1. Contrôle de départ :
   ```bash
   curl -fsS https://api.kpbeducation.cloud/api/health/version
   curl -fsS https://api.kpbeducation.cloud/api/config/app | jq '.features | {eef, eefTeaser, eefSpace}'   # false, true, false
   ```
2. `vps-ops` → `eef-space-on`, **`dry_run` coché** : les contrôles passent, rien n'est écrit.
3. `vps-ops` → `eef-space-on`, **`dry_run` décoché**. Avec #304, le job attend que l'API
   ait redémarré puis prouve `eefSpace=true` ; sans #304 il se marque en échec à tort —
   relire alors la commande du point 1 (`eefSpace` → `true`).
4. Sur un téléphone avec la **54 du store** (pas TestFlight) : tuer et relancer l'app → le
   hub s'affiche ; sur une 53 → la vitrine. Chercher « médecine » (badge « Accès santé »).
5. Pendant l'heure qui suit : pas d'erreur `eef_catalog_failed` dans l'analytique (le
   connecteur PostHog doit être ré-autorisé pour que je puisse le lire).

**Retour arrière** : `vps-ops` → `eef-space-off` (immédiat, sans simulation). Les 54
retombent sur la vitrine ; les déclarations et profils restent en base.

## 4. L'annonce — après l'ouverture, quand la 54 est installée

**Pourquoi attendre** : une 53 qui ouvre `/etudes-en-france` voit la vitrine, et
`recommended-version-set` n'agit pas sur elle. Le texte doit donc **demander la mise à
jour**, et l'envoi gagne à attendre que la 54 soit largement installée (publication
progressive iOS : 7 jours ; Play par paliers).

**Audience recommandée** : `all_students_except_countries` avec
`{"exceptCountries": ["eef_suspended"]}` — sans risque sur le consentement (question
juridique ouverte pour `eef_interest`, `docs/eef-consent-v1.md` § 4). Route
**`/etudes-en-france`**. Lire l'aperçu (pays exclus, comptes retirés) avant le feu vert.
Fenêtre 8 h – 20 h ; plafond de 3 diffusions sur 7 jours.

**Brouillon (à valider ; aucun chiffre, aucune promesse d'admission)** :

| | Titre | Texte |
|---|---|---|
| FR | Études en France : ton espace est ouvert | Cherche ta formation dans les universités publiques françaises et prépare ton dossier. Mets l'app à jour pour y accéder. |
| EN | Études en France: your space is open | Search programmes at French public universities and prepare your application. Update the app to get access. |

Les comptes du **Niger** sont exclus par `eef_suspended`. Un compte sans pays renseigné ne
peut pas l'être : il recevra le message (limite connue).

## 5. Après l'ouverture

Les indicateurs du runbook (§ « Après l'ouverture ») : `eef_space_viewed`,
`eef_catalog_searched`, `eef_help_cta_tapped` par `help_step`, `eef_catalog_failed` ≈ 0 ;
déclarations d'intérêt dans l'admin ; à J+7, la part de recherches sans résultat.
`eef:check-sources` à refaire toutes les deux semaines (rapport valable 14 jours).

## 6. Ce que le propriétaire doit trancher

1. ~~Valider les réponses de recherche~~ — **fait** le 02/10 (« tout valider »).
2. ~~Construire `eef:reconcile` et appliquer les corrections~~ — **fait** le 02/10 : #305
   fusionnée, déployée (`ebec041`), simulée puis appliquée (3 834 formations), contrôle à 0.
3. **Fusionner #304.**
4. **Le juridique** : la phrase du héros, « depuis cet écran », et l'audience de l'annonce.
5. **Le moment** : ouvrir dès l'approbation de la 54 et les corrections appliquées
   (recommandé), annoncer quand elle est largement installée.
