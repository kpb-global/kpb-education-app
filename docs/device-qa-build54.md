# Fiche de QA appareil — build 54 (`2.3.0`)

> **⚠️ 03/10/2026 — fiche écrite pour la 54, qui n'a jamais été envoyée.**
>
> La build 54 n'a **jamais été envoyée aux boutiques**. Les captures de App Store
> Connect (TestFlight → Build Uploads) et de Google Play Console montrées le 03/10/2026
> ne la contiennent pas : dernier envoi iOS `2.2.0 (53)` du 04/09, dernier bundle Android
> 53 / 2.2.0 (importé le 04/09, en production depuis le 11/09). Décision du propriétaire
> du 03/10 : on envoie **une seule build, `2.3.0 (55)`**, qui remplace la 54 et en
> porte tout le contenu.
>
> Les §A, §B, §B-aide, §C et §D **restent valables pour la 55** : lire `2.3.0 (55)` là où
> la fiche écrit `2.3.0 (54)` (A1 : TestFlight, ou `versionCode` 55 sur Android). Ce qui
> s'ajoute avec la 55 — aides à la demande de dossier, lien « Me retirer » dans la feuille,
> variante neutre pour le Niger, anglais — est dans **`docs/device-qa-build55.md`**. Les
> opérations d'envoi sont dans `docs/mise-a-jour-55-checklist.md`.
>
> **Les filtres du catalogue ont leur recette ici : §B-filtres, plus bas.** #314 (fusionnée ;
> côté serveur, en production depuis le 03/10) a remplacé la rangée de puces « Niveau et
> Procédure avec compteurs » par quatre boutons — Niveau, Domaine, Ville, Procédure — qui
> ouvrent chacun une feuille de choix. **B3 et B13 décrivaient cette rangée : elles ont été
> réécrites** et renvoient au §B-filtres. B14 (la carte : procédure, badge, niveau) n'est pas
> touchée. Dans Aide-7 et Aide-15, « filtre Parcoursup » (ou « DAP dossier jaune », « Hors
> procédure ») se pose maintenant par la feuille « Procédure », puis « Voir N formations ».
> `docs/device-qa-build55.md` ne couvre pas les filtres : il renvoie à B3 de cette fiche.

> **Pour qui.** Le propriétaire, sur **un iPhone et un Android physiques**, avec la
> **build soumise** (TestFlight / Play Internal) — pas un build de debug : le
> contrat de soumission exige que la preuve vienne de l'artefact, et que
> l'installation soit bien celle qu'on envoie. Complète
> `docs/phase1-stability-smoke-checklist.md` (le smoke « every release candidate »,
> toujours exigé) ; ne le remplace pas. Modèle : `docs/device-qa-build49.md`.
>
> **Ce que la prod ne permet PAS de tester** : l'état « Le catalogue arrive » (B5,
> second cas d'Aide-6) — le catalogue de production est publié depuis le 01/10
> (10 029 formations, 84 établissements) — et les logos (B10 : la carte du
> catalogue n'en dessine pas, et aucun des 69 établissements servis par Explorer n'avait
> de logo le 03/10). Le reste du §B se teste **contre la production**
> (voie 2).

## A. Sur la build soumise, contre la production

Cocher, noter l'appareil et l'heure. Un ✗ s'écrit avec ce qu'on a vu.

Avant A1, et de nouveau après le §B :

```bash
curl -fsS https://api.kpbeducation.cloud/api/config/app | jq '.features | {eef, eefTeaser, eefSpace}'
# attendu pour le §A et pour la soumission : false, true, false
```

