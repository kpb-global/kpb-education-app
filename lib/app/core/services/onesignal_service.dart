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
///
/// Ce qui part vers OneSignal, et pourquoi (périmètre volontairement fermé) :
/// - l'external id (identifiant de profil KPB) et le jeton de notification :
///   sans eux il n'y a pas de notification adressée à un utilisateur connu ;
/// - quatre étiquettes de ciblage — `account_type`, `level`, `target_country`,
///   `locale`. On les GARDE parce que le ciblage des notifications est une
///   fonctionnalité réellement utilisée (une alerte bourse n'a de sens que
///   pour le bon niveau et le bon pays visé) ; le prix à payer est de les
///   DÉCLARER dans le formulaire de confidentialité des boutiques plutôt que
///   de prétendre qu'elles n'existent pas.
///
/// Ce qui NE part pas : l'adresse e-mail de l'étudiant. OneSignal ne s'en sert
/// que pour ses propres campagnes courriel, et les nôtres passent par Resend
/// (transactionnel) et Mautic (newsletter bourses). On perdait donc une donnée
/// personnelle par la porte d'un canal qu'on n'utilise pas. Écarté : garder
/// l'envoi derrière une case de consentement — cela aurait fait vivre une
/// permission pour une capacité que personne ne réclame.
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
  ///
  /// [email] est accepté et VOLONTAIREMENT ignoré : aucun appel ne l'emporte
  /// vers OneSignal (voir l'en-tête de classe). Le paramètre survit parce que
  /// `AppController.syncOneSignalIdentity()` le passe encore ; le retirer ici
  /// casserait cet appelant. À supprimer des deux côtés dans le même geste.
  Future<void> login({
    required String userId,
    String? email,
    Map<String, String> tags = const {},
  }) async {
    if (!_initialized || userId.trim().isEmpty) return;
    try {
      OneSignal.login(userId.trim());
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
    final raw = data?['route'];
    // Normalize the external payload and fall back to the home shell when it
    // resolves to nothing (e.g. an unknown or MVP-locked route) so a tap never
    // dies silently. `/scholarships` resolves to a graceful "coming soon".
    var route = raw is String ? AppRoutes.normalizeExternalRoute(raw) : null;
    final scholarshipId = data?['scholarshipId'];
    // Older backend activations route to the generic list and carry the target
    // id separately. Upgrade that payload client-side so the rollout remains
    // backward compatible while new pushes can send the detail route directly.
    if (route == AppRoutes.scholarships &&
        scholarshipId is String &&
        scholarshipId.trim().isNotEmpty) {
      route = AppRoutes.normalizeExternalRoute(
        AppRoutes.scholarshipDetailPath(scholarshipId.trim()),
      );
    }
    try {
      if (route == null) {
        Get.offAllNamed(AppRoutes.home);
      } else {
        Get.toNamed(route);
      }
    } catch (error) {
      debugPrint('[OneSignal] route "$raw" not navigable: $error');
      try {
        Get.offAllNamed(AppRoutes.home);
      } catch (_) {}
    }
  }
}
