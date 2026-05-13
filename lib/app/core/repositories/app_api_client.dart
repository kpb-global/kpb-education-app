import 'dart:async';

import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../config/kpb_secure_storage.dart';

class AppApiClient {
  AppApiClient({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: AppConfig.apiBaseUrl,
                connectTimeout: const Duration(
                  seconds: AppConfig.requestTimeoutInSeconds,
                ),
                receiveTimeout: const Duration(
                  seconds: AppConfig.requestTimeoutInSeconds,
                ),
                sendTimeout: const Duration(
                  seconds: AppConfig.requestTimeoutInSeconds,
                ),
                headers: const {
                  'Accept': 'application/json',
                  'Content-Type': 'application/json',
                },
              ),
            ) {
    _dio.interceptors.add(_AuthInterceptor(_dio));
  }

  final Dio _dio;

  /// Generic POST for auth endpoints (no token needed).
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> payload,
  ) async {
    final response = await _dio.post<Map<String, dynamic>>(path, data: payload);
    return response.data ?? <String, dynamic>{};
  }

  // ── Device tokens ─────────────────────────────────────────────

  Future<void> registerDeviceToken(String token, String platform) async {
    await _dio.post<void>(
      '/device-tokens',
      data: {'token': token, 'platform': platform},
    );
  }

  Future<void> unregisterDeviceToken(String token) async {
    await _dio.delete<void>('/device-tokens/$token');
  }

  Future<Map<String, dynamic>> getProfile() async {
    final response = await _dio.get<Map<String, dynamic>>('/profiles/me');
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> updateProfile(
      Map<String, dynamic> payload) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/profiles/me',
      data: payload,
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> createOrientationSession(
    Map<String, dynamic> payload,
  ) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/orientation/sessions',
      data: payload,
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> getOrientationResult(String sessionId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/orientation/results/$sessionId',
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<List<dynamic>> listCatalog(String resource) async {
    final response = await _dio.get<Map<String, dynamic>>('/catalog/$resource');
    final data = response.data ?? <String, dynamic>{};
    return (data['items'] as List<dynamic>? ?? <dynamic>[]);
  }

  /// Fetch live scraped scholarships, filtered and scored by the user's profile.
  Future<List<dynamic>> fetchLiveScholarships({
    required String lang,
    String? level,
    List<String>? fieldIds,
    String? countryId,
    String? fundingType,
    int limit = 20,
    int offset = 0,
  }) async {
    final queryParams = <String, dynamic>{
      'lang': lang,
      'limit': limit,
      'offset': offset,
      if (level != null) 'level': level,
      if (fieldIds != null && fieldIds.isNotEmpty) 'fields': fieldIds.join(','),
      if (countryId != null) 'countryId': countryId,
      if (fundingType != null) 'fundingType': fundingType,
    };
    final response = await _dio.get<Map<String, dynamic>>(
      '/scholarships',
      queryParameters: queryParams,
    );
    final data = response.data ?? <String, dynamic>{};
    return (data['items'] as List<dynamic>? ?? <dynamic>[]);
  }

  Future<List<dynamic>> listContent(String resource) async {
    final response = await _dio.get<Map<String, dynamic>>('/content/$resource');
    final data = response.data ?? <String, dynamic>{};
    return (data['items'] as List<dynamic>? ?? <dynamic>[]);
  }

  Future<List<dynamic>> listCommunity(String resource) async {
    final response =
        await _dio.get<Map<String, dynamic>>('/community/$resource');
    final data = response.data ?? <String, dynamic>{};
    return (data['items'] as List<dynamic>? ?? <dynamic>[]);
  }

  Future<List<dynamic>> listCases() async {
    final response = await _dio.get<List<dynamic>>('/cases');
    return response.data ?? <dynamic>[];
  }

  Future<Map<String, dynamic>> getCase(String caseId) async {
    final response = await _dio.get<Map<String, dynamic>>('/cases/$caseId');
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> createCase(Map<String, dynamic> payload) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/cases',
      data: payload,
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> updateCase(
    String caseId,
    Map<String, dynamic> payload,
  ) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/cases/$caseId',
      data: payload,
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<List<dynamic>> listCaseMessages(String caseId) async {
    final response = await _dio.get<List<dynamic>>('/cases/$caseId/messages');
    return response.data ?? <dynamic>[];
  }

  Future<Map<String, dynamic>> createCaseMessage(
    String caseId,
    Map<String, dynamic> payload,
  ) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/cases/$caseId/messages',
      data: payload,
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> uploadCaseDocument(
    String caseId,
    Map<String, dynamic> payload,
  ) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/cases/$caseId/documents',
      data: payload,
    );
    return response.data ?? <String, dynamic>{};
  }

  /// Multipart upload to `/cases/:id/documents/upload`. The file should
  /// already be compressed client-side via [DocumentUploadService] before
  /// calling this — students pay by the megabyte.
  Future<Map<String, dynamic>> uploadCaseDocumentFile({
    required String caseId,
    required String filePath,
    required String title,
    void Function(int sent, int total)? onProgress,
  }) async {
    final fileName = filePath.split('/').last;
    final formData = FormData.fromMap(<String, dynamic>{
      'title': title,
      'file': await MultipartFile.fromFile(filePath, filename: fileName),
    });
    final response = await _dio.post<Map<String, dynamic>>(
      '/cases/$caseId/documents/upload',
      data: formData,
      onSendProgress: onProgress,
      options: Options(
        contentType: 'multipart/form-data',
        headers: const {'Accept': 'application/json'},
      ),
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<List<dynamic>> listAppointments() async {
    final response = await _dio.get<List<dynamic>>('/appointments');
    return response.data ?? <dynamic>[];
  }

  Future<Map<String, dynamic>> createAppointment(
    Map<String, dynamic> payload,
  ) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/appointments',
      data: payload,
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<List<dynamic>> listSavedItems() async {
    final response = await _dio.get<List<dynamic>>('/saved-items');
    return response.data ?? <dynamic>[];
  }

  Future<Map<String, dynamic>> createSavedItem(
    Map<String, dynamic> payload,
  ) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/saved-items',
      data: payload,
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<void> deleteSavedItem(String savedItemId) async {
    await _dio.delete<void>('/saved-items/$savedItemId');
  }

  Future<Map<String, dynamic>> createPartnerLead(
    Map<String, dynamic> payload,
  ) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/partner-leads',
      data: payload,
    );
    return response.data ?? <String, dynamic>{};
  }

  // ── Parent links (Track C1) ───────────────────────────────────────────────

  Future<Map<String, dynamic>> createParentInvite() async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/parent-links/invites',
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> acceptParentInvite(String inviteCode) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/parent-links/accept',
      data: {'inviteCode': inviteCode},
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<List<dynamic>> listParentChildren() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/parent-links/children',
    );
    final data = response.data ?? <String, dynamic>{};
    return (data['items'] as List<dynamic>? ?? <dynamic>[]);
  }

  Future<List<dynamic>> listParentVisibleCases() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/parent-links/cases',
    );
    final data = response.data ?? <String, dynamic>{};
    return (data['items'] as List<dynamic>? ?? <dynamic>[]);
  }

  Future<Map<String, dynamic>> getParentVisibleCase(String caseId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/parent-links/cases/$caseId',
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> setCaseParentVisibility({
    required String caseId,
    required bool parentCanView,
  }) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/parent-links/cases/$caseId/visibility',
      data: {'parentCanView': parentCanView},
    );
    return response.data ?? <String, dynamic>{};
  }

  // ── Payments (Track C3) ───────────────────────────────────────────────────

  Future<List<String>> listPaymentProviders() async {
    final response = await _dio.get<Map<String, dynamic>>('/payments/providers');
    final data = response.data ?? <String, dynamic>{};
    return (data['providers'] as List<dynamic>? ?? <dynamic>[])
        .map((e) => e.toString())
        .toList();
  }

  Future<Map<String, dynamic>> createPaymentIntent({
    required String provider,
    required int amountMinor,
    required String returnUrl,
    required String cancelUrl,
    String? caseId,
    String? counsellorId,
    String currency = 'XOF',
    String? description,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/payments/intents',
      data: {
        'provider': provider,
        'amountMinor': amountMinor,
        'currency': currency,
        'returnUrl': returnUrl,
        'cancelUrl': cancelUrl,
        if (caseId != null) 'caseId': caseId,
        if (counsellorId != null) 'counsellorId': counsellorId,
        if (description != null) 'description': description,
      },
    );
    return response.data ?? <String, dynamic>{};
  }

  // ── Counsellor marketplace (Track B) ──────────────────────────────────────

  Future<List<dynamic>> listCounsellors({
    String? country,
    String? specialty,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/counsellors',
      queryParameters: {
        if (country != null) 'country': country,
        if (specialty != null) 'specialty': specialty,
      },
    );
    final data = response.data ?? <String, dynamic>{};
    return (data['items'] as List<dynamic>? ?? <dynamic>[]);
  }

  Future<Map<String, dynamic>> getCounsellor(String counsellorId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/counsellors/$counsellorId',
    );
    return response.data ?? <String, dynamic>{};
  }

  // ── Phase 3 — Service packages ("Dossier prêt" + kits) ────────────────────

  Future<List<dynamic>> listServicePackages({String? category}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/service-packages',
      queryParameters: {
        if (category != null) 'category': category,
      },
    );
    final data = response.data ?? <String, dynamic>{};
    return (data['items'] as List<dynamic>? ?? <dynamic>[]);
  }

  Future<Map<String, dynamic>> getServicePackage(String code) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/service-packages/$code',
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> purchaseServicePackage({
    required String packageCode,
    required String returnUrl,
    required String cancelUrl,
    String? provider,
    String? caseId,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/me/purchases',
      data: {
        'packageCode': packageCode,
        'returnUrl': returnUrl,
        'cancelUrl': cancelUrl,
        if (provider != null) 'provider': provider,
        if (caseId != null) 'caseId': caseId,
      },
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<List<dynamic>> listMyPurchases() async {
    final response = await _dio.get<Map<String, dynamic>>('/me/purchases');
    final data = response.data ?? <String, dynamic>{};
    return (data['items'] as List<dynamic>? ?? <dynamic>[]);
  }

  // ── Phase 3 — Alumni mentor directory ─────────────────────────────────────

  Future<List<dynamic>> listAlumni({
    String? country,
    String? university,
    int? limit,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/alumni',
      queryParameters: {
        if (country != null) 'country': country,
        if (university != null) 'university': university,
        if (limit != null) 'limit': limit.toString(),
      },
    );
    final data = response.data ?? <String, dynamic>{};
    return (data['items'] as List<dynamic>? ?? <dynamic>[]);
  }

  Future<Map<String, dynamic>> getMyAlumniStatus() async {
    final response = await _dio.get<Map<String, dynamic>>('/me/alumni');
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> applyAsAlumni({
    required String university,
    required String programme,
    required int graduationYear,
    required String proofUrl,
    String? countryCode,
    String? bioFr,
    String? bioEn,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/me/alumni/apply',
      data: {
        'alumniUniversity': university,
        'alumniProgramme': programme,
        'alumniGraduationYear': graduationYear,
        'alumniProofUrl': proofUrl,
        if (countryCode != null) 'alumniCountryCode': countryCode,
        if (bioFr != null) 'alumniBioFr': bioFr,
        if (bioEn != null) 'alumniBioEn': bioEn,
      },
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> setAlumniBadgeVisible(bool visible) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/me/alumni/badge-visible',
      data: {'visible': visible},
    );
    return response.data ?? <String, dynamic>{};
  }

  // ── Phase 3 — Partners (credibility layer) ────────────────────────────────

  Future<List<dynamic>> listPartners({String? category, String? country}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/partners',
      queryParameters: {
        if (category != null) 'category': category,
        if (country != null) 'country': country,
      },
    );
    final data = response.data ?? <String, dynamic>{};
    return (data['items'] as List<dynamic>? ?? <dynamic>[]);
  }

  Future<List<dynamic>> listFeaturedPartners({int limit = 12}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/partners/featured',
      queryParameters: {'limit': limit.toString()},
    );
    final data = response.data ?? <String, dynamic>{};
    return (data['items'] as List<dynamic>? ?? <dynamic>[]);
  }

  // ── Phase 3 — Salon KPB Virtuel ───────────────────────────────────────────

  Future<List<dynamic>> listSalonEvents() async {
    final response = await _dio.get<Map<String, dynamic>>('/salon/events');
    final data = response.data ?? <String, dynamic>{};
    return (data['items'] as List<dynamic>? ?? <dynamic>[]);
  }

  Future<Map<String, dynamic>> getSalonEvent(String slug) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/salon/events/$slug',
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> registerForSalonSession(String sessionId) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/me/salon/sessions/$sessionId/register',
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<void> cancelSalonRegistration(String sessionId) async {
    await _dio.delete<Map<String, dynamic>>(
      '/me/salon/sessions/$sessionId/register',
    );
  }

  Future<List<dynamic>> listMySalonRegistrations() async {
    final response =
        await _dio.get<Map<String, dynamic>>('/me/salon/registrations');
    final data = response.data ?? <String, dynamic>{};
    return (data['items'] as List<dynamic>? ?? <dynamic>[]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Auth interceptor — injects Bearer token, auto-refreshes on 401
// ─────────────────────────────────────────────────────────────────────────────
class _AuthInterceptor extends Interceptor {
  _AuthInterceptor(this._dio);

  final Dio _dio;
  bool _isRefreshing = false;
  Completer<bool>? _refreshCompleter;

  static const _keyAccessToken = 'kpb.auth.accessToken';
  static const _keyRefreshToken = 'kpb.auth.refreshToken';
  static const _storage = kpbFlutterSecureStorage;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Skip auth header for auth endpoints
    if (options.path.startsWith('/auth/')) {
      return handler.next(options);
    }

    final token = await _storage.read(key: _keyAccessToken);
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode != 401 ||
        err.requestOptions.path.startsWith('/auth/')) {
      return handler.next(err);
    }

    // Try to refresh the token
    if (_isRefreshing) {
      final success = await _refreshCompleter?.future ?? false;
      if (success) {
        return handler.resolve(await _retryRequest(err.requestOptions));
      }
      return handler.next(err);
    }

    _isRefreshing = true;
    _refreshCompleter = Completer<bool>();

    try {
      final refresh = await _storage.read(key: _keyRefreshToken);
      if (refresh == null || refresh.isEmpty) {
        _refreshCompleter!.complete(false);
        return handler.next(err);
      }

      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/student/refresh',
        data: {'refreshToken': refresh},
      );
      final data = response.data;
      if (data != null) {
        final newAccess = data['accessToken'] as String?;
        final newRefresh = data['refreshToken'] as String?;
        if (newAccess != null) {
          await _storage.write(key: _keyAccessToken, value: newAccess);
        }
        if (newRefresh != null) {
          await _storage.write(key: _keyRefreshToken, value: newRefresh);
        }
        _refreshCompleter!.complete(true);
        return handler.resolve(await _retryRequest(err.requestOptions));
      }
      _refreshCompleter!.complete(false);
      handler.next(err);
    } catch (_) {
      _refreshCompleter!.complete(false);
      handler.next(err);
    } finally {
      _isRefreshing = false;
      _refreshCompleter = null;
    }
  }

  Future<Response<dynamic>> _retryRequest(RequestOptions options) async {
    final token = await _storage.read(key: _keyAccessToken);
    options.headers['Authorization'] = 'Bearer $token';
    return _dio.fetch(options);
  }
}
