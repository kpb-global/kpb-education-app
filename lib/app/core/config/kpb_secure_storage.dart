import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Shared [FlutterSecureStorage] configuration. Backs `KpbSecureLocalStorage`
/// (the Supabase auth session store), keeping the refresh token out of plain
/// SharedPreferences/NSUserDefaults.
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
