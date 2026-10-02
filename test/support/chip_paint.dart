// Ce qu'une puce PEINT — pas ce qu'on croit lui avoir demandé.
//
// Le piège que ce fichier existe pour voir : le chipTheme global prévoit un
// libellé blanc sur fond actionPrimary à l'état sélectionné, et il le pose par
// `DefaultTextStyle`. Un `Text(style: …)` explicite, lui, écrase cette couleur.
// L'arbre contient alors le bon texte, le bon thème, la bonne coche — et un
// libellé gris-bleu sur bleu (1,09:1). Lire `DefaultTextStyle.of` ne le voit
// pas : c'est la valeur héritée, pas celle du paragraphe. On lit donc la couleur
// dans le `RichText` que le `Text` a réellement construit, et le fond dans
// l'`Ink` que `RawChip` peint sous le libellé.
//
// Toutes les puces Material (FilterChip, ChoiceChip, InputChip, ActionChip)
// passent par `RawChip` : un seul point de mesure pour toutes.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Seuil WCAG 2.x AA pour du texte courant.
const kChipMinContrast = 4.5;

/// Rapport de contraste WCAG entre deux couleurs OPAQUES.
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

String _hex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

/// Une puce telle qu'elle est peinte.
class PaintedChip {
  const PaintedChip({
    required this.label,
    required this.selected,
    required this.labelColor,
    required this.fill,
  });

  final String label;
  final bool selected;

  /// Couleur EFFECTIVE du libellé, mélangée sur [fill] si elle est translucide.
  final Color labelColor;

  /// Fond effectivement peint, mélangé sur le fond de page s'il est translucide.
  final Color fill;

  double get contrast => contrastRatio(labelColor, fill);

  @override
  String toString() => '« $label » (${selected ? 'sélectionnée' : 'au repos'}) '
      ': libellé ${_hex(labelColor)} sur fond ${_hex(fill)} '
      '= ${contrast.toStringAsFixed(2)}:1';
}

/// Toutes les puces Material sous [within] (ou de tout l'arbre), mesurées.
///
/// Un libellé multiple (rare) est jugé par son PIRE contraste : la puce échoue
/// dès qu'un seul de ses textes est illisible.
List<PaintedChip> paintedChips(WidgetTester tester, {Finder? within}) {
  final chips = within == null
      ? find.byType(RawChip)
      : find.descendant(of: within, matching: find.byType(RawChip));

  final out = <PaintedChip>[];
  for (final element in chips.evaluate()) {
    final chip = element.widget as RawChip;
    final scope = find.byWidget(chip);

    final ink = tester.widget<Ink>(
      find.descendant(of: scope, matching: find.byType(Ink)).first,
    );
    final page = Theme.of(element).scaffoldBackgroundColor;
    final fill = Color.alphaBlend(
      (ink.decoration! as ShapeDecoration).color ?? Colors.transparent,
      page,
    );

    PaintedChip? worst;
    for (final rich in tester
        .widgetList<RichText>(
          find.descendant(of: scope, matching: find.byType(RichText)),
        )
        .toList()) {
      final raw = rich.text.style?.color;
      if (raw == null) continue;
      final painted = PaintedChip(
        label: rich.text.toPlainText(),
        selected: chip.selected,
        labelColor: Color.alphaBlend(raw, fill),
        fill: fill,
      );
      if (worst == null || painted.contrast < worst.contrast) worst = painted;
    }
    if (worst != null) out.add(worst);
  }
  return out;
}

/// Échoue si une puce est sous [min]. [selected] impose le nombre de puces
/// sélectionnées : sans lui, un test qui ne sélectionne rien passerait au vert
/// en ne mesurant que l'état de repos.
void expectChipsReadable(
  WidgetTester tester, {
  required int selected,
  Finder? within,
  double min = kChipMinContrast,
}) {
  final chips = paintedChips(tester, within: within);
  expect(chips, isNotEmpty, reason: 'aucune puce mesurée : test vide');
  expect(
    chips.where((c) => c.selected),
    hasLength(selected),
    reason: 'le nombre de puces sélectionnées ne correspond pas : '
        'l\'état sélectionné n\'a pas été éprouvé',
  );

  final failing = chips.where((c) => c.contrast < min).toList();
  expect(
    failing,
    isEmpty,
    reason: 'Puces sous $min:1 (AA) :\n  ${failing.join('\n  ')}',
  );
}

/// Les libellés de puce COUPÉS par leur contenant : faded/ellipsés, ou au-delà
/// de `maxLines`. Une puce dont le libellé est rogné affiche une information à
/// moitié (« Études de sa… ») — sans lever la moindre exception.
List<String> clippedChipLabels(WidgetTester tester, {Finder? within}) {
  final chips = within == null
      ? find.byType(RawChip)
      : find.descendant(of: within, matching: find.byType(RawChip));
  final out = <String>[];
  for (final chip in chips.evaluate()) {
    final texts = find.descendant(
      of: find.byWidget(chip.widget),
      matching: find.byType(RichText),
    );
    for (final element in texts.evaluate()) {
      final render = element.renderObject;
      if (render is RenderParagraph &&
          (render.didExceedMaxLines || render.debugHasOverflowShader)) {
        out.add(render.text.toPlainText());
      }
    }
  }
  return out;
}
