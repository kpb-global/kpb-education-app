import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:karatou/app/core/data/success_lab_api_codec.dart';
import 'package:karatou/app/core/models/success_lab.dart';
import 'package:karatou/app/core/repositories/app_api_client.dart';
import 'package:karatou/app/core/repositories/success_lab_repository.dart';
import 'package:karatou/app/core/services/success_lab_cache_service.dart';
import 'package:karatou/app/core/services/success_lab_outbox.dart';

class _MockApiClient extends Mock implements AppApiClient {}

class _MemoryCache implements SuccessLabCacheStore {
  SuccessLabAccess? access;
  SuccessLabWorkspacePage? page;
  final Map<String, SuccessLabWorkspace> workspaces = {};

  @override
  Future<void> clearUser() async {
    access = null;
    page = null;
    workspaces.clear();
  }

  @override
  Future<SuccessLabCachedValue<SuccessLabAccess>?> readAccess() async =>
      access == null
          ? null
          : SuccessLabCachedValue(
              value: access!,
              syncedAt: DateTime.utc(2026, 7, 17),
            );

  @override
  Future<SuccessLabCachedValue<SuccessLabWorkspacePage>?> readPage({
    String? status,
  }) async =>
      page == null
          ? null
          : SuccessLabCachedValue(
              value: page!,
              syncedAt: DateTime.utc(2026, 7, 17),
            );

  @override
  Future<SuccessLabCachedValue<SuccessLabWorkspace>?> readWorkspace(
    String workspaceId,
  ) async {
    final value = workspaces[workspaceId];
    return value == null
        ? null
        : SuccessLabCachedValue(
            value: value,
            syncedAt: DateTime.utc(2026, 7, 17),
          );
  }

  @override
  Future<void> writeAccess(
    SuccessLabAccess value, {
    DateTime? syncedAt,
  }) async {
    access = value;
  }

  @override
  Future<void> writePage(
    SuccessLabWorkspacePage value, {
    String? status,
    DateTime? syncedAt,
  }) async {
    page = value;
  }

  @override
  Future<void> writeWorkspace(
    SuccessLabWorkspace value, {
    DateTime? syncedAt,
  }) async {
    workspaces[value.id] = value;
  }
}

class _MemoryOutbox implements SuccessLabOutboxStore {
  final List<SuccessLabPendingMutation> entries = [];

  @override
  Future<void> clearUser() async => entries.clear();

  @override
  Future<void> enqueue(SuccessLabPendingMutation mutation) async {
    entries.removeWhere(
      (entry) => entry.clientMutationId == mutation.clientMutationId,
    );
    entries.add(mutation);
  }

  @override
  Future<void> markAttempt(
    SuccessLabPendingMutation mutation, {
    required String? errorCode,
    int? rebasedVersion,
    bool permanentlyFailed = false,
  }) async {
    await enqueue(
      mutation.copyWith(
        baseVersion: rebasedVersion,
        attempts: mutation.attempts + 1,
        lastErrorCode: errorCode,
        permanentlyFailed: permanentlyFailed,
      ),
    );
  }

  @override
  Future<List<SuccessLabPendingMutation>> pending({
    String? workspaceId,
  }) async =>
      entries
          .where(
            (entry) => workspaceId == null || entry.workspaceId == workspaceId,
          )
          .toList(growable: false);

  @override
  Future<void> remove(String clientMutationId) async {
    entries.removeWhere(
      (entry) => entry.clientMutationId == clientMutationId,
    );
  }
}

