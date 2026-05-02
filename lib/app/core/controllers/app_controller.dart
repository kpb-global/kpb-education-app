import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:collection/collection.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

import '../services/analytics_service.dart';
import '../services/case_message_outbox.dart';
import '../services/catalog_cache_service.dart';
import '../services/connectivity_service.dart';

import '../config/app_config.dart';
import '../data/mock_catalog.dart';
import '../data/orientation_engine.dart';
import '../data/roadmap_engine.dart';
import '../models/app_models.dart';
import '../repositories/app_api_client.dart';
import '../repositories/app_repository.dart';
import '../repositories/app_snapshot.dart';
import '../utils/user_facing_sync_error.dart';

class AppController extends GetxController {
  AppController({
    required AppRepository repository,
    AppApiClient? apiClient,
  })  : _repository = repository,
        _apiClient = apiClient ?? AppApiClient();

  final AppRepository _repository;
  final AppApiClient _apiClient;

  String localeCode = 'fr';
  bool hasSeenIntro = false;
  bool isAppLockEnabled = false;
  bool hasCompletedOnboarding = false;
  ThemeMode themeMode = ThemeMode.system;
  int shellIndex = 0;
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
  final List<ServiceOffer> serviceOffers = List<ServiceOffer>.of(MockCatalog.serviceOffers);
  final List<SupportDestination> supportDestinations = List<SupportDestination>.of(MockCatalog.supportDestinations);
  final List<ArticleModel> articles = List<ArticleModel>.of(MockCatalog.articles);
  final List<ForumCategoryModel> forumCategories = List<ForumCategoryModel>.of(MockCatalog.forumCategories);
  final List<ForumTopicTagModel> forumTopicTags = List<ForumTopicTagModel>.of(MockCatalog.forumTopicTags);
  final List<OrientationQuestion> orientationQuestions =
      MockCatalog.orientationQuestions;

  final List<SavedItem> _savedItems = <SavedItem>[];
  final List<StudentCase> _cases = <StudentCase>[];
  final List<OrientationSession> _orientationHistory = <OrientationSession>[];
  final Map<String, String> _remoteSavedItemIds = <String, String>{};
  final List<String> _searchHistory = <String>[];
  Map<String, List<String>> _pendingOrientationAnswers = {};
  final List<String> _purchasedCourseIds = <String>[];
  Map<String, List<String>> _completedRoadmapSteps = {};
  int pendingOrientationQuestionIndex = 0;

  List<SavedItem> get savedItems => List.unmodifiable(_savedItems);
  List<StudentCase> get cases => List.unmodifiable(_cases);
  List<OrientationSession> get orientationHistory =>
      List.unmodifiable(_orientationHistory);
  List<String> get searchHistory => List.unmodifiable(_searchHistory);
  List<String> get purchasedCourseIds => List.unmodifiable(_purchasedCourseIds);
  Map<String, List<String>> get pendingOrientationAnswers =>
      Map.unmodifiable(_pendingOrientationAnswers);

  bool get isStudent => profile?.accountType == AccountType.student;
  bool get isParent => profile?.accountType == AccountType.parent;
  bool get isPartner => profile?.accountType == AccountType.partner;
  List<ServiceOffer> get publishedServiceOffers => serviceOffers
      .where((item) => item.status == PublicationStatus.published)
      .toList();
  List<SupportDestination> get visibleSupportDestinations =>
      supportDestinations
          .where(
            (item) =>
                item.status == PublicationStatus.published && item.isVisible,
          )
          .toList();
  List<ArticleModel> get publishedArticles =>
      articles.where((item) => item.status == PublicationStatus.published).toList()
        ..sort(
          (left, right) => (right.publishedAt ?? DateTime.fromMillisecondsSinceEpoch(0))
              .compareTo(left.publishedAt ?? DateTime.fromMillisecondsSinceEpoch(0)),
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
    isAppLockEnabled = snapshot.isAppLockEnabled;
    hasCompletedOnboarding = snapshot.hasCompletedOnboarding;
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
    themeMode = snapshot.themeMode;
    latestOrientationSession = _orientationHistory.isNotEmpty
        ? _orientationHistory.first
        : null;
    _pendingOrientationAnswers = Map.of(snapshot.pendingOrientationAnswers);
    pendingOrientationQuestionIndex = snapshot.pendingOrientationQuestionIndex;
    fields..clear()..addAll(snapshot.fields.isNotEmpty ? snapshot.fields : MockCatalog.fields);
    countries..clear()..addAll(snapshot.countries.isNotEmpty ? snapshot.countries : MockCatalog.countries);
    institutions..clear()..addAll(snapshot.institutions.isNotEmpty ? snapshot.institutions : MockCatalog.institutions);
    programs..clear()..addAll(snapshot.programs.isNotEmpty ? snapshot.programs : MockCatalog.programs);
    scholarships..clear()..addAll(snapshot.scholarships.isNotEmpty ? snapshot.scholarships : MockCatalog.scholarships);
    academyCourses..clear()..addAll(MockCatalog.academyCourses);
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
    _pushProfileUpdate();
    _persist();
    update();
  }

