import 'dart:async';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/core/config/app_config.dart';
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
import 'app/core/navigation/app_boot_screen.dart';
import 'app/core/services/auth_service.dart';
import 'app/core/navigation/shell_tabs.dart';
import 'app/core/services/security_service.dart';
import 'app/core/services/onesignal_service.dart';
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

    // ── Supabase Auth ────────────────────────────────────────────────────────
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
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

    final authService = await AuthService.create(apiClient);
    Get.put(authService, permanent: true);
    if (authService.isLoggedIn) {
      await controller.finishAuthSession();
    }
    
    Get.put(SecurityService());
    // ── Push notifications (OneSignal) ─────────────────────────────────────────
    await OneSignalService.instance.initialize();
    unawaited(OneSignalService.instance.requestPermission());
    // Link an already-signed-in user to OneSignal on cold start.
    if (controller.profile != null) {
      unawaited(controller.syncOneSignalIdentity());
    }
    
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
          // MVP launch lock: French only, light theme only.
          locale: const Locale('fr'),
          fallbackLocale: const Locale('fr'),
          supportedLocales: const [
            Locale('fr'),
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
          navigatorObservers: [AnalyticsService.instance.observer],
          home: const AppBootScreen(),
        );
      },
    );
  }
}
