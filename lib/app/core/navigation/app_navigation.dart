import 'dart:developer' as dev;

import 'package:get/get.dart';

import '../config/app_routes.dart';

/// Single entry for navigating from untrusted external sources (FCM, OS URLs).
class AppNavigation {
  AppNavigation._();

  /// Navigates only when [rawRoute] normalizes to a registered route.
  static void toExternalRoute(dynamic rawRoute) {
    if (rawRoute is! String) return;
    final normalized = AppRoutes.normalizeExternalRoute(rawRoute);
    if (normalized == null) {
      dev.log('Navigation ignored unsupported route: $rawRoute');
      return;
    }
    try {
      Get.toNamed(normalized);
    } catch (e, st) {
      dev.log('Navigation failed for "$normalized": $e', stackTrace: st);
    }
  }
}
