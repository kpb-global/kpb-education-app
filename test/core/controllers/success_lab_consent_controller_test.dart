import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:karatou/app/core/controllers/success_lab_diagnostic_controller.dart';
import 'package:karatou/app/core/controllers/success_lab_study_review_controller.dart';
import 'package:karatou/app/core/models/success_lab.dart';
import 'package:karatou/app/core/repositories/success_lab_repository.dart';

class _MockSuccessLabRepository extends Mock implements SuccessLabRepository {}

const _diagnosticAccess = SuccessLabAccess(
  enabled: true,
  aiDiagnosticEnabled: false,
  aiDiagnosticAvailable: true,
  aiDiagnosticRequiresConsent: true,
);

const _studyAccess = SuccessLabAccess(
  enabled: true,
  counsellorStudyEnabled: true,
);

const _notice = SuccessLabAiNotice(
  version: 'notice-v2',
  languageCode: 'fr',
  title: 'Notice',
  body: 'Body',
  contentHash: 'current-content-hash',
);

const _artifact = SuccessLabArtifact(
  id: 'artifact-1',
  kind: 'cv',
  title: 'CV',
  currentVersionId: 'version-1',
  versions: <SuccessLabArtifactVersion>[
    SuccessLabArtifactVersion(
      id: 'version-1',
      versionNumber: 1,
      originalFileName: 'cv.pdf',
      mimeType: 'application/pdf',
      sizeBytes: 1200,
      processingStatus: 'clean',
    ),
  ],
);

const _newArtifact = SuccessLabArtifact(
  id: 'artifact-2',
  kind: 'essay',
  title: 'Essai',
  currentVersionId: 'version-2',
  versions: <SuccessLabArtifactVersion>[
    SuccessLabArtifactVersion(
      id: 'version-2',
      versionNumber: 1,
      originalFileName: 'essay.pdf',
      mimeType: 'application/pdf',
      sizeBytes: 1400,
      processingStatus: 'clean',
    ),
  ],
);

