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

  static bool get enableRemoteSync =>
      _enableRemoteSyncOverride ??
      const bool.fromEnvironment(
        'KPB_ENABLE_REMOTE_SYNC',
        defaultValue: true,
      );

  static bool? _enableRemoteSyncOverride;

  @visibleForTesting
  static set enableRemoteSyncOverride(bool? value) =>
      _enableRemoteSyncOverride = value;

  static const requestTimeoutInSeconds = int.fromEnvironment(
    'KPB_REQUEST_TIMEOUT',
    defaultValue: 15,
  );

  /// Main KPB WhatsApp line (E.164 digits, with or without leading +).
  /// Defaults to the KPB advisor line so the "Discuter avec un conseiller" CTAs
  /// reach a real person even when no --dart-define is passed; override per
  /// environment with --dart-define=KPB_WHATSAPP_NUMBER=...
  static const whatsappNumber = String.fromEnvironment(
    'KPB_WHATSAPP_NUMBER',
    defaultValue: '+33768674292',
  );

  /// Optional WhatsApp group invite fallback.
  static const whatsappGroupInvite = String.fromEnvironment(
    'KPB_WHATSAPP_GROUP',
    defaultValue: 'https://chat.whatsapp.com/KPBEducation',
  );

  // ── OneSignal push notifications ───────────────────────────────────────
  /// OneSignal App ID. Overridable via --dart-define=KPB_ONESIGNAL_APP_ID.
  static const oneSignalAppId = String.fromEnvironment(
    'KPB_ONESIGNAL_APP_ID',
    defaultValue: '779d9ea8-1a0d-4189-9d51-4077cb8ded2a',
  );

  /// True when a non-empty OneSignal App ID is configured.
  static bool get oneSignalEnabled => oneSignalAppId.trim().isNotEmpty;

  /// MVP launch lock. When true, modules outside the M1–M14 MVP scope
  /// (community/forum, alumni, academy, salon, housing, travel, blog and the
  /// scraped live-scholarships aggregator) are hidden from navigation without
  /// removing their code, so they can be re-enabled for V1.1+.
  static const mvpOnly = bool.fromEnvironment(
    'KPB_MVP_ONLY',
    defaultValue: true,
  );

  // ── Supabase Auth ──────────────────────────────────────────────────────
  /// Supabase project URL (auth only — business data stays in Prisma/Postgres).
  static const supabaseUrl = String.fromEnvironment(
    'KPB_SUPABASE_URL',
    defaultValue: 'https://hijzqsljasbobjrjotjy.supabase.co',
  );

  /// Supabase anon (publishable) key.
  static const supabaseAnonKey = String.fromEnvironment(
    'KPB_SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imhpanpxc2xqYXNib2JqcmpvdGp5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ4MTkwODQsImV4cCI6MjA5MDM5NTA4NH0.Yib53B7tICNpnJWktCrc_JhtD06mAby4hbNWKXt3je0',
  );

  /// Deep-link redirect registered with the Supabase OAuth provider (Google).
  static const supabaseOAuthRedirect = String.fromEnvironment(
    'KPB_SUPABASE_OAUTH_REDIRECT',
    defaultValue: 'io.supabase.kpbeducation://login-callback/',
  );

  static const storageNamespace = 'kpb_relaunch_v1';

  // ── Brand identity ─────────────────────────────────────────────────────
  /// Public brand name, used in shareable artifacts (e.g. the match card).
  /// Kept as a single source of truth so shared copy stays truthful.
  static const brandName = 'KPB Education';

  /// Public brand domain (marketing site). Matches the `kpbeducation.cloud`
  /// API host; surfaced on shareable cards instead of any placeholder domain.
  static const brandDomain = 'kpbeducation.cloud';

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
        return 'https://api.kpbeducation.cloud/api';
    }
  }
}
