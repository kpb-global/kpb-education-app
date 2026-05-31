import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../navigation/shell_tabs.dart';
import '../services/analytics_service.dart';
import '../services/case_message_outbox.dart';
import '../services/case_socket_service.dart';
import '../services/safe_crashlytics.dart';
import '../services/connectivity_service.dart';

import '../observability/crashlytics_observability.dart';
import '../config/app_config.dart';
import '../config/app_routes.dart';
import '../data/mock_catalog.dart';
import '../data/orientation_engine.dart';
import '../data/orientation_questions_m4.dart';
import '../data/roadmap_engine.dart';
import '../models/app_models.dart';
import '../repositories/app_api_client.dart';
import '../repositories/app_repository.dart';
import '../repositories/app_snapshot.dart';
import '../utils/country_utils.dart';
import '../utils/user_facing_sync_error.dart';
import '../data/case_api_codec.dart';
import '../data/profile_api_codec.dart';
import '../data/saved_item_api_codec.dart';
import '../services/app_search_service.dart';
import '../services/catalog_remote_sync.dart';
import '../services/catalog_cache_service.dart';
import '../services/push_notification_service.dart';
import '../services/onesignal_service.dart';
import '../services/sync_conflict_merge.dart';
import '../services/sync_telemetry.dart';
import '../services/auth_service.dart';

class AppController extends GetxController {
  static const int shellTabCount = StudentShellTab.count;

  AppController({
    required AppRepository repository,
    AppApiClient? apiClient,
  })  : _repository = repository,
        _apiClient = apiClient ?? AppApiClient();

  final AppRepository _repository;
  final AppApiClient _apiClient;
  /// Expose the API client for feature screens that need direct calls.
  AppApiClient get apiClient => _apiClient;

  String localeCode = 'fr';
  bool hasSeenIntro = false;
  bool isGuestMode = false;
  bool isAppLockEnabled = false;
  /// Data-saver mode — when on, the UI skips non-essential network images.
  bool dataSaverEnabled = false;
  bool hasCompletedOnboarding = false;
  bool onboardingSkipped = false;
  int onboardingStep = 0;
  ThemeMode themeMode = ThemeMode.system;
  int shellIndex = 0;
  int commercialShellIndex = 0;
  int selectedOrientationQuestion = 0;
  bool isSyncing = false;
  DateTime? lastSyncedAt;
  String? syncError;
  UserProfile? profile;
  OrientationSession? latestOrientationSession;

  // Catalog data always initialized from MockCatalog (static content).
  // Operational data (cases, profile, savedItems) is synced from remote.
  final List<FieldModel> fields = <FieldModel>[];
  final List<CountryModel> countries = <CountryModel>[];
  final List<InstitutionModel> institutions = <InstitutionModel>[];
  final List<ProgramModel> programs = <ProgramModel>[];
  final List<ScholarshipModel> scholarships = <ScholarshipModel>[];
  final List<AcademyCourseModel> academyCourses = <AcademyCourseModel>[];
  final List<ServiceOffer> serviceOffers =
      List<ServiceOffer>.of(MockCatalog.serviceOffers);
  final List<SupportDestination> supportDestinations =
      List<SupportDestination>.of(MockCatalog.supportDestinations);
  final List<ArticleModel> articles =
      List<ArticleModel>.of(MockCatalog.articles);
  final List<ForumCategoryModel> forumCategories =
      List<ForumCategoryModel>.of(MockCatalog.forumCategories);
  final List<ForumTopicTagModel> forumTopicTags =
      List<ForumTopicTagModel>.of(MockCatalog.forumTopicTags);
  final List<OrientationQuestion> orientationQuestions = [
    ...MockCatalog.orientationQuestions,
    ...orientationQuestionsM4Extension,
  ];

  final List<SavedItem> _savedItems = <SavedItem>[];
  final List<StudentCase> _cases = <StudentCase>[];
  final Map<String, CountryModel> _countryDetailCache = <String, CountryModel>{};
  final CaseSocketService _caseSocket = CaseSocketService();
  final Map<String, DateTime> _caseLastReadAt = <String, DateTime>{};
  String? _activeCaseSocketId;
  // True while the remote participant is typing (shown in CaseDetailScreen).
  bool isCaseAdvisorTyping = false;
  final List<OrientationSession> _orientationHistory = <OrientationSession>[];
  final Map<String, String> _remoteSavedItemIds = <String, String>{};

  /// True after local profile edits until PATCH `/profiles/me` succeeds (offline sync conflict avoidance).
  bool _profileNeedsPush = false;
  DateTime? _lastSyncAttemptAt;
  DateTime? _syncBackoffUntil;
  static const Duration _minSyncInterval = Duration(seconds: 30);
  final List<String> _searchHistory = <String>[];
  Map<String, List<String>> _pendingOrientationAnswers = {};
  final List<String> _purchasedCourseIds = <String>[];
  Map<String, List<String>> _completedRoadmapSteps = {};
  int pendingOrientationQuestionIndex = 0;
  bool isSubmittingOrientation = false;
  String? universitiesInitialFieldId;
  final List<CommercialLead> _commercialLeads = <CommercialLead>[];
  bool isLoadingCommercialLeads = false;
  String? commercialLeadsError;
  CommercialStats commercialStats = CommercialStats.empty;
  bool isLoadingCommercialStats = false;

  // ── Parcours (Chantier C) — KPB YouTube playlist ──────────────────────────
  final List<YoutubeVideo> _parcoursVideos = <YoutubeVideo>[];
  List<YoutubeVideo> get parcoursVideos => List.unmodifiable(_parcoursVideos);
  bool isLoadingParcours = false;
  String? parcoursError;
  // True once the backend confirms a YOUTUBE_API_KEY is configured.
  bool parcoursConfigured = true;
  static const _parcoursCacheKey = 'parcours_videos';

  List<SavedItem> get savedItems => List.unmodifiable(_savedItems);
  List<StudentCase> get cases => List.unmodifiable(_cases);
  List<OrientationSession> get orientationHistory =>
      List.unmodifiable(_orientationHistory);
  List<String> get searchHistory => List.unmodifiable(_searchHistory);
  List<String> get purchasedCourseIds => List.unmodifiable(_purchasedCourseIds);
  Map<String, List<String>> get pendingOrientationAnswers =>
      Map.unmodifiable(_pendingOrientationAnswers);
  List<CommercialLead> get commercialLeads =>
      List.unmodifiable(_commercialLeads);

  bool get isStudent => profile?.accountType == AccountType.student;
  bool get isParent => profile?.accountType == AccountType.parent;
  bool get isPartner => profile?.accountType == AccountType.partner;
  bool get isCommercial => profile?.accountType == AccountType.commercial;
  List<ServiceOffer> get publishedServiceOffers => serviceOffers
      .where((item) => item.status == PublicationStatus.published)
      .toList();
  List<SupportDestination> get visibleSupportDestinations => supportDestinations
      .where(
        (item) => item.status == PublicationStatus.published && item.isVisible,
      )
      .toList();
  List<ArticleModel> get publishedArticles => articles
      .where((item) => item.status == PublicationStatus.published)
      .toList()
    ..sort(
      (left, right) =>
          (right.publishedAt ?? DateTime.fromMillisecondsSinceEpoch(0))
              .compareTo(
                  left.publishedAt ?? DateTime.fromMillisecondsSinceEpoch(0)),
    );
  List<ForumCategoryModel> get visibleForumCategories => forumCategories
      .where((item) => item.status == PublicationStatus.published)
      .toList()
    ..sort((left, right) => left.displayOrder.compareTo(right.displayOrder));
  List<ForumTopicTagModel> get visibleForumTopicTags => forumTopicTags
      .where((item) => item.status == PublicationStatus.published)
      .toList()
    ..sort((left, right) => left.displayOrder.compareTo(right.displayOrder));

