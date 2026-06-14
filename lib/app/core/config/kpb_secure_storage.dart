import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Shared [FlutterSecureStorage] configuration for OAuth tokens ([AuthService]
/// and the Dio auth interceptor in `app_api_client.dart`).
///
/// Android (package default): AES-GCM + Keystore-backed keys (API 23+).
/// iOS: Keychain with accessibility until first device unlock after reboot — balances
/// offline API access with limiting exposure when the device has never been unlocked.
const kpbFlutterSecureStorage = FlutterSecureStorage(
  iOptions: IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
    synchronizable: false,
  ),
);
