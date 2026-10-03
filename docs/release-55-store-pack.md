# Build 55 (`2.3.0`) — pack de soumission : notes de version, notes de revue, textes de fiche

> **À quoi sert ce fichier.** Tout ce qu'il faut *coller* dans les consoles pour la
> 55, au même endroit : notes de version (« Nouveautés » / « What to Test »),
> addendum aux « Notes for Review » Apple, phrases de non-affiliation pour la
> fiche Google Play, et la décision XC-03. **Il remplace
> `docs/release-54-store-pack.md`** : la 54 n'a jamais été envoyée aux boutiques
> (constat du 03/10/2026), la 55 la remplace et en porte tout le contenu. Il
> complète `docs/store-listing-copy.md` (textes de fiche, encore titré « build 49 »
> et dont le §3 « interdits durs » est **périmé** : les quatre outils IA (CV,
> lettres, entretien, relecture) sont actifs depuis la 52, `aiToolsEnabled` vaut
> `true` par défaut) et `docs/CONSOLE_ANSWERS.md` (réponses aux formulaires de
> confidentialité). En cas de contradiction avec `store-listing-copy.md` §3, **ce
> fichier et `CONSOLE_ANSWERS.md` font foi.**
>
> **Règle qui gouverne tout le reste** (`store-listing-copy.md`, en-tête
> « Règle appliquée à chaque phrase ») : *toute fonctionnalité vantée doit être
> atteignable le jour de l'approbation.* La 55 part **espace fermé** : les notes de
> version ne citent donc **ni le hub, ni le catalogue, ni les filtres, ni les aides à
> la demande de dossier**. Elles ne disent que ce qu'un utilisateur voit.
>
> **Rien de ce qui suit ne s'envoie sans le feu vert explicite du propriétaire** :
> ce fichier prépare des textes, il ne soumet rien.

---

## 1. Ce que l'utilisateur voit le jour de l'approbation — la décision XC-03

La 55 embarque le hub de l'espace « Études en France » (catalogue, filtres, aides à la
demande de dossier, profil) **derrière `features.eefSpace`**, une clé que seul le
serveur peut allumer. **Décision XC-03 : état A, espace éteint** (`eefSpace=false`),
retenue le 03/10/2026 : la 55 part espace fermé, et l'ouverture est une opération
serveur séparée (`docs/runbook-ouverture-espace-reel.md`), sans nouvelle soumission.

| | **A. Espace éteint** (`eefSpace=false`) — **retenu** |
|---|---|
| Ce que voit un utilisateur de la 55 | La **vitrine de la 53** (déclaration d'intérêt gratuite) — avec en plus ses liens vers les sources officielles, le sélecteur de domaines dans la déclaration et, à confirmer à la recette, un lien « Me retirer » dans la feuille (seulement après une première déclaration) — plus les correctifs du §2 |
| Ce que voit le relecteur Apple | La vitrine — **et il doit être prévenu** que l'espace réel s'active à distance (guideline 2.3.1) : §3 |
| Condition | Aucune |
| Risque | Fonction activée après la revue : il faut la déclarer (§3) |

Pourquoi A : l'ouverture attend la 55 en vente **et adoptée** (`docs/ouverture-espace-eef.md`
§ 2.3) ; l'ouvrir pendant la revue ne ferait que montrer le hub au relecteur, sans public.
Les corrections de procédure sont en production (appliquées le 02/10) et le juridique est
tranché (03/10), mais aucune build des boutiques ne contient encore le hub.