  String resolve(LocalizedText text) => text.resolve(localeCode);

  Future<void> hydrate() async {
    final snapshot = await _repository.loadSnapshot();
    localeCode = snapshot.localeCode;
    hasSeenIntro = snapshot.hasSeenIntro;
    isGuestMode = snapshot.isGuestMode;
    isAppLockEnabled = snapshot.isAppLockEnabled;
    dataSaverEnabled = snapshot.dataSaverEnabled;
    hasCompletedOnboarding = snapshot.hasCompletedOnboarding;
    onboardingSkipped = snapshot.onboardingSkipped;
    onboardingStep = snapshot.onboardingStep;
    profile = snapshot.profile;
    _savedItems
      ..clear()
      ..addAll(snapshot.savedItems);
    _cases
      ..clear()
      ..addAll(snapshot.cases);
    _orientationHistory
      ..clear()
      ..addAll(snapshot.orientationHistory);
    _searchHistory
      ..clear()
      ..addAll(snapshot.searchHistory);
    _purchasedCourseIds
      ..clear()
      ..addAll(snapshot.purchasedCourseIds);
    _completedRoadmapSteps = Map.from(snapshot.completedRoadmapSteps);
    _caseLastReadAt
      ..clear()
      ..addEntries(
        snapshot.caseLastReadAt.entries.map(
          (e) => MapEntry(
            e.key,
            DateTime.tryParse(e.value) ??
                DateTime.fromMillisecondsSinceEpoch(0),
          ),
        ),
      );
    themeMode = snapshot.themeMode;
    latestOrientationSession =
        _orientationHistory.isNotEmpty ? _orientationHistory.first : null;
    _pendingOrientationAnswers = Map.of(snapshot.pendingOrientationAnswers);
    pendingOrientationQuestionIndex = snapshot.pendingOrientationQuestionIndex;
    _profileNeedsPush = snapshot.profileNeedsPush;
    if (CatalogCacheService.isInitialized) {
      final cache = CatalogCacheService.instance;

      final cachedFields = cache.read('fields');
      fields
        ..clear()
        ..addAll(cachedFields.isNotEmpty
            ? cachedFields.whereType<Map<String, dynamic>>().map(FieldModel.fromJson)
            : MockCatalog.fields);

      final cachedCountries = cache.read('countries');
      countries
        ..clear()
        ..addAll(cachedCountries.isNotEmpty
            ? cachedCountries.whereType<Map<String, dynamic>>().map(CountryModel.fromJson)
            : MockCatalog.countries);

      final cachedInstitutions = cache.read('institutions');
      institutions
        ..clear()
        ..addAll(cachedInstitutions.isNotEmpty
            ? cachedInstitutions.whereType<Map<String, dynamic>>().map(InstitutionModel.fromJson)
            : MockCatalog.institutions);

      final cachedPrograms = cache.read('programs');
      programs
        ..clear()
        ..addAll(cachedPrograms.isNotEmpty
            ? cachedPrograms.whereType<Map<String, dynamic>>().map(ProgramModel.fromJson)
            : MockCatalog.programs);

      final cachedScholarships = cache.read('scholarships');
      scholarships
        ..clear()
        ..addAll(cachedScholarships.isNotEmpty
            ? cachedScholarships.whereType<Map<String, dynamic>>().map(ScholarshipModel.fromJson)
            : MockCatalog.scholarships);
    } else {
      fields
        ..clear()
        ..addAll(MockCatalog.fields);
      countries
        ..clear()
        ..addAll(MockCatalog.countries);
      institutions
        ..clear()
        ..addAll(MockCatalog.institutions);
      programs
        ..clear()
        ..addAll(MockCatalog.programs);
      scholarships
        ..clear()
        ..addAll(MockCatalog.scholarships);
    }
    academyCourses
      ..clear()
      ..addAll(MockCatalog.academyCourses);
    _applyMvpCountryLock();
    if (AppConfig.enableRemoteSync) {
      await syncRemoteData(silent: true);
    }
    update();
  }

  void switchLanguage(String newLocaleCode) {
    localeCode = newLocaleCode;
    final p = profile;
    if (p != null) {
      profile = p.copyWith(preferredLanguage: newLocaleCode);
    }
    _profileNeedsPush = true;
    unawaited(_pushProfileUpdate());
    _persist();
    update();
  }

  void toggleAppLock(bool enable) {
    isAppLockEnabled = enable;
    _repository.saveSnapshot(_snapshot);
    update();
  }

  void toggleDataSaver(bool enable) {
    dataSaverEnabled = enable;
    _repository.saveSnapshot(_snapshot);
    update();
  }

  void completeIntro() {
    hasSeenIntro = true;
    _repository.saveSnapshot(_snapshot);
    update();
  }

  void enterGuestMode() {
    isGuestMode = true;
    hasCompletedOnboarding = true;
    profile = null;
    _profileNeedsPush = false;
    _persist();
    update();
  }

  Future<void> finishAuthSession() async {
    isGuestMode = false;
    if (AppConfig.enableRemoteSync) {
      await syncRemoteData(silent: true);
    }
    maybeRestoreOnboardingFromProfile();
    unawaited(syncOneSignalIdentity());
    _persist();
    update();
  }

  void maybeRestoreOnboardingFromProfile() {
    final current = profile;
    if (current == null || hasCompletedOnboarding) return;
    if (current.completionScore >= 0.5 ||
        ((current.currentLevel ?? '').trim().isNotEmpty &&
            current.fieldIds.isNotEmpty)) {
      hasCompletedOnboarding = true;
    }
  }

  void saveOnboardingProgress(int step, UserProfile partialProfile) {
    onboardingStep = step;
    profile = partialProfile;
    _profileNeedsPush = true;
    _persist();
    unawaited(_pushProfileUpdate());
  }

  void skipOnboarding() {
    onboardingSkipped = true;
    onboardingStep = 0;
    hasCompletedOnboarding = true;
    isGuestMode = false;
    profile ??= UserProfile(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      accountType: AccountType.student,
      fullName: '',
      email: '',
      phone: '',
      whatsApp: '',
      countryOfResidence: '',
      preferredLanguage: localeCode,
    );
    _persist();
    update();
    Get.offAllNamed(AppRoutes.home);
  }

  bool get needsProfileCompletionBanner =>
      onboardingSkipped || (profile?.completionScore ?? 0) < 0.5;

  void completeOnboarding(UserProfile newProfile) {
    profile = newProfile;
    localeCode = newProfile.preferredLanguage;
    hasCompletedOnboarding = true;
    onboardingSkipped = false;
    onboardingStep = 0;
    isGuestMode = false;
    _cases.clear();
    _profileNeedsPush = true;
    unawaited(_pushProfileUpdate());
    _persist();
    update();
    unawaited(syncOneSignalIdentity());
    if (AppConfig.enableRemoteSync) {
      unawaited(syncRemoteData(silent: true));
      if (Get.isRegistered<PushNotificationService>()) {
        unawaited(registerDevicePushToken(Get.find<PushNotificationService>()));
      }
    }
  }

  void setThemeMode(ThemeMode mode) {
    themeMode = mode;
    _persist();
    update();
    AnalyticsService.instance.logThemeToggled(mode == ThemeMode.dark);
  }

