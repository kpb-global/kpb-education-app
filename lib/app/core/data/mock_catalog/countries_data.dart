// AUTO-GENERATED — KPB Education catalog seed data.
// ignore_for_file: lines_longer_than_80_chars
import '../../models/app_models.dart';

const kCountries = <CountryModel>[
    CountryModel(
      id: 'usa',
      name: LocalizedText(fr: 'États-Unis', en: 'United States'),
      whyStudy: LocalizedText(
          fr: 'Réseau universitaire mondial, diversité de programmes, carrières tech et recherche.',
          en: 'World-class universities, diverse programs, tech and research careers.'),
      tuitionRange: LocalizedText(fr: 'USD 15k–45k/an', en: 'USD 15k–45k/year'),
      livingCostRange:
          LocalizedText(fr: 'USD 900–2 000/mois', en: 'USD 900–2 000/month'),
      visaOverview: LocalizedText(
          fr: 'Visa F-1 avec preuve financière et I-20 de l\'université.',
          en: 'F-1 visa with financial proof and I-20 from university.'),
      admissionDifficulty: LocalizedText(fr: 'Élevée', en: 'High'),
      popularFieldIds: ['d01', 'd05', 'd02'],
    ),
    CountryModel(
      id: 'canada',
      name: LocalizedText(fr: 'Canada', en: 'Canada'),
      whyStudy: LocalizedText(
          fr: 'Excellente qualité de vie, parcours francophones et anglophones, immigration facilitée après études.',
          en: 'Excellent quality of life, French and English programs, facilitated post-study immigration.'),
      tuitionRange: LocalizedText(fr: 'CAD 10k–30k/an', en: 'CAD 10k–30k/year'),
      livingCostRange:
          LocalizedText(fr: 'CAD 800–1 500/mois', en: 'CAD 800–1 500/month'),
      visaOverview: LocalizedText(
          fr: 'Permis d\'études avec lettre d\'admission et preuve financière.',
          en: 'Study permit with admission letter and financial proof.'),
      admissionDifficulty: LocalizedText(fr: 'Modérée', en: 'Moderate'),
      popularFieldIds: ['d01', 'd02', 'd09'],
    ),
    CountryModel(
      id: 'china',
      name: LocalizedText(fr: 'Chine', en: 'China'),
      flagEmoji: '🇨🇳',
      tagline: LocalizedText(
          fr: 'Bourses CSC généreuses · diplômes reconnus · destination n°1 des étudiants africains en Asie',
          en: 'Generous CSC scholarships · recognized degrees · the #1 Asian destination for African students'),
      mainLanguage: LocalizedText(
          fr: 'Chinois (mandarin) — nombreux programmes 100 % en anglais',
          en: 'Chinese (Mandarin) — many fully English-taught programs'),
      whyStudy: LocalizedText(
          fr: 'La Chine est devenue la 1ʳᵉ destination des étudiants africains hors du continent : universités classées au top mondial, milliers de bourses CSC (souvent intégrales : frais + logement + allocation mensuelle), et un accueil structuré des étudiants africains (notamment via Jinhua / Zhejiang Normal University).',
          en: 'China is now the top destination for African students outside the continent: world-ranked universities, thousands of CSC scholarships (often full: tuition + housing + monthly stipend) and structured support for African students (notably via Jinhua / Zhejiang Normal University).'),
      marketingDescription: LocalizedText(
          fr: 'Avec KPB, tu candidates dans les universités où la diaspora étudiante africaine est déjà bien installée — tu n\'arrives pas en terrain inconnu.',
          en: 'With KPB you apply to the universities where the African student community is already well established — you don\'t arrive on unknown ground.'),
      whyStudyBulletsFr: [
        'Bourses CSC : frais de scolarité + chambre + allocation mensuelle (~2 500–3 500 CNY) souvent couverts',
        'Des centaines de programmes Licence/Master/Doctorat enseignés 100 % en anglais',
        'Coût de la vie bas comparé à l\'Europe ou l\'Amérique du Nord',
        'Forte communauté d\'étudiants africains, surtout à Jinhua, Pékin, Wuhan et Nankin',
        'Diplômes reconnus internationalement, débouchés en ingénierie, médecine (MBBS) et tech',
      ],
      whyStudyBulletsEn: [
        'CSC scholarships: tuition + dorm room + monthly stipend (~2,500–3,500 CNY) often covered',
        'Hundreds of Bachelor/Master/PhD programs taught 100% in English',
        'Low cost of living compared with Europe or North America',
        'Large African student community, especially in Jinhua, Beijing, Wuhan and Nanjing',
        'Internationally recognized degrees; strong outcomes in engineering, medicine (MBBS) and tech',
      ],
      // Steps are split on "·" by howItWorksStepsFor — visa procedure, to reassure.
      howItWorks: LocalizedText(
          fr: 'Choix de l\'université et du programme avec ton conseiller KPB · Candidature + dossier de bourse CSC/HSK (relevés, passeport, certificat médical, lettres) · Réception de la lettre d\'admission et du formulaire JW202/JW201 de l\'université · Demande du visa étudiant X1 à l\'ambassade de Chine avec le JW202 · Départ, puis conversion en permis de séjour dans les 30 jours après l\'arrivée (accompagné par le bureau international) · KPB te suit à chaque étape jusqu\'à ton installation sur le campus',
          en: 'Pick the university and program with your KPB advisor · Application + CSC/HSK scholarship file (transcripts, passport, medical certificate, letters) · Receive the admission letter and the university\'s JW202/JW201 form · Apply for the X1 student visa at the Chinese embassy with the JW202 · Travel, then convert to a residence permit within 30 days of arrival (guided by the international office) · KPB follows you at every step until you settle on campus'),
      costsOverview: LocalizedText(
          fr: 'Sans bourse, compte CNY 20 000–45 000/an de frais. Avec une bourse CSC ou provinciale (très fréquentes pour les Africains), les frais et le logement sont souvent gratuits, avec une allocation mensuelle.',
          en: 'Without a scholarship, budget CNY 20,000–45,000/yr in fees. With a CSC or provincial scholarship (very common for Africans), tuition and housing are often free, plus a monthly stipend.'),
      tuitionRange: LocalizedText(
          fr: 'CNY 20k–45k/an (souvent couvert par bourse)',
          en: 'CNY 20k–45k/year (often scholarship-covered)'),
      livingCostRange:
          LocalizedText(fr: 'CNY 2 000–4 000/mois', en: 'CNY 2,000–4,000/month'),
      languageSection: LocalizedText(
          fr: 'Programmes en anglais : IELTS 6.0–6.5 selon l\'université. Programmes en chinois : HSK 4 à 5. KPB t\'oriente vers le bon format selon ton niveau.',
          en: 'English-taught programs: IELTS 6.0–6.5 depending on the university. Chinese-taught: HSK 4 to 5. KPB guides you to the right format for your level.'),
      scholarshipsSection: LocalizedText(
          fr: 'Bourse du gouvernement chinois (CSC), bourses provinciales et bourses universitaires — KPB t\'aide à monter le dossier de bourse en parallèle de l\'admission.',
          en: 'Chinese Government Scholarship (CSC), provincial and university scholarships — KPB helps you build the scholarship file alongside the admission.'),
      visaOverview: LocalizedText(
          fr: 'Visa X1 (études > 6 mois) avec lettre d\'admission (JW202) et formulaire JW201, puis permis de séjour à l\'arrivée — procédure accompagnée par KPB.',
          en: 'X1 visa (studies > 6 months) with admission letter (JW202) and JW201 form, then residence permit on arrival — KPB-guided process.'),
      whatsAppPrefill: LocalizedText(
          fr: 'Bonjour KPB, je veux étudier en Chine (bourse CSC) et j\'aimerais être accompagné·e.',
          en: 'Hello KPB, I want to study in China (CSC scholarship) and would like support.'),
      admissionDifficulty: LocalizedText(fr: 'Modérée', en: 'Moderate'),
      popularFieldIds: ['d05', 'd01', 'd04', 'd09'],
    ),
    CountryModel(
      id: 'france',
      name: LocalizedText(fr: 'France', en: 'France'),
      whyStudy: LocalizedText(
          fr: 'Grande qualité académique, coûts réduits dans les universités publiques, accompagnement KPB de bout en bout.',
          en: 'High academic quality, low costs in public universities, end-to-end KPB support.'),
      tuitionRange:
          LocalizedText(fr: 'EUR 170–10 000/an', en: 'EUR 170–10 000/year'),
      livingCostRange:
          LocalizedText(fr: 'EUR 700–1 200/mois', en: 'EUR 700–1 200/month'),
      visaOverview: LocalizedText(
          fr: 'Visa long séjour étudiant — procédure accompagnée par KPB, pays par pays.',
          en: 'Long-stay student visa — KPB-guided process, country by country.'),
      admissionDifficulty: LocalizedText(fr: 'Modérée', en: 'Moderate'),
      popularFieldIds: ['d02', 'd03', 'd07', 'd06'],
    ),
    CountryModel(
      id: 'uk',
      name: LocalizedText(fr: 'Royaume-Uni', en: 'United Kingdom'),
      whyStudy: LocalizedText(
          fr: 'Universités classées mondialement, programmes courts et intensifs, carrières finance et tech.',
          en: 'World-ranked universities, short intensive programs, finance and tech careers.'),
      tuitionRange: LocalizedText(fr: 'GBP 12k–28k/an', en: 'GBP 12k–28k/year'),
      livingCostRange:
          LocalizedText(fr: 'GBP 900–1 800/mois', en: 'GBP 900–1 800/month'),
      visaOverview: LocalizedText(
          fr: 'Visa Student Tier 4 avec CAS de l\'université.',
          en: 'Student Tier 4 visa with university CAS.'),
      admissionDifficulty: LocalizedText(fr: 'Élevée', en: 'High'),
      popularFieldIds: ['d01', 'd03', 'd07'],
    ),
    CountryModel(
      id: 'germany',
      name: LocalizedText(fr: 'Allemagne', en: 'Germany'),
      whyStudy: LocalizedText(
          fr: 'Universités publiques quasi-gratuites, excellence technique, forte demande en ingénieurs.',
          en: 'Nearly free public universities, technical excellence, high demand for engineers.'),
      tuitionRange: LocalizedText(
          fr: 'EUR 0–3 000/an (frais de semestre)',
          en: 'EUR 0–3 000/year (semester fees)'),
      livingCostRange:
          LocalizedText(fr: 'EUR 700–1 100/mois', en: 'EUR 700–1 100/month'),
      visaOverview: LocalizedText(
          fr: 'Visa national D avec lettre d\'admission et preuves financières.',
          en: 'National D visa with admission letter and financial proof.'),
      admissionDifficulty: LocalizedText(fr: 'Modérée', en: 'Moderate'),
      popularFieldIds: ['d05', 'd01', 'd08'],
    ),
    CountryModel(
      id: 'morocco',
      name: LocalizedText(fr: 'Maroc', en: 'Morocco'),
      whyStudy: LocalizedText(
          fr: 'Proximité géographique, coûts abordables, nombreux partenariats avec écoles françaises.',
          en: 'Geographic proximity, affordable costs, many partnerships with French schools.'),
      tuitionRange: LocalizedText(fr: 'MAD 15k–60k/an', en: 'MAD 15k–60k/year'),
      livingCostRange: LocalizedText(
          fr: 'MAD 3 000–6 000/mois', en: 'MAD 3 000–6 000/month'),
      visaOverview: LocalizedText(
          fr: 'Pas de visa requis pour ressortissants CEDEAO. Titre de séjour ensuite.',
          en: 'No visa required for ECOWAS nationals. Residence permit afterward.'),
      admissionDifficulty:
          LocalizedText(fr: 'Facile à modérée', en: 'Easy to moderate'),
      popularFieldIds: ['d02', 'd04', 'd07'],
    ),
    CountryModel(
      id: 'turkey',
      name: LocalizedText(fr: 'Turquie', en: 'Turkey'),
      whyStudy: LocalizedText(
          fr: 'Coûts très abordables, bourse gouvernementale complète (Türkiye Burslari), médecine en anglais.',
          en: 'Very affordable costs, full government scholarship (Türkiye Burslari), medicine in English.'),
      tuitionRange:
          LocalizedText(fr: 'USD 500–6 000/an', en: 'USD 500–6 000/year'),
      livingCostRange:
          LocalizedText(fr: 'USD 400–800/mois', en: 'USD 400–800/month'),
      visaOverview: LocalizedText(
          fr: 'Visa étudiant avec lettre d\'admission et acte de naissance.',
          en: 'Student visa with admission letter and birth certificate.'),
      admissionDifficulty: LocalizedText(fr: 'Facile', en: 'Easy'),
      popularFieldIds: ['d04', 'd02', 'd05'],
    ),
    CountryModel(
      id: 'spain',
      name: LocalizedText(fr: 'Espagne', en: 'Spain'),
      whyStudy: LocalizedText(
          fr: 'Qualité de vie élevée, coûts inférieurs à la France, programmes en anglais en augmentation.',
          en: 'High quality of life, lower costs than France, growing English-language programs.'),
      tuitionRange:
          LocalizedText(fr: 'EUR 1 000–8 000/an', en: 'EUR 1 000–8 000/year'),
      livingCostRange:
          LocalizedText(fr: 'EUR 700–1 100/mois', en: 'EUR 700–1 100/month'),
      visaOverview: LocalizedText(
          fr: 'Visa étudiant Schengen avec inscription et ressources suffisantes.',
          en: 'Schengen student visa with enrollment and sufficient funds.'),
      admissionDifficulty: LocalizedText(fr: 'Modérée', en: 'Moderate'),
      popularFieldIds: ['d06', 'd02', 'd11'],
    ),
    CountryModel(
      id: 'uae',
      name:
          LocalizedText(fr: 'Émirats Arabes Unis', en: 'United Arab Emirates'),
      whyStudy: LocalizedText(
          fr: 'Hub international des affaires, programmes 100% anglais, connexions Afrique–Asie–Europe.',
          en: 'International business hub, 100% English programs, Africa–Asia–Europe connections.'),
      tuitionRange: LocalizedText(fr: 'AED 30k–80k/an', en: 'AED 30k–80k/year'),
      livingCostRange: LocalizedText(
          fr: 'AED 3 000–7 000/mois', en: 'AED 3 000–7 000/month'),
      visaOverview: LocalizedText(
          fr: 'Visa étudiant sponsorisé par l\'université.',
          en: 'Student visa sponsored by the university.'),
      admissionDifficulty: LocalizedText(fr: 'Facile', en: 'Easy'),
      popularFieldIds: ['d02', 'd03', 'd12'],
    ),
  ];

