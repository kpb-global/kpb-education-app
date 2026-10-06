# Fiche de QA appareil — build 55 : aide au dossier et retrait

> **⚠️ REMPLACÉE par la 56 le 05/10/2026 : la 55 n'a jamais été soumise ; suivre `docs/mise-a-jour-56-checklist.md`.**
> Décision du propriétaire : on n'envoie que la 56. La 55 (`2.3.0 (55)`) a été téléversée sur App Store Connect
> le 04/10/2026 mais jamais soumise à l'App Review ; son AAB signé (Flutter CI, run 37322572087) n'a jamais été
> importé dans Play et **ne doit pas l'être**. Le contenu ci-dessous est conservé tel qu'écrit. Ce que la 56 en
> reprend (notes de version, cas Aide-n, constats Xcode 27) est dit par ses propres documents ; pour tout numéro
> de version ou de build, lire 56. Le registre : `docs/release-ledger.md`.

> **Pour qui.** Le propriétaire, sur **un iPhone et un Android physiques**, avec la
> **build soumise** (TestFlight / Play Internal) — pas un build de debug : le
> contrat de soumission exige que la preuve vienne de l'artefact. Cette fiche est la
> **suite de la section B-aide de `docs/device-qa-build54.md`** (Aide-1 à Aide-17) :
> elle ne la remplace pas, et les règles de la build 54 y restent vraies, sauf là où
> elle les **étend explicitement** (voir « Ce qui change pour le Niger »).
>
> **Ce que cette fiche couvre** : les déclencheurs d'aide ajoutés par la build 55
> (bouton sous chaque formation, ligne sous les filtres actifs, ligne dans les trois
> outils du dossier) et le lien « Me retirer de la liste » de la feuille de
> déclaration. **Elle ne couvre pas** les filtres du catalogue eux-mêmes (Niveau,
> Domaine, Ville, Procédure) : ils ont leur propre recette (B3 et suivants de la
> fiche 54, à compléter) et leurs tests.
>
> **Où et comment tester.** Le hub et le catalogue sont derrière `features.eefSpace`,
> éteint en production : mêmes trois voies que le §B de la fiche 54 (voie 2, la
> fenêtre de recette sur la production, est la seule qui teste l'artefact soumis sur
> le vrai catalogue). **Tuer et relancer l'app** après chaque bascule, **aucune
> notification** pendant la fenêtre, et `eef-space-off` **avant** « Soumettre pour
> vérification ». La vitrine (état A, Aide-42) se teste, elle, **sans** ouvrir
> l'espace.
>
> **Comptes à avoir sous la main.** Un compte étudiant **hors Niger** (le Sénégal
> convient), un compte étudiant du **Niger**, un **invité** (Aide-44). Les deux langues
> (français et anglais) pour chaque cas marqué « FR + EN ».
>
> **Ce qui ne se teste pas sur appareil, et pourquoi.** Le **thème sombre** n'est pas
> branché sur l'app (clair seulement) : le contraste en sombre est mesuré par les
> tests, pas ici. L'état « Le catalogue arrive » (catalogue non publié) n'existe plus
> en production (catalogue publié depuis le 01/10) : voir la fiche 54.

Pour chaque ✗ : noter l'écran, la langue, le pays du compte, l'appareil.

## Les bornes des messages (à lire avant Aide-20, Aide-22 et Aide-38)

Chaque morceau **cité** dans un message prérempli est borné, puis coupé proprement :
**à une fin de mot** quand il y en a une raisonnablement proche, jamais au milieu d'un
caractère accentué ni d'un emoji, et il se termine alors par « … ». Le gabarit
(« Bonjour KPB Education, … pour mon dossier. ») n'est **jamais** coupé : c'est lui
qui porte la demande.

