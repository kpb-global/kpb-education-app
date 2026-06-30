// AUTO-GENERATED — KPB Education catalog seed data.
// ignore_for_file: lines_longer_than_80_chars
import '../../models/app_models.dart';

final kArticles = <ArticleModel>[
  ArticleModel(
    id: 'article-canada-budget',
    slug: 'budget-etudes-canada-afrique',
    category: 'guides',
    title: const LocalizedText(
        fr: 'Budget études au Canada pour un étudiant africain',
        en: 'Study budget in Canada for an African student'),
    summary: const LocalizedText(
        fr: 'Frais de scolarité, coût de vie, preuve de fonds et conseils pratiques.',
        en: 'Tuition, living costs, proof of funds, and practical planning tips.'),
    content: const LocalizedText(
        fr: 'Préparez votre budget autour des frais académiques, du logement et de la preuve de fonds.',
        en: 'Build your budget around tuition, housing, and proof-of-funds requirements.'),
    tags: const ['budget', 'canada', 'visa'],
    authorName: 'KPB Editorial',
    status: PublicationStatus.published,
    publishedAt: DateTime(2026, 3, 28, 9),
  ),
  ArticleModel(
    id: 'article-scholarships-2026',
    slug: '5-bourses-afrique-2026',
    category: 'scholarships',
    title: const LocalizedText(
        fr: '5 bourses à surveiller en 2026',
        en: '5 scholarships to watch in 2026'),
    summary: const LocalizedText(
        fr: 'Sélection d\'opportunités Licence et Master avec forte attractivité.',
        en: 'A shortlist of high-value Bachelor and Master opportunities.'),
    content: const LocalizedText(
        fr: 'Repérez les bourses selon votre niveau, pays cible et délais.',
        en: 'Track scholarships by study level, destination country, and timeline.'),
    tags: const ['scholarships', 'deadlines', 'strategy'],
    authorName: 'KPB Editorial',
    status: PublicationStatus.published,
    publishedAt: DateTime(2026, 4, 2, 14),
  ),
  ArticleModel(
    id: 'article-france-campus',
    slug: 'campus-france-guide-complet',
    category: 'guides',
    title: const LocalizedText(
        fr: 'Campus France : le guide complet pour l\'Afrique de l\'Ouest',
        en: 'Campus France: the complete guide for West Africa'),
    summary: const LocalizedText(
        fr: 'Procédure, timing, documents requis et erreurs à éviter.',
        en: 'Process, timing, required documents and mistakes to avoid.'),
    content: const LocalizedText(
        fr: 'Campus France est la porte d\'entrée vers les universités et grandes écoles françaises.',
        en: 'Campus France is the gateway to French universities and grandes écoles.'),
    tags: const ['france', 'campus-france', 'visa'],
    authorName: 'KPB Editorial',
    status: PublicationStatus.published,
    publishedAt: DateTime(2026, 3, 15, 10),
  ),
  ArticleModel(
    id: 'article-turkey-burslari',
    slug: 'bourse-turquie-burslari',
    category: 'scholarships',
    title: const LocalizedText(
        fr: 'Bourse Türkiye Burslari : comment postuler depuis l\'Afrique',
        en: 'Türkiye Burslari Scholarship: how to apply from Africa'),
    summary: const LocalizedText(
        fr: 'Bourse complète incluant frais, logement et billet d\'avion.',
        en: 'Full scholarship including tuition, housing and plane ticket.'),
    content: const LocalizedText(
        fr: 'La bourse Türkiye Burslari est l\'une des plus généreuses pour les étudiants africains.',
        en: 'The Türkiye Burslari scholarship is one of the most generous for African students.'),
    tags: const ['turquie', 'bourse-complete', 'medecine'],
    authorName: 'KPB Editorial',
    status: PublicationStatus.published,
    publishedAt: DateTime(2026, 2, 20, 8),
  ),
];

