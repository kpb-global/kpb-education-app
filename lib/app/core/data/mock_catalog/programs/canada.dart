// AUTO-GENERATED — KPB Education catalog seed data.
// Canadian programs. IDs match the programIds referenced by
// institutions/canada.dart so each Canadian institution surfaces its programs
// (previously these IDs were dangling → empty Canada catalog).
// ignore_for_file: lines_longer_than_80_chars
import '../../../models/app_models.dart';

const _contactKpb = LocalizedText(
  fr: 'Conditions spécifiques au programme — contacte KPB pour les critères d\'admission à jour.',
  en: 'Program-specific requirements — contact KPB for the latest admission criteria.',
);

const kProgramsCanada = <ProgramModel>[
  // ── McGill University (medicine, law, engineering) ──────────────────────
  ProgramModel(
    id: 'prog_c001',
    institutionId: 'mcgill',
    countryId: 'canada',
    fieldId: 'd04',
    name: LocalizedText(
        fr: 'Bachelor of Science — Sciences biomédicales',
        en: 'Bachelor of Science — Biomedical Sciences'),
    level: LocalizedText(fr: 'Bac+3', en: 'Bachelor'),
    duration: LocalizedText(fr: '3–4 ans', en: '3–4 years'),
    tuition: LocalizedText(fr: 'CAD 19k–42k/an', en: 'CAD 19k–42k/yr'),
    language:
        LocalizedText(fr: 'Anglais (IELTS 6.5+)', en: 'English (IELTS 6.5+)'),
    requirements: [
      LocalizedText(
          fr: 'Baccalauréat scientifique solide (maths, physique, chimie, biologie).',
          en: 'Strong science baccalaureate (math, physics, chemistry, biology).'),
      _contactKpb,
    ],
  ),
  ProgramModel(
    id: 'prog_c002',
    institutionId: 'mcgill',
    countryId: 'canada',
    fieldId: 'd05',
    name: LocalizedText(
        fr: 'Bachelor of Engineering — Génie logiciel',
        en: 'Bachelor of Engineering — Software Engineering'),
    level: LocalizedText(fr: 'Bac+4', en: 'Bachelor'),
    duration: LocalizedText(fr: '4 ans', en: '4 years'),
    tuition: LocalizedText(fr: 'CAD 19k–42k/an', en: 'CAD 19k–42k/yr'),
    language:
        LocalizedText(fr: 'Anglais (IELTS 6.5+)', en: 'English (IELTS 6.5+)'),
    requirements: [_contactKpb],
  ),
  // ── Université de Montréal ──────────────────────────────────────────────
  ProgramModel(
    id: 'prog_c003',
    institutionId: 'udem',
    countryId: 'canada',
    fieldId: 'd01',
    name: LocalizedText(
        fr: 'Baccalauréat en informatique', en: 'Bachelor in Computer Science'),
    level: LocalizedText(fr: 'Bac+3', en: 'Bachelor'),
    duration: LocalizedText(fr: '3 ans', en: '3 years'),
    tuition: LocalizedText(fr: 'CAD 15k–27k/an', en: 'CAD 15k–27k/yr'),
    language: LocalizedText(fr: 'Français (TCF B2+)', en: 'French (TCF B2+)'),
    requirements: [_contactKpb],
  ),
  // ── HEC Montréal (business) ─────────────────────────────────────────────
  ProgramModel(
    id: 'prog_c004',
    institutionId: 'hec_montreal',
    countryId: 'canada',
    fieldId: 'd02',
    name: LocalizedText(
        fr: 'BAA — Administration des affaires',
        en: 'BBA — Business Administration'),
    level: LocalizedText(fr: 'Bac+3', en: 'Bachelor'),
    duration: LocalizedText(fr: '3 ans', en: '3 years'),
    tuition: LocalizedText(fr: 'CAD 18k–32k/an', en: 'CAD 18k–32k/yr'),
    language: LocalizedText(
        fr: 'Français / Anglais selon programme',
        en: 'French / English depending on program'),
    requirements: [_contactKpb],
  ),
  // ── Université Laval (agriculture, foresterie) ──────────────────────────
  ProgramModel(
    id: 'prog_c005',
    institutionId: 'ulaval',
    countryId: 'canada',
    fieldId: 'd10',
    name: LocalizedText(
        fr: 'Baccalauréat en agronomie', en: 'Bachelor in Agronomy'),
    level: LocalizedText(fr: 'Bac+3', en: 'Bachelor'),
    duration: LocalizedText(fr: '3 ans', en: '3 years'),
    tuition: LocalizedText(fr: 'CAD 14k–22k/an', en: 'CAD 14k–22k/yr'),
    language: LocalizedText(fr: 'Français (TCF B2+)', en: 'French (TCF B2+)'),
    requirements: [_contactKpb],
  ),
  // ── Université d'Ottawa (droit, admin publique) ─────────────────────────
  ProgramModel(
    id: 'prog_c006',
    institutionId: 'uottawa',
    countryId: 'canada',
    fieldId: 'd07',
    name: LocalizedText(
        fr: 'Baccalauréat en droit / sciences politiques',
        en: 'Bachelor in Law / Political Science'),
    level: LocalizedText(fr: 'Bac+3', en: 'Bachelor'),
    duration: LocalizedText(fr: '3–4 ans', en: '3–4 years'),
    tuition: LocalizedText(fr: 'CAD 26k–38k/an', en: 'CAD 26k–38k/yr'),
    language: LocalizedText(
        fr: 'Français ou Anglais (IELTS 6.5)',
        en: 'French or English (IELTS 6.5)'),
    requirements: [_contactKpb],
  ),
  // ── Concordia (média, arts, business) ───────────────────────────────────
  ProgramModel(
    id: 'prog_c007',
    institutionId: 'concordia',
    countryId: 'canada',
    fieldId: 'd06',
    name: LocalizedText(
        fr: 'Bachelor en communication & médias',
        en: 'Bachelor in Communication & Media'),
    level: LocalizedText(fr: 'Bac+3', en: 'Bachelor'),
    duration: LocalizedText(fr: '3 ans', en: '3 years'),
    tuition: LocalizedText(fr: 'CAD 20k–30k/an', en: 'CAD 20k–30k/yr'),
    language:
        LocalizedText(fr: 'Anglais (IELTS 6.5+)', en: 'English (IELTS 6.5+)'),
    requirements: [_contactKpb],
  ),
  // ── UQAM (communication, sciences sociales) ─────────────────────────────
  ProgramModel(
    id: 'prog_c008',
    institutionId: 'uqam',
    countryId: 'canada',
    fieldId: 'd09',
    name: LocalizedText(
        fr: 'Baccalauréat en sciences humaines & sociales',
        en: 'Bachelor in Humanities & Social Sciences'),
    level: LocalizedText(fr: 'Bac+3', en: 'Bachelor'),
    duration: LocalizedText(fr: '3 ans', en: '3 years'),
    tuition: LocalizedText(fr: 'CAD 13k–18k/an', en: 'CAD 13k–18k/yr'),
    language: LocalizedText(fr: 'Français (B2)', en: 'French (B2)'),
    requirements: [_contactKpb],
  ),
  // ── Université de Sherbrooke (co-op, génie) ─────────────────────────────
  ProgramModel(
    id: 'prog_c009',
    institutionId: 'usherbrooke',
    countryId: 'canada',
    fieldId: 'd05',
    name: LocalizedText(
        fr: 'Baccalauréat en génie (coopératif)',
        en: 'Bachelor of Engineering (Co-op)'),
    level: LocalizedText(fr: 'Bac+4', en: 'Bachelor'),
    duration: LocalizedText(fr: '4 ans', en: '4 years'),
    tuition: LocalizedText(fr: 'CAD 12k–20k/an', en: 'CAD 12k–20k/yr'),
    language: LocalizedText(fr: 'Français (B2+)', en: 'French (B2+)'),
    requirements: [_contactKpb],
  ),
  // ── Trinity Western University (privée, BC) ─────────────────────────────
  ProgramModel(
    id: 'prog_ca_priv001',
    institutionId: 'twu',
    countryId: 'canada',
    fieldId: 'd09',
    name: LocalizedText(
        fr: 'Bachelor of Arts — Leadership',
        en: 'Bachelor of Arts — Leadership'),
    level: LocalizedText(fr: 'Bac+3', en: 'Bachelor'),
    duration: LocalizedText(fr: '4 ans', en: '4 years'),
    tuition: LocalizedText(fr: 'CAD 22 000/an', en: 'CAD 22,000/yr'),
    language:
        LocalizedText(fr: 'Anglais (IELTS 6.5)', en: 'English (IELTS 6.5)'),
    requirements: [_contactKpb],
  ),
  // ── Fairleigh Dickinson University — Vancouver ──────────────────────────
  ProgramModel(
    id: 'prog_ca_priv002',
    institutionId: 'fdu_vancouver',
    countryId: 'canada',
    fieldId: 'd02',
    name: LocalizedText(
        fr: 'Bachelor of Arts in Business (diplôme US)',
        en: 'Bachelor of Arts in Business (US degree)'),
    level: LocalizedText(fr: 'Bac+4', en: 'Bachelor'),
    duration: LocalizedText(fr: '4 ans', en: '4 years'),
    tuition: LocalizedText(fr: 'CAD 25 000/an', en: 'CAD 25,000/yr'),
    language:
        LocalizedText(fr: 'Anglais (IELTS 6.0)', en: 'English (IELTS 6.0)'),
    requirements: [_contactKpb],
  ),
  // ── University Canada West (MBA) ────────────────────────────────────────
  ProgramModel(
    id: 'prog_ca_priv003',
    institutionId: 'ucw',
    countryId: 'canada',
    fieldId: 'd02',
    name: LocalizedText(
        fr: 'MBA — Master of Business Administration',
        en: 'MBA — Master of Business Administration'),
    level: LocalizedText(fr: 'MBA', en: 'MBA'),
    duration: LocalizedText(fr: '2 ans', en: '2 years'),
    tuition: LocalizedText(
        fr: 'CAD 20 000–38 000/programme', en: 'CAD 20,000–38,000/program'),
    language:
        LocalizedText(fr: 'Anglais (IELTS 6.5)', en: 'English (IELTS 6.5)'),
    requirements: [_contactKpb],
  ),
  // ── York University (Schulich Business) ─────────────────────────────────
  ProgramModel(
    id: 'prog_ca_york',
    institutionId: 'york_u',
    countryId: 'canada',
    fieldId: 'd02',
    name: LocalizedText(
        fr: 'Bachelor of Business Administration (Schulich)',
        en: 'Bachelor of Business Administration (Schulich)'),
    level: LocalizedText(fr: 'Bac+4', en: 'Bachelor'),
    duration: LocalizedText(fr: '4 ans', en: '4 years'),
    tuition:
        LocalizedText(fr: 'CAD 28 000–35 000/an', en: 'CAD 28,000–35,000/yr'),
    language:
        LocalizedText(fr: 'Anglais (IELTS 6.5)', en: 'English (IELTS 6.5)'),
    requirements: [_contactKpb],
  ),
  // ── Université de Moncton (francophone, partenaire) ─────────────────────
  ProgramModel(
    id: 'prog_ca_moncton',
    institutionId: 'moncton',
    countryId: 'canada',
    fieldId: 'd02',
    name: LocalizedText(
        fr: 'Baccalauréat en administration des affaires',
        en: 'Bachelor in Business Administration'),
    level: LocalizedText(fr: 'Bac+3', en: 'Bachelor'),
    duration: LocalizedText(fr: '4 ans', en: '4 years'),
    tuition:
        LocalizedText(fr: 'CAD 12 000–15 000/an', en: 'CAD 12,000–15,000/yr'),
    language: LocalizedText(fr: 'Français (B2)', en: 'French (B2)'),
    requirements: [_contactKpb],
  ),
  // ── Dalhousie University (sciences de la mer) ───────────────────────────
  ProgramModel(
    id: 'prog_ca_dal',
    institutionId: 'dalhousie',
    countryId: 'canada',
    fieldId: 'd08',
    name: LocalizedText(
        fr: 'Bachelor of Science — Sciences marines & environnement',
        en: 'Bachelor of Science — Marine & Environmental Science'),
    level: LocalizedText(fr: 'Bac+4', en: 'Bachelor'),
    duration: LocalizedText(fr: '4 ans', en: '4 years'),
    tuition:
        LocalizedText(fr: 'CAD 20 000–26 000/an', en: 'CAD 20,000–26,000/yr'),
    language:
        LocalizedText(fr: 'Anglais (IELTS 6.5)', en: 'English (IELTS 6.5)'),
    requirements: [_contactKpb],
  ),
  // ── BCIT (informatique, génie civil) ────────────────────────────────────
  ProgramModel(
    id: 'prog_ca_bcit',
    institutionId: 'bc_poly',
    countryId: 'canada',
    fieldId: 'd01',
    name: LocalizedText(
        fr: 'Diploma — Technologie de l\'information',
        en: 'Diploma — Information Technology'),
    level: LocalizedText(fr: 'Diplôme', en: 'Diploma'),
    duration: LocalizedText(fr: '2 ans', en: '2 years'),
    tuition: LocalizedText(fr: 'CAD 18 000/an', en: 'CAD 18,000/yr'),
    language:
        LocalizedText(fr: 'Anglais (IELTS 6.0)', en: 'English (IELTS 6.0)'),
    requirements: [_contactKpb],
  ),
  // ── Seneca Polytechnic ──────────────────────────────────────────────────
  ProgramModel(
    id: 'prog_ca_seneca',
    institutionId: 'seneca',
    countryId: 'canada',
    fieldId: 'd05',
    name: LocalizedText(
        fr: 'Advanced Diploma — Génie & technologie',
        en: 'Advanced Diploma — Engineering & Technology'),
    level: LocalizedText(fr: 'Diplôme', en: 'Diploma'),
    duration: LocalizedText(fr: '2–3 ans', en: '2–3 years'),
    tuition: LocalizedText(fr: 'CAD 16 000/an', en: 'CAD 16,000/yr'),
    language:
        LocalizedText(fr: 'Anglais (IELTS 6.0)', en: 'English (IELTS 6.0)'),
    requirements: [_contactKpb],
  ),
  // ── Queen's University (business, santé) ────────────────────────────────
  ProgramModel(
    id: 'prog_ca_queens',
    institutionId: 'queens_u',
    countryId: 'canada',
    fieldId: 'd02',
    name: LocalizedText(fr: 'Bachelor of Commerce', en: 'Bachelor of Commerce'),
    level: LocalizedText(fr: 'Bac+4', en: 'Bachelor'),
    duration: LocalizedText(fr: '4 ans', en: '4 years'),
    tuition: LocalizedText(fr: 'CAD 35 000/an', en: 'CAD 35,000/yr'),
    language:
        LocalizedText(fr: 'Anglais (IELTS 7.0)', en: 'English (IELTS 7.0)'),
    requirements: [_contactKpb],
  ),
  // ── Western University (Ivey Business) ──────────────────────────────────
  ProgramModel(
    id: 'prog_ca_western',
    institutionId: 'western_u',
    countryId: 'canada',
    fieldId: 'd02',
    name: LocalizedText(
        fr: 'Honors Business Administration (Ivey)',
        en: 'Honors Business Administration (Ivey)'),
    level: LocalizedText(fr: 'Bac+4', en: 'Bachelor'),
    duration: LocalizedText(fr: '4 ans', en: '4 years'),
    tuition: LocalizedText(fr: 'CAD 32 000/an', en: 'CAD 32,000/yr'),
    language:
        LocalizedText(fr: 'Anglais (IELTS 6.5)', en: 'English (IELTS 6.5)'),
    requirements: [_contactKpb],
  ),
  // ── Université de Sherbrooke (entrée alt., génie) ───────────────────────
  ProgramModel(
    id: 'prog_ca_sherb',
    institutionId: 'sherbrooke',
    countryId: 'canada',
    fieldId: 'd05',
    name: LocalizedText(
        fr: 'Baccalauréat en génie mécanique',
        en: 'Bachelor in Mechanical Engineering'),
    level: LocalizedText(fr: 'Bac+4', en: 'Bachelor'),
    duration: LocalizedText(fr: '4 ans', en: '4 years'),
    tuition: LocalizedText(fr: 'CAD 18 000/an', en: 'CAD 18,000/yr'),
    language: LocalizedText(fr: 'Français (B2)', en: 'French (B2)'),
    requirements: [_contactKpb],
  ),
  // ── Université Laval (programme additionnel) ────────────────────────────
  ProgramModel(
    id: 'prog_ca_laval',
    institutionId: 'u_laval',
    countryId: 'canada',
    fieldId: 'd03',
    name: LocalizedText(
        fr: 'Baccalauréat en sciences comptables',
        en: 'Bachelor in Accounting'),
    level: LocalizedText(fr: 'Bac+3', en: 'Bachelor'),
    duration: LocalizedText(fr: '3 ans', en: '3 years'),
    tuition: LocalizedText(fr: 'CAD 20 000/an', en: 'CAD 20,000/yr'),
    language: LocalizedText(fr: 'Français (B2+)', en: 'French (B2+)'),
    requirements: [_contactKpb],
  ),
];
