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

