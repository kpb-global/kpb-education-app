// Les deux requêtes publiques du catalogue « Études en France » : la forme de
// l'URL que le serveur reçoit, vérifiée ICI plutôt que supposée par les mocks de
// plus haut (ils remplacent le client entier, donc ne voient jamais l'URL).

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:karatou/app/core/repositories/app_api_client.dart';

class _MockDio extends Mock implements Dio {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockDio dio;
  late AppApiClient client;
  late Map<String, dynamic> lastParams;
  late String lastPath;

  Response<Map<String, dynamic>> ok(String path, Map<String, dynamic> body) =>
      Response<Map<String, dynamic>>(
        requestOptions: RequestOptions(path: path),
        data: body,
        statusCode: 200,
      );

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (MethodCall call) async => null,
    );
    dio = _MockDio();
    when(() => dio.interceptors).thenReturn(Interceptors());
    when(() => dio.get<Map<String, dynamic>>(
          any(),
          queryParameters: any(named: 'queryParameters'),
        )).thenAnswer((invocation) async {
      lastPath = invocation.positionalArguments.single as String;
      lastParams = Map<String, dynamic>.from(
          invocation.namedArguments[#queryParameters] as Map);
      return ok(lastPath, <String, dynamic>{'ok': true});
    });
    client = AppApiClient(dio: dio);
  });

  group('searchEefCatalog — la ville voyage', () {
    test('campusCity et fieldId partent en valeurs séparées par des virgules',
        () async {
      await client.searchEefCatalog(
        query: ' droit ',
        fieldIds: ['d07', 'd09'],
        campusCities: ['Lyon', "Villeneuve-d'Ascq"],
        cycles: ['master'],
      );

      expect(lastPath, '/etudes-en-france/search');
      expect(lastParams['q'], 'droit');
      expect(lastParams['fieldId'], 'd07,d09');
      expect(lastParams['campusCity'], "Lyon,Villeneuve-d'Ascq");
      expect(lastParams['cycle'], 'master');
    });

    test('une famille vide n\'envoie aucun paramètre', () async {
      await client.searchEefCatalog();
      expect(lastParams, isEmpty);
    });
  });

  group('fetchEefCities — GET /etudes-en-france/cities', () {
    test('mêmes paramètres de filtre que la recherche, sauf la ville',
        () async {
      await client.fetchEefCities(
        query: '  informatique ',
        cycles: ['master', 'licence1'],
        procedureTypes: ['eef'],
        fieldIds: ['d01'],
        institutionIds: ['eef-univ-0134009m'],
        selectivities: ['selective'],
      );

      expect(lastPath, '/etudes-en-france/cities');
      expect(lastParams, <String, dynamic>{
        'q': 'informatique',
        'cycle': 'master,licence1',
        'procedureType': 'eef',
        'fieldId': 'd01',
        'institutionId': 'eef-univ-0134009m',
        'selectivity': 'selective',
      });
    });

    test('n\'envoie JAMAIS campusCity : le serveur l\'ignore', () async {
      await client.fetchEefCities(query: 'lyon', cycles: ['master']);
      expect(lastParams.containsKey('campusCity'), isFalse);
    });

    test('sans filtre : aucun paramètre, pas de « q » vide', () async {
      await client.fetchEefCities(query: '   ');
      expect(lastParams, isEmpty);
    });

    test('rend le corps tel quel', () async {
      final body = await client.fetchEefCities();
      expect(body, <String, dynamic>{'ok': true});
    });

    test(
        'un échec remonte : un 404 n\'est pas avalé ici (le contrôleur décide)',
        () async {
      when(() => dio.get<Map<String, dynamic>>(
            any(),
            queryParameters: any(named: 'queryParameters'),
          )).thenThrow(DioException(
        requestOptions: RequestOptions(path: '/etudes-en-france/cities'),
        type: DioExceptionType.badResponse,
        response: Response<dynamic>(
          requestOptions: RequestOptions(path: '/etudes-en-france/cities'),
          statusCode: 404,
        ),
      ));

      expect(
        () => client.fetchEefCities(),
        throwsA(isA<DioException>()
            .having((e) => e.response?.statusCode, 'status', 404)),
      );
    });
  });
}
