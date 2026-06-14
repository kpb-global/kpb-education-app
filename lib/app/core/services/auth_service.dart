import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/kpb_secure_storage.dart';
import '../repositories/app_api_client.dart';

class AuthService {
  AuthService._(this._storage, this._apiClient);

  final FlutterSecureStorage _storage;
  final AppApiClient _apiClient;

  static const _keyAccessToken = 'kpb.auth.accessToken';
  static const _keyRefreshToken = 'kpb.auth.refreshToken';
  static const _keyUserId = 'kpb.auth.userId';

  String? _cachedAccessToken;
  String? _cachedRefreshToken;
  String? _cachedUserId;

  static Future<AuthService> create(AppApiClient apiClient) async {
    const storage = kpbFlutterSecureStorage;
    final service = AuthService._(storage, apiClient);
    // Pre-load tokens into memory for synchronous access
    service._cachedAccessToken = await storage.read(key: _keyAccessToken);
    service._cachedRefreshToken = await storage.read(key: _keyRefreshToken);
    service._cachedUserId = await storage.read(key: _keyUserId);
    return service;
  }

  String? get accessToken => _cachedAccessToken;
  String? get refreshToken => _cachedRefreshToken;
  String? get userId => _cachedUserId;
  bool get isLoggedIn => accessToken != null && accessToken!.isNotEmpty;

  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String fullName,
    String? phone,
    String? countryOfResidence,
    String preferredLanguage = 'fr',
  }) async {
    final response = await _apiClient.post('/auth/student/register', {
      'email': email,
      'password': password,
      'fullName': fullName,
      if (phone != null) 'phone': phone,
      if (countryOfResidence != null) 'countryOfResidence': countryOfResidence,
      'preferredLanguage': preferredLanguage,
    });
    await _storeTokens(response);
    return response;
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await _apiClient.post('/auth/student/login', {
      'email': email,
      'password': password,
    });
    await _storeTokens(response);
    return response;
  }

  Future<void> forgotPassword({required String email}) async {
    await _apiClient.post('/auth/student/forgot-password', {'email': email});
  }

  Future<bool> refreshAccessToken() async {
    final currentRefresh = refreshToken;
    if (currentRefresh == null || currentRefresh.isEmpty) return false;

    try {
      final response = await _apiClient.post('/auth/student/refresh', {
        'refreshToken': currentRefresh,
      });
      await _storeTokens(response);
      return true;
    } catch (_) {
      await logout();
      return false;
    }
  }

  Future<void> logout() async {
    _cachedAccessToken = null;
    _cachedRefreshToken = null;
    _cachedUserId = null;
    await _storage.delete(key: _keyAccessToken);
    await _storage.delete(key: _keyRefreshToken);
    await _storage.delete(key: _keyUserId);
  }

  Future<void> _storeTokens(Map<String, dynamic> response) async {
    final access = response['accessToken'] as String?;
    final refresh = response['refreshToken'] as String?;
    final user = response['user'] as Map<String, dynamic>?;

    if (access != null) {
      _cachedAccessToken = access;
      await _storage.write(key: _keyAccessToken, value: access);
    }
    if (refresh != null) {
      _cachedRefreshToken = refresh;
      await _storage.write(key: _keyRefreshToken, value: refresh);
    }
    if (user != null) {
      final id = user['id'] as String?;
      if (id != null) {
        _cachedUserId = id;
        await _storage.write(key: _keyUserId, value: id);
      }
    }
  }
}
