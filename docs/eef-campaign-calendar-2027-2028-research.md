> ## Ce que KPB retient de cette recherche
>
> Document de recherche reçu le 21/08/2026, conservé **tel quel** en dessous —
> c'est la pièce justificative. Cette en-tête dit ce que l'app en sert, et ce
> qu'elle refuse d'en servir.
>
> ### Servi : l'ouverture, globalement
>
> **1er octobre 2026** comme date d'ouverture pour tous les pays.
> Trois pays la CONFIRMENT explicitement pour la rentrée 2027 (Algérie, Gabon,
> Maroc), trois autres l'estiment (Mali, Rwanda, Maurice), et **aucune source ne
> la contredit**. La plateforme Études en France est nationale : l'ouverture est
> synchronisée, la variance est dans les clôtures.
>
> ### NON servi : aucune clôture globale
>
> Les clôtures divergent — Maroc **15 novembre 2026** (confirmé), Rwanda et
> Maurice 15 décembre (estimé), Algérie « information à venir », 91 couples
> pays × procédure en `not_found`. Servir une clôture globale ferait manquer la
> campagne à un étudiant marocain qui croirait avoir jusqu'en décembre. La
> fenêtre servie n'a donc **qu'une borne** : `opensAt`. L'app sait l'afficher
> seule (« À partir du 1er octobre 2026 »).
>
> Les clôtures par pays arriveront avec le catalogue de la Phase 1, qui est déjà
> structuré par pays.
>
> ### Servi : la suspension du Niger
>
> La source officielle de l'ambassade dit que le traitement des dossiers
> d'étudiants nigériens est **impossible** (dénonciation de la convention du
> centre qui hébergeait Campus France). Annoncer « ouverture le 1er octobre » à
> un étudiant nigérien serait l'envoyer vers une démarche que l'État français
> déclare inopérante — et le Niger est un marché central de KPB.
>
> Les pays suspendus sont donc servis par `KPB_EEF_SUSPENDED_COUNTRIES` : l'app
> y remplace les dates par une mise en garde et un relais conseiller. La liste
> est une variable d'environnement précisément parce qu'une réouverture ne doit
> pas attendre une soumission App Store.
>
> ### Non retenu
>
> Les 91 `not_found` ne deviennent pas des dates. Les `estimated` ne sont pas
> promus en `confirmed` : ils coïncident ici avec le 1er octobre global, ce qui
> est une convergence, pas une confirmation.

---

# Campagnes de candidature aux études supérieures en France — 2027-2028

**Données relevées le 21 août 2026.** Cette base privilégie l’exactitude à la complétude. Une date n’est qualifiée de `confirmed` que lorsqu’une publication officielle vise explicitement la campagne ou la rentrée concernée. Une date `estimated` provient d’une règle annuelle explicitement publiée par une source officielle. Les champs `null` ne doivent pas être interprétés comme une absence d’échéance : ils signifient que l’échéance exacte n’a pas été publiée ou vérifiée.

> Les heures `00:00` (ouverture) et `23:59` (clôture) sont une convention de stockage uniquement lorsqu’une source ne publie qu’un jour ; cette convention est signalée dans `notes`.

| Statut de date | Nombre de couples pays × procédure |
|---|---:|
| confirmed | 7 |
| estimated | 7 |
| unsourced | 0 |
| not_found | 91 |

## Tableau des calendriers

