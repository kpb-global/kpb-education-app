// Motivation letter templates — 6 models in FR, each with a category tag.
// The backend personalises them via Groq and returns FR + EN versions.

class LetterTemplate {
  final String key;
  final String titleFr;
  final String titleEn;
  final String category; // admission | scholarship | visa | internship
  final String bodyFr;

  const LetterTemplate({
    required this.key,
    required this.titleFr,
    required this.titleEn,
    required this.category,
    required this.bodyFr,
  });
}

const kLetterTemplates = <LetterTemplate>[
  // ── Admissions ─────────────────────────────────────────────────────────────
  LetterTemplate(
    key: 'admission_general',
    titleFr: 'Admission universitaire (general)',
    titleEn: 'University Admission (general)',
    category: 'admission',
    bodyFr: '''Madame, Monsieur,

Actuellement etudiant(e) en [NIVEAU] dans le domaine de [DOMAINE], je souhaite integrer votre etablissement pour poursuivre mes etudes au sein de votre programme de [PROGRAMME].

Votre universite m'attire particulierement par la qualite de son enseignement et son ouverture internationale. Au cours de mon parcours, j'ai developpe des competences solides en [COMPETENCES] et une capacite d'adaptation qui me permettront de contribuer activement a la vie academique de votre institution.

Mon objectif est de [OBJECTIF PROFESSIONNEL]. Je suis convaincu(e) que votre formation me donnera les outils necessaires pour y parvenir.

Je reste a votre disposition pour tout entretien complementaire et vous prie d'agreer, Madame, Monsieur, l'expression de mes salutations distinguees.

[NOM]''',
  ),

  LetterTemplate(
    key: 'admission_master',
    titleFr: 'Admission en Master / Programme specialise',
    titleEn: 'Master / Specialised Programme Admission',
    category: 'admission',
    bodyFr: '''Madame, Monsieur le Directeur du programme,

Titulaire d'un [DIPLOME] en [DOMAINE] obtenu a [UNIVERSITE], je me permets de vous adresser ma candidature pour integrer votre programme de Master en [SPECIALITE].

Mon parcours academique m'a permis d'acquerir une expertise en [DOMAINE EXPERTISE]. J'ai egalement eu l'opportunite de realiser [PROJET/STAGE] qui a renforce ma determination a me specialiser dans ce domaine.

Votre programme se distingue par [POINT FORT DU PROGRAMME], ce qui correspond parfaitement a mon projet professionnel de [OBJECTIF]. Je suis particulierement interesse(e) par les modules de [MODULES] et la possibilite de [OPPORTUNITE].

Je serais honore(e) de pouvoir contribuer a la richesse de votre promotion par mon parcours atypique et ma motivation sans faille.

Dans l'attente de votre reponse, veuillez agreer mes salutations respectueuses.

[NOM]''',
  ),

  // ── Bourses ────────────────────────────────────────────────────────────────
  LetterTemplate(
    key: 'scholarship_kpb',
    titleFr: 'Bourse d\'etudes KPB Education',
    titleEn: 'KPB Education Scholarship',
    category: 'scholarship',
    bodyFr: '''A l'attention du Comite de selection KPB Education,

Je me permets de soumettre ma candidature pour la bourse d'etudes KPB Education en vue de poursuivre mes etudes en [DOMAINE] au [PAYS].

Issu(e) de [CONTEXTE], j'ai toujours fait preuve de determination pour atteindre mes objectifs academiques. Malgre [DIFFICULTES/DEFIS], j'ai obtenu d'excellents resultats qui temoignent de mon engagement envers l'excellence.

Cette bourse representerait pour moi une opportunite decisive pour :
- Acceder a une formation de qualite internationale en [DOMAINE]
- Developper des competences qui me permettront de contribuer au developpement de mon pays
- Rejoindre un reseau d'alumni engages et dynamiques

Mon projet professionnel consiste a [OBJECTIF]. Je m'engage a mettre les connaissances acquises au service de [CAUSE/COMMUNAUTE].

Je vous remercie de l'attention portee a ma candidature.

[NOM]''',
  ),

  LetterTemplate(
    key: 'scholarship_international',
    titleFr: 'Bourse d\'excellence internationale',
    titleEn: 'International Excellence Scholarship',
    category: 'scholarship',
    bodyFr: '''Dear Selection Committee / Madame, Monsieur,

Je soumets respectueusement ma candidature pour la bourse [NOM DE LA BOURSE] afin de poursuivre mes etudes de [NIVEAU] en [DOMAINE] au [PAYS].

Mon parcours academique est marque par [REALISATIONS]. Ces experiences m'ont forge(e) une vision claire : [VISION].

Je crois fermement que cette bourse me permettra de :
- Poursuivre des etudes dans un environnement academique d'excellence
- Developper une expertise internationale en [DOMAINE]
- Contribuer au rayonnement de [PAYS D'ORIGINE] par le transfert de competences

A mon retour, je prevois de [PROJET DE RETOUR]. Mon engagement communautaire actuel dans [ACTIVITES] temoigne deja de cette volonte d'impact positif.

Je me tiens a votre entiere disposition pour tout complement d'information.

Respectueusement,
[NOM]''',
  ),

  // ── Visa ───────────────────────────────────────────────────────────────────
  LetterTemplate(
    key: 'visa_student',
    titleFr: 'Lettre de motivation visa etudiant',
    titleEn: 'Student Visa Motivation Letter',
    category: 'visa',
    bodyFr: '''Madame, Monsieur le Consul,

Je soussigne(e) [NOM], de nationalite [NATIONALITE], sollicite par la presente un visa etudiant pour le [PAYS] afin de poursuivre mes etudes de [NIVEAU] en [DOMAINE] a [UNIVERSITE].

J'ai ete admis(e) au programme de [PROGRAMME] pour l'annee universitaire [ANNEE]. Mon projet d'etudes est le suivant :
- Duree : [DUREE]
- Diplome vise : [DIPLOME]
- Financement : [BOURSE / FONDS PROPRES / GARANT]

Je m'engage a respecter les lois et reglementations du pays d'accueil, a suivre assidument les cours et a retourner dans mon pays d'origine a l'issue de mes etudes. Mes attaches familiales et professionnelles dans mon pays garantissent mon retour.

Vous trouverez ci-joint l'ensemble des documents justificatifs requis.

Je vous prie d'agreer, Madame, Monsieur le Consul, l'expression de ma haute consideration.

[NOM]''',
  ),

  // ── Alternance / Stage ─────────────────────────────────────────────────────
  LetterTemplate(
    key: 'internship_alternance',
    titleFr: 'Stage ou alternance a l\'international',
    titleEn: 'International Internship / Work-Study',
    category: 'internship',
    bodyFr: '''Madame, Monsieur,

Etudiant(e) en [NIVEAU] en [DOMAINE] a [UNIVERSITE], je recherche activement un stage / une alternance de [DUREE] dans le secteur de [SECTEUR] a compter de [DATE].

Au cours de ma formation, j'ai acquis des competences en [COMPETENCES] ainsi qu'une experience pratique lors de [EXPERIENCE PRECEDENTE]. Mon profil international — je maitrise [LANGUES] — constitue un atout pour votre equipe.

Votre entreprise m'interesse particulierement pour [RAISON : projet innovant, valeurs, secteur]. Je souhaite contribuer a [CONTRIBUTION CONCRETE] tout en developpant mon expertise dans [DOMAINE].

Disponible et motive(e), je serais ravi(e) de vous presenter mon parcours lors d'un entretien.

Cordialement,
[NOM]''',
  ),
];

const kLetterCategories = ['admission', 'scholarship', 'visa', 'internship'];

String categoryLabelFr(String cat) {
  switch (cat) {
    case 'admission':
      return 'Admissions';
    case 'scholarship':
      return 'Bourses';
    case 'visa':
      return 'Visa';
    case 'internship':
      return 'Stage / Alternance';
    default:
      return cat;
  }
}

String categoryLabelEn(String cat) {
  switch (cat) {
    case 'admission':
      return 'Admissions';
    case 'scholarship':
      return 'Scholarships';
    case 'visa':
      return 'Visa';
    case 'internship':
      return 'Internship';
    default:
      return cat;
  }
}
