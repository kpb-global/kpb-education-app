import 'package:flutter_test/flutter_test.dart';

import 'package:karatou/app/core/config/app_config.dart';
import 'package:karatou/app/core/services/case_socket_service.dart';

void main() {
  group('socketBaseUrl', () {
    test('prod : retire le suffixe /api, pas le « /api » de « //api. »', () {
      // Régression : `replaceFirst('/api', '')` coupait la PREMIÈRE occurrence,
      // celle de « https://api.kpbeducation.cloud », et donnait
      // « https:/.kpbeducation.cloud/api ».
      expect(
        socketBaseUrl('https://api.kpbeducation.cloud/api'),
        'https://api.kpbeducation.cloud',
      );
    });

    test('base locale (le cas qui masquait le défaut en développement)', () {
      expect(
        socketBaseUrl('http://127.0.0.1:4010/api'),
        'http://127.0.0.1:4010',
      );
    });

    test('tolère un « / » final après /api', () {
      expect(
        socketBaseUrl('https://api.kpbeducation.cloud/api/'),
        'https://api.kpbeducation.cloud',
      );
      expect(
        socketBaseUrl('https://api.kpbeducation.cloud/api//'),
        'https://api.kpbeducation.cloud',
      );
    });

    test('ne retire que le suffixe final, jamais un /api au milieu', () {
      expect(
        socketBaseUrl('https://example.test/api/v1/api'),
        'https://example.test/api/v1',
      );
      expect(
        socketBaseUrl('https://example.test/apiary/api'),
        'https://example.test/apiary',
      );
    });

    test('un segment qui commence par « api » sans l’être n’est pas touché',
        () {
      expect(
        socketBaseUrl('https://example.test/api-gateway'),
        'https://example.test/api-gateway',
      );
    });

    test('sans suffixe /api : l’adresse est conservée (sans « / » final)', () {
      expect(
        socketBaseUrl('https://api.kpbeducation.cloud'),
        'https://api.kpbeducation.cloud',
      );
      expect(
        socketBaseUrl('https://api.kpbeducation.cloud/'),
        'https://api.kpbeducation.cloud',
      );
    });

    test('les trois environnements livrés gardent leur hôte et leur schéma',
        () {
      // On mesure les VRAIES valeurs de AppConfig, pas des chaînes recopiées :
      // si une valeur de production change, ce test la voit.
      for (final env in ['dev', 'staging', 'prod']) {
        final api = AppConfig.resolveApiBaseUrl(override: '', env: env);
        final socket = Uri.parse(socketBaseUrl(api));
        final rest = Uri.parse(api);

        expect(socket.scheme, rest.scheme, reason: env);
        expect(socket.host, rest.host, reason: env);
        expect(socket.hasPort, rest.hasPort, reason: env);
        if (rest.hasPort) expect(socket.port, rest.port, reason: env);
        expect(socket.path, isEmpty, reason: env);
      }
    });

    test(
      'adresse finale du namespace : /cases à la racine, jamais sous /api',
      () {
        // Le backend pose `app.setGlobalPrefix('api')`, qui ne vaut que pour
        // les routes HTTP ; le namespace du gateway est `@WebSocketGateway({
        // namespace: '/cases' })`, donc `https://<hôte>/cases`.
        final prod = AppConfig.resolveApiBaseUrl(override: '', env: 'prod');
        expect(
          '${socketBaseUrl(prod)}/cases',
          'https://api.kpbeducation.cloud/cases',
        );
      },
    );
  });
}
