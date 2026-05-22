import 'package:flutter/foundation.dart';

/// Compile-time app environment and API settings (Flutter `--dart-define=...`).
///
/// See [`docs/phase8-release-operations.md`](../../../../docs/phase8-release-operations.md).
class AppConfig {
  /// One of `dev`, `staging`, `prod`. Drives default API host when [apiBaseUrlOverride] is empty.
  static const appEnv = String.fromEnvironment(
    'KPB_APP_ENV',
    defaultValue: 'prod',
  );

  /// When non-empty, used as the REST base URL and overrides [appEnv] defaults.
  static const apiBaseUrlOverride = String.fromEnvironment(
    'KPB_API_BASE_URL',
    defaultValue: '',
  );

  /// Resolved REST API prefix (includes trailing `/api` segment used by this client).
  static String get apiBaseUrl =>
      resolveApiBaseUrl(override: apiBaseUrlOverride, env: appEnv);

  static bool get enableRemoteSync => _enableRemoteSyncOverride ?? const bool.fromEnvironment(
    'KPB_ENABLE_REMOTE_SYNC',
    defaultValue: true,
  );

  static bool? _enableRemoteSyncOverride;

  @visibleForTesting
  static set enableRemoteSyncOverride(bool? value) => _enableRemoteSyncOverride = value;

  static const requestTimeoutInSeconds = int.fromEnvironment(
    'KPB_REQUEST_TIMEOUT',
    defaultValue: 15,
  );

  static const storageNamespace = 'kpb_relaunch_v1';

  /// Pure resolver for tests and tooling.
  @visibleForTesting
  static String resolveApiBaseUrl({
    required String override,
    required String env,
  }) {
    final o = override.trim();
    if (o.isNotEmpty) return o;

    switch (env.toLowerCase()) {
      case 'dev':
        return 'http://127.0.0.1:4000/api';
      case 'staging':
        // Pre-production / CI-style host — override with KPB_API_BASE_URL if your stack differs.
        return 'https://api.vps-planethoster.com/api';
      case 'prod':
      default:
        return 'https://api.kpb-education.com/api';
    }
  }
}