> **L'état B (espace allumé à l'approbation) n'est pas rédigé ici.** S'il était choisi un
> jour, les notes seraient à réécrire pour la 55 (hub, catalogue, filtres, aides) : ne pas
> reprendre le §2.2 du pack de la 54, écrit pour une build qui n'a pas existé. « A » et « B »
> désignent ici l'état de l'espace (éteint / allumé), et non la décision du 03/10 d'envoyer une
> seule build (« option B » dans l'échange avec le propriétaire).

> Le catalogue est déjà lisible sans compte par l'API publique
> (`/etudes-en-france/search`), même espace fermé : aucune build ne l'affiche, mais
> il n'est pas secret.

---

## 2. Notes de version

Ne dire que ce qu'un utilisateur *voit*. **Ne citer ni le catalogue, ni les filtres, ni le
hub, ni les aides à la demande de dossier** : ils sont derrière un drapeau éteint — le dire
serait vanter une fonction inatteignable (guidelines 2.3.1 / 2.3.3). **Les logos
d'établissements** sont un cas à part : la carte du catalogue n'en dessine pas, mais la fiche
d'un établissement d'Explorer (hors drapeau) en dessine un, avec son crédit de licence, quand
l'établissement en a un (#281) ; aucun des 69 établissements servis n'en avait le 03/10, donc
rien à citer aujourd'hui (ligne « logos » du §2.2).

> **Ces notes reprennent celles de la 54, à l'identique.** Elles couvrent #287 (plus aucun
> pourcentage d'admission) et #288 (délai IA de 90 s), intégrées par #302 le 01/10, et
> tout ce que le registre attribue à la 55 comme **visible hors drapeau** — vérifié dans
> `docs/release-ledger.md` (« Ce que 55 embarque »), voir le tableau du §2.2. Les filtres
> (#314) et les aides à la demande de dossier n'y ajoutent rien de visible : ils vivent
> derrière `eefSpace`.

### 2.1 État A — espace éteint (retenu)

**App Store — « Nouveautés » (FR)**

```
• Notifications plus fiables : un récit de la semaine reçu en notification ouvre désormais directement ce récit.
• Le profil se synchronise correctement même quand l'adresse e-mail est manquante.
• Plus aucun pourcentage d'admission : universités, comparaison et fiches montrent désormais un niveau de « match » calculé à partir de ton profil (Très bon match, Bon match, À explorer).
• Lettres de motivation, CV et entretien : la génération par l'IA a le temps d'aboutir, et un message clair s'affiche quand elle prend plus de temps que prévu.
• Textes légaux mis à jour (septembre 2026).
• Améliorations de stabilité.
```

**App Store — « What's New » (EN)**

```
• More reliable notifications: a weekly story received as a notification now opens that story directly.
• Your profile now syncs correctly even when the email address is missing.
• No more admission percentages: universities, comparison and programme pages now show a "match" level computed from your profile (Great match, Good match, Worth exploring).
• Motivation letters, CV and interview: AI generation now has time to finish, and a clear message appears when it takes longer than expected.
• Legal texts updated (September 2026).
• Stability improvements.
```

**Google Play — « Notes de version » (≤ 500 caractères par langue)**

```
<fr-FR>
• Notifications plus fiables : un récit reçu en notification s'ouvre directement.
• Synchronisation du profil corrigée quand l'e-mail est manquant.
• Plus de pourcentage d'admission : un niveau de « match » calculé sur ton profil.
• IA (lettres, CV, entretien) : la génération a le temps d'aboutir.
• Textes légaux mis à jour (septembre 2026).
</fr-FR>
<en-US>
• More reliable notifications: a story received as a notification opens directly.
• Profile sync fixed when the email is missing.
• No more admission percentages: a "match" level computed from your profile.
• AI (letters, CV, interview): generation now has time to finish.
• Legal texts updated (September 2026).
</en-US>
```

### 2.2 Ce que le registre dit des changements visibles depuis la 53

Relevé sur `docs/release-ledger.md` (« Ce que 55 embarque »), pour que les notes ne
taisent rien de ce qu'un utilisateur voit à l'approbation, espace éteint :

| Changement visible depuis la 53 | Où | Dans les notes ? |
|---|---|---|
| Plus aucun pourcentage d'admission ; palier « match profil » absent sans profil | Explorer, Universités, Comparer, fiche formation, carte partageable | Oui |
| Délai IA de 90 s ; « plus long que prévu » au lieu de « vérifiez votre connexion » | CV, lettres, entretien, relecture, orientation | Oui |
| Un récit de la semaine reçu en notification ouvre le récit (#284) | Notification | Oui |
| Synchronisation du profil quand l'e-mail manque (#291) | Profil | Oui |
| Dernière mise à jour « septembre 2026 » ; « Un espace communautaire » retiré des CGU | Politique, CGU | Oui (« Textes légaux mis à jour ») |
| Puce de ville du Logement lisible (#287) | Logement | Non : détail de lisibilité |
| Logos d'établissements avec crédit de licence « Logo · licence · Wikimedia Commons » (#281, MISS-01), embarqués depuis la 53 | Explorer, fiche d'un établissement — **seulement si l'établissement a un `logoUrl`** | Non aujourd'hui : `GET /catalog/institutions` ne servait aucun logo le 03/10 (0 établissement sur 69). **Décision du propriétaire** : à citer si un établissement servi en reçoit un avant la soumission |
| Sélecteur de **domaines** (12 puces, préremplies depuis le profil) dans la feuille de déclaration | Vitrine → « Ça m'intéresse » | Non — ligne facultative A ci-dessous |
| Liens vers la plateforme officielle et vers la source de la suspension ; mention de non-affiliation | Vitrine | Non — ligne facultative A |
| Lien « Me retirer » dans la feuille de déclaration (décision juridique du 03/10) | Vitrine → « Modifier ma réponse », **après** une première déclaration (la feuille de la première déclaration n'a pas le lien) | Non — ligne facultative B, au conditionnel, **à confirmer à la recette** (Aide-39 et Aide-42 de `docs/device-qa-build55.md` ; la feuille est ouverte par la vitrine : `eef_teaser_screen.dart`) |
| Parents et partenaires arrivés par lien `/etudes-en-france` : « Un espace pour les étudiants » (au lieu de la vitrine puis d'un 403) | Lien profond | Non |
| Bandeau « une mise à jour est disponible » | Accueil, **seulement si** le serveur pose `recommendedVersion` : pas posé aujourd'hui | Non (inatteignable) — déclaré dans l'addendum du §3 |
| En-têtes `X-KPB-App-Version` / `X-KPB-App-Build`, étiquettes OneSignal normalisées | Invisible | — |

Aucun autre changement visible hors drapeau n'est consigné au registre pour la 55 : les
filtres (#314) et les aides à la demande de dossier sont derrière `eefSpace`. **Lignes
facultatives** — à ajouter en tête des notes **seulement** si le propriétaire veut les
citer ; elles sont vraies en état A :

*Ligne A (domaines et lien officiel)* — FR :

```
• Déclaration d'intérêt « Études en France » : tu peux préciser les domaines qui t'intéressent, et un lien mène à la plateforme officielle.
```

EN :

```
• "Études en France" interest form: you can now say which fields you are interested in, and a link leads to the official platform.
```

*Ligne B (retrait)* — **seulement si la recette confirme que « Modifier ma réponse » rouvre la
feuille avec le lien** (Aide-42) ; il n'est visible que pour un étudiant qui a déjà déclaré son
intérêt, d'où le conditionnel — FR :

```
• Si tu as déjà répondu, tu peux te retirer de la liste d'intérêt « Études en France » directement depuis le formulaire.
```

EN :

```
• If you have already answered, you can withdraw from the "Études en France" interest list directly from the form.
```

Ces phrases ne promettent ni admission, ni visa, ni prix.

### 2.3 TestFlight — « What to Test » (testeurs internes : tout ce qui existe)

Pour des testeurs **internes**. Si la build est ouverte à des testeurs externes, appliquer
la règle du pack : n'y citer ni le hub, ni le catalogue, ni les filtres, ni les aides.

```
FR — Build 55 (2.3.0)
À tester en priorité :
1. Notification « récit de la semaine » reçue app fermée : elle doit ouvrir le récit (pas l'accueil).
2. Fiche d'un établissement (Explorer), Universités, Comparer : plus aucun « % » ; un badge « Très bon match / Bon match / À explorer » si le profil est rempli, rien sinon.
3. Lettres → « Adapter à mon profil » : la personnalisation aboutit (jusqu'à 90 s) ; si elle tarde, le message parle de durée, pas de connexion.
4. Accueil → carte « Études en France » : la vitrine s'affiche, la date « 1er octobre 2026 » sans compte à rebours ; pour un compte au Niger, la mise en garde remplace la date, avec un lien vers la source officielle.
5. Vitrine → « Ça m'intéresse » : niveaux, domaines, consentement affiché avant « Valider ».
6. Profil → Conditions / Confidentialité : « Dernière mise à jour : septembre 2026 ». Plus de « espace communautaire » dans les CGU.
Hub de l'espace : INVISIBLE sur TestFlight tant que `eefSpace` est faux en production (le serveur l'emporte sur le réglage de compilation). Recette du hub : docs/device-qa-build54.md §B, §B-filtres et §B-aide (catalogue, filtres Niveau / Domaine / Ville / Procédure, « médecine » → PASS/L.AS avec badge « Accès santé », profil Modifier / Me retirer, cartes « C'est flou ? » vers WhatsApp, Niger) ; nouveautés de la 55 (aides à la demande de dossier, retrait, Niger, anglais) : docs/device-qa-build55.md.
```

```
EN — Build 55 (2.3.0)
Please test first:
1. "Weekly story" notification received with the app closed: it must open the story (not the home screen).
2. Institution page (Explore), Universities, Compare: no "%" anywhere; a "Great match / Good match / Worth exploring" badge when the profile is filled in, nothing otherwise.
3. Letters → "Adapt to my profile": personalisation completes (up to 90 s); if it is slow, the message talks about time, not connection.
4. Home → "Études en France" card: the showcase appears with "1 October 2026" and no countdown; for an account in Niger the warning replaces the date, with a link to the official source.
5. Showcase → "I am interested": levels, fields, consent shown before "Confirm".
6. Profile → Terms / Privacy: "Last updated: September 2026". No more "community space" in the Terms.
Space hub: INVISIBLE on TestFlight while `eefSpace` is false in production (the server overrides the compile-time setting). Hub test plan: docs/device-qa-build54.md §B, §B-filtres and §B-aide (catalogue, Level / Field / City / Procedure filters, "médecine" → PASS/L.AS with "Health studies access" badge, profile Edit / Remove me, "Unclear?" WhatsApp help cards, Niger); what is new in build 55 (application-help buttons, withdrawal, Niger, English): docs/device-qa-build55.md.
```

---

## 3. Addendum aux « Notes for Review » Apple (LIV-04 + XC-03)

À ajouter à la fin du bloc de `store-listing-copy.md` §7.1. **Texte à coller en
anglais** (les relecteurs lisent l'anglais) :

```
REMOTELY ACTIVATED FEATURE (guideline 2.3.1) — "Études en France" space.
This version adds a section to prepare an application to French public universities: a programme catalogue with filters, and "ask for help" buttons that open WhatsApp to a KPB advisor with a prefilled message naming what the student was looking at (programme, university, city, filters or tool) — never their name, email, phone or country name. The section is switched on from our server (flag eefSpace in api.kpbeducation.cloud/api/config/app) and is OFF at review time: the reviewer sees the "coming soon" showcase and a free "I am interested" form. No new permission, SDK or data type. Also remote: a dismissible "update available" banner (recommendedVersion, unset now).

NOT AFFILIATED WITH ANY GOVERNMENT. KPB Education is a private guidance service, not affiliated with Campus France or any French administration, and does not process applications. The demo account is a test account: its declarations are excluded from our advisors' call lists.
```

**À contrôler avant de coller** (le texte décrit la build finale ; les aides au dossier, #315, sont
fusionnées depuis le 03/10 : relire ces points sur le SHA à archiver) :

1. « a prefilled message naming what the student was looking at (programme, university, city,
   filters or tool) — never their name, email, phone or country name » : relevé sur la branche
   d'aide le 03/10 (`EefHelpMessages`, `lib/app/features/etudes_en_france/eef_help_line.dart`) —
   le bouton d'une formation cite son intitulé (80 caractères au plus), l'université et la
   ville ; la ligne sous les filtres cite les filtres posés (trois valeurs par famille au
   plus) ; l'aide d'un outil cite l'outil ; les cartes du hub, elles, nomment l'étape
   (`docs/device-qa-build54.md` Aide-2, Aide-3, Aide-14). Pour un compte dont le pays est
   suspendu, le message dit que la procédure est suspendue « dans mon pays » **sans nommer le
   pays**. **À vérifier sur le SHA final** (`docs/device-qa-build55.md`, Aide-19 à Aide-31) ; si
   un message porte autre chose (nom, e-mail, téléphone, pays), réécrire la phrase.
2. Le lien « Me retirer » n'est **pas** cité dans le texte : la feuille de déclaration ne
   l'affiche qu'à un étudiant qui a déjà déclaré son intérêt (« Modifier ma réponse » ;
   Aide-39, Aide-40, Aide-42), pas à un relecteur qui l'ouvre pour la première fois. Ne pas
   remettre « which also offers a link to withdraw » sans cette restriction.
3. « No new permission, SDK or data type » : à vérifier sur le SHA final avec les commandes de
   l'étape 0, point 5, de `docs/mise-a-jour-55-checklist.md` (dépendances, manifestes), et sur les
   nouveaux événements d'analytique, qui ne doivent porter que des comptes et des
   identifiants fermés (`docs/analytics-event-contract.md`). Au 03/10, le commit de la branche
   (`93a823c`) ne touche ni `pubspec.*`, ni `ios/`, ni `android/` ; un dossier de travail
   peut pourtant les modifier (étape 0, point 5).
4. **Longueur.** Le champ *Notes for Review* est limité à 4 000 caractères (à vérifier à la
   saisie dans App Store Connect). Mesuré le 03/10 : le bloc de `store-listing-copy.md` §7.1
   fait 2 923 caractères (marqueurs `<ADRESSE>` et `<MÉTHODE…>` non remplacés), l'addendum
   ci-dessus 1 025, soit 3 950 avec la ligne vide qui les sépare — il reste une cinquantaine de
   caractères pour l'adresse du compte de démonstration et la méthode de lecture du code.
   **Compter le texte final avant de coller.** S'il dépasse, raccourcir d'abord le bloc §7.1
   (par exemple ses paragraphes « AI FEATURES » ou « NO IN-APP PURCHASE » : décision du
   propriétaire), puis la phrase du bandeau de mise à jour ; **jamais** la déclaration
   d'activation à distance. (L'addendum de la 54, 1 903 caractères, aurait fait 4 828 avec le
   même bloc.) **Retiré de l'addendum de la 54 pour tenir** : l'attribution des données
   (Licence Ouverte 2.0), le lien vers les canaux officiels, les sources des dates et des
   suspensions, la phrase sur le compte étudiant et les parents. Ces mentions sont dans
   l'app (pied de page du catalogue, vitrine) et dans la fiche Google Play (§4) ; à remettre
   si le décompte final le permet.

> L'addendum de la 54 ne mentionnait pas le bandeau de mise à jour : ajouté ici parce que
> c'est une seconde activation à distance, même bénigne (guideline 2.3.1).

**Compte de démonstration** : inchangé (`store-listing-copy.md` §7.1). Prévoir un
compte **étudiant** (le hub n'est pas montré à un parent). La dernière phrase de
l'addendum ci-dessus dit aux relecteurs que ses déclarations d'intérêt ne sont pas
rappelées : **exclure réellement ce compte de toute liste d'appel** (admin → liste
d'intérêt), sinon la phrase est fausse.

---

## 4. Google Play — mention de non-affiliation et source officielle (XC-04)

La politique Play « Requirements for apps that communicate government
information » exige, dans la description et la fiche : **des sources bien
visibles** et **la mention claire que l'app ne représente aucune entité
gouvernementale**. À ajouter à la fin des descriptions longues FR et EN
(`store-listing-copy.md` §5.1 / §6.1) :

**FR**
```
KPB Education est un service privé d'accompagnement. Il n'est affilié ni à Campus France, ni à l'État français, ni à aucune administration, et ne représente aucune entité gouvernementale. Les candidatures se déposent auprès des services officiels, selon la procédure de chaque formation (plateforme Études en France, demande d'admission préalable) : https://www.campusfrance.org/fr — les dates et suspensions affichées dans l'app renvoient à leur source officielle.
```

**EN**
```
KPB Education is a private guidance service. It is not affiliated with Campus France, the French government or any administration, and does not represent any government entity. Applications are submitted through the official channels, depending on each programme (Études en France platform, pre-admission request): https://www.campusfrance.org/fr — dates and suspensions shown in the app link to their official source.
```

Puis, dans **Play Console → App content → Government apps** : déclarer que l'app
**n'est pas** une application gouvernementale et ne représente aucune entité
gouvernementale (réponse reportée dans `CONSOLE_ANSWERS.md` §0quater).

> **Ce que ce texte ne dit pas, exprès** : « officiel », « agréé », « partenaire de
> Campus France », « garantit l'admission ». `eef_naming_test` interdit d'ailleurs
> d'utiliser « Campus France » comme enseigne dans l'app ; la même prudence vaut
> pour la fiche.

> **Texte de la fiche Play : rien d'autre à changer pour la 55.** Ne pas y annoncer le
> catalogue, les filtres ni les aides tant que l'espace est fermé (même règle que le §2).

---

## 5. Preuves à joindre à la soumission (§5 du contrat)

À conserver avec la soumission, depuis **la build soumise** :

- captures **de la build soumise**, sans fonctionnalité éteinte côté serveur — dans l'état
  A, **ne pas capturer le hub ni le catalogue** ;
- l'archive iOS et l'AAB : sorties de `scripts/preflight-ios-archive.sh` /
  `scripts/preflight-android-aab.sh` (version `2.3.0`, build `55`) ;
- le run de **Flutter CI** (`release_android`) qui a produit l'AAB, son SHA de commit
  (= `RELEASE`) et l'empreinte SHA-256 comparée à Play Console ;
- le run de **Release preflight** (`ref` = `RELEASE`, `backend_coupling=tolerates-old`) ;
- `strings App.framework/App | grep -c '^phc_'` = **1** ; `AD_ID` absent du
  manifeste fusionné ;
- phase dSYM : « Successfully submitted symbols » ;
- les réponses au questionnaire d'âge (App Store Connect **et** IARC), les
  formulaires App Privacy / Data Safety tels que soumis ;
- deux signalements de sortie IA (un depuis le coach, un depuis l'orientation)
  avec leurs références de dossier ;
- la preuve que l'installation Play Internal / TestFlight **est** la build soumise ;
- la sortie de `curl .../api/config/app | jq '.features | {eef, eefTeaser, eefSpace}'`
  juste avant la soumission : `false`, `true`, `false` (état A).

## 6. Ce que ce pack ne tranche pas

| Question | Qui | Où |
|---|---|---|
| A ou B (espace éteint / allumé à l'approbation) | **Tranché le 03/10/2026 : A** | §1 |
| Finalités commerciales à déclarer (Marketing) | Juridique — **non tranché dans le dépôt** | `CONSOLE_ANSWERS.md` §0quater, XC-06 |
| Tranche d'âge (décision D2) | Propriétaire + juridique — **non tranché dans le dépôt** | `store-listing-copy.md` §9 |
| Phrase sur Campus France dans le héros du hub | **Validée telle quelle le 03/10/2026** (sans objet pour la fiche : le hub est éteint) | `docs/eef-consent-v1.md` |
| Lien « Me retirer » dans la feuille | **Tranché le 03/10/2026** : ajouté (texte consenti et `eef-consent-v1` inchangés) | `docs/eef-consent-v1.md`, question 2 |
| Lignes facultatives A et B du §2.2 | Propriétaire | §2.2 |
| Revue accélérée Apple | Propriétaire : l'urgence est faible en état A (l'espace reste fermé après l'approbation) ; la 54 n'ayant jamais été soumise, **aucune** revue n'est en cours | LIV-10 |
| Exclure le compte de démonstration des listes d'appel (la note de revue le promet) | Propriétaire | §3 |
| Publication après approbation : automatique ou manuelle ; publication progressive iOS (7 jours) et paliers Play 5 / 20 / 100 % | Propriétaire | `docs/mise-a-jour-55-checklist.md` §7 |
