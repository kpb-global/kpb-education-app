import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';

import 'package:karatou/app/core/controllers/app_controller.dart';
import 'package:karatou/app/core/models/app_models.dart';
import 'package:karatou/app/core/repositories/app_api_client.dart';
import 'package:karatou/app/core/repositories/app_repository.dart';
import 'package:karatou/app/core/repositories/app_snapshot.dart';

// ---------------------------------------------------------------------------
// Silence platform-channel noise from HapticFeedback / secure_storage
// ---------------------------------------------------------------------------

void _setupPlatformMocks() {
  // HapticFeedback → handled by TestWidgetsFlutterBinding; no extra setup needed.

  // flutter_secure_storage – used by AppApiClient's _AuthInterceptor at runtime
  // but not triggered during tests that use --dart-define=KPB_ENABLE_REMOTE_SYNC=false.
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
    (MethodCall call) async => null,
  );
}

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _FakeRepository implements AppRepository {
  _FakeRepository({AppSnapshot? snapshot})
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

class _MockApiClient extends Mock implements AppApiClient {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

UserProfile _studentProfile({
  String preferredLanguage = 'fr',
  List<String>? countries,
}) {
  return UserProfile(
    id: 'u-1',
    accountType: AccountType.student,
    fullName: 'Aminou Test',
    email: 'aminou@example.com',
    phone: '+22501020304',
    whatsApp: '+22501020304',
    countryOfResidence: 'CI',
    preferredLanguage: preferredLanguage,
    currentLevel: 'Licence',
    targetLevel: 'Master',
    languageLevel: 'B2',
    fieldIds: const <String>['d01'],
    targetCountryIds: countries ?? const <String>['canada'],
    gradeRange: '15-16',
    wantsScholarshipSupport: true,
    availableDocuments: const <String>['Passport', 'CV'],
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(_setupPlatformMocks);

  late _FakeRepository repository;
  late _MockApiClient apiClient;
  late AppController controller;

  setUp(() async {
    Get.testMode = true;
    repository = _FakeRepository();
    apiClient = _MockApiClient();
    when(() => apiClient.hasAuthSession()).thenAnswer((_) async => false);

    controller = AppController(
      repository: repository,
      apiClient: apiClient,
    );

    await controller.hydrate();

    controller.scholarships.addAll([
      const ScholarshipModel(
        id: 'brs_test_1',
        name: LocalizedText(fr: 'Bourse Test 1', en: 'Test Scholarship 1'),
        countryId: 'canada',
        levelEligible: LocalizedText(fr: 'Master', en: 'Master'),
        typeOfFunding: LocalizedText(fr: 'Complet', en: 'Full'),
        deadlineLabel: LocalizedText(fr: 'Juin', en: 'June'),
        keyRequirements: [
          LocalizedText(fr: 'Critère 1', en: 'Requirement 1'),
        ],
        relatedFieldIds: ['d01'],
        baseMatch: 0,
      ),
      const ScholarshipModel(
        id: 'brs_test_2',
        name: LocalizedText(fr: 'Bourse Test 2', en: 'Test Scholarship 2'),
        countryId: 'france',
        levelEligible: LocalizedText(fr: 'Licence', en: 'Bachelor'),
        typeOfFunding: LocalizedText(fr: 'Partiel', en: 'Partial'),
        deadlineLabel: LocalizedText(fr: 'Juillet', en: 'July'),
        keyRequirements: [
          LocalizedText(fr: 'Critère 2', en: 'Requirement 2'),
        ],
        relatedFieldIds: ['d02'],
        baseMatch: 0,
      ),
    ]);
  });

  tearDown(() {
    Get.testMode = false;
  });

  // ── completeOnboarding ──────────────────────────────────────────────────

  group('completeOnboarding', () {
    test('sets profile and marks onboarding as complete', () {
      expect(controller.hasCompletedOnboarding, isFalse);
      expect(controller.profile, isNull);

      controller.completeOnboarding(_studentProfile());

      expect(controller.hasCompletedOnboarding, isTrue);
      expect(controller.profile?.id, equals('u-1'));
    });

    test('updates localeCode to the profile preferred language', () {
      controller.completeOnboarding(_studentProfile(preferredLanguage: 'en'));

      expect(controller.localeCode, 'en');
    });

    test(
        'clears cases on onboarding complete (cases come from API when sync runs)',
        () {
      controller.completeOnboarding(_studentProfile());

      expect(controller.cases, isEmpty);
    });
  });

  // ── toggleSaved / isSaved ───────────────────────────────────────────────

  group('toggleSaved / isSaved', () {
    test('adds an item not previously saved', () {
      expect(controller.isSaved(SavedItemType.field, 'd01'), isFalse);

      controller.toggleSaved(SavedItemType.field, 'd01');

      expect(controller.isSaved(SavedItemType.field, 'd01'), isTrue);
    });

    test('removes an item that was already saved (toggle off)', () {
      controller.toggleSaved(SavedItemType.field, 'd01');
      expect(controller.isSaved(SavedItemType.field, 'd01'), isTrue);

      controller.toggleSaved(SavedItemType.field, 'd01');

      expect(controller.isSaved(SavedItemType.field, 'd01'), isFalse);
    });

    test('different SavedItemType values are tracked independently', () {
      controller.toggleSaved(SavedItemType.scholarship, 's01');

      expect(controller.isSaved(SavedItemType.scholarship, 's01'), isTrue);
      expect(controller.isSaved(SavedItemType.field, 's01'), isFalse);
    });

    test(
        'Bug E: re-saving an item purges its tombstone — otherwise a sync racing the un-save delete would silently drop the re-save in mergeSavedItemsUnion',
        () async {
      // 1. Save it.
      controller.toggleSaved(SavedItemType.field, 'd01');
      expect(controller.isSaved(SavedItemType.field, 'd01'), isTrue);

      // 2. Un-save → tombstone is added.
      controller.toggleSaved(SavedItemType.field, 'd01');
      await Future<void>.delayed(Duration.zero); // flush _persist microtask
      var snapshot = await repository.loadSnapshot();
      expect(snapshot.savedItemTombstones, contains('field:d01'));

      // 3. Re-save immediately (before _deleteRemoteSavedItem confirms) — the
      // fix is supposed to purge the tombstone here. Without it, the next
      // sync would filter out the re-save.
      controller.toggleSaved(SavedItemType.field, 'd01');
      await Future<void>.delayed(Duration.zero);
      snapshot = await repository.loadSnapshot();
      expect(snapshot.savedItemTombstones, isNot(contains('field:d01')),
          reason:
              're-save must purge the tombstone so the item survives the next merge');
      expect(controller.isSaved(SavedItemType.field, 'd01'), isTrue);
    });
  });

  // ── toggleRoadmapStep / isStepCompleted ────────────────────────────────

  group('toggleRoadmapStep / isStepCompleted', () {
    test('marks a step as completed', () {
      final id = controller.scholarships.first.id;

      expect(controller.isStepCompleted(id, RoadmapStepType.audit), isFalse);

      controller.toggleRoadmapStep(id, RoadmapStepType.audit);

      expect(controller.isStepCompleted(id, RoadmapStepType.audit), isTrue);
    });

    test('un-marks a completed step (toggle off)', () {
      final id = controller.scholarships.first.id;
      controller.toggleRoadmapStep(id, RoadmapStepType.audit);

      controller.toggleRoadmapStep(id, RoadmapStepType.audit);

      expect(controller.isStepCompleted(id, RoadmapStepType.audit), isFalse);
    });

    test('steps for different scholarships are independent', () {
      final id1 = controller.scholarships[0].id;
      final id2 = controller.scholarships[1].id;

      controller.toggleRoadmapStep(id1, RoadmapStepType.audit);

      expect(controller.isStepCompleted(id1, RoadmapStepType.audit), isTrue);
      expect(controller.isStepCompleted(id2, RoadmapStepType.audit), isFalse);
    });
  });

  // ── getChildOverallProgressPercentage ──────────────────────────────────

  group('getChildOverallProgressPercentage', () {
    test('returns 0.0 when no scholarships are saved', () {
      expect(controller.getChildOverallProgressPercentage(), 0.0);
    });

    test(
        'returns a positive value after saving a scholarship and completing a step',
        () {
      final id = controller.scholarships.first.id;
      controller.toggleSaved(SavedItemType.scholarship, id);
      controller.toggleRoadmapStep(id, RoadmapStepType.audit);

      expect(controller.getChildOverallProgressPercentage(), greaterThan(0.0));
    });
  });

  // ── getEstimatedFinancialSummary ───────────────────────────────────────

  group('getEstimatedFinancialSummary', () {
    test('returns map with totalCost, potentialSavings, and gap', () {
      final summary = controller.getEstimatedFinancialSummary();

      expect(summary['totalCost'], isNotNull);
      expect(summary['potentialSavings'], isNotNull);
      expect(summary['gap'], isNotNull);
    });

    test('gap equals totalCost minus potentialSavings', () {
      final summary = controller.getEstimatedFinancialSummary();
      final expected = (summary['totalCost'] as double) -
          (summary['potentialSavings'] as double);

      expect(summary['gap'], closeTo(expected, 0.01));
    });

    test('saving a scholarship increases potentialSavings', () {
      final baseline = controller
          .getEstimatedFinancialSummary()['potentialSavings'] as double;
      controller.toggleSaved(
          SavedItemType.scholarship, controller.scholarships.first.id);
      final after = controller
          .getEstimatedFinancialSummary()['potentialSavings'] as double;

      expect(after, greaterThan(baseline));
    });

    test('canada profile uses 25 000 total cost', () {
      controller.completeOnboarding(
        _studentProfile(countries: const <String>['canada']),
      );
      final id = controller.scholarships.first.id;
      controller.toggleSaved(SavedItemType.scholarship, id);

      final summary = controller.getEstimatedFinancialSummary();

      expect(summary['totalCost'], equals(25000.0));
      expect(summary['potentialSavings'], equals(5000.0));
      expect(summary['gap'], equals(20000.0));
    });
  });

  // ── logout ─────────────────────────────────────────────────────────────

  group('logout', () {
    test('clears profile and resets hasCompletedOnboarding', () {
      controller.completeOnboarding(_studentProfile());
      expect(controller.profile, isNotNull);

      controller.logout();

      expect(controller.profile, isNull);
      expect(controller.hasCompletedOnboarding, isFalse);
    });

    test('clears saved items', () {
      controller.toggleSaved(SavedItemType.field, 'd01');
      expect(controller.isSaved(SavedItemType.field, 'd01'), isTrue);

      controller.logout();

      expect(controller.isSaved(SavedItemType.field, 'd01'), isFalse);
    });
  });

  // ── switchLanguage ─────────────────────────────────────────────────────

  group('switchLanguage', () {
    test('updates localeCode', () {
      expect(controller.localeCode, 'fr');

      controller.switchLanguage('en');

      expect(controller.localeCode, 'en');
    });

    test('also updates preferredLanguage on the profile when set', () {
      controller.completeOnboarding(_studentProfile(preferredLanguage: 'fr'));

      controller.switchLanguage('ar');

      expect(controller.profile!.preferredLanguage, 'ar');
      expect(controller.localeCode, 'ar');
    });
  });

  // ── goToTab ────────────────────────────────────────────────────────────

  group('goToTab', () {
    test('updates shellIndex', () {
      expect(controller.shellIndex, 0);

      controller.goToTab(2);

      expect(controller.shellIndex, 2);
    });

    test('can navigate back to tab 0', () {
      controller.goToTab(3);
      controller.goToTab(0);

      expect(controller.shellIndex, 0);
    });

    test('clamps out-of-range tab index for shell safety', () {
      controller.goToTab(999);
      expect(controller.shellIndex, AppController.shellTabCount - 1);

      controller.goToTab(-10);
      expect(controller.shellIndex, 0);
    });
  });
}