  Future<void> logout() async {
    AnalyticsService.instance.logLogout();
    unawaited(OneSignalService.instance.logout());
    if (Get.isRegistered<AuthService>()) {
      await Get.find<AuthService>().clearSession();
    }
    profile = null;
    _profileNeedsPush = false;
    hasCompletedOnboarding = false;
    isGuestMode = false;
    latestOrientationSession = null;
    _savedItems.clear();
    _cases.clear();
    _orientationHistory.clear();
    _searchHistory.clear();
    _pendingOrientationAnswers = {};
    pendingOrientationQuestionIndex = 0;
    _persist();
    update();
  }

  void goToTab(int index) {
    final safeIndex = index.clamp(0, shellTabCount - 1);
    shellIndex = safeIndex;
    update();
  }

  void goToUniversitiesForField(String? fieldId) {
    universitiesInitialFieldId = fieldId;
    goToTab(StudentShellTab.universities);
  }

  void goToCommercialTab(int index) {
    commercialShellIndex =
        index.clamp(0, CommercialShellTab.count - 1);
    update();
  }

  void resetShell() {
    shellIndex = 0;
    commercialShellIndex = 0;
    update();
  }

  bool isSaved(SavedItemType type, String itemId) {
    return _savedItems
        .any((item) => item.type == type && item.itemId == itemId);
  }

  void toggleSaved(SavedItemType type, String itemId) {
    final index = _savedItems.indexWhere(
      (item) => item.type == type && item.itemId == itemId,
    );
    if (index >= 0) {
      final existing = _savedItems[index];
      _savedItems.removeAt(index);
      unawaited(_deleteRemoteSavedItem(existing));
      AnalyticsService.instance
          .logUnsaveItem(itemId: itemId, itemType: type.name);
      HapticFeedback.lightImpact();
    } else {
      final savedItem = SavedItem(type: type, itemId: itemId);
      _savedItems.add(savedItem);
      unawaited(_createRemoteSavedItem(savedItem));
      AnalyticsService.instance
          .logSaveItem(itemId: itemId, itemType: type.name);
      HapticFeedback.mediumImpact();
    }
    _persist();
    update();
  }

  AcademyCourseModel? getAcademyCourse(String? id) {
    if (id == null) return null;
    return academyCourses.firstWhereOrNull((c) => c.id == id);
  }

  List<AcademyLessonModel> getCourseLessons(String courseId) {
    return MockCatalog.academyLessons[courseId] ?? [];
  }

  bool hasPurchased(String courseId) {
    return _purchasedCourseIds.contains(courseId);
  }

  void purchaseCourse(String courseId) {
    if (!_purchasedCourseIds.contains(courseId)) {
      _purchasedCourseIds.add(courseId);
      _persist();
      update();
    }
  }

  // ── Roadmap Management ───────────────────────────────────────────────────

  bool isStepCompleted(String scholarshipId, RoadmapStepType type) {
    return _completedRoadmapSteps[scholarshipId]?.contains(type.name) ?? false;
  }

  void toggleRoadmapStep(String scholarshipId, RoadmapStepType type) {
    HapticFeedback.selectionClick();
    final steps = _completedRoadmapSteps[scholarshipId] ?? [];
    if (steps.contains(type.name)) {
      steps.remove(type.name);
    } else {
      steps.add(type.name);
    }
    _completedRoadmapSteps[scholarshipId] = steps;
    _persist();
    update();
  }

  Map<String, dynamic>? getNextUrgentMilestone() {
    // ... logic is fine ...
    return _findNextStep(
        scholarships.where((s) => isSaved(SavedItemType.scholarship, s.id)));
  }

  double getChildOverallProgressPercentage() {
    final saved =
        scholarships.where((s) => isSaved(SavedItemType.scholarship, s.id));
    if (saved.isEmpty) return 0.0;

    int totalSteps = saved.length * RoadmapEngine.getSteps().length;
    int completedCount = 0;

    for (final s in saved) {
      completedCount += (_completedRoadmapSteps[s.id]?.length ?? 0);
    }

    return completedCount / totalSteps;
  }

  Map<String, dynamic> getEstimatedFinancialSummary() {
    // Mock financial data based on profile
    final p = profile;
    double tuition = 12000; // Mock average
    double lifestyle = 8000;

    if (p != null) {
      if (p.targetCountryIds.contains('canada')) {
        tuition = 15000;
        lifestyle = 10000;
      } else if (p.targetCountryIds.contains('france')) {
        tuition = 5000;
        lifestyle = 8000;
      }
    }

    final savedScholarships =
        scholarships.where((s) => isSaved(SavedItemType.scholarship, s.id));
    double totalSavings =
        savedScholarships.length * 5000.0; // Mock scholarship value

    return {
      'totalCost': (tuition + lifestyle),
      'potentialSavings': totalSavings,
      'gap': (tuition + lifestyle) - totalSavings,
    };
  }

  Map<String, dynamic>? _findNextStep(
      Iterable<ScholarshipModel> savedScholarships) {
    final now = DateTime.now();
    Map<String, dynamic>? closest;
    DateTime? closestDate;

    for (final s in savedScholarships) {
      final deadline =
          RoadmapEngine.calculateDate(now.add(const Duration(days: 90)), 0);
      final steps = RoadmapEngine.getSteps();

      for (final step in steps) {
        if (!isStepCompleted(s.id, step.type)) {
          final stepDate =
              RoadmapEngine.calculateDate(deadline, step.daysBeforeDeadline);
          if (stepDate.isAfter(now)) {
            if (closestDate == null || stepDate.isBefore(closestDate)) {
              closestDate = stepDate;
              closest = {'scholarship': s, 'step': step, 'date': stepDate};
            }
          }
        }
      }
    }
    return closest;
  }

  /// Public pull-to-refresh — calls syncRemoteData and returns when done.
  ///
  /// IMPORTANT: do NOT name this `refresh()` — that would shadow
  /// `GetxController.refresh()`, which GetX calls internally to notify
  /// listeners. Naming this `pullToRefresh()` avoids triggering a full sync
  /// every time any widget rebuilds.
  Future<void> pullToRefresh() => syncRemoteData(silent: false, force: true);

  Future<OrientationSession> submitOrientation(
    Map<String, List<String>> answers,
  ) async {
    final activeProfile = profile;
    if (activeProfile == null) {
      throw StateError('Profile must exist before starting orientation.');
    }

    isSubmittingOrientation = true;
    update();

    OrientationSession session;
    try {
      if (AppConfig.enableRemoteSync) {
        final response = await _apiClient.submitOrientation(<String, dynamic>{
          'answers': answers,
          'profile': <String, dynamic>{
            'fullName': activeProfile.fullName,
            'currentLevel': activeProfile.currentLevel,
            'targetCountryIds': activeProfile.targetCountryIds,
            'fieldIds': activeProfile.fieldIds,
            'preferredLanguage': activeProfile.preferredLanguage,
          },
        });
        session = _orientationSessionFromApi(response, answers);
      } else {
        session = OrientationEngine.evaluate(
          profile: activeProfile,
          answers: answers,
          questions: orientationQuestions,
          fields: fields,
          scholarships: scholarships,
        );
      }
    } catch (e, s) {
      safeRecordError(
        e,
        s,
        reason: 'submitOrientation',
        domain: CrashlyticsObsDomain.sync,
        operation: 'submit_orientation',
      );
      session = OrientationEngine.evaluate(
        profile: activeProfile,
        answers: answers,
        questions: orientationQuestions,
        fields: fields,
        scholarships: scholarships,
      );
    } finally {
      isSubmittingOrientation = false;
    }

    latestOrientationSession = session;
    _orientationHistory.insert(0, session);

    if (session.recommendations.isNotEmpty) {
      final enrichedFieldIds = <String>{
        ...activeProfile.fieldIds,
        ...session.recommendations.map((item) => item.fieldId),
      }.toList();
      profile = activeProfile.copyWith(fieldIds: enrichedFieldIds);
    }

    clearOrientationProgress();
    _persist();
    update();
    HapticFeedback.heavyImpact();
    AnalyticsService.instance.logOrientationComplete(
      totalQuestions: orientationQuestions.length,
      matchCount: session.recommendations.length,
    );
    return session;
  }

