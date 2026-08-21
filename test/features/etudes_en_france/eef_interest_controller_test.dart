// La règle unique de ce fichier : UN ÉCHEC N'EST JAMAIS UN SUCCÈS.
//
// Le masquage `documentUploadEnabled` existe parce qu'un écran de ce dépôt
// cochait « fourni ✓ » AVANT l'appel réseau, puis avalait l'échec dans
// Crashlytics : l'étudiant voyait un document envoyé que le conseiller n'avait
// jamais reçu. La vitrine « Études en France » pose exactement le même risque —
// un « c'est noté » pour une ligne qui n'existe nulle part — et ces tests sont
// la contre-épreuve.

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:karatou/app/core/repositories/app_api_client.dart';
import 'package:karatou/app/features/etudes_en_france/eef_interest_controller.dart';

class _MockApiClient extends Mock implements AppApiClient {}

DioException _dio({int? status, DioExceptionType? type}) => DioException(
      requestOptions: RequestOptions(path: '/etudes-en-france/interest'),
      type: type ?? DioExceptionType.badResponse,
      response: status == null
          ? null
          : Response<dynamic>(
              requestOptions:
                  RequestOptions(path: '/etudes-en-france/interest'),
              statusCode: status,
            ),
    );

const _declaredBody = <String, dynamic>{
  'declared': true,
  'currentLevel': 'terminale',
  'targetLevel': 'licence',
  'fieldIds': ['info', 'sante'],
  'wantsPremium': true,
  'consentedAt': '2026-08-21T10:00:00.000Z',
};

void main() {
  late _MockApiClient api;
  late EefInterestController controller;

  setUpAll(() {
    registerFallbackValue(<String>[]);
  });

  setUp(() {
    api = _MockApiClient();
    controller = EefInterestController(apiClient: api);
  });

  tearDown(() => controller.dispose());

  group('submit — le chemin nominal', () {
    test('ne marque « déclaré » qu\'après confirmation du serveur', () async {
      when(() => api.declareEefInterest(
            currentLevel: any(named: 'currentLevel'),
            targetLevel: any(named: 'targetLevel'),
            fieldIds: any(named: 'fieldIds'),
            wantsPremium: any(named: 'wantsPremium'),
          )).thenAnswer((_) async => _declaredBody);

      expect(controller.declared, isFalse);

      final ok = await controller.submit(wantsPremium: true);

      expect(ok, isTrue);
      expect(controller.declared, isTrue);
      expect(controller.phase, EefInterestPhase.ready);
      expect(controller.failure, isNull);
      expect(controller.interest.wantsPremium, isTrue);
      expect(controller.interest.fieldIds, ['info', 'sante']);
    });
  });

  group('submit — les échecs', () {
    // LE cas limite qui a produit le défaut d'origine : le transport réussit,
    // l'enregistrement non. Un 200 n'est pas une preuve d'écriture.
    test('une réponse 2xx sans « declared: true » est un ÉCHEC', () async {
      when(() => api.declareEefInterest(
            currentLevel: any(named: 'currentLevel'),
            targetLevel: any(named: 'targetLevel'),
            fieldIds: any(named: 'fieldIds'),
            wantsPremium: any(named: 'wantsPremium'),
          )).thenAnswer((_) async => <String, dynamic>{'declared': false});

      final ok = await controller.submit();

      expect(ok, isFalse);
      expect(controller.declared, isFalse);
      expect(controller.phase, EefInterestPhase.failed);
      expect(controller.failure, EefInterestFailure.server);
    });

    test('un corps vide est un échec, pas un succès silencieux', () async {
      when(() => api.declareEefInterest(
            currentLevel: any(named: 'currentLevel'),
            targetLevel: any(named: 'targetLevel'),
            fieldIds: any(named: 'fieldIds'),
            wantsPremium: any(named: 'wantsPremium'),
          )).thenAnswer((_) async => <String, dynamic>{});

      expect(await controller.submit(), isFalse);
      expect(controller.declared, isFalse);
    });

    test('une exception réseau laisse « pas déclaré »', () async {
      when(() => api.declareEefInterest(
            currentLevel: any(named: 'currentLevel'),
            targetLevel: any(named: 'targetLevel'),
            fieldIds: any(named: 'fieldIds'),
            wantsPremium: any(named: 'wantsPremium'),
          )).thenThrow(_dio(type: DioExceptionType.connectionError));

      expect(await controller.submit(), isFalse);
      expect(controller.declared, isFalse);
      expect(controller.failure, EefInterestFailure.network);
    });

    // Une déclaration ANTÉRIEURE réussie ne doit pas être effacée par un échec
    // de modification : l'étudiant a bien déclaré son intérêt, et le lui retirer
    // parce qu'une correction a échoué serait une seconde information fausse.
    test('un échec de MODIFICATION ne détruit pas la déclaration acquise',
        () async {
      when(() => api.declareEefInterest(
            currentLevel: any(named: 'currentLevel'),
            targetLevel: any(named: 'targetLevel'),
            fieldIds: any(named: 'fieldIds'),
            wantsPremium: any(named: 'wantsPremium'),
          )).thenAnswer((_) async => _declaredBody);
      await controller.submit(wantsPremium: true);
      expect(controller.declared, isTrue);

      when(() => api.declareEefInterest(
            currentLevel: any(named: 'currentLevel'),
            targetLevel: any(named: 'targetLevel'),
            fieldIds: any(named: 'fieldIds'),
            wantsPremium: any(named: 'wantsPremium'),
          )).thenThrow(_dio(status: 500));

      expect(await controller.submit(wantsPremium: false), isFalse);
      expect(controller.declared, isTrue, reason: 'la déclaration reste');
      expect(controller.failure, EefInterestFailure.server);
    });
  });

  group('load', () {
    test('lit une déclaration existante', () async {
      when(api.getEefInterest).thenAnswer((_) async => _declaredBody);

      await controller.load();

      expect(controller.declared, isTrue);
      expect(controller.interest.currentLevel, 'terminale');
      expect(controller.phase, EefInterestPhase.ready);
    });

    // Un échec de LECTURE n'est pas un échec d'envoi : au pire on repose la
    // question. Il ne doit surtout pas afficher une erreur d'envoi.
    test('un échec de lecture retombe sur « pas déclaré », sans erreur',
        () async {
      when(api.getEefInterest).thenThrow(_dio(status: 500));

      await controller.load();

      expect(controller.declared, isFalse);
      expect(controller.phase, EefInterestPhase.ready);
      expect(controller.failure, isNull);
    });
  });

  group('classifyFailure', () {
    test('401 et 403 demandent de se reconnecter', () {
      expect(EefInterestController.classifyFailure(_dio(status: 401)),
          EefInterestFailure.unauthorized);
      expect(EefInterestController.classifyFailure(_dio(status: 403)),
          EefInterestFailure.unauthorized);
    });

    test('les autres codes d\'erreur sont serveur', () {
      for (final status in [400, 422, 500, 503]) {
        expect(EefInterestController.classifyFailure(_dio(status: status)),
            EefInterestFailure.server);
      }
    });

    test('les pannes de transport sont réseau', () {
      for (final type in [
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
        DioExceptionType.connectionError,
      ]) {
        expect(EefInterestController.classifyFailure(_dio(type: type)),
            EefInterestFailure.network);
      }
    });

    test('une erreur non-Dio est serveur, jamais réseau', () {
      expect(EefInterestController.classifyFailure(StateError('boom')),
          EefInterestFailure.server);
    });
  });
}