  void toggleAppLock(bool enable) {
    isAppLockEnabled = enable;
    _repository.saveSnapshot(_snapshot);
    update();
  }

  void completeIntro() {
    hasSeenIntro = true;
    _repository.saveSnapshot(_snapshot);
    update();
  }

  void completeOnboarding(UserProfile newProfile) {
    profile = newProfile;
    localeCode = newProfile.preferredLanguage;
    hasCompletedOnboarding = true;
    _cases
      ..clear()
      ..addAll(newProfile.accountType == AccountType.student
          ? MockCatalog.starterCases()
          : <StudentCase>[]);
    _pushProfileUpdate();
    _persist();
    update();
  }

  void setThemeMode(ThemeMode mode) {
    themeMode = mode;
    _persist();
    update();
    AnalyticsService.instance.logThemeToggled(mode == ThemeMode.dark);
  }

  void logout() {
    AnalyticsService.instance.logLogout();
    profile = null;
    hasCompletedOnboarding = false;
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
    shellIndex = index;
    update();
  }

  void resetShell() {
    shellIndex = 0;
    update();
  }

  bool isSaved(SavedItemType type, String itemId) {
    return _savedItems.any((item) => item.type == type && item.itemId == itemId);
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
    return _findNextStep(scholarships.where((s) => isSaved(SavedItemType.scholarship, s.id)));
  }

  double getChildOverallProgressPercentage() {
    final saved = scholarships.where((s) => isSaved(SavedItemType.scholarship, s.id));
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

    final savedScholarships = scholarships.where((s) => isSaved(SavedItemType.scholarship, s.id));
    double totalSavings = savedScholarships.length * 5000.0; // Mock scholarship value

    return {
      'totalCost': (tuition + lifestyle),
      'potentialSavings': totalSavings,
      'gap': (tuition + lifestyle) - totalSavings,
    };
  }