| Pays | Procédure | Ouverture | Clôture | Statut de la date | Statut du service | Source |
|---|---|---|---|---|---|---|
| Mali | Demande d'Admission Préalable (DAP Blanche - L1 / Architecture) | 2026-10-01T00:00:00+00:00 | — | estimated | operational | [Source](https://www.mali.campusfrance.org/1-je-reflechis-a-mon-projet) |
| Mali | Demande d'Admission Préalable (DAP Jaune - Écoles d’architecture) | 2026-10-01T00:00:00+00:00 | — | estimated | operational | [Source](https://www.mali.campusfrance.org/1-je-reflechis-a-mon-projet) |
| Mali | Études en France (Procédure classique / pré-consulaire) | 2026-10-01T00:00:00+00:00 | — | estimated | operational | [Source](https://www.mali.campusfrance.org/1-je-reflechis-a-mon-projet) |
| Algérie | Demande d'Admission Préalable (DAP) Blanche - 1ère année de Licence | 2026-10-01T00:00:00+01:00 | — | confirmed | operational | [Source](https://www.algerie.campusfrance.org/le-calendrier-de-la-procedure) |
| Algérie | Demande d'Admission Préalable (DAP) Jaune - Écoles d'architecture | 2026-10-01T00:00:00+01:00 | — | confirmed | operational | [Source](https://www.algerie.campusfrance.org/le-calendrier-de-la-procedure) |
| Algérie | Procédure Études en France (Hors DAP) | 2026-10-01T00:00:00+01:00 | — | confirmed | operational | [Source](https://www.algerie.campusfrance.org/le-calendrier-de-la-procedure) |
| Gabon | Études en France (Hors DAP) | 2026-10-01T00:00:00+01:00 | — | confirmed | operational | [Source](https://www.gabon.campusfrance.org/je-suis-candidate-procedure-de-candidature-etudes-en-france) |
| Maroc | Demande d’admission préalable (DAP blanche) — L1 | 2026-10-01T00:00:00+01:00 | 2026-11-15T23:59:00+01:00 | confirmed | operational | [Source](https://www.maroc.campusfrance.org/calendrier-de-la-procedure-de-candidature-20262027) |
| Maroc | Demande d’admission préalable (DAP jaune) — écoles d’architecture | 2026-10-01T00:00:00+01:00 | 2026-11-15T23:59:00+01:00 | confirmed | operational | [Source](https://www.maroc.campusfrance.org/calendrier-de-la-procedure-de-candidature-20262027) |
| Maroc | Procédure Études en France | 2026-10-01T00:00:00+01:00 | 2026-11-15T23:59:00+01:00 | confirmed | operational | [Source](https://www.maroc.campusfrance.org/calendrier-de-la-procedure-de-candidature-20262027) |
| Rwanda | Demande d'Admission Préalable (DAP) - Dossier Blanc (Licence 1) | 2026-10-01T00:00:00+02:00 | 2026-12-15T23:59:00+02:00 | estimated | operational | [Source](https://www.rwanda.campusfrance.org/comment-candidater-dans-un-etablissement-d-enseignement-superieur) |
| Rwanda | Demande d'Admission Préalable (DAP) - Dossier Jaune (Écoles d'Architecture) | 2026-10-01T00:00:00+02:00 | 2026-12-15T23:59:00+02:00 | estimated | operational | [Source](https://www.rwanda.campusfrance.org/comment-candidater-dans-un-etablissement-d-enseignement-superieur) |
| Rwanda | Études en France — Licence, Bachelor, Master et BUT | 2026-10-01T00:00:00+02:00 | — | estimated | operational | [Source](https://www.rwanda.campusfrance.org/comment-candidater-dans-un-etablissement-d-enseignement-superieur) |
| Maurice | Demande d'Admission Préalable (DAP) Blanche - 1ère année de licence | 2026-10-01T00:00:00+04:00 | 2026-12-15T23:59:00+04:00 | estimated | operational | [Source](https://www.maurice.campusfrance.org/inscription-en-licence-premiere-annee-au-sein-des-universites-ou-en-ecoles-d-architecture) |
| Bénin | Demande d'Admission Préalable (DAP Blanche - Licence 1) | — | — | not_found | operational | [Source](https://www.benin.campusfrance.org/quelle-procedure-dois-je-suivre) |
| Bénin | Demande d'Admission Préalable (DAP Jaune - Architecture) | — | — | not_found | operational | [Source](https://www.benin.campusfrance.org/quelle-procedure-dois-je-suivre) |
| Bénin | Études en France (Candidatures classiques) | — | — | not_found | operational | [Source](https://www.benin.campusfrance.org/calendrier-des-procedures) |
| Bénin | Parcoursup | — | — | not_found | operational | [Source](https://www.benin.campusfrance.org/calendrier-des-procedures) |
| Bénin | Procédure préconsulaire (Acceptation papier / Hors EEF) | — | — | not_found | operational | [Source](https://www.benin.campusfrance.org/la-procedure-preconsulaire-acceptation-papier-rentree-2026) |
| Burkina Faso | Acceptations hors plateforme Études en France (Procédure préconsulaire) | — | — | not_found | operational | [Source](https://www.burkina.campusfrance.org/calendrier-preconsulaire-2026-2027) |
| Burkina Faso | Demande d'Admission Préalable (DAP Blanche - 1ère année de Licence) | — | — | not_found | operational | [Source](https://www.burkina.campusfrance.org/) |
| Burkina Faso | Demande d'Admission Préalable (DAP Jaune - Écoles d'architecture) | — | — | not_found | operational | [Source](https://www.burkina.campusfrance.org/) |
| Burkina Faso | Parcoursup | — | — | not_found | operational | [Source](https://www.burkina.campusfrance.org/system/files/medias/documents/2024-09/CampusFrance.pdf) |
| Burkina Faso | Procédure Études en France | — | — | not_found | operational | [Source](https://www.burkina.campusfrance.org/) |
| Burundi | Candidatures Hors-DAP / Établissements non connectés | — | — | not_found | operational | [Source](https://www.burundi.campusfrance.org/fr/les-procedures-de-candidature) |
| Burundi | Demande d'Admission Préalable (DAP Blanche) | — | — | not_found | operational | [Source](https://www.burundi.campusfrance.org/fr/les-procedures-de-candidature) |
| Burundi | Demande d’admission préalable (DAP jaune) — écoles d’architecture | — | — | not_found | operational | [Source](https://www.burundi.campusfrance.org/fr/les-etudes-d-art-et-d-architecture) |
| Burundi | Plateforme Études en France | — | — | not_found | operational | [Source](https://www.burundi.campusfrance.org/fr/les-procedures-de-candidature) |
| Burundi | Plateforme Parcoursup | — | — | not_found | operational | [Source](https://www.burundi.campusfrance.org/fr/les-candidatures-sur-parcoursup) |
| Cameroun | Demande d'Admission Préalable (DAP) Blanche - Licence 1 | — | — | not_found | operational | [Source](https://www.cameroun.campusfrance.org/fr/consultez-ici-calendrier-de-candidatures) |
| Cameroun | Demande d'Admission Préalable (DAP) Jaune - Écoles d'architecture | — | — | not_found | operational | [Source](https://www.cameroun.campusfrance.org/fr/consultez-ici-calendrier-de-candidatures) |
| Cameroun | Études en France | — | — | not_found | operational | [Source](https://www.cameroun.campusfrance.org/fr/consultez-ici-calendrier-de-candidatures) |
| Cameroun | Hors Études en France | — | — | not_found | operational | [Source](https://www.cameroun.campusfrance.org/fr/consultez-ici-calendrier-de-candidatures) |
| Cameroun | Parcoursup | — | — | not_found | operational | [Source](https://www.cameroun.campusfrance.org/fr/consultez-ici-calendrier-de-candidatures) |
| Comores | Demande d'Admission Préalable (DAP Blanche - Licence 1) | — | — | not_found | operational | [Source](https://www.comores.campusfrance.org/les-differentes-etapes) |
| Comores | Demande d'Admission Préalable (DAP Jaune - Écoles d'architecture) | — | — | not_found | operational | [Source](https://www.comores.campusfrance.org/les-differentes-etapes) |
| Comores | Parcoursup (BTS, CPGE, etc.) | — | — | not_found | operational | [Source](https://www.comores.campusfrance.org/les-differentes-etapes) |
| Comores | Procédure Études en France (Pré-consulaire) | — | — | not_found | operational | [Source](https://www.comores.campusfrance.org/les-differentes-etapes) |
| Comores | Procédure Hors-DAP (L2, L3, Master, etc.) | — | — | not_found | operational | [Source](https://www.comores.campusfrance.org/les-differentes-etapes) |
| Congo-Brazzaville | DAP Blanche (1ère année de licence en université publique) | — | — | not_found | operational | [Source](https://www.congobrazzaville.campusfrance.org/je-candidate-en-licence-1-a-l-universite) |
| Congo-Brazzaville | DAP Jaune (Écoles d'architecture) | — | — | not_found | operational | [Source](https://www.congobrazzaville.campusfrance.org/je-candidate-en-licence-1-a-l-universite) |
| Congo-Brazzaville | Études en France - Hors DAP (L2, L3, M1, M2, BUT) | — | — | not_found | operational | [Source](https://www.congobrazzaville.campusfrance.org/les-8-etapes-de-la-procedure) |
| Congo-Brazzaville | Hors EEF / Préconsulaire (Établissements privés non connectés) | — | — | not_found | operational | [Source](https://www.congobrazzaville.campusfrance.org/procedure-preconsulaire) |
| Congo-Brazzaville | Parcoursup (BTS, BTSA, CPGE, DCG) | — | — | not_found | operational | [Source](https://www.congobrazzaville.campusfrance.org/procedure-preconsulaire) |
| Côte d’Ivoire | Demande d'Admission Préalable (DAP Blanche - Licence 1) | — | — | not_found | operational | [Source](https://www.ivoire.campusfrance.org/je-veux-m-inscrire-en-licence-1-a-l-universite) |
| Côte d’Ivoire | Demande d'Admission Préalable (DAP Jaune - Architecture) | — | — | not_found | operational | [Source](https://www.ivoire.campusfrance.org/je-veux-m-inscrire-en-licence-1-a-l-universite) |
| Côte d’Ivoire | Parcoursup (BTS, DCG, CPGE et candidats avec Bac français) | — | — | not_found | operational | [Source](https://www.ivoire.campusfrance.org/rentree-2025-postulez-en-bts-dcg-et-en-classes-prepas-grace-a-la-plateforme-parcoursup) |
| Côte d’Ivoire | Procédure Études en France (Hors DAP) | — | — | not_found | operational | [Source](https://www.ivoire.campusfrance.org/) |
| Côte d’Ivoire | Procédure Hors Études en France | — | — | not_found | operational | [Source](https://www.ivoire.campusfrance.org/) |
| Djibouti | Demande d'Admission Préalable (DAP Blanche - Licence 1 / PASS) | — | — | not_found | operational | [Source](https://www.djibouti.campusfrance.org/le-calendrier) |
| Djibouti | Demande d'Admission Préalable (DAP Jaune - Architecture) | — | — | not_found | operational | [Source](https://www.djibouti.campusfrance.org/la-procedure-dap-ou-hors-dap) |
| Djibouti | Études en France | — | — | not_found | operational | [Source](https://www.djibouti.campusfrance.org/le-calendrier) |
| Djibouti | Procédure Hors-DAP (Licence 2/3, Master, etc.) | — | — | not_found | operational | [Source](https://www.djibouti.campusfrance.org/la-procedure-dap-ou-hors-dap) |
| Gabon | Demande d'Admission Préalable (DAP Blanche - L1 / PASS) | — | — | not_found | operational | [Source](https://www.gabon.campusfrance.org/je-suis-candidate-procedure-de-candidature-etudes-en-france) |
| Gabon | Demande d'Admission Préalable (DAP Jaune - Architecture) | — | — | not_found | operational | [Source](https://www.gabon.campusfrance.org/je-suis-candidate-procedure-de-candidature-etudes-en-france) |
| Gabon | Hors EEF / Admission directe / Doctorat | — | — | not_found | operational | [Source](https://www.gabon.campusfrance.org/quelle-procedure-dois-je-suivre-frais-et-cas-d-exemption) |
| Gabon | Parcoursup | — | — | not_found | operational | [Source](https://www.gabon.campusfrance.org/quelle-procedure-dois-je-suivre-frais-et-cas-d-exemption) |
| Guinée | Procédure DAP Blanche (1ère année de licence en université publique) | — | — | not_found | operational | [Source](https://www.guinee.campusfrance.org/calendrier-de-la-procedure) |
| Guinée | Procédure DAP Jaune (Écoles d'architecture) | — | — | not_found | operational | [Source](https://www.guinee.campusfrance.org/calendrier-de-la-procedure) |
| Guinée | Procédure Hors-DAP (Licences 2 et 3, Master, DUT, etc.) | — | — | not_found | operational | [Source](https://www.guinee.campusfrance.org/calendrier-de-la-procedure) |
| Guinée | Procédure Parcoursup (BTS, BTSA, CPGE) | — | — | not_found | operational | [Source](https://www.guinee.campusfrance.org/demandes-en-btsbtsa-et-cpge-la-procedure-parcoursup) |
| Guinée | Procédure pour établissements non connectés (Procédure préconsulaire) | — | — | not_found | operational | [Source](https://www.guinee.campusfrance.org/demandes-en-etablissements-non-connectes-procedure-preconsulaire) |
| Madagascar | Demande d’Admission Préalable (DAP Blanche) | — | — | not_found | operational | [Source](https://www.madagascar.campusfrance.org/les-differentes-procedures-de-candidature) |
| Madagascar | Études en France (Licence 2/3, Master) | — | — | not_found | operational | [Source](https://www.madagascar.campusfrance.org/les-differentes-procedures-de-candidature) |
| Madagascar | Hors Études en France (Doctorat) | — | — | not_found | operational | [Source](https://www.madagascar.campusfrance.org/les-differentes-procedures-de-candidature) |
| Madagascar | Parcoursup (Licence 1 sélective, BTS, CPGE) | — | — | not_found | operational | [Source](https://www.madagascar.campusfrance.org/les-differentes-procedures-de-candidature) |
| Maroc | Hors Études en France | — | — | not_found | operational | [Source](https://www.maroc.campusfrance.org/) |
| Maroc | Parcoursup | — | — | not_found | operational | [Source](https://www.maroc.campusfrance.org/) |
| Maurice | Demande d'Admission Préalable (DAP) Jaune - Écoles d'architecture | — | — | not_found | operational | [Source](https://www.maurice.campusfrance.org/inscription-en-licence-premiere-annee-au-sein-des-universites-ou-en-ecoles-d-architecture) |
| Maurice | Parcoursup | — | — | not_found | operational | [Source](https://www.maurice.campusfrance.org/candidater-si-vous-residez-dans-un-pays-relevant-de-la-procedure-etudes-en-france) |
| Maurice | Procédure Études en France (Hors DAP - BUT, L2, L3, Master) | — | — | not_found | operational | [Source](https://www.maurice.campusfrance.org/inscription-en-butl2l3-et-master) |
| Mauritanie | Demande d'Admission Préalable (DAP) Blanche - 1ère année de Licence / PASS / L.AS | — | — | not_found | operational | [Source](https://www.mauritanie.campusfrance.org/calendrier-2025-2026-pour-la-rentree-universitaire-2026) |
| Mauritanie | Demande d'Admission Préalable (DAP) Jaune - École nationale d'Architecture | — | — | not_found | operational | [Source](https://www.mauritanie.campusfrance.org/calendrier-2025-2026-pour-la-rentree-universitaire-2026) |
| Mauritanie | Hors Demande d'Admission Préalable (Licence 2/3, Master 1/2, BUT, etc.) | — | — | not_found | operational | [Source](https://www.mauritanie.campusfrance.org/calendrier-2025-2026-pour-la-rentree-universitaire-2026) |
| Mauritanie | Procédure Études en France (Globale) | — | — | not_found | operational | [Source](https://www.mauritanie.campusfrance.org/procedure-etudes-en-france) |
| Niger | Études en France | — | — | not_found | suspended | [Source](https://ne.diplomatie.gouv.fr/informations-visas) |
| République centrafricaine | Demande d'Admission Préalable (DAP Blanche - 1ère année de licence) | — | — | not_found | operational | [Source](https://cf.diplomatie.gouv.fr/relations-bilaterales/enseignement-superieur) |
| République centrafricaine | Parcoursup | — | — | not_found | operational | [Source](https://cf.diplomatie.gouv.fr/relations-bilaterales/enseignement-superieur) |
| République centrafricaine | Procédure Études en France | — | — | not_found | operational | [Source](https://cf.diplomatie.gouv.fr/relations-bilaterales/enseignement-superieur) |
| République centrafricaine | Procédure hors Études en France | — | — | not_found | operational | [Source](https://cf.diplomatie.gouv.fr/relations-bilaterales/enseignement-superieur) |
| République démocratique du Congo | Demande d'Admission Préalable (DAP Blanche - 1ère année licence) | — | — | not_found | operational | [Source](https://www.rdc.campusfrance.org/acceptations-electroniques) |
| République démocratique du Congo | Demande d'Admission Préalable (DAP Jaune - Écoles d’architecture) | — | — | not_found | operational | [Source](https://www.rdc.campusfrance.org/acceptations-electroniques) |
| République démocratique du Congo | Procédure Acceptation papier / Établissements non connectés | — | — | not_found | operational | [Source](https://www.rdc.campusfrance.org/acceptations-papier) |
| République démocratique du Congo | Procédure Études en France (Acceptations électroniques) | — | — | not_found | operational | [Source](https://www.rdc.campusfrance.org/acceptations-electroniques) |
| Rwanda | Candidature hors Études en France / Hors DAP (Formations spécifiques ou en anglais non rattachées) | — | — | not_found | operational | [Source](https://www.rwanda.campusfrance.org/comment-candidater-dans-un-etablissement-d-enseignement-superieur) |
| Rwanda | Plateforme Nationale Parcoursup (BTS et formations spécifiques) | — | — | not_found | operational | [Source](https://www.rwanda.campusfrance.org/comment-candidater-dans-un-etablissement-d-enseignement-superieur) |
| Sénégal | Demande d'Admission Préalable (DAP Blanche) | — | — | not_found | operational | [Source](https://www.senegal.campusfrance.org/calendrier-de-la-procedure) |
| Sénégal | Formations non connectées / Candidature directe | — | — | not_found | operational | [Source](https://www.senegal.campusfrance.org/calendrier-de-la-procedure) |
| Sénégal | Parcoursup | — | — | not_found | operational | [Source](https://www.senegal.campusfrance.org/calendrier-de-la-procedure) |
| Sénégal | Procédure Études en France (Formations connectées) | — | — | not_found | operational | [Source](https://www.senegal.campusfrance.org/calendrier-de-la-procedure) |
| Seychelles | Candidature directe — pays non répertorié EEF | — | — | not_found | unclear | [Source](https://www.campusfrance.org/fr/faq/quels-sont-les-pays-relevant-de-la-procedure-etudes-en-france) |
| Tchad | DAP Blanche (Licence 1) | — | — | not_found | operational | [Source](https://www.tchad.campusfrance.org/le-calendrier-des-candidatures) |
| Tchad | DAP Jaune (Architecture) | — | — | not_found | operational | [Source](https://www.tchad.campusfrance.org/le-calendrier-des-candidatures) |
| Tchad | Parcoursup | — | — | not_found | operational | [Source](https://www.tchad.campusfrance.org/les-candidatures-sur-parcoursup) |
| Tchad | Procédure Études en France | — | — | not_found | operational | [Source](https://www.tchad.campusfrance.org/le-calendrier-des-candidatures) |
| Togo | Demande d'Admission Préalable (DAP Blanche - Licence 1) | — | — | not_found | operational | [Source](https://www.togo.campusfrance.org/les-procedures-et-inscriptions) |
| Togo | Demande d'Admission Préalable (DAP Jaune - Architecture) | — | — | not_found | operational | [Source](https://www.togo.campusfrance.org/les-procedures-et-inscriptions) |
| Togo | Études en France | — | — | not_found | operational | [Source](https://www.togo.campusfrance.org/les-procedures-et-inscriptions) |
| Togo | Hors Études en France (Établissements non connectés / Doctorat) | — | — | not_found | operational | [Source](https://www.togo.campusfrance.org/les-procedures-et-inscriptions) |
| Togo | Parcoursup | — | — | not_found | operational | [Source](https://www.togo.campusfrance.org/les-procedures-et-inscriptions) |
| Tunisie | Demande d'Admission Préalable (DAP Blanche) - Licence 1 | — | — | not_found | operational | [Source](https://www.tunisie.campusfrance.org/licence-1-dap-blanche-0) |
| Tunisie | Demande d'Admission Préalable (DAP Jaune) - Écoles d'architecture | — | — | not_found | operational | [Source](https://www.tunisie.campusfrance.org/) |
| Tunisie | Établissements non connectés / Hors Études en France | — | — | not_found | operational | [Source](https://www.tunisie.campusfrance.org/masters-masteres) |
| Tunisie | Parcoursup - BTS, CPGE, DCG et IFSI | — | — | not_found | operational | [Source](https://www.tunisie.campusfrance.org/bts-cpge-dcg-et-ifsi) |
| Tunisie | Procédure Études en France (Hors-DAP) - Master, Licences 2 et 3 | — | — | not_found | operational | [Source](https://www.tunisie.campusfrance.org/masters-masteres) |

## Statut du service

| Pays | Statut | Source | Preuve relevée |
|---|---|---|---|
| Sénégal | operational | [Source](https://www.senegal.campusfrance.org/) | https://www.senegal.campusfrance.org/ — L'espace Campus France au Sénégal est un service de l'Ambassade de France et de l'Institut Français au Sénégal. Il accompagne les étudiants sénégalais pour préparer leur projet d'études en France. |
| Côte d’Ivoire | operational | [Source](https://www.ivoire.campusfrance.org/) | https://www.ivoire.campusfrance.org/ — "Campus France Côte d'Ivoire, service de l'Ambassade de France, est le seul organisme en Côte d'Ivoire, habilité à accompagner les mobilités étudiantes vers la France." |
| Mali | operational | [Source](https://www.mali.campusfrance.org/) | https://www.mali.campusfrance.org/ — "La date limite impérative pour soumettre votre dossier, si vous êtes titulaire du baccalauréat malien de 2026, admis en France dans un établissement d’enseignement supérieur privé pour les rentrées de septembre, octobre, novembre 2026 est le lundi 24 août à 23h00." |
| Burkina Faso | operational | [Source](https://www.burkina.campusfrance.org/horaires-de-reception-et-coordonnees) | https://www.burkina.campusfrance.org/horaires-de-reception-et-coordonnees — "Horaire d'ouverture · Du lundi au vendredi de 08h30 à 12h30 et de 13h30 à 17h00 · Téléphone : +226 54 49 53 08 / +226 54 51 16 17" |
| Niger | suspended | [Source](https://ne.diplomatie.gouv.fr/informations-visas) | https://ne.diplomatie.gouv.fr/informations-visas — « En outre, la décision nigérienne de dénoncer la convention bilatérale instituant le centre culturel franco-nigérien Jean Rouch, qui accueillait Campus France, organisme en charge des mobilités étudiantes vers la France, rend impossible le traitement des dossiers des étudiants nigériens souhaitant s’inscrire dans des universités françaises. » |
| Guinée | operational | [Source](https://gn.diplomatie.gouv.fr/fr/campus-france-guinee) | https://gn.diplomatie.gouv.fr/fr/campus-france-guinee — "Campus France Guinée est l’organe dédié à la promotion de l’enseignement supérieur français et à l’accompagnement des étudiants guinéens souhaitant poursuivre leurs études en France. En 2024-2025, Campus France Guinée a eu le bonheur d’accompagner plus de 5 000 étudiants dans leur démarche de candidature aux études en France." |
| Bénin | operational | [Source](https://www.benin.campusfrance.org/) | https://www.benin.campusfrance.org/ — "Campus France Bénin est un service de l'Ambassade de France au Bénin dédié aux résidants du Bénin non ressortissant de l’Union Européenne souhaitant poursuivre leurs études supérieures en France." |
| Togo | operational | [Source](https://tg.diplomatie.gouv.fr/campus-france-togo) | https://tg.diplomatie.gouv.fr/campus-france-togo — « Campus France Togo est un service de l'Ambassade de France au Togo qui a pour principal objectif de promouvoir l’enseignement supérieur français auprès des étudiants. » |
| Mauritanie | operational | [Source](https://institutfrancais-mauritanie.com/etudier-en-france/) | https://institutfrancais-mauritanie.com/etudier-en-france/ — "L’Espace Campus France Mauritanie est ouvert au public : Lundi : 9 h 30 – 18 h 00 sur rendez-vous Mardi : 9 h 30 – 18 h 00 Mercredi : 9 h 30 – 18 h 00 Jeudi : 9 h 30 – 18 h 00 Vendredi : 9 h 30 – 13 h 00" |
| Cameroun | operational | [Source](https://www.cameroun.campusfrance.org/fr/nous-contacter) | https://www.cameroun.campusfrance.org/fr/nous-contacter — "Campus France au Cameroun est à l'Institut Français du Cameroun (IFC) à Yaoundé et à Douala et regroupe toutes les demandes d'étudiants camerounais ou résidant au Cameroun." |
| Gabon | operational | [Source](https://www.gabon.campusfrance.org/je-suis-candidate-procedure-de-candidature-etudes-en-france) | https://www.gabon.campusfrance.org/je-suis-candidate-procedure-de-candidature-etudes-en-france — "Rendez vous le 1er octobre 2026 pour déposer vos candidatures pour la rentrée de septembre 2027" |
| Congo-Brazzaville | operational | [Source](https://www.congobrazzaville.campusfrance.org/les-8-etapes-de-la-procedure) | https://www.congobrazzaville.campusfrance.org/les-8-etapes-de-la-procedure — Si vous êtes étudiant(e) congolais(e) ou étranger(ère) et que vous envisagez de poursuivre vos études en France, vous devez obligatoirement suivre la procédure « Etudes en France » (également appelée « procédure Campus France »). |
| République démocratique du Congo | operational | [Source](https://www.rdc.campusfrance.org/acceptations-electroniques) | https://www.rdc.campusfrance.org/acceptations-electroniques — "Le dossier électronique \" Je suis candidat \" permet de candidater en ligne auprès des établissements de l'enseignement supérieur français connectés à la plateforme Etudes en France" |
| Tchad | operational | [Source](https://www.tchad.campusfrance.org/) | https://www.tchad.campusfrance.org/ — Tchad Campus France est l'agence officielle française chargée de promouvoir l'enseignement supérieur français à l'étranger, de gérer les programmes de bourses et d'accompagner les étudiants internationaux dans leurs projets d'études et de recherche en France. |
| République centrafricaine | operational | [Source](https://cf.diplomatie.gouv.fr/relations-bilaterales/enseignement-superieur) | https://cf.diplomatie.gouv.fr/relations-bilaterales/enseignement-superieur — "Les procédures d’inscription pour la rentrée académique 2026-27 sont ouvertes." |
| Maroc | operational | [Source](https://www.maroc.campusfrance.org/) | https://www.maroc.campusfrance.org/ — « Campus France Maroc vous propose un entretien d'accompagnement gratuit afin de vous aider dans la construction de votre projet d'études. » |
| Algérie | operational | [Source](https://www.algerie.campusfrance.org/le-calendrier-de-la-procedure) | https://www.algerie.campusfrance.org/le-calendrier-de-la-procedure — "La nouvelle campagne Études en France sera ouverte le 1er octobre 2026 pour préparer la rentrée 2027 en France." |
| Tunisie | operational | [Source](https://www.tunisie.campusfrance.org/) | https://www.tunisie.campusfrance.org/ — "Durant l'été, Adoptez les bons reflexes pour préparer au mieux votre venue dans les 03 espaces Campus France de Tunis, Sousse et Sfax." |
| Madagascar | operational | [Source](https://www.madagascar.campusfrance.org/) | https://www.madagascar.campusfrance.org/ — « La plateforme mondiale « Études en France » commune à 69 pays, dont Madagascar, a été mise en place en 2015. Simple d’utilisation, elle permet aux étudiants malgaches de créer un dossier de candidature en ligne » |
| Comores | operational | [Source](https://www.comores.campusfrance.org/) | https://www.comores.campusfrance.org/ — « afin de faciliter la mobilité des étudiants comoriens désireux de poursuivre leurs études en France, l’Espace CampusFrance – Union des Comores a pour mission d’accompagner et d’orienter les étudiants tout au long de la préparation de leur projet d’études. » |
| Djibouti | operational | [Source](https://www.djibouti.campusfrance.org/la-procedure-etudes-en-france) | https://www.djibouti.campusfrance.org/la-procedure-etudes-en-france — Djibouti fait partie des pays relevant de la procédure « Études en France », plateforme numérique permettant aux étudiants étrangers de postuler dans des établissements d’enseignement supérieur français connectés sur la plateforme... |
| Maurice | operational | [Source](https://www.maurice.campusfrance.org/candidater-si-vous-residez-dans-un-pays-relevant-de-la-procedure-etudes-en-france) | https://www.maurice.campusfrance.org/candidater-si-vous-residez-dans-un-pays-relevant-de-la-procedure-etudes-en-france — La plateforme Études en France est entièrement dématérialisée et permet de gérer l’ensemble des démarches d’inscription dans un établissement d’enseignement supérieur jusqu’à la demande de visa. |
| Rwanda | operational | [Source](https://www.rwanda.campusfrance.org/bienvenue-dans-l-espace-campus-france-rwanda) | https://www.rwanda.campusfrance.org/bienvenue-dans-l-espace-campus-france-rwanda — "Le bureau de Campus France Rwanda, hébergé au sein du Centre Culturel Francophone du Rwanda, est là pour vous recevoir, vous conseiller et vous accompagner dans vos démarches." |
| Burundi | operational | [Source](https://www.burundi.campusfrance.org/fr/l-espace-campus-france-au-burundi) | https://www.burundi.campusfrance.org/fr/l-espace-campus-france-au-burundi — "Les bureaux de Campus France Burundi vous accueillent sans rendez-vous : mardi de 14h à 17h; mercredi de 14h à 17h; jeudi de 14h à 17h; vendredi de 14h à 17h." |
| Seychelles | unclear | [Source](https://sc.diplomatie.gouv.fr/fr/etudier-en-france) | https://sc.diplomatie.gouv.fr/fr/etudier-en-france — "Campus France accompagne les étudiants étrangers dans leur projet, en France et via son réseau de près de 260 espaces et antennes répartis dans 123 pays dans le monde." |

## Contradictions et limites de vérification

Aucune contradiction explicite entre deux calendriers officiels pays-spécifiques n’a été retenue. En revanche, la donnée initiale visant les Seychelles comportait une date tirée du site Campus France Pologne ; cette page ne vise pas les Seychelles et a été écartée. La FAQ nationale Campus France liste 73 pays relevant d’Études en France sans inclure les Seychelles. La page de l’ambassade de France aux Seychelles ne désigne ni un espace compétent ni un calendrier ; la procédure est donc renseignée comme `hors_eef`, `not_found`, et le statut de service `unclear`.

Au Niger, le statut est `suspended` parce que la page officielle de l’ambassade affirme que la fermeture du consulat et la disparition du centre hébergeant Campus France rendent impossible le traitement des dossiers. Une date de plateforme, si elle apparaissait ailleurs, ne devrait pas être présentée comme un service utilisable dans ce contexte.

La limite structurelle principale est temporelle : au 21 août 2026, de nombreux espaces publient encore les échéances 2025-2026 ou 2026-2027. Elles sont citées comme éléments d’identification des procédures mais ne sont jamais converties en dates 2027-2028 confirmées. Les procédures hors EEF peuvent par nature dépendre du calendrier propre à chaque établissement ; elles demeurent `not_found` lorsqu’aucune échéance centralisée officielle n’est publiée.

## Sources-clés vérifiées directement

| Référence | Source officielle | Élément vérifié |
|---:|---|---|
| 1 | [Campus France Gabon](https://www.gabon.campusfrance.org/je-suis-candidate-procedure-de-candidature-etudes-en-france) | « Rendez vous le 1er octobre 2026 pour déposer vos candidatures pour la rentrée de septembre 2027 ». |
| 2 | [Campus France Maroc](https://www.maroc.campusfrance.org/calendrier-de-la-procedure-de-candidature-20262027) | Fenêtre 1er octobre 2026 — 15 novembre 2026 à 23h59 pour les formations connectées, incluant DAP blanche et jaune. |
| 3 | [Campus France Algérie](https://www.algerie.campusfrance.org/le-calendrier-de-la-procedure) | Ouverture le 1er octobre 2026 ; les dates limites DAP et hors-DAP sont indiquées « Information à venir ». |
| 4 | [Ambassade de France au Niger](https://ne.diplomatie.gouv.fr/informations-visas) | Impossibilité officielle de traiter les dossiers d’étudiants nigériens. |
| 5 | [FAQ Campus France — pays EEF](https://www.campusfrance.org/fr/faq/quels-sont-les-pays-relevant-de-la-procedure-etudes-en-france) | Liste nationale des 73 pays relevant de la procédure EEF ; les Seychelles n’y figurent pas. |

