import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';

import 'package:karatou/app/core/config/app_config.dart';
import 'package:karatou/app/core/controllers/app_controller.dart';
import 'package:karatou/app/core/models/app_models.dart';
import 'package:karatou/app/core/repositories/app_snapshot.dart';
import 'package:karatou/app/features/commercial/commercial_surface_screen.dart';

import '../../widget_test_helpers.dart';

CommercialLead _lead(
  String id,
  String name,
  String? tag, {
  int unread = 0,
  List<CommercialLeadDocument> documents = const <CommercialLeadDocument>[],
}) {
  return CommercialLead(
    id: id,
    referenceCode: 'KPB-$id',
    title: 'Dossier $name',
    status: 'submitted',
    studentName: name,
    studentLevel: 'L3 Éco',
    leadTag: tag,
    createdAt: DateTime(2026, 7, 1),
    updatedAt: DateTime(2026, 7, 8),
    unreadMessages: unread,
    documents: documents,
  );
}

void main() {
  group('CommercialSurfaceScreen', () {
    setUp(resetGetxSingleton);
    tearDown(() {
      AppConfig.enableRemoteSyncOverride = null;
      resetGetxSingleton();
    });

    Future<void> pump(WidgetTester tester, MockApiClient mock) async {
      tester.view.physicalSize = const Size(1200, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await pumpTestApp(
        tester,
        child: const CommercialSurfaceScreen(),
        initialSnapshot: AppSnapshot(
          localeCode: 'fr',
          hasCompletedOnboarding: true,
          profile: createTestProfile(accountType: AccountType.commercial),
        ),
        mockApiClient: mock,
      );
      AppConfig.enableRemoteSyncOverride = true;
      await Get.find<AppController>().fetchCommercialLeads();
      await Get.find<AppController>().fetchCommercialStats();
      await tester.pumpAndSettle();
    }

    testWidgets('renders the leads list + SLA + tab switch to performance',
        (tester) async {
      final mock = MockApiClient();
      when(() => mock.listCommercialLeads(
              email: any(named: 'email'), filter: any(named: 'filter')))
          .thenAnswer((_) async => [
                _lead('l1', 'Aïcha Diallo', null, unread: 2),
                _lead('l2', 'Ousmane Traoré', 'qualified'),
                _lead('l3', 'Ibrahima Ndiaye', 'converted'),
              ]);
      when(() => mock.getCommercialStats(email: any(named: 'email')))
          .thenAnswer((_) async => {
                'totalLeads': 18,
                'convertedLast30Days': 6,
                'avgFirstResponseMinutes': 40,
              });

      await pump(tester, mock);

      expect(find.text('Aïcha Diallo'), findsOneWidget);
      expect(find.text('commercial_leads_title'), findsOneWidget);

      // Switch to Performance → real stats bound.
      await tester.tap(find.text('commercial_nav_perf'));
      await tester.pumpAndSettle();
      expect(find.text('18'), findsOneWidget); // totalLeads
      expect(find.text('6'), findsOneWidget); // converted
    });

    testWidgets(
        'opening a lead → detail → convert calls updateCommercialLeadTag',
        (tester) async {
      final mock = MockApiClient();
      when(() => mock.listCommercialLeads(
              email: any(named: 'email'), filter: any(named: 'filter')))
          .thenAnswer((_) async => [_lead('l1', 'Aïcha Diallo', 'new')]);
      when(() => mock.getCommercialStats(email: any(named: 'email')))
          .thenAnswer((_) async => {'totalLeads': 1, 'convertedLast30Days': 0});
      when(() => mock.updateCommercialLead('l1',
              leadTag: any(named: 'leadTag'),
              discussionMotive: any(named: 'discussionMotive')))
          .thenAnswer((_) async => {'ok': true});

      await pump(tester, mock);
      await tester.tap(find.text('Aïcha Diallo'));
      await tester.pumpAndSettle();

      // Lead detail shows the "mark signed" action; tapping converts.
      await tester.tap(find.text('commercial_mark_signed'));
      await tester.pumpAndSettle();

      verify(() => mock.updateCommercialLead('l1',
          leadTag: 'converted',
          discussionMotive: any(named: 'discussionMotive'))).called(1);
    });

    testWidgets(
        'lead detail → validating a pending document calls reviewCommercialDocument + shows the status chip',
        (tester) async {
      final mock = MockApiClient();
      final leadWithDoc = _lead('l1', 'Aïcha Diallo', 'qualified', documents: [
        const CommercialLeadDocument(
          id: 'doc-1',
          title: 'Passeport',
          isProvided: true,
        ),
      ]);
      when(() => mock.listCommercialLeads(
          email: any(named: 'email'),
          filter: any(named: 'filter'))).thenAnswer((_) async => [leadWithDoc]);
      when(() => mock.getCommercialStats(email: any(named: 'email')))
          .thenAnswer((_) async => {'totalLeads': 1, 'convertedLast30Days': 0});
      when(() => mock
              .reviewCommercialDocument('doc-1', status: any(named: 'status')))
          .thenAnswer((_) async => {
                'id': 'doc-1',
                'caseId': 'l1',
                'title': 'Passeport',
                'isProvided': true,
                'reviewStatus': 'validated',
                'reviewedByName': 'Idriss',
                'reviewedAt': '2026-07-13T10:00:00.000Z',
              });

      await pump(tester, mock);
      await tester.tap(find.text('Aïcha Diallo'));
      await tester.pumpAndSettle();

      // The document + its three verdict buttons are rendered.
      expect(find.text('Passeport'), findsOneWidget);
      expect(find.text('commercial_doc_validate'), findsOneWidget);
      expect(find.text('commercial_doc_redo'), findsOneWidget);
      expect(find.text('commercial_doc_doubtful'), findsOneWidget);

      await tester.tap(find.text('commercial_doc_validate'));
      await tester.pumpAndSettle();

      verify(() => mock.reviewCommercialDocument('doc-1', status: 'validated'))
          .called(1);

      // After the verdict the buttons are replaced by the "Validé" chip.
      expect(find.text('commercial_doc_status_validated'), findsOneWidget);
      expect(find.text('commercial_doc_validate'), findsNothing);
    });
  });
}
