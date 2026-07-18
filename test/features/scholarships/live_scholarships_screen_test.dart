import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';

import 'package:karatou/app/core/config/app_config.dart';
import 'package:karatou/app/core/controllers/app_controller.dart';
import 'package:karatou/app/core/models/app_models.dart';
import 'package:karatou/app/core/repositories/app_snapshot.dart';
import 'package:karatou/app/core/translations/app_translations.dart';
import 'package:karatou/app/features/scholarships/live_scholarships_screen.dart';
import 'package:karatou/app/features/scholarships/scholarship_detail_screen.dart';

import '../../widget_test_helpers.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Smoke tests for the App-engagement restyle (PR4): the live scholarships list
// + detail sheet. Verify the restyled row binds to REAL model fields (name,
// funding, a J-<days> countdown computed from deadlineAt), that the "Deadline
// soon" chip fires for a near deadline, that the real per-scholarship alert
// action is rendered (backed by the alert-subscription API), and that opening
// the detail surfaces the external "Official application form" CTA.
// ─────────────────────────────────────────────────────────────────────────────

Map<String, dynamic> _scholarshipJson({bool withCycle = false}) =>
    <String, dynamic>{
      'id': 'mext-2027',
      'title': 'MEXT Japan Scholarship',
      'countryName': 'Japan',
      'fundingType': 'fully_funded',
      'applicationRequirement': 'separate_application',
      'description':
          'Full Japanese government scholarship for international students.',
      'advantages': <String>['Full tuition waiver', 'Monthly stipend'],
      'eligibility': <String>['Under 35 years old', 'Strong academic record'],
      'level': 'Master',
      'deadlineLabel': 'May 2027',
      'deadlineAt': DateTime.now()
          .add(const Duration(days: 5, hours: 2))
          .toIso8601String(),
      'applicationUrl': 'https://example.org/mext/apply',
      'sourceUrl': 'https://example.org/mext',
      'tags': <String>['scholarship'],
      'matchScore': 82,
      'applicationSteps': <dynamic>[],
      if (withCycle)
        'currentCycle': <String, dynamic>{
          'id': 'mext-2027-cycle',
          'academicYear': '2027-2028',
          'status': 'open',
          'dateConfidence': 'confirmed',
          'opensAt': DateTime.now()
              .subtract(const Duration(days: 1))
              .toIso8601String(),
          'closesAt':
              DateTime.now().add(const Duration(days: 30)).toIso8601String(),
        },
    };

Map<String, dynamic> _access(bool enabled, {String? reason}) =>
    <String, dynamic>{
      'enabled': enabled,
      'reasons': <String>[if (reason != null) reason],
    };

Future<void> _seed(MockApiClient apiClient) async {
  AppConfig.enableRemoteSyncOverride = false;
  final controller = AppController(
    repository: FakeRepository(
      snapshot: AppSnapshot(
        localeCode: 'fr',
        hasCompletedOnboarding: true,
        profile: createTestProfile(),
      ),
    ),
    apiClient: apiClient,
  );
  await controller.hydrate();
  Get.put<AppController>(controller, permanent: true);
}

void _stubFetch(
  MockApiClient mock,
  List<dynamic> items, {
  Map<String, dynamic>? successLabAccess,
}) {
  when(() => mock.fetchLiveScholarships(
        lang: any(named: 'lang'),
        level: any(named: 'level'),
        fieldIds: any(named: 'fieldIds'),
        fundingType: any(named: 'fundingType'),
      )).thenAnswer((_) async => items);
  when(() => mock.fetchScholarshipAlerts()).thenAnswer((_) async => <String>{});
  when(() => mock.getSuccessLabAccess()).thenAnswer(
    (_) async => successLabAccess ?? _access(false, reason: 'feature_disabled'),
  );
}

void _stubDetail(
  MockApiClient mock,
  LiveScholarshipModel scholarship,
) {
  when(
    () => mock.fetchLiveScholarshipDetailWithFallback(
      scholarshipId: any(named: 'scholarshipId'),
      lang: any(named: 'lang'),
      initial: any(named: 'initial'),
    ),
  ).thenAnswer((_) async => scholarship);
}

