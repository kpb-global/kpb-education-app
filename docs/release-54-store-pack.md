# Build 54 (`2.3.0`) — pack de soumission : notes de version, notes de revue, textes de fiche

> **À quoi sert ce fichier.** Tout ce qu'il faut *coller* dans les consoles pour la
> 54, au même endroit : notes de version (« Nouveautés » / « What to Test »),
> addendum aux « Notes for Review » Apple, phrases de non-affiliation pour la
> fiche Google Play, et la décision XC-03. Il complète
> `docs/store-listing-copy.md` (textes de fiche, encore titré « build 49 » et dont
> le §3 « interdits durs » est **périmé** : les trois outils IA sont actifs depuis
> la 52, `aiToolsEnabled` vaut `true` par défaut) et `docs/CONSOLE_ANSWERS.md`
> (réponses aux formulaires de confidentialité). En cas de contradiction avec
> `store-listing-copy.md` §3, **ce fichier et `CONSOLE_ANSWERS.md` font foi.**
>
> **Règle qui gouverne tout le reste** (`store-listing-copy.md`, ligne 8) : *toute
> fonctionnalité vantée doit être atteignable le jour de l'approbation.* Les textes
> ci-dessous sont donc écrits pour **l'état réel de la 54 à l'approbation**, qui
> dépend de la décision du §1.

---

## 1. Ce que l'utilisateur voit le jour de l'approbation — la décision XC-03

La 54 embarque le hub de l'espace « Études en France » **derrière
`features.eefSpace`**, une clé que seul le serveur peut allumer. Deux états
possibles à l'approbation :

