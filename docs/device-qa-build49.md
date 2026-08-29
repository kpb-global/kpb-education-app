# QA sur appareil réel — build 2.1.0 (49)

> **Pourquoi ce document existe.** L'audit de release du 26/08 a relevé que
> « les parcours critiques sont prouvés sur appareils réels » était **faux** :
> chaque référence du dépôt était une case non cochée ou un protocole à exécuter
> (`production-launch-implementation-plan.md:453`,
> `mvp-launch-readiness-checklist.md:30`,
> `mobile-store-submission-contract.md:156`, cutover étape 10) — **aucun résultat
> enregistré**. C'est le dernier bloqueur avant soumission publique, et il ne
> pouvait pas être levé avant que la 49 soit installable. Elle l'est.
>
> **Comment s'en servir :** cocher au fur et à mesure, et écrire le constat
> observé quand il diffère de l'attendu. Une case cochée sans observation ne vaut
> rien — c'est exactement ce que ce document remplace.

**Contexte figé au moment de la rédaction (29/08/2026)**

| Élément | Valeur | Vérifié |
|---|---|---|
| Build | `2.1.0 (49)` | uploadée sur App Store Connect le 29/08 |
| Backend prod | `8f5d71ce2f57` | `GET /api/health/version` — c'est le SHA d'où la 49 est coupée |
| PostHog | **actif** (clé `phc_…` dans le binaire) | `DART_DEFINES` de l'archive |
| Drapeaux serveur | `eef`, `eefTeaser`, `successLab`, `competitionReadiness`, `aiDiagnostic` = **false** | `GET /api/config/app` |

Appareil de test : `____________________`  ·  iOS `______`  ·  Testeur : `__________`  ·  Date : `__________`

---

## A. Les deux défauts signalés en vidéo — la raison d'être de la 49

Ce sont les régressions vues par un testeur le 15/08. Ils doivent être **morts**.

- [ ] **A1 — Le verrou d'application ne boucle plus.**
  Profil → activer « Verrouiller l'app ». Mettre l'app en arrière-plan, revenir,
  déverrouiller par Face ID.
  **Attendu :** **une seule** demande d'authentification, puis usage normal.
  **Défaut d'origine :** l'overlay « Application Verrouillée » revenait toutes
  les ~1,6 s, indéfiniment (Face ID → coche verte → rescan en boucle).
  **Faire aussi :** 10 verrouillages/déverrouillages d'affilée — le compteur doit
  rester à un par départ réel.
  Constat : `______________________________`

- [ ] **A2 — Le catalogue montre toutes les bourses publiées.**
  Ouvrir le catalogue **sans filtre**, avec un profil **sans domaine renseigné**.
  **Attendu :** toutes les fiches publiées s'affichent (≈ 34 au catalogue, dont
  celles sans `relatedFieldIds`).
  **Défaut d'origine :** le filtre par domaine excluait ~9 fiches sur 10.
  Constat : `______________________________`

## B. Parcours qui ne se prouvent QUE sur appareil réel

- [ ] **B1 — Deep links `kpb://`.**
  Non testables en debug/simulateur (garde `#if DEBUG` d'`app_links`, et le
  simulateur bloque les release). Depuis Notes/Messages, ouvrir un lien
  `kpb://…`.
  **Attendu :** l'app s'ouvre sur la bonne destination (iOS 26 peut demander une
  confirmation d'ouverture — c'est normal).
  Constat : `______________________________`

- [ ] **B2 — Notifications push (OneSignal).**
  Accepter l'invite système, puis envoyer une notification de test depuis le
  tableau de bord OneSignal vers ce device.
  **Attendu :** réception ; l'ouverture mène à l'écran attendu.
  **À noter :** l'identité poussée est un UUID + 4 étiquettes — **jamais**
  l'e-mail (garde `onesignal_no_email_test.dart`).
  Constat : `______________________________`

- [ ] **B3 — Connexion Google / OAuth Supabase + e-mail OTP.**
  Les deux voies, sur appareil (le rebond `io.supabase.kpbeducation://` ne se
  vérifie pas ailleurs).
  Constat : `______________________________`

- [ ] **B4 — Renvoi WhatsApp (unique chemin de monétisation).**
  Depuis une fiche service / bourse, toucher le CTA conseiller.
  **Attendu :** WhatsApp s'ouvre **directement** (pas un détour navigateur) avec
  le message prérempli de contexte catalogue — **ni nom ni e-mail dedans**.
  Constat : `______________________________`

- [ ] **B5 — Liens externes (« Formulaire officiel », source officielle).**
  **Attendu :** ouverture dans le navigateur système. Un échec doit être
  **visible**, jamais muet.
  Constat : `______________________________`

## C. Confidentialité — ce qui est déclaré aux stores doit être vrai

