import 'package:flutter_test/flutter_test.dart';

import 'package:karatou/app/core/data/notification_opt_out.dart';
import 'package:karatou/app/core/data/profile_api_codec.dart';

/// KPB-169 replaced one boolean per notification family with one list of keys.
/// The risks that come with that are exactly what these tests pin down: losing
/// a preference this build doesn't know about, and losing preferences saved by
/// the previous build.
void main() {
  group('applyOptOut', () {
    test('adds and removes one type without touching the others', () {
      const current = [
        NotificationOptOutType.dailyScholarship,
        NotificationOptOutType.weeklyDigest,
      ];

      final removed = applyOptOut(
        current,
        NotificationOptOutType.weeklyDigest,
        optOut: false,
      );
      expect(removed, [NotificationOptOutType.dailyScholarship]);

      final added = applyOptOut(
        removed,
        NotificationOptOutType.parcoursWeekly,
        optOut: true,
      );
      expect(added, [
        NotificationOptOutType.dailyScholarship,
        NotificationOptOutType.parcoursWeekly,
      ]);
    });

    test('preserves a key this build does not know about', () {
      final next = applyOptOut(
        const ['a_future_family'],
        NotificationOptOutType.parcoursWeekly,
        optOut: true,
      );
      expect(next, contains('a_future_family'));
      expect(next, contains(NotificationOptOutType.parcoursWeekly));
    });

    test('opting out twice does not duplicate the key', () {
      var types = applyOptOut(
        const [],
        NotificationOptOutType.weeklyDigest,
        optOut: true,
      );
      types = applyOptOut(
        types,
        NotificationOptOutType.weeklyDigest,
        optOut: true,
      );
      expect(types, [NotificationOptOutType.weeklyDigest]);
    });
  });

  group('ProfileApiCodec — opt-out types', () {
    Map<String, dynamic> base(Map<String, dynamic> extra) => {
          'id': 'u1',
          'accountType': 'student',
          ...extra,
        };

    test('reads the canonical array', () {
      final profile = ProfileApiCodec.userProfileFromApi(
        base({
          'disabledNotificationTypes': ['parcours_weekly', 'weekly_digest'],
        }),
        fallbackLocale: 'fr',
      );
      expect(profile.disabledNotificationTypes, [
        'parcours_weekly',
        'weekly_digest',
      ]);
      expect(
        profile.isNotificationTypeDisabled(
          NotificationOptOutType.dailyScholarship,
        ),
        isFalse,
      );
    });

    test('falls back to the legacy booleans when the array is absent', () {
      final profile = ProfileApiCodec.userProfileFromApi(
        base({'dailyScholarshipOptOut': true, 'weeklyDigestOptOut': false}),
        fallbackLocale: 'fr',
      );
      expect(profile.disabledNotificationTypes, [
        NotificationOptOutType.dailyScholarship,
      ]);
    });

    test('a profile with no preference at all is opted IN to everything', () {
      final profile = ProfileApiCodec.userProfileFromApi(
        base(const {}),
        fallbackLocale: 'fr',
      );
      expect(profile.disabledNotificationTypes, isEmpty);
      for (final type in NotificationOptOutType.all) {
        expect(profile.isNotificationTypeDisabled(type), isFalse);
      }
    });
  });
}
