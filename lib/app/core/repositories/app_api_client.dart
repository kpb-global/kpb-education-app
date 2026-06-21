import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart' show Color, EdgeInsets;
import 'package:get/get.dart' hide Response, FormData, MultipartFile;
import 'package:supabase_flutter/supabase_flutter.dart' hide MultipartFile;

import '../config/app_config.dart';
import '../controllers/app_controller.dart';
import '../models/app_models.dart';
import '../navigation/app_boot_screen.dart';

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

  /// True when an authenticated Supabase session is present.
  Future<bool> hasAuthSession() async {
    final token = Supabase.instance.client.auth.currentSession?.accessToken;
    return token != null && token.isNotEmpty;
  }

  /// Generic POST for auth endpoints (no token needed).
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> payload,
  ) async {
    final response = await _dio.post<Map<String, dynamic>>(path, data: payload);
    return response.data ?? <String, dynamic>{};
  }

  /// Generic GET returning a JSON object.
  Future<Map<String, dynamic>> get(String path) async {
    final response = await _dio.get<Map<String, dynamic>>(path);
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

  Future<Map<String, dynamic>> submitOrientation(
    Map<String, dynamic> payload,
  ) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/orientation/submit',
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

  // ── Coach IA (M10) ────────────────────────────────────────────

  Future<Map<String, dynamic>> getCoachQuota(String userId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/coach/quota',
      queryParameters: {'userId': userId},
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> createCoachConversation({
    required String userId,
    required Map<String, dynamic> profile,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/coach/conversations',
      data: {'userId': userId, 'profile': profile},
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<List<dynamic>> getCoachMessages(String conversationId) async {
    final response = await _dio.get<List<dynamic>>(
      '/coach/conversations/$conversationId/messages',
    );
    return response.data ?? const [];
  }

  Future<List<dynamic>> getCoachSuggestions(String userId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/coach/suggestions',
      queryParameters: {'userId': userId},
    );
    final data = response.data ?? <String, dynamic>{};
    return data['suggestions'] as List<dynamic>? ?? const [];
  }

  Stream<Map<String, dynamic>> streamCoachReply({
    required String conversationId,
    required String userId,
    required String message,
    required Map<String, dynamic> profile,
  }) async* {
    final response = await _dio.get<ResponseBody>(
      '/coach/conversations/$conversationId/messages/stream',
      queryParameters: {
        'userId': userId,
        'message': message,
        'fullName': profile['fullName'],
        'currentLevel': profile['currentLevel'],
        'targetCountryIds':
            (profile['targetCountryIds'] as List<dynamic>?)?.join(',') ?? '',
      },
      options: Options(responseType: ResponseType.stream),
    );

    final stream = response.data?.stream;
    if (stream == null) return;

    var buffer = '';
    await for (final chunk in stream) {
      buffer += utf8.decode(chunk, allowMalformed: true);
      final lines = buffer.split('\n');
      buffer = lines.removeLast();

      for (final line in lines) {
        if (!line.startsWith('data:')) continue;
        final payload = line.substring(5).trim();
        if (payload.isEmpty) continue;
        try {
          yield jsonDecode(payload) as Map<String, dynamic>;
        } catch (_) {
          // Ignore malformed SSE chunks.
        }
      }
    }
  }

  // ── Commercial (M9) ───────────────────────────────────────────

  Future<List<CommercialLead>> listCommercialLeads({
    required String email,
    String filter = 'all',
  }) async {
    final response = await _dio.get<List<dynamic>>(
      '/commercial/leads',
      queryParameters: {'email': email, 'filter': filter},
    );
    final items = response.data ?? const [];
    return items
        .map((item) => CommercialLead.fromApi(item as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, dynamic>> updateCommercialLead(
    String caseId, {
    String? leadTag,
    String? discussionMotive,
  }) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/commercial/leads/$caseId',
      data: {
        if (leadTag != null) 'leadTag': leadTag,
        if (discussionMotive != null) 'discussionMotive': discussionMotive,
      },
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> getCommercialStats({
    required String email,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/commercial/stats',
      queryParameters: {'email': email},
    );
    return response.data ?? <String, dynamic>{};
  }

  // ── Parcours (Chantier C) — KPB YouTube playlist ───────────────────────────

  /// Returns the playlist videos plus a `configured` flag (false when the
  /// backend has no YOUTUBE_API_KEY → the UI shows an informative empty state).
  Future<({List<YoutubeVideo> items, bool configured})>
      listParcoursVideos() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/content/youtube-playlist',
    );
    final data = response.data ?? <String, dynamic>{};
    final rawItems = (data['items'] as List<dynamic>? ?? const []);
    final items = rawItems
        .whereType<Map<String, dynamic>>()
        .map(YoutubeVideo.fromApi)
        .where((v) => v.videoId.isNotEmpty)
        .toList();
    return (items: items, configured: data['configured'] as bool? ?? false);
  }

  Future<List<dynamic>> listCatalog(String resource) async {
    final queryParameters = (resource == 'programs' || resource == 'institutions')
        ? <String, dynamic>{'limit': 1000}
        : null;
    final response = await _dio.get<Map<String, dynamic>>(
      '/catalog/$resource',
      queryParameters: queryParameters,
    );
    final data = response.data ?? <String, dynamic>{};
    return (data['items'] as List<dynamic>? ?? <dynamic>[]);
  }

  Future<Map<String, dynamic>> getCountryDetail(String countryKey) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/countries/${Uri.encodeComponent(countryKey)}',
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> submitCountryQuiz(
    String countryKey,
    Map<String, String> answers,
  ) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/countries/${Uri.encodeComponent(countryKey)}/quiz/submit',
      data: {'answers': answers},
    );
    return response.data ?? <String, dynamic>{};
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

  // ── Payments ──────────────────────────────────────────────────────────────
  // Intentionally not called from the app. Our (largely African) audience
  // settles fees directly with a KPB advisor over WhatsApp rather than through
  // an in-app checkout. The backend `payments` module + endpoints remain for
  // admin/manual reconciliation; the client just no longer initiates them.

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

  // purchaseServicePackage() removed: the app no longer initiates in-app
  // checkout. Students arrange payment with an advisor on WhatsApp (see
  // service_packages_screen). The backend purchase endpoint remains available.

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

  // ── AI document review (Sprint 9 — Document Studio) ───────────────────────

  /// Sends a draft (motivation letter or CV) to the backend for structured
  /// AI feedback. [kind] is `'motivation'` or `'cv'`. Student-authenticated;
  /// the auth token is attached by the interceptor like other student calls.
  Future<Map<String, dynamic>> reviewDocument({
    required String kind,
    required String text,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/document-review',
      data: {'kind': kind, 'text': text},
    );
    return response.data ?? <String, dynamic>{};
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
// Auth interceptor — injects the Supabase Bearer token, refreshes on 401
// ─────────────────────────────────────────────────────────────────────────────
class _AuthInterceptor extends Interceptor {
  _AuthInterceptor(this._dio);

  final Dio _dio;
  bool _isRefreshing = false;
  Completer<bool>? _refreshCompleter;

  GoTrueClient get _auth => Supabase.instance.client.auth;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Skip auth header for auth endpoints
    if (options.path.startsWith('/auth/')) {
      return handler.next(options);
    }

    final token = _auth.currentSession?.accessToken;
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

    // Bug A: a request that already went through a post-refresh retry must
    // NOT be retried again — that would loop forever if the new token is also
    // rejected (revoked refresh token, clock skew, backend reboot).
    if (err.requestOptions.extra['authRetried'] == true) {
      await _handlePermanentFailure();
      return handler.next(err);
    }

    // Concurrent 401 while a refresh is in flight — wait for its outcome,
    // then retry exactly once (guarded by the authRetried flag above).
    if (_isRefreshing) {
      final success = await _refreshCompleter?.future ?? false;
      if (!success) return handler.next(err);
      try {
        return handler.resolve(await _retryRequest(err.requestOptions));
      } catch (_) {
        return handler.next(err);
      }
    }

    if (_auth.currentSession == null) {
      // Guest/local-only session — never wipe onboarding on missing token.
      return handler.next(err);
    }

    _isRefreshing = true;
    _refreshCompleter = Completer<bool>();

    // Bug B: separate the refresh from the retry so the catch only handles
    // refresh failures — a retry that throws AFTER a successful refresh must
    // not call complete() on an already-completed completer (StateError).
    bool refreshed = false;
    try {
      final response = await _auth.refreshSession();
      refreshed = response.session != null;
    } catch (_) {
      refreshed = false;
    }
    if (!_refreshCompleter!.isCompleted) {
      _refreshCompleter!.complete(refreshed);
    }
    _isRefreshing = false;

    if (!refreshed) {
      await _handlePermanentFailure();
      _refreshCompleter = null;
      return handler.next(err);
    }

    try {
      final response = await _retryRequest(err.requestOptions);
      _refreshCompleter = null;
      return handler.resolve(response);
    } catch (_) {
      _refreshCompleter = null;
      return handler.next(err);
    }
  }

  Future<void> _handlePermanentFailure() async {
    try {
      await _auth.signOut();
    } catch (_) {}
    try {
      if (Get.isRegistered<AppController>()) {
        final controller = Get.find<AppController>();
        if (controller.profile != null) {
          await controller.logout();
          // Route to the boot gate, not the authenticated shell, so the user
          // lands on the login/onboarding screen rather than AppShell.
          Get.offAll(() => const AppBootScreen());
          Get.snackbar(
            'Session Expirée',
            'Votre session a expiré. Veuillez vous reconnecter.',
            snackPosition: SnackPosition.BOTTOM,
            margin: const EdgeInsets.all(12),
            backgroundColor: const Color(0xFFFEE2E2), // soft red
            colorText: const Color(0xFF991B1B), // dark red
            duration: const Duration(seconds: 4),
          );
        }
      }
    } catch (_) {}
  }

  Future<Response<dynamic>> _retryRequest(RequestOptions options) async {
    final token = _auth.currentSession?.accessToken;
    if (token == null || token.isEmpty) {
      // No usable token after refresh — bail out instead of sending
      // a literal "Bearer null".
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.cancel,
        message: 'No access token available for retry.',
      );
    }
    options.headers['Authorization'] = 'Bearer $token';
    // Mark so a recursive 401 short-circuits to permanent failure (Bug A).
    options.extra['authRetried'] = true;
    return _dio.fetch(options);
  }
}
