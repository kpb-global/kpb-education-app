import 'dart:async';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/core/config/app_config.dart';
import 'app/core/config/kpb_supabase_local_storage.dart';
import 'app/core/controllers/app_controller.dart';
import 'app/core/config/app_routes.dart';
import 'app/core/repositories/app_api_client.dart';
import 'app/core/repositories/local_app_repository.dart';
import 'app/core/services/analytics_service.dart';
import 'app/core/services/app_version_gate.dart';
import 'app/core/services/case_message_outbox.dart';
import 'app/core/services/catalog_cache_service.dart';
import 'app/core/services/connectivity_service.dart';
import 'app/core/translations/app_translations.dart';
import 'app/core/ui/app_theme.dart';
import 'app/core/navigation/app_boot_screen.dart';
import 'app/core/services/auth_service.dart';
import 'app/core/navigation/shell_tabs.dart';
import 'app/core/services/security_service.dart';
import 'app/core/services/onesignal_service.dart';
import 'app/core/services/deep_link_service.dart';
import 'package:quick_actions/quick_actions.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  bool firebaseInitialized = false;

  try {
    // ── Safe Firebase Booting ────────────────────────────────────────────────
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      FlutterError.onError =
          FirebaseCrashlytics.instance.recordFlutterFatalError;
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
      firebaseInitialized = true;
    } catch (firebaseError) {
      debugPrint(
          'Firebase/Crashlytics boot skipped (running offline/local-only): $firebaseError');
    }

    // ── PostHog product analytics + session replay ─────────────────────────────
    // Set up early so the "Application Opened" lifecycle event is captured.
    // Inert unless POSTHOG_API_KEY is provided (--dart-define); never blocks
    // boot. Session replay masks all text and images by default — the app shows
    // passports, transcripts and personal data, which must never be recorded.
    if (AppConfig.posthogEnabled) {
      try {
        final phConfig = PostHogConfig(AppConfig.posthogApiKey)
          ..host = AppConfig.posthogHost
          ..captureApplicationLifecycleEvents = true
          ..sessionReplay = true
          ..debug = kDebugMode;
        phConfig.sessionReplayConfig
          ..maskAllTexts = true
          ..maskAllImages = true;
        await Posthog().setup(phConfig);
      } catch (posthogError) {
        debugPrint('PostHog setup skipped: $posthogError');
      }
    }

    // ── Supabase Auth ────────────────────────────────────────────────────────
    // Store the session (incl. refresh token) in the platform secure store
    // rather than the default plain-text SharedPreferences/NSUserDefaults.
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        localStorage: KpbSecureLocalStorage(),
      ),
    );

    // ── Offline catalog cache (Hive) ─────────────────────────────────────────
    await Hive.initFlutter();
    await CatalogCacheService.init();
    await CaseMessageOutbox.init();

    // ── App bootstrap ────────────────────────────────────────────────────────
    final repository = await LocalAppRepository.create();
    final apiClient = AppApiClient();
    final controller = AppController(
      repository: repository,
      apiClient: apiClient,
    );
    await controller.hydrate();
    Get.put(controller, permanent: true);
    // Re-apply the persisted analytics/session-replay consent so a prior opt-out
    // survives restarts (PostHog was just set up above; disable it now if the
    // user had turned collection off).
    controller.applyAnalyticsConsent();

    final authService = await AuthService.create(apiClient);
    Get.put(authService, permanent: true);
    if (authService.isLoggedIn) {
      await controller.finishAuthSession();
    }

    Get.put(SecurityService());
    // ── Push notifications (OneSignal) ─────────────────────────────────────────
    await OneSignalService.instance.initialize();
    // NB: the OS permission prompt is requested contextually at the end of
    // onboarding (onboarding_screen._submit), not at cold start — asking here
    // would burn iOS's one-shot prompt for guests before any value is shown.
    // Link an already-signed-in user to OneSignal on cold start.
    if (controller.profile != null) {
      unawaited(controller.syncOneSignalIdentity());
    }

    // Force-update gate: async so an unreachable backend never delays boot;
    // replaces the stack with the update screen once the app has mounted.
    unawaited(AppVersionGate.check(apiClient));

    ConnectivityService.instance.startMonitoring();
    ConnectivityService.instance.bindReconnectSync(() async {
      await controller.flushPendingCaseMessages();
      await controller.syncRemoteData(silent: true);
    });

    // ── Quick Actions ────────────────────────────────────────────────────────
    const QuickActions quickActions = QuickActions();
    quickActions.initialize((String shortcutType) {
      if (shortcutType == 'action_cases') {
        // Reset stack to shell + Dossiers tab (named `/cases` was never registered).
        Get.offAllNamed(AppRoutes.home);
        Future.microtask(
          () => Get.find<AppController>().goToTab(StudentShellTab.cases),
        );
      } else if (shortcutType == 'action_search') {
        Get.toNamed(AppRoutes.search);
      }
    });

    quickActions.setShortcutItems(<ShortcutItem>[
      const ShortcutItem(
        type: 'action_cases',
        localizedTitle: 'Mes Dossiers',
        icon: 'icon_cases',
      ),
      const ShortcutItem(
        type: 'action_search',
        localizedTitle: 'Nouvelle Recherche',
        icon: 'icon_search',
      ),
    ]);

    // ── Deep links (kpb://) ────────────────────────────────────────────────────
    // The scheme is declared natively (iOS Info.plist + Android intent-filter)
    // but nothing consumed the inbound URLs. Start the listener so cold-start
    // and in-flight `kpb://…` links route to the matching screen. It subscribes
    // on the first frame internally, so this never delays boot.
    DeepLinkService.instance.initialize();

    // PostHogWidget wraps the tree so autocapture (taps) and session-replay
    // screenshotting can observe it. Only mount it when PostHog is configured.
    const Widget app = KpbEducationApp();
    runApp(AppConfig.posthogEnabled ? const PostHogWidget(child: app) : app);
  } catch (error, stack) {
    if (firebaseInitialized) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    } else {
      debugPrint('Boot critical error: $error\n$stack');
    }
    runApp(BootstrapErrorApp(error: error));
  }
}

