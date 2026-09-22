import 'package:flutter_test/flutter_test.dart';

import 'package:karatou/app/core/utils/commons_logo.dart';

void main() {
  group('commonsRasterDisplayUrl', () {
    test('laisse un PNG inchangé', () {
      const png =
          'https://upload.wikimedia.org/wikipedia/commons/6/6d/Logo.png';
      expect(commonsRasterDisplayUrl(png), png);
    });

    test('pointe le PNG miniature Commons d’un SVG', () {
      expect(
        commonsRasterDisplayUrl(
          'https://upload.wikimedia.org/wikipedia/commons/c/c6/Universit%C3%A4t_Artois_Logo.svg',
        ),
        'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c6/Universit%C3%A4t_Artois_Logo.svg/320px-Universit%C3%A4t_Artois_Logo.svg.png',
      );
    });

    test('rend null pour une URL vide', () {
      expect(commonsRasterDisplayUrl(null), isNull);
      expect(commonsRasterDisplayUrl(''), isNull);
    });
  });

  group('logoRequiresAttribution', () {
    test('exige un crédit pour CC BY et CC BY-SA', () {
      expect(logoRequiresAttribution('CC BY 4.0'), isTrue);
      expect(logoRequiresAttribution('CC BY-SA 3.0'), isTrue);
    });

    test('n’exige rien pour le domaine public, CC0, ou l’absence de licence', () {
      expect(logoRequiresAttribution('Public domain'), isFalse);
      expect(logoRequiresAttribution('CC0'), isFalse);
      expect(logoRequiresAttribution(null), isFalse);
    });
  });
}