void main() {
  late _MockApiClient apiClient;
  late _MemoryCache cache;
  late _MemoryOutbox outbox;

  setUp(() {
    apiClient = _MockApiClient();
    cache = _MemoryCache();
    outbox = _MemoryOutbox();
  });

  test('create retries a transport failure with the same idempotency key',
      () async {
    var calls = 0;
    when(
      () => apiClient.createSuccessLabWorkspace(
        scholarshipId: any(named: 'scholarshipId'),
        cycleId: any(named: 'cycleId'),
        idempotencyKey: any(named: 'idempotencyKey'),
      ),
    ).thenAnswer((_) async {
      calls++;
      if (calls == 1) {
        throw DioException.connectionError(
          requestOptions: RequestOptions(path: '/workspaces'),
          reason: 'offline',
        );
      }
      return _workspaceFixture();
    });
    final repository = SuccessLabRepository(
      apiClient: apiClient,
      cache: cache,
      outbox: outbox,
      userId: 'user-1',
      remoteEnabled: true,
      isOnline: () => true,
      delay: (_) async {},
      mutationIdFactory: () => 'mutation-fixed',
    );

    final workspace = await repository.createWorkspace(
      scholarshipId: 'scholarship_fixture_1',
      cycleId: 'cycle_fixture_1',
    );

    expect(workspace.id, 'workspace_fixture_1');
    expect(calls, 2);
    verify(
      () => apiClient.createSuccessLabWorkspace(
        scholarshipId: 'scholarship_fixture_1',
        cycleId: 'cycle_fixture_1',
        idempotencyKey: 'mutation-fixed',
      ),
    ).called(2);
  });

  test('offline step change is persisted before it is reported as queued',
      () async {
    final workspace = SuccessLabApiCodec.workspaceFromApi(_workspaceFixture());
    final repository = SuccessLabRepository(
      apiClient: apiClient,
      cache: cache,
      outbox: outbox,
      userId: 'user-1',
      remoteEnabled: true,
      isOnline: () => false,
      mutationIdFactory: () => 'mutation-offline',
    );

    final result = await repository.updateStep(
      workspace: workspace,
      step: workspace.steps.last,
      status: SuccessLabWorkspaceStepStatus.completed,
    );

    expect(result.queued, isTrue);
    expect(outbox.entries, hasLength(1));
    expect(outbox.entries.single.clientMutationId, 'mutation-offline');
    expect(
      outbox.entries.single.status,
      SuccessLabWorkspaceStepStatus.completed,
    );
    verifyNever(
      () => apiClient.updateSuccessLabWorkspaceStep(
        workspaceId: any(named: 'workspaceId'),
        stepId: any(named: 'stepId'),
        status: any(named: 'status'),
        clientMutationId: any(named: 'clientMutationId'),
        expectedVersion: any(named: 'expectedVersion'),
        notApplicableReason: any(named: 'notApplicableReason'),
      ),
    );
  });

  test('diagnostic retry reuses one client mutation id', () async {
    var calls = 0;
    when(
      () => apiClient.createSuccessLabDiagnostic(
        workspaceId: any(named: 'workspaceId'),
        language: any(named: 'language'),
        idempotencyKey: any(named: 'idempotencyKey'),
        applicationExcerpt: any(named: 'applicationExcerpt'),
      ),
    ).thenAnswer((_) async {
      calls++;
      if (calls == 1) {
        throw DioException.connectionError(
          requestOptions: RequestOptions(path: '/diagnostic'),
          reason: 'offline',
        );
      }
      return _diagnosticFixture();
    });
    final repository = SuccessLabRepository(
      apiClient: apiClient,
      cache: cache,
      outbox: outbox,
      userId: 'user-1',
      remoteEnabled: true,
      isOnline: () => true,
      delay: (_) async {},
      mutationIdFactory: () => 'diagnostic-mutation-fixed',
    );

    final diagnostic = await repository.createDiagnostic(
      workspaceId: 'workspace-1',
      language: 'fr',
      applicationExcerpt: 'Extrait sans identité.',
    );

    expect(diagnostic.isComplete, isTrue);
    expect(calls, 2);
    verify(
      () => apiClient.createSuccessLabDiagnostic(
        workspaceId: 'workspace-1',
        language: 'fr',
        idempotencyKey: 'diagnostic-mutation-fixed',
        applicationExcerpt: 'Extrait sans identité.',
      ),
    ).called(2);
  });

  test('study-review submission retry reuses one idempotency key', () async {
    var calls = 0;
    when(
      () => apiClient.createSuccessLabStudyReview(
        workspaceId: any(named: 'workspaceId'),
        artifactVersionIds: any(named: 'artifactVersionIds'),
        consentReceiptId: any(named: 'consentReceiptId'),
        idempotencyKey: any(named: 'idempotencyKey'),
        studentMessage: any(named: 'studentMessage'),
      ),
    ).thenAnswer((_) async {
      calls++;
      if (calls == 1) {
        throw DioException.connectionError(
          requestOptions: RequestOptions(path: '/study-reviews'),
          reason: 'offline',
        );
      }
      return _studyReviewFixture();
    });
    final repository = SuccessLabRepository(
      apiClient: apiClient,
      cache: cache,
      outbox: outbox,
      userId: 'user-1',
      remoteEnabled: true,
      isOnline: () => true,
      delay: (_) async {},
      mutationIdFactory: () => 'review-mutation-fixed',
    );

    final review = await repository.createStudyReview(
      workspaceId: 'workspace-1',
      artifactVersionIds: <String>['version-1'],
      consentReceiptId: 'consent-1',
      studentMessage: 'Merci de vérifier mon dossier.',
    );

    expect(review.id, 'review-1');
    expect(calls, 2);
    verify(
      () => apiClient.createSuccessLabStudyReview(
        workspaceId: 'workspace-1',
        artifactVersionIds: <String>['version-1'],
        consentReceiptId: 'consent-1',
        idempotencyKey: 'review-mutation-fixed',
        studentMessage: 'Merci de vérifier mon dossier.',
      ),
    ).called(2);
  });

  test('active study review is recovered from server truth without cache',
      () async {
    when(() => apiClient.getActiveSuccessLabStudyReview('workspace-1'))
        .thenAnswer(
      (_) async => <String, dynamic>{
        'schemaVersion': 1,
        'reviewRequest': _studyReviewFixture(),
      },
    );
    final repository = SuccessLabRepository(
      apiClient: apiClient,
      cache: cache,
      outbox: outbox,
      userId: 'user-1',
      remoteEnabled: true,
      isOnline: () => true,
      delay: (_) async {},
    );

    final review = await repository.fetchActiveStudyReview('workspace-1');

    expect(review?.id, 'review-1');
    expect(cache.workspaces, isEmpty);
    expect(outbox.entries, isEmpty);
  });

  test('slot offers hide expired or past entries defensively', () async {
    when(() => apiClient.listSuccessLabStudyReviewSlotOffers('review-1'))
        .thenAnswer(
      (_) async => _slotOffersFixture(),
    );
    final repository = SuccessLabRepository(
      apiClient: apiClient,
      cache: cache,
      outbox: outbox,
      userId: 'user-1',
      remoteEnabled: true,
      isOnline: () => true,
      delay: (_) async {},
      now: () => DateTime.utc(2026, 7, 18, 8),
    );

    final result = await repository.fetchStudyReviewSlotOffers('review-1');

    expect(
        result.offers.map((offer) => offer.slotOfferId), <String>['offer-1']);
    expect(cache.workspaces, isEmpty);
    expect(outbox.entries, isEmpty);
  });

  test(
      'booking timeout retry keeps bookingKey and Idempotency-Key byte-identical',
      () async {
    var calls = 0;
    when(
      () => apiClient.bookSuccessLabStudyReviewAppointment(
        reviewRequestId: any(named: 'reviewRequestId'),
        expectedVersion: any(named: 'expectedVersion'),
        slotOfferId: any(named: 'slotOfferId'),
        bookingKey: any(named: 'bookingKey'),
        timezone: any(named: 'timezone'),
        idempotencyKey: any(named: 'idempotencyKey'),
      ),
    ).thenAnswer((_) async {
      calls++;
      if (calls == 1) {
        throw DioException.connectionError(
          requestOptions: RequestOptions(path: '/appointments'),
          reason: 'timeout after send',
        );
      }
      return _bookingFixture();
    });
    final repository = SuccessLabRepository(
      apiClient: apiClient,
      cache: cache,
      outbox: outbox,
      userId: 'user-1',
      remoteEnabled: true,
      isOnline: () => true,
      delay: (_) async {},
    );

    final result = await repository.bookStudyReviewAppointment(
      reviewRequestId: 'review-1',
      expectedVersion: 3,
      slotOfferId: 'offer-1',
      bookingKey: 'booking-stable',
      timezone: 'Africa/Niamey',
      idempotencyKey: 'idempotency-stable',
    );

    expect(result.isServerConfirmed, isTrue);
    final callsCaptured = verify(
      () => apiClient.bookSuccessLabStudyReviewAppointment(
        reviewRequestId: 'review-1',
        expectedVersion: 3,
        slotOfferId: 'offer-1',
        bookingKey: captureAny(named: 'bookingKey'),
        timezone: 'Africa/Niamey',
        idempotencyKey: captureAny(named: 'idempotencyKey'),
      ),
    ).captured;
    expect(callsCaptured, <Object?>[
      'booking-stable',
      'idempotency-stable',
      'booking-stable',
      'idempotency-stable',
    ]);
    expect(cache.workspaces, isEmpty);
    expect(outbox.entries, isEmpty);
  });

  test(
      'artifact upload intent retry keeps one key and confirms a clean version',
      () async {
    final directory = await Directory.systemTemp.createTemp('kpb-artifact-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/cv.pdf');
    await file.writeAsBytes(<int>[0x25, 0x50, 0x44, 0x46, 0x2D, 0x31]);
    var intentCalls = 0;
    when(
      () => apiClient.createSuccessLabArtifactUploadIntent(
        workspaceId: any(named: 'workspaceId'),
        kind: any(named: 'kind'),
        title: any(named: 'title'),
        originalFileName: any(named: 'originalFileName'),
        mimeType: any(named: 'mimeType'),
        sizeBytes: any(named: 'sizeBytes'),
        sha256: any(named: 'sha256'),
        idempotencyKey: any(named: 'idempotencyKey'),
      ),
    ).thenAnswer((_) async {
      intentCalls++;
      if (intentCalls == 1) {
        throw DioException.connectionError(
          requestOptions: RequestOptions(path: '/upload-intents'),
          reason: 'offline',
        );
      }
      return <String, dynamic>{
        'version': <String, dynamic>{'id': 'version-1'},
      };
    });
    when(
      () => apiClient.completeSuccessLabArtifactUpload(
        versionId: any(named: 'versionId'),
        filePath: any(named: 'filePath'),
        fileName: any(named: 'fileName'),
        onProgress: null,
      ),
    ).thenAnswer((_) async => <String, dynamic>{'id': 'version-1'});
    when(() => apiClient.listSuccessLabArtifacts('workspace-1')).thenAnswer(
      (_) async => _artifactListFixture(),
    );
    final repository = SuccessLabRepository(
      apiClient: apiClient,
      cache: cache,
      outbox: outbox,
      userId: 'user-1',
      remoteEnabled: true,
      isOnline: () => true,
      delay: (_) async {},
      mutationIdFactory: () => 'artifact-mutation-fixed',
    );

    final version = await repository.uploadArtifact(
      workspaceId: 'workspace-1',
      kind: 'cv',
      title: 'CV bourse',
      filePath: file.path,
    );

    expect(version.id, 'version-1');
    expect(version.isClean, isTrue);
    expect(intentCalls, 2);
    final captured = verify(
      () => apiClient.createSuccessLabArtifactUploadIntent(
        workspaceId: 'workspace-1',
        kind: 'cv',
        title: 'CV bourse',
        originalFileName: 'cv.pdf',
        mimeType: 'application/pdf',
        sizeBytes: 6,
        sha256: captureAny(named: 'sha256'),
        idempotencyKey: 'artifact-mutation-fixed',
      ),
    ).captured;
    expect(captured, hasLength(2));
    expect(captured.toSet(), hasLength(1));
  });

  test('artifact deletion retries safely with the same explicit reason',
      () async {
    var calls = 0;
    when(
      () => apiClient.deleteSuccessLabArtifactVersion(
        versionId: any(named: 'versionId'),
        reason: any(named: 'reason'),
      ),
    ).thenAnswer((_) async {
      calls++;
      if (calls == 1) {
        throw DioException.connectionError(
          requestOptions: RequestOptions(path: '/artifact-versions/version-1'),
          reason: 'offline',
        );
      }
    });
    final repository = SuccessLabRepository(
      apiClient: apiClient,
      cache: cache,
      outbox: outbox,
      userId: 'user-1',
      remoteEnabled: true,
      isOnline: () => true,
      delay: (_) async {},
    );

    await repository.deleteArtifactVersion(
      versionId: 'version-1',
      reason: 'student_removed_before_review',
    );

    expect(calls, 2);
    verify(
      () => apiClient.deleteSuccessLabArtifactVersion(
        versionId: 'version-1',
        reason: 'student_removed_before_review',
      ),
    ).called(2);
  });

  test('artifact deletion is fail-closed while offline', () async {
    final repository = SuccessLabRepository(
      apiClient: apiClient,
      cache: cache,
      outbox: outbox,
      userId: 'user-1',
      remoteEnabled: true,
      isOnline: () => false,
    );

    await expectLater(
      repository.deleteArtifactVersion(
        versionId: 'version-1',
        reason: 'student_removed_before_review',
      ),
      throwsA(
        isA<SuccessLabFailure>().having(
          (failure) => failure.kind,
          'kind',
          SuccessLabFailureKind.offline,
        ),
      ),
    );
    verifyNever(
      () => apiClient.deleteSuccessLabArtifactVersion(
        versionId: any(named: 'versionId'),
        reason: any(named: 'reason'),
      ),
    );
  });

  test('submission retry keeps CAS/idempotency stable and stores no private id',
      () async {
    var calls = 0;
    when(
      () => apiClient.createSuccessLabSubmission(
        workspaceId: any(named: 'workspaceId'),
        expectedWorkspaceVersion: any(named: 'expectedWorkspaceVersion'),
        submittedAt: any(named: 'submittedAt'),
        idempotencyKey: any(named: 'idempotencyKey'),
        submissionChannel: any(named: 'submissionChannel'),
        applicationReference: any(named: 'applicationReference'),
        evidenceId: any(named: 'evidenceId'),
      ),
    ).thenAnswer((_) async {
      calls++;
      if (calls == 1) {
        throw DioException.connectionError(
          requestOptions: RequestOptions(path: '/submissions'),
          reason: 'lost response',
        );
      }
      return _submissionMutationFixture();
    });
    final repository = SuccessLabRepository(
      apiClient: apiClient,
      cache: cache,
      outbox: outbox,
      userId: 'user-1',
      remoteEnabled: true,
      isOnline: () => true,
      delay: (_) async {},
    );

    final result = await repository.createSubmission(
      workspaceId: 'workspace-1',
      expectedWorkspaceVersion: 3,
      submittedAt: DateTime.utc(2026, 7, 17),
      applicationReference: 'PRIVATE-REFERENCE',
      evidenceId: 'private-evidence-id',
      idempotencyKey: 'stable-submission-key',
    );

    expect(result.submission.id, 'submission-1');
    expect(result.workspace.version, 4);
    expect(calls, 2);
    expect(outbox.entries, isEmpty);
    expect(cache.workspaces, isEmpty);
    verify(
      () => apiClient.createSuccessLabSubmission(
        workspaceId: 'workspace-1',
        expectedWorkspaceVersion: 3,
        submittedAt: DateTime.utc(2026, 7, 17),
        idempotencyKey: 'stable-submission-key',
        submissionChannel: null,
        applicationReference: 'PRIVATE-REFERENCE',
        evidenceId: 'private-evidence-id',
      ),
    ).called(2);
  });

  test('outcome mutation fails closed offline without using the outbox',
      () async {
    final repository = SuccessLabRepository(
      apiClient: apiClient,
      cache: cache,
      outbox: outbox,
      userId: 'user-1',
      remoteEnabled: true,
      isOnline: () => false,
    );

    await expectLater(
      repository.createAdmissionDecision(
        workspaceId: 'workspace-1',
        expectedWorkspaceVersion: 3,
        issuedByName: 'Example University',
        decision: SuccessLabAdmissionDecision.admitted,
        receivedAt: DateTime.utc(2026, 7, 17),
        evidenceId: 'private-evidence-id',
        idempotencyKey: 'stable-admission-key',
      ),
      throwsA(
        isA<SuccessLabFailure>().having(
          (failure) => failure.kind,
          'kind',
          SuccessLabFailureKind.offline,
        ),
      ),
    );
    expect(outbox.entries, isEmpty);
    expect(cache.workspaces, isEmpty);
  });
}

