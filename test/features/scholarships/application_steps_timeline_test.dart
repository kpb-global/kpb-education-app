import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:karatou/app/core/models/app_models.dart';
import 'package:karatou/app/core/translations/app_translations.dart';
import 'package:karatou/app/features/scholarships/widgets/application_steps_timeline.dart';

void main() {
  tearDown(Get.reset);

  Future<void> pumpTimeline(
    WidgetTester tester,
    List<ScholarshipApplicationStepModel> steps,
  ) async {
    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('fr'),
        fallbackLocale: const Locale('fr'),
        home: Scaffold(
          body: ApplicationStepsTimeline(steps: steps, accent: Colors.blue),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders every step number, title and description',
      (tester) async {
    await pumpTimeline(tester, const [
      ScholarshipApplicationStepModel(
        id: 's1',
        stepNumber: 1,
        title: 'Formulaire en ligne',
        description: 'Remplir le formulaire officiel',
      ),
      ScholarshipApplicationStepModel(
        id: 's2',
        stepNumber: 2,
        title: 'Entretien',
        description: 'Entretien avec le jury',
      ),
    ]);

    expect(find.text('Formulaire en ligne'), findsOneWidget);
    expect(find.text('Remplir le formulaire officiel'), findsOneWidget);
    expect(find.text('Entretien'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('shows the estimated duration when provided', (tester) async {
    await pumpTimeline(tester, const [
      ScholarshipApplicationStepModel(
        id: 's1',
        stepNumber: 1,
        title: 'Examen écrit',
        description: '',
        estimatedDurationDays: 14,
      ),
    ]);

    expect(find.textContaining('14'), findsOneWidget);
  });

  testWidgets('omits the duration line when absent', (tester) async {
    await pumpTimeline(tester, const [
      ScholarshipApplicationStepModel(
        id: 's1',
        stepNumber: 1,
        title: 'Examen écrit',
        description: '',
      ),
    ]);

    expect(find.textContaining('Durée estimée'), findsNothing);
  });

  testWidgets('renders no step tile for an empty list', (tester) async {
    await pumpTimeline(tester, const []);
    expect(find.byType(IntrinsicHeight), findsNothing);
  });
}
