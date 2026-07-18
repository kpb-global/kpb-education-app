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

Future<void> pumpTestApp(
  WidgetTester tester, {
  required Widget child,
  AppSnapshot? initialSnapshot,
  MockApiClient? mockApiClient,
  bool ensureBinding = true,
}) async {
  AppConfig.enableRemoteSyncOverride = false;

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

  await controller.hydrate();

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
