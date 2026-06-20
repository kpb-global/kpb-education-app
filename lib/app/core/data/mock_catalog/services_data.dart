// AUTO-GENERATED — KPB Education catalog seed data.
// ignore_for_file: lines_longer_than_80_chars
import '../../models/app_models.dart';

const kServiceOffers = <ServiceOffer>[
    ServiceOffer(
      id: 'offer-application-pack',
      name: LocalizedText(
          fr: 'Pack admission guidée', en: 'Guided application pack'),
      offerType: 'application_support',
      destinationIds: ['canada', 'france', 'uk', 'morocco', 'turkey'],
      studyLevels: ['Bac+3', 'Bac+5'],
      priceLabel: LocalizedText(fr: 'Sur devis', en: 'Quoted on request'),
      benefits: [
        LocalizedText(
            fr: 'Qualification du profil et shortlist',
            en: 'Profile qualification and shortlist'),
        LocalizedText(
            fr: 'Support documents et suivi KPB',
            en: 'Document support and KPB follow-up'),
        LocalizedText(
            fr: 'Accès prioritaire aux partenaires KPB',
            en: 'Priority access to KPB partner schools'),
      ],
      ctaLabel: LocalizedText(
          fr: 'Démarrer ma candidature', en: 'Start my application'),
      status: PublicationStatus.published,
    ),
    ServiceOffer(
      id: 'offer-scholarship-boost',
      name: LocalizedText(fr: 'Boost bourse', en: 'Scholarship boost'),
      offerType: 'scholarship_support',
      destinationIds: ['canada', 'france', 'germany', 'turkey', 'uae'],
      studyLevels: ['Bac+3', 'Bac+5', 'Bac+8'],
      priceLabel:
          LocalizedText(fr: 'À partir de 75 000 FCFA', en: 'From 75,000 XOF'),
      benefits: [
        LocalizedText(
            fr: 'Matching bourses personnalisé',
            en: 'Personalised scholarship matching'),
        LocalizedText(
            fr: 'Stratégie de dossier et suivi',
            en: 'Application strategy and follow-up'),
      ],
      ctaLabel: LocalizedText(
          fr: 'Demander un accompagnement', en: 'Request support'),
      status: PublicationStatus.published,
    ),
  ];


const kSupportDestinations = <SupportDestination>[
    SupportDestination(
      id: 'support-canada',
      countryId: 'canada',
      supportLanguages: ['fr', 'en'],
      availableServiceTypes: [
        'consultation',
        'application_support',
        'scholarship_support'
      ],
      conditions: [
        LocalizedText(
            fr: 'Profil académique complet', en: 'Complete academic profile')
      ],
      counselorNames: ['Amina KPB', 'Youssef KPB'],
      isVisible: true,
      status: PublicationStatus.published,
    ),
    SupportDestination(
      id: 'support-france',
      countryId: 'france',
      supportLanguages: ['fr'],
      availableServiceTypes: [
        'consultation',
        'application_support',
        'housing_support'
      ],
      conditions: [
        LocalizedText(
            fr: 'Admission directe via nos écoles partenaires selon programme',
            en: 'Direct admission via partner schools depending on program')
      ],
      counselorNames: ['Moussa KPB'],
      isVisible: true,
      status: PublicationStatus.published,
    ),
    SupportDestination(
      id: 'support-morocco',
      countryId: 'morocco',
      supportLanguages: ['fr', 'ar'],
      availableServiceTypes: ['consultation', 'application_support'],
      conditions: [
        LocalizedText(
            fr: 'Dossier académique complet', en: 'Complete academic file')
      ],
      counselorNames: ['Karim KPB'],
      isVisible: true,
      status: PublicationStatus.published,
    ),
    SupportDestination(
      id: 'support-turkey',
      countryId: 'turkey',
      supportLanguages: ['fr', 'en'],
      availableServiceTypes: [
        'consultation',
        'application_support',
        'scholarship_support'
      ],
      conditions: [
        LocalizedText(fr: 'Profil Bac+0 à Bac+3', en: 'Profile Bac+0 to Bac+3')
      ],
      counselorNames: ['Sara KPB'],
      isVisible: true,
      status: PublicationStatus.published,
    ),
  ];