class BootstrapErrorApp extends StatelessWidget {
  final dynamic error;
  const BootstrapErrorApp({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 64),
                const SizedBox(height: 16),
                const Text(
                  'Une erreur critique est survenue au démarrage.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  error.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class KpbEducationApp extends StatelessWidget {
  const KpbEducationApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<AppController>(
      builder: (controller) {
        return GetMaterialApp(
          title: 'KPB Education',
          debugShowCheckedModeBanner: false,
          translations: AppTranslations(),
          // Locale is driven by the saved preference (default French). Runtime
          // switches go through AppController.switchLanguage → Get.updateLocale.
          // Light theme only remains the MVP launch lock.
          locale: Locale(controller.localeCode),
          fallbackLocale: const Locale('fr'),
          supportedLocales: const [
            Locale('fr'),
            Locale('en'),
          ],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: AppTheme.buildTheme(),
          themeMode: ThemeMode.light,
          defaultTransition: Transition.cupertino,
          transitionDuration: const Duration(milliseconds: 280),
          getPages: AppRoutes.pages,
          navigatorObservers: AnalyticsService.instance.navigatorObservers,
          // Accessibility: honor the user's OS font-size preference (older
          // parents and low-vision users on budget Android phones often crank
          // it up) but clamp it so extreme scales don't shatter fixed-size
          // chips/badges. Respect — never ignore — text scaling.
          builder: (context, child) {
            final mq = MediaQuery.of(context);
            final scaled = mq.textScaler.clamp(
              minScaleFactor: 1.0,
              maxScaleFactor: 1.3,
            );
            return MediaQuery(
              data: mq.copyWith(textScaler: scaled),
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: const AppBootScreen(),
        );
      },
    );
  }
}
