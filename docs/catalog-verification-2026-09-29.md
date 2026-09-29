# Relecture des 34 bourses aux sources officielles — 29/09/2026

> Preuves de la vague de vérification du 29 septembre 2026, journal de bord de
> ce qui a été **réellement lu** et de ce qui ne l'a pas été. Les rapports
> bruts des dix relecteurs (extraits verbatim, statuts HTTP, une entrée par
> fiche) sont versionnés dans `docs/evidence/catalog-2026-09-29/G1.json` …
> `G10.json` ; ce document en garde ce qu'un relecteur doit pouvoir contrôler.

## Méthode

- Dix relecteurs indépendants (un agent par groupe de 3 à 4 fiches), en LECTURE
  SEULE sur le dépôt. Chacun a ouvert les cinq sources officielles de chaque
  fiche, relevé le statut HTTP, l'URL finale et le titre, puis confronté le
  contenu de la page aux affirmations de la fiche (financement, éligibilité,
  pièces, démarche, calendrier, statut du cycle).
- Toute citation est copiée telle quelle depuis la page lue (25 mots au plus).
  Le rédacteur l'a recontrôlé lui-même : les **858 citations** des rapports sont
  retrouvées mot pour mot (espaces, guillemets et casse normalisés) dans les
  pages enregistrées par les relecteurs. Les pages elles-mêmes ne sont pas
  versionnées (volume) ; les URL le sont.
- `checkedAt` de chaque fiche = l'heure de la **fin de la lecture de ses cinq
  sources** (commande `date -u`), pas une heure choisie : les dates diffèrent
  d'une fiche à l'autre (deux fiches lues ensemble portent la même heure).
  Aucune date n'a été « repoussée » sans lecture.
- Les corrections ci-dessous ont été appliquées au dépôt par un seul rédacteur,
  après lecture des rapports. Une correction n'est appliquée que si une citation
  de la page la justifie.

## Résultat

| Verdict des relecteurs | Fiches |
|---|---|

| `verified` | 9 |
| `verified_with_edits` | 22 |
| `not_fully_verifiable` | 3 |

**Une fiche n'a PAS été relue et garde sa date du 24/08/2026 :
`up_mastercard_scholars_2027`.** Les quatre pages HTML d'UP
(`www.up.ac.za/mastercard-foundation-scholars-program…`) répondent à toute
requête de l'environnement de vérification par une page de blocage Cloudflare
(403, « Sorry, you have been blocked » — le blocage porte sur l'adresse de sortie
de cet environnement, pas sur un navigateur ; il n'a pas été contourné). Tant
qu'une personne ne les a pas relues dans un navigateur, la fraîcheur du
catalogue reste rouge pour cette seule fiche, **et sa clôture est le
30/09/2026**.

## Exceptions à la règle « cinq sources lues par le relecteur »

- **`kazakhstan_foreign_students_2027_forecast`** : `studyin.kz/admission` est
  une application JavaScript (le relecteur n'a vu qu'une coquille vide). Elle a
  été rendue dans un navigateur sans interface (Chromium, 29/09/2026 15:21 UTC) :
  c'est le portail de candidature officiel (connexion / inscription, contact
  `info@bolashak.gov.kz`). La lecture prouve que la page est le portail, pas le
  détail de la procédure, qui reste attesté par le communiqué de l'appel 2026.
- **`australia_awards_africa_2028_forecast`** : `www.dfat.gov.au` n'a répondu à
  aucune lecture (503 / 403 Akamai). Les sources `overview`, `eligibility` et
  `benefits` sont désormais des pages et le document 2027 du site officiel du
  programme (`australiaawardsafrica.org`, © DFAT), qui ont été lus. L'URL de
  l'`application` (portail OASIS) et du `cycle` sont inchangées et lues.
- **`chevening_2027`** : les cinq pages ont refusé `curl` (403 / erreur HTTP/2) ;
  elles ont été lues par `WebFetch`, qui **extrait par un modèle** (pas de HTML
  brut). Les citations retenues sont celles reproduites à l'identique dans au
  moins deux appels. Les dates (ouverture 04/08/2026, clôture 06/10/2026 11 h
  UTC) sont les plus importantes à recontrôler à la main.
- **`daad_helmut_schmidt_2027`, `daad_epos_2027`** : les domaines DAAD refusent
  `curl` ; lecture par `WebFetch` (voir ci-dessus) et par le PDF de l'appel.
- **`tz.uwc.org`** (fiche Tanzanie) : 403 au fetch direct le 24/08, chargée avec
  un User-Agent de navigateur le 29/09.

## Ce qui a changé de sens pour l'étudiant

- **Schwarzman** : la fenêtre 2027–2028 a clos le 09/09/2026 → `closed`.
- **Open Doors Russie** : les inscriptions ont ouvert le 20/08 → `open` (elle
  était annoncée « prochain cycle »).
- **AUC** : les échéances d'admission Fall 2027 sont publiées (1er février et
  1er juin 2027) → dates `confirmed` (le statut reste `forecast`).
- **Türkiye Scholarships** : l'allocation mensuelle était fausse (4 500 / 6 500 TL
  au lieu de 6 500 / 9 500 TL).
- **Türkiye–BID** : « financement complet » était faux en Licence (prêt sans
  intérêt remboursable) → `partially_funded`.
- **ETH Zurich** : 13 500 CHF par semestre à partir de la rentrée 2027/28.
- **UWC Kenya** : niveau exigé « CBE Grade 10 » (et non « Grade 12 »), relevés
  officiels sur papier à en-tête, formulaire d'information à télécharger.
- **McCall MacBain, Rhodes** : libellés de clôture au passé.
- **UCT** : l'avis « l'appel n'ouvrira pas » vise l'appel **2026**, pas 2027 ; la
  date du 10/11/2026 est celle d'une autre bourse.
- **ALU** : l'aide se **demande** (dossier distinct) → `separate_application`.

## Fiche par fiche


### `alu_scholarship_2027`

- Verdict du relecteur : **verified_with_edits** — lue le `2026-09-29T15:08:48.000Z` (groupe G9).

| Source | URL | HTTP | Lue |
|---|---|---|---|
| overview | https://www.alueducation.com/financial-aid-at-alu/ | 200 | oui |
| eligibility | https://help.alueducation.com/support/solutions/articles/204000012922-who-is-eligible-for-financial-aid- | 200 | oui |
| benefits | https://www.alueducation.com/financial-aid-at-alu/ | 200 | oui |
| application | https://www.alueducation.com/apply-now/ | 200 | oui |
| cycle | https://help.alueducation.com/support/solutions/articles/204000012913-what-are-the-application-deadlines- | 200 | oui |

**Écarts relevés**