| | **A. Espace éteint** (`eefSpace=false`) — **recommandé** | **B. Espace allumé** (`eefSpace=true`) |
|---|---|---|
| Ce que voit un utilisateur de la 54 | La **même vitrine** que la 53 (déclaration d'intérêt gratuite), plus les correctifs du §2 | Le hub : catalogue, CV/lettres/entretien, profil |
| Ce que voit le relecteur Apple | La vitrine — **et il doit être prévenu** que l'espace réel s'active à distance (guideline 2.3.1) | Le hub, avec le catalogue — **à condition qu'il ne soit pas vide** (guideline 2.1, contenu provisoire) |
| Condition | Aucune | **Un établissement publié** (XC-02) et le backend `95440db`+ déployé |
| Risque | Fonction activée après la revue : il faut la déclarer (§3) | Un relecteur qui tombe sur « Le catalogue arrive » ; les premiers utilisateurs voient l'espace avec le seul pilote |

**Recommandation : A.** Au 01/10/2026 le lancement est « vitrine + notifications »
(aucun établissement n'est publié, aucune formation n'est visible). Allumer
`eefSpace` maintenant exposerait un catalogue vide à tout le monde. La 54 part donc
**éteinte**, avec la déclaration du §3 ; l'ouverture est une opération serveur
séparée (`docs/runbook-ouverture-espace-reel.md`), sans nouvelle soumission.

> Si le propriétaire choisit **B**, remplacer le §2.1 par le §2.2 et supprimer le
> second paragraphe du §3.

---

## 2. Notes de version

Ne dire que ce qu'un utilisateur *voit*. **Ne citer ni le catalogue, ni les
logos d'établissements, ni le hub** dans l'état A : aucun logo n'est visible en
production (aucun établissement actif n'en a) et le catalogue est derrière un
drapeau éteint — le dire serait vanter une fonction inatteignable
(guidelines 2.3.1 / 2.3.3).

### 2.1 État A — espace éteint (recommandé)

**App Store — « Nouveautés » (FR)**

```
• Notifications plus fiables : un récit de la semaine reçu en notification ouvre désormais directement ce récit.
• Le profil se synchronise correctement même quand l'adresse e-mail est manquante.
• Fiches établissements : retrait d'un indicateur d'admission qui n'était pas fondé sur un calcul réel.
• Textes légaux mis à jour (septembre 2026).
• Améliorations de stabilité.
```

**App Store — « What's New » (EN)**

```
• More reliable notifications: a weekly story received as a notification now opens that story directly.
• Your profile now syncs correctly even when the email address is missing.
• Institution pages: removed an admission indicator that was not based on a real calculation.
• Legal texts updated (September 2026).
• Stability improvements.
```

**Google Play — « Notes de version » (≤ 500 caractères par langue)**

```
<fr-FR>
• Notifications plus fiables : un récit reçu en notification s'ouvre directement.
• Synchronisation du profil corrigée quand l'e-mail est manquant.
• Fiches établissements : retrait d'un indicateur d'admission non fondé.
• Textes légaux mis à jour (septembre 2026).
• Améliorations de stabilité.
</fr-FR>
<en-US>
• More reliable notifications: a story received as a notification opens directly.
• Profile sync fixed when the email is missing.
• Institution pages: removed an unfounded admission indicator.
• Legal texts updated (September 2026).
• Stability improvements.
</en-US>
```

### 2.2 État B — espace allumé (seulement si le §1 a tranché B)

Ajouter en tête, **au futur ou au présent selon l'état réel du catalogue** — jamais
« des milliers de formations » tant que seul un pilote est publié :

```
• Nouveau : l'espace « Études en France » — cherche ta formation dans les universités publiques françaises, prépare ton CV, tes lettres de motivation et ton entretien, et suis ta candidature avec un conseiller KPB.
```
```
• New: the "Études en France" space — search programmes at French public universities, prepare your CV, motivation letters and interview, and follow your application with a KPB advisor.
```

### 2.3 TestFlight — « What to Test » (testeurs internes : tout ce qui existe)

```
FR — Build 54 (2.3.0)
À tester en priorité :
1. Notification « récit de la semaine » reçue app fermée : elle doit ouvrir le récit (pas l'accueil).
2. Fiche d'un établissement (Explorer) : plus de jauge verte « 85 % ».
3. Accueil → carte « Études en France » : la vitrine s'affiche, la date « 1er octobre 2026 » sans compte à rebours ; pour un compte au Niger, la mise en garde remplace la date, avec un lien vers la source officielle.
4. Profil → Conditions / Confidentialité : « Dernière mise à jour : septembre 2026 ». Plus de « espace communautaire » dans les CGU.
Hub de l'espace (nécessite un build lancé avec KPB_EEF_SPACE_ENABLED=true, voir docs/device-qa-build54.md) : catalogue, profil (Modifier / Me retirer), CV, lettres, entretien, lien vers la plateforme officielle.
```
```
EN — Build 54 (2.3.0)
Please test first:
1. "Weekly story" notification received with the app closed: it must open the story (not the home screen).
2. Institution page (Explore): no more green "85%" gauge.
3. Home → "Études en France" card: the showcase appears with "1 October 2026" and no countdown; for an account in Niger the warning replaces the date, with a link to the official source.
4. Profile → Terms / Privacy: "Last updated: September 2026". No more "community space" in the Terms.
Space hub (needs a build run with KPB_EEF_SPACE_ENABLED=true, see docs/device-qa-build54.md): catalogue, profile (Edit / Remove me), CV, letters, interview, link to the official platform.
```

---

## 3. Addendum aux « Notes for Review » Apple (LIV-04 + XC-03)

À ajouter à la fin du bloc de `store-listing-copy.md` §7.1. **Texte à coller en
anglais** (les relecteurs lisent l'anglais) :

```
REMOTELY ACTIVATED FEATURE — "Études en France" space.
This version contains a section that helps students prepare an application to French public universities (a searchable programme catalogue, CV / motivation-letter / interview preparation tools that already ship in the app, and a profile the student can edit or withdraw at any time). It is switched on from our server (feature flag `eefSpace` in GET https://api.kpbeducation.cloud/api/config/app). At the time of review the flag is OFF, so the reviewer sees the "coming soon" showcase with a free "I'm interested" form. We are declaring the remote activation here as required by guideline 2.3.1; no new permission, SDK or data type is introduced by it.

Data: the programme catalogue is derived from the French Ministry of Higher Education's open data (Parcoursup, Trouver mon master, main diplomas), published under the Licence Ouverte 2.0, and attributed in the app. Institution logos come from Wikimedia Commons (their licence is shown next to the logo).

NOT AFFILIATED WITH ANY GOVERNMENT. KPB Education is a private guidance service. It is not affiliated with Campus France, the French government or any French administration, and does not process applications. Official applications are submitted on the official Études en France platform, which the app links to (https://www.campusfrance.org/fr). Dates and country suspensions shown in the app come from official sources, linked next to each statement.

No account is required to see the catalogue. A student account is required to declare interest; parents and partner accounts see a message that the space is reserved for students.
```

> Dans l'**état B**, remplacer « At the time of review the flag is OFF… » par « At the
> time of review the flag is ON and the reviewer sees the space directly. »

**Compte de démonstration** : inchangé (`store-listing-copy.md` §7.1). Prévoir un
compte **étudiant** (le hub n'est pas montré à un parent).

---

## 4. Google Play — mention de non-affiliation et source officielle (XC-04)

La politique Play « Requirements for apps that communicate government
information » exige, dans la description et la fiche : **des sources bien
visibles** et **la mention claire que l'app ne représente aucune entité
gouvernementale**. À ajouter à la fin des descriptions longues FR et EN
(`store-listing-copy.md` §5.1 / §6.1) :

**FR**
```
KPB Education est un service privé d'accompagnement. Il n'est affilié ni à Campus France, ni à l'État français, ni à aucune administration, et ne représente aucune entité gouvernementale. Les candidatures se déposent sur la plateforme officielle Études en France : https://www.campusfrance.org/fr — les dates et suspensions affichées dans l'app renvoient à leur source officielle.
```

**EN**
```
KPB Education is a private guidance service. It is not affiliated with Campus France, the French government or any administration, and does not represent any government entity. Applications are submitted on the official Études en France platform: https://www.campusfrance.org/fr — dates and suspensions shown in the app link to their official source.
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
| Revue accélérée Apple : l'approbation pour le 01/10 n'est **pas** garantie (1 à 3 jours) | — | LIV-10 |
