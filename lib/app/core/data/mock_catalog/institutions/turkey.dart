// AUTO-GENERATED — KPB Education catalog seed data.
// ignore_for_file: lines_longer_than_80_chars
import '../../../models/app_models.dart';

const kInstitutionsTurkey = <InstitutionModel>[
  InstitutionModel(
    id: 'bau',
    name: LocalizedText(
        fr: 'Bahçeşehir University (BAU) Istanbul',
        en: 'Bahçeşehir University (BAU) Istanbul'),
    countryId: 'turkey',
    location: LocalizedText(fr: 'Istanbul', en: 'Istanbul'),
    overview: LocalizedText(
        fr: 'Bahçeşehir University (BAU) Istanbul — Turquie',
        en: 'Bahçeşehir University (BAU) Istanbul — Turquie'),
    studyLevels: ['Bac+3'],
    tuitionLabel: LocalizedText(fr: '8500 USD/an', en: '8500 USD/an'),
    languageRequirements: LocalizedText(fr: 'Anglais', en: 'English'),
    intakePeriods: ['Undergraduate: Fall intake only'],
    programIds: [
      'prog_058',
      'prog_059',
      'prog_060',
      'prog_061',
      'prog_062',
      'prog_063',
      'prog_064',
      'prog_065',
      'prog_066'
    ],
    isPartner: true,
  ),
  InstitutionModel(
    id: 'istanbul_u',
    name:
        LocalizedText(fr: 'Université d\'Istanbul', en: 'Istanbul University'),
    countryId: 'turkey',
    location: LocalizedText(fr: 'Istanbul', en: 'Istanbul'),
    overview: LocalizedText(
        fr: 'Plus ancienne université de Turquie. Droit, médecine et littérature. Bourse Türkiye Burslari couvre tout.',
        en: 'Oldest university in Turkey. Law, medicine and literature. Türkiye Burslari scholarship covers everything.'),
    studyLevels: ['Bac+3', 'Bac+5', 'Doctorat'],
    tuitionLabel: LocalizedText(
        fr: 'USD 500–3 000/an (ou bourse Türkiye Burslari)',
        en: 'USD 500–3 000/yr (or Türkiye Burslari)'),
    languageRequirements: LocalizedText(
        fr: 'Turc (après année préparatoire) / Anglais pour certains masters',
        en: 'Turkish (after prep year) / English for select masters'),
    intakePeriods: ['Septembre'],
    programIds: ['prog_tr001'],
    isPartner: false,
  ),
  InstitutionModel(
    id: 'bogazici',
    name: LocalizedText(fr: 'Université Boğaziçi', en: 'Boğaziçi University'),
    countryId: 'turkey',
    location: LocalizedText(fr: 'Istanbul', en: 'Istanbul'),
    overview: LocalizedText(
        fr: '#1 en Turquie selon de nombreux classements. Enseignement 100% en anglais. Sciences, ingénierie et économie.',
        en: '#1 in Turkey by many rankings. 100% English-medium instruction. Sciences, engineering and economics.'),
    studyLevels: ['Bac+3', 'Bac+5', 'Doctorat'],
    tuitionLabel:
        LocalizedText(fr: 'USD 1 000–4 000/an', en: 'USD 1 000–4 000/yr'),
    languageRequirements: LocalizedText(
        fr: 'Anglais (TOEFL 80+ / IELTS 6.5)',
        en: 'English (TOEFL 80+ / IELTS 6.5)'),
    intakePeriods: ['Septembre', 'Février'],
    programIds: ['prog_tr002'],
    isPartner: false,
  ),
  InstitutionModel(
    id: 'metu',
    name: LocalizedText(
        fr: 'Middle East Technical University (METU/ODTÜ)',
        en: 'Middle East Technical University (METU)'),
    countryId: 'turkey',
    location: LocalizedText(fr: 'Ankara', en: 'Ankara'),
    overview: LocalizedText(
        fr: 'Top école d\'ingénieurs de Turquie. 100% anglais. Très forte en génie civil, aérospatiale et TIC.',
        en: 'Top engineering school in Turkey. 100% English. Very strong in civil, aerospace and ICT engineering.'),
    studyLevels: ['Bac+3', 'Bac+5', 'Doctorat'],
    tuitionLabel: LocalizedText(fr: 'USD 800–3 000/an', en: 'USD 800–3 000/yr'),
    languageRequirements: LocalizedText(
        fr: 'Anglais (TOEFL 79 / IELTS 6.5)',
        en: 'English (TOEFL 79 / IELTS 6.5)'),
    intakePeriods: ['Septembre'],
    programIds: ['prog_tr003'],
    isPartner: false,
  ),
  // ── CHINE (supplémentaires) ───────────────────────────────────────────────
  InstitutionModel(
    id: 'bilkent',
    name: LocalizedText(fr: 'Bilkent University', en: 'Bilkent University'),
    countryId: 'turkey',
    location: LocalizedText(fr: 'Ankara', en: 'Ankara'),
    overview: LocalizedText(
        fr: 'Université privée de très haut niveau, 100% en anglais. Incubateur de talents en tech et sciences.',
        en: 'Top-tier private university, 100% in English. Talent incubator for tech and sciences.'),
    studyLevels: ['Bac+3', 'Bac+5', 'Doctorat'],
    tuitionLabel: LocalizedText(
        fr: 'USD 8 500/an (bourses au mérite)',
        en: 'USD 8 500/yr (merit scholarships)'),
    languageRequirements: LocalizedText(
        fr: 'Anglais (TOEFL / IELTS)', en: 'English (TOEFL / IELTS)'),
    intakePeriods: ['Septembre'],
    programIds: ['prog_tr_priv001'],
    isPartner: false,
  ),
  InstitutionModel(
    id: 'sabanci',
    name: LocalizedText(fr: 'Sabancı University', en: 'Sabancı University'),
    countryId: 'turkey',
    location: LocalizedText(fr: 'Istanbul', en: 'Istanbul'),
    overview: LocalizedText(
        fr: 'Système innovant sans départements fixes la 1ère année. Top recherche. Bourses généreuses pour étudiants internationaux.',
        en: 'Innovative system with no fixed departments in 1st year. Top research. Generous scholarships for intl students.'),
    studyLevels: ['Bac+3', 'Bac+5', 'Doctorat'],
    tuitionLabel: LocalizedText(fr: 'USD 19 500/an', en: 'USD 19 500/yr'),
    languageRequirements: LocalizedText(fr: 'Anglais', en: 'English'),
    intakePeriods: ['Septembre', 'Février'],
    programIds: ['prog_tr_priv002'],
    isPartner: false,
  ),
  InstitutionModel(
    id: 'koc',
    name: LocalizedText(fr: 'Koç University', en: 'Koç University'),
    countryId: 'turkey',
    location: LocalizedText(fr: 'Istanbul', en: 'Istanbul'),
    overview: LocalizedText(
        fr: 'L\'une des universités privées les plus prestigieuses et sélectives de Turquie. Réseau Alumni très puissant.',
        en: 'One of the most prestigious and selective private universities in Turkey. Very powerful Alumni network.'),
    studyLevels: ['Bac+3', 'Bac+5', 'Doctorat'],
    tuitionLabel: LocalizedText(fr: 'USD 21 000/an', en: 'USD 21 000/yr'),
    languageRequirements: LocalizedText(fr: 'Anglais', en: 'English'),
    intakePeriods: ['Septembre'],
    programIds: ['prog_tr_priv003'],
    isPartner: false,
  ),
  // ── USA (Privées supplémentaires) ───────────────────────────────────────────
  InstitutionModel(
    id: 'bahcesehir',
    name: LocalizedText(
        fr: 'Bahçeşehir University (BAU)', en: 'Bahçeşehir University (BAU)'),
    countryId: 'turkey',
    location:
        LocalizedText(fr: 'Istanbul (Besiktas)', en: 'Istanbul (Besiktas)'),
    overview: LocalizedText(
        fr: '"Cœur d\'Istanbul". Très internationale, campuses mondiaux. N°1 en design et média en Turquie.',
        en: '"The Heart of Istanbul". Highly international, global campuses. N°1 in design and media in Turkey.'),
    studyLevels: ['Bac+3', 'Bac+5', 'Doctorat'],
    tuitionLabel:
        LocalizedText(fr: 'USD 5 000–8 000/an', en: 'USD 5 000–8 000/yr'),
    languageRequirements: LocalizedText(
        fr: 'Anglais (TOEFL 79) / Turc', en: 'English (TOEFL 79) / Turkish'),
    intakePeriods: ['Septembre', 'Février'],
    programIds: ['prog_tr_priv_bau'],
    isPartner: true,
  ),
  InstitutionModel(
    id: 'yeditepe',
    name: LocalizedText(fr: 'Yeditepe University', en: 'Yeditepe University'),
    countryId: 'turkey',
    location: LocalizedText(fr: 'Istanbul', en: 'Istanbul'),
    overview: LocalizedText(
        fr: 'L\'une des plus grandes universités privées. Campus vert. Excellence en médecine et dentisterie.',
        en: 'One of the largest private universities. Green campus. Excellence in medicine and dentistry.'),
    studyLevels: ['Bac+3', 'Bac+5', 'Doctorat'],
    tuitionLabel: LocalizedText(
        fr: 'USD 4 000–25 000/an (Médecine)',
        en: 'USD 4 000–25 000/yr (Medicine)'),
    languageRequirements:
        LocalizedText(fr: 'Anglais / Turc', en: 'English / Turkish'),
    intakePeriods: ['Septembre'],
    programIds: ['prog_tr_priv_yeditepe'],
    isPartner: false,
  ),
  InstitutionModel(
    id: 'osyegin',
    name: LocalizedText(fr: 'Özyeğin University', en: 'Ozyegin University'),
    countryId: 'turkey',
    location: LocalizedText(fr: 'Istanbul', en: 'Istanbul'),
    overview: LocalizedText(
        fr: 'Top Entrepreneurial University. Campus moderne. 100% Anglais. Gastronomie, Aviation et Business.',
        en: 'Top Entrepreneurial University. Modern campus. 100% English. Gastronomy, Aviation and Business.'),
    studyLevels: ['Bac+3', 'Bac+5'],
    tuitionLabel:
        LocalizedText(fr: 'USD 6 000–12 000/an', en: 'USD 6 000–12 000/yr'),
    languageRequirements:
        LocalizedText(fr: 'Anglais (IELTS 6.5)', en: 'English (IELTS 6.5)'),
    intakePeriods: ['Septembre'],
    programIds: ['prog_tr_priv_ozyegin'],
    isPartner: true,
  ),
  InstitutionModel(
    id: 'koc_uni',
    name: LocalizedText(fr: 'Koç University', en: 'Koç University'),
    countryId: 'turkey',
    location: LocalizedText(fr: 'Istanbul', en: 'Istanbul'),
    overview: LocalizedText(
        fr: 'Université de recherche d\'élite. Partenariats mondiaux. Très sélective. Campus exceptionnel.',
        en: 'Elite research university. Global partnerships. Highly selective. Exceptional campus.'),
    studyLevels: ['Bac+3', 'Bac+5', 'PhD'],
    tuitionLabel:
        LocalizedText(fr: 'USD 19 000–25 000/an', en: 'USD 19 000–25 000/yr'),
    languageRequirements:
        LocalizedText(fr: 'Anglais (TOEFL 80+)', en: 'English (TOEFL 80+)'),
    intakePeriods: ['Septembre'],
    programIds: ['prog_tr_koc'],
    isPartner: false,
  ),
  InstitutionModel(
    id: 'bilkent',
    name: LocalizedText(fr: 'Bilkent University', en: 'Bilkent University'),
    countryId: 'turkey',
    location: LocalizedText(fr: 'Ankara', en: 'Ankara'),
    overview: LocalizedText(
        fr: 'Première université privée de Turquie. Excellence en Ingénierie, Management et Humanités.',
        en: 'Turkey\'s first private university. Excellence in Engineering, Management and Humanities.'),
    studyLevels: ['Bac+3', 'Bac+5', 'PhD'],
    tuitionLabel:
        LocalizedText(fr: 'USD 12 000–15 000/an', en: 'USD 12 000–15 000/yr'),
    languageRequirements:
        LocalizedText(fr: 'Anglais (Bilkent PAE)', en: 'English (Bilkent PAE)'),
    intakePeriods: ['Septembre'],
    programIds: ['prog_tr_bilkent'],
    isPartner: false,
  ),
  InstitutionModel(
    id: 'izu_turkey',
    name: LocalizedText(
        fr: 'Istanbul Sabahattin Zaim University (IZU)',
        en: 'Istanbul Sabahattin Zaim University'),
    countryId: 'turkey',
    location: LocalizedText(fr: 'Istanbul', en: 'Istanbul'),
    overview: LocalizedText(
        fr: 'Université thématique forte en finance islamique et sciences sociales.',
        en: 'Thematic university strong in Islamic finance and social sciences.'),
    studyLevels: ['Bac+3', 'Bac+5'],
    tuitionLabel: LocalizedText(fr: 'USD 3 000/an', en: 'USD 3 000/yr'),
    languageRequirements: LocalizedText(
        fr: 'Anglais / Turc / Arabe', en: 'English / Turkish / Arabic'),
    intakePeriods: ['Septembre'],
    programIds: ['prog_tr_priv_izu'],
    isPartner: true,
  ),
  // Final Batch to 200
];
