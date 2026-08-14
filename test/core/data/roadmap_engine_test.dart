import 'package:flutter_test/flutter_test.dart';

import 'package:karatou/app/core/config/app_routes.dart';
import 'package:karatou/app/core/data/roadmap_engine.dart';
import 'package:karatou/app/core/models/app_models.dart';

void main() {
  group('RoadmapEngine', () {
    test('returns canonical five roadmap steps in expected order', () {
      final steps = RoadmapEngine.getSteps();

      expect(steps.length, equals(5));
      expect(steps.first.type, equals(RoadmapStepType.audit));
      expect(steps.last.type, equals(RoadmapStepType.submission));

      final deadlines = steps.map((s) => s.daysBeforeDeadline).toList();
      expect(deadlines, equals(<int>[60, 45, 30, 15, 0]));
    });

    test('calculateDate subtracts the expected number of days', () {
      final deadline = DateTime(2026, 6, 30);

      final result = RoadmapEngine.calculateDate(deadline, 15);

      expect(result, equals(DateTime(2026, 6, 15)));
    });
  });

  group('aucune route fantôme dans la feuille de route', () {
    // Le défaut : deux étapes portaient `actionRoute: '/academy'` et
    // `'/consultation'`, aucune des deux n'existant dans AppRoutes. Les boutons
    // étaient bel et bien rendus, et leur seul effet observable était un
    // `Get.snackbar` annonçant une redirection qui n'arrivait jamais. Un étudiant
    // qui appuie croit avoir raté quelque chose.
    //
    // Cette assertion est la garde durable : elle casse si quelqu'un réintroduit
    // une route qui n'est pas déclarée, sans avoir besoin de connaître les deux
    // cas historiques.
    test('chaque actionRoute déclarée existe vraiment dans AppRoutes', () {
      final steps = RoadmapEngine.getSteps();
      final declaredNames = AppRoutes.pages.map((page) => page.name).toSet();

      final phantom = steps
          .where((step) => step.actionRoute != null)
          .where((step) => !declaredNames.contains(step.actionRoute))
          .map((step) => '${step.type.name} → ${step.actionRoute}')
          .toList();

      expect(
        phantom,
        isEmpty,
        reason: 'Route(s) inexistante(s) promise(s) par la feuille de route. '
            'Déclarez-les dans AppRoutes, ou retirez l\'actionRoute — mais ne '
            'laissez pas un bouton promettre une navigation qui ne se produira '
            'pas.\n  ${phantom.join('\n  ')}',
      );
    });
  });
}
