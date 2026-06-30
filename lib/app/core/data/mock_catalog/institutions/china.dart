// AUTO-GENERATED — KPB Education catalog seed data.
// ignore_for_file: lines_longer_than_80_chars
import '../../../models/app_models.dart';

const kInstitutionsChina = <InstitutionModel>[
  InstitutionModel(
    id: 'tsinghua',
    name: LocalizedText(fr: 'Université Tsinghua', en: 'Tsinghua University'),
    countryId: 'china',
    location: LocalizedText(fr: 'Pékin', en: 'Beijing'),
    overview: LocalizedText(
        fr: '#1 en Chine. Top 20 mondial en ingénierie. Nombreux programmes en anglais pour masters. Bourse chinoise HSK.',
        en: '#1 in China. Top 20 globally in engineering. Many English-taught master programs. Chinese HSK scholarship.'),
    studyLevels: ['Bac+3', 'Bac+5', 'Doctorat'],
    tuitionLabel: LocalizedText(
        fr: 'CNY 26 000–45 000/an (ou bourse CSC)',
        en: 'CNY 26 000–45 000/yr (or CSC scholarship)'),
    languageRequirements: LocalizedText(
        fr: 'Anglais (IELTS 6.5) pour programmes EN / Chinois (HSK 5) pour programmes CN',
        en: 'English (IELTS 6.5) for EN programs / Chinese (HSK 5) for CN programs'),
    intakePeriods: ['Septembre'],
    programIds: ['prog_cn001', 'prog_cn002'],
    isPartner: false,
  ),
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
        LocalizedText(fr: 'CNY 24 000–38 000/an', en: 'CNY 24 000–38 000/yr'),
    languageRequirements: LocalizedText(
        fr: 'Anglais ou Chinois selon programme',
        en: 'English or Chinese depending on program'),
    intakePeriods: ['Septembre', 'Mars'],
    programIds: ['prog_cn003'],
    isPartner: false,
  ),
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
        en: 'CNY 20 000–30 000/yr (or HSK scholarship)'),
    languageRequirements: LocalizedText(
        fr: 'Chinois (HSK 4+) / Anglais pour certains masters',
        en: 'Chinese (HSK 4+) / English for select masters'),
    intakePeriods: ['Septembre'],
    programIds: ['prog_cn004'],
    isPartner: false,
  ),
  // ── MAROC (Privées supplémentaires) ─────────────────────────────────────────
];
