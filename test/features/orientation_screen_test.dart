import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:karatou/app/core/models/app_models.dart';
import 'package:karatou/app/core/repositories/app_snapshot.dart';
import 'package:karatou/app/features/orientation/orientation_screen.dart';

import '../widget_test_helpers.dart';

void main() {
  group('OrientationScreen Widget Tests', () {
    setUp(() {
      resetGetxSingleton();
    });

    tearDown(() {
      resetGetxSingleton();
    });

    testWidgets('renders questionnaire view by default for student', (tester) async {
      final profile = createTestProfile(accountType: AccountType.student);
      final snapshot = AppSnapshot(
        localeCode: 'fr',
        hasCompletedOnboarding: true,
        profile: profile,
      );

      await pumpTestApp(
        tester,
        child: const OrientationScreen(),
        initialSnapshot: snapshot,
      );

      expect(find.byType(OrientationScreen), findsOneWidget);
      // Questionnaire has a progress indicator and question title
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    });

    testWidgets('renders ResultsView with back button when student has results',
        (tester) async {
      final profile = createTestProfile(accountType: AccountType.student);
      final session = OrientationSession(
        id: 'session_1',
        completedAt: DateTime.now(),
        answers: {},
        recommendations: [
          OrientationRecommendation(
            fieldId: 'engineering',
            score: 95,
            explanation: const LocalizedText(
              fr: 'Vous aimez les maths et la logique.',
              en: 'You like math and logic.',
            ),
            relatedCountryIds: ['france'],
            relatedScholarshipIds: [],
          ),
        ],
      );

      final snapshot = AppSnapshot(
        localeCode: 'fr',
        hasCompletedOnboarding: true,
        profile: profile,
        orientationHistory: [session],
      );

      await pumpTestApp(
        tester,
        child: const OrientationScreen(),
        initialSnapshot: snapshot,
      );

      // Verify that ResultsView is rendered and wrapped in Scaffold
      expect(find.byType(OrientationScreen), findsOneWidget);
      expect(find.text('Vos résultats'), findsOneWidget);
      
      // Verify back button is visible
      expect(find.byIcon(Icons.arrow_back_rounded), findsWidgets);
    });

    testWidgets('renders ConsultativeView with back button when user is parent',
        (tester) async {
      final profile = createTestProfile(accountType: AccountType.parent);
      final snapshot = AppSnapshot(
        localeCode: 'fr',
        hasCompletedOnboarding: true,
        profile: profile,
      );

      await pumpTestApp(
        tester,
        child: const OrientationScreen(),
        initialSnapshot: snapshot,
      );

      // Verify that ConsultativeView is rendered and wrapped in Scaffold
      expect(find.byType(OrientationScreen), findsOneWidget);
      expect(find.text('nav_orientation'), findsOneWidget);
      
      // Verify back button is visible
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
    });
  });
}
