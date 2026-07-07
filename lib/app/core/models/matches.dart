part of 'app_models.dart';

// ── Admission-probability matches (Phase 0 / P0-D, kit US-003/US-004) ────────
// Server-scored (backend `matches` module, algorithm v1). The local
// AppSearchService affinity score remains the offline fallback; the two are
// bridged in AhaMomentScreen, not here.

enum SchoolMatchZone { green, yellow, blue }

class MatchFactorResult {
  const MatchFactorResult({
    required this.name,
    required this.weight,
    required this.score,
    required this.isEstimate,
  });

  /// 'academic' | 'field' | 'language' | 'budget' | 'timing'.
  final String name;
  final double weight;
  final double score;
  final bool isEstimate;
}

class SchoolMatch {
  const SchoolMatch({
    required this.institutionId,
    required this.institutionName,
    required this.programId,
    required this.programName,
    required this.probability,
    required this.zone,
    required this.isEstimate,
    required this.algorithmVersion,
    required this.factors,
    required this.narrative,
  });

  final String institutionId;
  final LocalizedText institutionName;
  final String programId;
  final LocalizedText programName;

  /// 0..1 — deterministic admission probability (see backend matching.ts).
  final double probability;
  final SchoolMatchZone zone;

  /// True when ≥1 scoring input was missing (profile or catalog side).
  final bool isEstimate;
  final String algorithmVersion;
  final List<MatchFactorResult> factors;
  final LocalizedText narrative;

  int get probabilityPercent => (probability * 100).round();
}
