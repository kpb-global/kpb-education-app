import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../repositories/app_api_client.dart';

/// Authentication is delegated to Supabase Auth (Google sign-in + email OTP).
///
/// The Supabase SDK owns session persistence and silent token refresh, so this
/// service is a thin wrapper that exposes the small surface the app relies on:
/// [isLoggedIn], [accessToken], [userId], the email-OTP pair
/// ([requestMagicLink] / [verifyMagicLink]), [signInWithGoogle], and session
/// teardown. Business data still lives in the NestJS/Prisma backend, which
/// trusts the Supabase access token via the `StudentAuthGuard`.
class AuthService {
  AuthService._(this._client, this._apiClient);

  final SupabaseClient _client;
  // Retained so future flows can call backend endpoints; the access token is
  // injected into requests by the Dio interceptor, not from here.
  // ignore: unused_field
  final AppApiClient _apiClient;

  static Future<AuthService> create(AppApiClient apiClient) async {
    return AuthService._(Supabase.instance.client, apiClient);
  }

  Session? get _session => _client.auth.currentSession;

  String? get accessToken => _session?.accessToken;
  String? get userId => _session?.user.id;
  bool get isLoggedIn => accessToken != null && accessToken!.isNotEmpty;

  /// Streams Supabase auth state changes (login/logout/token refresh).
  Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;

  /// Sends a 6-digit email OTP (also usable as a magic link). Supabase creates
  /// the user on first verification when `shouldCreateUser` is true.
  Future<void> requestMagicLink({required String email}) async {
    await _client.auth.signInWithOtp(
      email: email.trim().toLowerCase(),
      shouldCreateUser: true,
      emailRedirectTo: AppConfig.supabaseOAuthRedirect,
    );
  }

  /// Verifies the email OTP code and establishes a session.
  Future<AuthResponse> verifyMagicLink({
    String? token,
    String? email,
    String? code,
  }) async {
    final otp = (code ?? token ?? '').trim();
    final normalizedEmail = (email ?? '').trim().toLowerCase();
    return _client.auth.verifyOTP(
      type: OtpType.email,
      email: normalizedEmail,
      token: otp,
    );
  }

  /// Launches the Google OAuth flow via the system browser / deep link.
  Future<bool> signInWithGoogle() async {
    return _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: AppConfig.supabaseOAuthRedirect,
    );
  }

  Future<void> logout() async {
    await clearSession();
  }

  Future<void> clearSession() async {
    try {
      await _client.auth.signOut();
    } catch (_) {}
  }
}
