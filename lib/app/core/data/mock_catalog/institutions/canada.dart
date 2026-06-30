// AUTO-GENERATED — KPB Education catalog seed data.
// ignore_for_file: lines_longer_than_80_chars
import '../../../models/app_models.dart';

const kInstitutionsCanada = <InstitutionModel>[
  InstitutionModel(
    id: 'mcgill',
    name: LocalizedText(fr: 'Université McGill', en: 'McGill University'),
    countryId: 'canada',
    location: LocalizedText(fr: 'Montréal, Québec', en: 'Montreal, Quebec'),
    overview: LocalizedText(
        fr: 'Top 30 mondial, bilingue, forte communauté francophone, excellente en médecine, droit et ingénierie.',
        en: 'Top 30 globally, bilingual, strong francophone community, excellent in medicine, law and engineering.'),
    studyLevels: ['Bac+3', 'Bac+5', 'Doctorat'],
    tuitionLabel: LocalizedText(fr: 'CAD 19k–42k/an', en: 'CAD 19k–42k/yr'),
    languageRequirements:
        LocalizedText(fr: 'Anglais (IELTS 6.5+)', en: 'English (IELTS 6.5+)'),
    intakePeriods: ['Septembre', 'Janvier'],
    programIds: ['prog_c001', 'prog_c002'],
    isPartner: false,
  ),
  InstitutionModel(
    id: 'udem',
    name: LocalizedText(
        fr: 'Université de Montréal', en: 'Université de Montréal'),
    countryId: 'canada',
    location: LocalizedText(fr: 'Montréal, Québec', en: 'Montreal, Quebec'),
    overview: LocalizedText(
        fr: 'Top 3 des universités francophones au monde. Excellente pour les étudiants d\'Afrique francophone.',
        en: 'Top 3 francophone university worldwide. Excellent for francophone African students.'),
    studyLevels: ['Bac+3', 'Bac+5', 'Doctorat'],
    tuitionLabel: LocalizedText(fr: 'CAD 15k–27k/an', en: 'CAD 15k–27k/yr'),
    languageRequirements:
        LocalizedText(fr: 'Français (TCF B2+)', en: 'French (TCF B2+)'),
    intakePeriods: ['Septembre', 'Janvier'],
    programIds: ['prog_c003'],
    isPartner: false,
  ),
  InstitutionModel(
    id: 'hec_montreal',
    name: LocalizedText(fr: 'HEC Montréal', en: 'HEC Montréal'),
    countryId: 'canada',
    location: LocalizedText(fr: 'Montréal, Québec', en: 'Montreal, Quebec'),
    overview: LocalizedText(
        fr: '#1 École de gestion francophone en Amérique du Nord. MBA et MSc très reconnus.',
        en: '#1 Francophone business school in North America. Highly recognized MBA and MSc.'),
    studyLevels: ['Bac+3', 'Bac+5', 'MBA'],
    tuitionLabel: LocalizedText(fr: 'CAD 18k–32k/an', en: 'CAD 18k–32k/yr'),
    languageRequirements: LocalizedText(
        fr: 'Français / Anglais selon programme',
        en: 'French / English depending on program'),
    intakePeriods: ['Septembre', 'Janvier'],
    programIds: ['prog_c004'],
    isPartner: false,
  ),
  InstitutionModel(
    id: 'ulaval',
    name: LocalizedText(fr: 'Université Laval', en: 'Université Laval'),
    countryId: 'canada',
    location: LocalizedText(fr: 'Québec City', en: 'Quebec City'),
    overview: LocalizedText(
        fr: 'Première université francophone d\'Amérique. Forte en agriculture, foresterie, médecine et droit.',
        en: 'First francophone university in America. Strong in agriculture, forestry, medicine and law.'),
    studyLevels: ['Bac+3', 'Bac+5', 'Doctorat'],
    tuitionLabel: LocalizedText(fr: 'CAD 14k–22k/an', en: 'CAD 14k–22k/yr'),
    languageRequirements:
        LocalizedText(fr: 'Français (TCF B2+)', en: 'French (TCF B2+)'),
    intakePeriods: ['Septembre', 'Janvier'],
    programIds: ['prog_c005'],
    isPartner: false,
  ),
  InstitutionModel(
    id: 'uottawa',
    name: LocalizedText(fr: 'Université d\'Ottawa', en: 'University of Ottawa'),
    countryId: 'canada',
    location: LocalizedText(fr: 'Ottawa, Ontario', en: 'Ottawa, Ontario'),
    overview: LocalizedText(
        fr: 'Seule université bilingue (FR/EN) du Canada. Droit, administration publique et sciences de la santé.',
        en: 'Canada\'s only bilingual (FR/EN) university. Law, public administration and health sciences.'),
    studyLevels: ['Bac+3', 'Bac+5', 'Doctorat'],
    tuitionLabel: LocalizedText(fr: 'CAD 26k–38k/an', en: 'CAD 26k–38k/yr'),
    languageRequirements: LocalizedText(
        fr: 'Français ou Anglais (IELTS 6.5)',
        en: 'French or English (IELTS 6.5)'),
    intakePeriods: ['Septembre', 'Janvier'],
    programIds: ['prog_c006'],
    isPartner: false,
  ),
  InstitutionModel(
    id: 'concordia',
    name: LocalizedText(fr: 'Université Concordia', en: 'Concordia University'),
    countryId: 'canada',
    location: LocalizedText(fr: 'Montréal, Québec', en: 'Montreal, Quebec'),
    overview: LocalizedText(
        fr: 'Université anglophone dynamique à Montréal. Forte en média, arts, business et génie.',
        en: 'Dynamic English-language university in Montreal. Strong in media, arts, business and engineering.'),
    studyLevels: ['Bac+3', 'Bac+5'],
    tuitionLabel: LocalizedText(fr: 'CAD 20k–30k/an', en: 'CAD 20k–30k/yr'),
    languageRequirements:
        LocalizedText(fr: 'Anglais (IELTS 6.5+)', en: 'English (IELTS 6.5+)'),
    intakePeriods: ['Septembre', 'Janvier'],
    programIds: ['prog_c007'],
    isPartner: false,
  ),
  InstitutionModel(
    id: 'uqam',
    name:
        LocalizedText(fr: 'Université du Québec à Montréal (UQAM)', en: 'UQAM'),
    countryId: 'canada',
    location: LocalizedText(fr: 'Montréal, Québec', en: 'Montreal, Quebec'),
    overview: LocalizedText(
        fr: 'Université publique abordable. Forte en communication, arts et sciences sociales. Très accueillante pour Africa.',
        en: 'Affordable public university. Strong in communications, arts and social sciences. Very welcoming for Africa.'),
    studyLevels: ['Bac+3', 'Bac+5'],
    tuitionLabel: LocalizedText(fr: 'CAD 13k–18k/an', en: 'CAD 13k–18k/yr'),
    languageRequirements: LocalizedText(fr: 'Français (B2)', en: 'French (B2)'),
    intakePeriods: ['Septembre', 'Janvier'],
    programIds: ['prog_c008'],
    isPartner: false,
  ),
  InstitutionModel(
    id: 'usherbrooke',
    name: LocalizedText(
        fr: 'Université de Sherbrooke', en: 'Université de Sherbrooke'),
    countryId: 'canada',
    location: LocalizedText(fr: 'Sherbrooke, Québec', en: 'Sherbrooke, Quebec'),
    overview: LocalizedText(
        fr: 'Pionnière en co-op (alternance travail-études). Excellente en génie, médecine et environnement.',
        en: 'Pioneer in co-op (work-study). Excellent in engineering, medicine and environment.'),
    studyLevels: ['Bac+3', 'Bac+5', 'Doctorat'],
    tuitionLabel: LocalizedText(fr: 'CAD 12k–20k/an', en: 'CAD 12k–20k/yr'),
    languageRequirements:
        LocalizedText(fr: 'Français (B2+)', en: 'French (B2+)'),
    intakePeriods: ['Septembre', 'Janvier'],
    programIds: ['prog_c009'],
    isPartner: false,
  ),
  // ── UK ────────────────────────────────────────────────────────────────────
  InstitutionModel(
    id: 'twu',
    name: LocalizedText(
        fr: 'Trinity Western University', en: 'Trinity Western University'),
    countryId: 'canada',
    location: LocalizedText(fr: 'Langley, BC', en: 'Langley, BC'),
    overview: LocalizedText(
        fr: 'La plus grande université chrétienne privée du Canada. Petites classes, forte attention à l\'étudiant.',
        en: 'The largest private Christian university in Canada. Small classes, strong student focus.'),
    studyLevels: ['Bac+3', 'Bac+5'],
    tuitionLabel: LocalizedText(fr: 'CAD 22 000/an', en: 'CAD 22 000/yr'),
    languageRequirements:
        LocalizedText(fr: 'Anglais (IELTS 6.5)', en: 'English (IELTS 6.5)'),
    intakePeriods: ['Septembre', 'Janvier', 'Mai'],
    programIds: ['prog_ca_priv001'],
    isPartner: false,
  ),
  InstitutionModel(
    id: 'fdu_vancouver',
    name: LocalizedText(
        fr: 'Fairleigh Dickinson University - Vancouver',
        en: 'Fairleigh Dickinson University - Vancouver'),
    countryId: 'canada',
    location: LocalizedText(fr: 'Vancouver, BC', en: 'Vancouver, BC'),
    overview: LocalizedText(
        fr: 'Campus canadien d\'une université américaine. Diplôme US et permis de travail post-diplôme canadien (PGWP).',
        en: 'Canadian campus of an American university. US degree and Canadian post-graduation work permit (PGWP).'),
    studyLevels: ['Bac+3', 'Bac+5'],
    tuitionLabel: LocalizedText(fr: 'CAD 25 000/an', en: 'CAD 25 000/yr'),
    languageRequirements:
        LocalizedText(fr: 'Anglais (IELTS 6.0)', en: 'English (IELTS 6.0)'),
    intakePeriods: ['Septembre', 'Janvier', 'Mai'],
    programIds: ['prog_ca_priv002'],
    isPartner: false,
  ),
  InstitutionModel(
    id: 'ucw',
    name: LocalizedText(
        fr: 'University Canada West (UCW)', en: 'University Canada West (UCW)'),
    countryId: 'canada',
    location: LocalizedText(fr: 'Vancouver, BC', en: 'Vancouver, BC'),
    overview: LocalizedText(
        fr: 'Université privée focus Business et Tech. Très populaire pour son MBA accessible et son accompagnement.',
        en: 'Private university focused on Business and Tech. Very popular for its accessible MBA and support.'),
    studyLevels: ['Bac+3', 'MBA'],
    tuitionLabel: LocalizedText(
        fr: 'CAD 20 000–38 000/programme', en: 'CAD 20 000–38 000/program'),
    languageRequirements:
        LocalizedText(fr: 'Anglais (IELTS 6.5)', en: 'English (IELTS 6.5)'),
    intakePeriods: ['Octobre', 'Janvier', 'Avril', 'Juillet'],
    programIds: ['prog_ca_priv003'],
    isPartner: false,
  ),
  // ── FRANCE (Privées / Écoles supplémentaires non-OMNES/IGS) ───────────────
  InstitutionModel(
    id: 'york_u',
    name: LocalizedText(fr: 'Université York', en: 'York University'),
    countryId: 'canada',
    location: LocalizedText(fr: 'Toronto, Ontario', en: 'Toronto, Ontario'),
    overview: LocalizedText(
        fr: '3ème plus grande université du Canada. Schulich School of Business de renommée mondiale. Très diverse.',
        en: '3rd largest university in Canada. World-renowned Schulich School of Business. Very diverse.'),
    studyLevels: ['Bac+3', 'Bac+5', 'Doctorat'],
    tuitionLabel:
        LocalizedText(fr: 'CAD 28 000–35 000/an', en: 'CAD 28 000–35 000/yr'),
    languageRequirements:
        LocalizedText(fr: 'Anglais (IELTS 6.5)', en: 'English (IELTS 6.5)'),
    intakePeriods: ['Septembre', 'Janvier', 'Mai'],
    programIds: ['prog_ca_york'],
    isPartner: false,
  ),
  InstitutionModel(
    id: 'moncton',
    name:
        LocalizedText(fr: 'Université de Moncton', en: 'Université de Moncton'),
    countryId: 'canada',
    location: LocalizedText(
        fr: 'Moncton, Nouveau-Brunswick', en: 'Moncton, New Brunswick'),
    overview: LocalizedText(
        fr: 'Plus grande université francophone hors Québec. Très abordable. Excellente pour les étudiants d\'Afrique de l\'Ouest.',
        en: 'Largest francophone university outside Quebec. Very affordable. Excellent for West African students.'),
    studyLevels: ['Bac+3', 'Bac+5'],
    tuitionLabel:
        LocalizedText(fr: 'CAD 12 000–15 000/an', en: 'CAD 12 000–15 000/yr'),
    languageRequirements: LocalizedText(fr: 'Français (B2)', en: 'French (B2)'),
    intakePeriods: ['Septembre', 'Janvier'],
    programIds: ['prog_ca_moncton'],
    isPartner: true,
  ),
  InstitutionModel(
    id: 'dalhousie',
    name: LocalizedText(fr: 'Dalhousie University', en: 'Dalhousie University'),
    countryId: 'canada',
    location: LocalizedText(
        fr: 'Halifax, Nouvelle-Écosse', en: 'Halifax, Nova Scotia'),
    overview: LocalizedText(
        fr: 'Membre du U15 (recherche). Forte en Sciences de la mer, Médecine et Droit. Très bon accueil international.',
        en: 'Member of U15 (research). Strong in Ocean Sciences, Medicine and Law. Very welcoming to international students.'),
    studyLevels: ['Bac+3', 'Bac+5', 'Doctorat'],
    tuitionLabel:
        LocalizedText(fr: 'CAD 20 000–26 000/an', en: 'CAD 20 000–26 000/yr'),
    languageRequirements:
        LocalizedText(fr: 'Anglais (IELTS 6.5)', en: 'English (IELTS 6.5)'),
    intakePeriods: ['Septembre', 'Janvier'],
    programIds: ['prog_ca_dal'],
    isPartner: false,
  ),
  InstitutionModel(
    id: 'bc_poly',
    name: LocalizedText(
        fr: 'British Columbia Institute of Technology (BCIT)',
        en: 'British Columbia Institute of Technology'),
    countryId: 'canada',
    location: LocalizedText(fr: 'Burnaby, BC', en: 'Burnaby, BC'),
    overview: LocalizedText(
        fr: 'Focus sur l\'employabilité immédiate. Très forte en Informatique et Génie civil.',
        en: 'Focus on immediate employability. Strong in Computer Science and Civil Engineering.'),
    studyLevels: ['Diploma', 'Bac+3'],
    tuitionLabel: LocalizedText(fr: 'CAD 18 000/an', en: 'CAD 18 000/yr'),
    languageRequirements:
        LocalizedText(fr: 'Anglais (IELTS 6.0)', en: 'English (IELTS 6.0)'),
    intakePeriods: ['Septembre', 'Janvier'],
    programIds: ['prog_ca_bcit'],
    isPartner: false,
  ),
  InstitutionModel(
    id: 'seneca',
    name: LocalizedText(fr: 'Seneca Polytechnic', en: 'Seneca Polytechnic'),
    countryId: 'canada',
    location: LocalizedText(fr: 'Toronto, Ontario', en: 'Toronto, Ontario'),
    overview: LocalizedText(
        fr: 'Leader canadien de l\'enseignement polytechnique. Plus de 190 programmes innovants.',
        en: 'Canadian leader in polytechnic education. Over 190 innovative programs.'),
    studyLevels: ['Diploma', 'Bac+3'],
    tuitionLabel: LocalizedText(fr: 'CAD 16 000/an', en: 'CAD 16 000/yr'),
    languageRequirements:
        LocalizedText(fr: 'Anglais (IELTS 6.0)', en: 'English (IELTS 6.0)'),
    intakePeriods: ['Septembre', 'Janvier', 'Mai'],
    programIds: ['prog_ca_seneca'],
    isPartner: false,
  ),
  InstitutionModel(
    id: 'queens_u',
    name: LocalizedText(fr: 'Queen\'s University', en: 'Queen\'s University'),
    countryId: 'canada',
    location: LocalizedText(fr: 'Kingston, Ontario', en: 'Kingston, Ontario'),
    overview: LocalizedText(
        fr: 'Haut niveau académique. Très forte en Business et Santé.',
        en: 'High academic standard. Very strong in Business and Health.'),
    studyLevels: ['Bachelor', 'Master'],
    tuitionLabel: LocalizedText(fr: 'CAD 35 000/an', en: 'CAD 35 000/yr'),
    languageRequirements:
        LocalizedText(fr: 'Anglais (IELTS 7.0)', en: 'English (IELTS 7.0)'),
    intakePeriods: ['Septembre'],
    programIds: ['prog_ca_queens'],
    isPartner: false,
  ),
  InstitutionModel(
    id: 'western_u',
    name: LocalizedText(fr: 'Western University', en: 'Western University'),
    countryId: 'canada',
    location: LocalizedText(fr: 'London, Ontario', en: 'London, Ontario'),
    overview: LocalizedText(
        fr: 'Ivey Business School de renommée mondiale. Campus magnifique.',
        en: 'Home to the world-renowned Ivey Business School. Beautiful campus.'),
    studyLevels: ['Bachelor', 'Master'],
    tuitionLabel: LocalizedText(fr: 'CAD 32 000/an', en: 'CAD 32 000/yr'),
    languageRequirements:
        LocalizedText(fr: 'Anglais (IELTS 6.5)', en: 'English (IELTS 6.5)'),
    intakePeriods: ['Septembre'],
    programIds: ['prog_ca_western'],
    isPartner: false,
  ),
  InstitutionModel(
    id: 'sherbrooke',
    name: LocalizedText(
        fr: 'Université de Sherbrooke', en: 'University of Sherbrooke'),
    countryId: 'canada',
    location: LocalizedText(fr: 'Sherbrooke, Québec', en: 'Sherbrooke, Quebec'),
    overview: LocalizedText(
        fr: 'Pionnière de l\'apprentissage expérientiel. Très forte en Génie.',
        en: 'Pioneer of experiential learning. Very strong in Engineering.'),
    studyLevels: ['Bac', 'Master'],
    tuitionLabel: LocalizedText(fr: 'CAD 18 000/an', en: 'CAD 18 000/yr'),
    languageRequirements: LocalizedText(fr: 'Français (B2)', en: 'French (B2)'),
    intakePeriods: ['Septembre', 'Janvier'],
    programIds: ['prog_ca_sherb'],
    isPartner: false,
  ),
  InstitutionModel(
    id: 'u_laval',
    name: LocalizedText(fr: 'Université Laval', en: 'Laval University'),
    countryId: 'canada',
    location:
        LocalizedText(fr: 'Québec City, Québec', en: 'Quebec City, Quebec'),
    overview: LocalizedText(
        fr: 'Première université francophone d\'Amérique. Excellence dans tous les domaines.',
        en: 'First francophone university in America. Excellence in all fields.'),
    studyLevels: ['Bac', 'Master', 'Doctorat'],
    tuitionLabel: LocalizedText(fr: 'CAD 20 000/an', en: 'CAD 20 000/yr'),
    languageRequirements:
        LocalizedText(fr: 'Français (B2+)', en: 'French (B2+)'),
    intakePeriods: ['Septembre', 'Janvier'],
    programIds: ['prog_ca_laval'],
    isPartner: false,
  ),
];
