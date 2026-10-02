# Ouverture de l'espace « Études en France » — dossier de préparation

> Établi le 02/10/2026, après la soumission de la 2.3.0 (54). Complète
> `docs/runbook-ouverture-espace-reel.md` (le mode opératoire) : ce fichier dit **où on
> en est, ce qui manque, dans quel ordre**. Rien n'est ouvert : `eefSpace=false`.

## 1. Où on en est

| | État |
|---|---|
| Build 54 | **Soumise** le 02/10 (archive de `47a1295`). En attente d'approbation (1 à 3 jours) |
| Backend | `47a1295` en production (#299 à #303) |
| Catalogue | **Publié** : 10 029 formations, 84 établissements ; 473 en attente (page-source morte) |
| Espace | **Fermé** (`eefSpace=false`, `eef=false`, `eefTeaser=true`) ; recette sur appareil faite le 02/10 (fenêtre 10 h 23 – 10 h 35 UTC) |
| Actions `eef-space-on` / `-off` | Fonctionnent, mais **se marquent en échec** à tort (course au redémarrage) : corrigé par **#304**, à fusionner |

## 2. Ce qui bloque l'ouverture

### 2.1 Les 7 questions de procédure — **des corrections sont nécessaires**

La recherche du 02/10 (`docs/eef-dossier-relecture-procedures.md`, § « Réponses de
recherche ») établit que **cinq points du catalogue publié sont faux ou trompeurs** :

| # | Ce qui est faux | Lignes | Correction |
|---|---|---:|---|
| 1 | Sciences Po Paris L1 présentée en DAP : Sciences Po a sa propre voie internationale | 39 | procédure → `hors_eef` |
| 2a | DCG présenté en DAP : il passe par Parcoursup | 1 | procédure → `parcoursup` |
| 5 | « Formation non sélective » sur des L1 en DAP (dont les 650 PASS / L.AS) : faux pour un candidat DAP | 2 428 | reformuler la ligne |
| 6 | « ne se demande pas par la procédure Études en France » (cycles d'ingénieurs) : faux pour certaines écoles, et le visa passe toujours par Études en France | 80 | reformuler la ligne |
| 7 | « Vise au moins X/20 » : chiffre tiré des seuls élèves de terminale française | 3 525 | reformuler, retirer la consigne |

Et deux points **probables**, à confirmer ou à accepter : 2b (CUPGE → `eef`, 17 lignes),
3 (L1 sélectives : garder la DAP, 705 lignes).

**Ces corrections sont serveur seulement** — aucune build mobile. Mais il faut d'abord
construire l'outil qui manque :

### 2.2 `eef:reconcile` — l'outil à construire

Les formations publiées ne se corrigent aujourd'hui qu'une par une dans l'admin : `eef:import`
est en création seule, et les rattrapages (`eef:backfill:*`) ne comblent que des champs
vides. `eef:reconcile` doit :

1. régénérer les fichiers versionnés avec les règles corrigées (`eef-catalog.normalize.ts`,
   `eef-catalog.copy.ts`) ;
2. comparer, pour chaque formation **publiée ou en attente**, `procedureType`,
   `selectivity`, `requirementsFr/En` à ceux des fichiers — **simulation par défaut**, qui
   compte les différences par champ et par établissement et n'écrit rien ;
3. appliquer avec un **total attendu** (comme `eef-publish`), une transaction par
   établissement, une trace d'audit par établissement, sans toucher ni au tampon de
   vérification, ni à `isActive`, ni à une ligne modifiée à la main dans l'admin depuis
   l'import (elle est signalée, pas écrasée) ;
4. prouver depuis l'extérieur que le catalogue général n'a pas bougé (69 / 634).

Effort estimé : une journée de travail, plus la CI. Action `vps-ops` → `eef-reconcile`.

### 2.3 Les autres préconditions du runbook

| Précondition | État |
|---|---|
| 54 en vente sur les deux stores | ⏳ soumise |
| Backend porteur de la build 54 (`eef-catalog-attribution.js`) | ✅ `47a1295` |
| Catalogue publié, recherche qui répond | ✅ 10 029 |
| Héros du hub (`eef_hub_hero_body`) validé par le juridique | ⏳ |
| « depuis cet écran » (retrait) | ⏳ validé tel quel, ou lien « Me retirer » ajouté dans la feuille (sans nouvelle version de consentement) |
| #304 fusionnée | ⏳ |

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

1. **Valider les réponses de recherche** (§ 2.1 et le dossier de relecture) : « tout
   valider », ou point par point — en particulier les deux points probables (2b, 3) et la
   LPE (non établie). Idéalement, un appel à un Espace Campus France pour les points 3 et 4.
2. **Le feu vert pour construire `eef:reconcile`** et les corrections (une PR, CI, puis
   simulation en production — l'application reste à ton feu vert).
3. **Fusionner #304.**
4. **Le juridique** : la phrase du héros, « depuis cet écran », et l'audience de l'annonce.
5. **Le moment** : ouvrir dès l'approbation de la 54 et les corrections appliquées
   (recommandé), annoncer quand elle est largement installée.