Map<String, dynamic> _submissionMutationFixture() => <String, dynamic>{
      'submission': <String, dynamic>{
        'id': 'submission-1',
        'workspaceId': 'workspace-1',
        'version': 1,
        'lockVersion': 1,
        'submittedAt': '2026-07-17T00:00:00.000Z',
        'submissionChannel': null,
        'hasApplicationReference': true,
        'evidence': <Object?>[
          <String, dynamic>{'id': 'not-retained'},
        ],
        'verificationStatus': 'pending',
        'verificationNotes': null,
        'verifiedAt': null,
        'createdAt': '2026-07-17T00:00:01.000Z',
        'updatedAt': '2026-07-17T00:00:01.000Z',
      },
      'workspace': <String, dynamic>{
        'id': 'workspace-1',
        'status': 'submitted',
        'version': 4,
      },
    };

Map<String, dynamic> _workspaceFixture() {
  return jsonDecode(
    File(
      'backend/src/modules/competition-readiness/contracts/fixtures/'
      'workspace-v1.fixture.json',
    ).readAsStringSync(),
  ) as Map<String, dynamic>;
}

Map<String, dynamic> _diagnosticFixture() => <String, dynamic>{
      'schemaVersion': 1,
      'id': 'diagnostic-1',
      'workspaceId': 'workspace-1',
      'status': 'succeeded',
      'generatedLanguage': 'fr',
      'result': <String, dynamic>{
        'strength': 'Une expérience pertinente est déjà présente.',
        'priorityImprovement': 'Ajoute une preuve mesurable.',
        'rationale': 'Le critère demande un exemple vérifiable.',
        'nextAction': 'Ajoute un résultat chiffré.',
        'criterionReferences': <String>['eligibility-001'],
      },
      'stale': false,
      'promptVersion': 'success-lab-v1',
      'fallbackReason': null,
      'completedAt': '2026-07-17T12:00:00.000Z',
      'reviewInvitation': <String, dynamic>{'available': true},
    };