Widget _wrap(Widget home) => GetMaterialApp(
      translations: AppTranslations(),
      locale: const Locale('fr'),
      fallbackLocale: const Locale('fr'),
      home: home,
    );

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    resetGetxSingleton();
  });
  tearDown(resetGetxSingleton);

  testWidgets(
      'restyled list renders a real scholarship row (name, funding, J-days, '
      'soon chip) and the real alert action', (tester) async {
    final mock = MockApiClient();
    _stubFetch(mock, <dynamic>[_scholarshipJson()]);
    await _seed(mock);

    await tester.pumpWidget(_wrap(LiveScholarshipsScreen(apiClient: mock)));
    await tester.pumpAndSettle();

    // Real data bound from the model.
    expect(find.text('MEXT Japan Scholarship'), findsOneWidget);
    expect(find.text('Entièrement financée'), findsWidgets); // fundingType chip
    // J-<days> (localized "days until") is computed from the real deadlineAt
    // (~5 days out); FR locale renders "J-", EN renders "D-".
    expect(find.textContaining('J-'), findsWidgets);
    // Near deadline (<= 14 days) surfaces the amber "soon" chip.
    expect(find.text('Deadline imminente'), findsOneWidget);
    // The trailing action is backed by the alert-subscription API.
    expect(find.text('M\'avertir'), findsOneWidget);
    expect(find.byIcon(Icons.notifications), findsNothing);
    expect(find.byIcon(Icons.notifications_none_rounded), findsOneWidget);
    expect(find.byIcon(Icons.notifications_active_rounded), findsNothing);

    expect(tester.takeException(), isNull);
  });

  for (final reason in <String>[
    'feature_disabled',
    'rollout_excluded',
    'country_not_eligible',
  ]) {
    testWidgets('Success Lab list entry stays hidden for $reason',
        (tester) async {
      final mock = MockApiClient();
      _stubFetch(
        mock,
        <dynamic>[_scholarshipJson()],
        successLabAccess: _access(false, reason: reason),
      );
      await _seed(mock);

      await tester.pumpWidget(_wrap(LiveScholarshipsScreen(apiClient: mock)));
      await tester.pumpAndSettle();

      expect(
        find.byKey(
          const ValueKey<String>('scholarships-success-lab-entry'),
        ),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Success Lab list entry appears only after server approval',
      (tester) async {
    final mock = MockApiClient();
    _stubFetch(
      mock,
      <dynamic>[_scholarshipJson()],
      successLabAccess: _access(true),
    );
    await _seed(mock);

    await tester.pumpWidget(_wrap(LiveScholarshipsScreen(apiClient: mock)));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('scholarships-success-lab-entry')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('list entry revalidates access before navigation',
      (tester) async {
    final mock = MockApiClient();
    _stubFetch(mock, <dynamic>[_scholarshipJson()]);
    var accessChecks = 0;
    when(() => mock.getSuccessLabAccess()).thenAnswer((_) async {
      accessChecks += 1;
      return accessChecks == 1
          ? _access(true)
          : _access(false, reason: 'rollout_excluded');
    });
    await _seed(mock);

    await tester.pumpWidget(_wrap(LiveScholarshipsScreen(apiClient: mock)));
    await tester.pumpAndSettle();

    final entry = find.byKey(
      const ValueKey<String>('scholarships-success-lab-entry'),
    );
    expect(entry, findsOneWidget);

    await tester.tap(entry);
    await tester.pumpAndSettle();

    expect(accessChecks, 2);
    expect(entry, findsNothing);
    expect(find.byType(LiveScholarshipsScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'tapping a row opens the detail sheet with the external application CTA',
      (tester) async {
    final mock = MockApiClient();
    _stubFetch(mock, <dynamic>[_scholarshipJson()]);
    await _seed(mock);

    await tester.pumpWidget(_wrap(LiveScholarshipsScreen(apiClient: mock)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('MEXT Japan Scholarship'));
    await tester.pumpAndSettle();

    // Real description + funding tile carried into the detail sheet (top-visible).
    expect(find.textContaining('Full Japanese government'), findsOneWidget);
    expect(find.text('FINANCEMENT'), findsOneWidget);

    // External application form button (opens the real applicationUrl) — it sits
    // below the benefits/eligibility sections, so scroll it into view first.
    final ctaFinder = find.text('Formulaire officiel');
    await tester.scrollUntilVisible(
      ctaFinder,
      250,
      scrollable: find.byType(Scrollable).last,
    );
    expect(ctaFinder, findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  testWidgets('empty results render the honest empty state', (tester) async {
    final mock = MockApiClient();
    _stubFetch(mock, <dynamic>[]);
    await _seed(mock);

    await tester.pumpWidget(_wrap(LiveScholarshipsScreen(apiClient: mock)));
    await tester.pumpAndSettle();

    expect(find.text('Aucune bourse trouvée'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('guide CTA opens the store-safe informational page',
      (tester) async {
    final mock = MockApiClient();
    _stubFetch(mock, <dynamic>[]);
    await _seed(mock);

    await tester.pumpWidget(_wrap(LiveScholarshipsScreen(apiClient: mock)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('En savoir plus'));
    await tester.pumpAndSettle();

    expect(find.text('Ce que tu vas apprendre'), findsOneWidget);
    expect(find.textContaining('20.000'), findsNothing);
    expect(find.textContaining('10.000'), findsNothing);
    expect(find.textContaining('Chariow'), findsNothing);
    expect(find.text('Acheter'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('detail CTA is hidden when country eligibility is denied',
      (tester) async {
    final mock = MockApiClient();
    final scholarship = LiveScholarshipModel.fromJson(
      _scholarshipJson(withCycle: true),
    );
    _stubFetch(
      mock,
      <dynamic>[],
      successLabAccess: _access(false, reason: 'country_not_eligible'),
    );
    _stubDetail(mock, scholarship);
    await _seed(mock);

    await tester.pumpWidget(
      _wrap(
        ScholarshipDetailScreen(
          scholarshipId: scholarship.id,
          initialScholarship: scholarship,
          apiClient: mock,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('scholarship-start-success-lab')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('detail CTA appears only after effective access is approved',
      (tester) async {
    final mock = MockApiClient();
    final scholarship = LiveScholarshipModel.fromJson(
      _scholarshipJson(withCycle: true),
    );
    _stubFetch(
      mock,
      <dynamic>[],
      successLabAccess: _access(true),
    );
    _stubDetail(mock, scholarship);
    await _seed(mock);

    await tester.pumpWidget(
      _wrap(
        ScholarshipDetailScreen(
          scholarshipId: scholarship.id,
          initialScholarship: scholarship,
          apiClient: mock,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('scholarship-start-success-lab')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('detail CTA revalidates access before workspace creation',
      (tester) async {
    final mock = MockApiClient();
    final scholarship = LiveScholarshipModel.fromJson(
      _scholarshipJson(withCycle: true),
    );
    _stubFetch(mock, <dynamic>[]);
    _stubDetail(mock, scholarship);
    var accessChecks = 0;
    when(() => mock.getSuccessLabAccess()).thenAnswer((_) async {
      accessChecks += 1;
      return accessChecks == 1
          ? _access(true)
          : _access(false, reason: 'feature_disabled');
    });
    await _seed(mock);

    await tester.pumpWidget(
      _wrap(
        ScholarshipDetailScreen(
          scholarshipId: scholarship.id,
          initialScholarship: scholarship,
          apiClient: mock,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final cta = find.byKey(
      const ValueKey<String>('scholarship-start-success-lab'),
    );
    expect(cta, findsOneWidget);
    await tester.ensureVisible(cta);
    await tester.tap(cta);
    await tester.pumpAndSettle();

    expect(accessChecks, 2);
    expect(cta, findsNothing);
    verifyNever(
      () => mock.createSuccessLabWorkspace(
        scholarshipId: any(named: 'scholarshipId'),
        cycleId: any(named: 'cycleId'),
        idempotencyKey: any(named: 'idempotencyKey'),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