  OrientationSession _orientationSessionFromApi(
    Map<String, dynamic> json,
    Map<String, List<String>> answers,
  ) {
    final locale = profile?.preferredLanguage ?? localeCode;
    final recommendations = (json['recommendations'] as List<dynamic>? ?? [])
        .map((item) {
          final map = item as Map<String, dynamic>;
          final explanation = map['explanation'];
          final jobsPayload = map['jobs'];
          final jobs = <String>[];
          if (jobsPayload is Map<String, dynamic>) {
            final localized =
                (locale.startsWith('en') ? jobsPayload['en'] : jobsPayload['fr'])
                    as List<dynamic>?;
            jobs.addAll(localized?.cast<String>() ?? const []);
          }
          final partnerCountries =
              (map['partnerCountryIds'] as List<dynamic>? ?? const [])
                  .cast<String>();
          return OrientationRecommendation(
            fieldId: map['fieldId'] as String? ?? '',
            score: map['score'] as int? ?? 55,
            explanation: explanation is Map<String, dynamic>
                ? LocalizedText(
                    fr: explanation['fr'] as String? ?? '',
                    en: explanation['en'] as String? ?? '',
                  )
                : const LocalizedText(fr: '', en: ''),
            relatedCountryIds: partnerCountries,
            relatedScholarshipIds: scholarships
                .where(
                  (s) => s.relatedFieldIds.contains(map['fieldId']),
                )
                .map((s) => s.id)
                .take(3)
                .toList(),
            jobs: jobs,
            iaResilience: map['iaResilience'] as String? ?? 'medium',
          );
        })
        .where((item) => item.fieldId.isNotEmpty)
        .toList();

    return OrientationSession(
      id: json['id'] as String? ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      completedAt: DateTime.tryParse(json['completedAt'] as String? ?? '') ??
          DateTime.now(),
      answers: answers,
      recommendations: recommendations,
    );
  }

  Future<void> fetchCommercialLeads({String filter = 'all'}) async {
    if (!isCommercial || !AppConfig.enableRemoteSync) return;
    final email = profile?.email;
    if (email == null || email.isEmpty) return;
    // Dedup the simultaneous startup fetch from the Leads + Conversations tabs.
    if (isLoadingCommercialLeads) return;

    isLoadingCommercialLeads = true;
    commercialLeadsError = null;
    update();

    try {
      final items = await _apiClient.listCommercialLeads(
        email: email,
        filter: filter,
      );
      _commercialLeads
        ..clear()
        ..addAll(items);
    } catch (e, s) {
      commercialLeadsError = userFacingSyncError(e, localeCode);
      safeRecordError(
        e,
        s,
        reason: 'fetchCommercialLeads',
        domain: CrashlyticsObsDomain.sync,
        operation: 'fetch_commercial_leads',
      );
    } finally {
      isLoadingCommercialLeads = false;
      update();
    }
  }

  Future<void> updateCommercialLeadTag(
    String caseId, {
    required String leadTag,
    String? discussionMotive,
  }) async {
    if (!AppConfig.enableRemoteSync) return;
    try {
      await _apiClient.updateCommercialLead(
        caseId,
        leadTag: leadTag,
        discussionMotive: discussionMotive,
      );
      await fetchCommercialLeads();
    } catch (e, s) {
      safeRecordError(
        e,
        s,
        reason: 'updateCommercialLeadTag',
        domain: CrashlyticsObsDomain.sync,
        operation: 'update_commercial_lead',
      );
      rethrow;
    }
  }

  Future<void> fetchCommercialStats() async {
    if (!isCommercial || !AppConfig.enableRemoteSync) return;
    final email = profile?.email;
    if (email == null || email.isEmpty) return;

    isLoadingCommercialStats = true;
    update();

    try {
      final data = await _apiClient.getCommercialStats(email: email);
      commercialStats = CommercialStats.fromApi(data);
    } catch (e, s) {
      safeRecordError(
        e,
        s,
        reason: 'fetchCommercialStats',
        domain: CrashlyticsObsDomain.sync,
        operation: 'fetch_commercial_stats',
      );
    } finally {
      isLoadingCommercialStats = false;
      update();
    }
  }

  /// Hydrate the Parcours videos from the offline cache, then refresh from the
  /// backend YouTube proxy when online. Safe to call repeatedly.
  Future<void> fetchParcoursVideos({bool force = false}) async {
    // 1. Offline-first: hydrate from Hive cache if we have nothing yet.
    if (_parcoursVideos.isEmpty && CatalogCacheService.isInitialized) {
      final cached = CatalogCacheService.instance.read(_parcoursCacheKey);
      if (cached.isNotEmpty) {
        _parcoursVideos
          ..clear()
          ..addAll(cached
              .whereType<Map<String, dynamic>>()
              .map(YoutubeVideo.fromApi));
        update();
      }
    }

    if (!AppConfig.enableRemoteSync) return;
    if (isLoadingParcours) return;
    if (!force && _parcoursVideos.isNotEmpty && parcoursConfigured) {
      // Already populated this session; skip redundant network call.
      return;
    }

    isLoadingParcours = true;
    parcoursError = null;
    update();

    try {
      final result = await _apiClient.listParcoursVideos();
      parcoursConfigured = result.configured;
      if (result.items.isNotEmpty) {
        _parcoursVideos
          ..clear()
          ..addAll(result.items);
        if (CatalogCacheService.isInitialized) {
          await CatalogCacheService.instance.write(
            _parcoursCacheKey,
            result.items.map((v) => v.toJson()).toList(),
          );
        }
      }
    } catch (e, s) {
      if (_parcoursVideos.isEmpty) {
        parcoursError = userFacingSyncError(e, localeCode);
      }
      safeRecordError(
        e,
        s,
        reason: 'fetchParcoursVideos',
        domain: CrashlyticsObsDomain.sync,
        operation: 'fetch_parcours_videos',
      );
    } finally {
      isLoadingParcours = false;
      update();
    }
  }

  // ── Orientation progress persistence ──────────────────────────

  void saveOrientationProgress(
    Map<String, List<String>> answers,
    int questionIndex,
  ) {
    _pendingOrientationAnswers = Map.of(answers);
    pendingOrientationQuestionIndex = questionIndex;
    _persist();
  }

  void clearOrientationProgress() {
    _pendingOrientationAnswers = {};
    pendingOrientationQuestionIndex = 0;
    _persist();
  }

  // ── Profile update ──────────────────────────────────────────

  void updateProfile(UserProfile newProfile) {
    profile = newProfile;
    _profileNeedsPush = true;
    unawaited(_pushProfileUpdate());
    _persist();
    update();
  }

  // ── Search ──────────────────────────────────────────────────

  AppSearchContext get _searchContext => AppSearchContext(
        localeCode: localeCode,
        fields: fields,
        countries: countries,
        institutions: institutions,
        programs: programs,
        scholarships: scholarships,
        profile: profile,
        latestOrientationSession: latestOrientationSession,
      );

  AppSearchService get _searchService => AppSearchService(_searchContext);

  void addSearchQuery(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    _searchHistory.remove(trimmed);
    _searchHistory.insert(0, trimmed);
    if (_searchHistory.length > 10) _searchHistory.removeLast();
    _persist();
    AnalyticsService.instance.logSearch(trimmed);
  }

  void clearSearchHistory() {
    _searchHistory.clear();
    _persist();
    update();
  }

