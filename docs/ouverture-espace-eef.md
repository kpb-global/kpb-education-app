# Ouverture de l'espace « Études en France » — dossier de préparation

> **⚠️ 03/10/2026 — ce dossier a été corrigé.**
>
> La build 54 n'a **jamais été envoyée aux boutiques**. Les captures de App Store
> Connect (TestFlight → Build Uploads) et de Google Play Console montrées le 03/10/2026
> ne la contiennent pas : dernier envoi iOS `2.2.0 (53)` du 04/09, dernier bundle Android
> 53 / 2.2.0 (importé le 04/09, en production depuis le 11/09). Décision du propriétaire
> du 03/10 : on envoie **une seule build, `2.3.0 (55)`**, qui remplace la 54 et en
> porte tout le contenu.
>
> Les §1, §2.3, §3, §4 et §6 ci-dessous ont été remis à jour le 03/10 (état réel, décisions
> juridiques du 03/10, séquencement). Les opérations d'envoi : `docs/mise-a-jour-55-checklist.md`.

> **05/10/2026 — la build 56 est préparée** (bulle verte WhatsApp, visite guidée, feuille
> « écoles privées », tous dormants : `docs/release-56-store-pack.md`, `docs/release-ledger.md`
> « 56 — préparée, non archivée »). Elle ne change rien à l'état ci-dessous (espace fermé) ; elle
> change le **choix du moment** (§ 6, point 5) et ajoute des décisions (§ 6, point 7).

> Établi le 02/10/2026, corrigé le 03/10/2026 : la 2.3.0 (54) n'a jamais été soumise, la
> 2.3.0 (55) la remplace. Complète `docs/runbook-ouverture-espace-reel.md` (le mode
> opératoire) : ce fichier dit **où on en est, ce qui manque, dans quel ordre**. Rien
> n'est ouvert : `eefSpace=false`.

## 1. Où on en est