Map<String, dynamic> _studyReviewFixture() => <String, dynamic>{
      'id': 'review-1',
      'workspaceId': 'workspace-1',
      'requestNumber': 1,
      'version': 1,
      'status': 'submitted',
      'nextAction': 'wait_for_triage',
      'studentMessage': null,
      'preferredContact': 'in_app',
      'timezone': 'UTC',
      'availability': null,
      'missingItems': null,
      'submittedAt': '2026-07-17T13:00:00.000Z',
      'triagedAt': null,
      'closedAt': null,
      'createdAt': '2026-07-17T13:00:00.000Z',
      'updatedAt': '2026-07-17T13:00:00.000Z',
      'sharedVersions': <Object?>[
        <String, dynamic>{
          'shareId': 'share-1',
          'artifactVersionId': 'version-1',
          'consentReceiptId': 'consent-1',
          'grantedAt': '2026-07-17T13:00:00.000Z',
          'revokedAt': null,
          'artifact': <String, dynamic>{
            'id': 'artifact-1',
            'kind': 'cv',
            'title': 'CV bourse',
          },
          'version': <String, dynamic>{
            'id': 'version-1',
            'versionNumber': 1,
            'originalFileName': 'cv.pdf',
            'mimeType': 'application/pdf',
            'sizeBytes': 6,
            'sha256': 'ignored-on-mobile',
            'processingStatus': 'clean',
            'uploadedAt': '2026-07-17T12:00:00.000Z',
          },
        },
      ],
    };

