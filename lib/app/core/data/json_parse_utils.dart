/// Shared JSON helpers for API / snapshot parsing.
List<String> stringListFromJson(Object? raw) {
  if (raw is List<dynamic>) {
    return raw.whereType<String>().toList();
  }
  return const <String>[];
}