| Morceau cité | Borne |
|---|---|
| Intitulé de la formation | **80** caractères |
| Université | **60** caractères |
| Ville (d'une formation) | **30** caractères |
| Libellé d'un filtre (niveau, domaine, ville, procédure) | **32** caractères |
| Valeurs citées par famille de filtre | **3**, puis « … » |
| Résumé des filtres, en entier | **300** caractères |
| Message entier, gabarit compris | **520** caractères (au plus **1 800** une fois encodé dans le lien) |

Chercher des cas aux bornes : sur la production, chercher « ingénieur » ou « diplôme »
dans le catalogue et parcourir la liste à la recherche de l'intitulé le plus long ; si
aucune formation n'atteint les bornes, c'est un cas de la **voie 1** de la fiche 54
(backend local, avec une formation de test à l'intitulé de plus de 120 caractères
accentués, une université et une ville longues). Dire dans la signature quelle voie a
servi.

## Aide au dossier : catalogue

| # | À vérifier | Attendu |
|---|---|---|
| Aide-18 | Catalogue, compte **hors Niger**, FR : un bouton sous **chaque** formation | Chaque carte se termine par un bouton de texte « Demander de l'aide » (icône de conversation), sous le lien de source. **Pas une carte pleine** : un bouton, sur une ligne. Cible tactile confortable (≥ 48 dp : le pouce l'atteint sans viser). Il n'y a PAS de mention « Un accompagnement n'est pas une garantie » sous chaque carte : l'écran la porte **une seule fois** (voir Aide-24). |
| Aide-19 | Le message du bouton | Tap → WhatsApp s'ouvre sur la ligne du conseiller (`AppConfig.whatsappNumber`, +33 7 68 67 42 92) avec : *« Bonjour KPB Education, je regarde la formation « <intitulé> » (<université>, <ville>) dans l'espace Études en France de l'app et j'aimerais de l'aide pour mon dossier. »* **Rien d'autre** : ni nom, ni e-mail, ni téléphone, ni pays du compte. Le message n'est **pas envoyé tout seul**. Essayer sur deux formations différentes : chacune nomme **sa** formation. Sur iPhone **et** Android. |
| Aide-20 | Message **borné**, coupé proprement | Prendre une formation dont l'intitulé dépasse **80 caractères**, de préférence avec une université de plus de 60 et une ville de plus de 30 (méthode : « Les bornes des messages », plus haut), puis taper son bouton. Attendu : le message arrive **entier côté demande** (il commence par « Bonjour KPB Education, je regarde la formation » et finit par « …pour mon dossier. »), l'intitulé cité fait **au plus 80 caractères** et se termine par « … » **à une fin de mot** (jamais au milieu d'un mot ni d'un caractère accentué) ; idem pour l'université (60) et la ville (30). Une formation sans université ni ville servies : la formation seule, sans parenthèses vides. |
| Aide-21 | Ligne sous les filtres actifs | **Aucun filtre** : pas de ligne « Tu hésites entre ces formations ? ». **Un filtre posé** (par exemple Niveau → Master) : la ligne apparaît **sous les puces de filtres actifs et « Tout effacer »**, **sous le compteur « N formations »** et au-dessus de la première formation. Elle disparaît quand le dernier filtre est retiré. Son lien « Demander de l'aide » ouvre WhatsApp avec : *« …je regarde les formations de l'espace Études en France de l'app (Niveau : Master ; Ville : Lyon) et j'hésite. J'aimerais de l'aide pour choisir. »* — les filtres **posés au moment du tap**, en clair. |
| Aide-22 | Filtres cités : bornés | Cocher **quatre villes ou plus** : le message cite **trois** valeurs puis « … » (« Ville : Paris, Toulouse, Montpellier, … »). L'ordre cité est **celui de la feuille** (les villes qui comptent le plus de formations d'abord ; pour le niveau, de la licence au master), **pas** celui des cases cochées (cocher Lyon avant Paris ne change pas l'ordre cité). Un libellé de plus de 32 caractères (un domaine long) est abrégé par « … ». Le message reste court (résumé : 300 caractères au plus). La **procédure** choisie est citée aussi pour un compte **hors Niger** (« Procédure : Études en France ») : c'est un ajout volontaire aux trois familles demandées (voir les points produit). Pour un compte du **Niger** elle n'est **jamais** citée (voir Aide-29 et Aide-30). |
| Aide-23 | **Une seule ligne d'aide à la fois** (règle de non-empilement) | Filtre **Parcoursup**, **DAP dossier jaune** ou **Hors procédure** : **seule** la ligne « Pas sûr(e) de la procédure pour ces formations ? » (build 54) apparaît — **pas** « Tu hésites… ». Filtre **Études en France** ou **DAP dossier blanc** (ou tout autre filtre) : seule « Tu hésites entre ces formations ? ». **Jamais les deux** sous le compteur. |
| Aide-24 | **Au plus une carte pleine** par écran (Aide-9 de la fiche 54, maintenue) | Liste **entière** (recherche étroite) + un filtre : une seule carte pleine (« Tu hésites sur ta formation ? », en bas de liste), et « Un accompagnement n'est pas une garantie… » **une seule fois**. Aucun résultat avec un filtre posé : la carte « Tu ne trouves pas ta formation ? » **seule**, **sans** la ligne « Tu hésites… » ni boutons de formation. Liste longue encore paginée (le cas courant : des milliers de formations) : **pas** de carte pleine tant qu'il reste des pages, mais « Un accompagnement n'est pas une garantie… » est déjà là, **une seule fois, en tête de liste** (sous le compteur et sous la ligne d'aide éventuelle, avant la première formation) : les boutons, eux, sont déjà sous les formations chargées, et ils ne sont jamais proposés sans la mention sur l'écran. Quand la dernière page est chargée, la mention **passe dans la carte du bas** : jamais deux mentions, jamais aucune. |

