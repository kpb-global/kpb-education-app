import 'dart:async';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app/core/controllers/app_controller.dart';
import 'app/core/config/app_routes.dart';
import 'app/core/repositories/app_api_client.dart';
import 'app/core/repositories/local_app_repository.dart';
import 'app/core/services/analytics_service.dart';
import 'app/core/services/case_message_outbox.dart';
import 'app/core/services/catalog_cache_service.dart';
import 'app/core/services/connectivity_service.dart';
import 'app/core/translations/app_translations.dart';
import 'app/core/ui/app_theme.dart';
import 'app/features/onboarding/intro_slideshow_screen.dart';
import 'app/features/onboarding/onboarding_screen.dart';
import 'app/features/shell/app_shell.dart';
import 'app/core/services/security_service.dart';
import 'app/core/services/push_notification_service.dart';
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
      FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
      firebaseInitialized = true;
    } catch (firebaseError) {
      debugPrint('Firebase/Crashlytics boot skipped (running offline/local-only): $firebaseError');
    }

    // ── Offline catalog cache (Hive) ─────────────────────────────────────────
    await Hive.initFlutter();
    await CatalogCacheService.init();
    await CaseMessageOutbox.init();

    // ── App bootstrap ────────────────────────────────────────────────────────
    final repository = await LocalAppRepository.create();
    final controller = AppController(
      repository: repository,
      apiClient: AppApiClient(),
    );
    await controller.hydrate();
    Get.put(controller, permanent: true);
    
    Get.put(SecurityService());
    final pushService = Get.put(PushNotificationService());
    unawaited(controller.registerDevicePushToken(pushService));
    
    ConnectivityService.instance.startMonitoring();
    
    Timer? connectivityDebounceTimer;
    ConnectivityService.instance.onConnectivityChanged.listen((online) {
      if (online) {
        // Debounce connection changes by 3 seconds to mitigate cell signal flapping
        connectivityDebounceTimer?.cancel();
        connectivityDebounceTimer = Timer(const Duration(seconds: 3), () async {
          if (ConnectivityService.instance.isOnline) {
            controller.flushPendingCaseMessages();
            controller.syncRemoteData(silent: true);
          }
        });
      } else {
        connectivityDebounceTimer?.cancel();
      }
    });

    // ── Quick Actions ────────────────────────────────────────────────────────
    const QuickActions quickActions = QuickActions();
    quickActions.initialize((String shortcutType) {
      if (shortcutType == 'action_cases') {
        // Reset stack to shell + Dossiers tab (named `/cases` was never registered).
        Get.offAllNamed(AppRoutes.home);
        Future.microtask(() => Get.find<AppController>().goToTab(2));
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

    runApp(const KpbEducationApp());
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
          darkTheme: AppTheme.buildDarkTheme(),
          themeMode: controller.themeMode,
          defaultTransition: Transition.cupertino,
          transitionDuration: const Duration(milliseconds: 280),
          getPages: AppRoutes.pages,
          navigatorObservers: [AnalyticsService.instance.observer],
          home: controller.hasCompletedOnboarding
              ? const AppShell()
              : (controller.hasSeenIntro
                  ? const OnboardingScreen()
                  : const IntroSlideshowScreen()),
        );
      },
    );
  }
}