- [ ] **C1 — Dictée vocale : reconnaissance locale, repli sur accord explicite.**
  Tunnel de dossier → étape message → dicter.
  **Attendu :** transcription sans dialogue si le local est disponible. Si le
  local échoue, un **dialogue d'accord** apparaît **avant** tout envoi au service
  de la plateforme — refuser doit annuler la dictée, pas basculer en silence.
  Constat : `______________________________`

- [ ] **C2 — « Analyse d'usage » coupe les TROIS collecteurs.**
  Profil → couper l'interrupteur.
  **Attendu :** plus aucun événement dans **PostHog** ni **Firebase**, et les
  rapports Crashlytics non envoyés sont purgés. Réactiver rétablit.
  **Vérification externe :** tableau de bord PostHog (projet 519294) — l'absence
  d'événements après coupure est la preuve.
  Constat : `______________________________`

- [ ] **C3 — PostHog reçoit bien (la clé est dans ce binaire).**
  Naviguer 2-3 minutes avec l'analyse **activée**.
  **Attendu :** événements + **session replay** visibles dans PostHog, avec
  **textes et images masqués**. Si le replay manque : le tout premier lancement
  d'un process n'enregistre jamais (cache de config vide) — refaire un démarrage
  à froid avant de conclure.
  Constat : `______________________________`

- [ ] **C4 — Export et suppression de compte.**
  Profil → « Mes données » → exporter, puis supprimer (**compte de test**).
  **Attendu :** export JSON partagé via la feuille iOS ; suppression immédiate,
  reconnexion impossible.
  ⚠️ **Réserve connue :** la purge des résidus (`CounsellorReview`, registre
  ambassadeur, contact Mautic — PR #246) est **mergée mais PAS déployée**
  (prod = `8f5d71ce2f57`, du 26/08). Ce test valide donc le comportement
  **d'avant** la purge. À rejouer après le prochain déploiement backend.
  Constat : `______________________________`

## D. Masquages de la 49 (ce qui ne doit PAS apparaître)

- [ ] **D1 — Les 4 outils IA sont absents** de la boîte à outils. Le **scanner de
  documents doit rester présent** (masquage M2 le garde ouvert, aucun appel
  réseau).
  Constat : `______________________________`

- [ ] **D2 — Aucun téléversement de pièces** dans le tunnel : l'étape documents
  est remplacée par un renvoi WhatsApp.
  Constat : `______________________________`

- [ ] **D3 — Aucun espace Communauté / forum** (5 onglets, pas de Communauté).
  Constat : `______________________________`

- [ ] **D4 — Signalement de contenu IA disponible** sur une réponse du coach et
  sur une explication d'orientation (exigence de classification d'âge). Le
  formulaire doit confirmer avec une référence de dossier — pas un renvoi
  WhatsApp.
  **À conserver :** les 2 références de dossier produites, comme preuve
  opérationnelle pour la soumission.
  Constat : `______________________________`

- [ ] **D5 — Orientation : le questionnaire aboutit** et affiche des
  recommandations. Sans consentement IA, elles viennent du **moteur local** et un
  non-fatal `submitOrientation` apparaît dans Crashlytics : **c'est attendu, pas
  une panne.** Si rien ne s'affiche, lire l'erreur — ce n'est pas la garde.
  Constat : `______________________________`

## E. Non testable pour l'instant — et pourquoi

- [ ] **E1 — Vitrine « Études en France ».** L'étape 10 du cutover en fait sa
  preuve principale, mais `GET /api/config/app` renvoie **`eefTeaser: false`** au
  29/08 : la vitrine est **éteinte côté serveur**. Rien à observer tant que
  l'étape 9 bis (`KPB_EEF_TEASER_ENABLED=true` + `KPB_EEF_CAMPAIGN_OPENS_AT` +
  `KPB_EEF_SUSPENDED_COUNTRIES=Niger,NE`) n'est pas appliquée sur le VPS.
  **À rejouer après la bascule**, avec un compte de test : la déclaration
  d'intérêt doit **confirmer à l'écran** (un 2xx ne suffit pas) et la ligne doit
  apparaître dans `/etudes-en-france` du back-office. Avec un profil **Niger**,
  la mise en garde doit **remplacer** la date, pas s'y ajouter.

- [ ] **E2 — Purge des résidus de suppression** (voir C4) : après déploiement de
  #246.

---

## Verdict

- [ ] **Aucun défaut P0/P1 ouvert** → la case « parcours critiques prouvés sur
  appareils réels » peut enfin être cochée dans
  `mobile-store-submission-contract.md:156`,
  `mvp-launch-readiness-checklist.md:30` et
  `production-launch-implementation-plan.md:453`.

Défauts relevés : `______________________________________________`

Signé : `____________`  ·  Date : `____________`
