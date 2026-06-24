// AUTO-GENERATED — KPB Education catalog seed data.
// Chinese programs. IDs match the programIds referenced by
// institutions/china.dart (Tsinghua, Fudan, BNU).
// ignore_for_file: lines_longer_than_80_chars
import '../../../models/app_models.dart';

const _contactKpb = LocalizedText(
  fr: 'Conditions spécifiques au programme — contacte KPB pour les critères d\'admission et les bourses CSC/HSK.',
  en: 'Program-specific requirements — contact KPB for admission criteria and CSC/HSK scholarships.',
);

const kProgramsChina = <ProgramModel>[
  // ── Tsinghua University (Pékin) ─────────────────────────────────────────
  ProgramModel(
    id: 'prog_cn001',
    institutionId: 'tsinghua',
    countryId: 'china',
    fieldId: 'd05',
    name: LocalizedText(
        fr: 'Bachelor of Engineering — Génie mécanique',
        en: 'Bachelor of Engineering — Mechanical Engineering'),
    level: LocalizedText(fr: 'Bac+4', en: 'Bachelor'),
    duration: LocalizedText(fr: '4 ans', en: '4 years'),
    tuition: LocalizedText(
        fr: 'CNY 26 000–45 000/an (ou bourse CSC)',
        en: 'CNY 26,000–45,000/yr (or CSC scholarship)'),
    language: LocalizedText(
        fr: 'Anglais (IELTS 6.5)', en: 'English (IELTS 6.5)'),
    requirements: [
      LocalizedText(
          fr: 'Baccalauréat scientifique solide (maths, physique).',
          en: 'Strong science baccalaureate (math, physics).'),
      _contactKpb,
    ],
  ),
  ProgramModel(
    id: 'prog_cn002',
    institutionId: 'tsinghua',
    countryId: 'china',
    fieldId: 'd01',
    name: LocalizedText(
        fr: 'Master en Informatique & Intelligence Artificielle',
        en: 'Master in Computer Science & AI'),
    level: LocalizedText(fr: 'Bac+5', en: 'Master'),
    duration: LocalizedText(fr: '2 ans', en: '2 years'),
    tuition: LocalizedText(
        fr: 'CNY 30 000–45 000/an (ou bourse CSC)',
        en: 'CNY 30,000–45,000/yr (or CSC scholarship)'),
    language: LocalizedText(
        fr: 'Anglais (IELTS 6.5)', en: 'English (IELTS 6.5)'),
    requirements: [_contactKpb],
  ),
  // ── Fudan University (Shanghai) ─────────────────────────────────────────
  ProgramModel(
    id: 'prog_cn003',
    institutionId: 'fudan',
    countryId: 'china',
    fieldId: 'd04',
    name: LocalizedText(
        fr: 'Bachelor of Medicine (MBBS, enseigné en anglais)',
        en: 'Bachelor of Medicine (MBBS, English-taught)'),
    level: LocalizedText(fr: 'Bac+5', en: 'Bachelor'),
    duration: LocalizedText(fr: '5–6 ans', en: '5–6 years'),
    tuition: LocalizedText(
        fr: 'CNY 24 000–38 000/an', en: 'CNY 24,000–38,000/yr'),
    language: LocalizedText(
        fr: 'Anglais (IELTS 6.0+)', en: 'English (IELTS 6.0+)'),
    requirements: [_contactKpb],
  ),
  // ── Beijing Normal University ───────────────────────────────────────────
  ProgramModel(
    id: 'prog_cn004',
    institutionId: 'bnu',
    countryId: 'china',
    fieldId: 'd09',
    name: LocalizedText(
        fr: 'Master en Sciences de l\'éducation',
        en: 'Master in Education Sciences'),
    level: LocalizedText(fr: 'Bac+5', en: 'Master'),
    duration: LocalizedText(fr: '2–3 ans', en: '2–3 years'),
    tuition: LocalizedText(
        fr: 'CNY 20 000–30 000/an (ou bourse HSK)',
        en: 'CNY 20,000–30,000/yr (or HSK scholarship)'),
    language: LocalizedText(
        fr: 'Chinois (HSK 4+) / Anglais selon programme',
        en: 'Chinese (HSK 4+) / English depending on program'),
    requirements: [_contactKpb],
  ),
];
