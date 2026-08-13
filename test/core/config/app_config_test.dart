import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:karatou/app/core/config/app_config.dart';

void main() {
  group('AppConfig.resolveApiBaseUrl', () {
    test('override wins when non-empty', () {
      expect(
        AppConfig.resolveApiBaseUrl(
          override: 'https://custom.example/api',
          env: 'prod',
        ),
        'https://custom.example/api',
      );
    });

    test('prod default when override empty', () {
      expect(
        AppConfig.resolveApiBaseUrl(override: '', env: 'prod'),
        'https://api.kpbeducation.cloud/api',
      );
    });

    test('dev default', () {
      expect(
        AppConfig.resolveApiBaseUrl(override: '', env: 'dev'),
        'http://127.0.0.1:4000/api',
      );
    });

    test('staging default', () {
      expect(
        AppConfig.resolveApiBaseUrl(override: '', env: 'staging'),
        'https://api.vps-planethoster.com/api',
      );
    });

    test('whitespace-only override falls through to env', () {
      expect(
        AppConfig.resolveApiBaseUrl(override: '   ', env: 'dev'),
        'http://127.0.0.1:4000/api',
      );
    });
  });

  group('AppConfig.appDownloadUrl', () {
    // The smart store-redirect page appended to referral/ambassador share
    // messages. Must be an https link on the brand domain (a bare scheme or a
    // placeholder domain would be dead for WhatsApp recipients), with no
    // trailing slash and no .html suffix.
    //
    // These tests compare Dart strings and nothing more. They cannot see
    // whether the nginx route `location = /app` is loaded, nor whether the page
    // is reachable — /app answered 404 in production for 17 days while they
    // stayed green. The live proof is the `/app` content assertion in
    // .github/workflows/uptime.yml, run every 15 minutes against the real host.
    test('is the /app page on the brand domain', () {
      expect(
        AppConfig.appDownloadUrl,
        'https://${AppConfig.brandDomain}/app',
      );
    });

    test('is a plain https URL WhatsApp will linkify as-is', () {
      final uri = Uri.parse(AppConfig.appDownloadUrl);
      expect(uri.scheme, 'https');
      expect(uri.path, '/app');
      expect(uri.hasQuery, isFalse);
      expect(AppConfig.appDownloadUrl, isNot(endsWith('/')));
    });

    // What this file CAN check about the deployed page: that the page the URL
    // points at still exists in the repo and still carries both store ids.
    // Deleting the file, or dropping an id, breaks the share link for every
    // recipient — and the uptime probe would then be red against a repo that
    // no longer explains why.
    test('the page /app resolves to exists and carries both store ids', () {
      final page = File('web/public/app/index.html');
      expect(
        page.existsSync(),
        isTrue,
        reason: 'AppConfig.appDownloadUrl points at /app, served by nginx from '
            'web/public/app/index.html (see the `location = /app` block in '
            'web/nginx.conf).',
      );

      final html = page.readAsStringSync();
      expect(
        html,
        contains('id1128659292'),
        reason: 'the iOS listing id is what sends an iPhone to the App Store',
      );
      expect(
        html,
        contains('com.karatou.android'),
        reason: 'the Play package is what sends an Android phone to the store',
      );
    });
  });
}
