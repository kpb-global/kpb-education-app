// Les en-têtes de version : informer le serveur, sans jamais perdre une requête.

import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:karatou/app/core/repositories/app_version_headers.dart';

/// Un adaptateur qui note les en-têtes reçus et répond 200.
class _CapturingAdapter implements HttpClientAdapter {
  final List<Map<String, dynamic>> seen = <Map<String, dynamic>>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    seen.add(Map<String, dynamic>.from(options.headers));
    return ResponseBody.fromString('{}', 200, headers: {
      Headers.contentTypeHeader: ['application/json'],
    });
  }

  @override
  void close({bool force = false}) {}
}

PackageInfo _info({String version = '2.3.0', String build = '54'}) =>
    PackageInfo(
      appName: 'KPB',
      packageName: 'com.karatou.android',
      version: version,
      buildNumber: build,
    );

void main() {
  late _CapturingAdapter adapter;

  Dio dioWith(Future<PackageInfo> Function() loader) {
    adapter = _CapturingAdapter();
    return Dio()
      ..httpClientAdapter = adapter
      ..interceptors.add(AppVersionHeadersInterceptor(loader: loader));
  }

  test('envoie la version marketing ET le numéro de build', () async {
    final dio = dioWith(() async => _info());

    await dio.get<dynamic>('https://exemple.test/x');

    expect(adapter.seen.single[AppVersionHeadersInterceptor.versionHeader],
        '2.3.0');
    expect(adapter.seen.single[AppVersionHeadersInterceptor.buildHeader], '54');
  });

  test('les noms d\'en-têtes sont ceux que le serveur lira', () {
    expect(AppVersionHeadersInterceptor.versionHeader, 'X-KPB-App-Version');
    expect(AppVersionHeadersInterceptor.buildHeader, 'X-KPB-App-Build');
  });

  test('ne lit la plateforme qu\'une fois, quel que soit le nombre d\'appels',
      () async {
    var reads = 0;
    final dio = dioWith(() async {
      reads += 1;
      return _info();
    });

    await dio.get<dynamic>('https://exemple.test/a');
    await dio.get<dynamic>('https://exemple.test/b');
    await dio.get<dynamic>('https://exemple.test/c');

    expect(reads, 1);
    expect(adapter.seen, hasLength(3));
  });

  test('deux appels simultanés ne déclenchent qu\'une lecture', () async {
    var reads = 0;
    final completer = Completer<PackageInfo>();
    final dio = dioWith(() {
      reads += 1;
      return completer.future;
    });

    final first = dio.get<dynamic>('https://exemple.test/a');
    final second = dio.get<dynamic>('https://exemple.test/b');
    completer.complete(_info());
    await Future.wait([first, second]);

    expect(reads, 1);
  });

  // La propriété qui compte : un en-tête informatif ne vaut pas une requête
  // perdue. Une plateforme sans le plugin lève ; la requête part quand même.
  test('une lecture qui échoue laisse la requête partir SANS l\'en-tête',
      () async {
    final dio = dioWith(() async => throw StateError('plugin absent'));

    final response = await dio.get<dynamic>('https://exemple.test/x');

    expect(response.statusCode, 200);
    expect(adapter.seen.single.containsKey('X-KPB-App-Version'), isFalse);
    expect(adapter.seen.single.containsKey('X-KPB-App-Build'), isFalse);
  });

  test('un échec est mémorisé : on ne rejoue pas la lecture à chaque appel',
      () async {
    var reads = 0;
    final dio = dioWith(() async {
      reads += 1;
      throw StateError('plugin absent');
    });

    await dio.get<dynamic>('https://exemple.test/a');
    await dio.get<dynamic>('https://exemple.test/b');

    expect(reads, 1);
  });

  test('n\'écrase pas un en-tête posé par l\'appelant', () async {
    final dio = dioWith(() async => _info());

    await dio.get<dynamic>(
      'https://exemple.test/x',
      options: Options(headers: {'X-KPB-App-Version': 'imposée'}),
    );

    expect(adapter.seen.single['X-KPB-App-Version'], 'imposée');
    expect(adapter.seen.single['X-KPB-App-Build'], '54');
  });

  test('omet un champ vide plutôt que d\'envoyer un en-tête vide', () async {
    final dio = dioWith(() async => _info(version: ' ', build: '54'));

    await dio.get<dynamic>('https://exemple.test/x');

    expect(adapter.seen.single.containsKey('X-KPB-App-Version'), isFalse);
    expect(adapter.seen.single['X-KPB-App-Build'], '54');
  });
}
