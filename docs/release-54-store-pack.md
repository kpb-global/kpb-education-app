# Build 54 (`2.3.0`) — pack de soumission : notes de version, notes de revue, textes de fiche

> **⚠️ 03/10/2026 — pack de la 54, jamais soumise.**
>
> La build 54 n'a **jamais été envoyée aux boutiques**. Les captures de App Store
> Connect (TestFlight → Build Uploads) et de Google Play Console montrées le 03/10/2026
> ne la contiennent pas : dernier envoi iOS `2.2.0 (53)` du 04/09, dernier bundle Android
> 53 / 2.2.0 (importé le 04/09, en production depuis le 11/09). Décision du propriétaire
> du 03/10 : on envoie **une seule build, `2.3.0 (55)`**, qui remplace la 54 et en
> porte tout le contenu.
>
> Pour la 55, **coller les textes de `docs/release-55-store-pack.md`**, pas ceux-ci. Ce pack
> reste comme historique : la décision XC-03 (état A, espace éteint) et les notes sur la fin
> des pourcentages d'admission et le délai IA sont reprises dans le pack de la 55 ; ce qui
> change, c'est le numéro et ce qui s'y ajoute.

> **À quoi sert ce fichier.** Tout ce qu'il faut *coller* dans les consoles pour la
> 54, au même endroit : notes de version (« Nouveautés » / « What to Test »),
> addendum aux « Notes for Review » Apple, phrases de non-affiliation pour la
> fiche Google Play, et la décision XC-03. Il complète
> `docs/store-listing-copy.md` (textes de fiche, encore titré « build 49 » et dont
> le §3 « interdits durs » est **périmé** : les quatre outils IA (CV, lettres, entretien, relecture) sont actifs depuis
> la 52, `aiToolsEnabled` vaut `true` par défaut) et `docs/CONSOLE_ANSWERS.md`
> (réponses aux formulaires de confidentialité). En cas de contradiction avec
> `store-listing-copy.md` §3, **ce fichier et `CONSOLE_ANSWERS.md` font foi.**
>
> **Règle qui gouverne tout le reste** (`store-listing-copy.md`, en-tête
> « Règle appliquée à chaque phrase ») : *toute fonctionnalité vantée doit être
> atteignable le jour de l'approbation.* Les textes
> ci-dessous sont donc écrits pour **l'état réel de la 54 à l'approbation**, qui
> dépend de la décision du §1.

---

## 1. Ce que l'utilisateur voit le jour de l'approbation — la décision XC-03

La 54 embarque le hub de l'espace « Études en France » **derrière
`features.eefSpace`**, une clé que seul le serveur peut allumer. Deux états
possibles à l'approbation :

| | **A. Espace éteint** (`eefSpace=false`) — **recommandé** | **B. Espace allumé** (`eefSpace=true`) |
|---|---|---|
| Ce que voit un utilisateur de la 54 | La **vitrine de la 53** (déclaration d'intérêt gratuite) — avec en plus ses liens vers les sources officielles et le sélecteur de domaines dans la déclaration — plus les correctifs du §2 | Le hub : catalogue, CV/lettres/entretien, profil |
| Ce que voit le relecteur Apple | La vitrine — **et il doit être prévenu** que l'espace réel s'active à distance (guideline 2.3.1) | Le hub, avec le catalogue (non vide : voir « Condition ») |
| Condition | Aucune | **Remplie le 01/10/2026** : 10 029 formations publiées dans 84 établissements (`eef-publish`, 473 en attente) et backend de la build en production (`33c5a51`) |
| Risque | Fonction activée après la revue : il faut la déclarer (§3) | L'espace s'ouvre à tous les utilisateurs de la 54 dès l'approbation, **avant** que les corrections de procédure soient en production (questions tranchées le 02/10, `docs/eef-dossier-relecture-procedures.md` ; appliquées par `eef-reconcile`, #305) et que le héros du hub soit validé par le juridique |

**Recommandation : A.** Le catalogue est publié (10 029 formations au 01/10/2026),
mais l'ouverture attend trois choses : les corrections de procédure en production (tranchées le 02/10, `eef-reconcile`), la validation
juridique (§6) et une 54 en vente et adoptée. La 54 part donc **éteinte**, avec la
déclaration du §3 ; l'ouverture est une opération serveur séparée
(`docs/runbook-ouverture-espace-reel.md`), sans nouvelle soumission.

> Le catalogue est déjà lisible sans compte par l'API publique
> (`/etudes-en-france/search`), même espace fermé : aucune build ne l'affiche, mais
> il n'est pas secret.

> Si le propriétaire choisit **B**, remplacer le §2.1 par le §2.2 et supprimer le
> second paragraphe du §3.

---

## 2. Notes de version

Ne dire que ce qu'un utilisateur *voit*. **Ne citer ni le catalogue, ni les
logos d'établissements, ni le hub** dans l'état A : la 54 n'affiche aucun logo (la
carte du catalogue n'en dessine pas) et le catalogue est derrière un drapeau
éteint — le dire serait vanter une fonction inatteignable (guidelines 2.3.1 /
2.3.3).

> **Ces notes couvrent #287 et #288**, intégrées à la 54 par #302 (fusionnée le
> 01/10) : plus aucun pourcentage d'admission ; délai IA de 90 s. À coller telles
> quelles.

