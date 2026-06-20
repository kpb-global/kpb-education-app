import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

import '../config/app_config.dart';
import '../config/app_routes.dart';

/// Thin wrapper around the OneSignal Flutter SDK.
///
/// Design notes:
/// - Every method is a no-op until [initialize] has run. This keeps the rest of
///   the app (and the widget tests, which never call [initialize]) safe — no
///   OneSignal platform channel is ever touched before init.
/// - We link the OneSignal "external id" to the KPB user id on login so the
///   backend can target a known user across devices, and clear it on logout.
class OneSignalService {
  OneSignalService._internal();
  static final OneSignalService instance = OneSignalService._internal();

  bool _initialized = false;
  bool get isInitialized => _initialized;

  /// Boot OneSignal. Call once from main() after the bindings are ready.
  /// Safe to call when no App ID is configured (becomes a no-op).
  Future<void> initialize() async {
    if (_initialized || !AppConfig.oneSignalEnabled) return;
    try {
      OneSignal.Debug.setLogLevel(
        kReleaseMode ? OSLogLevel.none : OSLogLevel.warn,
      );
      OneSignal.initialize(AppConfig.oneSignalAppId);

      // Route taps on a notification to the in-app destination if provided.
      OneSignal.Notifications.addClickListener(_onNotificationClicked);

      _initialized = true;
    } catch (error) {
      debugPrint('[OneSignal] init skipped: $error');
    }
  }

  /// Ask the OS for notification permission (shows the system prompt once).
  Future<void> requestPermission() async {
    if (!_initialized) return;
    try {
      await OneSignal.Notifications.requestPermission(true);
    } catch (error) {
      debugPrint('[OneSignal] requestPermission failed: $error');
    }
  }

  /// Link this device to a known KPB user (external id = profile id) and attach
  /// targeting tags. Called on login / profile completion.
  Future<void> login({
    required String userId,
    String? email,
    Map<String, String> tags = const {},
  }) async {
    if (!_initialized || userId.trim().isEmpty) return;
    try {
      OneSignal.login(userId.trim());
      if (email != null && email.trim().isNotEmpty) {
        OneSignal.User.addEmail(email.trim());
      }
      final cleaned = <String, String>{
        for (final entry in tags.entries)
          if (entry.value.trim().isNotEmpty) entry.key: entry.value.trim(),
      };
      if (cleaned.isNotEmpty) OneSignal.User.addTags(cleaned);
    } catch (error) {
      debugPrint('[OneSignal] login failed: $error');
    }
  }

  /// Unlink the external id from this device. Called on sign-out.
  Future<void> logout() async {
    if (!_initialized) return;
    try {
      OneSignal.logout();
    } catch (error) {
      debugPrint('[OneSignal] logout failed: $error');
    }
  }

  /// Update targeting tags (e.g. when the profile changes).
  Future<void> setTags(Map<String, String> tags) async {
    if (!_initialized) return;
    final cleaned = <String, String>{
      for (final entry in tags.entries)
        if (entry.value.trim().isNotEmpty) entry.key: entry.value.trim(),
    };
    if (cleaned.isEmpty) return;
    try {
      OneSignal.User.addTags(cleaned);
    } catch (error) {
      debugPrint('[OneSignal] setTags failed: $error');
    }
  }

  // ── Internal ────────────────────────────────────────────────────────────

  void _onNotificationClicked(OSNotificationClickEvent event) {
    final data = event.notification.additionalData;
    final route = data?['route'];
    if (route is String && route.isNotEmpty) {
      try {
        Get.toNamed(route);
      } catch (error) {
        debugPrint('[OneSignal] route "$route" not navigable: $error');
      }
    } else {
      // No explicit route → land on the home shell.
      try {
        Get.offAllNamed(AppRoutes.home);
      } catch (_) {}
    }
  }
}
