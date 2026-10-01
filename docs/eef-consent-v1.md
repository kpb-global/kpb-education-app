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

En vigueur depuis la vitrine de la build 49. **Inchangée en build 54.**

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
- les niveaux (`currentLevel`, `targetLevel`) et, depuis la build 54, les
  domaines (`fieldIds`, codes d01–d12) — des **réponses**, pas un consentement
  supplémentaire.

## Ce que la build 54 change *sans* changer le texte

| Changement | Pourquoi ce n'est pas une nouvelle version |
|---|---|
| Un sélecteur de **domaines** dans la feuille | Le texte consenti ne parle pas de domaines ; ce sont des réponses facultatives qui qualifient le rappel, comme les niveaux. |
| Un bloc « Mon profil Études en France » dans le hub, avec **Modifier** et **Me retirer** | Cela *tient* la promesse du texte (« tu peux te retirer à tout moment, depuis cet écran ») au lieu de la changer. |
| **Modifier** passe par `PATCH /etudes-en-france/interest` | Le serveur n'accepte ni `consent`, ni `consentVersion`, ni `wantsPremium` sur cette route (400) : modifier ses domaines ne redonne pas un consentement et n'efface pas l'intérêt Premium. `consentedAt` et `consentVersion` restent ceux de la déclaration d'origine. |
| La feuille est préremplie depuis le profil | Le préremplissage ne coche rien à la place de l'étudiant pour le consentement : il ne porte que sur les niveaux et les domaines. |

## Questions juridiques encore ouvertes

1. **EEF-UX-15 — découpler ou assumer le couplage.** En build 54 il n'y a *pas*
   de sélection de formations : la déclaration n'est donc la condition d'aucune
   fonction gratuite, et le consentement au rappel reste optionnel. La question
   se pose **avant la build 55**, quand la sélection exigera un profil
   déclaré : soit on découple (profil de sélection sans consentement commercial,
   case de rappel séparée, `eef-consent-v2`), soit on assume le couplage et on le
   dit à l'écran.
2. **« depuis cet écran ».** Le texte promet un retrait « depuis cet écran ». En
   build 54 le retrait est dans le hub (écran derrière la feuille), pas dans la
   feuille elle-même. À faire valider ; si c'est jugé insuffisant, le remède est
   un lien « Me retirer » dans la feuille de modification, sans changer la
   version.
3. **Phrase sur Campus France dans le héros du hub** (`eef_hub_hero_body`) :
   « …plateforme officielle Études en France, gérée par Campus France. » À faire
   valider (EEF-UX-04).

## Export

`GET /admin/etudes-en-france/interest/export.csv` (CSV) inclut `consentVersion`. Les
lignes antérieures à la build 54 portent `eef-consent-v1` ; elles ne sont pas
modifiées par le `PATCH`.