## Aide au dossier : les trois outils (depuis le hub)

| # | À vérifier | Attendu |
|---|---|---|
| Aide-25 | **Depuis le hub** : CV, Lettres, Entretien | Chacun des trois écrans montre **une ligne** (sur un fond bleu très clair, comme le bandeau « IA » au-dessus d'elle) : « Besoin d'aide pour rédiger ton CV ? » / « …pour ta lettre de motivation ? » / « …pour préparer ton entretien ? », son lien « Demander de l'aide », et dessous « Un accompagnement n'est pas une garantie… » (c'est le **seul** déclencheur de l'écran : la mention l'accompagne). CV : sous le bandeau IA, en tête du formulaire. Lettres : **première ligne de la liste** des modèles (elle défile avec eux). Entretien : sous l'introduction, dans le **choix du type d'entretien** (pas pendant l'exercice). |
| Aide-26 | Le message de chaque outil | Tap → WhatsApp : *« Bonjour KPB Education, je suis dans l'espace Études en France de l'app, sur l'outil « CV » (ou « lettre de motivation », ou « préparation d'entretien »). J'aimerais de l'aide. »* Rien de personnel. Non envoyé tout seul. |
| Aide-27 | **Hors du hub : rien ne change** | Ouvrir les **mêmes** écrans depuis la boîte à outils étudiants, depuis le tiroir « Outils KPB », depuis le dossier d'un étudiant (entretien), depuis le coach (lettres) : **aucune** ligne « Besoin d'aide… », aucune mention nouvelle. |

## Ce qui change pour le Niger (extension EXPLICITE de la fiche 54)

> **Décision du propriétaire, 03/10/2026.** Un compte dont le pays est suspendu
> **VOIT** les déclencheurs d'aide du catalogue et des outils : un étudiant peut faire
> sa procédure par un autre pays, on ne bloque personne. **Ce qui reste vrai** : nulle
> part dans l'espace un libellé ni un message « démarrer l'étude de ton dossier » pour
> ce compte, aucune promesse que la procédure est ouverte pour lui, et **aucun pays de
> remplacement n'est cité** (ce contenu n'est pas validé juridiquement). Les lignes de
> la build 54 (`procédure`, `documents`, et la ligne de procédure du catalogue)
> restent **absentes** pour lui, comme au Aide-8 / Aide-15.

