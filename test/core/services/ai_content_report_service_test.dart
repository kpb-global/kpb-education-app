import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:karatou/app/core/repositories/app_api_client.dart';
import 'package:karatou/app/core/services/ai_content_report_service.dart';

class _MockAppApiClient extends Mock implements AppApiClient {}

void main() {
  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  late _MockAppApiClient apiClient;
  late AiContentReportService service;

  setUp(() {
    apiClient = _MockAppApiClient();
    service = AiContentReportService(apiClient: apiClient);
  });

  test('persists a bounded, staff-reviewable case and returns its receipt',
      () async {
    when(() => apiClient.createCase(any())).thenAnswer(
      (_) async => <String, dynamic>{
        'id': 'case-report-1',
        'referenceCode': 'KPB-2026-0049',
      },
    );

    final receipt = await service.submit(
      surface: AiContentSurface.coach,
      generatedText: '${List.filled(1400, 'x').join()}\u0001',
      reason: AiContentReportReason.inaccurate,
      sourceReference: 'conversation-42',
      reporterNote: 'The school deadline is wrong.',
    );

    expect(receipt.caseId, 'case-report-1');
    expect(receipt.referenceCode, 'KPB-2026-0049');
    final payload = verify(() => apiClient.createCase(captureAny()))
        .captured
        .single as Map<String, dynamic>;
    expect(payload['type'], 'consultation');
    expect(payload['preferredContactMethod'], 'in_app');
    expect(payload['contextLabel'], contains('Trust & Safety'));
    final description = payload['description'] as String;
    expect(description, startsWith('TRUST_AND_SAFETY_REPORT\n'));
    expect(description, contains('Surface: coach'));
    expect(description, contains('Reason: inaccurate_or_misleading'));
    expect(description, contains('Source reference: conversation-42'));
    expect(
        description, contains('Reporter note: The school deadline is wrong.'));
    expect(description.length, lessThanOrEqualTo(2000));
    expect(description, isNot(contains('\u0001')));
  });

  test('rejects an unknown reason before making a network request', () async {
    await expectLater(
      service.submit(
        surface: AiContentSurface.orientation,
        generatedText: 'Generated recommendation',
        reason: 'unreviewed_free_text',
      ),
      throwsArgumentError,
    );
    verifyNever(() => apiClient.createCase(any()));
  });

  test('does not claim success without a durable backend receipt', () async {
    when(() => apiClient.createCase(any()))
        .thenAnswer((_) async => <String, dynamic>{});

    await expectLater(
      service.submit(
        surface: AiContentSurface.orientation,
        generatedText: 'Generated recommendation',
        reason: AiContentReportReason.privacy,
      ),
      throwsStateError,
    );
  });
}
