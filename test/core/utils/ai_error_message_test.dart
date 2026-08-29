import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide Response;

import 'package:karatou/app/core/translations/app_translations.dart';
import 'package:karatou/app/core/utils/ai_error_message.dart';

DioException _dio({
  int? status,
  Object? data,
  DioExceptionType type = DioExceptionType.badResponse,
}) {
  return DioException(
    requestOptions: RequestOptions(path: '/tools/cv-summary'),
    type: type,
    response: status == null
        ? null
        : Response<dynamic>(
            requestOptions: RequestOptions(path: '/tools/cv-summary'),
            statusCode: status,
            data: data,
          ),
  );
}

void main() {
  setUpAll(() {
    Get.addTranslations(AppTranslations().keys);
    Get.locale = const Locale('fr');
  });

  test('403 ai_consent_required is detected, not a snackbar key', () {
    final error = _dio(
      status: 403,
      data: {'code': 'ai_consent_required', 'message': 'nope'},
    );
    expect(isAiConsentRequiredError(error), isTrue);
    expect(aiConsentBlockCode(error), 'ai_consent_required');
  });

  test('403 guardian_consent_required is not the reopen-dialog case', () {
    final error = _dio(
      status: 403,
      data: {'code': 'guardian_consent_required'},
    );
    expect(isAiConsentRequiredError(error), isFalse);
    expect(aiConsentBlockCode(error), 'guardian_consent_required');
  });

  // `AiConsentService` refuse sur la date de naissance AVANT de regarder le
  // consentement. Ce 403 était inatteignable tant que les outils IA étaient
  // masqués ; la build 50 les démasque, donc il devient un vrai écran.
  test('403 age_verification_required envoie au profil, pas à la connexion',
      () {
    final error = _dio(
      status: 403,
      data: {'code': 'age_verification_required'},
    );
    expect(isAiConsentRequiredError(error), isFalse,
        reason: 'ce n\'est pas le cas qui rouvre la boîte de consentement');
    expect(aiConsentBlockCode(error), 'age_verification_required');

    final message = aiErrorMessage(error).toLowerCase();
    expect(message, contains('date de naissance'));
    // La régression exacte : un compte connecté à qui on dit de se reconnecter.
    expect(message, isNot(contains('reconnecte')));
  });

  test('timeouts blame the network', () {
    final error = _dio(type: DioExceptionType.connectionTimeout);
    expect(aiErrorMessage(error),
        isNot(equals('tools_ai_error_check_connection')));
    expect(aiErrorMessage(error).toLowerCase(), contains('connexion'));
  });
}