| | État |
|---|---|
| Build | **La 55 n'existe pas encore dans les boutiques.** La 54 n'a jamais été envoyée (constat du 03/10) ; la **2.3.0 (55)** la remplace et reste à archiver, soumettre et faire approuver (`docs/mise-a-jour-55-checklist.md`). Dernier envoi iOS : 2.2.0 (53) ; dernier bundle Android : 53 / 2.2.0. **Aucune build des boutiques ne contient le hub** |
| Backend | `0641601` en production depuis le 03/10 à 17 h 06 UTC : route `GET /etudes-en-france/cities`, limiteur unique à 60 req/min/IP/route (#313), correction de la shortlist (#307) — voir `docs/release-ledger.md` |
| Catalogue | **Publié** : 10 029 formations, 84 établissements ; 473 en attente (page-source morte). Filtres Niveau, Domaine, Ville et Procédure dans l'app (#314, build 55) |
| Espace | **Fermé** (`eefSpace=false`, `eef=false`, `eefTeaser=true`) ; la 55 part **espace fermé** (décision XC-03, état A : `docs/release-55-store-pack.md`). Une fenêtre `eef-space-on` / `-off` a eu lieu le 02/10 (10 h 23 – 10 h 35 UTC) ; **sur quelle installation la recette a été faite est à vérifier** — aucune 54 n'est dans les boutiques ni dans TestFlight : elle ne vaut pas recette de la 55, à refaire sur la build envoyée |
| Actions `eef-space-on` / `-off` | Corrigées par **#304**, fusionnée le 02/10 (`bf750c2`) : le job attend que l'API recréée réponde, et « Prouver l'état de l'espace » s'exécute enfin. Aucun déploiement requis (workflow seulement) |
| Préflight de release | Le run du 02/10 (37016398211, `ref=main` = `ebec041`, `requires-new`, dérogation 24 h) portait sur la 54 : **à refaire pour la 55**, sur son SHA de release, en `tolerates-old` (`docs/mise-a-jour-55-checklist.md`, étape 4). Un run sur `47a1295` avait échoué par construction : la production était EN AVANCE du commit de la build, cas que le préflight ne modélise pas — à éviter en ne déployant pas le backend d'un commit postérieur au SHA de release avant le préflight |
| Questions de procédure | **Tranchées** le 02/10 (« tout valider ») et **appliquées en production** le 02/10 : `eef-reconcile` a réaligné 3 834 formations publiées dans 70 établissements (run 37014663792), dont 57 changements de procédure ; simulation de contrôle : 0 à réaligner |
| Build 56 | **Préparée, non archivée** (`docs/release-ledger.md`) : porte la bulle, la visite et la feuille « écoles privées », derrière `eefSpace` et deux interrupteurs fermés (`eefHelpBubble`, `eefPrivateSchools`). Aucune n'est dans les boutiques |
| Juridique | **Tranché le 03/10/2026** : les quatre décisions du § 6 (lien « Me retirer », phrase du héros, annonce à tous, EEF-UX-15) |

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
| La build qui contient le hub (**55**, ou la **56** qui la reprend) en vente sur les deux stores, puis adoptée | ⏳ à archiver puis soumettre : la 54 n'a jamais été envoyée. Ouvrir avec la 55 ou attendre la 56 : § 6, point 5 |
| Backend porteur de la build (`eef-catalog-attribution.js`) | ✅ `0641601` (inclut `ebec041`) |
| Catalogue publié, recherche qui répond | ✅ 10 029 |
| Héros du hub (`eef_hub_hero_body`) validé par le juridique | ✅ 03/10 : la phrase sur Campus France est validée **telle quelle** |
| « depuis cet écran » (retrait) | ✅ 03/10 : lien « Me retirer » ajouté dans la feuille (**build 55**), texte consenti et `eef-consent-v1` inchangés. Vaut seulement quand la 55 est installée : les 49 à 53 n'ont pas ce lien |
| #304 fusionnée — **avant `eef-space-on`** : sans elle, l'étape « Prouver l'état de l'espace » ne peut pas s'exécuter (une apostrophe coupe son programme Python), donc rien ne prouve l'ouverture | ✅ 02/10 (`bf750c2`) |

**Quand ouvrir ?** Ouvrir ne touche **que** les builds qui contiennent le hub (la 55 et les
suivantes) : les 49 à 53 gardent la vitrine. Ouvrir avant que la 55 soit en vente n'a
aucun effet pour le public (seuls ses testeurs verraient le hub) ; l'ouvrir avant qu'elle
soit adoptée ne profite qu'à une minorité. **L'ouverture attend donc la 55 en vente sur
les deux stores et adoptée** — le seuil d'adoption n'est pas fixé dans le dépôt : à
décider (§ 6, point 4) —, comme l'écrit déjà la précondition 1 du runbook. Les corrections
du § 2.1 sont appliquées. L'**annonce** vient après l'ouverture (§ 4).

## 3. Le jour J — séquence

1. Contrôle de départ :
   ```bash
   curl -fsS https://api.kpbeducation.cloud/api/health/version
   curl -fsS https://api.kpbeducation.cloud/api/config/app | jq '.features | {eef, eefTeaser, eefSpace}'   # false, true, false
   ```
2. `vps-ops` → `eef-space-on`, **`dry_run` coché** : les contrôles passent, rien n'est écrit.
3. `vps-ops` → `eef-space-on`, **`dry_run` décoché**. Le job attend que l'API ait redémarré
   puis prouve `eefSpace=true` (#304). S'il rougit malgré tout, relire la commande du point 1
   (`eefSpace` → `true`) avant toute autre action.
4. Sur un téléphone avec la **55 du store** (pas TestFlight) : tuer et relancer l'app → le
   hub s'affiche ; sur une 53 → la vitrine. Chercher « médecine » (badge « Accès santé »).
   Avec la **56**, la première ouverture du hub montre la **visite guidée** (elle n'a pas
   d'interrupteur) ; la bulle et la feuille « écoles privées » attendent leurs propres
   actions (`docs/runbook-ouverture-espace-reel.md`).
5. Pendant l'heure qui suit : pas d'erreur `eef_catalog_failed` dans l'analytique (le
   connecteur PostHog doit être ré-autorisé pour que je puisse le lire).

**Retour arrière** : `vps-ops` → `eef-space-off` (immédiat, sans simulation). Les 55
retombent sur la vitrine ; les déclarations et profils restent en base.

## 4. L'annonce — après l'ouverture, quand la 55 est installée

**Pourquoi attendre** : une 53 qui ouvre `/etudes-en-france` voit la vitrine, et
`recommended-version-set` n'agit pas sur elle (elle ne lit pas `recommendedVersion`). Le texte
doit donc **demander la mise à jour**, et l'envoi gagne à attendre que la 55 soit largement
installée (publication progressive iOS : 7 jours ; Play par paliers).

**Audience (décision juridique du 03/10/2026)** : **tous les étudiants, Niger compris**
(`all_students`). Un étudiant nigérien peut faire sa procédure par un autre pays : on ne
bloque personne. Le texte est **neutre** : il ne promet pas que la procédure est ouverte pour
le lecteur. **Ne pas** utiliser `eef_suspended` pour exclure le Niger, **ne pas** utiliser
l'audience `eef_interest` : la question de consentement (`docs/eef-consent-v1.md` § 4,
point 4) n'est pas tranchée. Route **`/etudes-en-france`**. Lire l'aperçu (nombre de
destinataires) avant le feu vert. Fenêtre 8 h – 20 h ; plafond de 3 diffusions sur 7 jours.

**Ce que l'outillage dit encore, et qui contredit cette décision** (constaté dans le dépôt le
03/10/2026). L'agent `kpb-notifications` (`.claude/agents/kpb-notifications.md`, rubrique
« Études en France ») ordonne, pour une annonce du type « la campagne est ouverte », d'exclure
les pays suspendus (`{"exceptCountries": ["eef_suspended"]}`) et de n'utiliser que
`eef_interest` ou `all_students_except_countries`. L'outil `kpb_draft_notification`
(`tools/kpb-admin-mcp/index.mjs`) émet, sur toute annonce vers `/etudes-en-france` qui
n'exclut pas les pays suspendus, l'avertissement « Cette annonce vise Études en France sans
exclure les pays suspendus : préférer all_students_except_countries ou eef_interest… » — un
**avertissement**, pas un blocage : le brouillon reste envoyable. Pour cette annonce,
l'avertissement est **attendu** (décision juridique du 03/10), on **n'ajoute pas**
`exceptCountries`, et la consigne (audience `all_students`, Niger compris, texte neutre) est
**donnée explicitement à l'agent**, qui suivrait sinon sa fiche. Mettre l'agent et l'outil à
jour est un chantier à part (PR séparée, à faire avant le jour J) ; d'ici là, un humain relit
l'aperçu : le nombre de destinataires doit être celui des comptes étudiants, sans pays retiré.

