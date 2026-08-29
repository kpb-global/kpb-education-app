import 'package:dio/dio.dart';
import 'package:get/get.dart';

/// Honest mapping of AI-tool failures. Extracted from
/// `cv_generator_screen.dart` so every Groq-backed screen says the same
/// thing — and so a 403 `ai_consent_required` can reopen the consent
/// dialog instead of showing "check your connection" (IA-T6).

String? aiConsentBlockCode(Object error) {
  if (error is! DioException) return null;
  if (error.response?.statusCode != 403) return null;
  final data = error.response?.data;
  if (data is Map && data['code'] is String) {
    final code = data['code'] as String;
    if (code == 'ai_consent_required' ||
        code == 'guardian_consent_required' ||
        code == 'age_verification_required') {
      return code;
    }
  }
  return null;
}

bool isAiConsentRequiredError(Object error) =>
    aiConsentBlockCode(error) == 'ai_consent_required';

String aiErrorMessage(Object error) {
  const fallback = 'tools_ai_error_check_connection';
  String trOr(String key) {
    final value = key.tr;
    return value == key ? fallback.tr : value;
  }

  if (error is! DioException) {
    return trOr('tools_ai_error_unavailable');
  }
  switch (error.type) {
    case DioExceptionType.connectionError:
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return fallback.tr;
    default:
      break;
  }
  final status = error.response?.statusCode;
  final block = aiConsentBlockCode(error);
  if (block == 'guardian_consent_required') {
    return trOr('guardian_consent_required');
  }
  // `AiConsentService` refuse AVANT de regarder le consentement quand la date
  // de naissance manque : un compte connecté tombait donc sur « reconnecte-toi »,
  // qui ne mène nulle part. Le masque des outils IA rendait ce 403 inatteignable
  // ; le démasquage de la build 50 le rend atteignable.
  if (block == 'age_verification_required') {
    return trOr('tools_ai_error_birthdate_required');
  }
  if (status == 401 || status == 403) {
    return trOr('tools_ai_error_signin_required');
  }
  if (status == 429) {
    return trOr('tools_ai_error_rate_limited');
  }
  return trOr('tools_ai_error_unavailable');
}
