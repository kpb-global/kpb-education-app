import { CaseStatus } from '../enums/case-status.enum';
import { InternalRole } from '../enums/internal-role.enum';
import { NotificationCampaignStatus } from '../enums/notification-campaign-status.enum';
import { PublicationStatus } from '../enums/publication-status.enum';

export const mockAdminData = {
  serviceOffers: [
    {
      id: 'offer-application-pack',
      name: { fr: 'Pack admission guidée', en: 'Guided application pack' },
      offerType: 'application_support',
      destinationIds: ['canada', 'france', 'uk'],
      studyLevels: ['Bachelor', 'Master'],
      priceLabel: { fr: 'Sur devis', en: 'Quoted on request' },
      benefits: {
        fr: [
          'Qualification du profil',
          'Shortlist de programmes',
          'Support documents et suivi',
        ],
        en: [
          'Profile qualification',
          'Program shortlist',
          'Document support and follow-up',
        ],
      },
      ctaLabel: { fr: 'Démarrer ma candidature', en: 'Start my application' },
      status: PublicationStatus.Published,
    },
    {
      id: 'offer-scholarship-boost',
      name: { fr: 'Boost bourse', en: 'Scholarship boost' },
      offerType: 'scholarship_support',
      destinationIds: ['canada', 'france'],
      studyLevels: ['Bachelor', 'Master', 'PhD'],
      priceLabel: { fr: 'À partir de 75 000 FCFA', en: 'From 75,000 XOF' },
      benefits: {
        fr: [
          'Matching bourses',
          'Vérification éligibilité',
          'Stratégie dossier',
        ],
        en: [
          'Scholarship matching',
          'Eligibility review',
          'Application strategy',
        ],
      },
      ctaLabel: { fr: 'Demander un accompagnement', en: 'Request support' },
      status: PublicationStatus.Published,
    },
  ],
  supportDestinations: [
    {
      id: 'support-canada',
      countryId: 'canada',
      countryName: { fr: 'Canada', en: 'Canada' },
      supportLanguages: ['fr', 'en'],
      availableServiceTypes: [
        'consultation',
        'application_support',
        'scholarship_support',
      ],
      conditions: {
        fr: ['Profil académique complet', 'Projet d’études défini ou en orientation'],
        en: ['Complete academic profile', 'Study plan defined or still in orientation'],
      },
      counselorNames: ['Amina KPB', 'Youssef KPB'],
      isVisible: true,
      status: PublicationStatus.Published,
    },
    {
      id: 'support-france',
      countryId: 'france',
      countryName: { fr: 'France', en: 'France' },
      supportLanguages: ['fr'],
      availableServiceTypes: [
        'consultation',
        'application_support',
        'housing_support',
      ],
      conditions: {
        fr: ['Campus France ou admission directe selon le programme'],
        en: ['Campus France or direct admission depending on the program'],
      },
      counselorNames: ['Moussa KPB'],
      isVisible: true,
      status: PublicationStatus.Published,
    },
  ],
  articles: [
    {
      id: 'article-canada-budget',
      slug: 'budget-etudes-canada-afrique',
      category: 'guides',
      title: {
        fr: 'Budget études au Canada pour un étudiant africain',
        en: 'Study budget in Canada for an African student',
      },
      summary: {
        fr: 'Frais de scolarité, coût de vie, pièces financières et astuces pour préparer son dossier.',
        en: 'Tuition, living costs, proof of funds, and practical preparation tips.',
      },
      content: {
        fr: 'Préparez votre budget autour des frais académiques, du logement, de la vie quotidienne et de la preuve de fonds.',
        en: 'Build your budget around tuition, housing, day-to-day expenses, and proof-of-funds requirements.',
      },
      tags: ['budget', 'canada', 'visa'],
      authorName: 'KPB Editorial',
      status: PublicationStatus.Published,
      publishedAt: '2026-03-28T09:00:00.000Z',
    },
    {
      id: 'article-scholarships-2026',
      slug: '5-bourses-afrique-2026',
      category: 'scholarships',
      title: {
        fr: '5 bourses à surveiller en 2026',
        en: '5 scholarships to watch in 2026',
      },
      summary: {
        fr: 'Une sélection d’opportunités pour Licence et Master avec forte attractivité.',
        en: 'A shortlist of high-value Bachelor and Master opportunities.',
      },
      content: {
        fr: 'Repérez les bourses selon votre niveau, votre pays cible et vos délais de préparation.',
        en: 'Track scholarships by study level, destination country, and preparation timeline.',
      },
      tags: ['scholarships', 'deadlines', 'advice'],
      authorName: 'KPB Editorial',
      status: PublicationStatus.Draft,
      publishedAt: null,
    },
  ],
  forumCategories: [
    {
      id: 'forum-admission',
      label: { fr: 'Admissions', en: 'Admissions' },
      description: {
        fr: 'Questions sur les démarches, pièces et sélections.',
        en: 'Questions about application steps, documents, and selection.',
      },
      displayOrder: 1,
      status: PublicationStatus.Published,
    },
    {
      id: 'forum-scholarships',
      label: { fr: 'Bourses', en: 'Scholarships' },
      description: {
        fr: 'Retours d’expérience et stratégies de financement.',
        en: 'Experience sharing and funding strategies.',
      },
      displayOrder: 2,
      status: PublicationStatus.Published,
    },
  ],
  forumTags: [
    {
      id: 'tag-canada',
      label: { fr: 'Canada', en: 'Canada' },
      description: {
        fr: 'Sujets liés au Canada',
        en: 'Topics related to Canada',
      },
      displayOrder: 1,
      status: PublicationStatus.Published,
    },
    {
      id: 'tag-campus-france',
      label: { fr: 'Campus France', en: 'Campus France' },
      description: {
        fr: 'Tout sur les démarches Campus France',
        en: 'Everything about Campus France procedures',
      },
      displayOrder: 2,
      status: PublicationStatus.Published,
    },
  ],
  moderationQueue: [
    {
      id: 'moderation-1',
      targetType: 'forum_post',
      targetId: 'post-219',
      reason: 'Potential misinformation about visa timelines',
      action: 'review_pending',
      reporterCount: 2,
    },
  ],
  notificationTemplates: [
    {
      id: 'template-missing-docs',
      name: 'Missing documents reminder',
      title: {
        fr: 'Documents manquants sur votre dossier',
        en: 'Missing documents on your case',
      },
      body: {
        fr: 'Votre dossier KPB attend encore des pièces pour continuer.',
        en: 'Your KPB case still needs documents before moving forward.',
      },
      channels: ['push', 'in_app', 'email'],
      isCritical: true,
    },
    {
      id: 'template-webinar',
      name: 'Orientation webinar',
      title: {
        fr: 'Webinar orientation KPB',
        en: 'KPB orientation webinar',
      },
      body: {
        fr: 'Rejoignez notre session collective pour comprendre les meilleures options 2026.',
        en: 'Join our group session to understand the best 2026 options.',
      },
      channels: ['push', 'email'],
      isCritical: false,
    },
  ],
  notificationCampaigns: [
    {
      id: 'campaign-cases-reminder',
      name: 'Cases missing docs - April batch',
      templateId: 'template-missing-docs',
      audienceType: 'case_status',
      filters: {
        caseStatus: [CaseStatus.DocumentsNeeded],
        languages: ['fr', 'en'],
      },
      channels: ['push', 'in_app', 'email'],
      scheduledFor: '2026-04-08T08:00:00.000Z',
      status: NotificationCampaignStatus.Scheduled,
      linkedCaseId: 'case-1',
    },
    {
      id: 'campaign-orientation-webinar',
      name: 'Orientation webinar invite',
      templateId: 'template-webinar',
      audienceType: 'all_students',
      filters: {
        roles: ['student'],
        languages: ['fr', 'en'],
      },
      channels: ['push', 'email'],
      scheduledFor: null,
      status: NotificationCampaignStatus.Completed,
      linkedCaseId: null,
    },
  ],
  notificationDeliveries: [
    {
      id: 'delivery-1',
      campaignId: 'campaign-cases-reminder',
      recipientId: 'demo-user',
      recipientName: 'Aissatou Ibrahim',
      channel: 'push',
      status: 'queued',
      deliveredAt: null,
    },
    {
      id: 'delivery-2',
      campaignId: 'campaign-orientation-webinar',
      recipientId: 'student-2',
      recipientName: 'Kwame Mensah',
      channel: 'email',
      status: 'delivered',
      deliveredAt: '2026-04-04T10:10:00.000Z',
    },
  ],
  adminUsers: [
    {
      id: 'admin-1',
      fullName: 'Amina KPB',
      email: 'amina@kpb.education',
      role: InternalRole.Counselor,
      isActive: true,
      languageScope: ['fr', 'en'],
      workload: 18,
    },
    {
      id: 'admin-2',
      fullName: 'Moussa KPB',
      email: 'moussa@kpb.education',
      role: InternalRole.ContentManager,
      isActive: true,
      languageScope: ['fr'],
      workload: 7,
    },
    {
      id: 'admin-3',
      fullName: 'Fatou Admin',
      email: 'fatou@kpb.education',
      role: InternalRole.Admin,
      isActive: true,
      languageScope: ['fr', 'en'],
      workload: 12,
    },
  ],
  reports: {
    overview: {
      activeCases: 124,
      awaitingDocuments: 27,
      submittedThisWeek: 31,
      premiumConversions: 9,
      counselorResponseSlaHours: 2.2,
    },
    funnel: [
      { label: 'Leads', value: 520 },
      { label: 'Qualified cases', value: 188 },
      { label: 'Premium support', value: 74 },
      { label: 'Applications submitted', value: 39 },
      { label: 'Admissions received', value: 16 },
    ],
    counselorPerformance: [
      { counselor: 'Amina KPB', activeCases: 18, avgResponseHours: 1.8 },
      { counselor: 'Moussa KPB', activeCases: 11, avgResponseHours: 2.9 },
    ],
    campaignPerformance: [
      { campaign: 'Orientation webinar invite', delivered: 420, opened: 210 },
      { campaign: 'Cases missing docs - April batch', delivered: 64, opened: 33 },
    ],
  },
};
