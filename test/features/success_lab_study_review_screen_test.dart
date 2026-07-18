import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';

import 'package:karatou/app/core/controllers/success_lab_study_review_controller.dart';
import 'package:karatou/app/core/models/success_lab.dart';
import 'package:karatou/app/core/repositories/success_lab_repository.dart';
import 'package:karatou/app/core/translations/app_translations.dart';
import 'package:karatou/app/features/success_lab/success_lab_study_review_screen.dart';

class _MockSuccessLabRepository extends Mock implements SuccessLabRepository {}

void main() {
  testWidgets('tracking and complement UI survive 200% text scale',
      (tester) async {
    final controller = SuccessLabStudyReviewController(
      repository: _MockSuccessLabRepository(),
      workspaceId: 'workspace-1',
      language: 'fr',
    )
      ..phase = SuccessLabStudyReviewPhase.tracking
      ..request = _request()
      ..artifacts = const <SuccessLabArtifact>[_newArtifact]
      ..selectedVersionIds = <String>{'version-1'};
    addTearDown(controller.dispose);
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('fr'),
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: SuccessLabStudyReviewScreen(
            workspaceId: 'workspace-1',
            controller: controller,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
        find.text('Informations complémentaires nécessaires'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('Ajouter un essai corrigé.'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -1600));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('success-lab-submit-complement')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

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

SuccessLabStudyReviewRequest _request() => SuccessLabStudyReviewRequest(
      id: 'review-1',
      workspaceId: 'workspace-1',
      status: SuccessLabStudyReviewStatus.moreInformationNeeded,
      statusWireValue: 'more_information_needed',
      nextAction: SuccessLabStudyReviewNextAction.provideMoreInformation,
      nextActionWireValue: 'provide_more_information',
      requestNumber: 1,
      version: 3,
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
      updatedAt: DateTime.utc(2026, 7, 18),
      submittedAt: DateTime.utc(2026, 7, 17),
    );
