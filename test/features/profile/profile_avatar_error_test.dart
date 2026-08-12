import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_test/flutter_test.dart';

import 'package:karatou/app/features/profile/profile_avatar_error.dart';

// ─────────────────────────────────────────────────────────────────────────────
// The avatar error table. This is the test that matters for this feature: the
// point of the whole mapping is that a student never reads "check your
// connection" for a server-side cause. So the table below is exhaustive over
// `ProfileAvatarErrorCode` (backend/src/modules/profiles/profile-avatar.errors.ts),
// and there is an explicit assertion that NOTHING but a real transport failure
// can produce the network message.
// ─────────────────────────────────────────────────────────────────────────────

DioException _coded(String code, int status) {
  final options = RequestOptions(path: '/profiles/me/avatar');
  return DioException(
    requestOptions: options,
    type: DioExceptionType.badResponse,
    response: Response<Map<String, dynamic>>(
      requestOptions: options,
      statusCode: status,
      data: <String, dynamic>{'code': code, 'message': 'x'},
    ),
  );
}

DioException _bareStatus(int status) {
  final options = RequestOptions(path: '/profiles/me/avatar');
  return DioException(
    requestOptions: options,
    type: DioExceptionType.badResponse,
    response: Response<String>(
      requestOptions: options,
      statusCode: status,
      // An HTML error page from a proxy: no JSON body, so no code.
      data: '<html>502</html>',
    ),
  );
}

DioException _transport(DioExceptionType type) => DioException(
      requestOptions: RequestOptions(path: '/profiles/me/avatar'),
      type: type,
    );