  List<SearchResult> search(String query) => _searchService.run(query);

  int fieldMatch(FieldModel field) => _searchService.fieldMatch(field);

  int programMatch(ProgramModel program) =>
      _searchService.programMatch(program);

  int institutionMatch(InstitutionModel institution) =>
      _searchService.institutionMatch(institution);

  List<FieldModel> get recommendedFields => _searchService.recommendedFields;

  List<ProgramModel> get recommendedPrograms =>
      _searchService.recommendedPrograms;

  List<InstitutionModel> get recommendedInstitutions =>
      _searchService.recommendedInstitutions;

  List<String> matchExplanation(SearchResultType type, String id) =>
      _searchService.matchExplanation(type, id);

  List<ScholarshipModel> get recommendedScholarships =>
      _searchService.recommendedScholarships;

  int scholarshipMatch(ScholarshipModel scholarship) =>
      _searchService.scholarshipMatch(scholarship);

  StudentCase submitCase({
    required CaseType type,
    required String title,
    required String description,
    required String contextLabel,
    required ContactMethod contactMethod,
  }) {
    if (!hasCompletedOnboarding || profile == null) {
      throw StateError(
        'Onboarding must be completed before creating a transactional case.',
      );
    }

    final now = DateTime.now();
    final referenceId = (_cases.length + 1).toString().padLeft(3, '0');
    final created = StudentCase(
      id: 'case-${now.millisecondsSinceEpoch}',
      referenceCode: 'KPB-${now.year}-$referenceId',
      type: type,
      title: LocalizedText(fr: title, en: title),
      description: LocalizedText(fr: description, en: description),
      contextLabel: LocalizedText(fr: contextLabel, en: contextLabel),
      status: CaseStatus.submitted,
      preferredContactMethod: contactMethod,
      createdAt: now,
      updatedAt: now,
      nextStepTitle: const LocalizedText(
        fr: 'Votre dossier est en revue',
        en: 'Your case is under review',
      ),
      nextStepDescription: const LocalizedText(
        fr: 'L’équipe KPB va qualifier votre demande, vérifier vos informations et vous attribuer un conseiller.',
        en: 'The KPB team will review your request, verify your information, and assign a counselor.',
      ),
      timeline: [
        CaseTimelineEvent(
          id: 'submitted-${now.millisecondsSinceEpoch}',
          title: const LocalizedText(
              fr: 'Demande envoyée', en: 'Request submitted'),
          description: const LocalizedText(
            fr: 'Votre demande est visible dans My Cases et a été transmise à l’équipe KPB.',
            en: 'Your request now appears in My Cases and has been sent to the KPB team.',
          ),
          createdAt: now,
          status: CaseStatus.submitted,
        ),
      ],
      messages: [
        CaseMessage(
          id: 'welcome-${now.millisecondsSinceEpoch}',
          senderName: 'KPB Operations',
          senderRole: 'system',
          body: const LocalizedText(
            fr: 'Merci pour votre demande. Nous revenons vers vous avec la prochaine étape.',
            en: 'Thanks for your request. We will come back to you with the next step.',
          ),
          createdAt: now,
        ),
      ],
      documentRequests: const [
        DocumentRequest(
          id: 'doc-profile',
          title: LocalizedText(
              fr: 'Profil académique complet', en: 'Complete academic profile'),
          isProvided: false,
        ),
      ],
    );
    _cases.insert(0, created);
    _persist();
    update();
    HapticFeedback.heavyImpact();
    AnalyticsService.instance.logCaseCreated(caseType: type.name);
    Get.snackbar(
      'case_created_title'.tr,
      'case_created_body'.trParams({'code': created.referenceCode}),
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(12),
      duration: const Duration(seconds: 4),
      mainButton: TextButton(
        onPressed: () {
          shellIndex = StudentShellTab.cases;
          update();
          Get.closeCurrentSnackbar();
        },
        child: Text('view'.tr),
      ),
    );
    unawaited(_createRemoteCase(created));
    return created;
  }

  void addCaseMessage(String caseId, String text) {
    final index = _cases.indexWhere((item) => item.id == caseId);
    if (index < 0 || text.trim().isEmpty) return;
    final caseItem = _cases[index];
    final now = DateTime.now();
    final updatedMessages = [
      ...caseItem.messages,
      CaseMessage(
        id: 'user-${now.millisecondsSinceEpoch}',
        senderName: profile?.fullName ?? 'Student',
        senderRole: 'student',
        body: LocalizedText(fr: text, en: text),
        createdAt: now,
      ),
    ];
    _cases[index] = caseItem.copyWith(
      updatedAt: now,
      status: CaseStatus.awaitingStudent,
      messages: updatedMessages,
      timeline: [
        ...caseItem.timeline,
        CaseTimelineEvent(
          id: 'timeline-${now.millisecondsSinceEpoch}',
          title: const LocalizedText(
            fr: 'Réponse de l’étudiant',
            en: 'Student reply',
          ),
          description: const LocalizedText(
            fr: 'Le dossier a été mis à jour avec un nouveau message.',
            en: 'The case has been updated with a new message.',
          ),
          createdAt: now,
          status: CaseStatus.awaitingStudent,
        ),
      ],
    );
    _persist();
    update();

    if (ConnectivityService.instance.isOnline) {
      if (_caseSocket.isConnected && _activeCaseSocketId == caseId) {
        _caseSocket.sendMessage(caseId, text.trim());
      } else {
        unawaited(_createRemoteCaseMessage(caseId, text));
      }
    } else {
      unawaited(CaseMessageOutbox.instance.enqueue(
        caseId: caseId,
        body: text,
        senderName: profile?.fullName ?? 'Student',
      ));
    }
  }

  int unreadMessagesForCase(String caseId) {
    final caseItem = _cases.firstWhereOrNull((item) => item.id == caseId);
    if (caseItem == null) return 0;
    final lastRead = _caseLastReadAt[caseId] ?? caseItem.createdAt;
    return caseItem.messages
        .where(
          (message) =>
              message.senderRole != 'student' &&
              message.createdAt.isAfter(lastRead),
        )
        .length;
  }

  int get totalUnreadCaseMessages =>
      _cases.fold(0, (sum, item) => sum + unreadMessagesForCase(item.id));

  void markCaseMessagesRead(String caseId) {
    _caseLastReadAt[caseId] = DateTime.now();
    _persist();
    update();
  }

  Future<void> connectCaseDetailSocket(String caseId) async {
    if (!AppConfig.enableRemoteSync) return;
    if (!await _apiClient.hasAuthSession()) return;

    _activeCaseSocketId = caseId;
    await _caseSocket.connect(caseId, fullName: profile?.fullName);

    _caseSocket.onMessage((data) => ingestRemoteCaseMessage(caseId, data));
    _caseSocket.onCaseUpdated((data) {
      try {
        _upsertCase(CaseApiCodec.studentCaseFromApi(data));
        _persist();
        update();
      } catch (_) {}
    });
    _caseSocket.onTyping((data) {
      final isTyping = data['isTyping'] as bool? ?? false;
      if (isCaseAdvisorTyping == isTyping) return;
      isCaseAdvisorTyping = isTyping;
      update();
      if (isTyping) {
        // Auto-reset after 4 s in case the stop event is missed.
        Future.delayed(const Duration(seconds: 4), () {
          if (isCaseAdvisorTyping) {
            isCaseAdvisorTyping = false;
            update();
          }
        });
      }
    });
  }

  Future<void> disconnectCaseDetailSocket() async {
    await _caseSocket.disconnect();
    _activeCaseSocketId = null;
    isCaseAdvisorTyping = false;
    update();
  }

