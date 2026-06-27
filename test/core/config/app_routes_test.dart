import 'package:flutter_test/flutter_test.dart';
import 'package:karatou/app/core/config/app_routes.dart';

void main() {
  group('AppRoutes.normalizeExternalRoute', () {
    test('returns known static routes', () {
      expect(
        AppRoutes.normalizeExternalRoute(AppRoutes.home),
        AppRoutes.home,
      );
      expect(
        AppRoutes.normalizeExternalRoute(AppRoutes.search),
        AppRoutes.search,
      );
      expect(
        AppRoutes.normalizeExternalRoute(AppRoutes.caseCreate),
        AppRoutes.caseCreate,
      );
    });

    test('resolves /scholarships even under the MVP lock (graceful)', () {
      // `/scholarships` always normalizes now: under the MVP lock its page
      // renders a "coming soon" placeholder, so a deep-link never dies
      // silently (it no longer returns null).
      expect(
        AppRoutes.normalizeExternalRoute(AppRoutes.scholarships),
        AppRoutes.scholarships,
      );
    });

    test('normalizes valid case detail route', () {
      expect(
        AppRoutes.normalizeExternalRoute('/cases/abc123'),
        '/cases/abc123',
      );
    });

    test('maps legacy create route to current route', () {
      expect(
        AppRoutes.normalizeExternalRoute('/cases/create'),
        AppRoutes.caseCreate,
      );
    });

    test('accepts surrounding whitespace from payloads', () {
      expect(
        AppRoutes.normalizeExternalRoute('   /search   '),
        AppRoutes.search,
      );
    });

    test('rejects invalid or unsupported routes', () {
      expect(AppRoutes.normalizeExternalRoute(null), isNull);
      expect(AppRoutes.normalizeExternalRoute(''), isNull);
      expect(AppRoutes.normalizeExternalRoute('cases/abc'), isNull);
      expect(AppRoutes.normalizeExternalRoute('/cases/'), isNull);
      expect(AppRoutes.normalizeExternalRoute('/cases/a/b'), isNull);
      expect(AppRoutes.normalizeExternalRoute('/unknown'), isNull);
    });
  });

  group('AppRoutes.pages', () {
    test('registers all critical named routes for external openability', () {
      final names = AppRoutes.pages.map((page) => page.name).toSet();

      expect(names, contains(AppRoutes.home));
      expect(names, contains(AppRoutes.search));
      expect(names, contains(AppRoutes.caseCreate));
      expect(names, contains(AppRoutes.caseDetail));
      // `/scholarships` is always registered (renders a "coming soon" under the
      // MVP lock) so deep-links to it resolve gracefully.
      expect(names, contains(AppRoutes.scholarships));
      expect(names.length, equals(5));
    });
  });
}
