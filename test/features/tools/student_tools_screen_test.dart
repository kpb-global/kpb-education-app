import 'package:flutter_test/flutter_test.dart';

import 'package:karatou/app/core/config/app_config.dart';
import 'package:karatou/app/core/repositories/app_snapshot.dart';
import 'package:karatou/app/features/tools/student_tools_screen.dart';
import 'package:karatou/app/features/tools/interview_simulator_screen.dart';
import 'package:karatou/app/features/tools/document_scanner_screen.dart';

import '../../widget_test_helpers.dart';

void main() {
  group('Student tools', () {
    setUp(resetGetxSingleton);
    tearDown(() {
      AppConfig.enableRemoteSyncOverride = null;
      resetGetxSingleton();
    });

    testWidgets('hub lists the five tools', (tester) async {
      await pumpTestApp(
        tester,
        child: const StudentToolsScreen(),
        initialSnapshot: AppSnapshot(
          localeCode: 'fr',
          hasCompletedOnboarding: true,
          profile: createTestProfile(),
        ),
      );

      expect(find.text('cv_generator_title'), findsOneWidget);
      expect(find.text('letters_title'), findsOneWidget);
      expect(find.text('interview_title'), findsOneWidget);
      expect(find.text('scanner_title'), findsOneWidget);
      expect(find.text('impact_title'), findsOneWidget);
    });

    testWidgets('interview simulator shows the three interview types',
        (tester) async {
      await pumpTestApp(
        tester,
        child: const InterviewSimulatorScreen(),
        initialSnapshot: AppSnapshot(
          localeCode: 'fr',
          hasCompletedOnboarding: true,
          profile: createTestProfile(),
        ),
      );

      expect(find.text('interview_type_visa_title'), findsOneWidget);
      expect(find.text('interview_type_admission_title'), findsOneWidget);
      expect(find.text('interview_type_scholarship_title'), findsOneWidget);
    });

    testWidgets('document scanner renders the checklist with progress',
        (tester) async {
      await pumpTestApp(
        tester,
        child: const DocumentScannerScreen(),
        initialSnapshot: AppSnapshot(
          localeCode: 'fr',
          hasCompletedOnboarding: true,
          profile: createTestProfile(),
        ),
      );

      expect(find.text('scanner_doc_passport'), findsOneWidget);
      expect(find.text('scanner_doc_diploma'), findsOneWidget);
      expect(find.textContaining('0 / 6 documents'), findsOneWidget);
    });
  });
}