| # | À vérifier | Attendu | iPhone | Android |
|---|---|---|---|---|
| A1 | Version | `2.3.0 (54)` ; `GET /api/config/app` → `minVersion` strictement inférieure. *iPhone : seul TestFlight affiche « 2.3.0 (54) » (Réglages → Général → Stockage n'affiche que « 2.3.0 »). Android : Play Console, ou `adb shell dumpsys package com.karatou.android \| grep versionCode` → 54. L'app n'affiche pas sa version : manque connu.* | ☐ | ☐ |
| A2 | Vitrine, pays hors Niger | Accueil → carte « Études en France » → « À partir du 1er octobre 2026 », **sans compte à rebours** le jour J et après ; lien « Voir la plateforme officielle » qui s'ouvre | ☐ | ☐ |
| A3 | Vitrine, compte du **Niger** | La mise en garde **remplace** la date ; lien « Voir la source officielle » (page de l'ambassade) ; aucune date | ☐ | ☐ |
| A4 | Déclaration d'intérêt | « Ça m'intéresse » → niveaux, **domaines** (12 puces, préremplies depuis le profil), consentement affiché avant « Valider » → « C'est noté » ; l'admin voit la ligne | ☐ | ☐ |
| A5 | Retrait | « Me retirer de la liste » → confirmation → retiré ; la ligne disparaît de l'admin | ☐ | ☐ |
| A6 | Compte **parent** par lien profond `kpb://etudes-en-france` | « Un espace pour les étudiants », bouton conseiller ; pas de vitrine ni de hub | ☐ | ☐ |
| A7 | **Invité** | La vitrine s'ouvre ; « Créer mon compte » à la place de la déclaration | ☐ | ☐ |
| A8 | Fiche d'un établissement (Explorer) | **Plus de jauge verte « 85 % »** ; avec #287 : plus aucun « % » nulle part (Universités, Comparer, fiche formation, carte partageable, accueil) — un badge « Très bon match / Bon match / À explorer » si le profil est rempli, **aucun badge** sans profil | ☐ | ☐ |
| A8 bis | Lettres → « Adapter à mon profil » (avec #288) | La personnalisation aboutit, parfois après 20 à 40 s (jusqu'à 90 s) ; si elle tarde : « La génération prend plus de temps que prévu… », **jamais** « vérifiez votre connexion » sur un réseau qui marche | ☐ | ☐ |
| A9 | Notification « récit de la semaine » reçue **app tuée** | Le tap ouvre le **récit** (pas l'accueil) — #284 | ☐ | ☐ |
| A10 | Étiquettes OneSignal (tableau OneSignal) | `level` en clé normalisée ; `target_country` **absent** quand il est vide — #286 | ☐ | ☐ |
| A11 | Réception réelle d'une notification | Reçue sur l'appareil (APNs production / FCM) | ☐ | ☐ |
| A12 | Conditions / Confidentialité | « Dernière mise à jour : septembre 2026 » ; plus de « espace communautaire » dans la liste des services | ☐ | ☐ |
| A13 | Mise à jour **forcée** (porte de version) | Avec `KPB_MIN_APP_VERSION` temporairement au-dessus : l'écran bloquant s'affiche, **avec un bouton conseiller** ; revenir à `0.0.0` après | ☐ | ☐ |
| A14 | Bandeau **doux** de mise à jour | Il n'apparaît que si `recommendedVersion` > version installée : sur la 54, il faut donc une **PR** qui met `RECOMMENDED_APP_VERSION` à une version supérieure (`2.3.1` par exemple) dans `vps-ops.sh`, puis l'action `recommended-version-set` ; remettre la constante à vide ensuite. Attendu : bandeau fermable sur l'accueil, lien du store ; fermé, il ne revient pas dans la session. *Aucun effet sur les builds 49 à 53.* | ☐ | ☐ |
| A15 | En-têtes de version | **Non vérifiable aujourd'hui côté serveur** : aucun code backend ne lit ni ne journalise `X-KPB-App-Version` / `X-KPB-App-Build`, et le proxy n'est pas dans le dépôt. Les en-têtes sont posés par l'app (testés en unitaire). Un proxy Wi-Fi (Charles / mitmproxy réglé dans les réglages Wi-Fi) ne voit **pas** ces requêtes : le `HttpClient` de Dart ignore le proxy système. Seule la variante « mandataire inverse » du §B les montre. Les lire côté serveur est un chantier de la 55. | ☐ | — |
| A16 | Texte agrandi (réglages d'accessibilité au maximum) | Vitrine, accueil, Universités : rien de coupé, rien qui déborde (le hub et le catalogue : B14 / Aide-11) | ☐ | ☐ |
| A17 | Hors ligne | Avion : l'accueil reste utilisable (le catalogue hors ligne : B6) | ☐ | ☐ |
| A18 | Signalement IA | Un signalement depuis le **coach**, un depuis l'**orientation**, avec leurs références de dossier (preuve exigée par le contrat §5) | ☐ | ☐ |
| A19 | État A étanche | Ni hub, ni carte « C'est flou ? », ni badge « Accès santé » ; `kpb://etudes-en-france/catalogue` → écran « bientôt » | ☐ | ☐ |
| A20 | Non-affiliation (XC-04) | Vitrine : la mention de non-affiliation et son lien « Voir la plateforme officielle » s'ouvrent | ☐ | ☐ |

## B. Recette du hub et du catalogue (build lancée avec l'espace ouvert)

Le hub est derrière `features.eefSpace`, éteint en production. **La valeur servie
par le serveur prime sur le réglage de compilation** : `--dart-define=
KPB_EEF_SPACE_ENABLED=true` seul ne montre rien contre la prod. Trois voies :

1. **Voie 2 — prod, fenêtre de recette (recommandée, avant la soumission)**. Tant
   que la 54 n'est que sur TestFlight / Play Internal, `vps-ops` → `eef-space-on`
   n'ouvre le hub **qu'aux testeurs** : les builds 49 à 53 ignorent `eefSpace` et
   gardent la vitrine. Les préconditions de l'action sont remplies (catalogue
   publié, backend `33c5a51`). C'est la seule voie qui teste **l'artefact soumis**
   sur le **vrai catalogue**. Règles :
   - accord du propriétaire ; **aucune notification** pendant la fenêtre ;
   - **tuer et relancer l'app** après chaque bascule (drapeaux lus au démarrage) ;
   - **`eef-space-off` AVANT « Soumettre pour vérification »**, puis le `curl` du §A
     (`eefSpace` → `false`) : sinon le relecteur voit l'état B.
2. **Voie 1 — backend local + tunnel HTTPS** : seulement pour B5 et le second cas
   d'Aide-6 (une base sans publication). Backend local au commit de la release
   (le badge et les synonymes santé sont calculés par le serveur), lancé avec
   `KPB_EEF_SPACE_ENABLED=true`, exposé en **HTTPS** (`cloudflared tunnel --url
   http://localhost:4000` ou `ngrok http 4000`) ; app lancée avec
   `--dart-define=KPB_API_BASE_URL=https://<tunnel>/api`. **Le HTTP simple ne
   marche pas sur un appareil physique** (iOS `NSAllowsArbitraryLoads=false`,
   Android sans trafic en clair). Ce n'est pas l'artefact soumis.
3. *Variante sans toucher la prod* : un mandataire inverse
   (`mitmdump --mode reverse:https://api.kpbeducation.cloud`) qui réécrit
   `features.eefSpace` à `true` dans `/api/config/app`, exposé par `cloudflared`,
   app lancée avec `--dart-define=KPB_API_BASE_URL=https://<tunnel>/api`. Pas
   l'artefact soumis non plus. **Après un `flutter run` avec ces options, ne pas
   archiver sans refaire `flutter build ios --release`** : il réécrit
   `ios/Flutter/Generated.xcconfig`.

Puis, sur le hub :

| # | À vérifier | Attendu |
|---|---|---|
| B1 | Héros | « Prépare ta candidature aux universités françaises » ; le corps dit où se dépose la candidature ; date selon le pays (compte du Niger : mise en garde dans la 54 et la 55, rien dans la 56) |
| B2 | Tuiles | Formations, CV, Lettres, Entretien : **chacune ouvre un écran qui marche** ; aucune mention « en préparation ». Le conseiller n'est plus une tuile : c'est la carte d'aide (§B-aide) |
| B3 | Catalogue | Recherche par nom d'université / sigle / ville (sans accents) ; chaque carte nomme l'université, la ville, la procédure ; les filtres Niveau, Domaine, Ville et Procédure : §B-filtres |
| B4 | Cas vide | Recherche sans résultat → « Aucune formation ne correspond » + « Tout effacer » **qui vide aussi le champ** |
| B5 | Catalogue non publié | (base sans publication) « Le catalogue arrive », **sans** « Tout effacer » |
| B6 | Panne | Réseau coupé → « Pas de connexion » ; une page suivante qui échoue **garde la liste** et propose « Réessayer » |
| B7 | Pied de page | Fin de liste : « Données : Ministère de l'Enseignement supérieur et de la Recherche (…). Licence Ouverte 2.0. Actualisées le … » + non-affiliation + lien ; la rangée « Sources des données et mentions » ouvre la même feuille à tout moment |
| B8 | Profil | « Mon profil Études en France » : Compléter → déclaré ; Modifier (domaines) **ne redemande pas le consentement** ; Me retirer fonctionne |
| B9 | Outils IA | CV / lettres / entretien : invité → mur de conversion ; étudiant sans consentement IA → dialogue de consentement |
| B10 | Logos (recette seulement) | Dans la fiche d'un établissement qui en a un : logo **et** crédit de licence ; un logo SVG qui ne charge pas ne casse pas la fiche (MISS-01) |
| B11 | « médecine » | ≈ 589 résultats, tous « L1 - … » (PASS / L.AS), chacun avec le badge « Accès santé » ; aucun diplôme paramédical en première page. Idem « pharmacie », « kiné », « dentaire », « L.AS », « medicine » ; « PASS » → ≈ 205, seulement des PASS |
| B12 | « orthophoniste » / « santé » | Certificat d'orthophoniste **sans** badge. « santé » → ≈ 924 : badge sur les PASS / L.AS seulement. « las » ne ramène aucun « Arts plastiques » |
| B13 | Filtre Niveau | Dans la feuille « Niveau » (Filtres-2), la ligne du cycle santé dit « Études de santé » (pas « Accès santé ») : elle compte aussi les 61 diplômes paramédicaux, sans badge |
| B14 | EN, ×1,3, iPhone SE / Android 360 dp | Badge « Health studies access » ; la rangée procédure + badge + niveau passe à la ligne sans rien couper |

## B-filtres. Filtres du catalogue (même build que le §B)

Écrite le 03/10/2026 d'après le code de #314 (`eef_catalog_filters.dart`,
`eef_filter_options.dart`, `eef_catalog_controller.dart`) et **jamais jouée sur appareil** : un
« attendu » qui se révèle faux se corrige ici, on ne plie pas la recette à la build.

Le catalogue se filtre par **quatre boutons** — Niveau, Domaine, Ville, Procédure — qui ouvrent
chacun une **feuille de choix** (une case par valeur, avec son compteur). Rien n'est demandé au
serveur avant « Voir N formations » : une seule requête, quel que soit le nombre de cases
cochées ; fermer la feuille sans valider (balayage, retour, fond) ne change rien. Les filtres
sont dans le catalogue, donc derrière `features.eefSpace` : mêmes conditions de recette que le §B.

| # | À vérifier | Attendu |
|---|---|---|
| Filtres-1 | Les quatre boutons | Au-dessus de la liste : « Niveau », « Domaine », « Ville », « Procédure » dans cet ordre (EN : Level, Field, City, Procedure). « Ville » est toujours là ; les trois autres s'affichent quand le serveur a servi des valeurs à y choisir (ou qu'une est déjà posée). Aucun bouton quand le serveur n'a rien servi à filtrer (panne, catalogue non publié) et qu'aucun filtre n'est posé. Chaque bouton fait 48 dp de haut au moins ; ils passent à la ligne quand ils ne tiennent pas sur une. |
| Filtres-2 | Feuille « Niveau » | Une case par niveau servi, avec son compteur, du plus bas au plus haut : Licence 1re année, Licence 2e année, Licence 3e année, BUT 1re année, DEUST, Études de santé, Cycle ingénieur, Master. Cocher n'envoie rien : le bouton du bas devient « Voir N formations » (N = somme des cases cochées ; « Voir 0 formation » possible ; sans case cochée, il annonce le total courant) ; « Effacer » (en haut de la feuille, seulement quand une case est cochée) décoche tout dans la feuille. Après « Voir N formations » : le bouton devient « Niveau · 2 » (fond bleu plein, texte blanc) et la liste se recharge. |
| Filtres-3 | Feuille « Domaine » | Les domaines servis, par ordre alphabétique, chacun avec son compteur et son nom dans la langue de l'app ; **jamais** un code (« d07 ») à la place du nom ; un nom long (« Énergie, Environnement & Développement durable ») passe à la ligne. |
| Filtres-4 | Feuille « Procédure » | « DAP dossier blanc », « DAP dossier jaune », « Études en France », « Parcoursup », « Hors procédure » (EN : « DAP, white form », « DAP, yellow form », « Études en France », « Parcoursup », « Outside the procedure »), chacune avec son compteur. Repère au 02/10, sans autre filtre (`docs/ouverture-espace-eef.md` § 2.3) : 3 076 · 29 · 6 804 · 1 · 119, total 10 029 — un ordre de grandeur, le catalogue peut avoir bougé. |
| Filtres-5 | Feuille « Ville » | « Chargement des villes… », puis un champ « Chercher une ville » et la liste, triée par nombre de formations décroissant ; la recherche ignore accents et majuscules ; une saisie sans résultat → « Aucune ville ne correspond ». **La liste est complète** (276 villes mesurées sur le catalogue 1.3.0, d'après #314), pas seulement les 20 plus fournies, qui ne couvrent que 4 201 formations sur 10 029 : chercher une ville peu fournie (absente des 20 premières lignes), la cocher, « Voir N formations » → seules ses formations s'affichent, chaque carte nomme cette ville. |
| Filtres-6 | Compteurs et « Voir N formations » | Poser Niveau = Master, puis ouvrir « Procédure » et « Ville » : leurs compteurs ne comptent que les masters, pas le catalogue entier. Cocher deux valeurs d'une même famille **élargit** la liste (le N de « Voir N formations » est la somme des deux compteurs). Le N annoncé par le bouton doit être le total que la liste affiche ensuite (« N formations ») : noter tout écart, pour Niveau, Procédure, Ville puis Domaine. |
| Filtres-7 | « Ville » hors ligne | Mode avion **avant** de toucher « Ville » : la feuille dit « Impossible de charger les villes » et « Pas de connexion. Vérifie-la, puis réessaie. », avec « Réessayer » — jamais une liste vide ni un écran bloqué (on peut fermer la feuille). Réseau rétabli, « Réessayer » charge la liste. |
| Filtres-8 | « Ville », repli (backend sans la route) | Si `GET /etudes-en-france/cities` répond 404, 405 ou 5xx (backend plus ancien que l'app), la feuille propose les villes de la facette de la recherche — les plus fournies, 20 au plus — avec la mention « Villes principales — pour une autre ville, tape-la dans la recherche », sans rien bloquer. **Ne se teste pas contre la production** (la route y répond depuis le 03/10, 17 h 06 UTC, backend `0641601`) : voie 3 du §B avec une règle du mandataire qui répond 404 à `/api/etudes-en-france/cities`, ou voie 1 avec un backend local au commit `a7b3fcf` (celui d'avant #314). |
| Filtres-9 | Filtres actifs | Après validation : une puce par valeur choisie sous les boutons, plus « Tout effacer ». Un tap sur une puce retire ce seul filtre ; « Tout effacer » les retire tous **et vide le champ de recherche**. Cibles de 48 dp au moins. |
| Filtres-10 | Texte agrandi, petit écran, anglais | ×1,3 sur Android 360 dp **et** iPhone SE : les quatre boutons passent à la ligne, aucun n'est coupé ; la feuille « Ville » avec le clavier ouvert garde « Voir N formations » visible au-dessus du clavier ; avec dix villes choisies, la zone des filtres défile dans sa propre hauteur et la liste garde de la place. En anglais : « Show N programmes », « Clear all », « Search a city ». |
| Filtres-11 | Lecteur d'écran | Chaque bouton annonce son nom puis « Aucun choix » ou « N choix » (EN : « N selected ») ; chaque case annonce « <libellé>, N formation(s) » et son état coché ; chaque puce « Retirer le filtre <libellé> » (EN : « Remove filter … »). |

## B-aide. Cartes d'aide « C'est flou ? » (même build que le §B)

« À chaque étape où c'est flou, on pose une question » : une carte (ou une ligne)
qui ouvre WhatsApp vers le conseiller, avec un message **prérempli qui dit à quelle
étape on en est**. Elles vivent dans le hub et le catalogue, donc derrière
`features.eefSpace` : mêmes conditions de recette que le §B. Aucune de ces cartes ne
promet d'admission, de visa ni de prix — la mention sous la carte le dit.

Pour chaque ✗ : noter l'écran, la langue, le pays du compte.

| # | À vérifier | Attendu |
|---|---|---|
| Aide-1 | Hub, compte **hors Niger** | Trois emplacements, dans cet ordre : une ligne « Procédure, dates, dépôt : c'est flou ? » sous le héros ; **une** carte « C'est flou ? Tu veux de l'aide ? » sous « Trouver ma formation » ; une ligne « Tu ne sais pas quels documents préparer ? » sous les outils (absente si les outils IA sont masqués). L'ancienne tuile « Parler à un conseiller » **n'existe plus**. |
| Aide-2 | Bouton de la carte du hub | « Démarrer l'étude de mon dossier sur WhatsApp » → WhatsApp s'ouvre sur la ligne du conseiller (`AppConfig.whatsappNumber`) avec : *« Bonjour KPB Education, je suis dans l'espace Études en France de l'app (étape : accueil de l'espace). Pour passer à l'étape supérieure, j'aimerais démarrer l'étude de mon dossier. »* **Rien d'autre** : ni nom, ni e-mail, ni téléphone, ni pays. Le message n'est pas envoyé tout seul. |
| Aide-3 | Les deux lignes | « Demander de l'aide sur WhatsApp » → même message, avec « (étape : procédure, dates et dépôt) » puis « (étape : documents à fournir) ». |
| Aide-4 | Langue **anglaise** | « Unclear? Want some help? », « Start my file review on WhatsApp » ; le message prérempli est en anglais (« Hello KPB Education, I am in the Études en France space… »). |
| Aide-5 | Catalogue, sous les résultats | Recherche assez étroite pour que la liste soit entière → carte « Tu hésites sur ta formation ? » sous la dernière formation, **avant** les mentions de données. Liste longue, encore paginée : **pas** de carte tant qu'il reste des pages. |
| Aide-6 | Catalogue, aucun résultat / non publié | « Aucune formation ne correspond » → « Tout effacer » **et** la carte « Tu ne trouves pas ta formation ? » ; « Le catalogue arrive » → la carte « Tu ne veux pas attendre ? » (sans « Tout effacer »). |
| Aide-7 | Catalogue, procédure | Filtre « Parcoursup », « DAP dossier jaune » ou « Hors procédure » → une ligne « Pas sûr(e) de la procédure pour ces formations ? » sous le compteur ; filtre « Études en France » ou « DAP dossier blanc » → **pas** de ligne. |
| Aide-8 | Compte du **Niger** | Hub : **aucune** ligne ; **une** carte « Besoin d'y voir plus clair ? » au bouton « Parler à un conseiller des autres options ». **Nulle part** dans l'espace un texte « démarrer l'étude de ton dossier ». Le message prérempli dit que la procédure est suspendue « dans mon pays » (sans le nommer) et demande les autres options. Même libellé neutre dans le catalogue (vide, non publié, sous les résultats). |
| Aide-9 | **Pas de double carte** | Sur chaque écran (hub ; catalogue : liste, vide, non publié) il y a **au plus une carte pleine** à la fois — la phrase « Un accompagnement n'est pas une garantie… » n'apparaît qu'une fois. Seule la ligne de procédure du catalogue peut s'y ajouter. |
| Aide-10 | Aucune impasse | Sans WhatsApp installé : le toast « Impossible d'ouvrir WhatsApp… » s'affiche (jamais un bouton muet). |
| Aide-11 | Texte agrandi (×1,3, petit Android) | Le libellé du bouton passe à la ligne, **jamais coupé par « … »** ; rien ne déborde, y compris sous le bandeau de suspension. |
| Aide-12 | Analytique | PostHog → Activity, filtré sur l'identifiant du compte de test (Android : aussi Firebase DebugView, `adb shell setprop debug.firebase.analytics.app com.karatou.android`). Un tap → `eef_help_cta_tapped` (`help_step`, `surface`, `variant`) puis `whatsapp_handoff` (`source` = `eef_help_<étape>`) ; `eef_help_card_shown` une fois par étape et par visite ; **aucune autre propriété**. |
| Aide-13 | Écrans inchangés | Compte parent (« Un espace pour les étudiants ») et vitrine : **pas** de carte d'aide (le bouton conseiller de l'écran étudiants-seulement existait déjà). |
| Aide-14 | Messages du catalogue | « (étape : choix de ma formation) », « (étape : recherche de formation sans résultat) », « (étape : procédure d'une formation) » ; numéro +33 7 68 67 42 92 ; sur iPhone **et** Android |
| Aide-15 | Niger, catalogue | Filtre « Parcoursup » → **pas** de ligne de procédure ; message « La procédure est suspendue dans mon pays : j'aimerais parler des autres options d'études. » |
| Aide-16 | Niger, anglais | « Need a clearer picture? », « Talk to an advisor about other options », « The procedure is suspended in my country… » |
| Aide-17 | Petit iPhone, ×1,3 | Comme Aide-11, sur iPhone SE |

## C. Budget de performance (LIV-38)

Sur l'appareil de référence (un Android d'entrée de gamme, ~2 Go de RAM, avec la
build Play Internal), à remplir dans `docs/STORE_READINESS.md` (§ budget, quatre
lignes « _TBD_ ») :

- **Taille de l'APK et taille livrée de l'AAB** (l'AAB du CI) :
  ```bash
  java -jar bundletool-all.jar build-apks --bundle=app-release.aab --output=kpb.apks
  java -jar bundletool-all.jar get-device-spec --output=dev.json
  java -jar bundletool-all.jar get-size total --apks=kpb.apks --device-spec=dev.json
  ```
  À recouper avec Play Console → Explorateur d'app bundle → taille de téléchargement.
- **Démarrage à froid**, moyenne de 5 :
  ```bash
  adb shell am force-stop com.karatou.android; sleep 3
  adb shell am start -W -n com.karatou.android/.MainActivity | grep TotalTime
  ```
- **Octets d'une session** (ouvrir l'app, parcourir, un tour de coach) : Wi-Fi
  coupé, lire Réglages → Applis → KPB Education → données mobiles avant et après.
  En état A le catalogue n'est pas atteignable : ne pas l'inclure.

## D. Signature

Appareils (modèle + OS), build soumise (numéro, source : TestFlight / Play
Internal), date, et ce qui a échoué. Un ✗ non résolu bloque la soumission.
