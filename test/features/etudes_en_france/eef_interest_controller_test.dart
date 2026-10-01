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

  group('consentement — il part, et il est versionné', () {
    test('la déclaration envoie la version du texte affiché', () async {
      when(() => api.declareEefInterest(
            consentVersion: any(named: 'consentVersion'),
            currentLevel: any(named: 'currentLevel'),
            targetLevel: any(named: 'targetLevel'),
            fieldIds: any(named: 'fieldIds'),
            wantsPremium: any(named: 'wantsPremium'),
          )).thenAnswer((_) async => _declaredBody);

      await controller.submit(wantsPremium: true);

      // Sans version, la colonne en base ne désignerait aucun texte et l'on ne
      // pourrait produire qu'une date. `eef_consent_version_test.dart` verrouille
      // l'appariement entre cette constante et le texte réellement affiché.
      verify(() => api.declareEefInterest(
            consentVersion: kEefConsentVersion,
            currentLevel: any(named: 'currentLevel'),
            targetLevel: any(named: 'targetLevel'),
            fieldIds: any(named: 'fieldIds'),
            wantsPremium: any(named: 'wantsPremium'),
          )).called(1);
    });
  });

  group('withdraw — le pendant du consentement', () {
    test('un retrait confirmé remet l\'état à « pas déclaré »', () async {
      when(() => api.withdrawEefInterest())
          .thenAnswer((_) async => <String, dynamic>{'declared': false});

      final ok = await controller.withdraw();

      expect(ok, isTrue);
      expect(controller.declared, isFalse);
      expect(controller.phase, EefInterestPhase.ready);
    });

    test('un corps qui dit encore « déclaré » est un ÉCHEC', () async {
      // Le symétrique exact de la règle de ce fichier. Une réponse 2xx dont le
      // corps affirme que la ligne existe toujours signifie que la suppression
      // n'a pas eu lieu : afficher « tu es retiré » serait le même mensonge que
      // « c'est noté » sur une ligne jamais écrite, dans l'autre sens.
      when(() => api.withdrawEefInterest())
          .thenAnswer((_) async => _declaredBody);

      final ok = await controller.withdraw();

      expect(ok, isFalse);
      expect(controller.phase, EefInterestPhase.failed);
      expect(controller.failure, EefInterestFailure.server);
    });

    test('un échec réseau ne prétend pas avoir retiré', () async {
      when(() => api.withdrawEefInterest())
          .thenThrow(_dio(type: DioExceptionType.connectionError));

      final ok = await controller.withdraw();

      expect(ok, isFalse);
      expect(controller.phase, EefInterestPhase.failed);
      expect(controller.failure, EefInterestFailure.network);
    });

    test('un double tap ne lance pas deux retraits', () async {
      when(() => api.withdrawEefInterest())
          .thenAnswer((_) async => <String, dynamic>{'declared': false});

      // Le premier appel n'est pas attendu : on simule le second tap pendant
      // que le premier vole encore.
      final first = controller.withdraw();
      final second = await controller.withdraw();
      await first;

      expect(second, isFalse);
      verify(() => api.withdrawEefInterest()).called(1);
    });
  });

  group('submit — le chemin nominal', () {
    test('ne marque « déclaré » qu\'après confirmation du serveur', () async {
      when(() => api.declareEefInterest(
            consentVersion: any(named: 'consentVersion'),
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
            consentVersion: any(named: 'consentVersion'),
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
            consentVersion: any(named: 'consentVersion'),
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
            consentVersion: any(named: 'consentVersion'),
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
            consentVersion: any(named: 'consentVersion'),
            currentLevel: any(named: 'currentLevel'),
            targetLevel: any(named: 'targetLevel'),
            fieldIds: any(named: 'fieldIds'),
            wantsPremium: any(named: 'wantsPremium'),
          )).thenAnswer((_) async => _declaredBody);
      await controller.submit(wantsPremium: true);
      expect(controller.declared, isTrue);

      when(() => api.declareEefInterest(
            consentVersion: any(named: 'consentVersion'),
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

    // …mais l'écran DOIT pouvoir le savoir : « pas déclaré » est alors un repli,
    // pas un fait (le hub n'invite pas à redéclarer et ne cache pas « Me retirer »).
    test(
        'un échec de lecture est signalé par readFailed, jusqu\'à la relecture',
        () async {
      when(api.getEefInterest).thenThrow(_dio(status: 500));
      await controller.load();
      expect(controller.readFailed, isTrue);

      when(api.getEefInterest).thenAnswer((_) async => _declaredBody);
      await controller.load();
      expect(controller.readFailed, isFalse);
      expect(controller.declared, isTrue);
    });

    test('une lecture réussie « pas déclaré » n\'est pas un échec', () async {
      when(api.getEefInterest)
          .thenAnswer((_) async => <String, dynamic>{'declared': false});
      await controller.load();
      expect(controller.readFailed, isFalse);
      expect(controller.declared, isFalse);
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

  // EEF-UX-13 — modifier ses niveaux et ses domaines SANS redonner le
  // consentement : c'est PATCH, jamais POST.
  group('updateProfile — PATCH, pas POST', () {
    void stubPatch(Future<Map<String, dynamic>> Function() answer) {
      when(() => api.updateEefProfile(
            currentLevel: any(named: 'currentLevel'),
            targetLevel: any(named: 'targetLevel'),
            fieldIds: any(named: 'fieldIds'),
          )).thenAnswer((_) async => answer());
    }

    test('envoie niveaux et domaines, et ne touche JAMAIS à la déclaration',
        () async {
      stubPatch(() async => <String, dynamic>{
            ..._declaredBody,
            'targetLevel': 'master',
            'fieldIds': ['d07'],
          });

      final ok = await controller.updateProfile(
        targetLevel: 'master',
        fieldIds: ['d07'],
      );

      expect(ok, isTrue);
      expect(controller.interest.targetLevel, 'master');
      expect(controller.interest.fieldIds, ['d07']);
      verify(() => api.updateEefProfile(
            currentLevel: null,
            targetLevel: 'master',
            fieldIds: ['d07'],
          )).called(1);
      // Le consentement n'est PAS redonné : POST n'est jamais appelé.
      verifyNever(() => api.declareEefInterest(
            consentVersion: any(named: 'consentVersion'),
            currentLevel: any(named: 'currentLevel'),
            targetLevel: any(named: 'targetLevel'),
            fieldIds: any(named: 'fieldIds'),
            wantsPremium: any(named: 'wantsPremium'),
          ));
    });

    // Un 200 n'est pas une preuve d'écriture : le corps l'est.
    test('un 2xx qui ne dit pas « declared » est un échec', () async {
      stubPatch(() async => <String, dynamic>{'declared': false});

      final ok = await controller.updateProfile(fieldIds: ['d07']);

      expect(ok, isFalse);
      expect(controller.phase, EefInterestPhase.failed);
      expect(controller.failure, EefInterestFailure.server);
    });

    test('une panne réseau est dite telle, sans toucher à l\'état connu',
        () async {
      // Il y a déjà une déclaration en mémoire.
      when(() => api.getEefInterest()).thenAnswer((_) async => _declaredBody);
      await controller.load();
      expect(controller.declared, isTrue);

      stubPatch(() async => throw _dio(type: DioExceptionType.connectionError));
      final ok = await controller.updateProfile(fieldIds: ['d07']);

      expect(ok, isFalse);
      expect(controller.failure, EefInterestFailure.network);
      // L'échec ne détruit pas ce que l'étudiant avait déclaré.
      expect(controller.declared, isTrue);
      expect(controller.interest.fieldIds, ['info', 'sante']);
    });

    test('404 (pas de déclaration) est une erreur serveur, pas un succès',
        () async {
      stubPatch(() async => throw _dio(status: 404));
      final ok = await controller.updateProfile(fieldIds: ['d07']);
      expect(ok, isFalse);
      expect(controller.declared, isFalse);
    });

    test('ne rejoue pas une mise à jour en cours', () async {
      var calls = 0;
      stubPatch(() async {
        calls += 1;
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return _declaredBody;
      });

      final first = controller.updateProfile(fieldIds: ['d07']);
      final second = await controller.updateProfile(fieldIds: ['d01']);
      await first;

      expect(second, isFalse);
      expect(calls, 1);
    });
  });
}