### 2.1 État A — espace éteint (recommandé)

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

### 2.2 État B — espace allumé (seulement si le §1 a tranché B)

Ajouter en tête, **sans aucun chiffre** (règle « aucun nombre non prouvé »), même
avec 10 029 formations publiées :

```
• Nouveau : l'espace « Études en France » — cherche ta formation dans les universités publiques françaises, prépare ton CV, tes lettres de motivation et ton entretien, et suis ta candidature avec un conseiller KPB.
```
```
• New: the "Études en France" space — search programmes at French public universities, prepare your CV, motivation letters and interview, and follow your application with a KPB advisor.
```

**Seulement dans l'état B** (jamais dans l'état A : les cartes d'aide vivent dans le
hub et le catalogue, derrière `eefSpace` — les citer dans l'état A, ce serait vanter
une fonction inatteignable, guidelines 2.3.1 / 2.3.3), ajouter une ligne :

```
• Un doute à une étape ? Des cartes « C'est flou ? » te proposent de demander de l'aide à un conseiller KPB sur WhatsApp, avec un message déjà rédigé qui indique où tu en es.
```
```
• Not sure at some step? "Unclear?" cards let you ask a KPB advisor for help on WhatsApp, with a ready-written message that says where you are.
```

Et une ligne pour la recherche santé (état B seulement, pour la même raison) :

```
• Tu vises médecine, pharmacie, maïeutique, odontologie ou kiné ? La recherche te mène aux PASS et L.AS, signalées par un badge « Accès santé ».
```
```
• Aiming for medicine, pharmacy, midwifery, dentistry or physiotherapy? Search takes you to the PASS and L.AS first years, marked with a "Health studies access" badge.
```

Ces phrases ne promettent ni admission, ni visa, ni prix — et c'est voulu : la carte
elle-même dit qu'un accompagnement n'est pas une garantie.

### 2.3 TestFlight — « What to Test » (testeurs internes : tout ce qui existe)

```
FR — Build 54 (2.3.0)
À tester en priorité :
1. Notification « récit de la semaine » reçue app fermée : elle doit ouvrir le récit (pas l'accueil).
2. Fiche d'un établissement (Explorer), Universités, Comparer : plus aucun « % » ; un badge « Très bon match / Bon match / À explorer » si le profil est rempli, rien sinon.
3. Lettres → « Adapter à mon profil » : la personnalisation aboutit (jusqu'à 90 s) ; si elle tarde, le message parle de durée, pas de connexion.
4. Accueil → carte « Études en France » : la vitrine s'affiche, la date « 1er octobre 2026 » sans compte à rebours ; pour un compte au Niger, la mise en garde remplace la date, avec un lien vers la source officielle.
5. Profil → Conditions / Confidentialité : « Dernière mise à jour : septembre 2026 ». Plus de « espace communautaire » dans les CGU.
Hub de l'espace : INVISIBLE sur TestFlight tant que `eefSpace` est faux en production (le serveur l'emporte sur le réglage de compilation). Recette du hub : docs/device-qa-build54.md §B (catalogue, « médecine » → PASS/L.AS avec badge « Accès santé », aucun badge sur « orthophoniste », profil Modifier / Me retirer, cartes d'aide « C'est flou ? » vers WhatsApp, Niger sans carte « démarrer ton dossier »).
```
```
EN — Build 54 (2.3.0)
Please test first:
1. "Weekly story" notification received with the app closed: it must open the story (not the home screen).
2. Institution page (Explore), Universities, Compare: no "%" anywhere; a "Great match / Good match / Worth exploring" badge when the profile is filled in, nothing otherwise.
3. Letters → "Adapt to my profile": personalisation completes (up to 90 s); if it is slow, the message talks about time, not connection.
4. Home → "Études en France" card: the showcase appears with "1 October 2026" and no countdown; for an account in Niger the warning replaces the date, with a link to the official source.
5. Profile → Terms / Privacy: "Last updated: September 2026". No more "community space" in the Terms.
Space hub: INVISIBLE on TestFlight while `eefSpace` is false in production (the server overrides the compile-time setting). Hub test plan: docs/device-qa-build54.md §B (catalogue, "médecine" → PASS/L.AS with "Health studies access" badge, no badge on "orthophoniste", profile Edit / Remove me, "Unclear?" WhatsApp help cards, Niger without a "start your file" card).
```

