import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';

import 'package:karatou/app/core/config/app_config.dart';
import 'package:karatou/app/core/controllers/app_controller.dart';
import 'package:karatou/app/core/models/app_models.dart';
import 'package:karatou/app/core/repositories/app_api_client.dart';
import 'package:karatou/app/core/repositories/app_repository.dart';
import 'package:karatou/app/core/repositories/app_snapshot.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Platform Mocks
// ─────────────────────────────────────────────────────────────────────────────

void setupPlatformChannelMocks() {
  AppConfig.enableRemoteSyncOverride = false;

  // Mock flutter_secure_storage
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
    (MethodCall call) async => null,
  );

  // Mock HapticFeedback
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('flutter.io.vitalsigns.com/haptic'),
    (MethodCall call) async => null,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Fakes
// ─────────────────────────────────────────────────────────────────────────────

class FakeRepository implements AppRepository {
  FakeRepository({AppSnapshot? snapshot})
      : _snapshot = snapshot ?? AppSnapshot.initial();

  AppSnapshot _snapshot;

  @override
  Future<AppSnapshot> loadSnapshot() async => _snapshot;

  @override
  Future<void> saveSnapshot(AppSnapshot snapshot) async {
    _snapshot = snapshot;
  }

  @override
  Future<void> clear() async {
    _snapshot = AppSnapshot.initial();
  }
}

class MockApiClient extends Mock implements AppApiClient {
  @override
  Future<bool> hasAuthSession() async => false;

  /// No session in widget tests, so the profile avatar renders the initials and
  /// never reaches for the network. Stubbed explicitly rather than left to
  /// throw MissingStubError inside a widget build.
  @override
  Future<Map<String, String>?> authImageHeaders() async => null;

  @override
  String get avatarStreamUrl =>
      'https://api.invalid.test/api/profiles/me/avatar';
}

/// Client qui COMPTE ses appels, pour les tests qui doivent prouver qu'un
/// aller-retour réseau a réellement eu lieu — et pas seulement qu'un booléen
/// vaut `true`.
///
/// L'observable est `listParcoursStories()`, appelé par
/// `AppController.fetchParcoursStories()` juste après son portillon
/// `if (!AppConfig.enableRemoteSync) return;`
/// (lib/app/core/controllers/app_controller/parcours.dart:69, appel :80).
///
/// Ce chemin-là et pas `syncRemoteData` : `syncRemoteData` enchaîne des dizaines
/// d'appels, des délais de repli et une file d'attente, et ne se termine JAMAIS
/// sous un client qui rend `null` — mesuré, le test pendait indéfiniment.
/// `fetchParcoursStories` fait un seul appel dans un `try/catch`, sans toucher
/// Hive (`CatalogCacheService.isInitialized` est faux en test) : borné et
/// déterministe. Un observable qui pend n'est pas un observable.
class CountingApiClient extends MockApiClient {
  int listParcoursStoriesCalls = 0;

