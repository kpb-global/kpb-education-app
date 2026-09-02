// La règle unique de ce fichier : UN ÉCHEC N'EST JAMAIS UN SUCCÈS.
//
// La faute serait ici plus silencieuse qu'ailleurs. Un étudiant persuadé d'être
// sur la liste d'attente attend une notification qui ne viendra jamais, et rien,
// jamais, ne le détrompera — pas de message d'erreur, pas de conseiller qui
// rappelle, pas d'écran qui se contredit. C'est la même famille de défaut que le
// masquage `documentUploadEnabled`, où « fourni ✓ » était coché avant l'appel
// réseau et l'échec disparaissait dans Crashlytics.

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:karatou/app/core/repositories/app_api_client.dart';
import 'package:karatou/app/features/premium/premium_waitlist_controller.dart';

class _MockApiClient extends Mock implements AppApiClient {}

DioException _dio({int? status, DioExceptionType? type}) => DioException(
      requestOptions: RequestOptions(path: '/premium/waitlist'),
      type: type ?? DioExceptionType.badResponse,
      response: status == null
          ? null
          : Response<dynamic>(
              requestOptions: RequestOptions(path: '/premium/waitlist'),
              statusCode: status,
            ),
    );

const _registeredBody = <String, dynamic>{
  'registered': true,
  'registeredAt': '2026-09-03T10:00:00.000Z',
};

void main() {
  late _MockApiClient api;
  late PremiumWaitlistController controller;

  setUp(() {
    api = _MockApiClient();
    controller = PremiumWaitlistController(apiClient: api);
  });

  tearDown(() => controller.dispose());

  group('inscription', () {
    test('envoie la version de consentement, pas seulement un tap', () async {
      when(() => api.joinPremiumWaitlist(
          consentVersion: any(named: 'consentVersion'))).thenAnswer(
        (_) async => _registeredBody,
      );

      await controller.join();

      // Sans version, la preuve en base ne désignerait aucun texte : on saurait
      // QUAND l'étudiant a tapé, jamais à quoi il s'est inscrit.
      verify(() => api.joinPremiumWaitlist(
          consentVersion: kPremiumWaitlistConsentVersion)).called(1);
    });

    test('ne marque « inscrit » que sur confirmation du serveur', () async {
      when(() => api.joinPremiumWaitlist(
              consentVersion: any(named: 'consentVersion')))
          .thenAnswer((_) async => _registeredBody);

      expect(controller.registered, isFalse);
      await expectLater(controller.join(), completion(isTrue));
      expect(controller.registered, isTrue);
      expect(controller.phase, PremiumWaitlistPhase.ready);
    });

    test('un 200 dont le corps ne confirme PAS est un échec', () async {
      // Le cas limite qui compte : le transport a réussi, l'enregistrement non.
      // Un 200 n'est pas une preuve d'écriture — le corps l'est.
      when(() => api.joinPremiumWaitlist(
              consentVersion: any(named: 'consentVersion')))
          .thenAnswer((_) async => <String, dynamic>{'registered': false});

      await expectLater(controller.join(), completion(isFalse));
      expect(controller.registered, isFalse);
      expect(controller.phase, PremiumWaitlistPhase.failed);
      expect(controller.failure, PremiumWaitlistFailure.server);
    });

    test('un corps vide ou illisible ne produit pas un succès', () async {
      when(() => api.joinPremiumWaitlist(
              consentVersion: any(named: 'consentVersion')))
          .thenAnswer((_) async => <String, dynamic>{});

      await expectLater(controller.join(), completion(isFalse));
      expect(controller.registered, isFalse);
    });

    test('une panne réseau laisse « pas inscrit »', () async {
      when(() => api.joinPremiumWaitlist(
              consentVersion: any(named: 'consentVersion')))
          .thenThrow(_dio(type: DioExceptionType.connectionError));

      await expectLater(controller.join(), completion(isFalse));
      expect(controller.registered, isFalse);
      expect(controller.failure, PremiumWaitlistFailure.network);
    });

    test('un second appel pendant l\'envoi ne part pas deux fois', () async {
      // Un double tap sur un réseau lent ne doit pas doubler la requête. Le
      // serveur est idempotent, mais l'écran ne doit pas non plus compter deux
      // fois l'événement analytique qui sert à mesurer la demande.
      when(() => api.joinPremiumWaitlist(
          consentVersion: any(named: 'consentVersion'))).thenAnswer(
        (_) async {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          return _registeredBody;
        },
      );

      final first = controller.join();
      await expectLater(controller.join(), completion(isFalse));
      await first;

      verify(() => api.joinPremiumWaitlist(
          consentVersion: any(named: 'consentVersion'))).called(1);
    });
  });

  group('retrait', () {
    test('ne dit « retiré » que si le serveur le confirme', () async {
      when(() => api.leavePremiumWaitlist())
          .thenAnswer((_) async => <String, dynamic>{'registered': false});

      await expectLater(controller.leave(), completion(isTrue));
      expect(controller.registered, isFalse);
    });

    test('un serveur qui dit encore « inscrit » est un échec', () async {
      // Symétrique de l'inscription : afficher « tu es retiré » sur une ligne
      // toujours en base est le même mensonge, dans l'autre sens.
      when(() => api.leavePremiumWaitlist())
          .thenAnswer((_) async => _registeredBody);

      await expectLater(controller.leave(), completion(isFalse));
      expect(controller.failure, PremiumWaitlistFailure.server);
    });
  });

  group('lecture', () {
    test('un échec de LECTURE retombe sur « pas inscrit », sans erreur',
        () async {
      // Au pire on repropose le bouton à quelqu'un d'inscrit, et un second tap
      // est idempotent. Masquer le bouton sur une lecture ratée perdrait
      // l'inscription pour de bon.
      when(() => api.getPremiumWaitlist()).thenThrow(_dio(status: 500));

      await controller.load();

      expect(controller.registered, isFalse);
      expect(controller.phase, PremiumWaitlistPhase.ready);
      expect(controller.failure, isNull);
    });

    test('relit l\'inscription existante', () async {
      when(() => api.getPremiumWaitlist())
          .thenAnswer((_) async => _registeredBody);

      await controller.load();

      expect(controller.registered, isTrue);
      expect(controller.entry.registeredAt, isNotNull);
    });
  });

  group('classement des échecs', () {
    test('401 et 403 disent « reconnecte-toi »', () {
      for (final status in [401, 403]) {
        expect(
          PremiumWaitlistController.classifyFailure(_dio(status: status)),
          PremiumWaitlistFailure.unauthorized,
        );
      }
    });

    test('les délais et coupures disent « vérifie ta connexion »', () {
      for (final type in [
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
        DioExceptionType.connectionError,
      ]) {
        expect(
          PremiumWaitlistController.classifyFailure(_dio(type: type)),
          PremiumWaitlistFailure.network,
        );
      }
    });

    test('tout le reste retombe sur « réessaie »', () {
      expect(
        PremiumWaitlistController.classifyFailure(Exception('boom')),
        PremiumWaitlistFailure.server,
      );
      expect(
        PremiumWaitlistController.classifyFailure(_dio(status: 500)),
        PremiumWaitlistFailure.server,
      );
    });
  });
}
