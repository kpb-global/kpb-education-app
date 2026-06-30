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
    name:
        LocalizedText(fr: 'Université du Zhejiang', en: 'Zhejiang University'),
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
  // ── Hebei University of Technology (Tianjin) — très abordable, 211 ────────
  InstitutionModel(
    id: 'hebut',
    name: LocalizedText(
        fr: 'Université de Technologie du Hebei (HEBUT)',
        en: 'Hebei University of Technology (HEBUT)'),
    countryId: 'china',
    location: LocalizedText(fr: 'Tianjin', en: 'Tianjin'),
    overview: LocalizedText(
        fr: 'Université 211 d\'ingénierie aux frais très abordables. Bourses CSC (exonération totale + logement gratuit + allocation) et bourse provinciale du Hebei. Masters et doctorats en anglais accessibles aux étudiants africains.',
        en: '211 engineering university with very affordable fees. CSC scholarships (full waiver + free housing + stipend) and Hebei Provincial scholarship. English-taught masters and PhDs accessible to African students.'),
    studyLevels: ['Bac+5', 'Doctorat'],
    tuitionLabel: LocalizedText(
        fr: 'CNY 6 000–18 000/an (souvent bourse CSC)',
        en: 'CNY 6,000–18,000/yr (often CSC scholarship)'),
    languageRequirements: LocalizedText(
        fr: 'Anglais (IELTS 6.0 / TOEFL 85)',
        en: 'English (IELTS 6.0 / TOEFL 85)'),
    intakePeriods: ['Septembre'],
    programIds: ['prog_cn_hebut'],
    isPartner: false,
  ),
  // ── China Three Gorges University (Yichang) — abordable, accueillante ─────
  InstitutionModel(
    id: 'ctgu',
    name: LocalizedText(
        fr: 'Université des Trois Gorges (CTGU)',
        en: 'China Three Gorges University (CTGU)'),
    countryId: 'china',
    location: LocalizedText(fr: 'Yichang, Hubei', en: 'Yichang, Hubei'),
    overview: LocalizedText(
        fr: 'Université abordable et accueillante avec plus de 1 200 étudiants internationaux. Bourses CSC et provinciales du Hubei, réductions de frais fréquentes (jusqu\'à 50%) pour les étudiants africains. Génie, médecine et informatique en anglais.',
        en: 'Affordable and welcoming university with 1,200+ international students. CSC and Hubei Provincial scholarships, frequent tuition reductions (up to 50%) for African students. English-taught engineering, medicine and computing.'),
    studyLevels: ['Bac+4', 'Bac+5', 'Doctorat'],
    tuitionLabel: LocalizedText(
        fr: 'CNY 15 000–25 000/an (bourse/réduction possible)',
        en: 'CNY 15,000–25,000/yr (scholarship/reduction possible)'),
    languageRequirements:
        LocalizedText(fr: 'Anglais (IELTS 6.0)', en: 'English (IELTS 6.0)'),
    intakePeriods: ['Septembre'],
    programIds: ['prog_cn_ctgu'],
    isPartner: false,
  ),
  // ── Yangzhou University (Jiangsu) — bourse maison généreuse ───────────────
  InstitutionModel(
    id: 'yzu',
    name: LocalizedText(
        fr: 'Université de Yangzhou (YZU)', en: 'Yangzhou University (YZU)'),
    countryId: 'china',
    location: LocalizedText(fr: 'Yangzhou, Jiangsu', en: 'Yangzhou, Jiangsu'),
    overview: LocalizedText(
        fr: 'Grande université publique offrant une bourse maison généreuse (exonération frais + logement + allocation mensuelle) en plus du CSC. Programmes en anglais et frais raisonnables : option très accessible, surtout en master.',
        en: 'Large public university offering a generous in-house scholarship (tuition + accommodation waiver + monthly allowance) on top of CSC. English-taught programs and reasonable fees: a very accessible option, especially at master level.'),
    studyLevels: ['Bac+4', 'Bac+5', 'Doctorat'],
    tuitionLabel: LocalizedText(
        fr: 'CNY 16 000–30 000/an (souvent bourse)',
        en: 'CNY 16,000–30,000/yr (often scholarship)'),
    languageRequirements: LocalizedText(
        fr: 'Anglais (IELTS 6.0 / TOEFL 80)',
        en: 'English (IELTS 6.0 / TOEFL 80)'),
    intakePeriods: ['Septembre'],
    programIds: ['prog_cn_yzu'],
    isPartner: false,
  ),
  // ── Nanjing University of Science & Technology (NJUST) — CSC direct, 211 ──
  InstitutionModel(
    id: 'njust',
    name: LocalizedText(
        fr: 'Université des Sciences et Technologies de Nankin (NJUST)',
        en: 'Nanjing University of Science & Technology (NJUST)'),
    countryId: 'china',
    location: LocalizedText(fr: 'Nankin, Jiangsu', en: 'Nanjing, Jiangsu'),
    overview: LocalizedText(
        fr: 'Université 211 réputée en ingénierie et technologies. Admission directe à la bourse CSC type B (frais exonérés + allocation mensuelle) pour masters et doctorats enseignés en anglais. Procédure simplifiée appréciée des candidats africains.',
        en: 'Renowned 211 university in engineering and technology. Direct admission to CSC Type-B scholarship (tuition exempt + monthly allowance) for English-taught masters and PhDs. Streamlined process popular with African applicants.'),
    studyLevels: ['Bac+5', 'Doctorat'],
    tuitionLabel: LocalizedText(
        fr: 'CNY 20 000–30 000/an (souvent bourse CSC)',
        en: 'CNY 20,000–30,000/yr (often CSC scholarship)'),
    languageRequirements: LocalizedText(
        fr: 'Anglais (IELTS 6.0 / TOEFL 80)',
        en: 'English (IELTS 6.0 / TOEFL 80)'),
    intakePeriods: ['Septembre'],
    programIds: ['prog_cn_njust'],
    isPartner: false,
  ),
  // ── Shandong University (Jinan) — grande bourse internationale ───────────
  InstitutionModel(
    id: 'sdu',
    name: LocalizedText(
        fr: 'Université du Shandong (SDU)', en: 'Shandong University (SDU)'),
    countryId: 'china',
    location: LocalizedText(fr: 'Jinan, Shandong', en: 'Jinan, Shandong'),
    overview: LocalizedText(
        fr: 'Université 985 avec une importante bourse pour étudiants internationaux (totale : frais + logement + allocation + assurance ; partielle : frais). Programmes en anglais (licence, master, doctorat, sciences médicales) avec exemption de test pour les diplômés en anglais.',
        en: '985 university with a large international-student scholarship (full: tuition + accommodation + allowance + insurance; partial: tuition). English-taught programs (bachelor, master, PhD, medical sciences) with test exemption for English-medium graduates.'),
    studyLevels: ['Bac+4', 'Bac+5', 'Doctorat'],
    tuitionLabel: LocalizedText(
        fr: 'CNY 20 000–35 000/an (ou bourse SDU/CSC)',
        en: 'CNY 20,000–35,000/yr (or SDU/CSC scholarship)'),
    languageRequirements: LocalizedText(
        fr: 'Anglais (IELTS 6.0 / TOEFL 80, exemption si cursus en anglais)',
        en: 'English (IELTS 6.0 / TOEFL 80, waived if English-medium studies)'),
    intakePeriods: ['Septembre'],
    programIds: ['prog_cn_sdu'],
    isPartner: false,
  ),
  // ── Nanjing Agricultural University (NAU) — agriculture, CSC direct ───────
  InstitutionModel(
    id: 'nau',
    name: LocalizedText(
        fr: 'Université d\'Agriculture de Nankin (NAU)',
        en: 'Nanjing Agricultural University (NAU)'),
    countryId: 'china',
    location: LocalizedText(fr: 'Nankin, Jiangsu', en: 'Nanjing, Jiangsu'),
    overview: LocalizedText(
        fr: 'Université 211 de premier plan en agriculture et sciences du vivant. Admission directe à la bourse CSC type B (frais exonérés + allocation jusqu\'à CNY 3 500/mois). Programmes en anglais (agriculture, agroalimentaire, environnement) très adaptés aux étudiants africains.',
        en: 'Leading 211 university in agriculture and life sciences. Direct admission to CSC Type-B scholarship (tuition exempt + allowance up to CNY 3,500/mo). English-taught programs (agriculture, food tech, environment) very well-suited to African students.'),
    studyLevels: ['Bac+5', 'Doctorat'],
    tuitionLabel: LocalizedText(
        fr: 'CNY 18 000–28 000/an (souvent bourse CSC)',
        en: 'CNY 18,000–28,000/yr (often CSC scholarship)'),
    languageRequirements: LocalizedText(
        fr: 'Anglais (IELTS 6.0 / TOEFL 80)',
        en: 'English (IELTS 6.0 / TOEFL 80)'),
    intakePeriods: ['Septembre'],
    programIds: ['prog_cn_nau'],
    isPartner: false,
  ),
];
