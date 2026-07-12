import 'package:get/get.dart';
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

List<LetterTemplate> get kLetterTemplates => <LetterTemplate>[
      // ── Admissions ─────────────────────────────────────────────────────────────
      LetterTemplate(
        key: 'admission_general',
        titleFr: 'letter_tpl_admission_general_title'.tr,
        titleEn: 'University Admission (general)',
        category: 'admission',
        bodyFr: '''Madame, Monsieur,

Actuellement étudiant(e) en [NIVEAU] dans le domaine de [DOMAINE], je souhaite intégrer votre établissement pour poursuivre mes études au sein de votre programme de [PROGRAMME].

Votre université m'attire particulièrement par la qualité de son enseignement et son ouverture internationale. Au cours de mon parcours, j'ai développé des compétences solides en [COMPETENCES] et une capacité d'adaptation qui me permettront de contribuer activement à la vie académique de votre institution.

Mon objectif est de [OBJECTIF PROFESSIONNEL]. Je suis convaincu(e) que votre formation me donnera les outils nécessaires pour y parvenir.

Je reste à votre disposition pour tout entretien complémentaire et vous prie d'agréer, Madame, Monsieur, l'expression de mes salutations distinguées.

[NOM]''',
      ),

      LetterTemplate(
        key: 'admission_master',
        titleFr: 'letter_tpl_admission_master_title'.tr,
        titleEn: 'Master / Specialised Programme Admission',
        category: 'admission',
        bodyFr: '''Madame, Monsieur le Directeur du programme,

Titulaire d'un [DIPLOME] en [DOMAINE] obtenu à [UNIVERSITE], je me permets de vous adresser ma candidature pour intégrer votre programme de Master en [SPECIALITE].

Mon parcours académique m'a permis d'acquérir une expertise en [DOMAINE EXPERTISE]. J'ai également eu l'opportunité de réaliser [PROJET/STAGE] qui a renforcé ma détermination à me spécialiser dans ce domaine.

Votre programme se distingue par [POINT FORT DU PROGRAMME], ce qui correspond parfaitement à mon projet professionnel de [OBJECTIF]. Je suis particulièrement intéressé(e) par les modules de [MODULES] et la possibilité de [OPPORTUNITE].

Je serais honoré(e) de pouvoir contribuer à la richesse de votre promotion par mon parcours atypique et ma motivation sans faille.

Dans l'attente de votre réponse, veuillez agréer mes salutations respectueuses.

[NOM]''',
      ),

      // ── Bourses ────────────────────────────────────────────────────────────────
      LetterTemplate(
        key: 'scholarship_kpb',
        titleFr: 'letter_tpl_scholarship_kpb_title'.tr,
        titleEn: 'KPB Education Scholarship',
        category: 'scholarship',
        bodyFr: '''À l'attention du Comité de sélection KPB Education,

Je me permets de soumettre ma candidature pour la bourse d'études KPB Education en vue de poursuivre mes études en [DOMAINE] au [PAYS].

Issu(e) de [CONTEXTE], j'ai toujours fait preuve de détermination pour atteindre mes objectifs académiques. Malgré [DIFFICULTES/DEFIS], j'ai obtenu d'excellents résultats qui témoignent de mon engagement envers l'excellence.

Cette bourse représenterait pour moi une opportunité décisive pour :
- Accéder à une formation de qualité internationale en [DOMAINE]
- Développer des compétences qui me permettront de contribuer au développement de mon pays
- Rejoindre un réseau d'alumni engagés et dynamiques

Mon projet professionnel consiste à [OBJECTIF]. Je m'engage à mettre les connaissances acquises au service de [CAUSE/COMMUNAUTE].

Je vous remercie de l'attention portée à ma candidature.

[NOM]''',
      ),

      LetterTemplate(
        key: 'scholarship_international',
        titleFr: 'letter_tpl_scholarship_international_title'.tr,
        titleEn: 'International Excellence Scholarship',
        category: 'scholarship',
        bodyFr: '''Dear Selection Committee / Madame, Monsieur,

Je soumets respectueusement ma candidature pour la bourse [NOM DE LA BOURSE] afin de poursuivre mes études de [NIVEAU] en [DOMAINE] au [PAYS].

Mon parcours académique est marqué par [REALISATIONS]. Ces expériences m'ont forgé(e) une vision claire : [VISION].

Je crois fermement que cette bourse me permettra de :
- Poursuivre des études dans un environnement académique d'excellence
- Développer une expertise internationale en [DOMAINE]
- Contribuer au rayonnement de [PAYS D'ORIGINE] par le transfert de compétences

À mon retour, je prévois de [PROJET DE RETOUR]. Mon engagement communautaire actuel dans [ACTIVITES] témoigne déjà de cette volonté d'impact positif.

Je me tiens à votre entière disposition pour tout complément d'information.

Respectueusement,
[NOM]''',
      ),

      // ── Visa ───────────────────────────────────────────────────────────────────
      LetterTemplate(
        key: 'visa_student',
        titleFr: 'letter_tpl_visa_student_title'.tr,
        titleEn: 'Student Visa Motivation Letter',
        category: 'visa',
        bodyFr: '''Madame, Monsieur le Consul,

Je soussigné(e) [NOM], de nationalité [NATIONALITE], sollicite par la présente un visa étudiant pour le [PAYS] afin de poursuivre mes études de [NIVEAU] en [DOMAINE] à [UNIVERSITE].

J'ai été admis(e) au programme de [PROGRAMME] pour l'année universitaire [ANNEE]. Mon projet d'études est le suivant :
- Durée : [DUREE]
- Diplôme visé : [DIPLOME]
- Financement : [BOURSE / FONDS PROPRES / GARANT]

Je m'engage à respecter les lois et réglementations du pays d'accueil, à suivre assidûment les cours et à retourner dans mon pays d'origine à l'issue de mes études. Mes attaches familiales et professionnelles dans mon pays garantissent mon retour.

Vous trouverez ci-joint l'ensemble des documents justificatifs requis.

Je vous prie d'agréer, Madame, Monsieur le Consul, l'expression de ma haute considération.

[NOM]''',
      ),

      // ── Alternance / Stage ─────────────────────────────────────────────────────
      LetterTemplate(
        key: 'internship_alternance',
        titleFr: 'letter_tpl_internship_title'.tr,
        titleEn: 'International Internship / Work-Study',
        category: 'internship',
        bodyFr: '''Madame, Monsieur,

Étudiant(e) en [NIVEAU] en [DOMAINE] à [UNIVERSITE], je recherche activement un stage / une alternance de [DUREE] dans le secteur de [SECTEUR] à compter de [DATE].

Au cours de ma formation, j'ai acquis des compétences en [COMPETENCES] ainsi qu'une expérience pratique lors de [EXPERIENCE PRECEDENTE]. Mon profil international — je maîtrise [LANGUES] — constitue un atout pour votre équipe.

Votre entreprise m'intéresse particulièrement pour [RAISON : projet innovant, valeurs, secteur]. Je souhaite contribuer à [CONTRIBUTION CONCRETE] tout en développant mon expertise dans [DOMAINE].

Disponible et motivé(e), je serais ravi(e) de vous présenter mon parcours lors d'un entretien.

Cordialement,
[NOM]''',
      ),
    ];

const kLetterCategories = ['admission', 'scholarship', 'visa', 'internship'];

String categoryLabelFr(String cat) {
  switch (cat) {
    case 'admission':
      return 'letter_category_admission'.tr;
    case 'scholarship':
      return 'letter_category_scholarship'.tr;
    case 'visa':
      return 'Visa';
    case 'internship':
      return 'letter_category_internship'.tr;
    default:
      return cat;
  }
}

String categoryLabelEn(String cat) {
  switch (cat) {
    case 'admission':
      return 'letter_category_admission'.tr;
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
