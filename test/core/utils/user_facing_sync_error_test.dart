import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karatou/app/core/utils/user_facing_sync_error.dart';

void main() {
  group('userFacingSyncError', () {
    test('French locale returns French network message for connection error',
        () {
      final msg = userFacingSyncError(
        DioException(
          requestOptions: RequestOptions(path: '/x'),
          type: DioExceptionType.connectionError,
        ),
        'fr',
      );
      expect(msg, contains('serveur'));
    });

    test('English locale returns English message', () {
      final msg = userFacingSyncError(
        DioException(
          requestOptions: RequestOptions(path: '/x'),
          type: DioExceptionType.connectionError,
        ),
        'en',
      );
      expect(msg.toLowerCase(), contains('server'));
    });

    test('maps 401 to session-related message', () {
      final msg = userFacingSyncError(
        DioException(
          requestOptions: RequestOptions(path: '/x'),
          response: Response(
            requestOptions: RequestOptions(path: '/x'),
            statusCode: 401,
          ),
          type: DioExceptionType.badResponse,
        ),
        'fr',
      );
      expect(msg.toLowerCase(), contains('session'));
    });

    test('generic fallback for unknown errors', () {
      final msg = userFacingSyncError(Exception(' opaque '), 'en');
      expect(msg.toLowerCase(), contains('sync'));
    });
  });
}
