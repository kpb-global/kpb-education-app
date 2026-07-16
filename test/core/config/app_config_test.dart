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
}
