import '../models/app_models.dart';

class RoadmapEngine {
  static List<RoadmapStepModel> getSteps() {
    return const [
      RoadmapStepModel(
        type: RoadmapStepType.audit,
        title: LocalizedText(fr: 'Initialisation \u0026 Audit Dossier', en: 'Initialization \u0026 Document Audit'),
        description: LocalizedText(
          fr: 'Rassemblez vos documents d\'identité, diplômes et relevés de notes.',
          en: 'Gather your ID, degrees, and academic transcripts.',
        ),
        daysBeforeDeadline: 60,
      ),
      RoadmapStepModel(
        type: RoadmapStepType.language,
        title: LocalizedText(fr: 'Certification de Langue', en: 'Language Certification'),
        description: LocalizedText(
          fr: 'Passez le TOEFL, IELTS ou TCF si nécessaire pour cette destination.',
          en: 'Take TOEFL, IELTS, or TCF if required for this destination.',
        ),
        daysBeforeDeadline: 45,
      ),
      RoadmapStepModel(
        type: RoadmapStepType.writing,
        title: LocalizedText(fr: 'Rédaction Stratégique', en: 'Strategic Writing'),
        description: LocalizedText(
          fr: 'Rédigez votre lettre de motivation (Personal Statement) avec nos tutoriels.',
          en: 'Write your Personal Statement using our tutorials.',
        ),
        daysBeforeDeadline: 30,
        actionRoute: '/academy', // Deep link to Academy
      ),
      RoadmapStepModel(
        type: RoadmapStepType.review,
        title: LocalizedText(fr: 'Revue Finale Expert', en: 'Final Expert Review'),
        description: LocalizedText(
          fr: 'Faites relire votre dossier par un expert KPB pour maximiser vos chances.',
          en: 'Have your application reviewed by a KPB expert to maximize your chances.',
        ),
        daysBeforeDeadline: 15,
        actionRoute: '/consultation', // Deep link to Consultation
      ),
      RoadmapStepModel(
        type: RoadmapStepType.submission,
        title: LocalizedText(fr: 'Soumission Officielle', en: 'Official Submission'),
        description: LocalizedText(
          fr: 'Vérifiez une dernière fois et soumettez votre candidature.',
          en: 'Final check and submit your application.',
        ),
        daysBeforeDeadline: 0,
      ),
    ];
  }

  static DateTime calculateDate(DateTime deadline, int daysBefore) {
    return deadline.subtract(Duration(days: daysBefore));
  }
}
