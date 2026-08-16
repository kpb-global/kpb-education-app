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

  test('timeouts blame the network', () {
    final error = _dio(type: DioExceptionType.connectionTimeout);
    expect(aiErrorMessage(error),
        isNot(equals('tools_ai_error_check_connection')));
    expect(aiErrorMessage(error).toLowerCase(), contains('connexion'));
  });
}
