import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karatou/app/core/config/app_config.dart';
import 'package:karatou/app/core/repositories/app_api_client.dart';

/// Real HTTP round-trips against a local server that answers SLOWLY, the way
/// `/tools/personalize-letter` does in production (5–19 s per provider
/// attempt, measured 26/09/2026). A mock Dio would only prove that an
/// `Options` object is passed; this proves Dio actually waits for it.
void main() {
  late HttpServer server;
  late Dio dio;
  late AppApiClient client;
  final requests = <String>[];
  HttpOverrides? bindingOverrides;

  // TestWidgetsFlutterBinding (flutter_test_config.dart) swaps HttpClient for
  // a mock that answers 400 to everything: every request would "fail" here
  // for a reason unrelated to timeouts. Real sockets for this file only.
  setUpAll(() {
    bindingOverrides = HttpOverrides.current;
    HttpOverrides.global = null;
  });
  tearDownAll(() => HttpOverrides.global = bindingOverrides);

  setUp(() async {
    requests.clear();
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      requests.add(request.uri.path);
      await utf8.decoder.bind(request).join();
      await Future<void>.delayed(const Duration(milliseconds: 400));
      request.response
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({'fr': 'Lettre', 'en': 'Letter'}));
      await request.response.close();
    });
    dio = Dio(
      BaseOptions(
        baseUrl: 'http://127.0.0.1:${server.port}/api',
        // Scaled-down stand-in for the 15 s default.
        receiveTimeout: const Duration(milliseconds: 100),
      ),
    );
    client = AppApiClient(
      dio: dio,
      aiReceiveTimeout: const Duration(seconds: 5),
    );
    // The auth interceptor reads Supabase, which is not initialised here and
    // is irrelevant to timeouts.
    dio.interceptors.clear();
  });

  tearDown(() => server.close(force: true));

  test('the default timeout still aborts a slow ordinary call', () async {
    // Proves the harness CAN fail: without the AI override this is exactly
    // the production symptom.
    await expectLater(
      client.post('/tools/personalize-letter', const {}),
      throwsA(
        isA<DioException>().having(
          (e) => e.type,
          'type',
          DioExceptionType.receiveTimeout,
        ),
      ),
    );
  });

  test('postAi waits for a slow generation and normalises the path', () async {
    final result = await client.postAi('tools/personalize-letter', const {});
    expect(result, {'fr': 'Lettre', 'en': 'Letter'});
    expect(requests, ['/api/tools/personalize-letter']);
  });

  test('document review and orientation submit get the AI timeout too',
      () async {
    await client.reviewDocument(kind: 'motivation', text: 'Lettre');
    await client.submitOrientation(const {'answers': <Object>[]});
    expect(requests, ['/api/document-review', '/api/orientation/submit']);
  });

  test('the production AI timeout covers two 40 s backend attempts', () {
    expect(AppConfig.aiRequestTimeoutInSeconds, greaterThan(80));
    expect(AppConfig.requestTimeoutInSeconds, 15);
  });

  test('no screen posts to an AI tool route with the short timeout', () {
    final offenders = <String>[];
    final shortPost = RegExp(r'''\.post\(\s*['"]/?tools/''');
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (shortPost.hasMatch(entity.readAsStringSync())) {
        offenders.add(entity.path);
      }
    }
    expect(offenders, isEmpty, reason: 'use apiClient.postAi for /tools/*');
  });
}
