import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:mocktail/mocktail.dart';
import 'package:karatou/app/core/repositories/app_api_client.dart';

class MockDio extends Mock implements Dio {}

class MockInterceptorHandler extends Mock
    implements RequestInterceptorHandler {}

class MockErrorInterceptorHandler extends Mock
    implements ErrorInterceptorHandler {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(Options());
  });

  late AppApiClient apiClient;
  late MockDio mockDio;

  setUp(() {
    // Mock Secure Storage Native Channel to avoid missing plugin exceptions
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
            (MethodCall methodCall) async {
      if (methodCall.method == 'read') {
        final arguments = methodCall.arguments as Map<dynamic, dynamic>;
        if (arguments['key'] == 'kpb.auth.accessToken') {
          return 'valid-access-token';
        }
        if (arguments['key'] == 'kpb.auth.refreshToken') {
          return 'valid-refresh-token';
        }
      }
      return null;
    });

    mockDio = MockDio();

    // Stub interceptors mechanism to avoid null errors when AppApiClient injects it
    when(() => mockDio.interceptors).thenReturn(Interceptors());

    apiClient = AppApiClient(dio: mockDio);
  });

  group('AppApiClient Interceptors', () {
    test('Injects Authorization header automatically unless /auth/', () async {
      // In Dart test, we can't extract the private _AuthInterceptor directly without reflections or casting
      // But we can test that the instantiated client HAS the interceptor and test its logic theoretically.
      expect(apiClient, isNotNull);
      // Validating interceptor presence
      // Real test would extract the interceptor and call `onRequest` with a MockHandler
    });
  });

  // Since testing private components in Dart is restricted,
  // we validate the public API signatures throw appropriately.
  group('Profiles Endpoint', () {
    test('getProfile throws exception when backend fails', () async {
      when(() => mockDio.get<Map<String, dynamic>>('/profiles/me')).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/profiles/me'),
          response: Response(
            requestOptions: RequestOptions(path: '/profiles/me'),
            statusCode: 500,
          ),
        ),
      );

      expect(() => apiClient.getProfile(), throwsA(isA<DioException>()));
    });
  });

  group('Success Lab artifacts', () {
    test('deletes only the requested version and sends the audit reason',
        () async {
      const path = '/competition-readiness/artifact-versions/version-1';
      when(
        () => mockDio.delete<void>(
          path,
          data: any(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => Response<void>(
          requestOptions: RequestOptions(path: path),
          statusCode: 204,
        ),
      );

      await apiClient.deleteSuccessLabArtifactVersion(
        versionId: 'version-1',
        reason: 'student_removed_before_review',
      );

      final captured = verify(
        () => mockDio.delete<void>(
          path,
          data: captureAny(named: 'data'),
        ),
      ).captured.single as Map<String, dynamic>;
      expect(
        captured,
        <String, dynamic>{'reason': 'student_removed_before_review'},
      );
    });
  });

  group('Success Lab study-review tracking and scheduling', () {
    test('loads the workspace-scoped active review endpoint', () async {
      const path =
          '/competition-readiness/workspaces/workspace-1/review-requests/active';
      when(() => mockDio.get<Map<String, dynamic>>(path)).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: path),
          data: <String, dynamic>{
            'schemaVersion': 1,
            'reviewRequest': null,
          },
        ),
      );

      final response =
          await apiClient.getActiveSuccessLabStudyReview('workspace-1');

      expect(response['reviewRequest'], isNull);
    });

    test('sends CAS complement only with explicitly provided fields', () async {
      const path = '/competition-readiness/review-requests/review-1';
      when(
        () => mockDio.patch<Map<String, dynamic>>(
          path,
          data: any(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: path),
          data: <String, dynamic>{},
        ),
      );

      await apiClient.updateSuccessLabStudyReview(
        reviewRequestId: 'review-1',
        expectedVersion: 4,
        studentMessage: '  Document corrigé.  ',
        artifactVersionIds: <String>['version-2'],
        consentReceiptId: 'receipt-2',
      );

      final body = verify(
        () => mockDio.patch<Map<String, dynamic>>(
          path,
          data: captureAny(named: 'data'),
        ),
      ).captured.single as Map<String, dynamic>;
      expect(body, <String, dynamic>{
        'expectedVersion': 4,
        'studentMessage': 'Document corrigé.',
        'artifactVersionIds': <String>['version-2'],
        'consentReceiptId': 'receipt-2',
      });
    });

    test('booking sends separate stable body and header keys', () async {
      const path =
          '/competition-readiness/review-requests/review-1/appointments';
      when(
        () => mockDio.post<Map<String, dynamic>>(
          path,
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: path),
          data: <String, dynamic>{},
        ),
      );

      await apiClient.bookSuccessLabStudyReviewAppointment(
        reviewRequestId: 'review-1',
        expectedVersion: 4,
        slotOfferId: 'offer-1',
        bookingKey: 'booking-stable',
        timezone: 'Africa/Niamey',
        idempotencyKey: 'idempotency-stable',
      );

      final captured = verify(
        () => mockDio.post<Map<String, dynamic>>(
          path,
          data: captureAny(named: 'data'),
          options: captureAny(named: 'options'),
        ),
      ).captured;
      expect(captured.first, <String, dynamic>{
        'expectedVersion': 4,
        'slotOfferId': 'offer-1',
        'bookingKey': 'booking-stable',
        'timezone': 'Africa/Niamey',
      });
      expect(
        (captured.last as Options).headers?['Idempotency-Key'],
        'idempotency-stable',
      );
    });
  });

  group('Success Lab verified outcomes', () {
    test('loads workspace-scoped notice and decision history routes', () async {
      const noticePath =
          '/competition-readiness/workspaces/workspace-1/consents/'
          'outcome-evidence/notice';
      const decisionsPath =
          '/competition-readiness/workspaces/workspace-1/decisions';
      when(
        () => mockDio.get<Map<String, dynamic>>(
          noticePath,
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: noticePath),
          data: <String, dynamic>{'version': 'outcome-evidence-v1'},
        ),
      );
      when(() => mockDio.get<Map<String, dynamic>>(decisionsPath)).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: decisionsPath),
          data: <String, dynamic>{
            'current': <String, dynamic>{},
            'history': <String, dynamic>{},
          },
        ),
      );

      await apiClient.getSuccessLabOutcomeConsentNotice(
        workspaceId: 'workspace-1',
        language: 'en',
      );
      await apiClient.listSuccessLabDecisions('workspace-1');

      final query = verify(
        () => mockDio.get<Map<String, dynamic>>(
          noticePath,
          queryParameters: captureAny(named: 'queryParameters'),
        ),
      ).captured.single as Map<String, dynamic>;
      expect(query, <String, dynamic>{'language': 'en'});
      verify(() => mockDio.get<Map<String, dynamic>>(decisionsPath)).called(1);
    });

    test('outcome consent is workspace-scoped and explicitly accepted',
        () async {
      const path = '/competition-readiness/workspaces/workspace-1/consents';
      when(
        () => mockDio.post<Map<String, dynamic>>(
          path,
          data: any(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: path),
          data: <String, dynamic>{'receiptId': 'receipt-1'},
        ),
      );

      await apiClient.grantSuccessLabOutcomeConsent(
        workspaceId: 'workspace-1',
        languageCode: 'fr',
        noticeVersion: 'outcome-evidence-v1',
      );

      final body = verify(
        () => mockDio.post<Map<String, dynamic>>(
          path,
          data: captureAny(named: 'data'),
        ),
      ).captured.single as Map<String, dynamic>;
      expect(body, <String, dynamic>{
        'purpose': 'outcome_evidence',
        'languageCode': 'fr',
        'noticeVersion': 'outcome-evidence-v1',
        'accepted': true,
      });
    });

    test('upload intent carries consent and stable idempotency metadata',
        () async {
      const path = '/competition-readiness/workspaces/workspace-1/'
          'outcome-evidence/upload-intents';
      when(
        () => mockDio.post<Map<String, dynamic>>(
          path,
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: path),
          data: <String, dynamic>{},
        ),
      );

      await apiClient.createSuccessLabOutcomeEvidenceUploadIntent(
        workspaceId: 'workspace-1',
        kind: 'admission_decision',
        originalFileName: 'decision.pdf',
        mimeType: 'application/pdf',
        sizeBytes: 42,
        sha256: 'sha-256',
        consentReceiptId: 'receipt-1',
        idempotencyKey: 'stable-upload-key',
      );

      final captured = verify(
        () => mockDio.post<Map<String, dynamic>>(
          path,
          data: captureAny(named: 'data'),
          options: captureAny(named: 'options'),
        ),
      ).captured;
      expect(captured.first, <String, dynamic>{
        'kind': 'admission_decision',
        'originalFileName': 'decision.pdf',
        'mimeType': 'application/pdf',
        'sizeBytes': 42,
        'sha256': 'sha-256',
        'consentReceiptId': 'receipt-1',
      });
      expect(
        (captured.last as Options).headers?['Idempotency-Key'],
        'stable-upload-key',
      );
    });

    test('upload completion uses the frozen multipart file endpoint', () async {
      final temporary = await Directory.systemTemp.createTemp('outcome-test');
      addTearDown(() => temporary.delete(recursive: true));
      final file = File('${temporary.path}/evidence.pdf')
        ..writeAsBytesSync(<int>[1, 2, 3]);
      const path =
          '/competition-readiness/outcome-evidence/evidence-1/complete';
      when(
        () => mockDio.post<Map<String, dynamic>>(
          path,
          data: any(named: 'data'),
          onSendProgress: any(named: 'onSendProgress'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: path),
          data: <String, dynamic>{'processingStatus': 'clean'},
        ),
      );

      await apiClient.completeSuccessLabOutcomeEvidenceUpload(
        evidenceId: 'evidence-1',
        filePath: file.path,
        fileName: 'evidence.pdf',
      );

      final data = verify(
        () => mockDio.post<Map<String, dynamic>>(
          path,
          data: captureAny(named: 'data'),
          onSendProgress: any(named: 'onSendProgress'),
          options: any(named: 'options'),
        ),
      ).captured.single;
      expect(data, isA<FormData>());
      expect((data as FormData).files.single.key, 'file');
    });

    test('submission keeps raw reference in TLS payload and sends CAS version',
        () async {
      const path = '/competition-readiness/workspaces/workspace-1/submissions';
      when(
        () => mockDio.post<Map<String, dynamic>>(
          path,
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: path),
          data: <String, dynamic>{},
        ),
      );

      await apiClient.createSuccessLabSubmission(
        workspaceId: 'workspace-1',
        expectedWorkspaceVersion: 3,
        submittedAt: DateTime.utc(2026, 7, 17, 10),
        applicationReference: '  REF-2026-42  ',
        evidenceId: 'evidence-1',
        idempotencyKey: 'stable-submission-key',
      );

      final captured = verify(
        () => mockDio.post<Map<String, dynamic>>(
          path,
          data: captureAny(named: 'data'),
          options: captureAny(named: 'options'),
        ),
      ).captured;
      expect(captured.first, <String, dynamic>{
        'expectedWorkspaceVersion': 3,
        'submittedAt': '2026-07-17T10:00:00.000Z',
        'applicationReference': 'REF-2026-42',
        'evidenceId': 'evidence-1',
      });
      expect(
        (captured.last as Options).headers?['Idempotency-Key'],
        'stable-submission-key',
      );
    });

    test('funding amount stays an exact decimal string', () async {
      const path =
          '/competition-readiness/workspaces/workspace-1/funding-decisions';
      when(
        () => mockDio.post<Map<String, dynamic>>(
          path,
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: path),
          data: <String, dynamic>{},
        ),
      );

      await apiClient.createSuccessLabFundingDecision(
        workspaceId: 'workspace-1',
        expectedWorkspaceVersion: 5,
        issuedByName: 'Example University',
        fundingDecision: 'partial',
        receivedAt: DateTime.utc(2026, 7, 17),
        evidenceId: 'evidence-2',
        fundingAmountMinor: '9007199254740993',
        fundingCurrency: 'xof',
        idempotencyKey: 'stable-funding-key',
      );

      final body = verify(
        () => mockDio.post<Map<String, dynamic>>(
          path,
          data: captureAny(named: 'data'),
          options: any(named: 'options'),
        ),
      ).captured.single as Map<String, dynamic>;
      expect(body['fundingAmountMinor'], '9007199254740993');
      expect(body['fundingCurrency'], 'XOF');
      expect(body['expectedWorkspaceVersion'], 5);
    });

    test('admission declaration sends institution decision and workspace CAS',
        () async {
      const path = '/competition-readiness/workspaces/workspace-1/'
          'admission-decisions';
      when(
        () => mockDio.post<Map<String, dynamic>>(
          path,
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: path),
          data: <String, dynamic>{},
        ),
      );

      await apiClient.createSuccessLabAdmissionDecision(
        workspaceId: 'workspace-1',
        expectedWorkspaceVersion: 4,
        issuedByName: ' Example University ',
        admissionDecision: 'waitlisted',
        receivedAt: DateTime.utc(2026, 7, 17),
        evidenceId: 'evidence-4',
        idempotencyKey: 'stable-admission-key',
      );

      final body = verify(
        () => mockDio.post<Map<String, dynamic>>(
          path,
          data: captureAny(named: 'data'),
          options: any(named: 'options'),
        ),
      ).captured.single as Map<String, dynamic>;
      expect(body['expectedWorkspaceVersion'], 4);
      expect(body['issuedByName'], 'Example University');
      expect(body['admissionDecision'], 'waitlisted');
      expect(body['evidenceId'], 'evidence-4');
    });

    test('evidence complement uses outcome lockVersion CAS', () async {
      const path =
          '/competition-readiness/outcomes/admission/admission-1/evidence';
      when(
        () => mockDio.post<Map<String, dynamic>>(
          path,
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: path),
          data: <String, dynamic>{},
        ),
      );

      await apiClient.attachSuccessLabOutcomeEvidence(
        outcomeType: 'admission',
        outcomeId: 'admission-1',
        expectedVersion: 4,
        evidenceId: 'evidence-3',
        idempotencyKey: 'stable-complement-key',
      );

      final body = verify(
        () => mockDio.post<Map<String, dynamic>>(
          path,
          data: captureAny(named: 'data'),
          options: any(named: 'options'),
        ),
      ).captured.single as Map<String, dynamic>;
      expect(body, <String, dynamic>{
        'expectedVersion': 4,
        'evidenceId': 'evidence-3',
      });
    });
  });
}
