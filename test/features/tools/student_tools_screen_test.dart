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

      expect(find.text('Generateur de CV'), findsOneWidget);
      expect(find.text('Lettres de motivation'), findsOneWidget);
      expect(find.text('Simulateur d\'entretien'), findsOneWidget);
      expect(find.text('Scanner mes documents'), findsOneWidget);
      expect(find.text('Notre impact'), findsOneWidget);
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

      expect(find.text('Entretien de visa étudiant'), findsOneWidget);
      expect(find.text('Entretien d\'admission'), findsOneWidget);
      expect(find.text('Entretien de bourse'), findsOneWidget);
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

      expect(find.text('Passeport'), findsOneWidget);
      expect(find.text('Diplôme / Attestation'), findsOneWidget);
      expect(find.textContaining('0 / 6 documents'), findsOneWidget);
    });
  });
}
