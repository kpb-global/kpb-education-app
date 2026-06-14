export const adminOverview = {
  activeCases: 124,
  awaitingDocuments: 27,
  consultationsThisWeek: 18,
  responseSla: '2h 14m',
};

export const adminCases = [
  {
    reference: 'KPB-2026-001',
    student: 'Aissatou Ibrahim',
    language: 'FR',
    type: 'consultation',
    country: 'Canada',
    owner: 'Amina KPB',
    status: 'counselor_assigned',
    nextStep: 'Confirmer la consultation de mardi à 16:00',
  },
  {
    reference: 'KPB-2026-002',
    student: 'Kwame Mensah',
    language: 'EN',
    type: 'scholarship_support',
    country: 'France',
    owner: 'Fatou Admin',
    status: 'documents_needed',
    nextStep: 'Relancer pour le certificat de langue',
  },
  {
    reference: 'KPB-2026-003',
    student: 'Mariam Diallo',
    language: 'FR',
    type: 'application_support',
    country: 'United Kingdom',
    owner: 'Moussa KPB',
    status: 'in_progress',
    nextStep: 'Vérifier la shortlist et les deadlines',
  },
];

export const serviceOffers = [
  {
    name: 'Pack admission guidée',
    status: 'published',
    destinations: 'Canada, France, UK',
    level: 'Bachelor / Master',
    price: 'Sur devis',
  },
  {
    name: 'Boost bourse',
    status: 'published',
    destinations: 'Canada, France',
    level: 'Bachelor / Master / PhD',
    price: 'À partir de 75 000 FCFA',
  },
];

export const supportDestinations = [
  {
    country: 'Canada',
    services: 'Consultation, admission, bourses',
    counselors: 'Amina KPB, Youssef KPB',
    languages: 'FR / EN',
    visibility: 'Visible',
  },
  {
    country: 'France',
    services: 'Consultation, admission, logement',
    counselors: 'Moussa KPB',
    languages: 'FR',
    visibility: 'Visible',
  },
];

export const articles = [
  {
    title: 'Budget études au Canada pour un étudiant africain',
    category: 'Guides',
    status: 'published',
    author: 'KPB Editorial',
  },
  {
    title: '5 bourses à surveiller en 2026',
    category: 'Scholarships',
    status: 'draft',
    author: 'KPB Editorial',
  },
];

export const forumCategories = [
  { label: 'Admissions', status: 'published', order: 1 },
  { label: 'Bourses', status: 'published', order: 2 },
];

export const forumTags = [
  { label: 'Canada', status: 'published' },
  { label: 'Campus France', status: 'published' },
];

export const moderationQueue = [
  {
    subject: 'Potential misinformation about visa timelines',
    target: 'forum_post',
    reports: 2,
    action: 'review_pending',
  },
];

export const notificationTemplates = [
  {
    name: 'Missing documents reminder',
    channels: 'Push / In-app / Email',
    critical: 'Yes',
  },
  {
    name: 'Orientation webinar',
    channels: 'Push / Email',
    critical: 'No',
  },
];

export const notificationCampaigns = [
  {
    name: 'Cases missing docs - April batch',
    audience: 'case_status',
    channels: 'Push / In-app / Email',
    status: 'scheduled',
    scheduledFor: '2026-04-08 08:00',
  },
  {
    name: 'Orientation webinar invite',
    audience: 'all_students',
    channels: 'Push / Email',
    status: 'completed',
    scheduledFor: 'Sent',
  },
];

export const notificationDeliveries = [
  {
    recipient: 'Aissatou Ibrahim',
    channel: 'push',
    status: 'queued',
  },
  {
    recipient: 'Kwame Mensah',
    channel: 'email',
    status: 'delivered',
  },
];

export const adminUsers = [
  {
    name: 'Amina KPB',
    role: 'counselor',
    languages: 'FR / EN',
    activeCases: 18,
    status: 'active',
  },
  {
    name: 'Moussa KPB',
    role: 'content_manager',
    languages: 'FR',
    activeCases: 7,
    status: 'active',
  },
  {
    name: 'Fatou Admin',
    role: 'admin',
    languages: 'FR / EN',
    activeCases: 12,
    status: 'active',
  },
];

export const reportFunnel = [
  ['Leads', '520'],
  ['Qualified cases', '188'],
  ['Premium support', '74'],
  ['Applications submitted', '39'],
  ['Admissions received', '16'],
];

export const counselorPerformance = [
  ['Amina KPB', '18 active', '1.8h avg response'],
  ['Moussa KPB', '11 active', '2.9h avg response'],
];

export const campaignPerformance = [
  ['Orientation webinar invite', '420 delivered', '210 opened'],
  ['Cases missing docs - April batch', '64 delivered', '33 opened'],
];
