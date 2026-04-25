import 'package:flutter_test/flutter_test.dart';

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
}
