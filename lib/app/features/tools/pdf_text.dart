// ─────────────────────────────────────────────────────────────────────────────
// PDF text sanitiser — shared by the student tools that export a PDF.
//
// WHY THIS EXISTS
// The generated documents use the `pdf` package's BUILT-IN Helvetica, a Type1
// font declared with `/Encoding /WinAnsiEncoding`. That font can only render
// code points U+0000–U+00FF (`PdfType1Font.isRuneSupported`). For anything
// above that range the package does not throw: it draws an empty rectangle
// placeholder — the "tofu" ▯ students reported ("Bachelor ▯ Bac").
//
// The tofu was NOT limited to emoji: the em dash (U+2014), curly quotes
// (U+2018/2019/201C/201D), the ellipsis (U+2026), the euro sign (U+20AC) and
// the French ligature œ (U+0153) are all above U+00FF too, and all came out as
// boxes. Accented Latin-1 letters (é, è, à, ç, ô, «, », °…) DO render, because
// bytes 0xA0–0xFF are identical in Latin-1 and WinAnsi — so we keep them.
//
// WHY WE STRIP INSTEAD OF EMBEDDING AN EMOJI FONT
// A colour emoji TTF weighs several megabytes. Our audience downloads and
// updates the app on modest phones and metered mobile data in West/Central
// Africa, so app weight wins over decorative glyphs: we fold what has a sane
// ASCII/Latin-1 equivalent and drop the rest.
//
// EMOJI COVERAGE
// Every emoji code point is above U+00FF, so the catch-all drop below removes
// all of them by construction — no hand-picked character list to keep in sync.
// Concretely that covers at least:
//   U+1F300–U+1F5FF  Misc symbols & pictographs   U+1F600–U+1F64F  Emoticons
//   U+1F680–U+1F6FF  Transport & map              U+1F700–U+1F77F  Alchemical
//   U+1F780–U+1F7FF  Geometric shapes ext.        U+1F800–U+1F8FF  Arrows-C
//   U+1F900–U+1F9FF  Supplemental pictographs     U+1FA70–U+1FAFF  Ext-A
//   U+1F000–U+1F0FF  Mahjong/domino/cards         U+1F200–U+1F2FF  Enclosed
//   U+1F1E6–U+1F1FF  Regional indicators (flags)  U+1F3FB–U+1F3FF  Skin tones
//   U+2600–U+26FF    Misc symbols                 U+2700–U+27BF    Dingbats
//   U+2B00–U+2BFF    Arrows & misc symbols        U+FE00–U+FE0F    Var. sel.
//   U+200D           ZWJ (emoji sequences)        U+20E3           Keycap
//
// Sanitise as late as possible on the way OUT (at PDF build time) so the
// on-screen preview, the profile and the API payloads keep the user's exact
// text; only the document that cannot draw those glyphs is cleaned.
// ─────────────────────────────────────────────────────────────────────────────

/// Separator that is safe in a PDF (U+00B7 exists in WinAnsi, unlike the em
/// dash U+2014 that used to render as ▯).
const String pdfSeparator = ' · ';

/// Code points above U+00FF that carry meaning worth preserving, mapped to a
/// WinAnsi-renderable equivalent. Anything above U+00FF that is NOT in this
/// table is dropped.
const Map<int, String> _foldings = <int, String>{
  // Dashes and hyphens (U+2010–U+2015, U+2212 minus, U+2043 hyphen bullet).
  0x2010: '-', 0x2011: '-', 0x2012: '-', 0x2013: '-', 0x2014: '-',
  0x2015: '-', 0x2212: '-', 0x2043: '-',
  // Single quotes / primes / modifier apostrophe.
  0x2018: "'", 0x2019: "'", 0x201A: "'", 0x201B: "'", 0x2032: "'",
  0x2039: "'", 0x203A: "'", 0x02BC: "'",
  // Double quotes.
  0x201C: '"', 0x201D: '"', 0x201E: '"', 0x201F: '"', 0x2033: '"',
  // Ellipsis and bullets.
  0x2026: '...', 0x2022: '-', 0x2023: '-', 0x2219: '-', 0x25AA: '-',
  0x25CF: '-', 0x25E6: '-',
  // Unicode spaces → plain space (U+00A0 is already WinAnsi-safe).
  0x2002: ' ', 0x2003: ' ', 0x2004: ' ', 0x2005: ' ', 0x2006: ' ',
  0x2007: ' ', 0x2008: ' ', 0x2009: ' ', 0x200A: ' ', 0x202F: ' ',
  0x205F: ' ', 0x3000: ' ',
  // Currency and symbols students actually type in a CV.
  0x20AC: 'EUR', 0x2122: '(TM)', 0x2116: 'No', 0x2105: 'c/o',
  // Arrows used in "2023 → 2024" style timelines.
  0x2192: '->', 0x27F6: '->', 0x21D2: '=>', 0x2190: '<-', 0x2194: '<->',
  // Maths comparators occasionally typed in a grade line (U+00D7 "×" needs no
  // folding: it is WinAnsi 0xD7).
  0x2264: '<=', 0x2265: '>=', 0x2260: '!=',
  // Latin letters that exist in WinAnsi but NOT in Latin-1, so their code
  // point is above U+00FF and the package cannot draw them.
  0x0152: 'OE', 0x0153: 'oe', 0x0178: 'Y', 0x0160: 'S', 0x0161: 's',
  0x017D: 'Z', 0x017E: 'z', 0x0192: 'f', 0x02C6: '^', 0x02DC: '~',
  // Common Latin Extended-A letters (names, transliterations).
  0x0100: 'A', 0x0101: 'a', 0x0112: 'E', 0x0113: 'e', 0x012A: 'I',
  0x012B: 'i', 0x014C: 'O', 0x014D: 'o', 0x016A: 'U', 0x016B: 'u',
  0x0131: 'i', 0x0130: 'I', 0x015E: 'S', 0x015F: 's', 0x011E: 'G',
  0x011F: 'g', 0x0141: 'L', 0x0142: 'l',
};

