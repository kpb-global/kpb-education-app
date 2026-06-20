import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:karatou/app/core/config/app_routes.dart';
import 'package:karatou/app/core/navigation/app_navigation.dart';

class _RouteProbe extends StatelessWidget {
  const _RouteProbe(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(
          label,
          key: ValueKey<String>('probe_$label'),
        ),
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
          name: AppRoutes.search,
          page: () => const _RouteProbe('search'),
        ),
        GetPage(
          name: AppRoutes.scholarships,
          page: () => const _RouteProbe('scholarships'),
        ),
        GetPage(
          name: AppRoutes.caseCreate,
          page: () => const _RouteProbe('case_create'),
        ),
        GetPage(
          name: AppRoutes.caseDetail,
          page: () => _RouteProbe('case_${Get.parameters['id']}'),
        ),
      ],
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('AppNavigation.toExternalRoute', () {
    setUp(() {
      Get.testMode = true;
    });

    tearDown(() {
      Get.reset();
      Get.testMode = false;
    });

    testWidgets('ignores non-string payloads from external sources',
        (tester) async {
      await _pumpRoutingHarness(tester);
      expect(find.byKey(const ValueKey('probe_home')), findsOneWidget);

      AppNavigation.toExternalRoute(42);
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('probe_home')), findsOneWidget);
    });

    testWidgets('ignores unsupported external routes', (tester) async {
      await _pumpRoutingHarness(tester);
      expect(find.byKey(const ValueKey('probe_home')), findsOneWidget);

      AppNavigation.toExternalRoute('/non-existent');
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('probe_home')), findsOneWidget);
    });

    testWidgets('navigates to normalized legacy case create route',
        (tester) async {
      await _pumpRoutingHarness(tester);

      AppNavigation.toExternalRoute('/cases/create');
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('probe_case_create')), findsOneWidget);
    });

    testWidgets('navigates to case detail dynamic route', (tester) async {
      await _pumpRoutingHarness(tester);

      AppNavigation.toExternalRoute('/cases/abc123');
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('probe_case_abc123')), findsOneWidget);
    });
  });
}
