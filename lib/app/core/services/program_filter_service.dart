import '../controllers/app_controller.dart';
import '../models/app_models.dart';
import '../utils/study_level.dart';
import '../utils/tuition_utils.dart';

/// M6 filter criteria for the university program catalog.
class ProgramFilterState {
  const ProgramFilterState({
    this.query = '',
    this.countryId,
    this.budgetMaxEur = 30000,
    this.levelKey,
    this.fieldId,
    this.languageKey,
    this.partnerOnly = true,
  });

  final String query;
  final String? countryId;
  final double budgetMaxEur;
  final String? levelKey;
  final String? fieldId;
  final String? languageKey;
  final bool partnerOnly;

  ProgramFilterState copyWith({
    String? query,
    String? countryId,
    bool clearCountryId = false,
    double? budgetMaxEur,
    String? levelKey,
    bool clearLevelKey = false,
    String? fieldId,
    bool clearFieldId = false,
    String? languageKey,
    bool clearLanguageKey = false,
    bool? partnerOnly,
  }) {
    return ProgramFilterState(
      query: query ?? this.query,
      countryId: clearCountryId ? null : (countryId ?? this.countryId),
      budgetMaxEur: budgetMaxEur ?? this.budgetMaxEur,
      levelKey: clearLevelKey ? null : (levelKey ?? this.levelKey),
      fieldId: clearFieldId ? null : (fieldId ?? this.fieldId),
      languageKey: clearLanguageKey ? null : (languageKey ?? this.languageKey),
      partnerOnly: partnerOnly ?? this.partnerOnly,
    );
  }

  bool get hasActiveFilters =>
      query.trim().isNotEmpty ||
      countryId != null ||
      budgetMaxEur < 30000 ||
      levelKey != null ||
      fieldId != null ||
      languageKey != null;
}

const programLevelFilters = <({String key, String labelFr})>[
  (key: 'bachelor', labelFr: 'Bachelor'),
  (key: 'master', labelFr: 'Master'),
  (key: 'mba', labelFr: 'MBA / DBA'),
  (key: 'doctorate', labelFr: 'Doctorat'),
  (key: 'other', labelFr: 'Autre'),
];

const programLanguageFilters = <({String key, String labelFr})>[
  (key: 'fr', labelFr: 'Français'),
  (key: 'en', labelFr: 'Anglais'),
  (key: 'de', labelFr: 'Allemand'),
  (key: 'es', labelFr: 'Espagnol'),
  (key: 'tr', labelFr: 'Turc'),
  (key: 'ar', labelFr: 'Arabe'),
];

abstract final class ProgramFilterService {
  static List<ProgramModel> apply(
    List<ProgramModel> programs,
    ProgramFilterState filters,
    AppController controller,
  ) {
    final query = filters.query.trim().toLowerCase();

    final filtered = programs.where((program) {
      final institution =
          controller.institutionByIdOrNull(program.institutionId);
      final isPartner = institution?.isPartner ?? false;

      if (filters.partnerOnly && !isPartner) return false;

      if (filters.countryId != null &&
          program.countryId.toLowerCase() != filters.countryId!.toLowerCase()) {
        return false;
      }

      if (filters.fieldId != null && program.fieldId != filters.fieldId) {
        return false;
      }

      if (filters.levelKey != null &&
          !_matchesLevel(
            filters.levelKey!,
            controller.resolve(program.level),
          )) {
        return false;
      }

      if (filters.languageKey != null &&
          !_matchesLanguage(
            filters.languageKey!,
            controller.resolve(program.language),
          )) {
        return false;
      }

      final tuitionEur =
          TuitionUtils.parseEurAnnual(controller.resolve(program.tuition));
      if (tuitionEur != null && tuitionEur > filters.budgetMaxEur.round()) {
        return false;
      }

      if (query.isEmpty) return true;
      final haystack = [
        controller.resolve(program.name),
        controller.resolve(program.level),
        institution != null ? controller.resolve(institution.name) : '',
        program.fieldId,
        program.countryId,
      ].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();

    filtered.sort((a, b) {
      bool isPartner(ProgramModel p) =>
          controller.institutionByIdOrNull(p.institutionId)?.isPartner ?? false;

      final partnerCmp = (isPartner(a) ? 0 : 1).compareTo(isPartner(b) ? 0 : 1);
      if (partnerCmp != 0) return partnerCmp;

      final tuitionA = TuitionUtils.parseEurAnnual(
            controller.resolve(a.tuition),
          ) ??
          999999;
      final tuitionB = TuitionUtils.parseEurAnnual(
            controller.resolve(b.tuition),
          ) ??
          999999;
      final budgetCmp = tuitionA.compareTo(tuitionB);
      if (budgetCmp != 0) return budgetCmp;

      return controller
          .resolve(a.name)
          .toLowerCase()
          .compareTo(controller.resolve(b.name).toLowerCase());
    });

    return filtered;
  }

  /// Matches the selected filter family against the program's level using the
  /// canonical normalizer (single source of truth in `study_level.dart`).
  static bool _matchesLevel(String key, String levelText) {
    return normalizeProgramLevel(levelText).filterKey == key;
  }

  static bool _matchesLanguage(String key, String languageText) {
    final normalized = languageText.toLowerCase();
    switch (key) {
      case 'fr':
        return normalized.contains('fr') ||
            normalized.contains('français') ||
            normalized.contains('french');
      case 'en':
        return normalized.contains('en') ||
            normalized.contains('anglais') ||
            normalized.contains('english');
      case 'de':
        return normalized.contains('de') ||
            normalized.contains('allemand') ||
            normalized.contains('german');
      case 'es':
        return normalized.contains('es') ||
            normalized.contains('espagnol') ||
            normalized.contains('spanish');
      case 'tr':
        return normalized.contains('tr') ||
            normalized.contains('turc') ||
            normalized.contains('turkish');
      case 'ar':
        return normalized.contains('ar') ||
            normalized.contains('arabe') ||
            normalized.contains('arabic');
      default:
        return true;
    }
  }
}
