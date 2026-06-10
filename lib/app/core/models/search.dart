part of 'app_models.dart';


enum SearchResultType { field, country, institution, program, scholarship }
class SearchResult {
  const SearchResult({
    required this.type,
    required this.id,
    required this.title,
    required this.subtitle,
  });
  final SearchResultType type;
  final String id;
  final String title;
  final String subtitle;
}