  @override
  Future<List<ParcoursStory>> listParcoursStories() async {
    listParcoursStoriesCalls++;
    return const <ParcoursStory>[];
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Test App Wrapper
// ─────────────────────────────────────────────────────────────────────────────

class TestAppWrapper extends StatelessWidget {
  final Widget child;
  final AppController? controller;

  const TestAppWrapper({
    required this.child,
    this.controller,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      home: Scaffold(
        body: child,
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper: Create Test App with AppController
// ─────────────────────────────────────────────────────────────────────────────

/// Monte [child] avec un AppController hydraté depuis [initialSnapshot].
///
/// ## Pourquoi [enableRemoteSync] existe, et pourquoi son défaut est `false`
///
/// `AppConfig.enableRemoteSync` garde une trentaine de chemins de
/// `AppController` (`app_controller.dart` : 18 occurrences, plus parcours.dart
/// et commercial.dart). Le défaut `false` est le bon pour la grande majorité des
/// tests : sans lui, chaque `pumpTestApp` partirait chercher le réseau et
/// exploserait sur un `MissingStubError` au milieu d'un `build`.
///
/// Mais ce défaut a un coût, et il faut le nommer : **un test d'envoi qui ne
/// passe pas `enableRemoteSync: true` ne teste PAS l'envoi.** Il monte l'écran,
/// tape sur le bouton, voit « fourni ✓ » et passe au vert — pendant qu'aucun
/// octet ne part. C'est le motif d'outillage menteur que le lot 5 existe pour
/// supprimer : le harnais doit être capable d'échouer.
///
/// Donc : tout test qui prétend vérifier un aller-retour réseau (création de
/// dossier, téléversement de pièce, synchronisation) DOIT passer
/// `enableRemoteSync: true` et observer un client qui compte. Voir
/// `test/core/remote_sync_seam_test.dart`, le méta-test qui rougit si ce
/// paramètre est ignoré ou re-figé à `false`.
///
/// ## Le paramètre s'applique APRÈS l'hydratation, et ce n'est pas un détail
///
/// `AppController.hydrate()` fait `if (AppConfig.enableRemoteSync) await
/// syncRemoteData(silent: true);` (app_controller.dart:429-431). Poser le drapeau
/// avant `hydrate()` fait donc partir une synchronisation COMPLÈTE dans le
/// helper — et sous un client de test elle ne se termine jamais : dizaines
/// d'appels, replis temporisés, file d'attente. Mesuré : le test pendait
/// indéfiniment, y compris avec `--timeout 45s`, avant même d'atteindre son
/// premier `expect`.
///
/// L'hydratation reste donc LOCALE dans tous les cas, et le drapeau s'ouvre
/// juste avant le premier `build`. C'est aussi la sémantique utile : ce qu'un
/// test d'envoi veut, c'est « le chemin réseau est ouvert quand j'appuie sur le
/// bouton », pas « le helper a rejoué toute la synchronisation d'ouverture ».
///
/// Conséquence à connaître : avec `enableRemoteSync: true`, un écran qui lance un
/// appel dans son `initState` le lancera pour de vrai pendant le `pumpAndSettle`
/// final. C'est au test de fournir les réponses.
Future<void> pumpTestApp(
  WidgetTester tester, {
  required Widget child,
  AppSnapshot? initialSnapshot,
  MockApiClient? mockApiClient,
  bool ensureBinding = true,
  bool enableRemoteSync = false,
}) async {
  if (ensureBinding) {
    TestWidgetsFlutterBinding.ensureInitialized();
  }

  setupPlatformChannelMocks();

  final repository = FakeRepository(snapshot: initialSnapshot);
  final apiClient = mockApiClient ?? MockApiClient();

  final controller = AppController(
    repository: repository,
    apiClient: apiClient,
  );

  // Hydratation TOUJOURS locale : `hydrate()` enchaîne un `syncRemoteData`
  // complet dès que le drapeau est levé (app_controller.dart:429-431), et cette
  // synchronisation ne se termine jamais sous un client de test.
  await controller.hydrate();

  // Le drapeau s'ouvre ici, après l'hydratation et avant le premier build.
  // Booléen EXPLICITE, jamais `null` : `null` retomberait sur le dart-define
  // `KPB_ENABLE_REMOTE_SYNC`, qui vaut `false` en CI (flutter-ci.yml:89) et
  // `true` en local — le test dirait deux choses selon la machine.
  AppConfig.enableRemoteSyncOverride = enableRemoteSync;

  Get.put<AppController>(controller, permanent: true);

  await tester.pumpWidget(
    TestAppWrapper(
      controller: controller,
      child: child,
    ),
  );

  // Trigger initial build and layout
  await tester.pumpAndSettle();
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper: Reset GetX singleton
// ─────────────────────────────────────────────────────────────────────────────

void resetGetxSingleton() {
  Get.reset();
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper: Create a test profile
// ─────────────────────────────────────────────────────────────────────────────

UserProfile createTestProfile({
  String id = 'test-user-1',
  String fullName = 'Test User',
  String email = 'test@example.com',
  String phone = '+22501020304',
  AccountType accountType = AccountType.student,
  String preferredLanguage = 'fr',
  bool withAiConsent = true,
  DateTime? aiConsentedAt,
}) {
  return UserProfile(
    id: id,
    accountType: accountType,
    fullName: fullName,
    email: email,
    phone: phone,
    whatsApp: phone,
    countryOfResidence: 'CI',
    preferredLanguage: preferredLanguage,
    currentLevel: 'Licence',
    targetLevel: 'Master',
    languageLevel: 'B2',
    fieldIds: const ['d01', 'd02'],
    targetCountryIds: const ['canada', 'france'],
    gradeRange: '15-16',
    wantsScholarshipSupport: true,
    availableDocuments: const ['Passport', 'CV'],
    // Default: already consented, so existing navigation tests do not grow
    // a consent dialog. Pass `withAiConsent: false` to exercise the gate.
    aiConsentedAt:
        withAiConsent ? (aiConsentedAt ?? DateTime.utc(2026, 1, 1)) : null,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper: Common widget tester operations
// ─────────────────────────────────────────────────────────────────────────────

extension WidgetTesterX on WidgetTester {
  /// Enters text in a text field matching the given finder
  Future<void> enterTextInField(Finder finder, String text) async {
    await tap(finder);
    await pumpAndSettle();
    await enterText(finder, text);
    await pumpAndSettle();
  }

  /// Finds and taps a button with text
  Future<void> tapButtonWithText(String text) async {
    final button = find.byWidgetPredicate(
      (widget) => widget is ElevatedButton || widget is TextButton,
    );
    await tap(button);
    await pumpAndSettle();
  }

  /// Finds a Text widget by its content (partial match)
  Finder findText(String text) {
    return find.byWidgetPredicate(
      (widget) =>
          widget is Text && widget.data != null && widget.data!.contains(text),
    );
  }
}
