import 'package:flutter_test/flutter_test.dart';
import 'package:karatou/app/core/services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show LaunchMode;

/// Pins the launch mode used for the Google consent screen.
///
/// What this guards: supabase_flutter's `signInWithOAuth` defaults to
/// [LaunchMode.platformDefault], which `url_launcher_ios` maps to an in-app
/// `SFSafariViewController` for https URLs. supabase_flutter establishes the
/// session from the `io.supabase.kpbeducation://login-callback/` deep link but
/// never dismisses that sheet, so on iOS sign-in succeeded while the user stayed
/// stuck on the blank redirect page (TestFlight, iPhone / iOS 26).
///
/// What it cannot prove: that the sheet is actually gone on a device. Asserting
/// that would mean driving `ASWebAuthenticationSession`/`SFSafariViewController`
/// presentation, which no host-free test can observe — it stays a device check.
/// This test only makes a silent regression back to an in-app browser view (or
/// to the platform default) fail in CI.
void main() {
  group('AuthService.oauthLaunchMode', () {
    test('hands the consent screen to the system browser', () {
      expect(AuthService.oauthLaunchMode, LaunchMode.externalApplication);
    });

    test('is never an in-app browser view nor the platform default', () {
      // platformDefault → SFSafariViewController on iOS (the bug).
      // inAppWebView / inAppBrowserView → same overlay problem, and Google
      // rejects embedded web views outright (`disallowed_useragent`).
      expect(
        AuthService.oauthLaunchMode,
        isNot(anyOf(
          LaunchMode.platformDefault,
          LaunchMode.inAppWebView,
          LaunchMode.inAppBrowserView,
        )),
      );
    });
  });
}
