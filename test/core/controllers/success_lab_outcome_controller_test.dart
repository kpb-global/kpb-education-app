import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:karatou/app/core/controllers/success_lab_outcome_controller.dart';
import 'package:karatou/app/core/models/success_lab.dart';
import 'package:karatou/app/core/repositories/success_lab_repository.dart';

class _MockRepository extends Mock implements SuccessLabRepository {}

void main() {
  late _MockRepository repository;
  late SuccessLabOutcomeController controller;
  var keyNumber = 0;

  setUpAll(() {
    registerFallbackValue(DateTime.utc(2000));
    registerFallbackValue(SuccessLabAdmissionDecision.admitted);
    registerFallbackValue(SuccessLabOutcomeEvidenceKind.other);
    registerFallbackValue(
      const SuccessLabAiNotice(
        version: 'fallback',
        languageCode: 'fr',
        title: 'Fallback',
        body: 'Fallback',
        contentHash: 'fallback',
      ),
    );
  });

  setUp(() {
    keyNumber = 0;
    repository = _MockRepository();
    when(() => repository.canUseNetwork).thenReturn(true);
    controller = SuccessLabOutcomeController(
      repository: repository,
      workspaceId: 'workspace-1',
      keyFactory: () => 'key-${++keyNumber}',
    );
    controller.history = const SuccessLabDecisionHistory(
      admissions: <SuccessLabAdmissionDecisionRecord>[],
      funding: <SuccessLabFundingDecisionRecord>[],
      workspaceVersion: 3,
    );
    controller.consentNotice = const SuccessLabAiNotice(
      version: 'outcome-evidence-v1',
      languageCode: 'fr',
      title: 'Preuves privées',
      body: 'Notice',
      contentHash: 'notice-hash',
    );
    controller.setConsentAccepted(true);
    controller.selectAdmissionEvidence(
      path: '/tmp/decision.pdf',
      name: 'decision.pdf',
    );
    when(
      () => repository.grantOutcomeEvidenceConsent(
        workspaceId: any(named: 'workspaceId'),
        notice: any(named: 'notice'),
      ),
    ).thenAnswer((_) async => 'receipt-1');
    when(
      () => repository.uploadOutcomeEvidence(
        workspaceId: any(named: 'workspaceId'),
        kind: any(named: 'kind'),
        filePath: any(named: 'filePath'),
        consentReceiptId: any(named: 'consentReceiptId'),
        idempotencyKey: any(named: 'idempotencyKey'),
        onProgress: any(named: 'onProgress'),
      ),
    ).thenAnswer((_) async => _evidence());
    when(
      () => repository.createAdmissionDecision(
        workspaceId: any(named: 'workspaceId'),
        expectedWorkspaceVersion: any(named: 'expectedWorkspaceVersion'),
        issuedByName: any(named: 'issuedByName'),
        decision: any(named: 'decision'),
        receivedAt: any(named: 'receivedAt'),
        idempotencyKey: any(named: 'idempotencyKey'),
        issuedAt: any(named: 'issuedAt'),
        evidenceId: any(named: 'evidenceId'),
      ),
    ).thenThrow(
      const SuccessLabFailure(
        kind: SuccessLabFailureKind.server,
        code: 'HTTP_503',
        retryable: true,
      ),
    );
  });

  tearDown(() => controller.dispose());

  test('same retry keeps key; semantic payload change rotates it', () async {
    final receivedAt = DateTime.utc(2026, 7, 17);

    await controller.declareAdmission(
      issuedByName: 'Example University',
      decision: SuccessLabAdmissionDecision.admitted,
      receivedAt: receivedAt,
    );
    await controller.declareAdmission(
      issuedByName: 'Example University',
      decision: SuccessLabAdmissionDecision.admitted,
      receivedAt: receivedAt,
    );
    await controller.declareAdmission(
      issuedByName: 'Other University',
      decision: SuccessLabAdmissionDecision.admitted,
      receivedAt: receivedAt,
    );

    final keys = verify(
      () => repository.createAdmissionDecision(
        workspaceId: 'workspace-1',
        expectedWorkspaceVersion: 3,
        issuedByName: any(named: 'issuedByName'),
        decision: SuccessLabAdmissionDecision.admitted,
        receivedAt: receivedAt,
        idempotencyKey: captureAny(named: 'idempotencyKey'),
        issuedAt: null,
        evidenceId: 'evidence-1',
      ),
    ).captured.cast<String>();
    expect(keys, hasLength(3));
    expect(keys[0], keys[1]);
    expect(keys[2], isNot(keys[1]));
    verify(
      () => repository.uploadOutcomeEvidence(
        workspaceId: any(named: 'workspaceId'),
        kind: any(named: 'kind'),
        filePath: any(named: 'filePath'),
        consentReceiptId: any(named: 'consentReceiptId'),
        idempotencyKey: any(named: 'idempotencyKey'),
        onProgress: any(named: 'onProgress'),
      ),
    ).called(1);
  });

  test('complement is refused unless KPB requested information', () async {
    await controller.attachEvidence(
      outcomeType: 'admission',
      outcomeId: 'admission-1',
      lockVersion: 1,
      kind: SuccessLabOutcomeEvidenceKind.other,
      filePath: '/tmp/complement.pdf',
      verificationStatus: SuccessLabEvidenceVerificationStatus.pending,
    );

    expect(controller.failure?.code, 'OUTCOME_COMPLEMENT_NOT_REQUESTED');
    verifyNever(
      () => repository.attachOutcomeEvidence(
        outcomeType: any(named: 'outcomeType'),
        outcomeId: any(named: 'outcomeId'),
        expectedVersion: any(named: 'expectedVersion'),
        evidenceId: any(named: 'evidenceId'),
        idempotencyKey: any(named: 'idempotencyKey'),
      ),
    );
  });
}

SuccessLabOutcomeEvidence _evidence() => SuccessLabOutcomeEvidence(
      id: 'evidence-1',
      workspaceId: 'workspace-1',
      kind: SuccessLabOutcomeEvidenceKind.admissionDecision,
      kindWireValue: 'admission_decision',
      originalFileName: 'decision.pdf',
      mimeType: 'application/pdf',
      sizeBytes: 42,
      processingStatus: 'clean',
      createdAt: DateTime.utc(2026, 7, 17),
    );
