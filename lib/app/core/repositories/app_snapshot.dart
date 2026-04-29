import 'package:flutter/material.dart';

import '../models/app_models.dart';

class AppSnapshot {
  const AppSnapshot({
    required this.localeCode,
    required this.hasCompletedOnboarding,
    this.hasSeenIntro = false,
    this.isAppLockEnabled = false,
    this.themeMode = ThemeMode.system,
    this.profile,
    this.savedItems = const [],
    this.cases = const [],
    this.orientationHistory = const [],
    this.searchHistory = const [],
    this.pendingOrientationAnswers = const {},
    this.pendingOrientationQuestionIndex = 0,
    this.fields = const [],
    this.countries = const [],
    this.institutions = const [],
    this.programs = const [],
    this.scholarships = const [],
    this.purchasedCourseIds = const [],
    this.completedRoadmapSteps = const {},
  });

  final String localeCode;
  final bool hasCompletedOnboarding;
  final bool hasSeenIntro;
  final bool isAppLockEnabled;
  final ThemeMode themeMode;
  final UserProfile? profile;
  final List<SavedItem> savedItems;
  final List<StudentCase> cases;
  final List<OrientationSession> orientationHistory;
  final List<String> searchHistory;
  final Map<String, List<String>> pendingOrientationAnswers;
  final int pendingOrientationQuestionIndex;
  final List<FieldModel> fields;
  final List<CountryModel> countries;
  final List<InstitutionModel> institutions;
  final List<ProgramModel> programs;
  final List<ScholarshipModel> scholarships;
  final List<String> purchasedCourseIds;
  final Map<String, List<String>> completedRoadmapSteps;

  factory AppSnapshot.initial() {
    return const AppSnapshot(
      localeCode: 'fr',
      hasCompletedOnboarding: false,
      hasSeenIntro: false,
      isAppLockEnabled: false,
    );
  }
}