- [minor] `advantages[3] et applicationRequirement` — fiche : « Aide évaluée dans la même candidature, à l’étape « Finances », sans dossier de bourse séparé » ; applicationRequirement: automatic ; page : La page de candidature dit que l’étape Finances indique si l’on peut DEMANDER l’aide, donc une demande d’aide suit. Le guide officiel ALU (hors des cinq URLs :…
  - « Additionally, you will find out if you qualify to apply for ALU financial aid. » (application)

**Corrections**

- appliquée : `advantages[3]`
- appliquée : `applicationRequirement`

**Calendrier confirmé par la page**

- Démarche : dépôt en continu, examen au fil de l’eau — « Please note that applications are reviewed on a rolling basis. Hence, you may apply at any point. »
- Démarche : un dossier tardif est en général reporté à la rentrée suivante — « any late applications will generally be considered for the next intake. »

**Non vérifié (la page ne le dit pas ou n'a pas pu être lue)**

- description : « trois échéances annuelles, qui tombent environ deux mois avant le début de chaque trimestre » — page silencieuse : les cinq pages ne donnent ni le nombre d’échéances par an ni le délai avant le trimestre (le tableau annoncé par l’artic…
- cycle.estimatedCloseAt = 2027-06-18 (échéance estimée pour septembre 2027) et sa base, l’échéance de septembre 2026 — page silencieuse : l’article des échéances renvoie à « the deadlines in the table below » mais aucun tableau n’est présent ; la page apply-…
- cycle.estimatedOpenAt = 2026-12-01 — page silencieuse : aucune date d’ouverture publiée pour 2027-2028
- description : « ALC Maurice n’accueille pas de nouvelle cohorte de Licence pour l’instant » — page silencieuse : les cinq pages ne parlent que d’ALU Rwanda (« currently open … at ALU Rwanda ») ; rien sur ALC Maurice
- steps[3] : « Les décisions sont rendues en général sous deux semaines » — absent des cinq URLs ; confirmé sur un article voisin du centre d’aide (…204000012921, modifié le 25 sept.) : « you can expect your admissi…
- Rentrée visée par la fiche : septembre 2027 — page silencieuse : la liste de rentrées du formulaire apply-now s’arrête à mai 2027 (liste par ailleurs périmée) ; aucune rentrée de septem…

### `ashesi_scholarship_2027`

- Verdict du relecteur : **verified_with_edits** — lue le `2026-09-29T15:08:11.000Z` (groupe G9).

| Source | URL | HTTP | Lue |
|---|---|---|---|
| overview | https://ashesi.edu.gh/scholarships/ | 200 | oui |
| eligibility | https://admissions.ashesi.edu.gh/courses/course/257-first-year-student | 200 | oui |
| benefits | https://ashesi.edu.gh/scholarships/ | 200 | oui |
| application | https://ashesi.edu.gh/how-to-apply/ | 200 | oui |
| cycle | https://ashesi.edu.gh/our-two-intake-cycle/ | 200 | oui |

**Écarts relevés**

- [minor] `eligibility[3] (organisme validant les équivalents)` — fiche : équivalent approuvé par la GTEC ; page : La page kind=eligibility (portail) écrit « National Accreditation Board of Ghana » alors que la page kind=application (how-to-apply) écrit « Ghana Tertiary Edu…
  - « Other equivalent exam results approved by the National Accreditation Board of Ghana. » (eligibility)
- [minor] `steps[2].detail (aide non demandable après l’admission)` — fiche : l’aide ne peut plus être demandée une fois l’admission prononcée ; page : Aucune des cinq pages ne contient cette règle ; elles disent seulement de remplir le formulaire d’aide et d’indiquer le montant. Affirmation non étayée, non co…
  - « To receive such assistance, be sure to complete the financial aid form and indicate the amount of assistance required. » (application)
- [minor] `cycle (échéance de la rentrée de janvier)` — fiche : quatre tours juin/août/octobre/décembre (steps[0]) et échéance 16 novembre 2026 (description) ; page : Deux pages officielles divergent entre elles : la page des deux rentrées dit « December deadline » pour janvier, le portail dit « Mid Nov » / 16 novembre 2026.…
  - « January Intake (Deadline: Mid Nov) » (eligibility)

**Corrections**

- appliquée : `steps[2].detail`

**Calendrier confirmé par la page**

- Démarche : les candidats à une bourse sont encouragés à postuler tôt — « Students applying for scholarships, for either intake, are also encouraged to apply sooner. »
- Calendrier : rentrée de septembre = dépôt complet avant l’échéance d’août ; rentrée de janvier = avant l’échéance de dé… — « Students looking to join the January intake must submit all documents by the December deadline. »

**Non vérifié (la page ne le dit pas ou n'a pas pu être lue)**

- steps[2] : « l’aide ne peut plus être demandée une fois l’admission prononcée » — page silencieuse (introuvable sur les cinq pages lues ; voir proposedEdits)
- cycle.estimatedOpenAt = 2026-09-01 (ouverture de la fenêtre 2027-2028) — page silencieuse : aucune date d’ouverture de fenêtre publiée ; le portail montre seulement l’année 2026/27
- Dates exactes des tours 2027-2028 (mi-août 2027 pour septembre 2027) — page silencieuse pour 2027-2028 ; seule l’échéance « Mid Aug » de la rentrée de septembre du cycle 2026/27 est publiée, sans jour ni année
- requirements[0] : formulaire de candidature « complété puis soumis sur le portail » — confirmé pour la soumission en ligne ; la page ajoute que les candidats de Licence peuvent aussi déposer un dossier papier (PDF) par courri…

### `auc_excellence_2027`

- Verdict du relecteur : **verified_with_edits** — lue le `2026-09-29T15:09:32.000Z` (groupe G9).

| Source | URL | HTTP | Lue |
|---|---|---|---|
| overview | https://www.aucegypt.edu/admissions/scholarships | 200 | oui |
| eligibility | https://www.aucegypt.edu/admissions/undergraduate | 200 | oui |
| benefits | https://www.aucegypt.edu/admissions/tuition-and-financial-assistance | 200 | oui |
| application | https://www.aucegypt.edu/admissions/scholarships/excellence-program | 200 | oui |
| cycle | https://www.aucegypt.edu/admissions/undergraduate | 200 | oui |

**Écarts relevés**

- [blocking] `cycle.dateConfidence / cycle.estimatedCloseAt` — fiche : estimated ; clôture estimée 2027-06-01 ; page : La page du cycle publie désormais l’admission régulière Fall 2027 au 1er juin 2027 (datetime="01/06/2027"). La date de clôture de la fiche est exacte mais n’es…
  - « 1 Jun Fall 2027 Regular Admission » (cycle)
- [blocking] `deadlineLabel (admission anticipée)` — fiche : admission anticipée vers le 1er mars 2027 (estimée) ; page : La page publie l’admission anticipée Fall 2027 au 1er février 2027 (datetime="01/02/2027"), pas au 1er mars.
  - « 1 Feb Fall 2027 Early Admission » (cycle)
- [blocking] `description (« Aucune date 2027–2028 n’est publiée … n’affiche pour l’instant q…` — fiche : Aucune date 2027–2028 n’est publiée ; page : Faux depuis la mise à jour du 24 sept. 2026 : la page des exigences de Licence liste Fall 2027 anticipée (1er février 2027) et régulière (1er juin 2027) en plu…
  - « 1 Nov Spring 2027 » (cycle)
- [minor] `description (« la page du programme, mise à jour le 16 octobre 2025 »)` — fiche : mise à jour le 16 octobre 2025 ; page : La page du programme affiche maintenant « Last Updated : Sep 07, 2026 » ; elle liste toujours uniquement Spring 2026 et Fall 2026 (l’affirmation « ne liste que…
  - « Last Updated : Sep 07, 2026 » (application)

**Corrections**

- appliquée : `cycle.dateConfidence`
- non appliquée : `cycle.status`
- appliquée : `cycle.closesAt`
- appliquée : `cycle.opensAt`
- appliquée : `deadlineLabel`
- appliquée : `description`
- non appliquée : `cycle.sourceUrl`

**Calendrier confirmé par la page**

- Calendrier : échéance Spring 2027 publiée au 1er novembre (attribut datetime 01/11/2026) — « 1 Nov Spring 2027 »
- Calendrier NOUVEAU : admission anticipée Fall 2027 le 1er février 2027 (attribut datetime 01/02/2027) — « 1 Feb Fall 2027 Early Admission »

**Non vérifié (la page ne le dit pas ou n'a pas pu être lue)**

- cycle.estimatedOpenAt = 2026-11-01 (ouverture de la fenêtre 2027-2028) — page silencieuse : aucune date d’ouverture des candidatures Fall 2027 n’est écrite
- Dates propres du programme de bourses pour Fall 2027 (priorité, liste d’attente) — page silencieuse : la page du programme (application, mise à jour 07/09/2026) ne liste encore que Spring 2026 / Fall 2026 ; la règle « prio…
- Bourse d’excellence 2027-2028 : mêmes catégories et pourcentages qu’en 2025-2026 — page silencieuse sur 2027 : les catégories et pourcentages lus sont ceux de la page du programme, dont le bloc « By the Numbers (2025 - 202…

### `australia_awards_africa_2028_forecast`

- Verdict du relecteur : **not_fully_verifiable** — lue le `2026-09-29T15:12:44.000Z` (groupe G7).

| Source | URL | HTTP | Lue |
|---|---|---|---|
| overview | https://www.dfat.gov.au/geo/africa-middle-east/development-assistance-in-sub-saharan-africa/australia-awards-… | 503 | **non** |
| eligibility | https://australiaawardsafrica.org/awards/apply/ | 200 | oui |
| benefits | https://www.dfat.gov.au/geo/africa-middle-east/development-assistance-in-sub-saharan-africa/australia-awards-… | 503 | **non** |
| application | https://oasis.dfat.gov.au/ | 200 | oui |
| cycle | https://australiaawardsafrica.org/awards/apply/ | 200 | oui |

**Écarts relevés**

- [minor] `deadlineLabel (fr/en) et description` — fiche : Prévision prochain cycle — environ du 1er février au 30 avril 2027, à reconfirmer ; page : Le site officiel annonce désormais l'ouverture du prochain appel en février 2027 ('from 1 February 2027') mais ne publie aucune date de clôture ; le 30 avril 2…
  - « Applications for the 2028 Intake will open in February 2027. » (cycle)
- [minor] `sources.eligibility` — fiche : https://australiaawardsafrica.org/awards/apply/ ; page : Cette page ne contient aucun critère d'éligibilité (seulement 'now closed' / 'will open in February 2027'). Les critères se trouvent dans le PDF du cycle 2027 …
  - « Applications for the Australia Awards Scholarships 2027 Intake are now closed. » (eligibility)
- [minor] `eligibility[4] (cinq ans d'expérience) — omission` — fiche : Avoir au moins cinq ans d’expérience professionnelle après le diplôme, pertinente pour le domaine choisi ; page : La FAQ ajoute une exception : trois ans suffisent pour un candidat en situation de handicap. Omission, pas contradiction ; aucune édition proposée.
  - « unless you have a disability in which case, you must demonstrate at least three years post-graduate work experience. » (eligibility)

**Corrections**

- appliquée : `deadlineLabel`
- appliquée : `description`

**Calendrier confirmé par la page**

- Le cycle 2027 est clos (cycle.sourceUrl) — « Applications for the Australia Awards Scholarships 2027 Intake are now closed. »
- Le cycle suivant (rentrée 2028) ouvre en février 2027 : statut 'forecast' correct, ouverture désormais annoncée au nive… — « Applications for the 2028 Intake will open in February 2027. »

**Non vérifié (la page ne le dit pas ou n'a pas pu être lue)**

- Contenu de la page DFAT (sources overview et benefits) : partenariat Australie-Afrique 2025-2030, absence de suspension ou de coupe budgétaire annoncée par le … — 403 / 503 / réponse vide : www.dfat.gov.au est inaccessible depuis cet environnement (Akamai). Ni la page ni le PDF du DFAT n'ont été lus ;…
- Date de clôture du cycle 2028 (30 avril 2027) et heure de clôture — page silencieuse : seules l'ouverture (février 2027 / 1er février 2027) et la clôture 2026 sont écrites ; la fiche doit rester forecast + e…
- Liste des pays éligibles, âge (au 1er février 2028), seuils de langue et domaines prioritaires pour l'appel 2028 — page silencieuse : seuls les critères du cycle 2027 sont publiés ; la fiche les présente comme critères 'de référence' à reconfirmer
- Passeport / diplôme / relevé 'certifiés' (requirements[0-1], steps[1]) — page silencieuse : le PDF 2027 dit seulement que les lauréats devront produire les originaux pour certification ; l'exigence de copies cert…
- Alerte à activer, 'PDF couleur lisibles' (steps[0], steps[3]) — page silencieuse : aucun texte lu sur une alerte ni sur le format couleur des PDF (probablement dans le guide OASIS non lu)
- Pages anciennes du même site (/awards/australia-awards-scholarships/ : 'Applications open annually, in September', pays et secteurs différents ; FAQ : 'Applica… — contenus périmés et non datés, non retenus comme preuve ; ils ne contredisent pas la fiche mais ne la confirment pas non plus

### `brunei_government_scholarship_2027_forecast`

- Verdict du relecteur : **verified** — lue le `2026-09-29T15:04:12.000Z` (groupe G3).

| Source | URL | HTTP | Lue |
|---|---|---|---|
| overview | https://www.mfa.gov.bn/pages/online-bdgs.aspx | 200 | oui |
| eligibility | https://www.mfa.gov.bn/pages/online-bdgs.aspx | 200 | oui |
| benefits | https://www.mfa.gov.bn/pages/online-bdgs.aspx | 200 | oui |
| application | https://www.mfa.gov.bn/pages/online-bdgs.aspx | 200 | oui |
| cycle | https://www.mfa.gov.bn/pages/online-bdgs.aspx | 200 | oui |

**Écarts relevés**

- [minor] `levelLabel / levels` — fiche : Licence et Master (bachelor, master) ; page : La page inclut aussi le niveau Diploma (diplôme). Omission, pas une contradiction : aucune correction proposée.
  - « pursue studies at the Diploma, Undergraduate Degree and Postgraduate Master's Degree level » (overview)

**Calendrier confirmé par la page**

- Calendrier : cycle précédent (2026/2027) ouvert le 15 décembre 2025, base de l’estimation 15 décembre 2026 — « for the academic session 2026 / 2027 will open on 15 December 2025 »
- Calendrier : cycle précédent clos le 15 février 2026, base de l’estimation 15 février 2027 — « The closing date for application of the Scholarship is 15 February 2026. »

**Non vérifié (la page ne le dit pas ou n'a pas pu être lue)**

- Dates exactes de la session 2027/2028 (ouverture ~15 décembre 2026, clôture ~15 février 2027) — page silencieuse : seule la session 2026/2027 est annoncée ; la fiche reste correctement forecast + estimated
- Libellé « Financement complet » (fullyFunded) — la page liste les prestations (scolarité, vols, allocations, logement, assurance) sans employer l’expression « fully funded » ; caractérisa…

### `chevening_2027`

- Verdict du relecteur : **verified** — lue le `2026-09-29T15:09:19.000Z` (groupe G5).

| Source | URL | HTTP | Lue |
|---|---|---|---|
| overview | https://www.chevening.org/scholarships/ | 403 | oui |
| eligibility | https://www.chevening.org/resource-hub/guidance/eligibility/ | None | oui |
| benefits | https://www.chevening.org/faqs/what-does-a-chevening-scholarship-cover/ | 403 | oui |
| application | https://www.chevening.org/apply/ | None | oui |
| cycle | https://www.chevening.org/scholarships/application-timeline/ | 403 | oui |

**Calendrier confirmé par la page**

- Ouverture : 4 août 2026 à 11 h UTC (opensAt de la fiche correct) — « 4 August 2026 Applications open at 11:00 UTC »
- Clôture : 6 octobre 2026 à 11 h UTC (closesAt de la fiche correct ; cycle encore ouvert au 29/09/2026) — « The deadline for applications is 6 October 2026 at 11:00 UTC. »

**Non vérifié (la page ne le dit pas ou n'a pas pu être lue)**

- requirements[4] : « Passeport/pièce d’identité et diplômes/relevés selon les étapes » — page silencieuse sur la liste exacte des pièces : les pages lues disent seulement « upload all their documentation » avant l’entretien ; le…
- Nuance sur « Financement complet » : bourses partielles (« part award ») et plafond de frais pour un MBA — un extrait de résultat WebSearch attaché à l’URL de la FAQ « What does a Chevening Scholarship cover? » mentionne ces deux points, mais l’e…
- Citations lues via extraction WebFetch, pas via HTML brut — chevening.org refuse curl (403 Akamai) ; aucun contournement tenté. Les citations retenues sont celles reproduites à l’identique dans au mo…

### `daad_epos_2027`

- Verdict du relecteur : **verified_with_edits** — lue le `2026-09-29T15:12:42.000Z` (groupe G6).

| Source | URL | HTTP | Lue |
|---|---|---|---|
| overview | https://www.daad.de/en/information-services-for-higher-education-institutions/further-information-on-daad-pro… | 200 | oui |
| eligibility | https://www2.daad.de/deutschland/stipendium/datenbank/en/21148-scholarship-database/?detail=50076777 | 200 | oui |
| benefits | https://www2.daad.de/deutschland/stipendium/datenbank/en/21148-scholarship-database/?detail=50076777 | 200 | oui |
| application | https://www2.daad.de/deutschland/stipendium/datenbank/en/21148-scholarship-database/?detail=50076777 | 200 | oui |
| cycle | https://static.daad.de/media/daad_de/pdfs_nicht_barrierefrei/in-deutschland-studieren-forschen-lehren/daad_ep… | 200 | oui |

**Écarts relevés**

- [minor] `advantages[2] (forfait voyage)` — fiche : Forfait voyage vers l’Allemagne et retour pris en charge par le DAAD / Travel allowance to Germany and back covered by DAAD ; page : L’allocation de voyage est conditionnelle : elle n’est pas versée si ces frais sont couverts par le pays d’origine ou une autre source
  - « Travel allowance, unless these expenses are covered by the home country or another source of funding » (benefits)
- [minor] `eligibility[4] (séjour en Allemagne)` — fiche : Ne pas avoir séjourné en Allemagne plus de quinze mois à la date de la candidature / … at the date of application ; page : Le décompte des 15 mois s’apprécie à la date limite de candidature, pas à la date où l’on postule
  - « Applicants who have been resident in Germany for longer than 15 months at the application deadline cannot be considered » (eligibility)

**Corrections**

- appliquée : `advantages[2]`
- appliquée : `eligibility[4]`

**Calendrier confirmé par la page**

- Pas de date limite unique : la fiche DAAD renvoie à chaque cursus — « Depending on chosen study programme; please check scholarship brochure or the website of your chosen study programme. »
- Liste des dates limites du DAAD pour l’admission 2027/2028 (édition 06/2026) — « Application Deadlines for Intake 2027/2028 Development-Related Postgraduate Courses »

**Non vérifié (la page ne le dit pas ou n'a pas pu être lue)**

- Cycle : estimatedOpenAt 2026-05-15 et estimatedCloseAt 2027-01-31, et libellé « du printemps 2026 à fin janvier 2027 » — AUCUNE des pages ne donne ces dates pour 2027/2028 (le PDF de juin 2026 ne contient que « see website of the course »). La fiche doit donc …
- Statut « forecast » au 29/09/2026 alors que l’ouverture estimée (15 mai 2026) est passée — sans date confirmée par une page, la fiche ne peut être ni open (exige des dates confirmées) ni requalifiée ; certains cursus ont sans dout…
- Anglais : « en règle générale IELTS 6 ou TOEFL 550 papier / 213 ordinateur / 80 internet » — page silencieuse sur ces seuils (la base DAAD dit seulement « according to the regulations of the respective course » et « English – IELTS …
- CV Europass « signé à la main »; lettre de motivation « signée à la main, deux pages maximum, rattachée à l’emploi actuel » — page silencieuse sur la signature manuscrite et les deux pages (la base DAAD cite l’Europass et la lettre unique, sans ces précisions). Ret…
- Lettre de recommandation « de date récente » — la base DAAD écrit « must be of current date » selon un rendu du résumeur non répété à l’identique ; le FAQ 10/2019 écrit « of recent date …
- Aucune admission préalable au Master n’est exigée pour candidater à la bourse — page silencieuse (cinq sources). Retrouvé dans l’EPOS-FAQ 10/2019 : « Do I need to be accepted for the masters programme before I apply for…

### `daad_helmut_schmidt_2027`

- Verdict du relecteur : **verified** — lue le `2026-09-29T15:04:51.000Z` (groupe G6).

| Source | URL | HTTP | Lue |
|---|---|---|---|
| overview | https://www.daad.de/en/information-services-for-higher-education-institutions/further-information-on-daad-pro… | 200 | oui |
| eligibility | https://static.daad.de/media/daad_de/pdfs_nicht_barrierefrei/in-deutschland-studieren-forschen-lehren/daad_he… | 200 | oui |
| benefits | https://static.daad.de/media/daad_de/pdfs_nicht_barrierefrei/in-deutschland-studieren-forschen-lehren/daad_he… | 200 | oui |
| application | https://static.daad.de/media/daad_de/pdfs_nicht_barrierefrei/in-deutschland-studieren-forschen-lehren/daad_he… | 200 | oui |
| cycle | https://static.daad.de/media/daad_de/pdfs_nicht_barrierefrei/in-deutschland-studieren-forschen-lehren/daad_he… | 200 | oui |

**Calendrier confirmé par la page**

- Sélection en octobre/novembre 2026 — « The selection will be made by a selection committee in October/November 2026. »
- Fenêtre de candidature de l’appel 2027 : 1er juin – 31 juillet 2026 (donc close au 29/09/2026) — « The application period for all seven higher education institutions is from 1 June until 31 July 2026. »

**Non vérifié (la page ne le dit pas ou n'a pas pu être lue)**

- « prochain appel attendu vers juin 2027 » (deadlineLabel FR/EN et statut de l’extrapolation) — page silencieuse : le PDF (édition 05/2026) et la page de présentation ne décrivent que la fenêtre du 1er juin au 31 juillet 2026 et n’anno…
- Heures exactes d’ouverture et de clôture (00:00 le 1er juin, 23:59:59 UTC le 31 juillet) — le PDF donne les jours, pas les heures ; les bornes horaires de la fiche sont une convention du catalogue
- « Formulaire Helmut-Schmidt » (requirements[0]) — le PDF écrit « the DAAD “Application Form” » et « a ticked off checklist and list of criteria, signed by hand » ; l’intitulé « Helmut-Schmi…
- « Financement complet du programme » (fundingLabel) / fundingType fully_funded — le PDF liste les prestations (allocation, scolarité, assurance, voyage) sans employer les mots « full funding » ; le contenu de la liste co…
- Contenu de la page de présentation lu via WebFetch (HTML brut inaccessible par curl : 403) — citations de la page overview rendues par un outil de résumé, non vérifiées sur le HTML brut ; le PDF, source des quatre autres kinds, est …

### `eiffel_excellence_master_2027`

- Verdict du relecteur : **verified_with_edits** — lue le `2026-09-29T15:07:35.000Z` (groupe G8).

| Source | URL | HTTP | Lue |
|---|---|---|---|
| overview | https://www.campusfrance.org/en/france-excellence-eiffel-scholarship-program | 200 | oui |
| eligibility | https://www.campusfrance.org/en/the-france-excellence-eiffel-scholarship-program | 200 | oui |
| benefits | https://www.campusfrance.org/en/france-excellence-eiffel-scholarship-implementation | 200 | oui |
| application | https://www.campusfrance.org/fr/faq-appel-a-candidature-a-la-bourse-eiffel | 200 | oui |
| cycle | https://ressources.campusfrance.org/pratique/programmes/en/plaquette_eiffel_1_en.pdf | 200 | oui |

**Écarts relevés**

- [minor] `advantages[2] (voyage international)` — fiche : Prise en charge du voyage international vers la France et du retour, ainsi que du transport national ; page : Billet remboursé sur justificatifs, plafonné à 50 % du tarif maximal fixé par le ministère pour le pays concerné (aller comme retour)
  - « reimbursed in an amount not to exceed 50% of the maximum rate set by the Ministry for Europe and Foreign Affairs » (benefits)
- [minor] `advantages[1] (durée)` — fiche : 12 mois en Master 2, 24 mois en Master 1 (durées présentées comme fixes ; ingénieur omis) ; page : Ce sont des maxima (12 / 24 / 36 mois pour un diplôme d’ingénieur)
  - « a maximum of 12 months when enrolling in an M2 » (eligibility)

**Corrections**

- appliquée : `advantages[1]`
- appliquée : `advantages[2]`

**Calendrier confirmé par la page**

- Calendrier récurrent : appel fin septembre — « Online call for applications: end of September »
- Calendrier récurrent : dépôt des établissements première semaine de janvier — « Deadline for institutions to send applications to Campus France: 1st week of January »

**Non vérifié (la page ne le dit pas ou n'a pas pu être lue)**

- Dates du cycle 2027–2028 (ouverture estimée 2026-09-30, clôture estimée 2027-01-08) — Page silencieuse : aucune mention de 2027 dans les cinq sources (HTML brut compris) ; le site affiche encore la session 2026. La fiche rest…
- Montant de 1 200 EUR pour la promotion 2027–2028 — Les pages datent le montant « from January 2026 » ; rien sur 2027.
- Pièces du dossier : diplômes, relevés, CV, lettre de motivation situant le projet dans un domaine prioritaire — Page silencieuse : la liste des pièces figure dans le guide pratique réservé aux établissements (non public). Seuls passeport/carte d’ident…
- Date limite interne de l’établissement « largement antérieure » à la date nationale — Les pages disent seulement de contacter l’établissement pour connaître ses procédures et dates limites.
- « l’établissement classe ses candidats » — La brochure écrit « pre-selected by their institution » ; la notion de classement n’apparaît pas dans les pages lues.

### `erasmus_mundus_joint_masters_2027`

- Verdict du relecteur : **verified_with_edits** — lue le `2026-09-29T15:07:54.000Z` (groupe G8).

| Source | URL | HTTP | Lue |
|---|---|---|---|
| overview | https://erasmus-plus.ec.europa.eu/opportunities/individuals/students/erasmus-mundus-joint-masters | 200 | oui |
| eligibility | https://erasmus-plus.ec.europa.eu/programme-guide/part-b/key-action-2/erasmus-mundus-action | 200 | oui |
| benefits | https://erasmus-plus.ec.europa.eu/programme-guide/part-b/key-action-2/erasmus-mundus-action | 200 | oui |
| application | https://www.eacea.ec.europa.eu/scholarships/erasmus-mundus-catalogue_en | 200 | oui |
| cycle | https://www.eacea.ec.europa.eu/scholarships/erasmus-mundus-catalogue_en | 200 | oui |

**Écarts relevés**

- [minor] `eligibility[5] (master du catalogue = bourse)` — fiche : Postuler à un master figurant au catalogue Erasmus Mundus : seuls ces programmes ouvrent droit à la bourse (lecture possible : tout master … ; page : Certains masters du catalogue n’offrent pas de bourse (fin de période de financement ou usage temporaire du label)
  - « While many programs offer Erasmus Mundus scholarships, some do not » (application)

**Corrections**

- appliquée : `eligibility[5]`

**Calendrier confirmé par la page**

- Calendrier : octobre à janvier pour la plupart des masters — « Most master’s programmes require applications to be submitted between October and January for courses commencing the following academic year. »

**Non vérifié (la page ne le dit pas ou n'a pas pu être lue)**

- Dates du cycle 2027–2028 (estimatedOpenAt 2026-10-01, estimatedCloseAt 2027-01-31) — Page silencieuse sur des dates précises : chaque consortium a son calendrier. Seule la fenêtre générale « October and January » est écrite …
- La nouvelle promotion du catalogue apparaît « à l’automne » — Les pages disent seulement « added to the list each year » / « updated annually » ; la saison n’est pas écrite. Le filtre du catalogue s’ar…
- Pièces du dossier (preuve de langue, CV, lettre de motivation, recommandations, passeport, visa) — Page silencieuse : chaque consortium publie sa propre liste sur le site du master. La fiche le dit déjà.
- Le consortium notifie lui-même le résultat — Seule la responsabilité exclusive de la sélection est écrite, pas la notification.

### `eth_zurich_esop_2027`

- Verdict du relecteur : **verified_with_edits** — lue le `2026-09-29T15:06:09.000Z` (groupe G8).

| Source | URL | HTTP | Lue |
|---|---|---|---|
| overview | https://ethz.ch/students/en/studies/financial/scholarships/excellencescholarship.html | 200 | oui |
| eligibility | https://ethz.ch/students/en/studies/financial/scholarships/excellencescholarship.html | 200 | oui |
| benefits | https://ethz.ch/students/en/studies/financial/scholarships/excellencescholarship.html | 200 | oui |
| application | https://ethz.ch/students/en/studies/financial/scholarships/excellencescholarship.html | 200 | oui |
| cycle | https://ethz.ch/students/en/studies/financial/scholarships/excellencescholarship.html | 200 | oui |

**Écarts relevés**

- [blocking] `advantages[0] (allocation semestrielle)` — fiche : 12 000 CHF par semestre pour les dépenses d’études et de vie (aucune mention du relèvement) ; page : 12 000 CHF par semestre, mais 13 500 CHF à partir de HS27 (rentrée 2027/28, celle que couvre la fiche)
  - « CHF 12'000 per semester, from HS27 onwards 13'500 CHF » (benefits)
- [minor] `cycle.closesAt (heure de clôture, source interne incohérente)` — fiche : 2026-11-30T10:59:00.000Z (11 h 59 CET) ; deadlineLabel « 11 h 59 CET » ; page : La phrase d’introduction en gras dit 11.59h MEZ ; un paragraphe plus bas dit 12.59 MEZ. Le jour (30 novembre 2026) est identique dans les deux.
  - « November 1 - 30 (12.59 MEZ) » (cycle)

**Corrections**

- appliquée : `advantages[0]`

**Calendrier confirmé par la page**

- Fenêtre de candidature du 1er au 30 novembre 2026 pour une entrée en HS27 — « The next application window is open Nov, 1 - Nov, 30 2026, 11.59h, MEZ for a start in the Master programme in HS27. »

**Non vérifié (la page ne le dit pas ou n'a pas pu être lue)**

- Heure exacte de clôture le 30 novembre 2026 (11 h 59 vs 12 h 59 CET) — La page se contredit (11.59h dans la phrase principale, 12.59 plus bas). Aucune modification proposée : la fiche suit la phrase principale …
- CV comme pièce du dossier — Page silencieuse sur la liste des pièces d’admission Master (renvoie aux « documents for the Master admission ») ; seule mention indirecte …
- Statut « forecast » au 29/09/2026 — Cohérent : la fenêtre ouvre le 1er novembre 2026, donc pas encore ouverte. La page écrit pourtant « is open » au présent (formulation de la…

### `heydar_aliyev_grant_2027_forecast`

- Verdict du relecteur : **verified** — lue le `2026-09-29T15:05:58.000Z` (groupe G3).

| Source | URL | HTTP | Lue |
|---|---|---|---|
| overview | https://studyinazerbaijan.edu.az/financial-support | 200 | oui |
| eligibility | https://studyinazerbaijan.edu.az/H.Aliyev_IEG_CALL_18.04.pdf | 200 | oui |
| benefits | https://studyinazerbaijan.edu.az/H.Aliyev_IEG_CALL_18.04.pdf | 200 | oui |
| application | https://studyinazerbaijan.edu.az/financial-support | 200 | oui |
| cycle | https://studyinazerbaijan.edu.az/H.Aliyev_IEG_CALL_18.04.pdf | 200 | oui |

**Écarts relevés**

- [minor] `levelLabel / levels` — fiche : Licence et Master (bachelor, master) ; page : Le programme couvre aussi les cours préparatoires, la médecine générale, la résidence médicale et le doctorat (PhD). Omission de périmètre, pas une contradicti…
  - « Bachelor’s Program General medicine Program Master’s Program Medical Residency Program Doctoral (PhD) Program » (overview)

**Calendrier confirmé par la page**

- Démarche : première étape auprès des autorités gouvernementales du pays (nomination), 16 février – 15 avril 2026 — « From Feb 16 to April 15, 2026 »
- Calendrier : dernière date de dépôt le 15 avril 2026 à 18 h heure de Bakou — « The last date of the submission is April 15, 2026 at 6 PM Baku time. »

**Non vérifié (la page ne le dit pas ou n'a pas pu être lue)**

- Dates 2027-2028 (nomination ~16 février – 15 avril 2027 à 18 h Bakou ; SIACAS 1er–10 juin 2027) — page silencieuse : seul l’appel 2026-2027 est publié (PDF et /news, dernier communiqué du 11 février 2026) ; la fiche reste correctement fo…
- Filière anglaise : « ou prouver une scolarité antérieure dans la langue du cursus » (eligibility[4]) — pour l’anglais, le PDF liste les scores IELTS/TOEFL puis, en puce séparée sans « or », « the language of study of the previous education mu…
- « permis de séjour temporaire renouvelé chaque année universitaire » (advantages[4]) — le PDF dit « temporary residence permit … for the period of each academic year » ; « renouvelé » est une paraphrase non littérale (sens coh…

### `jj_wbgsp_2027_forecast`

- Verdict du relecteur : **verified_with_edits** — lue le `2026-09-29T15:06:54.000Z` (groupe G8).

| Source | URL | HTTP | Lue |
|---|---|---|---|
| overview | https://www.worldbank.org/en/programs/scholarships/jj-wbgsp | 200 | oui |
| eligibility | https://thedocs.worldbank.org/en/doc/912b7c054651373f33bb2e3ef1757772-0050052025/original/2026-Application-Gu… | 200 | oui |
| benefits | https://www.worldbank.org/en/programs/scholarships/jj-wbgsp | 200 | oui |
| application | https://www.worldbank.org/en/programs/scholarships/jj-wbgsp | 200 | oui |
| cycle | https://www.worldbank.org/en/programs/scholarships/jj-wbgsp | 200 | oui |

**Écarts relevés**

- [minor] `sources.eligibility` — fiche : Guide 2026 fenêtre 1 (mis à jour octobre 2025), qui donne comme date limite le 27 février 2026 ; page : La page officielle renvoie au guide 2027 fenêtre 1 (mis à jour août 2026), date limite 26 février 2027 ; contenu identique à 2026 hors dates et annexes pays
  - « Application Deadline: February 27, 2026 (for Window 1 programs only) » (eligibility)
- [minor] `description / steps[0] (programmes participants « à reconfirmer »)` — fiche : La liste des programmes participants et les critères détaillés restent à reconfirmer à l’ouverture ; page : La liste des programmes participants 2027 est publiée (page datée du 21 août 2026) et les lignes directrices 2027 fenêtre 1 sont publiées (« Updated August 202…
  - « JJ/WBGSP Participating Programs for 2027 Scholarship Applications » (overview)

**Corrections**

- appliquée : `sources.eligibility`
- appliquée : `description`

**Calendrier confirmé par la page**

- Fenêtre 1 : 18 janvier au 26 février 2027 — « Application Window #1 from January 18 to February 26, 2027 »
- Fenêtre 2 : 29 mars au 21 mai 2027 — « Application Window #2 from March 29 to May 21, 2027 »

**Non vérifié (la page ne le dit pas ou n'a pas pu être lue)**

- Heure de clôture de la fenêtre 1 (closesAt 2027-02-26T23:59:59Z) — Page et guide donnent seulement « February 26, 2027 », sans heure ni fuseau ; la fiche l’indique déjà (fin de journée UTC retenue). Aucune …
- Fenêtre applicable à chaque Master participant (1 ou 2) — Les listes par fenêtre sont sur des pages liées (non lues) ; la page overview dit seulement que le processus est organisé en deux tours sel…
- Liste des fragile states / FAQ fenêtre 1 (comptage du temps partiel) — FAQ 2027 non lue (hors des cinq sources de la fiche).
- steps[0] : « activer l’alerte pour reconfirmer les programmes participants et les critères dès l’ouverture » — Conseil de prudence, non contredit ; la liste des programmes est désormais publiée mais l’ouverture (18/01/2027) n’a pas eu lieu. Modificat…

### `kazakhstan_foreign_students_2027_forecast`

- Verdict du relecteur : **not_fully_verifiable** — lue le `2026-09-29T15:04:57.000Z` (groupe G3).

| Source | URL | HTTP | Lue |
|---|---|---|---|
| overview | https://oq.gov.kz/en/b-ship | 200 | oui |
| eligibility | https://oq.gov.kz/en/news/1504 | 200 | oui |
| benefits | https://oq.gov.kz/en/b-ship | 200 | oui |
| application | https://studyin.kz/admission | 200 | **non** |
| cycle | https://oq.gov.kz/en/news/1504 | 200 | oui |

**Écarts relevés**

- [minor] `eligibility[2] (Master : moyenne minimale)` — fiche : moyenne d’au moins 3,0/4,0 « selon l’appel 2026 » ; page : La page générale (overview) indique 2,33/4 ; le communiqué de l’appel 2026 (news/1504) indique 3,0/4,0. La fiche suit l’appel 2026 et l’attribue à celui-ci : p…
  - « having diploma of bachelor or specialist with at least 2.33 (out of 4) GPA or its equivalent in educational institutions. » (overview)
- [minor] `steps[2] / sources.application (portail de candidature)` — fiche : Candidater sur Study in Kazakhstan (studyin.kz/admission) ; page : La page générale (overview) renvoie encore vers l’ancien portail enic-kazakhstan.edu.kz ; l’appel 2026 (news/1504) cite studyin.kz/admission. La fiche suit l’a…
  - « LINK TO SUBMIT DOCUMENTS: https://enic-kazakhstan.edu.kz/en/fellowship_programme/universities » (overview)

**Calendrier confirmé par la page**

- Calendrier : cycle 2026, du 30 mars au 31 mai 2026 jusqu’à 23 h 59 heure d’Astana, lien studyin.kz/admission (base de l… — « Applicants can apply online from 30 March to 31 May 2026 until 23:59 Astana time at the following link: https://studyin.kz/admission. »

**Non vérifié (la page ne le dit pas ou n'a pas pu être lue)**

- Contenu du portail de candidature https://studyin.kz/admission (sources.application) — JavaScript seul : coquille React vide, aucun texte servi ; source non lue, d’où le verdict not_fully_verifiable
- Dates 2027 (30 mars – 31 mai 2027, 23 h 59 Astana) — page silencieuse : seules les dates 2026 sont publiées ; la fiche reste correctement forecast + estimated. La recherche restreinte à oq.gov…
- « Frais de scolarité couverts pendant la durée officielle » (advantages[0]) — la page dit « full cost of tuition fees » sans préciser la durée officielle des études
- Pièce d’identité « valide » (eligibility[4]) — la page dit « Identity document (including a refugee certificate) » sans mentionner la validité
- Heure d’ouverture estimée (estimatedOpenAt 2027-03-30T00:00:00.000Z) — la page 2026 donne la date d’ouverture (30 mars) sans heure ; seule la clôture est horodatée (23 h 59 heure d’Astana = 18 h 59 UTC, cohéren…

### `knight_hennessy_2027`

- Verdict du relecteur : **verified** — lue le `2026-09-29T15:01:44.000Z` (groupe G7).

| Source | URL | HTTP | Lue |
|---|---|---|---|
| overview | https://knight-hennessy.stanford.edu/ | 200 | oui |
| eligibility | https://knight-hennessy.stanford.edu/admission/before-you-apply/eligibility | 200 | oui |
| benefits | https://knight-hennessy.stanford.edu/program-overview/funding | 200 | oui |
| application | https://apply.knight-hennessy.stanford.edu/apply/ | 200 | oui |
| cycle | https://knight-hennessy.stanford.edu/admission/preparing-your-applications/your-applications | 200 | oui |

**Calendrier confirmé par la page**

- Clôture KHS le 6 octobre 2026 (date) — « October 6, 2026 »
- Heure de clôture KHS : 13 h heure du Pacifique. Le 6 oct. 2026 le Pacifique est en heure d'été (PDT, UTC-7) : 20:00 UTC… — « 1:00 pm Pacific Time »

**Non vérifié (la page ne le dit pas ou n'a pas pu être lue)**

- 'Manquer l'une des deux échéances annule la candidature' (steps[3]) — La page /application-deadlines dit seulement qu'une candidature de programme déposée après le 1er décembre 2026 rend le candidat inéligible…
- Détails du contenu de l'essai, du CV et des lettres (nombre de lettres, formats) — Hors périmètre des cinq URLs (sous-pages Resume / Recommendation Letters / Short Answers non ouvertes) ; la fiche ne fait que les nommer.
- Détail des programmes Stanford ouvrant droit aux 6 trimestres / 1-2 ans de financement pour les Masters — Le tableau de la page funding donne 'Up to six academic quarters' pour MA/MS/MBA/MPP ; la fiche dit 'jusqu'à trois ans' (maximum), cohérent…

### `mastercard_foundation_scholars_2027`

- Verdict du relecteur : **verified** — lue le `2026-09-29T15:05:05.000Z` (groupe G10).

| Source | URL | HTTP | Lue |
|---|---|---|---|
| overview | https://mastercardfdn.org/en/what-we-do/our-programs/mastercard-foundation-scholars-program/ | 200 | oui |
| eligibility | https://mastercardfdn.org/en/articles/becoming-a-mastercard-foundation-scholar/ | 200 | oui |
| benefits | https://mastercardfdn.org/en/frequently-asked-questions/ | 200 | oui |
| application | https://mastercardfdn.org/en/what-we-do/our-programs/mastercard-foundation-scholars-program/where-to-apply/ | 200 | oui |
| cycle | https://mastercardfdn.org/en/frequently-asked-questions/ | 200 | oui |

**Calendrier confirmé par la page**

- No single deadline: each partner sets its own (deadlineLabel) — « Each partner in the Mastercard Foundation Scholars Program sets their own deadline. »

**Non vérifié (la page ne le dit pas ou n'a pas pu être lue)**

- cycle.estimatedOpenAt 2026-08-10 and estimatedCloseAt 2027-06-30 — page silencieuse — no source gives a programme-wide window (partners set their own). The window is an editorial projection; the deadlineLab…
- Advantages[4] 'accès au réseau des Scholars et Alumni' — not on the FAQ (benefits source); present on the overview page as the Alumni Network — minor, no edit needed
- Individual partner windows and criteria (e.g. UP, UCT) — out of scope of this record; the Foundation's feed lists UP as 'open' in English and 'closed' in French, so use partner sites for dates
- Fiche step 1 wording 'filtres pays, niveau d’étude et fenêtre' — country filter — the country filter label is only in embedded script, not visible text, because the list itself is JavaScript-rendered

### `mccall_macbain_2027`

- Verdict du relecteur : **verified_with_edits** — lue le `2026-09-29T15:01:38.000Z` (groupe G5).

| Source | URL | HTTP | Lue |
|---|---|---|---|
| overview | https://mccallmacbainscholars.org/ | 200 | oui |
| eligibility | https://mccallmacbainscholars.org/apply/ | 200 | oui |
| benefits | https://mccallmacbainscholars.org/faq/ | 200 | oui |
| application | https://apply.mccallmacbainscholars.org/apply/ | 200 | oui |
| cycle | https://mccallmacbainscholars.org/apply/ | 200 | oui |

**Écarts relevés**

- [blocking] `deadlineLabel (FR et EN)` — fiche : FR : « Ouvert — clôture pour les candidats internationaux le 19 août 2026 à 16 h (heure de l’Est) » ; EN : « Open — international deadline … ; page : Les candidatures 2027 sont closes ; les deux dates limites (19 août et 23 septembre 2026) sont passées. cycle.status=closed est correct, mais le libellé affich…
  - « Applications for Summer/Fall 2027 are closed. » (cycle)
- [minor] `description (FR et EN)` — fiche : Présente les deux dates limites au présent (« publie deux dates limites ») sans dire que les candidatures sont closes ; page : Les candidatures sont closes ; les dates sont au passé (« had the following deadline »).
  - « Students and graduates of universities located in other countries had the following deadline: » (cycle)
- [minor] `source overview (page d’accueil) vs pages apply / portail` — fiche : cycle.status=closed (appuyé sur apply et portail) ; page : La page d’accueil affirme encore le contraire ; c’est le texte d’accueil qui est périmé : apply et portail sont concordants et les dates limites sont passées. …
  - « Applications are open for Summer/Fall 2027 entry. » (overview)

**Corrections**

- appliquée : `deadlineLabel`
- appliquée : `description (correction mineure, optionnelle)`

**Calendrier confirmé par la page**

- Statut du cycle 2027 : candidatures closes (fiche cycle.status=closed correct au 29/09/2026) — « Applications for Summer/Fall 2027 are closed. »
- Clôture internationale : 19 août 2026 à 16 h heure de l’Est (= 2026-08-19T20:00:00Z en heure d’été, closesAt de la fich… — « August 19, 2026 4:00 PM Eastern Time »

**Non vérifié (la page ne le dit pas ou n'a pas pu être lue)**

- Réponses courtes, essais et CV dans le dossier de bourse (requirements[2], partie « Réponses courtes, essais, CV ») — page silencieuse : seuls les relevés de notes non officiels et les deux références sont décrits (FAQ) ; le formulaire du portail n’est pas …
- Informations personnelles, parcours d’études et activités de leadership (requirements[1]) — page silencieuse / portail fermé : contenu du formulaire non consultable
- Dates du cycle suivant (cohorte 2028) — page silencieuse : aucune date de réouverture ni de clôture pour 2028 sur apply, accueil, FAQ, program ni news-updates. La fiche n’en inven…

### `open_doors_russia_2027`

- Verdict du relecteur : **verified_with_edits** — lue le `2026-09-29T15:06:33.000Z` (groupe G4).

| Source | URL | HTTP | Lue |
|---|---|---|---|
| overview | https://od.globaluni.ru/about | 200 | oui |
| eligibility | https://od.globaluni.ru/index.php/rules | 200 | oui |
| benefits | https://od.globaluni.ru/about | 200 | oui |
| application | https://od.globaluni.ru/ | 200 | oui |
| cycle | https://od.globaluni.ru/ | 200 | oui |

**Écarts relevés**

- [blocking] `cycle.status` — fiche : status: forecast ; deadlineLabel « Prochain cycle confirmé — inscriptions du 20 août au 1er novembre 2026 » ; page : Les inscriptions ont ouvert le 20 août 2026 et sont en cours jusqu’au 1er novembre 2026 : au 29/09/2026 le cycle est ouvert, avec dates confirmées et clôture f…
  - « Registration for the Bachelor’s, Master’s, Doctoral, and Postdoctoral tracks is open from August 20 to November 1, 2026. » (eligibility)
- [minor] `fundingLabel / advantages` — fiche : Frais de scolarité couverts ; vie et voyage non couverts ; page : La FAQ précise que la bourse couvre les frais de scolarité ET verse une allocation mensuelle, dont le montant varie selon l’université. La mention « vie … non …
  - « The scholarship covers tuition fees and provides a monthly stipend. » (application)
- [minor] `steps[2] (Passer les étapes)` — fiche : Première étape jusqu’au 13 novembre 2026 (portfolio et test) ; page : La première étape dure jusqu’au 13 novembre (résultats), mais le portfolio doit être déposé avant la clôture des inscriptions le 1er novembre ; après cette dat…
  - « Participants may submit their portfolio at any time before registration closes. » (eligibility)
- [minor] `eligibility[1] et eligibility[2]` — fiche : Licence : 16 à 23 ans ; Master : 20 à 33 ans (sans date de référence) ; page : L’âge s’apprécie à la date d’ouverture des inscriptions (20 août 2026).
  - « Applicants aged between 20 and 33 as of the registration opening date are eligible to participate in the Master’s track of the Open Doors » (eligibility)

**Corrections**

- appliquée : `cycle.status`
- non appliquée : `cycle.dateConfidence`
- appliquée : `deadlineLabel`
- appliquée : `tags`
- appliquée : `fundingLabel`
- appliquée : `advantages (ajouter un élément)`
- appliquée : `steps[2] description (index 2 FR / index 3 EN)`
- appliquée : `eligibility[1] (Licence)`
- appliquée : `eligibility[2] (Master)`

**Calendrier confirmé par la page**

- Cycle : début des inscriptions le 20 août 2026 (déjà passé au 29/09/2026) — « 20 August 2026 Start of the Open Doors registration »
- Clôture des inscriptions le 1er novembre 2026 (date écrite ; heure et fuseau non précisés) — « 1 November 2026 Open Doors registration deadline »

**Non vérifié (la page ne le dit pas ou n'a pas pu être lue)**

- cycle.academicYear « 2027-2028 » — page silencieuse : le règlement est celui de « 2026 » et précise que les lauréats peuvent être admis l’année du concours ou l’année suivant…
- Heure et fuseau horaire de la clôture du 1er novembre 2026 (fiche : 23:59:59 UTC) — page silencieuse : seule la date est écrite
- Montant de l’allocation mensuelle — la page renvoie à chaque université (« The amount varies depending on the university »)
- Bourse du gouvernement russe complémentaire (décret n° 1837) pour les lauréats étudiant en russe — mentionnée au règlement (art. 13-14) sous conditions ; non reprise dans la fiche, montant non précisé

### `qatar_university_international_2027_forecast`

- Verdict du relecteur : **verified** — lue le `2026-09-29T15:06:40.000Z` (groupe G3).

| Source | URL | HTTP | Lue |
|---|---|---|---|
| overview | https://www.qu.edu.qa/en-us/students/admission/scholarships/Pages/types.aspx | 200 | oui |
| eligibility | https://www.qu.edu.qa/en-us/students/admission/scholarships/Pages/types.aspx | 200 | oui |
| benefits | https://www.qu.edu.qa/en-us/students/admission/scholarships/Pages/types.aspx | 200 | oui |
| application | https://www.qu.edu.qa/en-us/students/admission/undergraduate/apply | 200 | oui |
| cycle | https://www.qu.edu.qa/en-us/students/admission/scholarships/Pages/scholarships-timeline.aspx | 200 | oui |

**Écarts relevés**

- [minor] `requirements[1] (passeport / carte qatarie)` — fiche : Photo format passeport et copie du passeport (ou carte qatarie pour les Qataris) ; page : La page cite « a valid Qatar ID card (and a copy of the passport for non-Qataris) ». La formulation est ambiguë pour un candidat hors du Qatar ; la paraphrase …
  - « Upload a digital copy of your passport-size photo and a valid Qatar ID card (and a copy of the passport for non-Qataris) » (application)
- [minor] `requirements[2] (relevé de notes)` — fiche : Copie certifiée conforme du relevé de notes du secondaire ; originaux après admission ; page : La page « types » dit que les internationaux doivent envoyer « the original high school transcript » pendant la période de candidature, alors que la page « App…
  - « International students must submit the original high school transcript and required documents during the application period » (eligibility)

**Calendrier confirmé par la page**

- Calendrier : catégorie « nouveaux étudiants internationaux de licence candidatant depuis l’extérieur du Qatar » — « New international undergraduate students applying to QU from outside Qatar »
- Calendrier : ouverture de la candidature à la bourse internationale le 1er mars 2026 (base de l’estimation) — « March 1, 2026 1. Start online application for these Scholarships »

**Non vérifié (la page ne le dit pas ou n'a pas pu être lue)**

- Calendrier 2027 (automne 2027) : « L’université n’a pas encore publié son calendrier 2027 » — page silencieuse : absence de tout calendrier 2027 constatée sur scholarships-timeline.aspx et application-timeline.aspx (seul Fall 2026 es…
- Heure de clôture estimée (estimatedCloseAt 2027-03-25T23:59:59Z) — la page 2026 donne la date du 25 mars sans heure ni fuseau ; l’horodatage de la fiche est une hypothèse
- Statut « premier diplôme de Licence » (eligibility[0]) — la page exclut la seconde licence, les transferts, visiteurs et non-diplômants, ce qui implique un premier diplôme, mais n’emploie pas l’ex…

### `rhodes_southern_africa_2027`

- Verdict du relecteur : **verified_with_edits** — lue le `2026-09-29T15:03:19.000Z` (groupe G7).

| Source | URL | HTTP | Lue |
|---|---|---|---|
| overview | https://www.rhodeshouse.ox.ac.uk/scholarships/the-rhodes-scholarship/ | 200 | oui |
| eligibility | https://www.rhodeshouse.ox.ac.uk/media/y4plyclm/southern-africa-information-for-candidates-document-2027-fina… | 200 | oui |
| benefits | https://www.rhodeshouse.ox.ac.uk/scholarships/the-rhodes-scholarship/ | 200 | oui |
| application | https://www.rhodeshouse.ox.ac.uk/scholarships/the-rhodes-scholarship/ | 200 | oui |
| cycle | https://www.rhodeshouse.ox.ac.uk/media/y4plyclm/southern-africa-information-for-candidates-document-2027-fina… | 200 | oui |

**Écarts relevés**

- [minor] `deadlineLabel (fr/en) — 'les références restent attendues jusqu’au 17 août 2026…` — fiche : Clôturé — ... les références restent attendues jusqu’au 17 août 2026 ; prochain cycle attendu vers juin 2027, date non publiée ; page : La date limite des références (17 août 2026) est désormais passée au 29/09/2026 : le présent ('restent attendues') est périmé.
  - « Reference Deadline: 23:59 SAST, Monday 17 August 2026 » (cycle)
- [minor] `deadlineLabel (fr/en) — 'prochain cycle attendu vers juin 2027'` — fiche : prochain cycle attendu vers juin 2027, date non publiée ; page : Aucune page lue (accueil, page circonscription Afrique australe, FAQ, PDF) ne donne de date de réouverture ; elles disent seulement d'attendre une notification…
  - « You can sign up to our mailing list to be notified when applications reopen in future years. » (overview)
- [minor] `requirements (omission)` — fiche : La liste ne mentionne ni le certificat de fin d’études secondaires (Grade 12 / Matric) ni la photo d’identité couleur ; elle dit 'Preuve d’… ; page : Le PDF liste aussi le certificat Grade 12 et une photo tête-épaules, et ne demande pas de test d’anglais dans 'Key Documents' (seulement de vérifier son niveau…
  - « A copy of your Grade 12 school leaving certificate. » (eligibility)
- [minor] `cycle.status (observation, pas d'erreur de fiche)` — fiche : closed ; page : Le bandeau de la page d'accueil Rhodes annonce 'Applications ... 2027 are open!' mais il est générique (toutes circonscriptions) ; la page Afrique australe et …
  - « Applications for the Rhodes Scholarship 2027 are open! » (overview)

**Corrections**

- appliquée : `deadlineLabel`

**Calendrier confirmé par la page**

- Ouverture des candidatures : 00:01 SAST, 1er juin 2026 (= 2026-05-31T22:01:00Z, cycle.opensAt correct) — « Applications Open: 00:01 SAST, Monday 01 June 2026 »
- Clôture des candidatures : 23:59 SAST, 3 août 2026 (= 2026-08-03T21:59:00Z, cycle.closesAt correct) ; cycle passé, stat… — « Applications Close: 23:59 SAST, Monday 03 August 2026 »

**Non vérifié (la page ne le dit pas ou n'a pas pu être lue)**

- Prochain cycle attendu vers juin 2027 / date de réouverture — page silencieuse : le site Rhodes ne publie aucune date pour le cycle suivant
- Allocation annuelle pour 2026-27 ou 2027-28 (le montant 2025-26 est le seul publié) — page silencieuse : la page affiche encore 20 400 GBP pour 2025-26 ; la fiche le dit déjà ('révisable')
- Preuve d'anglais 'lorsque requise' (requirements[6]) — le PDF impose de vérifier le niveau supérieur d'Oxford mais ne liste aucun certificat d'anglais parmi les pièces à téléverser ; la nécessit…
- Détail des critères de sélection (page selection-criteria) — page non listée dans les sources ; critères lus uniquement dans le PDF (Guidance for Referees et Personal Statement)

### `romania_mfa_scholarship_2027_forecast`

- Verdict du relecteur : **verified_with_edits** — lue le `2026-09-29T15:07:26.000Z` (groupe G2).

| Source | URL | HTTP | Lue |
|---|---|---|---|
| overview | https://scholarships.studyinromania.gov.ro/scholarship-about | 200 | oui |
| eligibility | https://scholarships.studyinromania.gov.ro/scholarship-about | 200 | oui |
| benefits | https://scholarships.studyinromania.gov.ro/scholarship-about | 200 | oui |
| application | https://scholarships.studyinromania.gov.ro/ | 200 | oui |
| cycle | https://scholarships.studyinromania.gov.ro/scholarship-about | 200 | oui |

**Écarts relevés**

- [minor] `requirements[4] (apostille / authentification)` — fiche : Authentification ou apostille lorsque demandée ; page : L’apostille ou l’authentification est exigée pour tous les documents d’études, sans condition « lorsque demandée ».
  - « All study documents must be apostilled under the Hague Convention or authenticated by the relevant authorities in the home country » (application)
- [minor] `requirements[2] (langue du CV)` — fiche : Curriculum vitae en anglais ou français ; page : Le CV peut aussi être rédigé en roumain.
  - « Curriculum Vitae in English, French or Romanian. » (application)
- [minor] `advantages[1] (bourse mensuelle « selon le niveau »)` — fiche : Bourse mensuelle selon le niveau ; page : La page prévoit une bourse mensuelle pendant l’année préparatoire et pendant le cycle d’études, mais ne donne aucun montant et ne distingue pas de barème par n…
  - « receiving a monthly scholarship, for students enrolled in Bachelor, Master or doctoral studies, but not more than the duration of a university cycle » (benefits)

**Corrections**

- appliquée : `requirements[4]`
- appliquée : `requirements[2]`
- appliquée : `advantages[1]`

**Calendrier confirmé par la page**

- Base de l’estimation : appel 2026 du 16 février au 31 mars 2026 — « The enrolment period begins on 16 February 2026. The deadline for submitting applications is 31 March 2026. »
- Résultats annoncés vers le 15 juillet (cycle 2026) — « The results of the scholarship selection process will be announced by e-mail, around 15 July 2026 »

**Non vérifié (la page ne le dit pas ou n'a pas pu être lue)**

- Montant de la bourse mensuelle, et sa variation « selon le niveau » — page silencieuse : « monthly financial aid, in accordance with the legislation in force » sans chiffre
- Dates du cycle 2027–2028 (16 février – 31 mars 2027) — page silencieuse : aucun appel 2027 publié ; la fiche reste correctement « estimée »
- Contenu détaillé du formulaire de candidature (choix du niveau, du domaine et des établissements) — formulaire derrière la connexion ; la FAQ mentionne « preferred study domains » mais pas la sélection d’établissements

### `schwarzman_scholars_2027`

- Verdict du relecteur : **verified_with_edits** — lue le `2026-09-29T15:02:30.000Z` (groupe G6).

| Source | URL | HTTP | Lue |
|---|---|---|---|
| overview | https://www.schwarzmanscholars.org/program-experience/ | 200 | oui |
| eligibility | https://www.schwarzmanscholars.org/admissions/application-instructions/ | 200 | oui |
| benefits | https://www.schwarzmanscholars.org/program-experience/ | 200 | oui |
| application | https://www.schwarzmanscholars.org/admissions/application-instructions/ | 200 | oui |
| cycle | https://www.schwarzmanscholars.org/admissions/application-instructions/ | 200 | oui |

**Écarts relevés**

- [blocking] `cycle.status` — fiche : open (dateConfidence confirmed, closesAt 2026-09-09T19:00:00.000Z) ; page : Fenêtre 2027-2028 close ; la suivante (promotion 2028-2029) ouvrira d’avril à septembre 2027
  - « The application window for the class of 2027-2028 is now closed. » (cycle)
- [blocking] `deadlineLabel` — fiche : Ouvert — clôture le 9 septembre 2026 à 15 h EDT / Open — closes 9 September 2026 at 3:00 PM EDT ; page : La clôture (9 septembre 2026, 15 h EDT) est dépassée au 29/09/2026 ; le libellé affirme encore « Ouvert ».
  - « The application window for the class of 2027-2028 is now closed. » (cycle)
- [minor] `tags` — fiche : ['master','china','tsinghua','open','leadership','fully-funded'] ; page : La fenêtre est close ; le tag « open » n’est plus exact (McCall MacBain, fiche voisine, porte « closed »).
  - « The application window for the class of 2027-2028 is now closed. » (cycle)
- [minor] `cycle.opensAt` — fiche : 2026-04-08T00:00:00.000Z ; page : Aucune page relue n’écrit le jour d’ouverture 2026 ; la FAQ donne seulement le mois (« between April and September »).
  - « Applicants holding a passport from any other country apply between April and September. » (cycle)
- [minor] `steps[3] (Soumettre avant l’heure limite)` — fiche : Finaliser au plus tard le 9 septembre à 15 h EDT et se préparer à un entretien éventuel. ; page : Fait exact mais périmé : la fenêtre est close, l’étape n’est plus actionnable. Non bloquant pour le validateur ; à laisser tel quel ou à reformuler par le réda…
  - « The application window for the class of 2027-2028 is now closed. » (application)

**Corrections**

- appliquée : `cycle.status`
- appliquée : `cycle.dateConfidence`
- appliquée : `cycle.closesAt`
- appliquée : `cycle.opensAt`
- non appliquée : `cycle.academicYear`
- non appliquée : `cycle.sourceUrl`
- appliquée : `deadlineLabel`
- appliquée : `tags`
- non appliquée : `OPTION non recommandée : nouvelle fiche forecast 2028-2029`

**Calendrier confirmé par la page**

- Calendrier : la fenêtre suivante (promotion 2028-2029) est annoncée d’avril à septembre 2027, en mois seulement (aucun … — « The U.S. and Global application for the class of 2028-2029 will be open from April 2027 to September 2027. »
- Calendrier : la fenêtre de candidature 2027-2028 est close — « The application window for the class of 2027-2028 is now closed. »

**Non vérifié (la page ne le dit pas ou n'a pas pu être lue)**

- Jour d’ouverture 2026 (8 avril 2026, cycle.opensAt) — page silencieuse : les pages relues donnent seulement « April » ; le jour 8 n’est écrit nulle part
- Âge et diplôme « au 1er août 2027 » textuellement — la page ne cite plus que la promotion 2028-2029 (1er août 2028) ; 2027 n’est déduit que de la règle générale « 1er août de l’année d’entrée…
- Libellé « Master en affaires mondiales / Master in Global Affairs » (levelLabel) — les pages relues disent « master’s degree and leadership program » et parlent d’« global affairs » comme pilier du curriculum, sans écrire …
- Programme « résidentiel » (description) — déduit de « Room & Board » ; le mot « residential » n’apparaît pas sur les pages relues
- Nationalité : la fiche n’énonce pas la restriction sur la citoyenneté chinoise pour la voie U.S./Global — omission plutôt qu’écart : la page dit que les candidats U.S./Global doivent être non chinois ; sans effet pour le public francophone d’Afr…

### `si_global_professionals_2027_forecast`

- Verdict du relecteur : **verified_with_edits** — lue le `2026-09-29T15:00:55.000Z` (groupe G4).

| Source | URL | HTTP | Lue |
|---|---|---|---|
| overview | https://si.se/en/apply/scholarships/swedish-institute-scholarships-for-global-professionals/ | 200 | oui |
| eligibility | https://si.se/en/apply/scholarships/swedish-institute-scholarships-for-global-professionals/ | 200 | oui |
| benefits | https://si.se/en/apply/scholarships/swedish-institute-scholarships-for-global-professionals/ | 200 | oui |
| application | https://si.se/en/apply/scholarships/swedish-institute-scholarships-for-global-professionals/ | 200 | oui |
| cycle | https://si.se/en/apply/scholarships/swedish-institute-scholarships-for-global-professionals/ | 200 | oui |

**Écarts relevés**

- [minor] `requirements` — fiche : CV ; preuves d’emploi/leadership ; passeport ; « Formulaire de motivation et pièces publiées au prochain appel » (les lettres de recommanda… ; page : Deux lettres de recommandation (deux référents distincts, modèle SI, signées et tamponnées) sont exigées ; la motivation est saisie dans le portail, non dans u…
  - « You are required to submit two letters of reference from two different referees. » (application)

**Corrections**

- appliquée : `requirements (ajouter un élément avant l’item « Formulaire de motivation… »)`
- appliquée : `requirements[4] (remplacement de « Formulaire de motivation et pièces publiées au prochai…`

**Calendrier confirmé par la page**

- Dépôt de la candidature SI dans une fenêtre de deux semaines (appel de référence) — « 9-25 February 2026: Application portal for the SI Scholarships is open for two weeks. »
- Clôture du portail le dernier jour à 14:59 CET (= 13:59 UTC, cohérent avec estimatedCloseAt) — « Please note that the portal closes at 14:59 CET on the final day. »

**Non vérifié (la page ne le dit pas ou n'a pas pu être lue)**

- Dates, critères et pays du prochain appel (2027/2028) — page silencieuse : aucune date 2027/2028 n’est publiée ; la page décrit encore l’appel 2026/2027 (« Application closed »). Le cycle reste c…
- Fenêtre attendue en février 2027 (9–25 février) — estimation reposant sur le calendrier 2026 (9–25 février 2026, lu sur la page) ; la page précise « The information may be subjected to chan…
- Absence de suspension ou de coupe budgétaire annoncée — lecture intégrale de la page : aucune mention de suspension ; la page reste silencieuse sur l’appel suivant
- Liste des Masters éligibles 2027/2028 — page silencieuse (la liste est publiée à la mi-novembre de chaque cycle ; page 2026/2027 seule disponible)

### `stipendium_hungaricum_2027_forecast`

- Verdict du relecteur : **verified_with_edits** — lue le `2026-09-29T15:05:59.000Z` (groupe G2).

| Source | URL | HTTP | Lue |
|---|---|---|---|
| overview | https://stipendiumhungaricum.hu/about/ | 200 | oui |
| eligibility | https://stipendiumhungaricum.hu/apply/ | 200 | oui |
| benefits | https://stipendiumhungaricum.hu/about/ | 200 | oui |
| application | https://apply.stipendiumhungaricum.hu/ | 200 | oui |
| cycle | https://stipendiumhungaricum.hu/apply/ | 200 | oui |

**Écarts relevés**

- [minor] `requirements[4] (certificat médical)` — fiche : Certificat médical uniquement à l’étape prévue pour les candidats nommés ; page : Le certificat médical n’est obligatoire que pour les personnes qui reçoivent la bourse ; les nommés sont seulement invités à s’y prendre à l’avance. Il n’est p…
  - « mandatory only for those who will receive a scholarship. » (application)

**Corrections**

- appliquée : `requirements[4]`

**Calendrier confirmé par la page**

- Nomination par le partenaire d’envoi à la fin de février — « Sending partners will nominate the best applicants by the end of February »
- Dernier cycle publié : clôture le 15 janvier 2026 à 14 h CET — « 15th January 2026, 2 pm (CET) »

**Non vérifié (la page ne le dit pas ou n'a pas pu être lue)**

- Dates du cycle 2027–2028 (ouverture novembre-décembre 2026, clôture vers le 15 janvier 2027 à 14 h CET) — page silencieuse : aucun appel 2027/2028 publié ; la fiche reste correctement « estimée »
- Formulaire de candidature et étapes internes du portail — portail derrière connexion (DreamApply) ; pièces recoupées avec l’appel PDF
- Nomination « lorsque cette étape s’applique » — l’appel dit que seules les candidatures nommées sont considérées, avec une exception (lauréats de la conférence scientifique étudiante nati…

### `taiwan_icdf_2027`

- Verdict du relecteur : **verified_with_edits** — lue le `2026-09-29T15:02:15.000Z` (groupe G4).

| Source | URL | HTTP | Lue |
|---|---|---|---|
| overview | https://www.icdf.org.tw/wSite/ct?ctNode=31562&mp=2&xItem=12505 | 200 | oui |
| eligibility | https://www.icdf.org.tw/wSite/np?ctNode=31563&CtUnit=365&BaseDSD=7&mp=2 | 200 | oui |
| benefits | https://www.icdf.org.tw/wSite/DownloadFile?file=f1764223019963.pdf&realname=Scope+of+Scholarship+2026.pdf&typ… | 200 | oui |
| application | https://www.icdf.org.tw/wSite/ct?ctNode=31566&mp=2&xItem=69338 | 200 | oui |
| cycle | https://www.icdf.org.tw/wSite/ct?ctNode=31562&mp=2&xItem=12505 | 200 | oui |

**Écarts relevés**

- [minor] `requirements[0]` — fiche : Formulaire TaiwanICDF signé ; page : La candidature se fait en ligne, avec des informations exactes et complètes ; le seul formulaire signé mentionné est le formulaire de consentement, renvoyé apr…
  - « Applicants must ensure that they submit accurate and complete information; failure to do so will result in the application not being processed. » (application)
- [minor] `eligibility[5]` — fiche : Ne pas avoir eu une bourse TaiwanICDF révoquée ni avoir été expulsé d’un établissement taïwanais ; page : L’exclusion vise toute bourse retirée par une agence du gouvernement taïwanais (ROC) ou une institution liée, pas seulement TaiwanICDF.
  - « Have never had any scholarship revoked by any ROC (Taiwan) government agency or related institution, nor been expelled from any Taiwanese university. » (eligibility)
- [minor] `steps[0].descriptionFr/En` — fiche : Comparer sa nationalité et le niveau visé à la liste TaiwanICDF 2027. ; page : Les pages n’hébergent que le guidebook et les programmes 2026 (liste de pays incluse) ; aucune liste 2027 n’est publiée à ce jour.
  - « 2026 TaiwanICDF Scholarship Application Guidebook. v3.pdf » (overview)

**Corrections**

- appliquée : `requirements[0]`
- appliquée : `eligibility[5]`
- appliquée : `steps[0] description (index 2 FR / index 3 EN)`

**Calendrier confirmé par la page**

- Cycle 2027 annoncé : candidatures du 1er décembre 2026 au 15 mars 2027 (dates écrites sur la page ; pas encore ouvert a… — « The 2027 TaiwanICDF Scholarship applications open from December 1, 2026 to March 15, 2027! »

**Non vérifié (la page ne le dit pas ou n'a pas pu être lue)**

- Pièces exactes à téléverser dans le système de candidature en ligne (passeport, relevés du niveau précédent, formulaire) — le lien du système en ligne n’est pas exposé dans la page récupérée et le système n’a pas été lu ; le guidebook ne liste pas les pièces de …
- Conditions 2027 (liste de pays, programmes, montants d’allocation, échéance du diplôme) — page silencieuse sur le 2027 : seuls le guidebook v3 de janvier 2026, « Programs Available … 2026 » et « Scope of Scholarship 2026 » sont p…
- Heure de clôture du 15 mars 2027 (fiche : 23:59:59 UTC) et fuseau horaire — page silencieuse : seule la date est écrite
- Pays africains éligibles au Master en 2027 — liste 2026 lue (Côte d’Ivoire, Djibouti, Eswatini, Éthiopie, Kenya, Sénégal, Afrique du Sud, Somaliland, Tanzanie, Ouganda) ; liste 2027 no…
- Documents linguistiques exigés par le programme choisi — page silencieuse côté TaiwanICDF (pas de test d’anglais requis par le Fonds) ; les exigences relèvent de chaque programme partenaire (PDF «…

### `turkiye_isdb_joint_2027_forecast`

- Verdict du relecteur : **verified_with_edits** — lue le `2026-09-29T15:03:44.000Z` (groupe G2).

| Source | URL | HTTP | Lue |
|---|---|---|---|
| overview | https://www.turkiyeburslari.gov.tr/announcements/ytb-islamic-development-bank-isdb-joint-scholarship-program-… | 200 | oui |
| eligibility | https://www.turkiyeburslari.gov.tr/announcements/ytb-islamic-development-bank-isdb-joint-scholarship-program-… | 200 | oui |
| benefits | https://www.turkiyeburslari.gov.tr/announcements/ytb-islamic-development-bank-isdb-joint-scholarship-program-… | 200 | oui |
| application | https://tbbs.turkiyeburslari.gov.tr/ | 200 | oui |
| cycle | https://www.turkiyeburslari.gov.tr/announcements/ytb-islamic-development-bank-isdb-joint-scholarship-program-… | 200 | oui |

**Écarts relevés**

- [blocking] `fundingLabel / fundingType / advantages` — fiche : « Financement complet » (fundingType fully_funded), sans mention d’un remboursement ; page : Au niveau Associate et Licence, le financement est un prêt que l’étudiant rembourse après ses études et son emploi, au fonds fiduciaire IsDB Education Trust de…
  - « Associate degree and bachelor degree students are required to repay the loan after graduation and employment, in easy installments » (benefits)
- [blocking] `fundingLabel / fundingType / advantages (corroboration)` — fiche : Financement complet ; page : Annonce officielle 2025 : pour Associate et Licence, la bourse est un prêt sans intérêt (Qard-Hasan) au bénéficiaire
  - « For associate and bachelor’s degrees, the scholarship is an interest-free loan (Qard-Hasan) to the students » (benefits)
- [minor] `cycle.estimatedOpenAt / estimatedCloseAt (fragilité de l’estimation)` — fiche : Ouverture du 10 janvier au 20 février 2027 « estimée depuis l’appel 2026 » ; page : L’appel 2026 a bien couru du 10 janvier au 20 février 2026, mais l’appel 2025 du même programme avait couru du 10 au 20 mars 2025 : le calendrier du volet conj…
  - « APPLICATION DATES: 10 March 2025 - 20 March 2025 » (cycle)

**Corrections**

- appliquée : `fundingLabel`
- appliquée : `fundingType`
- appliquée : `advantages (ajouter une ligne en fin de liste)`

**Calendrier confirmé par la page**

- Base de l’estimation : appel 2026 du 10 janvier au 20 février 2026 — « Application Dates: 10 January – 20 February 2026 »

**Non vérifié (la page ne le dit pas ou n'a pas pu être lue)**

- Satisfaire les critères académiques et d’âge du niveau Türkiye Scholarships demandé — page annonce silencieuse ; critères généraux confirmés seulement sur la page générale, sans mention qu’ils s’appliquent tels quels au volet…
- Ne pas être citoyen turc ni déjà inscrit en Turquie au même niveau (volet conjoint) — page annonce silencieuse ; règle générale confirmée sur /scholarshipsprograms uniquement
- Placement universitaire (avantage 1) — l’annonce parle d’universités prestigieuses de Türkiye mais n’emploie pas le mot placement
- « choisir Türkiye–IsDB » et « réponses complètes au profil et aux motivations sur TBBS » — la page dit seulement de répondre Yes sous Joint Scholarship Programs ; le formulaire est derrière l’authentification
- Liste des pays et filières éligibles — renvoyée vers un PDF (storagetbbsweb.blob.core.windows.net/tbbsweb/Contents/ListofCountriesProgramsandDepartments.pdf) non lu

### `turkiye_scholarships_2027_forecast`

- Verdict du relecteur : **verified_with_edits** — lue le `2026-09-29T15:03:44.000Z` (groupe G2).

| Source | URL | HTTP | Lue |
|---|---|---|---|
| overview | https://www.turkiyeburslari.gov.tr/fulltimeprograms | 200 | oui |
| eligibility | https://turkiyeburslari.gov.tr/scholarshipsprograms | 200 | oui |
| benefits | https://www.turkiyeburslari.gov.tr/whyturkiyescholarships | 200 | oui |
| application | https://tbbs.turkiyeburslari.gov.tr/ | 200 | oui |
| cycle | https://www.turkiyeburslari.gov.tr/calendar | 200 | oui |

**Écarts relevés**

- [blocking] `advantages[4] (allocation mensuelle)` — fiche : Allocation mensuelle officielle : 4 500 TL en Licence et 6 500 TL en Master ; page : 6.500 TL en Licence (et Associate), 9.500 TL en Master, 13.000 TL en Doctorat
  - « Monthly Stipend Undergraduate : 6.500 TL, Master’s: 9.500 TL, PhD: 13.000 TL » (overview)
- [blocking] `advantages[4] (allocation mensuelle) — deuxième source concordante` — fiche : 4 500 TL (Licence) / 6 500 TL (Master) ; page : 6.500 TL (Licence) / 9.500 TL (Master) / 13.000 TL (Doctorat)
  - « A monthly stipend of 6.500 TL at undergraduate level, 9.500 TL at master’s level, and 13.000 TL at doctorate level » (benefits)
- [minor] `eligibility[1] (nuance, sans correction imposée)` — fiche : 90 % pour médecine, dentaire et pharmacie (critère général) ; page : Le volet Master ne décerne pas de bourse en sciences de la santé ; le seuil de 90 % reste correct sur la page des critères
  - « Türkiye Scholarships does not award scholarships in the field of health sciences. » (overview)

**Corrections**

- appliquée : `advantages[4]`

**Calendrier confirmé par la page**

- Calendrier officiel : période générale du 10 janvier au 20 février — « January 10 – February 20 »
- Base de l’estimation : l’appel 2026 a couru du 10 janvier au 20 février 2026 — « applications will be open between 10th January- 20th February 2026 for international students from all countries. »

**Non vérifié (la page ne le dit pas ou n'a pas pu être lue)**

- Étapes 2 et 3 (compléter le profil : parcours, résultats, activités ; choisir les programmes) dans le détail — l’écran TBBS est une simple page de connexion ; le détail du formulaire n’est visible qu’après authentification
- Résultats d’examens internationaux ou de langue « lorsque le programme les exige » — confirmé uniquement sur /applysteps (hors des cinq URLs) ; les cinq pages de la fiche sont silencieuses

### `uct_international_refugee_2027`

- Verdict du relecteur : **verified_with_edits** — lue le `2026-09-29T15:08:11.000Z` (groupe G10).

| Source | URL | HTTP | Lue |
|---|---|---|---|
| overview | https://uct.ac.za/students/fees-funding-postgraduate-degree-funding-bursaries-scholarships/international-and-… | 200 | oui |
| eligibility | https://www.uct.ac.za/sites/default/files/media/documents/uct-handbook-14-2027-final.pdf | 200 | oui |
| benefits | https://uct.ac.za/students/fees-funding-postgraduate-degree-funding-bursaries-scholarships/international-and-… | 200 | oui |
| application | https://uct.ac.za/students/fees-funding-postgraduate-degree-funding/applications-and-requirements | 200 | oui |
| cycle | https://uct.ac.za/students/fees-funding-postgraduate-degree-funding-bursaries-scholarships/international-and-… | 200 | oui |

**Écarts relevés**

- [blocking] `deadlineLabel (FR+EN), description, steps[0] — year of the 'call will not open'…` — fiche : Label: « l’appel à candidatures n’ouvrira pas » / “call for applications will not open”, presented as the answer for the 2027 cycle (‘Aucun… ; page : The notice is about the 2026 call, not 2027. The page's meta description also frames the page as covering the 2026 academic year. The page says nothing at all …
  - « The call for applications for 2026 will not open, due to funding constraints. » (cycle)
- [minor] `cycle.estimatedCloseAt (2026-11-10T21:59:00.000Z) and estimatedOpenAt (2026-09-…` — fiche : Projected window 1 Sept – 10 Nov 2026 for the international/refugee call. ; page : No page or handbook gives any date for an international/refugee call (the 2026 call never opened, so there is no earlier dated call to extrapolate from). The o…
  - « 2027 UCT Postgraduate Financial Aid Bursary for SA Citizens or Permanent residents Honours, Masters, Doctoral Open to all fields 10 Nov 2026 » (cycle)
- [minor] `description / deadlineLabel — 'As of 10 August 2026'` — fiche : Au 10 août 2026 la page n’annonce toujours aucun appel ; page : Re-read 29 Sept 2026: still no call; same 2026 notice, unchanged. Date in the text is simply stale.
  - « NOTICES The call for applications for 2026 will not open, due to funding constraints. » (cycle)

**Corrections**

- appliquée : `deadlineLabel`
- appliquée : `description (only the third sentence changes)`
- appliquée : `steps[0] (descriptionFr / descriptionEn)`
- non appliquée : `cycle`

**Non vérifié (la page ne le dit pas ou n'a pas pu être lue)**

- Any 2027 (or 2027–2028) international/refugee call: opening date, closing date, application form, supporting-document list — page silencieuse — the page, Handbook 14 (2027 edition) and the funding noticeboard list no such call
- requirements[3] 'Relevés et pièces justificatives exigés par l’appel et le manuel de financement' — no call published, so no document list for this scheme exists on the sources
- Value of the award ('complément partiel') in rand — page silencieuse; the fiche does not state an amount
- Whether the 2027 call will reopen or is cancelled — page silencieuse; the notice concerns 2026 only. Status 'suspended' is kept as the closest of the four catalogue statuses (a suspension not…

### `uoft_lester_b_pearson_2027`

- Verdict du relecteur : **verified_with_edits** — lue le `2026-09-29T15:07:39.000Z` (groupe G5).

| Source | URL | HTTP | Lue |
|---|---|---|---|
| overview | https://future.utoronto.ca/pearson-scholarships | 200 | oui |
| eligibility | https://future.utoronto.ca/pearson-scholarships | 200 | oui |
| benefits | https://future.utoronto.ca/pearson-scholarships | 200 | oui |
| application | https://future.utoronto.ca/pearson-scholarships | 200 | oui |
| cycle | https://future.utoronto.ca/pearson-scholarships | 200 | oui |

**Écarts relevés**

- [minor] `eligibility[3] (FR/EN)` — fiche : « ne pas commencer ailleurs en janvier 2027 » / « not begin elsewhere in January 2027 » ; page : La page exclut un début d’études postsecondaires en janvier 2027 à l’Université de Toronto OU dans un autre établissement ; « ailleurs » ne couvre que le secon…
  - « students who are starting their post-secondary studies in January 2027 at U of T or another post-secondary institution » (eligibility)

**Corrections**

- appliquée : `eligibility[3] (correction mineure, optionnelle)`

**Calendrier confirmé par la page**

- Échéance de nomination du lycée : 9 octobre 2026 — « School nomination deadline: October 9, 2026 »
- Échéance de la demande d’admission OUAC : 16 octobre 2026 — « Student OUAC admission application deadline: October 16, 2026 »

**Non vérifié (la page ne le dit pas ou n'a pas pu être lue)**

- Statut « open » du cycle — la page n’emploie pas le mot « open » ; le statut découle des dates écrites (accès au formulaire de nomination dès le 6 juillet 2026, échéa…
- cycle.opensAt = 2026-07-06T00:00:00.000Z — le 6 juillet 2026 est la date d’accès au formulaire de nomination pour les lycées déjà participants, pas une ouverture côté étudiant ; la p…
- cycle.closesAt = 2026-11-06T23:59:59.000Z (heure de clôture) — la page donne seulement « November 6, 2026 », sans heure ni fuseau ; l’heure de la fiche est une convention, non une donnée de la page.

### `up_mastercard_scholars_2027`

- Verdict du relecteur : **not_fully_verifiable** — lue le `2026-09-29T15:07:09.000Z` (groupe G10).
- **Non relue** : les cinq sources ont répondu 403 (Cloudflare). `checkedAt` inchangé (24/08/2026). Aucune correction de contenu appliquée : les écarts relevés dans les formulaires PDF 2027 (facultés du postgrade, Master de première année seulement, moyenne minimale de 70 %) contredisent la lecture du 24/08 des pages HTML et doivent être tranchés par une personne qui lit les pages.

| Source | URL | HTTP | Lue |
|---|---|---|---|
| overview | https://www.up.ac.za/mastercard-foundation-scholars-program | 403 | **non** |
| eligibility | https://www.up.ac.za/mastercard-foundation-scholars-program/application-instructions | 403 | **non** |
| benefits | https://www.up.ac.za/mastercard-foundation-scholars-program/what-program-covers | 403 | **non** |
| application | https://www.up.ac.za/mastercard-foundation-scholars-program/how-apply | 403 | **non** |
| cycle | https://www.up.ac.za/mastercard-foundation-scholars-program/how-apply | 403 | **non** |

**Écarts relevés**

- [blocking] `eligibility[5] (postgraduate faculties)` — fiche : Postgrade : cursus limité aux facultés Natural and Agricultural Sciences, Economic and Management Sciences, Humanities en Honours ou Master… ; page : The official 2027 postgraduate form lists six faculties: Economic and Management Sciences; Natural and Agricultural Sciences; Engineering, Built Environment an…
  - « Humanities (with the exception of Psychology degrees) » (eligibility)
- [blocking] `levels / levelLabel / eligibility[1] (postgraduate level)` — fiche : Licence, Honours et Master à temps plein ; « Ouvert aux niveaux Licence, Honours et Master » ; page : The 2027 postgraduate form restricts postgraduate applicants to first-year master's students and excludes anyone who already holds a Master's; Honours is not m…
  - « open to African students who are first -year master's students with a grade point average (GPA) of at least 70% » (eligibility)
- [minor] `eligibility (minimum GPA — omitted)` — fiche : No academic threshold mentioned in eligibility ; page : Both 2027 forms state a minimum GPA of 70% (undergraduate: 'with a grade point average (GPA) of at least 70%').
  - « open to African students with a grade point average (GPA) of at least 70% » (eligibility)
- [minor] `cycle.closesAt / deadlineLabel — clock note (not a discrepancy today)` — fiche : open, confirmed, closesAt 2026-09-30T21:59:00.000Z (= 23:59 SAST on 30 Sept) ; page : Both official 2027 forms still give 30 Sept 2026 (postgraduate) and 31 Aug 2026 (undergraduate); neither states a time of day. At 29/09/2026 the cycle is still…
  - « no later than September 30 September 2026 » (cycle)

**Calendrier confirmé par la page**

- Postgraduate deadline 30 September 2026 and admission application by 30 June 2026 (2027 postgraduate form, official UP … — « ensure that the university receives all required documentation no later than September 30 September 2026. Apply by 30 June 2026 for admission into a faculty. »
- Undergraduate deadline 31 August 2026 (2027 undergraduate form, official UP PDF; not one of the five source URLs) — « ensure that the University receives all required documentation no later than 31st August 2026. »

**Non vérifié (la page ne le dit pas ou n'a pas pu être lue)**

- Content of the five UP HTML pages (overview, application-instructions, what-program-covers, how-apply) on 29/09/2026, including the wording 'Undergraduate: 31 … — 403 Cloudflare block on every fetch route; only the two 2027 PDF forms (hosted on drupalwebprod-files.up.ac.za, HTTP 200) could be read
- Benefits: full tuition, residence and meals, monthly stipend, start-up funds, visa fees, textbooks, medical aid, flights, Africa-based summer internship, couns… — what-program-covers page blocked (403); the forms do not list programme benefits
- 'Un entretien précède toute admission au programme' and 'sans réponse d’UP, la candidature doit être considérée comme non retenue' — not stated in either 2027 form; page blocked
- Programme history claims (at UP since January 2014, phase 2 since December 2023) and phone +27 (0)12 420 4297 — page blocked; not in the forms
- 'Passeport permettant une demande de visa sans délai' as a document requirement — not in the forms' document list; page blocked
- Statement that no opening date is published and that another UP page contradicts how-apply on the opening window — pages blocked; cannot re-read

### `uwc_burkina_faso_2027_forecast`

- Verdict du relecteur : **verified_with_edits** — lue le `2026-09-29T15:03:27.000Z` (groupe G1).

| Source | URL | HTTP | Lue |
|---|---|---|---|
| overview | https://bf.uwc.org/ | 200 | oui |
| eligibility | https://bf.uwc.org/eligibility-criteria/ | 200 | oui |
| benefits | https://bf.uwc.org/how-to-apply/ | 200 | oui |
| application | https://apply.uwc.org/ | 200 | oui |
| cycle | https://bf.uwc.org/how-to-apply/ | 200 | oui |

**Écarts relevés**

- [minor] `scholarship.keyRequirementsFr[5] / keyRequirementsEn[5] et applicationSteps[3].…` — fiche : « Informations financières si la candidature est retenue pour une nomination » ; étape 4 : « Si présélectionné, … transmettre les informati… ; page : La page demande les informations financières à tous les candidats, pas seulement aux présélectionnés ou aux nommés.
  - « all applicants will be requested to submit financial information to this effect » (benefits)

**Corrections**

- appliquée : `scholarship.keyRequirementsFr[5] / scholarship.keyRequirementsEn[5]`
- appliquée : `applicationSteps[stepNumber 4].descriptionFr / descriptionEn`

**Calendrier confirmé par la page**

- Calendrier : ouverture des candidatures le 1er novembre 2026 — « Application Open: November 1st, 2026 »
- Calendrier : clôture le 3 janvier 2027 — « Application Deadline: January 3rd, 2027 »

**Non vérifié (la page ne le dit pas ou n'a pas pu être lue)**

- Avantage « cursus résidentiel de deux ans préparant au Baccalauréat International » — page silencieuse sur la durée du programme IB : seuls figurent « final two years of secondary education », « residential » et « IB Diploma …
- Heures exactes d’ouverture et de clôture (00:00:00 le 1er novembre 2026 ; 23:59:59 le 3 janvier 2027) et fuseau horaire — page silencieuse : seules les dates sont écrites ; l’heure retenue par la fiche est une convention du dépôt
- Présence de la voie « Burkina Faso » dans le tableau de bord apply.uwc.org à l’ouverture du 1er novembre 2026 — connexion requise ; la page publique de la plateforme est générique et ne liste aucune voie nationale

### `uwc_kenya_entry_2027`

- Verdict du relecteur : **verified_with_edits** — lue le `2026-09-29T15:04:13.000Z` (groupe G1).

| Source | URL | HTTP | Lue |
|---|---|---|---|
| overview | https://ke.uwc.org/ | 200 | oui |
| eligibility | https://ke.uwc.org/eligibility-criteria/ | 200 | oui |
| benefits | https://ke.uwc.org/how-to-apply/ | 200 | oui |
| application | https://ke.uwc.org/how-to-apply/ | 200 | oui |
| cycle | https://ke.uwc.org/how-to-apply/ | 200 | oui |

**Écarts relevés**

- [blocking] `scholarship.eligibilityFr[4] / eligibilityEn[4]` — fiche : 8-4-4 Form 4 ou « CBC Grade 12 » déjà obtenus ; la liste des cursus en cours omet Pearson Edexcel GCSE ; page : Pour le cursus CBE, le niveau exigé est le Grade 10 (achevé), pas le Grade 12 ; la page ajoute Pearson Edexcel GCSE Year 11 (en cours) ; les candidats de « tou…
  - « CBE curriculum – Grade 10 (completed) » (eligibility)
- [blocking] `scholarship.keyRequirementsFr[0] / keyRequirementsEn[0] et applicationSteps[1].…` — fiche : « Résumé officiel des notes 2025 et 2026, signé ou tamponné par l’établissement, une page maximum par année » ; étape 2 : « relevés résumés… ; page : La page exige des relevés de notes / bulletins officiels sur papier à en-tête de l’établissement, pour 2025 et 2026, tous les semestres jusqu’au dernier de 202…
  - « official transcripts / report cards on your school letterhead of your grades for 2 years (2025 and 2026) for ALL semesters » (application)
- [minor] `scholarship.keyRequirements (pièce manquante) et applicationSteps[1]` — fiche : Aucune mention du formulaire de candidature à remplir ; les pièces se limitent aux relevés, recommandations, certificats et PDF ; page : L’étape 1 commence par le téléchargement de l’« Applicant Information Form », avant la liste des pièces justificatives
  - « STAGE 1: DOWNLOAD THE APPLICANT INFORMATION FORM BELOW » (application)
- [minor] `scholarship.keyRequirementsFr[6] / keyRequirementsEn[6] et applicationSteps[3].…` — fiche : Informations financières « en cas de nomination » ; journée d’entretien de janvier avec « évaluation financière » ; page : La liste des activités de la journée d’entretien ne comporte pas d’évaluation financière ; les informations financières sont demandées à tous les candidats, à …
  - « all applicants will be requested to submit financial information to this effect » (benefits)
- [minor] `scholarship.deadlineLabelFr / deadlineLabelEn` — fiche : « Ouvert — clôture le 31 décembre 2026 » ; page : La fenêtre est ouverte depuis le 1er juillet, mais aucun dossier ne doit être déposé avant le 1er décembre 2026 ; le libellé peut faire croire qu’on peut dépos…
  - « Do NOT submit your application documents before 1st December 2026 or after 31st December 2026 » (cycle)

**Corrections**

- appliquée : `scholarship.eligibilityFr[4] / scholarship.eligibilityEn[4]`
- appliquée : `scholarship.keyRequirementsFr[0] / scholarship.keyRequirementsEn[0]`
- appliquée : `scholarship.keyRequirementsFr / keyRequirementsEn (nouvel élément à insérer en première p…`
- appliquée : `applicationSteps[stepNumber 2].descriptionFr / descriptionEn`
- appliquée : `scholarship.keyRequirementsFr[6] / scholarship.keyRequirementsEn[6]`
- appliquée : `applicationSteps[stepNumber 4].descriptionFr / descriptionEn`
- appliquée : `scholarship.deadlineLabelFr / deadlineLabelEn (facultatif ; cycle.status reste « open », …`

**Calendrier confirmé par la page**

- Calendrier : fenêtre de candidature entrée 2027 du 1er juillet au 31 décembre 2026, actuellement ouverte — « Entry 2027 application window is now open from 1st July – 31st December 2026. »
- Calendrier : les pièces se déposent uniquement du 1er au 31 décembre 2026 — « Do NOT submit your application documents before 1st December 2026 or after 31st December 2026 »

**Non vérifié (la page ne le dit pas ou n'a pas pu être lue)**

- Avantage « cursus UWC de deux ans centré sur le Baccalauréat International » — page silencieuse sur la durée : les pages du Kenya parlent de « I.B. curriculum » sans écrire « deux ans »
- Adresse exacte de dépôt du PDF — adresse masquée par la protection anti-spam de la page (« [email protected] ») ; la fiche renvoie à la page officielle, ce qui est correct
- Heures exactes d’ouverture et de clôture (00:00:00 le 1er juillet 2026 ; 23:59:59 le 31 décembre 2026) et fuseau horaire — page silencieuse : seules les dates sont écrites ; l’heure retenue par la fiche est une convention du dépôt

### `uwc_tanzania_2027_forecast`

- Verdict du relecteur : **verified** — lue le `2026-09-29T15:04:37.000Z` (groupe G1).

| Source | URL | HTTP | Lue |
|---|---|---|---|
| overview | https://tz.uwc.org/ | 200 | oui |
| eligibility | https://tz.uwc.org/eligibility-criteria/ | 200 | oui |
| benefits | https://tz.uwc.org/how-to-apply/ | 200 | oui |
| application | https://tz.uwc.org/how-to-apply/ | 200 | oui |
| cycle | https://tz.uwc.org/how-to-apply/ | 200 | oui |

**Calendrier confirmé par la page**

- Calendrier : la seule ouverture affichée est celle du cycle précédent (8 décembre 2025) — « Application open: December 8th, 2025 »
- Calendrier : la seule clôture affichée est celle du cycle précédent (16 janvier 2026) — « Application deadline: January 16th, 2026 »

**Non vérifié (la page ne le dit pas ou n'a pas pu être lue)**

- Fenêtre 2027 estimée (ouverture 8 décembre 2026, clôture 16 janvier 2027) — page silencieuse sur l’entrée 2027 : seules les dates du cycle précédent (8 décembre 2025 – 16 janvier 2026) figurent, et la fiche les déca…
- Avantage « cursus résidentiel de deux ans préparant au Baccalauréat International » — page silencieuse sur la durée du programme : seuls figurent « final two years of secondary education » et « residential » (eligibility) et …
- Lien de candidature du nouveau cycle — le lien court shorturl.at/EyxkT (cycle 2025-2026) répond 403 et n’est pas une des cinq sources ; la page ne publie aucun lien pour l’entrée…
- Heures exactes des bornes estimées et fuseau horaire — page silencieuse : bornes estimées reprises du cycle précédent, heure choisie par convention du dépôt

### `york_pise_2027_forecast`

- Verdict du relecteur : **verified** — lue le `2026-09-29T15:00:59.000Z` (groupe G5).

| Source | URL | HTTP | Lue |
|---|---|---|---|
| overview | https://futurestudents.yorku.ca/presidents-international-scholarship-excellence | 200 | oui |
| eligibility | https://futurestudents.yorku.ca/presidents-international-scholarship-excellence-application-guides | 200 | oui |
| benefits | https://futurestudents.yorku.ca/financing-your-degree/international-scholarships | 200 | oui |
| application | https://futurestudents.yorku.ca/presidents-international-scholarship-excellence-application-guides | 200 | oui |
| cycle | https://futurestudents.yorku.ca/presidents-international-scholarship-excellence-application-guides | 200 | oui |

**Calendrier confirmé par la page**

- Clôture étudiante : 27 janvier 2027 à 23 h 59 (heure de l’Est, EST) — date de la fiche confirmée, 2027-01-28T04:59:00Z … — « Student Application Deadline: January 27, 2027 at 11:59 p.m. EST »
- Nomination et lettre : 4 février 2027 à 23 h 59 EST — « Nomination & Reference Submission Deadline: February 4, 2027 at 11:59 p.m. EST »

**Non vérifié (la page ne le dit pas ou n'a pas pu être lue)**

- « dépenses restantes possibles » (fundingLabel) et fundingType partially_funded — page silencieuse : elle donne 180 000 CAD sur quatre ans mais ne dit pas si cela couvre l’ensemble des coûts (seuls des témoignages d’étudi…
- Ouverture du formulaire 2027-2028 (statut forecast) — la page affiche les dates Fall 2027 mais aussi « The scholarship application is now closed » et « Application is now closed! » ; aucune dat…
