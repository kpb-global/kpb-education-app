import 'package:flutter_test/flutter_test.dart';
import 'package:karatou/app/core/observability/analytics_event_contract.dart';

void main() {
  test('GA4 event names stay within typical length limits', () {
    const events = <String>[
      AnalyticsEventName.logout,
      AnalyticsEventName.orientationComplete,
      AnalyticsEventName.syncFullComplete,
      AnalyticsEventName.syncConflictResolved,
      AnalyticsEventName.syncCatalogHiveFallback,
    ];
    for (final e in events) {
      expect(e.length, lessThanOrEqualTo(40), reason: e);
    }
  });
}
