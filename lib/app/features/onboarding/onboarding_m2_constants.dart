import 'package:get/get.dart';
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

// ─────────────────────────────────────────────────────────────────────────────
// Les quatre listes que l'onboarding gardait pour lui
//
// Elles vivaient en `const _privé` dans onboarding_screen.dart, et c'est
// exactement pourquoi l'écran de profil ne pouvait pas offrir ces champs : les
// rouvrir à l'édition aurait demandé de recopier les listes, donc de créer une
// seconde vérité. Le dépôt a déjà payé ce prix une fois — `currentLevel` est
// écrit « High school » par l'onboarding et « Terminale » par le profil, si
// bien que rejouer l'onboarding après une modification de profil rétrograde
// silencieusement le niveau.
//
// Forme `(jeton, libellé)` : le JETON est ce qui est persisté et envoyé au
// serveur, le LIBELLÉ est ce qu'on affiche. Les deux écrans doivent stocker le
// jeton et n'afficher que le libellé — voir [targetLevelLabel] et
// [languageLevelLabel], qui existent parce que l'écran de profil affichait le
// jeton brut (« Bachelor », « Intermediate ») dans une interface française.
// ─────────────────────────────────────────────────────────────────────────────

const onboardingTargetLevels = <(String, String)>[
  ('Bachelor', 'Licence'),
  ('Master', 'Master'),
  ('PhD', 'Doctorat'),
];

const onboardingLanguageLevels = <(String, String)>[
  ('Beginner', 'Débutant'),
  ('Intermediate', 'Intermédiaire'),
  ('Advanced', 'Avancé'),
];

/// Fourchettes de moyenne. Pas de jeton séparé : la valeur EST le libellé.
const onboardingGradeRanges = <String>[
  '10 - 12/20',
  '12 - 14/20',
  '15+/20',
];

/// Annual tuition-budget ranges in EUR. The selected display currency only
/// changes the presentation; matching remains on this canonical EUR value.
const onboardingBudgetRanges = <(int, String)>[
  (4000, '< 5 000 €'),
  (7500, '5 000 – 10 000 €'),
  (15000, '10 000 – 20 000 €'),
  (25000, '> 20 000 €'),
];

/// Le libellé français d'un niveau visé ; rend le jeton tel quel s'il est
/// inconnu — un profil ancien ne doit pas afficher du vide.
String targetLevelLabel(String? token) =>
    _labelFor(onboardingTargetLevels, token);

/// Idem pour le niveau de langue.
String languageLevelLabel(String? token) =>
    _labelFor(onboardingLanguageLevels, token);

String _labelFor(List<(String, String)> table, String? token) {
  if (token == null || token.trim().isEmpty) return '';
  for (final entry in table) {
    if (entry.$1 == token) return entry.$2;
  }
  // Déjà un libellé français (profil édité par une version qui stockait le
  // libellé), ou une valeur qu'on ne connaît pas : on la rend telle quelle
  // plutôt que d'effacer une information réelle.
  return token;
}

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
      return 'account_type_student'.tr;
    case AccountType.parent:
      return 'account_type_parent'.tr;
    case AccountType.partner:
      return 'account_type_partner'.tr;
    case AccountType.commercial:
      return 'account_type_commercial'.tr;
  }
}

bool studyLevelNeedsBacSeries(String level) =>
    normalizeStudentLevel(level)?.needsBacSeries ?? false;
