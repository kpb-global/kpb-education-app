/// Returns true when [current] is strictly below [minimum].
///
/// Compares dotted numeric versions ("1.2.3"). Build metadata ("+45") and
/// pre-release suffixes ("-beta") are ignored; missing segments count as 0.
/// Unparseable input returns false — the force-update gate must fail open,
/// never lock users out on a malformed config value.
bool isVersionBelow(String current, String minimum) {
  final currentParts = _parseVersion(current);
  final minimumParts = _parseVersion(minimum);
  if (currentParts == null || minimumParts == null) return false;

  final length = currentParts.length > minimumParts.length
      ? currentParts.length
      : minimumParts.length;
  for (var i = 0; i < length; i++) {
    final c = i < currentParts.length ? currentParts[i] : 0;
    final m = i < minimumParts.length ? minimumParts[i] : 0;
    if (c != m) return c < m;
  }
  return false;
}

List<int>? _parseVersion(String version) {
  final core = version.trim().split('+').first.split('-').first;
  if (core.isEmpty) return null;
  final parts = <int>[];
  for (final segment in core.split('.')) {
    final value = int.tryParse(segment);
    if (value == null) return null;
    parts.add(value);
  }
  return parts;
}