/// Returns [input] with every glyph the built-in PDF font cannot draw either
/// folded to a WinAnsi equivalent or removed, then tidied (collapsed spaces,
/// no space left dangling before punctuation).
///
/// Safe to call on anything: translations, catalogue labels, profile fields
/// typed by the student, and AI-generated text.
String pdfSafeText(String? input) {
  final value = input ?? '';
  if (value.isEmpty) return '';

  final out = StringBuffer();
  for (final rune in value.runes) {
    final folded = _foldings[rune];
    if (folded != null) {
      out.write(folded);
      continue;
    }
    // Structural whitespace we keep as-is.
    if (rune == 0x0A || rune == 0x09) {
      out.writeCharCode(rune);
      continue;
    }
    // Printable ASCII, then Latin-1 == WinAnsi for 0xA0–0xFF.
    if ((rune >= 0x20 && rune <= 0x7E) || (rune >= 0xA0 && rune <= 0xFF)) {
      out.writeCharCode(rune);
      continue;
    }
    // Dropped on purpose:
    //  • C0/C1 controls (0x00–0x1F, 0x7F–0x9F) — byte 0x92 would otherwise be
    //    drawn as a random WinAnsi punctuation glyph.
    //  • every remaining code point above U+00FF: emoji and their modifiers,
    //    combining diacritics (U+0300–U+036F, the base letter survives), CJK,
    //    Arabic, Devanagari… none of which has a glyph in Helvetica.
  }
  return _tidy(out.toString());
}

/// Sanitises a comma-separated field (skills, languages) into a clean list.
/// Entries that were emoji-only disappear instead of becoming empty chips.
List<String> pdfSafeCsv(String? input) => pdfSafeText(input)
    .split(',')
    .map((item) => item.trim())
    .where((item) => item.isNotEmpty)
    .toList(growable: false);

/// Sanitises a multi-line field (experience) into a clean list of lines.
List<String> pdfSafeLines(String? input) => pdfSafeText(input)
    .split('\n')
    .map((line) => line.trim())
    .where((line) => line.isNotEmpty)
    .toList(growable: false);

/// Joins the non-empty [parts] with [separator], sanitising each one, so a
/// missing profile value never leaves a dangling separator ("Bachelor 3 · ").
String pdfSafeJoin(
  Iterable<String?> parts, {
  String separator = pdfSeparator,
}) =>
    parts.map(pdfSafeText).where((part) => part.isNotEmpty).join(separator);

final RegExp _horizontalSpace = RegExp(r'[ \t]+');

/// Only the punctuation that takes NO leading space in French. `:` `;` `!` `?`
/// `%` and `»` are deliberately excluded — "Pays cible : France" and "20 %" are
/// correct French typography and must survive sanitising.
final RegExp _spaceBeforePunctuation = RegExp(r' +([,.\)\]])');
final RegExp _spaceAfterOpening = RegExp(r'([\(\[]) +');

/// Collapses the whitespace a removed emoji leaves behind, per line, so
/// "Motivé 💪 , rigoureux" becomes "Motivé, rigoureux" rather than
/// "Motivé , rigoureux".
String _tidy(String value) {
  final lines = value.split('\n').map((line) {
    var cleaned = line.replaceAll(_horizontalSpace, ' ');
    cleaned = cleaned.replaceAllMapped(
      _spaceBeforePunctuation,
      (match) => match.group(1)!,
    );
    cleaned = cleaned.replaceAllMapped(
      _spaceAfterOpening,
      (match) => match.group(1)!,
    );
    return cleaned.trim();
  });
  return lines.join('\n').trim();
}