| # | À vérifier | Attendu |
|---|---|---|
| Aide-28 | Compte du **Niger**, FR : le bouton de formation | Sous chaque formation : « **Parler à un conseiller** » (et **jamais** « Demander de l'aide » ni un libellé « dossier »). Message : *« …je regarde la formation « <intitulé> » (<université>, <ville>) dans l'espace Études en France de l'app. La procédure est suspendue dans mon pays : j'aimerais savoir quelles options existent. »* — le pays n'est **pas nommé**, aucun autre pays non plus, aucun mot « dossier » / « démarrer ». |
| Aide-29 | Compte du **Niger** : ligne des filtres et carte | Un filtre posé : la ligne « Tu hésites entre ces formations ? » est **visible**, son lien est « Parler à un conseiller », son message : *« …(Niveau : Master). La procédure est suspendue dans mon pays : j'aimerais savoir quelles options existent. »* La carte neutre « Besoin d'y voir plus clair ? » reste en bas de liste, **seule carte pleine** (Aide-24 vaut aussi pour lui). |
| Aide-30 | **Niger + filtre Parcoursup** (ou « DAP dossier jaune ») | **Pas** de ligne de procédure (Aide-15, inchangé) **mais** la ligne neutre « Tu hésites… » à sa place : l'étudiant qui filtre voit toujours **une** invitation, jamais deux, jamais aucune. Son message **ne cite pas la procédure** (le nom « DAP dossier jaune » contient le mot « dossier ») : avec ce seul filtre il ne cite rien — *« …de l'espace Études en France de l'app. La procédure est suspendue dans mon pays : j'aimerais savoir quelles options existent. »*, **sans parenthèses vides** — et avec un autre filtre en plus (Niveau : Master) seul celui-là est cité. |
| Aide-31 | Compte du **Niger** : les trois outils, depuis le hub | La ligne est visible : même question, lien « Parler à un conseiller ». Message : *« Bonjour KPB Education, je regarde l'outil « CV » dans l'espace Études en France de l'app. La procédure est suspendue dans mon pays : j'aimerais savoir quelles options existent. »* |
| Aide-32 | **Niger, anglais** | Catalogue : « Talk to an advisor » (bouton), « Torn between these programmes? » (ligne). Outils : « Need help writing your CV? » / « …with your motivation letter? » / « …preparing for your interview? » + « Talk to an advisor ». Messages : *« …The procedure is suspended in my country: I would like to know which options exist. »* — ni « file », ni « start », ni « review », ni pays. |

## Transversal

| # | À vérifier | Attendu |
|---|---|---|
| Aide-33 | **Anglais** (compte hors Niger) | Bouton « Ask for help » ; ligne « Torn between these programmes? » ; outils « Need help writing your CV? »… ; messages en anglais (*« Hello KPB Education, I am looking at the programme “…” (…, …) in the Études en France space of the app and I would like some help with my file. »*). Rien de laissé en français dans les libellés. |
| Aide-34 | **Analytique** (PostHog → Activity, filtré sur le compte de test ; Android : aussi Firebase DebugView, `adb shell setprop debug.firebase.analytics.app com.karatou.android`) | Un tap sur un bouton de formation → `eef_help_cta_tapped` avec `help_step` = `catalog_program`, `surface` = `catalog`, `variant` = `compact`, puis `whatsapp_handoff` (`source` = `eef_help_catalog_program`). **Aucun** `eef_help_card_shown` pour `catalog_program`. La ligne des filtres : `eef_help_card_shown` (`catalog_filters`) **une fois** par visite du catalogue, même si on change de filtres. Les outils : `tool_cv` / `tool_letters` / `tool_interview`, `surface` = `tools`, shown une fois par ouverture de l'écran. **Aucune autre propriété** : ni intitulé de formation, ni université, ni ville, ni libellé de filtre, ni pays, ni « suspendu ». Contrat : `docs/analytics-event-contract.md`. |
| Aide-35 | **Texte agrandi** (×1,3, petit Android 360 dp **et** iPhone SE), FR + EN | Les boutons et lignes **passent à la ligne**, **jamais coupés par « … »**, rien ne déborde — y compris sous le bandeau de suspension du Niger et avec un nom de formation très long. Le lien reste atteignable (≥ 48 dp). |
| Aide-36 | **Lecteur d'écran** (VoiceOver / TalkBack) | Chaque bouton de formation annonce **de quelle formation** il parle : « Demander de l'aide à propos de « <intitulé> » » (Niger : « Parler à un conseiller à propos de… »), pas vingt fois « Demander de l'aide ». Les lignes annoncent leur lien comme un bouton. |
| Aide-37 | **Aucune impasse** | Sans WhatsApp installé : le toast « Impossible d'ouvrir WhatsApp… » s'affiche pour chacun des déclencheurs (jamais un bouton muet). |
| Aide-38 | **Longueur du lien WhatsApp** (à MESURER ici, pas mesuré ailleurs) | Avec un nom de formation, une université et une ville **aux bornes** (80, 60 et 30 caractères : « Les bornes des messages », plus haut), puis avec six filtres posés dont quatre villes et un domaine au libellé long : le message **arrive entier** dans le champ de saisie de WhatsApp (sa phrase finale — « …pour mon dossier. » / « …pour choisir. » — est lisible avant envoi), sur iPhone **et** Android. Si WhatsApp le tronque : noter le nombre de caractères du message reçu et à partir de quelle longueur — c'est ce qui décide de resserrer les bornes. |
| Aide-44 | **Invité** (l'app ouverte sans compte, comme A7 de la fiche 54) | Hub : « Créer mon compte » à la place de la déclaration — donc **pas** de feuille, **pas** de lien « Me retirer ». Catalogue (« Trouver ma formation » reste ouverte à l'invité) : sous chaque formation le bouton **normal** « Demander de l'aide » (un invité n'a pas de profil, donc pas de pays : il n'est jamais suspendu), avec le message habituel d'Aide-19 — rien de personnel, puisqu'il n'y a rien. Outils CV / Lettres / Entretien : le mur de conversion (B9), **jamais** la ligne d'aide. |

## Retrait depuis la feuille de déclaration

> Le texte consenti **n'a pas changé** (« Tu peux te retirer à tout moment, depuis cet
> écran. », `eef-consent-v1`). Ce qui change : le geste est maintenant **dans** la
> feuille, là où une déclaration existe.