void main() {
  test('diagnostic rejects acceptance bound to an older notice hash', () async {
    final repository = _MockSuccessLabRepository();
    when(() => repository.canUseNetwork).thenReturn(true);
    when(repository.fetchAccess).thenAnswer((_) async => _diagnosticAccess);
    when(() => repository.fetchDiagnostic('workspace-1')).thenAnswer(
      (_) async => const SuccessLabDiagnosticEnvelope(
        entitlementAvailable: true,
      ),
    );
    when(() => repository.fetchAiNotice(language: 'fr'))
        .thenAnswer((_) async => _notice);
    final controller = SuccessLabDiagnosticController(
      repository: repository,
      workspaceId: 'workspace-1',
      language: 'fr',
      delay: (_) async {},
    );
    addTearDown(controller.dispose);

    await controller.load();
    await controller.start(
      consentAccepted: true,
      acceptedNoticeContentHash: 'older-content-hash',
    );

    expect(controller.phase, SuccessLabDiagnosticPhase.consentRequired);
    expect(controller.failure?.code, 'AI_CONSENT_REQUIRED');
    verifyNever(() => repository.grantAiConsent(_notice));
  });

  test('study review rejects acceptance bound to an older notice hash',
      () async {
    final repository = _MockSuccessLabRepository();
    when(() => repository.canUseNetwork).thenReturn(true);
    when(repository.fetchAccess).thenAnswer((_) async => _studyAccess);
    when(() => repository.fetchActiveStudyReview('workspace-1'))
        .thenAnswer((_) async => null);
    when(() => repository.fetchStudyReviewNotice(language: 'fr'))
        .thenAnswer((_) async => _notice);
    when(() => repository.fetchArtifacts('workspace-1'))
        .thenAnswer((_) async => const <SuccessLabArtifact>[]);
    final controller = SuccessLabStudyReviewController(
      repository: repository,
      workspaceId: 'workspace-1',
      language: 'fr',
    );
    addTearDown(controller.dispose);

    await controller.load();
    await controller.upload(
      consentAccepted: true,
      acceptedNoticeContentHash: 'older-content-hash',
      kind: 'cv',
      title: 'CV',
      filePath: '/not-read-when-consent-is-invalid.pdf',
    );

    expect(controller.phase, SuccessLabStudyReviewPhase.ready);
    expect(
      controller.failure?.code,
      'ADVISOR_DOCUMENT_SHARE_CONSENT_REQUIRED',
    );
    verifyNever(() => repository.grantStudyReviewConsent(_notice));
  });

  test('study review reloads artifacts after an explicit deletion', () async {
    final repository = _MockSuccessLabRepository();
    when(() => repository.canUseNetwork).thenReturn(true);
    when(repository.fetchAccess).thenAnswer((_) async => _studyAccess);
    when(() => repository.fetchActiveStudyReview('workspace-1'))
        .thenAnswer((_) async => null);
    when(() => repository.fetchStudyReviewNotice(language: 'fr'))
        .thenAnswer((_) async => _notice);
    var artifactLoads = 0;
    when(() => repository.fetchArtifacts('workspace-1')).thenAnswer((_) async {
      artifactLoads++;
      return artifactLoads == 1
          ? const <SuccessLabArtifact>[_artifact]
          : const <SuccessLabArtifact>[];
    });
    when(
      () => repository.deleteArtifactVersion(
        versionId: 'version-1',
        reason: 'student_removed_before_review',
      ),
    ).thenAnswer((_) async {});
    final controller = SuccessLabStudyReviewController(
      repository: repository,
      workspaceId: 'workspace-1',
      language: 'fr',
    );
    addTearDown(controller.dispose);

    await controller.load();
    expect(controller.selectedVersionIds, contains('version-1'));
    await controller.deleteVersion('version-1');

    expect(controller.phase, SuccessLabStudyReviewPhase.ready);
    expect(controller.artifacts, isEmpty);
    expect(controller.selectedVersionIds, isEmpty);
    verify(
      () => repository.deleteArtifactVersion(
        versionId: 'version-1',
        reason: 'student_removed_before_review',
      ),
    ).called(1);
  });

  test('shared artifact conflict keeps the document visible', () async {
    final repository = _MockSuccessLabRepository();
    when(() => repository.canUseNetwork).thenReturn(true);
    when(repository.fetchAccess).thenAnswer((_) async => _studyAccess);
    when(() => repository.fetchActiveStudyReview('workspace-1'))
        .thenAnswer((_) async => null);
    when(() => repository.fetchStudyReviewNotice(language: 'fr'))
        .thenAnswer((_) async => _notice);
    when(() => repository.fetchArtifacts('workspace-1')).thenAnswer(
      (_) async => const <SuccessLabArtifact>[_artifact],
    );
    when(
      () => repository.deleteArtifactVersion(
        versionId: 'version-1',
        reason: 'student_removed_before_review',
      ),
    ).thenThrow(
      const SuccessLabFailure(
        kind: SuccessLabFailureKind.forbidden,
        code: 'FORBIDDEN_SCOPE',
        retryable: false,
      ),
    );
    final controller = SuccessLabStudyReviewController(
      repository: repository,
      workspaceId: 'workspace-1',
      language: 'fr',
    );
    addTearDown(controller.dispose);

    await controller.load();
    await controller.deleteVersion('version-1');

    expect(controller.phase, SuccessLabStudyReviewPhase.ready);
    expect(controller.artifacts.single.currentVersion?.id, 'version-1');
    expect(controller.failure?.code, 'FORBIDDEN_SCOPE');
    expect(controller.isDeletingVersion('version-1'), isFalse);
  });

  test('complement keeps every clean existing share when adding a new version',
      () async {
    final repository = _MockSuccessLabRepository();
    final active = _review(
      status: SuccessLabStudyReviewStatus.moreInformationNeeded,
      nextAction: SuccessLabStudyReviewNextAction.provideMoreInformation,
    );
    final submitted = _review(
      status: SuccessLabStudyReviewStatus.submitted,
      nextAction: SuccessLabStudyReviewNextAction.waitForTriage,
      version: 4,
    );
    when(() => repository.canUseNetwork).thenReturn(true);
    when(repository.fetchAccess).thenAnswer((_) async => _studyAccess);
    when(() => repository.fetchActiveStudyReview('workspace-1'))
        .thenAnswer((_) async => active);
    when(() => repository.fetchStudyReviewNotice(language: 'fr'))
        .thenAnswer((_) async => _notice);
    when(() => repository.fetchArtifacts('workspace-1')).thenAnswer(
      (_) async => const <SuccessLabArtifact>[_artifact, _newArtifact],
    );
    when(() => repository.grantStudyReviewConsent(_notice))
        .thenAnswer((_) async => 'receipt-2');
    when(
      () => repository.submitStudyReviewComplement(
        reviewRequest: active,
        studentMessage: 'Nouvel essai joint.',
        artifactVersionIds: <String>['version-1', 'version-2'],
        consentReceiptId: 'receipt-2',
      ),
    ).thenAnswer((_) async => submitted);
    final controller = SuccessLabStudyReviewController(
      repository: repository,
      workspaceId: 'workspace-1',
      language: 'fr',
    );
    addTearDown(controller.dispose);

    await controller.load();
    expect(controller.selectedVersionIds, <String>{'version-1'});
    controller.toggleVersion('version-2', true);
    await controller.submitComplement(
      consentAccepted: true,
      acceptedNoticeContentHash: _notice.contentHash,
      studentMessage: 'Nouvel essai joint.',
    );

    expect(controller.request?.status, SuccessLabStudyReviewStatus.submitted);
    verify(
      () => repository.submitStudyReviewComplement(
        reviewRequest: active,
        studentMessage: 'Nouvel essai joint.',
        artifactVersionIds: <String>['version-1', 'version-2'],
        consentReceiptId: 'receipt-2',
      ),
    ).called(1);
  });
}

SuccessLabStudyReviewRequest _review({
  required SuccessLabStudyReviewStatus status,
  required SuccessLabStudyReviewNextAction nextAction,
  int version = 3,
}) {
  return SuccessLabStudyReviewRequest(
    id: 'review-1',
    workspaceId: 'workspace-1',
    status: status,
    statusWireValue: status == SuccessLabStudyReviewStatus.moreInformationNeeded
        ? 'more_information_needed'
        : 'submitted',
    nextAction: nextAction,
    nextActionWireValue:
        nextAction == SuccessLabStudyReviewNextAction.provideMoreInformation
            ? 'provide_more_information'
            : 'wait_for_triage',
    requestNumber: 1,
    version: version,
    timezone: 'Africa/Niamey',
    missingItems: const <String>['Ajouter un essai corrigé.'],
    sharedVersions: <SuccessLabStudyReviewSharedVersion>[
      SuccessLabStudyReviewSharedVersion(
        shareId: 'share-1',
        artifactVersionId: 'version-1',
        artifactId: 'artifact-1',
        artifactKind: 'cv',
        artifactTitle: 'CV',
        versionNumber: 1,
        originalFileName: 'cv.pdf',
        mimeType: 'application/pdf',
        sizeBytes: 1200,
        processingStatus: 'clean',
        grantedAt: DateTime.utc(2026, 7, 17),
      ),
    ],
    createdAt: DateTime.utc(2026, 7, 17),
    updatedAt: DateTime.utc(2026, 7, 17),
    submittedAt: DateTime.utc(2026, 7, 17),
  );
}
