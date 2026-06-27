import 'package:get/get.dart';
import 'app_config.dart';
import '../../features/cases/case_create_screen.dart';
import '../../features/cases/case_detail_screen.dart';
import '../../features/scholarships/live_scholarships_screen.dart';
import '../../features/search/search_screen.dart';
import '../../features/shell/app_shell.dart';
import '../ui/components/coming_soon_screen.dart';

/// Define named routes specifically for handling deep links and push notifications.
///
/// Most of the app can still use `Get.to(() => Screen())` for internal navigation,
/// but routes defined here allow external URLs (like `kpb://cases/123`) to open
/// specific screens directly.
class AppRoutes {
  static const String home = '/';
  static const String search = '/search';
  static const String scholarships = '/scholarships';
  /// Intentionally not under `/cases/...` so it never collides with `/cases/:id` (e.g. id "create").
  static const String caseCreate = '/new-case';
  static const String caseDetail = '/cases/:id';
  static const String _casePrefix = '/cases/';
  static const String _legacyCaseCreate = '/cases/create';

  /// Normalizes external route payloads (quick actions, deep links, FCM).
  /// Returns null when route is unsupported/invalid.
  static String? normalizeExternalRoute(String? rawRoute) {
    final route = rawRoute?.trim();
    if (route == null || route.isEmpty || !route.startsWith('/')) {
      return null;
    }

    // Backward-compatibility for older payloads sent before case-create route rename.
    if (route == _legacyCaseCreate) {
      return caseCreate;
    }

    if (route.startsWith(_casePrefix)) {
      final caseId = route.substring(_casePrefix.length);
      // Reject empty or nested ids (`/cases/` or `/cases/a/b`).
      if (caseId.isEmpty || caseId.contains('/')) return null;
      return '/cases/$caseId';
    }

    final known = <String>{
      home,
      search,
      caseCreate,
      // `/scholarships` always resolves: the live aggregator is a V1.1+ module,
      // but under the MVP lock the route renders a graceful "coming soon" (see
      // pages) so a push to it never dies silently.
      scholarships,
    };
    if (known.contains(route)) return route;
    return null;
  }

  static final List<GetPage> pages = [
    GetPage(
      name: home,
      page: () => const AppShell(),
    ),
    GetPage(
      name: search,
      page: () => const SearchScreen(),
    ),
    // Live-scholarships aggregator is a V1.1+ module. The route is always
    // registered so external deep-links resolve; under the MVP lock it renders
    // a graceful "coming soon" instead of the live aggregator.
    GetPage(
      name: scholarships,
      page: () => AppConfig.mvpOnly
          ? const ComingSoonScreen()
          : const LiveScholarshipsScreen(),
    ),
    GetPage(
      name: caseCreate,
      page: () => const CaseCreateScreen(),
    ),
    GetPage(
      name: caseDetail,
      page: () {
        final caseId = Get.parameters['id'];
        if (caseId == null) return const AppShell();
        return CaseDetailScreen(caseId: caseId);
      },
    ),
  ];
}
