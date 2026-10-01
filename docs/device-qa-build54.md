# Fiche de QA appareil — build 54 (`2.3.0`)

> **Pour qui.** Le propriétaire, sur **un iPhone et un Android physiques**, avec la
> **build soumise** (TestFlight / Play Internal) — pas un build de debug : le
> contrat de soumission exige que la preuve vienne de l'artefact, et que
> l'installation soit bien celle qu'on envoie. Complète
> `docs/phase1-stability-smoke-checklist.md` (le smoke « every release candidate »,
> toujours exigé) ; ne le remplace pas. Modèle : `docs/device-qa-build49.md`.
>
> **Ce que la prod ne permet PAS de tester** : la liste et la pagination du
> catalogue (aucun établissement publié) ni les logos (aucun établissement actif
> n'en a). Pour cela, voir le §B (recette locale).

## A. Sur la build soumise, contre la production

Cocher, noter l'appareil et l'heure. Un ✗ s'écrit avec ce qu'on a vu.

| # | À vérifier | Attendu | iPhone | Android |
|---|---|---|---|---|
| A1 | Version | TestFlight / Play Store (ou réglages du téléphone → KPB Education) affichent `2.3.0 (54)` ; `GET /api/config/app` → `minVersion` strictement inférieure. *L'app n'affiche pas sa version : c'est un manque connu, à ajouter au profil si le support en a besoin.* | ☐ | ☐ |
| A2 | Vitrine, pays hors Niger | Accueil → carte « Études en France » → « À partir du 1er octobre 2026 », **sans compte à rebours** le jour J et après ; lien « Voir la plateforme officielle » qui s'ouvre | ☐ | ☐ |
| A3 | Vitrine, compte du **Niger** | La mise en garde **remplace** la date ; lien « Voir la source officielle » (page de l'ambassade) ; aucune date | ☐ | ☐ |
| A4 | Déclaration d'intérêt | « Ça m'intéresse » → niveaux, **domaines** (12 puces, préremplies depuis le profil), consentement affiché avant « Valider » → « C'est noté » ; l'admin voit la ligne | ☐ | ☐ |
| A5 | Retrait | « Me retirer de la liste » → confirmation → retiré ; la ligne disparaît de l'admin | ☐ | ☐ |
| A6 | Compte **parent** par lien profond `kpb://etudes-en-france` | « Un espace pour les étudiants », bouton conseiller ; pas de vitrine ni de hub | ☐ | ☐ |
| A7 | **Invité** | La vitrine s'ouvre ; « Créer mon compte » à la place de la déclaration | ☐ | ☐ |
| A8 | Fiche d'un établissement (Explorer) | **Plus de jauge verte « 85 % »** | ☐ | ☐ |
| A9 | Notification « récit de la semaine » reçue **app tuée** | Le tap ouvre le **récit** (pas l'accueil) — #284 | ☐ | ☐ |
| A10 | Étiquettes OneSignal (tableau OneSignal) | `level` en clé normalisée ; `target_country` **absent** quand il est vide — #286 | ☐ | ☐ |
| A11 | Réception réelle d'une notification | Reçue sur l'appareil (APNs production / FCM) | ☐ | ☐ |
| A12 | Conditions / Confidentialité | « Dernière mise à jour : septembre 2026 » ; plus de « espace communautaire » dans la liste des services | ☐ | ☐ |
| A13 | Mise à jour **forcée** (porte de version) | Avec `KPB_MIN_APP_VERSION` temporairement au-dessus : l'écran bloquant s'affiche, **avec un bouton conseiller** ; revenir à `0.0.0` après | ☐ | ☐ |
| A14 | Bandeau **doux** de mise à jour | Avec `recommended-version-set` (une valeur > installée) : bandeau fermable sur l'accueil, lien du store ; fermé, il ne revient pas dans la session | ☐ | ☐ |
| A15 | En-têtes de version | Dans les journaux du serveur : `X-KPB-App-Version: 2.3.0`, `X-KPB-App-Build: 54` sur les requêtes de la 54 | ☐ | — |
| A16 | Texte agrandi (réglages d'accessibilité au maximum) | Vitrine, catalogue, hub : rien de coupé, rien qui déborde | ☐ | ☐ |
| A17 | Hors ligne | Avion : l'accueil reste utilisable ; le catalogue dit « Pas de connexion », pas « aucune formation » | ☐ | ☐ |
| A18 | Signalement IA | Un signalement depuis le **coach**, un depuis l'**orientation**, avec leurs références de dossier (preuve exigée par le contrat §5) | ☐ | ☐ |

## B. Recette du hub et du catalogue (build lancée avec l'espace ouvert)

Le hub est derrière `features.eefSpace`, éteint en production. Pour le voir sur un
appareil **sans l'allumer pour tout le monde** :

1. Lancer l'app depuis Xcode / Android Studio avec la constante de compilation :
   ```bash
   flutter run --dart-define=KPB_EEF_SPACE_ENABLED=true
   ```
   (c'est le repli de compilation de `AppConfig.eefSpaceEnabled` ; le serveur,
   lui, répond `eefSpace: false` — **la valeur servie prime sur le repli**, donc
   pour un appareil connecté à la prod il faut en plus une des deux voies
   suivantes).
2. **Voie 1 — backend local** : démarrer le backend en local avec
   `KPB_EEF_SPACE_ENABLED=true`, un catalogue importé et un établissement publié
   (`npm run eef:import` puis la publication admin), et lancer l'app avec
   `--dart-define=KPB_API_BASE_URL=http://<ip-du-poste>:4000/api`.
3. **Voie 2 — prod, un instant** : `vps-ops` → `eef-space-on` (voir
   `docs/runbook-ouverture-espace-reel.md` ; exige un établissement publié). À ne
   faire qu'avec l'accord du propriétaire : c'est l'ouverture elle-même.

Puis, sur le hub :

| # | À vérifier | Attendu |
|---|---|---|
| B1 | Héros | « Prépare ta candidature aux universités françaises » ; le corps dit où se dépose la candidature ; date ou mise en garde selon le pays |
| B2 | Tuiles | Formations, CV, Lettres, Entretien, Conseiller : **chacune ouvre un écran qui marche** ; aucune mention « en préparation » |
| B3 | Catalogue | Recherche par nom d'université / sigle / ville (sans accents) ; filtres Niveau et Procédure avec compteurs ; chaque carte nomme l'université, la ville, la procédure |
| B4 | Cas vide | Recherche sans résultat → « Aucune formation ne correspond » + « Tout effacer » **qui vide aussi le champ** |
| B5 | Catalogue non publié | (base sans publication) « Le catalogue arrive », **sans** « Tout effacer » |
| B6 | Panne | Réseau coupé → « Pas de connexion » ; une page suivante qui échoue **garde la liste** et propose « Réessayer » |
| B7 | Pied de page | Fin de liste : « Données : Ministère de l'Enseignement supérieur et de la Recherche (…). Licence Ouverte 2.0. Actualisées le … » + non-affiliation + lien ; la rangée « Sources des données et mentions » ouvre la même feuille à tout moment |
| B8 | Profil | « Mon profil Études en France » : Compléter → déclaré ; Modifier (domaines) **ne redemande pas le consentement** ; Me retirer fonctionne |
| B9 | Outils IA | CV / lettres / entretien : invité → mur de conversion ; étudiant sans consentement IA → dialogue de consentement |
| B10 | Logos (recette seulement) | Dans la fiche d'un établissement qui en a un : logo **et** crédit de licence ; un logo SVG qui ne charge pas ne casse pas la fiche (MISS-01) |

## C. Budget de performance (LIV-38)

Sur l'appareil de référence, à remplir dans `docs/STORE_READINESS.md` (§ budget,
quatre lignes « _TBD_ ») : taille livrée de l'AAB, démarrage à froid (moyenne de
5), mémoire, octets réseau d'une session représentative (accueil → catalogue →
trois pages).

## D. Signature

Appareils (modèle + OS), build soumise (numéro, source : TestFlight / Play
Internal), date, et ce qui a échoué. Un ✗ non résolu bloque la soumission.
