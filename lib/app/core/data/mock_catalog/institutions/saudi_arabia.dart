// AUTO-GENERATED — KPB Education catalog seed data.
// ignore_for_file: lines_longer_than_80_chars
import '../../../models/app_models.dart';

const kInstitutionsSaudiArabia = <InstitutionModel>[
  InstitutionModel(
    id: 'kaust',
    name: LocalizedText(
        fr: 'KAUST (King Abdullah University of Science and Technology)',
        en: 'KAUST'),
    countryId: 'saudi_arabia',
    location: LocalizedText(fr: 'Thuwal (Jeddah)', en: 'Thuwal (Jeddah)'),
    overview: LocalizedText(
        fr: 'Top 100 mondial en recherche. 100% internationaux. Bourses complètes (logement + salaire + santé). 100% anglais.',
        en: 'Top 100 globally in research. 100% international. Full scholarships (housing + stipend + health). 100% English.'),
    studyLevels: ['Bac+5', 'Doctorat'],
    tuitionLabel: LocalizedText(
        fr: 'Gratuit + bourse complète', en: 'Free + full scholarship'),
    languageRequirements: LocalizedText(
        fr: 'Anglais (IELTS 6.5 ou TOEFL 79)',
        en: 'English (IELTS 6.5 or TOEFL 79)'),
    intakePeriods: ['Août'],
    programIds: ['prog_sa001', 'prog_sa002'],
    isPartner: false,
  ),
  InstitutionModel(
    id: 'kfu',
    name: LocalizedText(
        fr: 'King Faisal University (KFU)', en: 'King Faisal University'),
    countryId: 'saudi_arabia',
    location: LocalizedText(fr: 'Al-Ahsa', en: 'Al-Ahsa'),
    overview: LocalizedText(
        fr: 'Université publique saoudienne avec bourses pour étudiants de pays OCI (Organisation Coopération Islamique). Agriculture, médecine, ingénierie.',
        en: 'Saudi public university with scholarships for OIC country students. Agriculture, medicine, engineering.'),
    studyLevels: ['Bac+3', 'Bac+5', 'Doctorat'],
    tuitionLabel: LocalizedText(
        fr: 'Gratuit pour boursiers OCI',
        en: 'Free for OIC scholarship holders'),
    languageRequirements: LocalizedText(
        fr: 'Arabe / Anglais selon programme',
        en: 'Arabic / English depending on program'),
    intakePeriods: ['Septembre'],
    programIds: ['prog_sa003'],
    isPartner: false,
  ),
  // ── MAROC (supplémentaires) ────────────────────────────────────────────────
];
