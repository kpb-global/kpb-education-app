import 'package:flutter_test/flutter_test.dart';

import 'package:karatou/app/core/utils/commons_logo.dart';

void main() {
  group('commonsRasterDisplayUrl', () {
    test('laisse un PNG inchangé', () {
      const png =
          'https://upload.wikimedia.org/wikipedia/commons/6/6d/Logo.png';
      expect(commonsRasterDisplayUrl(png), png);
    });

    const svg =
        'https://upload.wikimedia.org/wikipedia/commons/c/c6/Universit%C3%A4t_Artois_Logo.svg';
    String thumb(int width) =>
        'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c6/Universit%C3%A4t_Artois_Logo.svg/${width}px-Universit%C3%A4t_Artois_Logo.svg.png';

    test(
      'pointe le PNG miniature Commons d’un SVG, à une largeur acceptée',
      () {
        expect(commonsRasterDisplayUrl(svg), thumb(330));
      },
    );

    test('ne demande jamais une largeur que Wikimedia refuse', () {
      // 320 px répondait HTTP 400 : aucun logo ne s’affichait.
      for (final asked in <int>[
        1,
        20,
        200,
        300,
        320,
        330,
        331,
        400,
        640,
        2000,
      ]) {
        final url = commonsRasterDisplayUrl(svg, width: asked)!;
        final served = int.parse(
          RegExp(r'/(\d+)px-').firstMatch(url)!.group(1)!,
        );
        expect(kCommonsStandardThumbWidths, contains(served));
      }
      expect(commonsRasterDisplayUrl(svg, width: 320), thumb(330));
      expect(commonsRasterDisplayUrl(svg, width: 400), thumb(500));
      expect(commonsRasterDisplayUrl(svg, width: 9999), thumb(3840));
    });

    test(
      'ramène une miniature déjà stockée en 320 px à une largeur acceptée',
      () {
        expect(commonsRasterDisplayUrl(thumb(320)), thumb(330));
        expect(commonsRasterDisplayUrl(thumb(200)), thumb(250));
      },
    );

    test(
      'laisse une miniature à une largeur standard exactement telle quelle',
      () {
        for (final width in kCommonsStandardThumbWidths) {
          expect(commonsRasterDisplayUrl(thumb(width)), thumb(width));
        }
      },
    );

    test('ne touche pas une miniature qui n’est pas sur Wikimedia', () {
      const foreign =
          'https://cdn.example.org/wikipedia/commons/thumb/c/c6/Logo.svg/320px-Logo.svg.png';
      expect(commonsRasterDisplayUrl(foreign), foreign);
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

    test(
      'n’exige rien pour le domaine public, CC0, ou l’absence de licence',
      () {
        expect(logoRequiresAttribution('Public domain'), isFalse);
        expect(logoRequiresAttribution('CC0'), isFalse);
        expect(logoRequiresAttribution(null), isFalse);
      },
    );
  });
}