void main() {
  group('backend code → failure (exhaustive over ProfileAvatarErrorCode)', () {
    const cases = <String, (int, AvatarFailure)>{
      'AVATAR_FILE_REQUIRED': (400, AvatarFailure.fileUnreadable),
      'AVATAR_FILE_EMPTY': (400, AvatarFailure.fileUnreadable),
      'AVATAR_TOO_LARGE': (413, AvatarFailure.fileTooLarge),
      'AVATAR_TYPE_NOT_ALLOWED': (415, AvatarFailure.unsupportedType),
      'AVATAR_INFECTED': (422, AvatarFailure.infected),
      'AVATAR_SCANNER_UNAVAILABLE': (503, AvatarFailure.scannerUnavailable),
      'AVATAR_STORAGE_UNAVAILABLE': (503, AvatarFailure.serviceUnavailable),
      'AVATAR_UPLOAD_CONFLICT': (409, AvatarFailure.conflict),
      'PROFILE_NOT_FOUND': (404, AvatarFailure.profileMissing),
    };

    cases.forEach((code, expected) {
      test('$code → ${expected.$2.name}', () {
        expect(
          classifyAvatarFailure(_coded(code, expected.$1)),
          expected.$2,
        );
      });
    });

    test('the two 503 causes never collapse into one another', () {
      // This is the whole reason the backend ships a code on a 503: "our
      // scanner is down" and "our storage is down" must not read the same, and
      // neither may read as the student's fault.
      final scanner =
          classifyAvatarFailure(_coded('AVATAR_SCANNER_UNAVAILABLE', 503));
      final storage =
          classifyAvatarFailure(_coded('AVATAR_STORAGE_UNAVAILABLE', 503));
      expect(scanner, isNot(storage));
      expect(
        avatarFailureMessageKey(scanner),
        isNot(avatarFailureMessageKey(storage)),
      );
    });
  });

  group('status fallback when the body carries no code', () {
    const cases = <int, AvatarFailure>{
      400: AvatarFailure.fileUnreadable,
      401: AvatarFailure.unauthorized,
      403: AvatarFailure.unauthorized,
      409: AvatarFailure.conflict,
      413: AvatarFailure.fileTooLarge,
      415: AvatarFailure.unsupportedType,
      422: AvatarFailure.infected,
      429: AvatarFailure.rateLimited,
      500: AvatarFailure.server,
      502: AvatarFailure.server,
      503: AvatarFailure.serviceUnavailable,
    };

    cases.forEach((status, expected) {
      test('$status → ${expected.name}', () {
        expect(classifyAvatarFailure(_bareStatus(status)), expected);
      });
    });

    test('an unmapped status is "unknown", not "network"', () {
      final failure = classifyAvatarFailure(_bareStatus(418));
      expect(failure, AvatarFailure.unknown);
      expect(
        avatarFailureMessageKey(failure),
        isNot(avatarFailureMessageKey(AvatarFailure.network)),
      );
    });
  });

  group('only a real transport failure yields the network message', () {
    for (final type in <DioExceptionType>[
      DioExceptionType.connectionTimeout,
      DioExceptionType.sendTimeout,
      DioExceptionType.receiveTimeout,
      DioExceptionType.connectionError,
    ]) {
      test('${type.name} → network', () {
        expect(classifyAvatarFailure(_transport(type)), AvatarFailure.network);
      });
    }

    test('SocketException and TimeoutException → network', () {
      expect(
        classifyAvatarFailure(const SocketException('no route')),
        AvatarFailure.network,
      );
      expect(
        classifyAvatarFailure(TimeoutException('slow')),
        AvatarFailure.network,
      );
    });

    test('every non-transport input maps to something else', () {
      final nonTransport = <Object>[
        _coded('AVATAR_INFECTED', 422),
        _coded('AVATAR_SCANNER_UNAVAILABLE', 503),
        _coded('AVATAR_TOO_LARGE', 413),
        _bareStatus(500),
        _bareStatus(418),
        const AvatarTooLargeLocally(sizeBytes: 3, maxBytes: 2),
        PlatformException(code: 'camera_access_denied'),
        Exception('boom'),
      ];
      for (final error in nonTransport) {
        expect(
          classifyAvatarFailure(error),
          isNot(AvatarFailure.network),
          reason: '$error must not be reported as a connection problem',
        );
      }
    });
  });

  group('local and platform failures', () {
    test('pre-flight size guard → fileTooLarge', () {
      expect(
        classifyAvatarFailure(
          const AvatarTooLargeLocally(sizeBytes: 5, maxBytes: 2),
        ),
        AvatarFailure.fileTooLarge,
      );
    });

    test('denied camera/photo permission gets its own case', () {
      expect(
        classifyAvatarFailure(PlatformException(code: 'camera_access_denied')),
        AvatarFailure.permissionDenied,
      );
      expect(
        classifyAvatarFailure(PlatformException(code: 'photo_access_denied')),
        AvatarFailure.permissionDenied,
      );
    });

    test(
        'an unrelated PlatformException is not mislabelled as a permission '
        'problem', () {
      expect(
        classifyAvatarFailure(PlatformException(code: 'multiple_request')),
        AvatarFailure.unknown,
      );
    });
  });

  group('message keys', () {
    test('every failure has a distinct, non-empty key', () {
      final keys = AvatarFailure.values.map(avatarFailureMessageKey).toList();
      expect(keys.where((k) => k.trim().isEmpty), isEmpty);
      expect(keys.toSet().length, keys.length,
          reason: 'two failure cases share a message: $keys');
    });
  });

  group('idempotent removal', () {
    test('a 404 on DELETE is a success, not an error', () {
      expect(isAvatarAlreadyAbsent(_coded('AVATAR_NOT_FOUND', 404)), isTrue);
      expect(isAvatarAlreadyAbsent(_bareStatus(404)), isTrue);
    });

    test('any other failure is still an error', () {
      expect(isAvatarAlreadyAbsent(_coded('PROFILE_NOT_FOUND', 404)), isFalse);
      expect(isAvatarAlreadyAbsent(_bareStatus(503)), isFalse);
      expect(isAvatarAlreadyAbsent(Exception('boom')), isFalse);
    });
  });

  group('code extraction', () {
    test('is case-insensitive and trims', () {
      final options = RequestOptions(path: '/profiles/me/avatar');
      final error = DioException(
        requestOptions: options,
        response: Response<Map<String, dynamic>>(
          requestOptions: options,
          statusCode: 422,
          data: <String, dynamic>{'code': '  avatar_infected '},
        ),
      );
      expect(avatarFailureCode(error), 'AVATAR_INFECTED');
      expect(classifyAvatarFailure(error), AvatarFailure.infected);
    });

    test('is null when the body has no usable code', () {
      expect(avatarFailureCode(_bareStatus(500)), isNull);
    });
  });
}
