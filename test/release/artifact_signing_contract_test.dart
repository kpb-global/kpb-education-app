import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

String _plistValue(String xml, String key) {
  final match = RegExp(
    '<key>${RegExp.escape(key)}</key>\\s*<(string|true|false)(?:>(.*?)</string>|/>)',
    dotAll: true,
  ).firstMatch(xml);
  expect(match, isNotNull, reason: 'Clé plist absente : $key');
  final kind = match!.group(1)!;
  return kind == 'string' ? match.group(2)! : kind;
}

Set<String> _privacyDataTypes(String xml) {
  return RegExp(
    r'<key>NSPrivacyCollectedDataType</key>\s*<string>(.*?)</string>',
    dotAll: true,
  ).allMatches(xml).map((match) => match.group(1)!).toSet();
}

void main() {
  group('iOS App Store artifact contract', () {
    final project = _read('ios/Runner.xcodeproj/project.pbxproj');
    final debugEntitlements = _read('ios/Runner/Runner.entitlements');
    final releaseEntitlements = _read('ios/Runner/RunnerRelease.entitlements');
    final privacy = _read('ios/Runner/PrivacyInfo.xcprivacy');
    final info = _read('ios/Runner/Info.plist');
    final mainSource = _read('lib/main.dart');
    final analytics = _read('lib/app/core/services/analytics_service.dart');
    final crashlytics =
        _read('lib/app/core/observability/crashlytics_observability.dart');
    final oneSignal = _read('lib/app/core/services/onesignal_service.dart');
    final preflight = _read('scripts/preflight-ios-archive.sh');

    test('Release uses production APNs and Debug stays development-only', () {
      expect(
        project,
        contains('CODE_SIGN_ENTITLEMENTS = Runner/RunnerRelease.entitlements;'),
      );
      expect(_plistValue(releaseEntitlements, 'aps-environment'), 'production');
      expect(_plistValue(debugEntitlements, 'aps-environment'), 'development');
      expect(
        RegExp(
          r'CODE_SIGN_ENTITLEMENTS = Runner/RunnerRelease\.entitlements;.*?name = Release;',
          dotAll: true,
        ).hasMatch(project),
        isTrue,
        reason:
            'The Release configuration must select production entitlements.',
      );
    });

    test('app privacy manifest is bundled and declares no tracking', () {
      expect(_plistValue(privacy, 'NSPrivacyTracking'), 'false');
      expect(project, contains('PrivacyInfo.xcprivacy in Resources'));
      expect(
        RegExp(r'PrivacyInfo\.xcprivacy in Resources', multiLine: true)
            .allMatches(project)
            .length,
        greaterThanOrEqualTo(2),
        reason: 'The file needs both a PBXBuildFile and Resources-phase entry.',
      );

      final types = _privacyDataTypes(privacy);
      expect(
        types,
        containsAll(<String>{
          'NSPrivacyCollectedDataTypeName',
          'NSPrivacyCollectedDataTypeEmailAddress',
          'NSPrivacyCollectedDataTypePhoneNumber',
          'NSPrivacyCollectedDataTypeUserID',
          'NSPrivacyCollectedDataTypeDeviceID',
          'NSPrivacyCollectedDataTypeCustomerSupport',
          'NSPrivacyCollectedDataTypeOtherUserContent',
          'NSPrivacyCollectedDataTypeSearchHistory',
          'NSPrivacyCollectedDataTypeProductInteraction',
          'NSPrivacyCollectedDataTypeCrashData',
        }),
      );
      expect(types, isNot(contains('NSPrivacyCollectedDataTypeLocation')));
    });

    test('OneSignal location capability is linked but never invoked', () {
      expect(oneSignal, isNot(contains('OneSignal.Location')));
      expect(info, contains('NSLocationWhenInUseUsageDescription'));
      expect(
        _plistValue(info, 'NSLocationWhenInUseUsageDescription').toLowerCase(),
        contains('ne collecte pas votre position'),
      );
    });

    test('OneSignal receives no email or SMS identity', () {
      expect(oneSignal, isNot(contains('OneSignal.User.addEmail')));
      expect(oneSignal, isNot(contains('OneSignal.User.addSms')));
    });

    test('all analytics collectors start inert until consent is restored', () {
      expect(
          _plistValue(info, 'FIREBASE_ANALYTICS_COLLECTION_ENABLED'), 'false');
      expect(
          _plistValue(info, 'FirebaseCrashlyticsCollectionEnabled'), 'false');
      expect(mainSource, contains('..optOut = true'));
      expect(analytics, contains('setAnalyticsCollectionEnabled(enabled)'));
      expect(
        crashlytics,
        contains('setCrashlyticsCollectionEnabled(enabled)'),
      );
      expect(crashlytics, contains('deleteUnsentReports()'));
    });

    test('strict preflight rejects development or unsigned artifacts', () {
      expect(preflight, contains('codesign --verify --deep --strict'));
      expect(preflight, contains('Apple Distribution|iPhone Distribution'));
      expect(preflight, contains('get-task-allow'));
      expect(preflight, contains('aps-environment'));
      expect(preflight, contains('beta-reports-active'));
      expect(preflight, contains('ProvisionedDevices'));
      expect(
          preflight, contains('PrivacyInfo.xcprivacy absent du bundle signé'));
      expect(preflight, contains('EXPECTED_BUILD="49"'));
      expect(preflight, contains('EXPECTED_VERSION="2.1.0"'));
      expect(preflight, contains('EXPECTED_BUNDLE_ID="Karatou.karatou"'));
    });
  });

  group('Android Play artifact contract', () {
    final manifest = _read('android/app/src/main/AndroidManifest.xml');
    final gradle = _read('android/app/build.gradle');
    final preflight = _read('scripts/preflight-android-aab.sh');

    test('advertising ID is removed and native collection starts disabled', () {
      expect(
          manifest, contains('xmlns:tools="http://schemas.android.com/tools"'));
      expect(manifest, contains('com.google.android.gms.permission.AD_ID'));
      expect(manifest, contains('tools:node="remove"'));
      for (final key in <String>[
        'google_analytics_adid_collection_enabled',
        'firebase_analytics_collection_enabled',
        'firebase_crashlytics_collection_enabled',
      ]) {
        expect(
          RegExp(
            'android:name="${RegExp.escape(key)}"\\s+android:value="false"',
          ).hasMatch(manifest),
          isTrue,
          reason: '$key must be false in the source manifest.',
        );
      }
    });

    test('Gradle rejects placeholders, missing keys, and debug certificates',
        () {
      expect(gradle, contains('still contains placeholders'));
      expect(gradle, contains('androiddebugkey'));
      expect(gradle, contains('cn=androiddebug'));
      expect(gradle, contains('certificate.checkValidity()'));
      expect(gradle, contains('keyStore.isKeyEntry(alias)'));
    });

    test('AAB preflight pins identity, version, SDK, and Play certificate', () {
      expect(preflight, contains('EXPECTED_PACKAGE="com.karatou.android"'));
      expect(preflight, contains('EXPECTED_VERSION_NAME="2.1.0"'));
      expect(preflight, contains('EXPECTED_VERSION_CODE="49"'));
      expect(preflight, contains('EXPECTED_TARGET_SDK="36"'));
      expect(preflight, contains('"\$JARSIGNER_BIN" -verify'));
      expect(preflight, contains('"\$KEYTOOL_BIN" -printcert -jarfile'));
      expect(preflight, contains('bundletool'));
      expect(preflight, contains('dump manifest --bundle'));
      expect(preflight, contains('com.google.android.gms.permission.AD_ID'));
      expect(preflight, contains('base/manifest/AndroidManifest.xml'));
    });
  });

  test('the shipping pubspec version remains the build-49 contract', () {
    expect(
      RegExp(r'^version:\s*2\.1\.0\+49\s*$', multiLine: true)
          .hasMatch(_read('pubspec.yaml')),
      isTrue,
    );
  });

  test('analytics requires an explicit persisted consent decision', () {
    final snapshot = _read('lib/app/core/repositories/app_snapshot.dart');
    final repository =
        _read('lib/app/core/repositories/local_app_repository.dart');
    final controller = _read('lib/app/core/controllers/app_controller.dart');

    expect(snapshot, contains('this.analyticsOptOut = true'));
    expect(snapshot, contains('this.analyticsConsentDecided = false'));
    expect(
      repository,
      contains("json['analyticsConsentDecided'] as bool? ?? false"),
    );
    expect(
      controller,
      contains(
        'analyticsOptOut = analyticsConsentDecided ? snapshot.analyticsOptOut : true;',
      ),
    );
    expect(controller, contains('analyticsConsentDecided = true;'));
  });
}
