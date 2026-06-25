// AUTO-GENERATED — KPB Education catalog seed data.
// Chinese universities most popular with African / international students
// (CSC scholarships, English-taught programs). Jinhua / Zhejiang Normal
// University is the established hub for African students.
// ignore_for_file: lines_longer_than_80_chars
import '../../../models/app_models.dart';

const kInstitutionsChina = <InstitutionModel>[
  // ── Zhejiang Normal University (Jinhua) — the African-student hub ─────────
  InstitutionModel(
    id: 'znu_jinhua',
    name: LocalizedText(
        fr: 'Université Normale du Zhejiang (Jinhua)',
        en: 'Zhejiang Normal University (Jinhua)'),
    countryId: 'china',
    location: LocalizedText(fr: 'Jinhua, Zhejiang', en: 'Jinhua, Zhejiang'),
    overview: LocalizedText(
        fr: 'Le pôle des étudiants africains en Chine : abrite l\'Institut des études africaines, accueille des milliers d\'Africains, très nombreuses bourses CSC et programmes en anglais. Accompagnement structuré dès l\'arrivée.',
        en: 'The hub for African students in China: home to the Institute of African Studies, hosts thousands of Africans, many CSC scholarships and English-taught programs. Structured support from arrival.'),
    studyLevels: ['Bac+3', 'Bac+5', 'Doctorat'],
    tuitionLabel: LocalizedText(
        fr: 'CNY 18 000–24 000/an (souvent bourse CSC)',
        en: 'CNY 18,000–24,000/yr (often CSC scholarship)'),
    languageRequirements: LocalizedText(
        fr: 'Anglais (IELTS 6.0) ou Chinois (HSK 4)',
        en: 'English (IELTS 6.0) or Chinese (HSK 4)'),
    intakePeriods: ['Septembre'],
    programIds: ['prog_cn_znu1', 'prog_cn_znu2'],
    isPartner: false,
  ),
  // ── Beijing Institute of Technology ──────────────────────────────────────
  InstitutionModel(
    id: 'bit',
    name: LocalizedText(
        fr: 'Beijing Institute of Technology (BIT)',
        en: 'Beijing Institute of Technology (BIT)'),
    countryId: 'china',
    location: LocalizedText(fr: 'Pékin', en: 'Beijing'),
    overview: LocalizedText(
        fr: 'Université 985 d\'élite en ingénierie et technologie. Très grand effectif international, nombreux masters en anglais et bourses.',
        en: 'Elite 985 university in engineering and technology. Very large international cohort, many English masters and scholarships.'),
    studyLevels: ['Bac+4', 'Bac+5', 'Doctorat'],
    tuitionLabel:
        LocalizedText(fr: 'CNY 20 000–30 000/an', en: 'CNY 20,000–30,000/yr'),
    languageRequirements: LocalizedText(
        fr: 'Anglais (IELTS 6.0–6.5) / Chinois (HSK 4)',
        en: 'English (IELTS 6.0–6.5) / Chinese (HSK 4)'),
    intakePeriods: ['Septembre'],
    programIds: ['prog_cn_bit'],
    isPartner: false,
  ),
  // ── Zhejiang University (Hangzhou) ───────────────────────────────────────
  InstitutionModel(
    id: 'zju',
    name: LocalizedText(fr: 'Université du Zhejiang', en: 'Zhejiang University'),
    countryId: 'china',
    location: LocalizedText(fr: 'Hangzhou, Zhejiang', en: 'Hangzhou, Zhejiang'),
    overview: LocalizedText(
        fr: 'Top 5 chinois, classée dans le top 50 mondial. Énorme cohorte internationale, programmes en anglais dans presque tous les domaines.',
        en: 'Top 5 in China, ranked in the global top 50. Huge international cohort, English programs across almost every field.'),
    studyLevels: ['Bac+4', 'Bac+5', 'Doctorat'],
    tuitionLabel:
        LocalizedText(fr: 'CNY 26 000–40 000/an', en: 'CNY 26,000–40,000/yr'),
    languageRequirements: LocalizedText(
        fr: 'Anglais (IELTS 6.5) / Chinois (HSK 5)',
        en: 'English (IELTS 6.5) / Chinese (HSK 5)'),
    intakePeriods: ['Septembre'],
    programIds: ['prog_cn_zju'],
    isPartner: false,
  ),
  // ── Jiangsu University — very popular for MBBS (medicine in English) ──────
  InstitutionModel(
    id: 'jiangsu',
    name: LocalizedText(fr: 'Université du Jiangsu', en: 'Jiangsu University'),
    countryId: 'china',
    location: LocalizedText(fr: 'Zhenjiang, Jiangsu', en: 'Zhenjiang, Jiangsu'),
    overview: LocalizedText(
        fr: 'L\'une des destinations préférées des étudiants africains pour la médecine (MBBS enseigné en anglais), abordable et très accueillante. Bourses provinciales du Jiangsu.',
        en: 'One of African students\' favourite destinations for medicine (English-taught MBBS), affordable and very welcoming. Jiangsu provincial scholarships.'),
    studyLevels: ['Bac+3', 'Bac+5', 'Doctorat'],
    tuitionLabel:
        LocalizedText(fr: 'CNY 18 000–28 000/an', en: 'CNY 18,000–28,000/yr'),
    languageRequirements:
        LocalizedText(fr: 'Anglais (IELTS 6.0)', en: 'English (IELTS 6.0)'),
    intakePeriods: ['Septembre', 'Mars'],
    programIds: ['prog_cn_jsu'],
    isPartner: false,
  ),
  // ── Wuhan University ─────────────────────────────────────────────────────
  InstitutionModel(
    id: 'whu',
    name: LocalizedText(fr: 'Université de Wuhan', en: 'Wuhan University'),
    countryId: 'china',
    location: LocalizedText(fr: 'Wuhan, Hubei', en: 'Wuhan, Hubei'),
    overview: LocalizedText(
        fr: 'Université 985 réputée, l\'un des plus beaux campus de Chine. Forte communauté internationale, MBBS et masters en anglais, bourses CSC.',
        en: 'Renowned 985 university, one of China\'s most beautiful campuses. Strong international community, English MBBS and masters, CSC scholarships.'),
    studyLevels: ['Bac+4', 'Bac+5', 'Doctorat'],
    tuitionLabel:
        LocalizedText(fr: 'CNY 20 000–35 000/an', en: 'CNY 20,000–35,000/yr'),
    languageRequirements: LocalizedText(
        fr: 'Anglais (IELTS 6.0–6.5) / Chinois (HSK 4)',
        en: 'English (IELTS 6.0–6.5) / Chinese (HSK 4)'),
    intakePeriods: ['Septembre'],
    programIds: ['prog_cn_whu'],
    isPartner: false,
  ),
  // ── Hohai University (Nanjing) ───────────────────────────────────────────
  InstitutionModel(
    id: 'hohai',
    name: LocalizedText(fr: 'Université Hohai', en: 'Hohai University'),
    countryId: 'china',
    location: LocalizedText(fr: 'Nankin, Jiangsu', en: 'Nanjing, Jiangsu'),
    overview: LocalizedText(
        fr: 'Référence mondiale en hydraulique, génie civil et ressources en eau. Très prisée des étudiants africains en ingénierie, nombreuses bourses.',
        en: 'World reference in hydraulics, civil engineering and water resources. Very popular with African engineering students, many scholarships.'),
    studyLevels: ['Bac+4', 'Bac+5', 'Doctorat'],
    tuitionLabel:
        LocalizedText(fr: 'CNY 18 000–26 000/an', en: 'CNY 18,000–26,000/yr'),
    languageRequirements:
        LocalizedText(fr: 'Anglais (IELTS 6.0)', en: 'English (IELTS 6.0)'),
    intakePeriods: ['Septembre'],
    programIds: ['prog_cn_hohai'],
    isPartner: false,
  ),
  // ── Tsinghua University (prestige) ───────────────────────────────────────
  InstitutionModel(
    id: 'tsinghua',
    name: LocalizedText(fr: 'Université Tsinghua', en: 'Tsinghua University'),
    countryId: 'china',
    location: LocalizedText(fr: 'Pékin', en: 'Beijing'),
    overview: LocalizedText(
        fr: '#1 en Chine. Top 20 mondial en ingénierie. Nombreux programmes en anglais pour masters. Bourse chinoise CSC.',
        en: '#1 in China. Top 20 globally in engineering. Many English-taught master programs. Chinese CSC scholarship.'),
    studyLevels: ['Bac+3', 'Bac+5', 'Doctorat'],
    tuitionLabel: LocalizedText(
        fr: 'CNY 26 000–45 000/an (ou bourse CSC)',
        en: 'CNY 26,000–45,000/yr (or CSC scholarship)'),
    languageRequirements: LocalizedText(
        fr: 'Anglais (IELTS 6.5) pour programmes EN / Chinois (HSK 5) pour programmes CN',
        en: 'English (IELTS 6.5) for EN programs / Chinese (HSK 5) for CN programs'),
    intakePeriods: ['Septembre'],
    programIds: ['prog_cn001', 'prog_cn002'],
    isPartner: false,
  ),
  // ── Fudan University (Shanghai, prestige) ────────────────────────────────
  InstitutionModel(
    id: 'fudan',
    name: LocalizedText(fr: 'Université Fudan', en: 'Fudan University'),
    countryId: 'china',
    location: LocalizedText(fr: 'Shanghai', en: 'Shanghai'),
    overview: LocalizedText(
        fr: 'Top 30 en Asie. Médecine, économie et droit de référence en Chine. Fort programme Fudan-Africa.',
        en: 'Top 30 in Asia. Medicine, economics and law of reference in China. Strong Fudan-Africa program.'),
    studyLevels: ['Bac+3', 'Bac+5', 'Doctorat'],
    tuitionLabel:
        LocalizedText(fr: 'CNY 24 000–38 000/an', en: 'CNY 24,000–38,000/yr'),
    languageRequirements: LocalizedText(
        fr: 'Anglais ou Chinois selon programme',
        en: 'English or Chinese depending on program'),
    intakePeriods: ['Septembre', 'Mars'],
    programIds: ['prog_cn003'],
    isPartner: false,
  ),
  // ── Beijing Normal University ────────────────────────────────────────────
  InstitutionModel(
    id: 'bnu',
    name: LocalizedText(
        fr: 'Université Normale de Beijing (BNU)',
        en: 'Beijing Normal University'),
    countryId: 'china',
    location: LocalizedText(fr: 'Pékin', en: 'Beijing'),
    overview: LocalizedText(
        fr: 'Spécialisée en éducation et humanités. Nombreuses bourses pour étudiants africains. Langue d\'enseignement CN ou EN.',
        en: 'Specialized in education and humanities. Many scholarships for African students. Teaching language CN or EN.'),
    studyLevels: ['Bac+3', 'Bac+5', 'Doctorat'],
    tuitionLabel: LocalizedText(
        fr: 'CNY 20 000–30 000/an (ou bourse HSK)',
        en: 'CNY 20,000–30,000/yr (or HSK scholarship)'),
    languageRequirements: LocalizedText(
        fr: 'Chinois (HSK 4+) / Anglais pour certains masters',
        en: 'Chinese (HSK 4+) / English for select masters'),
    intakePeriods: ['Septembre'],
    programIds: ['prog_cn004'],
    isPartner: false,
  ),
];
