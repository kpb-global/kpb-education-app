# Consentement « Études en France » — texte archivé de la version `eef-consent-v1`

> **Pourquoi ce fichier existe (EEF-UX-M07).** Chaque déclaration d'intérêt
> enregistre `consentVersion` en base. Cette colonne répond à la seule question
> qu'un horodatage laisse ouverte : *qu'est-ce que l'étudiant a accepté ?* Or le
> texte ne vivait que dans `app_translations.dart` : à sa première réécriture, la
> phrase acceptée par les premiers déclarants aurait disparu, alors que leurs
> lignes portent `eef-consent-v1`. Ce fichier est la copie qui survit.
>
> **Règle.** Une version de consentement ne se *remplace* jamais : on ajoute
> `eef-consent-v2` (constante `kEefConsentVersion`, empreinte dans
> `test/features/etudes_en_france/eef_consent_version_test.dart`) **et** on
> archive ici le texte de la version qu'elle remplace.

## Version `eef-consent-v1`

En vigueur depuis la vitrine de la build 49. **Inchangée dans la 2.3.0 (55)** (la 54, jamais
envoyée aux boutiques, est abandonnée : `docs/release-ledger.md`).

### Ce qui est affiché au moment du consentement

Deux clés de traduction, affichées dans la feuille de déclaration, avant le
bouton « Valider » :

| Clé | Français | Anglais |
|---|---|---|
| `eef_sheet_body` | Tout est optionnel — un seul tap suffit. Ces réponses servent à te rappeler avec les bonnes informations, et à mesurer ce que nous devons préparer. | Everything is optional — one tap is enough. These answers help us come back to you with the right information, and gauge what we need to prepare. |
| `eef_consent_notice` | En validant, tu acceptes qu'un conseiller KPB te contacte au sujet de cet espace, et que ta réponse serve à préparer notre accompagnement. Tu peux te retirer à tout moment, depuis cet écran. | By confirming, you agree that a KPB counsellor may contact you about this space, and that your answer helps us prepare our guidance. You can remove yourself at any time, from this screen. |

### Ce que la version recouvre

- le **consentement à être contacté** par un conseiller KPB au sujet de l'espace
  (et le fait que la réponse serve à préparer l'accompagnement) ;
- la case facultative « La version Premium m'intéresserait aussi »
  (`wantsPremium`) ;
- les niveaux (`currentLevel`, `targetLevel`) et, depuis la 2.3.0 (55), les
  domaines (`fieldIds`, codes d01–d12) — des **réponses**, pas un consentement
  supplémentaire.

## Ce que la 2.3.0 (55) change *sans* changer le texte

| Changement | Pourquoi ce n'est pas une nouvelle version |
|---|---|
| Un sélecteur de **domaines** dans la feuille | Le texte consenti ne parle pas de domaines ; ce sont des réponses facultatives qui qualifient le rappel, comme les niveaux. |
| Un bloc « Mon profil Études en France » dans le hub, avec **Modifier** et **Me retirer** | Cela *tient* la promesse du texte (« tu peux te retirer à tout moment, depuis cet écran ») au lieu de la changer. |
| **Modifier** passe par `PATCH /etudes-en-france/interest` | Le serveur n'accepte ni `consent`, ni `consentVersion`, ni `wantsPremium` sur cette route (400) : modifier ses domaines ne redonne pas un consentement et n'efface pas l'intérêt Premium. `consentedAt` et `consentVersion` restent ceux de la déclaration d'origine. |
| La feuille est préremplie depuis le profil | Le préremplissage ne coche rien à la place de l'étudiant pour le consentement : il ne porte que sur les niveaux et les domaines. |

## Ce que `eef-consent-v1` ne couvre PAS — la feuille « écoles privées » (build 56)

> **Note ajoutée le 05/10/2026, hors du texte consenti, qui reste identique** (les deux clés de
> traduction du tableau ci-dessus n'ont pas bougé d'un caractère). `eef-consent-v1` est
> **inchangée dans la 56**.

La build 56 ajoute une feuille d'information sur les écoles privées (`docs/release-56-store-pack.md`,
éteinte par défaut derrière `features.eefPrivateSchools`). **Ce que v1 couvre** : qu'un conseiller
KPB te contacte au sujet de cet espace, et que ta réponse serve à préparer l'accompagnement de
KPB. **Ce qu'elle ne couvre pas** : une **prospection commerciale des écoles privées** — ni que
des écoles te contactent, ni que tes coordonnées ou ta déclaration d'intérêt leur soient
transmises, ni qu'on t'adresse des messages au sujet d'une école ou d'une offre privée.

En conséquence, la feuille :

