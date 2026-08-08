import 'package:flutter_test/flutter_test.dart';
import 'package:karatou/app/features/tools/pdf_text.dart';

/// The exported CV/letter PDFs use the `pdf` package's built-in Helvetica,
/// which can only draw code points U+0000–U+00FF; anything else is painted as
/// an empty box (the ▯ "tofu" students reported). These tests pin the contract
/// the PDF builders rely on: after sanitising, EVERY code point is renderable.
void main() {
  /// Mirrors `PdfType1Font.isRuneSupported` plus the C0/C1 gap that WinAnsi
  /// would otherwise turn into a random punctuation glyph.
  void expectRenderable(String value) {
    for (final rune in value.runes) {
      final printable = (rune >= 0x20 && rune <= 0x7E) ||
          (rune >= 0xA0 && rune <= 0xFF) ||
          rune == 0x0A ||
          rune == 0x09;
      expect(
        printable,
        isTrue,
        reason: 'U+${rune.toRadixString(16).toUpperCase().padLeft(4, '0')} '
            'has no glyph in the built-in PDF font (from "$value")',
      );
    }
  }

  group('pdfSafeText', () {
    test('keeps ASCII and Latin-1 accents untouched', () {
      const input = 'Étudiant motivé, à Ouagadougou «Bac» ç ô °C 20 %';
      final output = pdfSafeText(input);
      expect(output, contains('Étudiant motivé'));
      expect(output, contains('à Ouagadougou'));
      expect(output, contains('«Bac»'));
      expect(output, contains('°C'));
      expectRenderable(output);
    });

    test('folds the em dash that produced "Bachelor ▯ Bac"', () {
      expect(pdfSafeText('Bachelor 3 — Bac+3'), 'Bachelor 3 - Bac+3');
    });

    test('folds typographic punctuation to ASCII', () {
      expect(pdfSafeText('l’essentiel'), "l'essentiel");
      expect(pdfSafeText('“citation”'), '"citation"');
      expect(pdfSafeText('et plus…'), 'et plus...');
      expect(pdfSafeText('2 000 €'), '2 000 EUR');
      expect(pdfSafeText('2023 → 2024'), '2023 -> 2024');
      expect(pdfSafeText('sœur Œuvre'), 'soeur OEuvre');
    });

    test('strips emoji from every documented Unicode range', () {
      const samples = <String, String>{
        'emoticons U+1F600': '\u{1F600}',
        'pictographs U+1F30D': '\u{1F30D}',
        'transport U+1F680': '\u{1F680}',
        'supplemental U+1F91D': '\u{1F91D}',
        'extended-A U+1FA84': '\u{1FA84}',
        'misc symbols U+2600': '☀',
        'dingbats U+2714': '✔',
        'arrows U+2B50': '⭐',
        'enclosed U+1F237': '\u{1F237}',
        'cards U+1F0CF': '\u{1F0CF}',
        'flag (regional indicators)': '\u{1F1E7}\u{1F1EB}',
        'skin tone modifier': '\u{1F44D}\u{1F3FF}',
        'ZWJ family sequence': '\u{1F468}\u200D\u{1F469}\u200D\u{1F467}',
      };
      samples.forEach((label, emoji) {
        final output = pdfSafeText('Master$emoji Physique');
        expect(output, 'Master Physique', reason: 'failed for $label');
        expectRenderable(output);
      });
    });

    test('strips the decoration of a keycap sequence, keeping the digit', () {
      // "1️⃣": digit + variation selector + enclosing keycap.
      expect(pdfSafeText('Étape 1\uFE0F\u20E3 : dossier'), 'Étape 1 : dossier');
    });

    test('collapses the whitespace a removed emoji leaves behind', () {
      expect(pdfSafeText('Motivé \u{1F4AA} , rigoureux'), 'Motivé, rigoureux');
      expect(pdfSafeText('Bachelor  \u{1F393}  Bac'), 'Bachelor Bac');
      expect(pdfSafeText('  \u{1F393}  '), '');
    });

    test('drops control characters, keeps line breaks, tabs become spaces', () {
      // C0 control.
      expect(pdfSafeText('a\u0000b'), 'ab');
      // C1: latin1 byte 0x92 would be drawn as "’" under WinAnsiEncoding.
      expect(pdfSafeText('a\u0092b'), 'ab');
      // Line breaks are structural: one experience bullet per line.
      expect(pdfSafeText('ligne 1\nligne 2'), 'ligne 1\nligne 2');
      expect(pdfSafeText('Excel\tAvancé'), 'Excel Avancé');
    });

    test('preserves French spacing before : ; ! ? and %', () {
      expect(pdfSafeText('Pays cible : France'), 'Pays cible : France');
      expect(
        pdfSafeText('Moyenne : 14 % ; mention bien'),
        'Moyenne : 14 % ; mention bien',
      );
    });

    test('drops scripts the built-in font cannot draw, keeping the base letter',
        () {
      // NFD "é" = "e" + combining acute: the mark has no glyph, and dropping it
      // degrades to "e" rather than to a box.
      expect(pdfSafeText('e\u0301cole'), 'ecole');
      expect(pdfSafeText('Master 日本語'), 'Master');
    });

    test('handles null and empty input', () {
      expect(pdfSafeText(null), '');
      expect(pdfSafeText(''), '');
    });
  });

  group('pdfSafeCsv / pdfSafeLines', () {
    test('drops entries that were emoji-only', () {
      expect(
        pdfSafeCsv('Excel \u{1F4CA}, \u{1F680}, Analyse de données'),
        ['Excel', 'Analyse de données'],
      );
      expect(
        pdfSafeLines(
          'Stage KPB \u{1F393}\n\n\u{1F525}\nBénévolat 2024',
        ),
        ['Stage KPB', 'Bénévolat 2024'],
      );
    });
  });

  group('pdfSafeJoin', () {
    test('never leaves a dangling separator when a part is missing', () {
      expect(
        pdfSafeJoin(['Bachelor 3', 'Informatique']),
        'Bachelor 3 · Informatique',
      );
      expect(pdfSafeJoin(['Bachelor 3', '']), 'Bachelor 3');
      expect(pdfSafeJoin(['', null]), '');
      expect(pdfSafeJoin(['Bachelor 3', '\u{1F393}']), 'Bachelor 3');
    });

    test('uses a separator the PDF font can render', () {
      expectRenderable(pdfSafeJoin(['A', 'B']));
    });
  });
}