**Brouillon (à valider ; aucun chiffre, aucune promesse d'admission, aucune promesse que la
procédure soit ouverte pour le lecteur)** :

| | Titre | Texte |
|---|---|---|
| FR | Études en France : ton espace est ouvert | Cherche ta formation dans les universités publiques françaises et prépare ton dossier. Mets l'app à jour pour y accéder. |
| EN | Études en France: your space is open | Search programmes at French public universities and prepare your application. Update the app to get access. |

Le brouillon du 02/10 est repris, **à valider** : il ne dit rien de la procédure d'un pays,
mais « prépare ton dossier » est la formule à relire avec le critère du 03/10 (ne pas
promettre que la procédure est ouverte pour le lecteur). Dans l'espace, un compte du Niger
voit les aides en variante neutre et plus d'avertissement de suspension nulle part (vitrine, hub, catalogue : retiré le 05/10/2026) (« autres options ») ; l'annonce,
elle, n'en dit rien.

## 5. Après l'ouverture

Les indicateurs du runbook (§ « Après l'ouverture ») : `eef_space_viewed`,
`eef_catalog_searched`, `eef_help_cta_tapped` par `help_step`, `eef_catalog_failed` ≈ 0 ; avec
la 56, `eef_bubble_opened`, `eef_tour_shown` / `eef_tour_completed`, `eef_private_info_opened` ;
déclarations d'intérêt dans l'admin ; à J+7, la part de recherches sans résultat.
`eef:check-sources` à refaire toutes les deux semaines (rapport valable 14 jours).

## 6. Ce que le propriétaire doit trancher

1. ~~Valider les réponses de recherche~~ — **fait** le 02/10 (« tout valider »).
2. ~~Construire `eef:reconcile` et appliquer les corrections~~ — **fait** le 02/10 : #305
   fusionnée, déployée (`ebec041`), simulée puis appliquée (3 834 formations), contrôle à 0.
3. ~~Fusionner #304~~ — **fait** le 02/10 (`bf750c2`).
4. ~~**Le juridique**~~ — **tranché le 03/10/2026**, quatre décisions :
   1. **« depuis cet écran »** : un lien « Me retirer » est ajouté dans la feuille de
      déclaration d'intérêt (build 55). Le texte consenti et `eef-consent-v1` ne changent pas.
   2. **La phrase du héros sur Campus France** (`eef_hub_hero_body`) est validée telle quelle.
   3. **L'annonce d'ouverture** part vers **tous les étudiants, Niger compris**, avec un texte
      neutre qui ne promet pas que la procédure est ouverte pour le lecteur ; l'audience
      `eef_interest` reste **inutilisée** tant que la question de consentement
      (`docs/eef-consent-v1.md` § 4, point 4) n'est pas tranchée.
   4. **EEF-UX-15** (découpler ou assumer le couplage profil / consentement) **ne se pose pas
      pour la 55** : aucune sélection de formations n'exige de profil déclaré.
5. **Le moment** : ouvrir quand la **55** est en vente sur les deux stores **et adoptée**, et
   annoncer ensuite. **Avec la 56 en vue** : ouvrir avec la 55 si elle est approuvée avant que la
   56 soit prête (le catalogue et les aides servent tout de suite ; bulle et visite arrivent à
   la mise à jour) ; si la 56 est proche (environ 3 semaines), attendre est défendable pour une
   première impression complète — décision (f) du pack de la 56. **Le seuil d'adoption n'est pas défini** dans le dépôt (part des sessions
   en 2.3.0 (55) dans PostHog, par exemple) : à fixer avant le jour J.
6. **Archiver, soumettre et faire approuver la 55** : `docs/mise-a-jour-55-checklist.md`. Aucune
   étape de distribution ne se fait sans le feu vert explicite du propriétaire.
7. **Les décisions de la 56** (`docs/release-56-store-pack.md` §7), avant d'allumer
   `eefHelpBubble` et `eefPrivateSchools` : (a) KPB est-il rémunéré par des écoles privées ?
   (b) Niger : aucune mention d'école privée (retenu) ; (c) « frais en général plus élevés que
   dans le public » ou son repli ; (d) qui répond au +33768674292, quand, étiquettes WhatsApp
   Business et message d'absence ; (e) XC-06 et D5 avant la soumission ; (f) ouvrir avec la 55
   ou attendre la 56 ; (g) version marketing de la 56 selon l'état de la 55 dans App Store
   Connect (ITMS-90062). (a) et (c) portent sur des textes **compilés** : avant l'archive.