  void sendCaseTyping(String caseId, bool isTyping) {
    if (_caseSocket.isConnected) {
      _caseSocket.sendTyping(caseId, isTyping);
    }
  }

  void ingestRemoteCaseMessage(String caseId, Map<String, dynamic> data) {
    final index = _cases.indexWhere((item) => item.id == caseId);
    if (index < 0) return;

    final messageId = data['id'] as String? ?? '';
    final caseItem = _cases[index];
    if (messageId.isNotEmpty &&
        caseItem.messages.any((message) => message.id == messageId)) {
      return;
    }

    final body = data['body'] as String? ?? '';
    final senderRole = data['senderRole'] as String? ?? 'counselor';
    final message = CaseMessage(
      id: messageId.isNotEmpty
          ? messageId
          : 'remote-${DateTime.now().millisecondsSinceEpoch}',
      senderName: data['senderName'] as String? ?? 'KPB',
      senderRole: senderRole,
      body: LocalizedText(fr: body, en: body),
      createdAt: DateTime.tryParse(data['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );

    final withoutOptimistic = senderRole == 'student'
        ? caseItem.messages
            .where(
              (existing) =>
                  !(existing.id.startsWith('user-') && existing.body.fr == body),
            )
            .toList()
        : caseItem.messages;

    _cases[index] = caseItem.copyWith(
      messages: [...withoutOptimistic, message],
      updatedAt: DateTime.now(),
    );
    _persist();
    update();
  }

  void uploadDocument(String caseId, String documentId, String filePath) {
    final index = _cases.indexWhere((item) => item.id == caseId);
    if (index < 0) return;
    final caseItem = _cases[index];
    final updatedDocs = caseItem.documentRequests
        .map((doc) =>
            doc.id == documentId ? doc.copyWith(isProvided: true) : doc)
        .toList();
    _cases[index] = caseItem.copyWith(
      updatedAt: DateTime.now(),
      documentRequests: updatedDocs,
    );
    _persist();
    update();
    final document =
        updatedDocs.firstWhereOrNull((item) => item.id == documentId);
    if (document != null) {
      unawaited(_uploadRemoteCaseDocument(caseId, document, filePath));
    }
  }

  Future<void> syncRemoteData({bool silent = false, bool force = false}) async {
    if (!AppConfig.enableRemoteSync) return;
    if (isSyncing) return;

    final now = DateTime.now();
    if (!force && _syncBackoffUntil != null && now.isBefore(_syncBackoffUntil!)) {
      return;
    }
    if (!force &&
        _lastSyncAttemptAt != null &&
        now.difference(_lastSyncAttemptAt!) < _minSyncInterval) {
      return;
    }

    isSyncing = true;
    _lastSyncAttemptAt = now;
    if (!silent) {
      syncError = null;
      update();
    }

    final syncStarted = DateTime.now();
    var catalogHiveFallbackCount = 0;
    var authSyncFailed = false;
    void onCatalogHiveFallback(String resource, int attempts) {
      catalogHiveFallbackCount++;
      SyncTelemetry.catalogHiveFallback(resource: resource, attempts: attempts);
    }

    SyncTelemetry.fullSyncStarted();

    try {
      final hasAuth = await _apiClient.hasAuthSession();

      if (hasAuth) {
        try {
          // Flush any messages typed while offline
          await flushPendingCaseMessages();

          await _pushProfileUpdate();

          if (!_profileNeedsPush) {
            final profileJson = await _apiClient.getProfile();
            profile = ProfileApiCodec.userProfileFromApi(
              profileJson,
              fallbackLocale: localeCode,
            );
            localeCode = profile?.preferredLanguage ?? localeCode;
          } else {
            SyncTelemetry.profileSkippedRemotePull(
              reason: 'pending_local_patch',
            );
          }

          final remoteCasesRaw = await _apiClient.listCases();
          final remoteCases =
              remoteCasesRaw.map(CaseApiCodec.studentCaseFromApi).toList();
          final (mergedCases, caseStats) =
              mergeCasesRemoteWithLocal(remoteCases, List<StudentCase>.of(_cases));
          SyncTelemetry.casesMerged(
            remoteCount: caseStats.remoteCount,
            localWinCount: caseStats.localWinCount,
            keptLocalOnlyCount: caseStats.keptLocalOnlyCount,
          );
          _cases
            ..clear()
            ..addAll(mergedCases);

          final remoteSavedItems = await _apiClient.listSavedItems();
          final remoteSavedParsed =
              remoteSavedItems.map(SavedItemApiCodec.fromApi).toList();
          final (mergedSaved, unionExtraLocals) = mergeSavedItemsUnion(
            remoteSavedParsed,
            List<SavedItem>.of(_savedItems),
          );
          SyncTelemetry.savedItemsMerged(unionExtraLocals: unionExtraLocals);
          _savedItems
            ..clear()
            ..addAll(mergedSaved);

          _remoteSavedItemIds
            ..clear()
            ..addEntries(
              remoteSavedItems.whereType<Map<String, dynamic>>().map(
                    (item) => MapEntry(
                      _savedItemKey(
                        SavedItemApiCodec.parseType(item['type'] as String?) ??
                            SavedItemType.field,
                        item['itemId'] as String? ?? '',
                      ),
                      item['id'] as String? ?? '',
                    ),
                  ),
            );

          for (final item in _savedItems) {
            final key = _savedItemKey(item.type, item.itemId);
            final id = _remoteSavedItemIds[key];
            if (id == null || id.isEmpty) {
              unawaited(_createRemoteSavedItem(item));
            }
          }
        } catch (error, stack) {
          authSyncFailed = true;
          if (error is DioException && error.response?.statusCode == 429) {
            _syncBackoffUntil = DateTime.now().add(const Duration(seconds: 60));
            syncError = userFacingSyncError(error, localeCode);
          } else {
            syncError = userFacingSyncError(error, localeCode);
            safeRecordError(
              error,
              stack,
              reason: 'syncRemoteData.auth',
              domain: CrashlyticsObsDomain.sync,
              operation: 'sync_remote_data_auth',
            );
          }
        }
      } else {
        SyncTelemetry.profileSkippedRemotePull(reason: 'guest_no_auth_token');
      }

      await syncCatalogResource<FieldModel>(
        _apiClient,
        'fields',
        fields,
        FieldModel.fromJson,
        onHiveFallback: onCatalogHiveFallback,
      );
      await syncCatalogResource<CountryModel>(
        _apiClient,
        'countries',
        countries,
        CountryModel.fromJson,
        onHiveFallback: onCatalogHiveFallback,
      );
      await syncCatalogResource<InstitutionModel>(
        _apiClient,
        'institutions',
        institutions,
        InstitutionModel.fromJson,
        onHiveFallback: onCatalogHiveFallback,
      );
      await syncCatalogResource<ProgramModel>(
        _apiClient,
        'programs',
        programs,
        ProgramModel.fromJson,
        onHiveFallback: onCatalogHiveFallback,
      );
      await syncCatalogResource<ScholarshipModel>(
        _apiClient,
        'scholarships',
        scholarships,
        ScholarshipModel.fromJson,
        onHiveFallback: onCatalogHiveFallback,
      );
      _applyMvpCountryLock();

      lastSyncedAt = DateTime.now();
      if (!authSyncFailed) {
        syncError = null;
      }
      _persist();
      SyncTelemetry.fullSyncFinished(
        success: !authSyncFailed,
        elapsed: DateTime.now().difference(syncStarted),
        catalogHiveFallbackCount: catalogHiveFallbackCount,
      );
    } catch (error, stack) {
      if (error is DioException && error.response?.statusCode == 429) {
        _syncBackoffUntil = DateTime.now().add(const Duration(seconds: 60));
      }
      syncError = userFacingSyncError(error, localeCode);
      if (error is! DioException || error.response?.statusCode != 429) {
        safeRecordError(
          error,
          stack,
          reason: 'syncRemoteData',
          domain: CrashlyticsObsDomain.sync,
          operation: 'sync_remote_data',
        );
      }
      SyncTelemetry.fullSyncFinished(
        success: false,
        elapsed: DateTime.now().difference(syncStarted),
        catalogHiveFallbackCount: catalogHiveFallbackCount,
      );
    } finally {
      isSyncing = false;
      update();
    }
  }

  /// Restricts the catalog to the nine MVP destination countries. Drops any
  /// country/institution/program/scholarship outside the launch scope so a
  /// stale Hive cache or a broader remote payload can't surface V1.1+ data.
  void _applyMvpCountryLock() {
    if (!AppConfig.mvpOnly) return;
    countries.retainWhere((c) => isMvpCountryId(c.id));
    institutions.retainWhere((i) => isMvpCountryId(i.countryId));
    programs.retainWhere((p) => isMvpCountryId(p.countryId));
    // Keep cross-border scholarships (no specific country) alongside MVP ones.
    scholarships.retainWhere(
      (s) => s.countryId.trim().isEmpty || isMvpCountryId(s.countryId),
    );
  }

  List<StudentCase> casesByType(CaseType? filter) {
    if (filter == null) return cases;
    return cases.where((item) => item.type == filter).toList();
  }

  FieldModel? fieldByIdOrNull(String id) =>
      fields.firstWhereOrNull((item) => item.id == id);
  CountryModel? countryByIdOrNull(String id) {
    final normalized = normalizeCountryId(id);
    return countries.firstWhereOrNull(
      (item) => item.id == id || item.id == normalized,
    );
  }
  InstitutionModel? institutionByIdOrNull(String id) =>
      institutions.firstWhereOrNull((item) => item.id == id);
  ProgramModel? programByIdOrNull(String id) =>
      programs.firstWhereOrNull((item) => item.id == id);
  ScholarshipModel? scholarshipByIdOrNull(String id) =>
      scholarships.firstWhereOrNull((item) => item.id == id);

  /// Non-null convenience accessors — prefer the OrNull variants for new code.
  FieldModel fieldById(String id) => fields.firstWhere((item) => item.id == id);
  CountryModel countryById(String id) {
    final match = countryByIdOrNull(id);
    if (match != null) return match;
    throw StateError('Country not found: $id');
  }

  Future<CountryModel> loadCountryDetail(String countryKey) async {
    final normalized = normalizeCountryId(countryKey);
    final cached = _countryDetailCache[normalized];
    if (cached?.eligibilityQuiz != null) return cached!;

    final base = countryByIdOrNull(normalized) ?? countryByIdOrNull(countryKey);

    if (AppConfig.enableRemoteSync) {
      try {
        final json = await _apiClient.getCountryDetail(normalized);
        final detail = CountryModel.fromJson(json);
        _countryDetailCache[normalized] = detail;
        final idx = countries.indexWhere(
          (c) => c.id == detail.id || c.id == normalized,
        );
        if (idx >= 0) {
          countries[idx] = detail;
        }
        update();
        return detail;
      } catch (_) {
        if (base != null) return base;
        rethrow;
      }
    }

    if (base != null) return base;
    throw StateError('Country not found: $countryKey');
  }

  Future<CountryQuizResultModel> submitCountryQuiz(
    String countryKey,
    Map<String, String> answers,
  ) async {
    final normalized = normalizeCountryId(countryKey);
    if (!AppConfig.enableRemoteSync) {
      final detail = await loadCountryDetail(normalized);
      final quiz = detail.eligibilityQuiz;
      if (quiz == null || quiz.questions.isEmpty) {
        throw StateError('Quiz unavailable offline');
      }
      return CountryQuizResultModel(
        verdict: EligibilityVerdict.eligibleWithConditions,
        verdictTitle: quiz.verdicts['eligible_with_conditions']?.titleFor(localeCode) ??
            'Résultat provisoire',
        verdictMessage: quiz.verdicts['eligible_with_conditions']?.messageFor(localeCode) ??
            '',
        ctaLabel: quiz.verdicts['eligible_with_conditions']?.ctaFor(localeCode) ??
            'Continuer',
        countryId: detail.id,
      );
    }

    final json = await _apiClient.submitCountryQuiz(normalized, answers);
    return CountryQuizResultModel.fromJson(json, localeCode: localeCode);
  }
  InstitutionModel institutionById(String id) =>
      institutions.firstWhere((item) => item.id == id);
  ProgramModel programById(String id) =>
      programs.firstWhere((item) => item.id == id);
  ScholarshipModel scholarshipById(String id) =>
      scholarships.firstWhere((item) => item.id == id);

  AppSnapshot get _snapshot => AppSnapshot(
        localeCode: localeCode,
        hasSeenIntro: hasSeenIntro,
        isGuestMode: isGuestMode,
        isAppLockEnabled: isAppLockEnabled,
        dataSaverEnabled: dataSaverEnabled,
        hasCompletedOnboarding: hasCompletedOnboarding,
        themeMode: themeMode,
        profile: profile,
        savedItems: _savedItems,
        cases: _cases,
        orientationHistory: _orientationHistory,
        searchHistory: _searchHistory,
        pendingOrientationAnswers: _pendingOrientationAnswers,
        pendingOrientationQuestionIndex: pendingOrientationQuestionIndex,
        fields: const [],
        countries: const [],
        institutions: const [],
        programs: const [],
        scholarships: const [],
        purchasedCourseIds: _purchasedCourseIds,
        completedRoadmapSteps: _completedRoadmapSteps,
        profileNeedsPush: _profileNeedsPush,
        onboardingStep: onboardingStep,
        onboardingSkipped: onboardingSkipped,
        caseLastReadAt: _caseLastReadAt.map(
          (key, value) => MapEntry(key, value.toIso8601String()),
        ),
      );

  void _persist() {
    unawaited(_repository.saveSnapshot(_snapshot));
  }

  Future<void> _pushProfileUpdate() async {
    if (!AppConfig.enableRemoteSync) {
      _profileNeedsPush = false;
      return;
    }
    if (profile == null) return;
    if (!await _apiClient.hasAuthSession()) {
      _profileNeedsPush = false;
      _persist();
      return;
    }
    if (!ConnectivityService.instance.isOnline) {
      _profileNeedsPush = true;
      _persist();
      return;
    }
    try {
      await _apiClient.updateProfile(_userProfilePayload(profile!));
      _profileNeedsPush = false;
      _persist();
    } catch (e, s) {
      safeRecordError(
        e,
        s,
        reason: 'pushProfileUpdate',
        domain: CrashlyticsObsDomain.profile,
        operation: 'push_profile_update',
      );
      _profileNeedsPush = true;
      _persist();
    }
  }

  Future<void> _createRemoteCase(StudentCase localCase) async {
    if (!AppConfig.enableRemoteSync) return;
    try {
      final response = await _apiClient.createCase(<String, dynamic>{
        'type': CaseApiCodec.encodeCaseType(localCase.type),
        'title': resolve(localCase.title),
        'description': resolve(localCase.description),
        'contextLabel': resolve(localCase.contextLabel),
        'preferredContactMethod': CaseApiCodec.encodeContactMethod(
          localCase.preferredContactMethod,
        ),
      });
      _cases.removeWhere((item) => item.id == localCase.id);
      _upsertCase(CaseApiCodec.studentCaseFromApi(response));
      _persist();
      update();
    } catch (e, s) {
      safeRecordError(
        e,
        s,
        reason: 'createRemoteCase',
        domain: CrashlyticsObsDomain.cases,
        operation: 'create_remote_case',
      );
    }
  }

  Future<void> _createRemoteCaseMessage(String caseId, String text) async {
    if (!AppConfig.enableRemoteSync) return;
    final senderName = profile?.fullName ?? 'Student';

    // If we already know we're offline, go straight to the outbox — no need
    // to burn a DNS lookup and block the UI on a 5-second timeout.
    if (!ConnectivityService.instance.isOnline) {
      await CaseMessageOutbox.instance.enqueue(
        caseId: caseId,
        body: text,
        senderName: senderName,
      );
      return;
    }

    try {
      await _apiClient.createCaseMessage(caseId, <String, dynamic>{
        'senderName': senderName,
        'senderRole': 'student',
        'body': text,
      });
      final response = await _apiClient.getCase(caseId);
      _upsertCase(CaseApiCodec.studentCaseFromApi(response));
      _persist();
      update();
    } catch (e, s) {
      safeRecordError(
        e,
        s,
        reason: 'createRemoteCaseMessage',
        domain: CrashlyticsObsDomain.cases,
        operation: 'create_remote_case_message',
      );
      // Network blip — queue it. The connectivity listener will retry.
      await CaseMessageOutbox.instance.enqueue(
        caseId: caseId,
        body: text,
        senderName: senderName,
      );
    }
  }

  /// Flush the offline message queue. Called on connectivity-restored events.
  Future<void> flushPendingCaseMessages() async {
    if (!AppConfig.enableRemoteSync) return;
    if (!await _apiClient.hasAuthSession()) return;
    final outbox = CaseMessageOutbox.instance;
    final touched = <String>{};
    for (final entry in outbox.pending.toList()) {
      try {
        await _apiClient.createCaseMessage(entry.caseId, <String, dynamic>{
          'senderName': entry.senderName,
          'senderRole': 'student',
          'body': entry.body,
        });
        await outbox.remove(entry.key);
        touched.add(entry.caseId);
      } catch (e, s) {
        safeRecordError(
          e,
          s,
          reason: 'flushPendingCaseMessages',
          domain: CrashlyticsObsDomain.cases,
          operation: 'flush_pending_case_messages',
        );
        await outbox.markFailure(entry.key, entry);
      }
    }
    for (final caseId in touched) {
      try {
        final response = await _apiClient.getCase(caseId);
        _upsertCase(CaseApiCodec.studentCaseFromApi(response));
      } catch (e, s) {
        safeRecordError(
          e,
          s,
          reason: 'flushPendingCaseMessages.getCase',
          domain: CrashlyticsObsDomain.cases,
          operation: 'flush_pending_case_messages_get_case',
        );
      }
    }
    if (touched.isNotEmpty) {
      _persist();
      update();
    }
  }

  int get pendingOutboundMessageCount =>
      CaseMessageOutbox.instance.pendingCount;

  bool caseHasQueuedMessages(String caseId) =>
      CaseMessageOutbox.instance.hasPendingFor(caseId);

  /// Best-effort push token registration for transactional notifications.
  Future<void> registerDevicePushToken(PushNotificationService pushService) async {
    if (!AppConfig.enableRemoteSync) return;
    if (!await _apiClient.hasAuthSession()) return;
    try {
      final token = await pushService.getToken();
      if (token == null || token.isEmpty) return;
      final platform =
          GetPlatform.isIOS ? 'ios' : (GetPlatform.isAndroid ? 'android' : 'unknown');
      await _apiClient.registerDeviceToken(token, platform);
    } catch (e, s) {
      safeRecordError(
        e,
        s,
        reason: 'registerDevicePushToken',
        domain: CrashlyticsObsDomain.sync,
        operation: 'register_device_push_token',
      );
    }
  }

  /// Link the current profile to OneSignal (external id + targeting tags).
  /// Safe to call repeatedly; a no-op when OneSignal isn't configured.
  Future<void> syncOneSignalIdentity() async {
    final current = profile;
    if (current == null) return;
    final countryId = current.targetCountryIds.isNotEmpty
        ? current.targetCountryIds.first
        : current.countryOfResidence;
    await OneSignalService.instance.login(
      userId: current.id,
      email: current.email,
      tags: {
        'account_type': current.accountType.name,
        'level': current.currentLevel ?? '',
        'target_country': countryId,
        'locale': localeCode,
      },
    );
  }

  Future<void> _uploadRemoteCaseDocument(
    String caseId,
    DocumentRequest document,
    String filePath,
  ) async {
    if (!AppConfig.enableRemoteSync) return;
    try {
      await _apiClient.uploadCaseDocumentFile(
        caseId: caseId,
        filePath: filePath,
        title: resolve(document.title),
      );
      final response = await _apiClient.getCase(caseId);
      _upsertCase(CaseApiCodec.studentCaseFromApi(response));
      _persist();
      update();
    } catch (e, s) {
      safeRecordError(
        e,
        s,
        reason: 'uploadRemoteCaseDocument',
        domain: CrashlyticsObsDomain.cases,
        operation: 'upload_remote_case_document',
      );
    }
  }

  Future<void> _createRemoteSavedItem(SavedItem item) async {
    if (!AppConfig.enableRemoteSync) return;
    try {
      final response = await _apiClient.createSavedItem(<String, dynamic>{
        'type': item.type.name,
        'itemId': item.itemId,
      });
      final savedId = response['id'] as String?;
      if (savedId != null && savedId.isNotEmpty) {
        _remoteSavedItemIds[_savedItemKey(item.type, item.itemId)] = savedId;
      }
    } catch (e, s) {
      safeRecordError(
        e,
        s,
        reason: 'createRemoteSavedItem',
        domain: CrashlyticsObsDomain.savedItems,
        operation: 'create_remote_saved_item',
      );
    }
  }

  Future<void> _deleteRemoteSavedItem(SavedItem item) async {
    if (!AppConfig.enableRemoteSync) return;
    try {
      final key = _savedItemKey(item.type, item.itemId);
      final savedId = _remoteSavedItemIds[key];
      if (savedId != null && savedId.isNotEmpty) {
        await _apiClient.deleteSavedItem(savedId);
        _remoteSavedItemIds.remove(key);
      }
    } catch (e, s) {
      safeRecordError(
        e,
        s,
        reason: 'deleteRemoteSavedItem',
        domain: CrashlyticsObsDomain.savedItems,
        operation: 'delete_remote_saved_item',
      );
    }
  }

  String _savedItemKey(SavedItemType type, String itemId) =>
      '${type.name}:$itemId';

  Map<String, dynamic> _userProfilePayload(UserProfile profile) {
    return <String, dynamic>{
      'fullName': profile.fullName,
      'email': profile.email,
      'phone': profile.phone,
      'whatsApp': profile.whatsApp,
      'countryOfResidence': profile.countryOfResidence,
      'preferredLanguage': profile.preferredLanguage,
      'currentLevel': profile.currentLevel,
      'targetLevel': profile.targetLevel,
      'languageLevel': profile.languageLevel,
      'fieldIds': profile.fieldIds,
      'targetCountryIds': profile.targetCountryIds,
      'gradeRange': profile.bacSeries ?? profile.gradeRange,
      'wantsScholarshipSupport': profile.wantsScholarshipSupport,
      'availableDocuments': profile.availableDocuments,
    };
  }

  void _upsertCase(StudentCase caseItem) {
    final index = _cases.indexWhere((item) => item.id == caseItem.id);
    if (index >= 0) {
      _cases[index] = caseItem;
    } else {
      _cases.insert(0, caseItem);
    }
  }
}
