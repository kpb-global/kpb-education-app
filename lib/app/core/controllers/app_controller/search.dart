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
