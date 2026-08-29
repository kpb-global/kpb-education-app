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

/// Le libellé d'un niveau visé DANS LA LANGUE ACTIVE ; rend le jeton tel quel
/// s'il est inconnu — un profil ancien ne doit pas afficher du vide.
String targetLevelLabel(String? token) =>
    _labelFor(onboardingTargetLevels, token);

/// Idem pour le niveau de langue.
String languageLevelLabel(String? token) =>
    _labelFor(onboardingLanguageLevels, token);

/// Rend le libellé de la locale active, jamais le français inconditionnellement.
///
/// La première version rendait toujours `entry.$2`, le libellé français. En
/// anglais elle aurait donc REMPLACÉ des jetons déjà corrects — « Bachelor »,
/// « Intermediate » — par « Licence » et « Intermédiaire », et rendu à moitié
/// française une interface anglaise. Le défaut est aujourd'hui inatteignable
/// (`kShippedLocale = 'fr'`, `kLanguageSwitchVisible = false`), mais le
/// dictionnaire anglais est maintenu et vérifié par `translations_parity_test` :
/// une aide qui ignore la locale est une bombe à retardement posée dans du code
/// qu'on croit bilingue.
///
/// En anglais le JETON EST le libellé (« Bachelor », « Intermediate ») — c'est
/// pourquoi la table n'a que deux colonnes et que ce cas se résout en rendant
/// `entry.$1`.
String _labelFor(List<(String, String)> table, String? token) {
  if (token == null || token.trim().isEmpty) return '';
  final isEnglish = Get.locale?.languageCode == 'en';
  for (final entry in table) {
    if (entry.$1 == token) return isEnglish ? entry.$1 : entry.$2;
    // Un profil édité par une version qui stockait le LIBELLÉ français : on
    // sait alors retrouver le jeton anglais correspondant.
    if (entry.$2 == token) return isEnglish ? entry.$1 : entry.$2;
  }
  // Valeur qu'on ne connaît pas : la rendre telle quelle plutôt qu'effacer une
  // information réelle.
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
