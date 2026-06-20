import '../../core/models/app_models.dart';
import '../../core/utils/study_level.dart';

/// Clean, canonical student-level labels (Terminale · Bachelor 1/2/3 ·
/// Master 1/2 · Doctorat). Single source of truth lives in `study_level.dart`.
final List<String> onboardingStudyLevels = studentLevelLabels;

const onboardingBacSeries = <String>[
  'A',
  'A1',
  'A4',
  'A8',
  'B',
  'C',
  'D',
  'E',
  'F',
  'F1',
  'F2',
  'F3',
  'F4',
  'G',
  'G1',
  'G2',
  'PRO',
  'Tech',
  'Autre',
];

class OnboardingDestination {
  const OnboardingDestination({
    required this.id,
    required this.labelFr,
    required this.flag,
  });

  final String id;
  final String labelFr;
  final String flag;
}

const onboardingDestinations = <OnboardingDestination>[
  OnboardingDestination(id: 'fra', labelFr: 'France', flag: '🇫🇷'),
  OnboardingDestination(id: 'deu', labelFr: 'Allemagne', flag: '🇩🇪'),
  OnboardingDestination(id: 'usa', labelFr: 'États-Unis', flag: '🇺🇸'),
  OnboardingDestination(id: 'can', labelFr: 'Canada', flag: '🇨🇦'),
  OnboardingDestination(id: 'mar', labelFr: 'Maroc', flag: '🇲🇦'),
  OnboardingDestination(id: 'tur', labelFr: 'Turquie', flag: '🇹🇷'),
  OnboardingDestination(id: 'are', labelFr: 'EAU (Dubaï)', flag: '🇦🇪'),
  OnboardingDestination(id: 'gbr', labelFr: 'Royaume-Uni', flag: '🇬🇧'),
  OnboardingDestination(id: 'esp', labelFr: 'Espagne', flag: '🇪🇸'),
];

const onboardingAccountTypes = <AccountType>[
  AccountType.student,
  AccountType.parent,
  AccountType.partner,
];

String onboardingAccountLabel(AccountType type) {
  switch (type) {
    case AccountType.student:
      return 'Étudiant';
    case AccountType.parent:
      return 'Parent d\'élève';
    case AccountType.partner:
      return 'Partenaire (école / agence)';
    case AccountType.commercial:
      return 'Commercial KPB';
  }
}

bool studyLevelNeedsBacSeries(String level) =>
    normalizeStudentLevel(level)?.needsBacSeries ?? false;