Map<String, dynamic> _artifactListFixture() => <String, dynamic>{
      'items': <Object?>[
        <String, dynamic>{
          'id': 'artifact-1',
          'kind': 'cv',
          'title': 'CV bourse',
          'currentVersionId': 'version-1',
          'versions': <Object?>[
            <String, dynamic>{
              'id': 'version-1',
              'versionNumber': 1,
              'originalFileName': 'cv.pdf',
              'mimeType': 'application/pdf',
              'sizeBytes': 6,
              'processingStatus': 'clean',
            },
          ],
        },
      ],
    };

Map<String, dynamic> _slotOffersFixture() => <String, dynamic>{
      'reviewRequestId': 'review-1',
      'reviewRequestVersion': 3,
      'timezone': 'Africa/Niamey',
      'offers': <Object?>[
        <String, dynamic>{
          'slotOfferId': 'offer-1',
          'slotId': 'slot-1',
          'startsAt': '2026-07-20T09:00:00.000Z',
          'endsAt': '2026-07-20T09:30:00.000Z',
          'timezone': 'Africa/Niamey',
          'expiresAt': '2026-07-19T09:00:00.000Z',
          'counsellorName': 'Aïcha KPB',
        },
        <String, dynamic>{
          'slotOfferId': 'offer-expired',
          'slotId': 'slot-expired',
          'startsAt': '2026-07-20T10:00:00.000Z',
          'endsAt': '2026-07-20T10:30:00.000Z',
          'timezone': 'Africa/Niamey',
          'expiresAt': '2026-07-18T07:00:00.000Z',
          'counsellorName': 'Aïcha KPB',
        },
      ],
    };

Map<String, dynamic> _bookingFixture() => <String, dynamic>{
      'appointment': <String, dynamic>{
        'id': 'appointment-1',
        'reviewRequestId': 'review-1',
        'slotOfferId': 'offer-1',
        'slotId': 'slot-1',
        'counsellorId': 'counsellor-1',
        'startsAt': '2026-07-20T09:00:00.000Z',
        'endsAt': '2026-07-20T09:30:00.000Z',
        'timezone': 'Africa/Niamey',
        'status': 'scheduled',
        'contactMethod': 'in_app',
        'createdAt': '2026-07-18T08:00:00.000Z',
      },
      'reviewRequest': <String, dynamic>{
        'id': 'review-1',
        'version': 4,
        'status': 'scheduled',
      },
    };
