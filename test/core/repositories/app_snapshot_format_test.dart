import 'package:flutter_test/flutter_test.dart';
import 'package:karatou/app/core/repositories/app_snapshot_format.dart';

void main() {
  test('migrateAppSnapshotJson sets version and preserves payload', () {
    final json = <String, dynamic>{
      'localeCode': 'en',
      'hasCompletedOnboarding': true,
    };
    migrateAppSnapshotJson(json);
    expect(json['snapshotFormatVersion'], kAppSnapshotFormatVersion);
    expect(json['localeCode'], 'en');
    expect(json['hasCompletedOnboarding'], isTrue);
  });

  test('migrateAppSnapshotJson is idempotent for current version', () {
    final json = <String, dynamic>{
      'snapshotFormatVersion': kAppSnapshotFormatVersion,
      'localeCode': 'fr',
    };
    migrateAppSnapshotJson(json);
    expect(json['snapshotFormatVersion'], kAppSnapshotFormatVersion);
  });
}