  Map<String, dynamic>? _findNextStep(Iterable<ScholarshipModel> savedScholarships) {
    final now = DateTime.now();
    Map<String, dynamic>? closest;
    DateTime? closestDate;

    for (final s in savedScholarships) {
       final deadline = RoadmapEngine.calculateDate(now.add(const Duration(days: 90)), 0); 
       final steps = RoadmapEngine.getSteps();

       for (final step in steps) {
          if (!isStepCompleted(s.id, step.type)) {
             final stepDate = RoadmapEngine.calculateDate(deadline, step.daysBeforeDeadline);
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

  /// Public refresh — calls syncRemoteData and returns when done.
  @override
  Future<void> refresh() => syncRemoteData(silent: false);

  OrientationSession submitOrientation(Map<String, List<String>> answers) {
    final activeProfile = profile;
    if (activeProfile == null) {
      throw StateError('Profile must exist before starting orientation.');
    }

    final session = OrientationEngine.evaluate(
      profile: activeProfile,
      answers: answers,
      questions: orientationQuestions,
      fields: fields,
      scholarships: scholarships,
    );

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
    if (AppConfig.enableRemoteSync) {
      unawaited(_pushOrientationSession(answers));
    }
    return session;
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
    _pushProfileUpdate();
    _persist();
    update();
  }

  // ── Search ──────────────────────────────────────────────────

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

  List<SearchResult> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final results = <SearchResult>[];

    for (final f in fields) {
      if (_matchesField(f, q)) {
        results.add(SearchResult(
          type: SearchResultType.field,
          id: f.id,
          title: resolve(f.name),
          subtitle: resolve(f.description),
        ));
      }
    }
    for (final c in countries) {
      if (_matchesLocalized(c.name, q)) {
        results.add(SearchResult(
          type: SearchResultType.country,
          id: c.id,
          title: resolve(c.name),
          subtitle: resolve(c.tuitionRange),
        ));
      }
    }
    for (final i in institutions) {
      if (_matchesLocalized(i.name, q) || _matchesLocalized(i.location, q)) {
        results.add(SearchResult(
          type: SearchResultType.institution,
          id: i.id,
          title: resolve(i.name),
          subtitle: resolve(i.location),
        ));
      }
    }
    for (final p in programs) {
      if (_matchesLocalized(p.name, q) || _matchesLocalized(p.level, q)) {
        results.add(SearchResult(
          type: SearchResultType.program,
          id: p.id,
          title: resolve(p.name),
          subtitle: resolve(p.level),
        ));
      }
    }
    for (final s in scholarships) {
      if (_matchesLocalized(s.name, q)) {
        results.add(SearchResult(
          type: SearchResultType.scholarship,
          id: s.id,
          title: resolve(s.name),
          subtitle: resolve(s.typeOfFunding),
        ));
      }
    }
    return results;
  }

  bool _matchesLocalized(LocalizedText text, String q) =>
      text.fr.toLowerCase().contains(q) || text.en.toLowerCase().contains(q);

  bool _matchesField(FieldModel f, String q) {
    if (_matchesLocalized(f.name, q)) return true;
    if (_matchesLocalized(f.description, q)) return true;
    if (f.careers.any((c) => _matchesLocalized(c, q))) return true;
    if (f.subjects.any((s) => _matchesLocalized(s, q))) return true;
    return false;
  }

  // ── Matching engine ─────────────────────────────────────────

  int fieldMatch(FieldModel field) => _matchField(field);

  int _matchField(FieldModel field) {
    final p = profile;
    if (p == null) return 40;
    var score = 30;
    if (p.fieldIds.contains(field.id)) score += 20;
    if (latestOrientationSession != null) {
      final session = latestOrientationSession!;
      final rec = session.recommendations
          .where((r) => r.fieldId == field.id)
          .firstOrNull;
      if (rec != null) score += min((rec.score ~/ 4), 25);
    }
    if (field.relatedCountryIds
        .any((id) => p.targetCountryIds.contains(id))) {
      score += 10;
    }
    if (p.wantsScholarshipSupport && field.relatedScholarshipIds.isNotEmpty) {
      score += 5;
    }
    return min(score, 98);
  }

  int programMatch(ProgramModel program) => _matchProgram(program);

  int _matchProgram(ProgramModel program) {
    final p = profile;
    if (p == null) return 40;
    var score = 30;
    if (p.fieldIds.contains(program.fieldId)) score += 25;
    if (p.targetCountryIds.contains(program.countryId)) score += 20;
    if (p.targetLevel != null) {
      final programLevel = program.level.fr.toLowerCase();
      final targetLevel = p.targetLevel ?? '';
      if (programLevel.contains(targetLevel.toLowerCase()) ||
          targetLevel.toLowerCase().contains(programLevel)) {
        score += 15;
      }
    }
    if (latestOrientationSession != null) {
      final orientationFieldIds = latestOrientationSession!.recommendations
          .map((r) => r.fieldId)
          .toList();
      if (orientationFieldIds.contains(program.fieldId)) score += 10;
    }
    return min(score, 98);
  }

  int institutionMatch(InstitutionModel institution) =>
      _matchInstitution(institution);

  int _matchInstitution(InstitutionModel institution) {
    final p = profile;
    if (p == null) return 40;
    var score = 0;
    // Base logic: Country match is big, programs match is vital.
    if (p.targetCountryIds.contains(institution.countryId)) score += 25;
    
    final matchingPrograms = programs
        .where((prog) =>
            institution.programIds.contains(prog.id) &&
            p.fieldIds.contains(prog.fieldId))
        .length;
    score += min(matchingPrograms * 10, 30);
    
    // Level match
    if (p.targetLevel != null &&
        institution.studyLevels.any((l) =>
            l.toLowerCase().contains(p.targetLevel!.toLowerCase()))) {
      score += 15;
    }

    // Academic Merit (Grade Range)
    final grade = p.gradeRange ?? '';
    if (grade.contains('15') || grade.contains('16') || grade.contains('17')) {
       score += 20; // High merit
    } else if (grade.contains('12') || grade.contains('13') || grade.contains('14')) {
       score += 10; // Medium merit
    }

    if (institution.isPartner) score += 15;
    
    return min(score, 98);
  }

  List<FieldModel> get recommendedFields {
    final sorted = fields
        .map((f) => MapEntry(f, _matchField(f)))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(6).map((e) => e.key).toList();
  }

  List<ProgramModel> get recommendedPrograms {
    final sorted = programs
        .map((p) => MapEntry(p, _matchProgram(p)))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(10).map((e) => e.key).toList();
  }

  List<InstitutionModel> get recommendedInstitutions {
    final sorted = institutions
        .map((i) => MapEntry(i, _matchInstitution(i)))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(6).map((e) => e.key).toList();
  }

  List<String> matchExplanation(SearchResultType type, String id) {
    final p = profile;
    if (p == null) {
      return ['match_complete_profile'.tr];
    }
    final reasons = <String>[];
    switch (type) {
      case SearchResultType.field:
        final f = fieldByIdOrNull(id);
        if (f == null) break;
        if (p.fieldIds.contains(f.id)) reasons.add('match_field_in_interests'.tr);
        final session = latestOrientationSession;
        if (session != null &&
            session.recommendations.any((r) => r.fieldId == f.id)) {
          reasons.add('match_from_orientation'.tr);
        }
        if (f.relatedCountryIds
            .any((cid) => p.targetCountryIds.contains(cid))) {
          reasons.add('match_available_target_country'.tr);
        }
      case SearchResultType.country:
        if (p.targetCountryIds.contains(id)) reasons.add('match_target_country'.tr);
      case SearchResultType.institution:
        final inst = institutionByIdOrNull(id);
        if (inst == null) break;
        if (p.targetCountryIds.contains(inst.countryId)) {
          reasons.add('match_in_target_country'.tr);
        }
        if (inst.isPartner) reasons.add('match_kpb_partner'.tr);
      case SearchResultType.program:
        final prog = programByIdOrNull(id);
        if (prog == null) break;
        if (p.fieldIds.contains(prog.fieldId)) {
          reasons.add('match_field_match'.tr);
        }
        if (p.targetCountryIds.contains(prog.countryId)) {
          reasons.add('match_target_country'.tr);
        }
      case SearchResultType.scholarship:
        final s = scholarshipByIdOrNull(id);
        if (s == null) break;
        if (p.targetCountryIds.contains(s.countryId)) {
          final country = countryByIdOrNull(s.countryId);
          if (country != null) {
            reasons.add('${'match_target_country'.tr} : ${resolve(country.name)}');
          } else {
            reasons.add('match_target_country'.tr);
          }
        }
        if (p.fieldIds.any((fid) => s.relatedFieldIds.contains(fid))) {
          reasons.add('match_field_match'.tr);
        }
        if (p.wantsScholarshipSupport) {
          reasons.add('match_scholarship_interest'.tr);
        }
    }
    if (reasons.isEmpty) reasons.add('match_general'.tr);
    return reasons;
  }

  List<ScholarshipModel> get recommendedScholarships {
    final activeProfile = profile;
    if (activeProfile == null) return scholarships.take(4).toList();

    final sorted = scholarships
        .map((scholarship) => MapEntry(scholarship, _matchScholarship(scholarship)))
        .toList()
      ..sort((left, right) => right.value.compareTo(left.value));

    return sorted.take(6).map((entry) => entry.key).toList();
  }

  int scholarshipMatch(ScholarshipModel scholarship) =>
      _matchScholarship(scholarship);

  int _matchScholarship(ScholarshipModel scholarship) {
    final activeProfile = profile;
    if (activeProfile == null) return scholarship.baseMatch;

    var score = scholarship.baseMatch;
    if (activeProfile.targetCountryIds.contains(scholarship.countryId)) {
      score += 20;
    }
    if (activeProfile.fieldIds
        .any((fieldId) => scholarship.relatedFieldIds.contains(fieldId))) {
      score += 15;
    }
    
    // Academic requirements for scholarships are usually higher
    final grade = activeProfile.gradeRange ?? '';
    if (grade.contains('15') || grade.contains('16') || grade.contains('17')) {
       score += 25; 
    } else if (grade.contains('13') || grade.contains('14')) {
       score += 10;
    }

    if (activeProfile.wantsScholarshipSupport) score += 10;
    
    return min(score, 98);
  }

  StudentCase submitCase({
    required CaseType type,
    required String title,
    required String description,
    required String contextLabel,
    required ContactMethod contactMethod,
  }) {
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
          title: const LocalizedText(fr: 'Demande envoyée', en: 'Request submitted'),
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
          title: LocalizedText(fr: 'Profil académique complet', en: 'Complete academic profile'),
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
          shellIndex = 2; // Dossiers tab (new index)
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
      unawaited(_createRemoteCaseMessage(caseId, text));
    } else {
      unawaited(CaseMessageOutbox.instance.enqueue(
        caseId: caseId,
        body: text,
        senderName: profile?.fullName ?? 'Student',
      ));
    }
  }

  void markDocumentProvided(String caseId, String documentId) {
    final index = _cases.indexWhere((item) => item.id == caseId);
    if (index < 0) return;
    final caseItem = _cases[index];
    final updatedDocs = caseItem.documentRequests
        .map((doc) => doc.id == documentId ? doc.copyWith(isProvided: true) : doc)
        .toList();
    _cases[index] = caseItem.copyWith(
      updatedAt: DateTime.now(),
      documentRequests: updatedDocs,
    );
    _persist();
    update();
    final document = updatedDocs.firstWhereOrNull((item) => item.id == documentId);
    if (document != null) {
      unawaited(_uploadRemoteCaseDocument(caseId, document));
    }
  }

  Future<void> syncRemoteData({bool silent = false}) async {
    if (!AppConfig.enableRemoteSync) return;
    if (isSyncing) return;

    isSyncing = true;
    if (!silent) {
      syncError = null;
      update();
    }

    try {
      // Flush any messages typed while offline
      await flushPendingCaseMessages();

      final profileJson = await _apiClient.getProfile();
      profile = _userProfileFromApi(profileJson);
      localeCode = profile?.preferredLanguage ?? localeCode;

      final remoteCases = await _apiClient.listCases();
      _cases
        ..clear()
        ..addAll(remoteCases.map(_studentCaseFromApi));

      final remoteSavedItems = await _apiClient.listSavedItems();
      _savedItems
        ..clear()
        ..addAll(remoteSavedItems.map(_savedItemFromApi));

      await _syncCatalogResource<FieldModel>(
        'fields', fields, FieldModel.fromJson,
      );
      await _syncCatalogResource<CountryModel>(
        'countries', countries, CountryModel.fromJson,
      );
      await _syncCatalogResource<InstitutionModel>(
        'institutions', institutions, InstitutionModel.fromJson,
      );
      await _syncCatalogResource<ProgramModel>(
        'programs', programs, ProgramModel.fromJson,
      );
      await _syncCatalogResource<ScholarshipModel>(
        'scholarships', scholarships, ScholarshipModel.fromJson,
      );

      _remoteSavedItemIds
        ..clear()
        ..addEntries(
          remoteSavedItems
              .whereType<Map<String, dynamic>>()
              .map(
                (item) => MapEntry(
                  _savedItemKey(
                    _parseSavedItemType(item['type'] as String?) ??
                        SavedItemType.field,
                    item['itemId'] as String? ?? '',
                  ),
                  item['id'] as String? ?? '',
                ),
              ),
        );

      lastSyncedAt = DateTime.now();
      syncError = null;
      _persist();
    } catch (error, stack) {
      syncError = userFacingSyncError(error, localeCode);
      FirebaseCrashlytics.instance.recordError(
        error,
        stack,
        reason: 'syncRemoteData',
      );
    } finally {
      isSyncing = false;
      update();
    }
  }

  Future<void> _syncCatalogResource<T>(
    String resource,
    List<T> target,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    try {
      final raw = await _apiClient.listCatalog(resource);
      target
        ..clear()
        ..addAll(raw.whereType<Map<String, dynamic>>().map(fromJson));
      await CatalogCacheService.instance.write(resource, raw);
    } catch (error) {
      // Network or server down — hydrate from Hive cache so airtime-sensitive
      // users still see the last-known-good catalog. Rethrow only if no cache
      // is available either.
      final cached = CatalogCacheService.instance.read(resource);
      if (cached.isEmpty) rethrow;
      target
        ..clear()
        ..addAll(cached.whereType<Map<String, dynamic>>().map(fromJson));
    }
  }

  List<StudentCase> casesByType(CaseType? filter) {
    if (filter == null) return cases;
    return cases.where((item) => item.type == filter).toList();
  }

  FieldModel? fieldByIdOrNull(String id) =>
      fields.firstWhereOrNull((item) => item.id == id);
  CountryModel? countryByIdOrNull(String id) =>
      countries.firstWhereOrNull((item) => item.id == id);
  InstitutionModel? institutionByIdOrNull(String id) =>
      institutions.firstWhereOrNull((item) => item.id == id);
  ProgramModel? programByIdOrNull(String id) =>
      programs.firstWhereOrNull((item) => item.id == id);
  ScholarshipModel? scholarshipByIdOrNull(String id) =>
      scholarships.firstWhereOrNull((item) => item.id == id);

  /// Non-null convenience accessors — prefer the OrNull variants for new code.
  FieldModel fieldById(String id) =>
      fields.firstWhere((item) => item.id == id);
  CountryModel countryById(String id) =>
      countries.firstWhere((item) => item.id == id);
  InstitutionModel institutionById(String id) =>
      institutions.firstWhere((item) => item.id == id);
  ProgramModel programById(String id) =>
      programs.firstWhere((item) => item.id == id);
  ScholarshipModel scholarshipById(String id) =>
      scholarships.firstWhere((item) => item.id == id);

  AppSnapshot get _snapshot => AppSnapshot(
        localeCode: localeCode,
        hasSeenIntro: hasSeenIntro,
        isAppLockEnabled: isAppLockEnabled,
        hasCompletedOnboarding: hasCompletedOnboarding,
        themeMode: themeMode,
        profile: profile,
        savedItems: _savedItems,
        cases: _cases,
        orientationHistory: _orientationHistory,
        searchHistory: _searchHistory,
        pendingOrientationAnswers: _pendingOrientationAnswers,
        pendingOrientationQuestionIndex: pendingOrientationQuestionIndex,
        fields: fields,
        countries: countries,
        institutions: institutions,
        programs: programs,
        scholarships: scholarships,
        purchasedCourseIds: _purchasedCourseIds,
        completedRoadmapSteps: _completedRoadmapSteps,
      );

  void _persist() {
    unawaited(_repository.saveSnapshot(_snapshot));
  }

  Future<void> _pushProfileUpdate() async {
    if (!AppConfig.enableRemoteSync || profile == null) return;
    try {
      await _apiClient.updateProfile(_userProfilePayload(profile!));
    } catch (e, s) {
      FirebaseCrashlytics.instance.recordError(e, s, reason: 'pushProfileUpdate');
    }
  }

  Future<void> _pushOrientationSession(Map<String, List<String>> answers) async {
    if (!AppConfig.enableRemoteSync) return;
    try {
      await _apiClient.createOrientationSession(<String, dynamic>{
        'answers': answers,
      });
    } catch (e, s) {
      FirebaseCrashlytics.instance.recordError(e, s, reason: 'pushOrientationSession');
    }
  }

  Future<void> _createRemoteCase(StudentCase localCase) async {
    if (!AppConfig.enableRemoteSync) return;
    try {
      final response = await _apiClient.createCase(<String, dynamic>{
        'type': _apiCaseType(localCase.type),
        'title': resolve(localCase.title),
        'description': resolve(localCase.description),
        'contextLabel': resolve(localCase.contextLabel),
        'preferredContactMethod':
            _apiContactMethod(localCase.preferredContactMethod),
      });
      _cases.removeWhere((item) => item.id == localCase.id);
      _upsertCase(_studentCaseFromApi(response));
      _persist();
      update();
    } catch (e, s) {
      FirebaseCrashlytics.instance.recordError(e, s, reason: 'createRemoteCase');
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
      _upsertCase(_studentCaseFromApi(response));
      _persist();
      update();
    } catch (e, s) {
      FirebaseCrashlytics.instance.recordError(e, s, reason: 'createRemoteCaseMessage');
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
        FirebaseCrashlytics.instance.recordError(e, s, reason: 'flushPendingCaseMessages');
        await outbox.markFailure(entry.key, entry);
      }
    }
    for (final caseId in touched) {
      try {
        final response = await _apiClient.getCase(caseId);
        _upsertCase(_studentCaseFromApi(response));
      } catch (e, s) {
        FirebaseCrashlytics.instance.recordError(e, s, reason: 'flushPendingCaseMessages.getCase');
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

  Future<void> _uploadRemoteCaseDocument(
    String caseId,
    DocumentRequest document,
  ) async {
    if (!AppConfig.enableRemoteSync) return;
    try {
      await _apiClient.uploadCaseDocument(caseId, <String, dynamic>{
        'title': resolve(document.title),
      });
      final response = await _apiClient.getCase(caseId);
      _upsertCase(_studentCaseFromApi(response));
      _persist();
      update();
    } catch (e, s) {
      FirebaseCrashlytics.instance.recordError(e, s, reason: 'uploadRemoteCaseDocument');
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
      FirebaseCrashlytics.instance.recordError(e, s, reason: 'createRemoteSavedItem');
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
      FirebaseCrashlytics.instance.recordError(e, s, reason: 'deleteRemoteSavedItem');
    }
  }

  String _savedItemKey(SavedItemType type, String itemId) => '${type.name}:$itemId';

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
      'gradeRange': profile.gradeRange,
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

  UserProfile _userProfileFromApi(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String? ?? 'demo-user',
      accountType:
          _parseAccountType(json['accountType'] as String?) ?? AccountType.student,
      fullName: json['fullName'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      whatsApp: json['whatsApp'] as String? ?? '',
      countryOfResidence: json['countryOfResidence'] as String? ?? '',
      preferredLanguage: json['preferredLanguage'] as String? ?? localeCode,
      currentLevel: json['currentLevel'] as String?,
      targetLevel: json['targetLevel'] as String?,
      languageLevel: json['languageLevel'] as String?,
      fieldIds: _stringList(json['fieldIds']),
      targetCountryIds: _stringList(json['targetCountryIds']),
      gradeRange: json['gradeRange'] as String?,
      wantsScholarshipSupport:
          json['wantsScholarshipSupport'] as bool? ??
              json['wantsScholarship'] as bool? ??
              false,
      availableDocuments: _stringList(json['availableDocuments']),
    );
  }

  SavedItem _savedItemFromApi(dynamic raw) {
    final json = raw as Map<String, dynamic>;
    return SavedItem(
      type: _parseSavedItemType(json['type'] as String?) ?? SavedItemType.field,
      itemId: json['itemId'] as String? ?? '',
    );
  }

  StudentCase _studentCaseFromApi(dynamic raw) {
    final json = raw as Map<String, dynamic>;
    return StudentCase(
      id: json['id'] as String? ?? '',
      referenceCode: json['referenceCode'] as String? ?? '',
      type: _parseCaseType(json['type'] as String?) ?? CaseType.consultation,
      title: _text(json['title'] as String? ?? ''),
      description: _text(json['description'] as String? ?? ''),
      contextLabel: _text(json['contextLabel'] as String? ?? ''),
      status: _parseCaseStatus(json['status'] as String?) ?? CaseStatus.submitted,
      preferredContactMethod:
          _parseContactMethod(json['preferredContactMethod'] as String?) ??
              ContactMethod.inApp,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
      nextStepTitle: _text(json['nextStepTitle'] as String? ?? ''),
      nextStepDescription:
          _text(json['nextStepDescription'] as String? ?? ''),
      timeline: ((json['timeline'] as List<dynamic>?) ?? <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(
            (event) => CaseTimelineEvent(
              id: event['id'] as String? ?? '',
              title: _text(event['title'] as String? ?? ''),
              description: _text(event['description'] as String? ?? ''),
              createdAt:
                  DateTime.tryParse(event['createdAt'] as String? ?? '') ??
                      DateTime.now(),
              status: _parseCaseStatus(event['status'] as String?) ??
                  CaseStatus.submitted,
            ),
          )
          .toList(),
      messages: ((json['messages'] as List<dynamic>?) ?? <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(
            (message) => CaseMessage(
              id: message['id'] as String? ?? '',
              senderName: message['senderName'] as String? ?? 'KPB',
              senderRole: message['senderRole'] as String? ?? 'system',
              body: _text(message['body'] as String? ?? ''),
              createdAt:
                  DateTime.tryParse(message['createdAt'] as String? ?? '') ??
                      DateTime.now(),
            ),
          )
          .toList(),
      documentRequests:
          ((json['documentRequests'] as List<dynamic>?) ?? <dynamic>[])
              .whereType<Map<String, dynamic>>()
              .map(
                (document) => DocumentRequest(
                  id: document['id'] as String? ?? '',
                  title: _text(document['title'] as String? ?? ''),
                  isProvided: document['isProvided'] as bool? ?? false,
                ),
              )
              .toList(),
      assignedAdvisorName: json['assignedAdvisorName'] as String?,
      advisorPhone: json['assignedAdvisorPhone'] as String? ??
          json['advisorPhone'] as String?,
      advisorWhatsapp: json['assignedAdvisorWhatsapp'] as String? ??
          json['advisorWhatsapp'] as String?,
      scheduledAt: DateTime.tryParse(json['scheduledAt'] as String? ?? ''),
    );
  }

  LocalizedText _text(String value) => LocalizedText(fr: value, en: value);

  List<String> _stringList(Object? raw) {
    if (raw is List<dynamic>) {
      return raw.whereType<String>().toList();
    }
    return const <String>[];
  }

  AccountType? _parseAccountType(String? value) {
    return _firstWhereOrNull(
      AccountType.values,
      (item) => item.name == value,
    );
  }

  SavedItemType? _parseSavedItemType(String? value) {
    return _firstWhereOrNull(
      SavedItemType.values,
      (item) => item.name == value,
    );
  }

  CaseType? _parseCaseType(String? value) {
    return _firstWhereOrNull(
      CaseType.values,
      (item) => _apiCaseType(item) == value,
    );
  }

  CaseStatus? _parseCaseStatus(String? value) {
    return _firstWhereOrNull(
      CaseStatus.values,
      (item) => _apiCaseStatus(item) == value,
    );
  }

  ContactMethod? _parseContactMethod(String? value) {
    return _firstWhereOrNull(
      ContactMethod.values,
      (item) => _apiContactMethod(item) == value,
    );
  }

  T? _firstWhereOrNull<T>(
    Iterable<T> values,
    bool Function(T item) predicate,
  ) {
    for (final value in values) {
      if (predicate(value)) return value;
    }
    return null;
  }

  String _apiCaseType(CaseType type) {
    switch (type) {
      case CaseType.consultation:
        return 'consultation';
      case CaseType.applicationSupport:
        return 'application_support';
      case CaseType.scholarshipSupport:
        return 'scholarship_support';
      case CaseType.housingSupport:
        return 'housing_support';
      case CaseType.mentorship:
        return 'mentorship';
    }
  }

  String _apiCaseStatus(CaseStatus status) {
    switch (status) {
      case CaseStatus.draft:
        return 'draft';
      case CaseStatus.submitted:
        return 'submitted';
      case CaseStatus.underReview:
        return 'under_review';
      case CaseStatus.documentsNeeded:
        return 'documents_needed';
      case CaseStatus.counselorAssigned:
        return 'counselor_assigned';
      case CaseStatus.awaitingStudent:
        return 'awaiting_student';
      case CaseStatus.scheduled:
        return 'scheduled';
      case CaseStatus.inProgress:
        return 'in_progress';
      case CaseStatus.applicationSubmitted:
        return 'application_submitted';
      case CaseStatus.waitingDecision:
        return 'waiting_decision';
      case CaseStatus.awaitingPayment:
        return 'awaiting_payment';
      case CaseStatus.completed:
        return 'completed';
      case CaseStatus.rejected:
        return 'rejected';
      case CaseStatus.cancelled:
        return 'cancelled';
    }
  }

  String _apiContactMethod(ContactMethod method) {
    switch (method) {
      case ContactMethod.inApp:
        return 'in_app';
      case ContactMethod.whatsapp:
        return 'whatsapp';
      case ContactMethod.phone:
        return 'phone';
    }
  }

}
