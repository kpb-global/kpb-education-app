import '../models/app_models.dart';

/// Maps `/matches/*` JSON to [SchoolMatch] (see docs/api-contracts.md,
/// "Matches" section, and the backend `matches` module).
abstract final class MatchApiCodec {
  static SchoolMatch schoolMatchFromApi(Map<String, dynamic> json) {
    final institutionId = json['institutionId'] as String?;
    final programId = json['programId'] as String?;
    if (institutionId == null || programId == null) {
      throw const FormatException(
        'Match payload is missing "institutionId" or "programId".',
      );
    }
    return SchoolMatch(
      institutionId: institutionId,
      institutionName: _localized(json['institutionName']),
      programId: programId,
      programName: _localized(json['programName']),
      probability: (json['probability'] as num?)?.toDouble() ?? 0,
      zone: switch (json['zone'] as String?) {
        'green' => SchoolMatchZone.green,
        'blue' => SchoolMatchZone.blue,
        _ => SchoolMatchZone.yellow,
      },
      isEstimate: json['isEstimate'] as bool? ?? false,
      algorithmVersion: json['algorithmVersion'] as String? ?? 'v1',
      factors: _factors(json['factors']),
      narrative: _localized(json['narrative']),
    );
  }

  /// Parses the `GET /matches/aha-moment` envelope
  /// (`{items: [...], isEstimate: bool}`). Malformed items are dropped rather
  /// than failing the whole reveal.
  static List<SchoolMatch> ahaMatchesFromApi(Map<String, dynamic> json) {
    final rawItems = json['items'];
    if (rawItems is! List<dynamic>) return const <SchoolMatch>[];
    final items = <SchoolMatch>[];
    for (final raw in rawItems) {
      if (raw is! Map<String, dynamic>) continue;
      try {
        items.add(schoolMatchFromApi(raw));
      } on FormatException {
        continue;
      }
    }
    return items;
  }

  static LocalizedText _localized(Object? raw) {
    if (raw is Map<String, dynamic>) return LocalizedText.fromJson(raw);
    return const LocalizedText(fr: '', en: '');
  }

  static List<MatchFactorResult> _factors(Object? raw) {
    if (raw is! List<dynamic>) return const <MatchFactorResult>[];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(
          (f) => MatchFactorResult(
            name: f['name'] as String? ?? '',
            weight: (f['weight'] as num?)?.toDouble() ?? 0,
            score: (f['score'] as num?)?.toDouble() ?? 0,
            isEstimate: f['isEstimate'] as bool? ?? false,
          ),
        )
        .toList();
  }
}
