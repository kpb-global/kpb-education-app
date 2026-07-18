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
import '../../features/success_lab/success_lab_list_screen.dart';
import '../../features/success_lab/success_lab_schedule_screen.dart';
import '../../features/success_lab/success_lab_submission_screen.dart';
import '../../features/success_lab/success_lab_outcome_screen.dart';
import '../../features/success_lab/success_lab_diagnostic_screen.dart';
import '../../features/success_lab/success_lab_study_review_screen.dart';
import '../../features/success_lab/success_lab_workspace_screen.dart';

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
  static const String successLab = '/success-lab';
  static const String successLabWorkspace = '/success-lab/:workspaceId';
  static const String successLabDiagnostic =
      '/success-lab/:workspaceId/diagnostic';
  static const String successLabStudyReview =
      '/success-lab/:workspaceId/study-review';
  static const String successLabSchedule = '/success-lab/:workspaceId/schedule';
  static const String successLabSubmission =
      '/success-lab/:workspaceId/submission';
  static const String successLabOutcome = '/success-lab/:workspaceId/outcome';
  static const String _successLabPrefix = '/success-lab/';

  static String scholarshipDetailPath(String id) =>
      '$_scholarshipPrefix${Uri.encodeComponent(id)}';

  static String successLabWorkspacePath(String workspaceId) =>
      '$_successLabPrefix${Uri.encodeComponent(workspaceId)}';

  static String successLabDiagnosticPath(String workspaceId) =>
      '${successLabWorkspacePath(workspaceId)}/diagnostic';

  static String successLabStudyReviewPath(String workspaceId) =>
      '${successLabWorkspacePath(workspaceId)}/study-review';

  static String successLabSchedulePath(String workspaceId) =>
      '${successLabWorkspacePath(workspaceId)}/schedule';

  static String successLabSubmissionPath(String workspaceId) =>
      '${successLabWorkspacePath(workspaceId)}/submission';

  static String successLabOutcomePath(String workspaceId) =>
      '${successLabWorkspacePath(workspaceId)}/outcome';
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

    if (route.startsWith(_successLabPrefix)) {
      final tail = route.substring(_successLabPrefix.length);
      final segments = tail.split('/');
      if (segments.length == 2 && segments.first.isNotEmpty) {
        if (segments.last == 'diagnostic' ||
            segments.last == 'study-review' ||
            segments.last == 'schedule' ||
            segments.last == 'submission' ||
            segments.last == 'outcome') {
          return '$_successLabPrefix${segments.first}/${segments.last}';
        }
        return null;
      }
      if (segments.length != 1 || segments.first.isEmpty) return null;
      return '$_successLabPrefix${segments.first}';
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
      successLab,
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
    // Live-scholarships aggregator (unlocked for launch): serves the real
    // scraped /scholarships feed, with an honest empty state when the feed is
    // empty. Community stays MVP-gated (no real forum content yet).
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
    // Success Lab stays a pushed, deep-linkable workflow. It deliberately does
    // not add a sixth shell tab to the five-tab student navigation.
    GetPage(
      name: successLab,
      page: () => const SuccessLabListScreen(),
    ),
    GetPage(
      name: successLabWorkspace,
      page: () {
        final workspaceId = Get.parameters['workspaceId'];
        if (workspaceId == null || workspaceId.isEmpty) {
          return const SuccessLabListScreen();
        }
        return SuccessLabWorkspaceScreen(workspaceId: workspaceId);
      },
    ),
    GetPage(
      name: successLabDiagnostic,
      page: () {
        final workspaceId = Get.parameters['workspaceId'];
        if (workspaceId == null || workspaceId.isEmpty) {
          return const SuccessLabListScreen();
        }
        return SuccessLabDiagnosticScreen(workspaceId: workspaceId);
      },
    ),
    GetPage(
      name: successLabStudyReview,
      page: () {
        final workspaceId = Get.parameters['workspaceId'];
        if (workspaceId == null || workspaceId.isEmpty) {
          return const SuccessLabListScreen();
        }
        return SuccessLabStudyReviewScreen(workspaceId: workspaceId);
      },
    ),
    GetPage(
      name: successLabSchedule,
      page: () {
        final workspaceId = Get.parameters['workspaceId'];
        if (workspaceId == null || workspaceId.isEmpty) {
          return const SuccessLabListScreen();
        }
        return SuccessLabScheduleScreen(workspaceId: workspaceId);
      },
    ),
    GetPage(
      name: successLabSubmission,
      page: () {
        final workspaceId = Get.parameters['workspaceId'];
        if (workspaceId == null || workspaceId.isEmpty) {
          return const SuccessLabListScreen();
        }
        return SuccessLabSubmissionScreen(workspaceId: workspaceId);
      },
    ),
    GetPage(
      name: successLabOutcome,
      page: () {
        final workspaceId = Get.parameters['workspaceId'];
        if (workspaceId == null || workspaceId.isEmpty) {
          return const SuccessLabListScreen();
        }
        return SuccessLabOutcomeScreen(workspaceId: workspaceId);
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
