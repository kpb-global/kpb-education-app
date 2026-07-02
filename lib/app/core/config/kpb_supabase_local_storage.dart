import 'package:supabase_flutter/supabase_flutter.dart';

import 'kpb_secure_storage.dart';

/// Persists the Supabase auth session (which contains the long-lived refresh
/// token) in the platform secure store (iOS Keychain / Android Keystore-backed)
/// instead of the default SharedPreferences/NSUserDefaults, where it would sit
/// in plain text.
///
/// Note: `accessToken()` returns the whole persisted session string, matching
/// the contract of the SDK's [LocalStorage] (the name is historical).
class KpbSecureLocalStorage extends LocalStorage {
  const KpbSecureLocalStorage();

  static const _sessionKey = 'kpb-supabase-session';

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> hasAccessToken() async =>
      (await kpbFlutterSecureStorage.read(key: _sessionKey)) != null;

  @override
  Future<String?> accessToken() =>
      kpbFlutterSecureStorage.read(key: _sessionKey);

  @override
  Future<void> removePersistedSession() =>
      kpbFlutterSecureStorage.delete(key: _sessionKey);

  @override
  Future<void> persistSession(String persistSessionString) =>
      kpbFlutterSecureStorage.write(
        key: _sessionKey,
        value: persistSessionString,
      );
}
