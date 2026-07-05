import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../navigation/force_update_screen.dart';
import '../repositories/app_api_client.dart';
import '../utils/version_utils.dart';

/// Force-update gate: compares the installed build against the backend's
/// `/config/app` minimum supported version and replaces the whole navigation
/// stack with [ForceUpdateScreen] when the build is too old.
///
/// Every failure path (offline, endpoint missing, malformed payload) fails
/// open — an update gate must never brick the app when the backend is
/// unreachable.
abstract final class AppVersionGate {
  static Future<void> check(AppApiClient apiClient) async {
    try {
      final config = await apiClient.getAppConfig();
      final minVersion = (config['minVersion'] as String?)?.trim() ?? '';
      if (minVersion.isEmpty) return;

      final info = await PackageInfo.fromPlatform();
      if (!isVersionBelow(info.version, minVersion)) return;

      final storeUrl = defaultTargetPlatform == TargetPlatform.iOS
          ? (config['iosStoreUrl'] as String?)?.trim() ?? ''
          : (config['androidStoreUrl'] as String?)?.trim() ?? '';

      // Boot fires this check before GetMaterialApp has attached its
      // navigator; wait (bounded) for the first frame before replacing the
      // stack, and give up rather than crash if it never mounts.
      for (var i = 0; i < 100 && Get.context == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      if (Get.context == null) return;

      await Get.offAll<void>(() => ForceUpdateScreen(storeUrl: storeUrl));
    } catch (error) {
      debugPrint('Force-update check skipped: $error');
    }
  }
}
