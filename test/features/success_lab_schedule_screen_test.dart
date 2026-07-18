import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';

import 'package:karatou/app/core/controllers/success_lab_schedule_controller.dart';
import 'package:karatou/app/core/models/success_lab.dart';
import 'package:karatou/app/core/repositories/success_lab_repository.dart';
import 'package:karatou/app/core/translations/app_translations.dart';
import 'package:karatou/app/features/success_lab/success_lab_schedule_screen.dart';

class _MockSuccessLabRepository extends Mock implements SuccessLabRepository {}

void main() {
  testWidgets(
      'slot list survives 200% text and names device versus source timezone',
      (tester) async {
    final repository = _MockSuccessLabRepository();
    when(() => repository.canUseNetwork).thenReturn(true);
    when(repository.fetchAccess).thenAnswer(
      (_) async => const SuccessLabAccess(
        enabled: true,
        counsellorStudyEnabled: true,
      ),
    );
    when(() => repository.fetchActiveStudyReview('workspace-1'))
        .thenAnswer((_) async => _request());
    when(() => repository.fetchStudyReviewSlotOffers('review-1'))
        .thenAnswer((_) async => _offers());
    final controller = SuccessLabScheduleController(
      repository: repository,
      workspaceId: 'workspace-1',
    );
    addTearDown(controller.dispose);
    final semantics = tester.ensureSemantics();
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('fr'),
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: SuccessLabScheduleScreen(
            workspaceId: 'workspace-1',
            controller: controller,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('Fuseau d’origine : Africa/Niamey'),
        findsOneWidget);
    expect(
        find.textContaining('Heure affichée : ton appareil'), findsOneWidget);
    final radio =
        find.byKey(const ValueKey<String>('success-lab-slot-offer-1'));
    await tester.ensureVisible(radio);
    await tester.pumpAndSettle();
    await tester.tap(radio);
    await tester.pump();
    final scrollable = tester.state<ScrollableState>(
      find.byType(Scrollable).first,
    );
    scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
    await tester.pumpAndSettle();
    final confirm = find.byKey(
      const ValueKey<String>('success-lab-confirm-slot'),
    );
    expect(confirm, findsOneWidget);
    expect(tester.getSize(confirm).height, greaterThanOrEqualTo(48));
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}

SuccessLabStudyReviewRequest _request() => SuccessLabStudyReviewRequest(
      id: 'review-1',
      workspaceId: 'workspace-1',
      status: SuccessLabStudyReviewStatus.callOffered,
      statusWireValue: 'call_offered',
      nextAction: SuccessLabStudyReviewNextAction.chooseSlot,
      nextActionWireValue: 'choose_slot',
      requestNumber: 1,
      version: 3,
      timezone: 'Africa/Niamey',
      missingItems: const <String>[],
      sharedVersions: const <SuccessLabStudyReviewSharedVersion>[],
      createdAt: DateTime.utc(2026, 7, 17),
      updatedAt: DateTime.utc(2026, 7, 18),
      submittedAt: DateTime.utc(2026, 7, 17),
    );

SuccessLabStudyReviewSlotOffers _offers() => SuccessLabStudyReviewSlotOffers(
      reviewRequestId: 'review-1',
      reviewRequestVersion: 3,
      timezone: 'Africa/Niamey',
      offers: <SuccessLabStudyReviewSlotOffer>[
        SuccessLabStudyReviewSlotOffer(
          slotOfferId: 'offer-1',
          slotId: 'slot-1',
          startsAt: DateTime.utc(2026, 7, 20, 9),
          endsAt: DateTime.utc(2026, 7, 20, 9, 30),
          timezone: 'Africa/Niamey',
          expiresAt: DateTime.utc(2026, 7, 19, 9),
          counsellorName: 'Aïcha KPB',
        ),
      ],
    );
