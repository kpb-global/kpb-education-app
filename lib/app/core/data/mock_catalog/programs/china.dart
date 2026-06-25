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
  // ── Zhejiang Normal University (Jinhua) ─────────────────────────────────
  ProgramModel(
    id: 'prog_cn_znu1',
    institutionId: 'znu_jinhua',
    countryId: 'china',
    fieldId: 'd09',
    name: LocalizedText(
        fr: 'Master en Éducation internationale',
        en: 'Master in International Education'),
    level: LocalizedText(fr: 'Bac+5', en: 'Master'),
    duration: LocalizedText(fr: '2–3 ans', en: '2–3 years'),
    tuition: LocalizedText(
        fr: 'CNY 18 000–24 000/an (souvent bourse CSC)',
        en: 'CNY 18,000–24,000/yr (often CSC scholarship)'),
    language: LocalizedText(
        fr: 'Anglais (IELTS 6.0)', en: 'English (IELTS 6.0)'),
    requirements: [_contactKpb],
  ),
  ProgramModel(
    id: 'prog_cn_znu2',
    institutionId: 'znu_jinhua',
    countryId: 'china',
    fieldId: 'd02',
    name: LocalizedText(
        fr: 'Licence en Commerce international',
        en: 'Bachelor in International Business'),
    level: LocalizedText(fr: 'Bac+4', en: 'Bachelor'),
    duration: LocalizedText(fr: '4 ans', en: '4 years'),
    tuition: LocalizedText(
        fr: 'CNY 18 000–24 000/an (souvent bourse CSC)',
        en: 'CNY 18,000–24,000/yr (often CSC scholarship)'),
    language: LocalizedText(
        fr: 'Anglais (IELTS 6.0) ou Chinois (HSK 4)',
        en: 'English (IELTS 6.0) or Chinese (HSK 4)'),
    requirements: [_contactKpb],
  ),
  // ── Beijing Institute of Technology ─────────────────────────────────────
  ProgramModel(
    id: 'prog_cn_bit',
    institutionId: 'bit',
    countryId: 'china',
    fieldId: 'd01',
    name: LocalizedText(
        fr: 'Master en Informatique & IA',
        en: 'Master in Computer Science & AI'),
    level: LocalizedText(fr: 'Bac+5', en: 'Master'),
    duration: LocalizedText(fr: '2–3 ans', en: '2–3 years'),
    tuition: LocalizedText(
        fr: 'CNY 20 000–30 000/an', en: 'CNY 20,000–30,000/yr'),
    language: LocalizedText(
        fr: 'Anglais (IELTS 6.0–6.5)', en: 'English (IELTS 6.0–6.5)'),
    requirements: [_contactKpb],
  ),
  // ── Zhejiang University (Hangzhou) ──────────────────────────────────────
  ProgramModel(
    id: 'prog_cn_zju',
    institutionId: 'zju',
    countryId: 'china',
    fieldId: 'd05',
    name: LocalizedText(
        fr: 'Master en Génie & Sciences appliquées',
        en: 'Master in Engineering & Applied Sciences'),
    level: LocalizedText(fr: 'Bac+5', en: 'Master'),
    duration: LocalizedText(fr: '2–3 ans', en: '2–3 years'),
    tuition: LocalizedText(
        fr: 'CNY 26 000–40 000/an', en: 'CNY 26,000–40,000/yr'),
    language: LocalizedText(
        fr: 'Anglais (IELTS 6.5)', en: 'English (IELTS 6.5)'),
    requirements: [_contactKpb],
  ),
  // ── Jiangsu University — MBBS (médecine en anglais) ─────────────────────
  ProgramModel(
    id: 'prog_cn_jsu',
    institutionId: 'jiangsu',
    countryId: 'china',
    fieldId: 'd04',
    name: LocalizedText(
        fr: 'MBBS — Médecine (enseignée en anglais)',
        en: 'MBBS — Medicine (English-taught)'),
    level: LocalizedText(fr: 'Bac+5', en: 'Bachelor'),
    duration: LocalizedText(fr: '5–6 ans', en: '5–6 years'),
    tuition: LocalizedText(
        fr: 'CNY 18 000–28 000/an', en: 'CNY 18,000–28,000/yr'),
    language: LocalizedText(
        fr: 'Anglais (IELTS 6.0)', en: 'English (IELTS 6.0)'),
    requirements: [_contactKpb],
  ),
  // ── Wuhan University ────────────────────────────────────────────────────
  ProgramModel(
    id: 'prog_cn_whu',
    institutionId: 'whu',
    countryId: 'china',
    fieldId: 'd03',
    name: LocalizedText(
        fr: 'Master en Finance & Économie internationale',
        en: 'Master in International Finance & Economics'),
    level: LocalizedText(fr: 'Bac+5', en: 'Master'),
    duration: LocalizedText(fr: '2 ans', en: '2 years'),
    tuition: LocalizedText(
        fr: 'CNY 20 000–35 000/an', en: 'CNY 20,000–35,000/yr'),
    language: LocalizedText(
        fr: 'Anglais (IELTS 6.0–6.5)', en: 'English (IELTS 6.0–6.5)'),
    requirements: [_contactKpb],
  ),
  // ── Hohai University (Nanjing) ──────────────────────────────────────────
  ProgramModel(
    id: 'prog_cn_hohai',
    institutionId: 'hohai',
    countryId: 'china',
    fieldId: 'd05',
    name: LocalizedText(
        fr: 'Licence en Génie civil & hydraulique',
        en: 'Bachelor in Civil & Hydraulic Engineering'),
    level: LocalizedText(fr: 'Bac+4', en: 'Bachelor'),
    duration: LocalizedText(fr: '4 ans', en: '4 years'),
    tuition: LocalizedText(
        fr: 'CNY 18 000–26 000/an', en: 'CNY 18,000–26,000/yr'),
    language: LocalizedText(
        fr: 'Anglais (IELTS 6.0)', en: 'English (IELTS 6.0)'),
    requirements: [_contactKpb],
  ),
  // ── Accessible / scholarship-friendly universities ──────────────────────
  ProgramModel(
    id: 'prog_cn_hebut',
    institutionId: 'hebut',
    countryId: 'china',
    fieldId: 'd05',
    name: LocalizedText(
        fr: 'Master en Génie électrique & Communication',
        en: 'Master in Electrical & Communication Engineering'),
    level: LocalizedText(fr: 'Bac+5', en: 'Master'),
    duration: LocalizedText(fr: '2–3 ans', en: '2–3 years'),
    tuition: LocalizedText(
        fr: 'CNY 6 000–18 000/an (souvent bourse CSC)',
        en: 'CNY 6,000–18,000/yr (often CSC scholarship)'),
    language: LocalizedText(
        fr: 'Anglais (IELTS 6.0 / TOEFL 85)',
        en: 'English (IELTS 6.0 / TOEFL 85)'),
    requirements: [_contactKpb],
  ),
  ProgramModel(
    id: 'prog_cn_ctgu',
    institutionId: 'ctgu',
    countryId: 'china',
    fieldId: 'd08',
    name: LocalizedText(
        fr: 'Master en Génie hydraulique & Énergie',
        en: 'Master in Hydraulic & Power Engineering'),
    level: LocalizedText(fr: 'Bac+5', en: 'Master'),
    duration: LocalizedText(fr: '2–3 ans', en: '2–3 years'),
    tuition: LocalizedText(
        fr: 'CNY 15 000–25 000/an (bourse/réduction possible)',
        en: 'CNY 15,000–25,000/yr (scholarship/reduction possible)'),
    language: LocalizedText(
        fr: 'Anglais (IELTS 6.0)', en: 'English (IELTS 6.0)'),
    requirements: [_contactKpb],
  ),
  ProgramModel(
    id: 'prog_cn_yzu',
    institutionId: 'yzu',
    countryId: 'china',
    fieldId: 'd10',
    name: LocalizedText(
        fr: 'Master en Sciences agronomiques & vétérinaires',
        en: 'Master in Agronomy & Veterinary Sciences'),
    level: LocalizedText(fr: 'Bac+5', en: 'Master'),
    duration: LocalizedText(fr: '2–3 ans', en: '2–3 years'),
    tuition: LocalizedText(
        fr: 'CNY 16 000–30 000/an (souvent bourse)',
        en: 'CNY 16,000–30,000/yr (often scholarship)'),
    language: LocalizedText(
        fr: 'Anglais (IELTS 6.0 / TOEFL 80)',
        en: 'English (IELTS 6.0 / TOEFL 80)'),
    requirements: [_contactKpb],
  ),
  ProgramModel(
    id: 'prog_cn_njust',
    institutionId: 'njust',
    countryId: 'china',
    fieldId: 'd05',
    name: LocalizedText(
        fr: 'Master en Ingénierie mécanique & matériaux',
        en: 'Master in Mechanical Engineering & Materials'),
    level: LocalizedText(fr: 'Bac+5', en: 'Master'),
    duration: LocalizedText(fr: '2–3 ans', en: '2–3 years'),
    tuition: LocalizedText(
        fr: 'CNY 20 000–30 000/an (souvent bourse CSC)',
        en: 'CNY 20,000–30,000/yr (often CSC scholarship)'),
    language: LocalizedText(
        fr: 'Anglais (IELTS 6.0 / TOEFL 80)',
        en: 'English (IELTS 6.0 / TOEFL 80)'),
    requirements: [_contactKpb],
  ),
  ProgramModel(
    id: 'prog_cn_sdu',
    institutionId: 'sdu',
    countryId: 'china',
    fieldId: 'd02',
    name: LocalizedText(
        fr: 'Master en Administration des affaires (MBA)',
        en: 'Master in Business Administration (MBA)'),
    level: LocalizedText(fr: 'Bac+5', en: 'Master'),
    duration: LocalizedText(fr: '2–3 ans', en: '2–3 years'),
    tuition: LocalizedText(
        fr: 'CNY 20 000–35 000/an (ou bourse SDU/CSC)',
        en: 'CNY 20,000–35,000/yr (or SDU/CSC scholarship)'),
    language: LocalizedText(
        fr: 'Anglais (IELTS 6.0 / TOEFL 80)',
        en: 'English (IELTS 6.0 / TOEFL 80)'),
    requirements: [_contactKpb],
  ),
  ProgramModel(
    id: 'prog_cn_nau',
    institutionId: 'nau',
    countryId: 'china',
    fieldId: 'd10',
    name: LocalizedText(
        fr: 'Master en Agronomie & Sécurité alimentaire',
        en: 'Master in Agronomy & Food Security'),
    level: LocalizedText(fr: 'Bac+5', en: 'Master'),
    duration: LocalizedText(fr: '2–3 ans', en: '2–3 years'),
    tuition: LocalizedText(
        fr: 'CNY 18 000–28 000/an (souvent bourse CSC)',
        en: 'CNY 18,000–28,000/yr (often CSC scholarship)'),
    language: LocalizedText(
        fr: 'Anglais (IELTS 6.0 / TOEFL 80)',
        en: 'English (IELTS 6.0 / TOEFL 80)'),
    requirements: [_contactKpb],
  ),
];