| # | À vérifier | Attendu |
|---|---|---|
| Aide-39 | **Première déclaration** (hub : « Compléter mon profil ») | La feuille montre le consentement et « Valider » ; **pas** de lien « Me retirer de la liste » (rien à retirer avant « Valider »). Dès que « Valider » réussit et que la feuille se ferme, **le hub montre « Me retirer de la liste »** : la promesse est tenue par l'écran, à l'instant où il y a quelque chose à retirer. Pendant la fermeture de la feuille (une fraction de seconde), le lien « Me retirer » **n'apparaît pas** et la feuille ne grandit pas. |
| Aide-40 | **Modification** (hub : « Modifier mon profil ») | La feuille montre « Me retirer de la liste » (bouton de texte, sous les domaines, au-dessus de « Valider »). Tap → la feuille **se ferme**, puis la **même confirmation** que celle du hub : « Te retirer de la liste ? » (« Me retirer » / « Annuler »). |
| Aide-41 | Le flux de retrait | « Me retirer » → « Tu es retiré de la liste. » **lu sur le hub** (la feuille est fermée : le message n'est pas caché derrière elle), le bloc revient à « Compléter mon profil », la ligne disparaît de l'admin. Un retrait qui échoue (couper le réseau avant) : « Retrait impossible pour le moment… privacy@kpbeducation.com » **sur le hub**, et la déclaration reste. « Annuler » dans la confirmation : rien n'est retiré, la feuille reste **fermée** (rouvrir « Modifier mon profil » si besoin). **Après un retrait en échec**, rouvrir « Modifier mon profil » (sur la vitrine : « Modifier ma réponse ») : **aucune** erreur d'envoi (« Envoi impossible… Rien n'a été enregistré ») n'est affichée et le bouton est « Valider », pas « Réessayer » — l'échec du retrait s'est lu sur l'écran, il ne suit pas dans la feuille. |
| Aide-42 | **Vitrine** (état A, **sans** ouvrir l'espace), compte déjà déclaré | La carte « C'est noté » porte déjà « Me retirer de la liste » (inchangé : « C'est noté » est un état de la **vitrine**, pas de la feuille). « Modifier ma réponse » rouvre la feuille **avec** « Me retirer de la liste », sous le consentement ; même flux (confirmation, message lu sur la vitrine). Première déclaration depuis la vitrine : **pas** de lien. |
| Aide-43 | Texte agrandi et anglais | Le lien tient dans la feuille à ×1,3 sur 360 dp (« Remove me from the list »), rien de coupé ; la feuille défile. |

## Signature

Appareils (modèle + OS), build soumise (numéro, source : TestFlight / Play Internal),
date, et ce qui a échoué. Un ✗ non résolu bloque la soumission. **Aide-38** est la
seule vérification qui peut changer le code (les bornes de longueur) : la noter avec
le nombre de caractères observé.
