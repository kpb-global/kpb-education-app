import '../controllers/app_controller.dart';
import '../models/app_models.dart';
import 'country_utils.dart';

/// Picks a showcase program for conversion CTAs (Phase 2 E2E — ECE Lyon).
abstract final class ProgramRecommendationUtils {
  static ProgramModel? recommendedProgramForCountry(
    AppController controller,
    String countryId, {
    String? schoolHint,
    String? campusHint,
  }) {
    final normalizedCountry = normalizeCountryId(countryId);
    if (normalizedCountry != 'fra') return null;

    ProgramModel? eceFallback;
    for (final program in controller.programs) {
      if (normalizeCountryId(program.countryId) != 'fra') continue;

      final institution =
          controller.institutionByIdOrNull(program.institutionId);
      final institutionName = institution != null
          ? controller.resolve(institution.name).toLowerCase()
          : '';
      final programName = controller.resolve(program.name).toLowerCase();

      final matchesSchool = schoolHint == null ||
          institutionName.contains(schoolHint.toLowerCase()) ||
          programName.contains(schoolHint.toLowerCase());
      if (!matchesSchool) continue;

      if (schoolHint?.toLowerCase() == 'ece') {
        eceFallback ??= program;
      }

      final matchesCampus = campusHint == null ||
          institutionName.contains(campusHint.toLowerCase()) ||
          programName.contains(campusHint.toLowerCase());
      if (!matchesCampus) continue;

      return program;
    }

    return eceFallback;
  }

  /// Default Phase 2 demo target: first ECE Lyon bachelor program found.
  static ProgramModel? recommendedEceLyonProgram(AppController controller) {
    return recommendedProgramForCountry(
      controller,
      'fra',
      schoolHint: 'ece',
      campusHint: 'lyon',
    );
  }
}
