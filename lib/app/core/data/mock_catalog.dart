// KPB Education catalog facade.
// Static seed content lives in mock_catalog/*.dart, split per domain.
// ignore_for_file: lines_longer_than_80_chars
import '../models/app_models.dart';

import 'mock_catalog/orientation_data.dart';
import 'mock_catalog/fields_data.dart';
import 'mock_catalog/countries_data.dart';
import 'mock_catalog/institutions_data.dart';
import 'mock_catalog/programs_data.dart';
import 'mock_catalog/services_data.dart';
import 'mock_catalog/community_data.dart';
import 'mock_catalog/academy_data.dart';

class MockCatalog {
  static const orientationQuestions = kOrientationQuestions;
  static const fields = kFields;
  static const countries = kCountries;
  static const institutions = kInstitutions;
  static const programs = kPrograms;
  static const scholarships = <ScholarshipModel>[];
  static const serviceOffers = kServiceOffers;
  static const supportDestinations = kSupportDestinations;
  static final articles = kArticles;
  static const forumCategories = kForumCategories;
  static const forumTopicTags = kForumTopicTags;
  static const academyCourses = kAcademyCourses;
  static const academyLessons = kAcademyLessons;

  static List<StudentCase> starterCases() {
    final now = DateTime.now();
    return [
      StudentCase(
        id: 'case-1',
        referenceCode: 'KPB-2026-001',
        type: CaseType.consultation,
        title: const LocalizedText(
            fr: 'Consultation orientation Canada',
            en: 'Canada orientation consultation'),
        description: const LocalizedText(
          fr: 'Premier échange pour clarifier le projet d\'études, le niveau cible et les options de bourses.',
          en: 'Initial consultation to clarify the study plan, target level, and scholarship options.',
        ),
        contextLabel: const LocalizedText(
            fr: 'Canada • orientation + admission',
            en: 'Canada • orientation + admission'),
        status: CaseStatus.counselorAssigned,
        preferredContactMethod: ContactMethod.inApp,
        createdAt: now.subtract(const Duration(days: 3)),
        updatedAt: now.subtract(const Duration(hours: 6)),
        assignedAdvisorName: 'Amina KPB',
        nextStepTitle: const LocalizedText(
            fr: 'Préparer votre entretien',
            en: 'Prepare for your consultation'),
        nextStepDescription: const LocalizedText(
          fr: 'Complétez votre profil académique et confirmez votre disponibilité pour mardi 16h.',
          en: 'Complete your academic profile and confirm availability for Tuesday at 4 PM.',
        ),
        timeline: [
          CaseTimelineEvent(
            id: 'evt-1',
            title: const LocalizedText(
                fr: 'Demande reçue', en: 'Request received'),
            description: const LocalizedText(
                fr: 'Votre demande a bien été enregistrée.',
                en: 'Your request has been recorded.'),
            createdAt: now.subtract(const Duration(days: 3)),
            status: CaseStatus.submitted,
          ),
          CaseTimelineEvent(
            id: 'evt-2',
            title: const LocalizedText(
                fr: 'Conseillère assignée', en: 'Counselor assigned'),
            description: const LocalizedText(
                fr: 'Amina suit votre dossier.',
                en: 'Amina is handling your case.'),
            createdAt: now.subtract(const Duration(hours: 6)),
            status: CaseStatus.counselorAssigned,
          ),
        ],
        messages: [
          CaseMessage(
            id: 'msg-1',
            senderName: 'Amina KPB',
            senderRole: 'counselor',
            body: const LocalizedText(
              fr: 'Bonjour, je suis votre conseillère. Pouvez-vous confirmer votre niveau actuel et votre pays cible principal ?',
              en: 'Hello, I am your counselor. Can you confirm your current level and primary target country?',
            ),
            createdAt: now.subtract(const Duration(hours: 5)),
          ),
        ],
        documentRequests: const [
          DocumentRequest(
              id: 'doc-1',
              title: LocalizedText(
                  fr: 'Relevés de notes récents', en: 'Recent transcripts'),
              isProvided: false),
          DocumentRequest(
              id: 'doc-2',
              title: LocalizedText(
                  fr: 'Passeport ou pièce d\'identité', en: 'Passport or ID'),
              isProvided: true),
        ],
      ),
    ];
  }
}