---

## 3. Addendum aux « Notes for Review » Apple (LIV-04 + XC-03)

À ajouter à la fin du bloc de `store-listing-copy.md` §7.1. **Texte à coller en
anglais** (les relecteurs lisent l'anglais) :

```
REMOTELY ACTIVATED FEATURE — "Études en France" space.
This version contains a section that helps students prepare an application to French public universities (a searchable programme catalogue, CV / motivation-letter / interview preparation tools that already ship in the app, a profile the student can edit or withdraw at any time, and "Unclear?" cards that open WhatsApp to a KPB advisor with a prefilled message containing no personal data). It is switched on from our server (feature flag `eefSpace` in GET https://api.kpbeducation.cloud/api/config/app). At the time of review the flag is OFF, so the reviewer sees the "coming soon" showcase with a free "I'm interested" form. We are declaring the remote activation here as required by guideline 2.3.1; no new permission, SDK or data type is introduced by it.

Data: the programme catalogue is derived from the French Ministry of Higher Education's open data (Parcoursup, Trouver mon master, main diplomas), published under the Licence Ouverte 2.0, and attributed in the app.

NOT AFFILIATED WITH ANY GOVERNMENT. KPB Education is a private guidance service. It is not affiliated with Campus France, the French government or any French administration, and does not process applications. Official applications are submitted through the official channels (the Études en France platform or the pre-admission procedure, depending on the programme), which the app links to (https://www.campusfrance.org/fr). Dates and country suspensions shown in the app come from official sources, linked next to each statement.

Once the space is switched on, the catalogue can be browsed without an account. A student account is required to declare interest; parents and partner accounts see a message that the space is reserved for students. The demo account is a test account: any "I'm interested" declaration made with it is excluded from our advisors' call lists.
```

> Dans l'**état B**, remplacer « At the time of review the flag is OFF… » par « At the
> time of review the flag is ON and the reviewer sees the space directly. »

**Compte de démonstration** : inchangé (`store-listing-copy.md` §7.1). Prévoir un
compte **étudiant** (le hub n'est pas montré à un parent). La dernière phrase de
l'addendum ci-dessus dit aux relecteurs que sa déclaration d'intérêt n'est pas
rappelée : **exclure réellement ce compte de toute liste d'appel** (admin → liste
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

---

## 5. Preuves à joindre à la soumission (§5 du contrat)

À conserver avec la soumission, depuis **la build soumise** :

- captures **de la build soumise**, sans fonctionnalité éteinte côté serveur —
  dans l'état A, **ne pas capturer le hub ni le catalogue** ;
- l'archive iOS et l'AAB : sorties de `scripts/preflight-ios-archive.sh` /
  `scripts/preflight-android-aab.sh` (version `2.3.0`, build `54`) ;
- `strings App.framework/App | grep -c '^phc_'` = **1** ; `AD_ID` absent du
  manifeste fusionné ;
- phase dSYM : « Successfully submitted symbols » ;
- les réponses au questionnaire d'âge (App Store Connect **et** IARC), les
  formulaires App Privacy / Data Safety tels que soumis ;
- deux signalements de sortie IA (un depuis le coach, un depuis l'orientation)
  avec leurs références de dossier ;
- la preuve que l'installation Play Internal / TestFlight **est** la build soumise.

## 6. Ce que ce pack ne tranche pas

| Question | Qui | Où |
|---|---|---|
| A ou B (espace éteint / allumé à l'approbation) | Propriétaire | §1 |
| Finalités commerciales à déclarer (Marketing) | Juridique | `CONSOLE_ANSWERS.md` §0quater, XC-06 |
| Phrase sur Campus France dans le héros du hub | Juridique | `docs/eef-consent-v1.md` |
| Tranche d'âge (décision D2) | Propriétaire + juridique | `store-listing-copy.md` §9 |
| Revue accélérée Apple : soumission **prévue le 02/10, jamais faite** (la 54 n'a jamais été envoyée ; la 55 la remplace). En état A l'espace reste fermé après l'approbation : l'urgence est faible | Propriétaire | LIV-10 |
| Exclure le compte de démonstration des listes d'appel (la note de revue le promet) | Propriétaire | §3 |
