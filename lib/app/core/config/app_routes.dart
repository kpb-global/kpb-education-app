import 'package:get/get.dart';
import '../models/app_models.dart';
import '../../features/alumni/alumni_directory_screen.dart';
import '../../features/cases/case_create_screen.dart';
import '../../features/cases/case_detail_screen.dart';
import '../../features/deadlines/deadline_calendar_screen.dart';
import '../../features/eligibility/eligibility_simulator_screen.dart';
import '../../features/orientation/orientation_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/salon/salon_screen.dart';
import '../../features/saved/saved_screen.dart';
import '../../features/scholarships/live_scholarships_screen.dart';
import '../../features/scholarships/scholarship_detail_screen.dart';
import '../../features/search/search_screen.dart';
import '../../features/services/service_packages_screen.dart';
import '../../features/shell/app_shell.dart';

/// Define named routes specifically for handling deep links and push notifications.
///
/// Most of the app can still use `Get.to(() => Screen())` for internal navigation,
/// but routes defined here allow external URLs (like `kpb://cases/123`) to open
/// specific screens directly.
class AppRoutes {
  static const String home = '/';
  static const String search = '/search';
  static const String scholarships = '/scholarships';
  static const String scholarshipDetail = '/scholarships/:id';
  static const String _scholarshipPrefix = '/scholarships/';

  static String scholarshipDetailPath(String id) =>
      '$_scholarshipPrefix${Uri.encodeComponent(id)}';
  // High-intent re-engagement targets (KPB-63): named so push/deep-links can
  // land on the right screen instead of dumping the user on Home.
  static const String orientation = '/orientation';
  static const String eligibility = '/eligibility';
  static const String saved = '/saved';
  static const String deadlines = '/deadlines';
  static const String alumni = '/alumni';
  static const String salon = '/salon';
  static const String services = '/services';
  static const String profile = '/profile';

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

    if (route.startsWith(_scholarshipPrefix)) {
      final scholarshipId = route.substring(_scholarshipPrefix.length);
      if (scholarshipId.isEmpty || scholarshipId.contains('/')) return null;
      return '$_scholarshipPrefix$scholarshipId';
    }

    final known = <String>{
      home,
      search,
      caseCreate,
      orientation,
      eligibility,
      saved,
      deadlines,
      alumni,
      salon,
      services,
      profile,
      // Scholarship-opening push notifications land on this acquisition screen.
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
    GetPage(
      name: scholarships,
      page: () => const LiveScholarshipsScreen(),
    ),
    GetPage(
      name: scholarshipDetail,
      page: () {
        final scholarshipId = Get.parameters['id'];
        if (scholarshipId == null || scholarshipId.isEmpty) {
          return const LiveScholarshipsScreen();
        }
        final initial = Get.arguments;
        return ScholarshipDetailScreen(
          scholarshipId: scholarshipId,
          initialScholarship: initial is LiveScholarshipModel ? initial : null,
        );
      },
    ),
    // High-intent re-engagement destinations (KPB-63). Each is a standalone,
    // pushable screen with its own app bar.
    GetPage(name: orientation, page: () => const OrientationScreen()),
    GetPage(name: eligibility, page: () => const EligibilitySimulatorScreen()),
    GetPage(name: saved, page: () => const SavedScreen()),
    GetPage(name: deadlines, page: () => const DeadlineCalendarScreen()),
    GetPage(name: alumni, page: () => const AlumniDirectoryScreen()),
    GetPage(name: salon, page: () => const SalonScreen()),
    GetPage(name: services, page: () => const ServicePackagesScreen()),
    GetPage(name: profile, page: () => const ProfileScreen()),
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
