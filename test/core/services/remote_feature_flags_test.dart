// RemoteFeatureFlags : il échoue FERMÉ, et il ne devine pas.
//
// C'est ce service qui permet d'ouvrir l'espace « Études en France » le jour de
// la campagne en basculant une variable d'environnement, sans soumission App
// Store. Deux propriétés le rendent utilisable pour ça, et elles sont éprouvées
// ici plutôt que déduites de la lecture.

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:karatou/app/core/config/app_config.dart';
import 'package:karatou/app/core/repositories/app_api_client.dart';
import 'package:karatou/app/core/services/remote_feature_flags.dart';

class _MockApiClient extends Mock implements AppApiClient {}

void main() {
  late _MockApiClient api;

  setUp(() {
    api = _MockApiClient();
    RemoteFeatureFlags.resetForTest();
    AppConfig.eefTeaserEnabledOverride = null;
    AppConfig.eefEnabledOverride = null;
  });

  tearDown(() {
    RemoteFeatureFlags.resetForTest();
    AppConfig.eefTeaserEnabledOverride = null;
    AppConfig.eefEnabledOverride = null;
  });

  final flags = RemoteFeatureFlags.instance;

  group('le repli, quand le serveur ne répond pas', () {
    // La propriété qui compte : un backend injoignable ne doit pas OUVRIR un
    // module. Montrer par défaut une vitrine qu'on ne saurait plus éteindre à
    // distance est un mauvais échec ; ne rien montrer est réparable.
    test('échoue fermé sur les constantes de compilation', () async {
      when(api.getAppConfig).thenThrow(DioException(
        requestOptions: RequestOptions(path: '/config/app'),
        type: DioExceptionType.connectionError,
      ));

      await flags.refresh(api);

      expect(flags.loaded, isFalse);
      expect(flags.eefTeaserEnabled, isFalse);
      expect(flags.eefEnabled, isFalse);
      expect(flags.eefCampaign.hasAnyDate, isFalse);
    });

    test('ne lève jamais vers l\'appelant', () async {
      when(api.getAppConfig).thenThrow(StateError('boom'));
      await expectLater(flags.refresh(api), completes);
    });

    // La contre-épreuve du repli : le drapeau de compilation à VRAI doit bien
    // ouvrir le module quand le serveur est muet. Sans elle, « échoue fermé »
    // serait indistinguable de « ne marche jamais ».
    test('un repli de compilation à vrai ouvre bien le module', () async {
      AppConfig.eefTeaserEnabledOverride = true;
      when(api.getAppConfig).thenThrow(StateError('boom'));

      await flags.refresh(api);

      expect(flags.eefTeaserEnabled, isTrue);
    });
  });

  group('la lecture de la charge', () {
    test('la valeur servie PRIME sur le repli de compilation', () async {
      AppConfig.eefTeaserEnabledOverride = true;
      when(api.getAppConfig).thenAnswer((_) async => <String, dynamic>{
            'features': <String, dynamic>{'eefTeaser': false, 'eef': true},
          });

      await flags.refresh(api);

      expect(flags.eefTeaserEnabled, isFalse);
      expect(flags.eefEnabled, isTrue);
      expect(flags.loaded, isTrue);
    });

    // Une clé non booléenne est IGNORÉE, pas devinée. Une lecture laxiste
    // allumerait une fonctionnalité sur la foi d'une chaîne non vide — c'est-à
    // -dire sur rien.
    test('une valeur non booléenne est ignorée, pas interprétée', () async {
      when(api.getAppConfig).thenAnswer((_) async => <String, dynamic>{
            'features': <String, dynamic>{
              'eefTeaser': 'true',
              'eef': <String, dynamic>{'enabled': true},
            },
          });

      await flags.refresh(api);

      expect(flags.eefTeaserEnabled, isFalse);
      expect(flags.eefEnabled, isFalse);
    });

    test('un bloc features absent ou malformé ne fait pas lever', () async {
      when(api.getAppConfig)
          .thenAnswer((_) async => <String, dynamic>{'features': 'nope'});

      await flags.refresh(api);

      expect(flags.eefTeaserEnabled, isFalse);
      expect(flags.loaded, isTrue);
    });

    test('incrémente flagsVersion pour que les écrans se reconstruisent',
        () async {
      when(api.getAppConfig).thenAnswer((_) async => <String, dynamic>{
            'features': <String, dynamic>{'eefTeaser': true},
          });

      expect(flags.flagsVersion.value, 0);
      await flags.refresh(api);
      expect(flags.flagsVersion.value, 1);
    });
  });

  group('la fenêtre de campagne', () {
    test('décode deux instants ISO', () async {
      when(api.getAppConfig).thenAnswer((_) async => <String, dynamic>{
            'eefCampaign': <String, dynamic>{
              'opensAt': '2026-08-26T00:00:00.000Z',
              'closesAt': '2026-12-15T23:59:00.000Z',
            },
          });

      await flags.refresh(api);

      expect(flags.eefCampaign.opensAt, isNotNull);
      expect(flags.eefCampaign.closesAt, isNotNull);
      expect(flags.eefCampaign.opensAt!.toUtc().month, 8);
    });

    // Aucune date de repli : une échéance inventée est indistinguable d'une
    // information pour qui la lit.
    test('une date illisible devient null, jamais une date de repli', () async {
      when(api.getAppConfig).thenAnswer((_) async => <String, dynamic>{
            'eefCampaign': <String, dynamic>{
              'opensAt': 'pas-une-date',
              'closesAt': '',
            },
          });

      await flags.refresh(api);

      expect(flags.eefCampaign.opensAt, isNull);
      expect(flags.eefCampaign.closesAt, isNull);
      expect(flags.eefCampaign.hasAnyDate, isFalse);
    });

    test('null explicite du serveur est accepté sans lever', () async {
      when(api.getAppConfig).thenAnswer((_) async => <String, dynamic>{
            'eefCampaign': <String, dynamic>{
              'opensAt': null,
              'closesAt': null,
            },
          });

      await flags.refresh(api);
      expect(flags.eefCampaign.hasAnyDate, isFalse);
    });
  });
}
