import '../repositories/app_api_client.dart';

enum AiContentSurface {
  coach,
  orientation,
}

abstract final class AiContentReportReason {
  static const inaccurate = 'inaccurate_or_misleading';
  static const unsafe = 'unsafe_or_harmful';
  static const offensive = 'offensive_or_biased';
  static const privacy = 'privacy_concern';
  static const other = 'other';

  static const values = <String>{
    inaccurate,
    unsafe,
    offensive,
    privacy,
    other,
  };
}

class AiContentReportReceipt {
  const AiContentReportReceipt({
    required this.caseId,
    required this.referenceCode,
  });

  final String caseId;
  final String referenceCode;
}

/// Persists a student report through the authenticated case-review workflow.
///
/// Cases are already visible to the authorised KPB operations team and have a
/// durable status/timeline. Reusing that production path makes an AI report
/// actionable immediately without creating a second, unstaffed moderation
/// queue. The generated excerpt and optional note are deliberately bounded so
/// the backend's 2,000-character case-description contract cannot be exceeded.
class AiContentReportService {
  AiContentReportService({AppApiClient? apiClient})
      : _apiClient = apiClient ?? AppApiClient();

  final AppApiClient _apiClient;

  static const maxGeneratedExcerptLength = 1200;
  static const maxReporterNoteLength = 400;

  Future<AiContentReportReceipt> submit({
    required AiContentSurface surface,
    required String generatedText,
    required String reason,
    String? sourceReference,
    String? reporterNote,
  }) async {
    final excerpt = _bounded(generatedText, maxGeneratedExcerptLength);
    if (excerpt.isEmpty) {
      throw ArgumentError.value(
        generatedText,
        'generatedText',
        'A generated-content report needs a non-empty excerpt.',
      );
    }
    if (!AiContentReportReason.values.contains(reason)) {
      throw ArgumentError.value(reason, 'reason', 'Unknown report reason.');
    }

    final reference = _bounded(sourceReference ?? '', 120);
    final note = _bounded(reporterNote ?? '', maxReporterNoteLength);
    final description = <String>[
      'TRUST_AND_SAFETY_REPORT',
      'Surface: ${surface.name}',
      'Reason: $reason',
      if (reference.isNotEmpty) 'Source reference: $reference',
      if (note.isNotEmpty) 'Reporter note: $note',
      'Generated content:',
      excerpt,
    ].join('\n');

    final response = await _apiClient.createCase(<String, dynamic>{
      'type': 'consultation',
      'title': 'AI content report — ${surface.name}',
      'description': description,
      'contextLabel': 'Trust & Safety · Generated AI · ${surface.name}',
      'preferredContactMethod': 'in_app',
    });

    final caseId = response['id'] as String? ?? '';
    final referenceCode = response['referenceCode'] as String? ?? '';
    if (caseId.isEmpty || referenceCode.isEmpty) {
      throw StateError('The report backend returned no durable case receipt.');
    }
    return AiContentReportReceipt(
      caseId: caseId,
      referenceCode: referenceCode,
    );
  }

  static String _bounded(String value, int maxLength) {
    final cleaned = value
        .replaceAll(RegExp(r'[\u0000-\u0008\u000B\u000C\u000E-\u001F]'), ' ')
        .trim();
    if (cleaned.length <= maxLength) return cleaned;
    return '${cleaned.substring(0, maxLength - 1)}…';
  }
}
