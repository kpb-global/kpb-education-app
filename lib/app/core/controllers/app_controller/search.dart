part of '../app_controller.dart';

mixin _SearchMixin on _AppControllerBase {
  AppSearchContext get _searchContext => AppSearchContext(
        localeCode: localeCode,
        fields: fields,
        countries: countries,
        institutions: institutions,
        programs: programs,
        scholarships: scholarships,
        profile: profile,
        latestOrientationSession: latestOrientationSession,
      );

  AppSearchService get _searchService => AppSearchService(_searchContext);

  /// Best-matching program in [countryId] for the current profile, ranked by
  /// the shared search scorer. Replaces the old France/ECE-Lyon-only stub so
  /// the eligibility-quiz CTA recommends a real program for all 9 destinations.
  /// Returns null when the catalog has no program for that country.
  ProgramModel? topProgramForCountry(String countryId) {
    final norm = normalizeCountryId(countryId);
    final svc = _searchService;
    ProgramModel? best;
    var bestScore = -1;
    for (final program in programs) {
      if (normalizeCountryId(program.countryId) != norm) continue;
      final score = svc.programMatch(program);
      if (score > bestScore) {
        bestScore = score;
        best = program;
      }
    }
    return best;
  }

  void addSearchQuery(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    _searchHistory.remove(trimmed);
    _searchHistory.insert(0, trimmed);
    if (_searchHistory.length > 10) _searchHistory.removeLast();
    _persist();
    AnalyticsService.instance.logSearch(trimmed);
  }

  void clearSearchHistory() {
    _searchHistory.clear();
    _persist();
    update();
  }

  List<SearchResult> search(String query) => _searchService.run(query);

  int fieldMatch(FieldModel field) => _searchService.fieldMatch(field);

  int programMatch(ProgramModel program) =>
      _searchService.programMatch(program);

  int institutionMatch(InstitutionModel institution) =>
      _searchService.institutionMatch(institution);

  List<FieldModel> get recommendedFields => _searchService.recommendedFields;

  List<ProgramModel> get recommendedPrograms =>
      _searchService.recommendedPrograms;

  List<InstitutionModel> get recommendedInstitutions =>
      _searchService.recommendedInstitutions;

  List<String> matchExplanation(SearchResultType type, String id) =>
      _searchService.matchExplanation(type, id);

  List<ScholarshipModel> get recommendedScholarships =>
      _searchService.recommendedScholarships;

  int scholarshipMatch(ScholarshipModel scholarship) =>
      _searchService.scholarshipMatch(scholarship);
}