- **n'utilise ni la liste d'intérêt (`EefInterest`, audience `eef_interest`) ni le profil Études
  en France pour cibler** : elle s'ouvre par un geste volontaire de l'étudiant (le lien du
  catalogue sans résultat, ou l'option de la bulle) et elle est la même pour tous ;
- **ne transmet rien aux écoles** : pas de formulaire, pas de champ, pas de coordonnées ; son
  seul bouton ouvre WhatsApp vers KPB avec un message statique qui ne nomme que l'écran et le sujet (les écoles privées) ;
- **n'est suivie d'aucun push, e-mail ni message de ce sujet** vers cette audience ;
- ne passe pas par l'écran de demande d'admission d'une école privée (dont le bouton crée un
  dossier et envoie des coordonnées aux commerciaux).

Si un jour la feuille doit cibler (liste d'intérêt, profil), transmettre à une école ou relancer,
c'est une **nouvelle finalité** : décision juridique, texte de consentement dédié et
`eef-consent-v2` (constante `kEefConsentVersion`), avec l'archive du texte v1 ici.

## Questions juridiques encore ouvertes

> **Mise à jour du 03/10/2026 — décisions juridiques.** (1) **EEF-UX-15** ne se pose pas pour
> la build 55 : aucune sélection de formations n'exige de profil déclaré ; elle se posera
> avant toute build dont la sélection l'exigera. (2) **« depuis cet écran »** : un lien
> « Me retirer » est ajouté dans la feuille de déclaration (build 55) ; le texte consenti et
> `eef-consent-v1` ne changent pas. (3) **La phrase du héros** sur Campus France est validée
> telle quelle. (4) **L'annonce d'ouverture** part vers **tous les étudiants, Niger compris**,
> avec un texte neutre ; la question 4 ci-dessous **reste ouverte pour l'audience
> `eef_interest`**, qui n'est pas utilisée tant qu'elle n'est pas tranchée. Le texte
> d'origine des questions est conservé ci-dessous. Détail : `docs/ouverture-espace-eef.md` § 6.

1. **EEF-UX-15 — découpler ou assumer le couplage.** Dans la 2.3.0 (55) il n'y a *pas*
   de sélection de formations : la déclaration n'est donc la condition d'aucune
   fonction gratuite, et le consentement au rappel reste optionnel. La question
   se pose **avant la prochaine build dont la sélection exigera un profil
   déclaré** (« build 55 » dans l'ancienne numérotation, écrite avant que la 54 soit
   abandonnée ; la 2.3.0 (55) n'a pas de sélection) : soit on découple (profil de
   sélection sans consentement commercial, case de rappel séparée, `eef-consent-v2`),
   soit on assume le couplage et on le dit à l'écran.
2. **« depuis cet écran ».** Le texte promet un retrait « depuis cet écran ». Le
   retrait est dans l'écran DERRIÈRE la feuille de consentement — la vitrine
   (« Me retirer de la liste », état de lancement) ou le hub (« Mon profil Études en
   France », espace ouvert) —, pas dans la feuille elle-même. À faire valider ; si
   c'est jugé insuffisant, le remède est un lien « Me retirer » dans la feuille,
   sans changer la version.
3. **Phrase sur Campus France dans le héros du hub** (`eef_hub_hero_body`) :
   « …auprès des services officiels, selon la procédure indiquée sur chaque
   formation (plateforme Études en France gérée par Campus France, demande
   d'admission préalable…). » À faire valider (EEF-UX-04). Elle ne dit plus que
   TOUTES les candidatures passent par la plateforme Études en France : le
   catalogue compte ~3 100 formations en DAP blanche, 29 en DAP jaune et 80 hors
   procédure.
4. **Une annonce d'ouverture est-elle couverte par le consentement ?** Le texte v1
   dit « un conseiller KPB te contacte au sujet de cet espace ». La vitrine, elle,
   promet « on te préviendra dès l'ouverture » (`eef_cta_body`) — un texte que le
   test d'empreinte ne fige pas. Un push ou un e-mail automatisé de type « l'espace
   est ouvert » à l'audience `eef_interest` est-il couvert ? À trancher AVANT le
   premier envoi à cette audience. ~~Alternative sans risque : n'envoyer qu'aux
   étudiants par `all_students_except_countries` (message d'information général).~~ **Écartée le
   03/10/2026 pour l'annonce d'ouverture** : elle part vers **tous les étudiants** (`all_students`,
   Niger compris, texte neutre), sans exclure les pays suspendus ; jamais `eef_interest` tant que
   cette question n'est pas tranchée (`docs/ouverture-espace-eef.md` § 4).

## Export

`GET /admin/etudes-en-france/interest/export.csv` (CSV) inclut `consentVersion`. Les
lignes antérieures à la 2.3.0 (55) portent `eef-consent-v1` ; elles ne sont pas
modifiées par le `PATCH`.