const kForumCategories = <ForumCategoryModel>[
  ForumCategoryModel(
    id: 'forum-admission',
    label: LocalizedText(
        fr: 'Admissions & Candidatures', en: 'Admissions & Applications'),
    description: LocalizedText(
        fr: 'Démarches, pièces requises, délais et retours d\'expérience.',
        en: 'Application steps, required documents, deadlines and experience sharing.'),
    displayOrder: 1,
    status: PublicationStatus.published,
  ),
  ForumCategoryModel(
    id: 'forum-scholarships',
    label: LocalizedText(
        fr: 'Bourses & Financement', en: 'Scholarships & Funding'),
    description: LocalizedText(
        fr: 'Stratégies de financement, dossiers de bourses et retours.',
        en: 'Funding strategies, scholarship applications and feedback.'),
    displayOrder: 2,
    status: PublicationStatus.published,
  ),
  ForumCategoryModel(
    id: 'forum-visa',
    label: LocalizedText(fr: 'Visa & Immigration', en: 'Visa & Immigration'),
    description: LocalizedText(
        fr: 'Démarches consulaires, refus, recours et témoignages.',
        en: 'Consular procedures, refusals, appeals and testimonials.'),
    displayOrder: 3,
    status: PublicationStatus.published,
  ),
  ForumCategoryModel(
    id: 'forum-logement',
    label: LocalizedText(fr: 'Logement & Arrivée', en: 'Housing & Arrival'),
    description: LocalizedText(
        fr: 'Trouver un logement, s\'installer, les premières semaines.',
        en: 'Finding housing, settling in, the first weeks abroad.'),
    displayOrder: 4,
    status: PublicationStatus.published,
  ),
  ForumCategoryModel(
    id: 'forum-vie-etudiante',
    label: LocalizedText(
        fr: 'Vie Étudiante & Conseils', en: 'Student Life & Tips'),
    description: LocalizedText(
        fr: 'Astuces, entraide et partage d\'expériences entre étudiants.',
        en: 'Tips, mutual support and experience sharing between students.'),
    displayOrder: 5,
    status: PublicationStatus.published,
  ),
];

const kForumTopicTags = <ForumTopicTagModel>[
  ForumTopicTagModel(
      id: 'tag-canada',
      label: LocalizedText(fr: 'Canada', en: 'Canada'),
      description: LocalizedText(
          fr: 'Sujets liés au Canada', en: 'Topics related to Canada'),
      displayOrder: 1,
      status: PublicationStatus.published),
  ForumTopicTagModel(
      id: 'tag-france',
      label: LocalizedText(fr: 'France', en: 'France'),
      description: LocalizedText(
          fr: 'Sujets liés à la France', en: 'Topics related to France'),
      displayOrder: 2,
      status: PublicationStatus.published),
  ForumTopicTagModel(
      id: 'tag-turquie',
      label: LocalizedText(fr: 'Turquie', en: 'Turkey'),
      description: LocalizedText(
          fr: 'Sujets liés à la Turquie', en: 'Topics related to Turkey'),
      displayOrder: 3,
      status: PublicationStatus.published),
  ForumTopicTagModel(
      id: 'tag-bourse-complete',
      label: LocalizedText(fr: 'Bourse complète', en: 'Full scholarship'),
      description: LocalizedText(
          fr: 'Bourses couvrant tous les frais',
          en: 'Scholarships covering all fees'),
      displayOrder: 4,
      status: PublicationStatus.published),
  ForumTopicTagModel(
      id: 'tag-campus-france',
      label: LocalizedText(fr: 'Campus France', en: 'Campus France'),
      description: LocalizedText(
          fr: 'Tout sur les démarches Campus France',
          en: 'Everything about Campus France procedures'),
      displayOrder: 5,
      status: PublicationStatus.published),
  ForumTopicTagModel(
      id: 'tag-visa-refus',
      label: LocalizedText(fr: 'Refus visa', en: 'Visa refusal'),
      description: LocalizedText(
          fr: 'Expériences de refus et recours',
          en: 'Refusal experiences and appeals'),
      displayOrder: 6,
      status: PublicationStatus.published),
];
