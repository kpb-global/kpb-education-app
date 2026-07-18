import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:karatou/app/core/config/app_routes.dart';
import 'package:karatou/app/core/services/deep_link_service.dart';

/// Minimal screen that stamps a findable key so tests can assert which route is
/// on top without pulling in the real (controller-heavy) screens.
class _RouteProbe extends StatelessWidget {
  const _RouteProbe(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(label, key: ValueKey<String>('probe_$label')),
      ),
    );
  }
}

Future<void> _pumpRoutingHarness(WidgetTester tester) async {
  await tester.pumpWidget(
    GetMaterialApp(
      initialRoute: AppRoutes.home,
      getPages: [
        GetPage(name: AppRoutes.home, page: () => const _RouteProbe('home')),
        GetPage(
          name: AppRoutes.scholarships,
          page: () => const _RouteProbe('scholarships'),
        ),
        GetPage(
          name: AppRoutes.scholarshipDetail,
          page: () => _RouteProbe('scholarship_${Get.parameters['id']}'),
        ),
        GetPage(
          name: AppRoutes.orientation,
          page: () => const _RouteProbe('orientation'),
        ),
        GetPage(
          name: AppRoutes.deadlines,
          page: () => const _RouteProbe('deadlines'),
        ),
        GetPage(
          name: AppRoutes.profile,
          page: () => const _RouteProbe('profile'),
        ),
      ],
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('DeepLinkService.resolveRoute', () {
    test('maps host-style kpb:// links to their static routes', () {
      expect(
        DeepLinkService.resolveRoute(Uri.parse('kpb://scholarships')),
        AppRoutes.scholarships,
      );
      expect(
        DeepLinkService.resolveRoute(Uri.parse('kpb://orientation')),
        AppRoutes.orientation,
      );
      expect(
        DeepLinkService.resolveRoute(Uri.parse('kpb://deadlines')),
        AppRoutes.deadlines,
      );
      expect(
        DeepLinkService.resolveRoute(Uri.parse('kpb://profile')),
        AppRoutes.profile,
      );
      expect(
        DeepLinkService.resolveRoute(Uri.parse('kpb://saved')),
        AppRoutes.saved,
      );
    });

    test('maps parameterized links (host + path segments)', () {
      expect(
        DeepLinkService.resolveRoute(Uri.parse('kpb://scholarships/sch-42')),
        '/scholarships/sch-42',
      );
      expect(
        DeepLinkService.resolveRoute(Uri.parse('kpb://cases/c-7')),
        '/cases/c-7',
      );
      expect(
        DeepLinkService.resolveRoute(Uri.parse('kpb://success-lab/w1')),
        '/success-lab/w1',
      );
      expect(
        DeepLinkService.resolveRoute(
          Uri.parse('kpb://success-lab/w1/diagnostic'),
        ),
        '/success-lab/w1/diagnostic',
      );
    });

    test('folds the triple-slash form (empty host) into the same route', () {
      expect(
        DeepLinkService.resolveRoute(Uri.parse('kpb:///scholarships')),
        AppRoutes.scholarships,
      );
      expect(
        DeepLinkService.resolveRoute(Uri.parse('kpb:///scholarships/sch-42')),
        '/scholarships/sch-42',
      );
    });

    test('drops query strings and fragments', () {
      expect(
        DeepLinkService.resolveRoute(
          Uri.parse('kpb://scholarships/sch-42?ref=email#top'),
        ),
        '/scholarships/sch-42',
      );
    });

    test('resolves a bare kpb:// to home', () {
      expect(
        DeepLinkService.resolveRoute(Uri.parse('kpb://')),
        AppRoutes.home,
      );
    });

    test('returns null for unsupported or malformed links', () {
      // Unknown top-level target.
      expect(DeepLinkService.resolveRoute(Uri.parse('kpb://unknown')), isNull);
      // Nested scholarship id is rejected by the route normalizer.
      expect(
        DeepLinkService.resolveRoute(Uri.parse('kpb://scholarships/a/b')),
        isNull,
      );
      // supabase's OAuth redirect scheme stays out of app navigation.
      expect(
        DeepLinkService.resolveRoute(
          Uri.parse('io.supabase.kpbeducation://login-callback'),
        ),
        isNull,
      );
    });
  });

  group('DeepLinkService.handleUri (end-to-end flow)', () {
    setUp(() {
      Get.testMode = true;
    });

    tearDown(() {
      Get.reset();
      Get.testMode = false;
    });

    testWidgets('navigates to the mapped screen for a supported link',
        (tester) async {
      await _pumpRoutingHarness(tester);
      expect(find.byKey(const ValueKey('probe_home')), findsOneWidget);

      DeepLinkService.instance.handleUri(Uri.parse('kpb://orientation'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('probe_orientation')), findsOneWidget);
    });

    testWidgets('opens a parameterized detail route', (tester) async {
      await _pumpRoutingHarness(tester);

      DeepLinkService.instance
          .handleUri(Uri.parse('kpb://scholarships/sch-42'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('probe_scholarship_sch-42')),
        findsOneWidget,
      );
    });

    testWidgets('ignores an unsupported link and stays on home',
        (tester) async {
      await _pumpRoutingHarness(tester);

      DeepLinkService.instance.handleUri(Uri.parse('kpb://unknown'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('probe_home')), findsOneWidget);
      expect(find.byKey(const ValueKey('probe_orientation')), findsNothing);
    });

    testWidgets('a bare kpb:// stays on home without stacking a second shell',
        (tester) async {
      await _pumpRoutingHarness(tester);

      DeepLinkService.instance.handleUri(Uri.parse('kpb://'));
      await tester.pumpAndSettle();

      // Exactly one home route — a stacked duplicate would surface a second
      // probe_home in the (retained) route below.
      expect(find.byKey(const ValueKey('probe_home')), findsOneWidget);
    });
  });
}
