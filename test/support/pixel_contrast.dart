// Le contraste MESURÉ SUR LES PIXELS, pas lu dans l'arbre de widgets.
//
// Pourquoi ce n'est pas un `Text.style.color` comparé à un `Material.color` : le
// défaut que ce harnais existe pour attraper — un libellé sélectionné peint en gris
// sur fond bleu, 1,09:1 — NAISSAIT précisément de l'écart entre ce que le code
// déclare et ce que le moteur peint. Un style explicite écrasait la couleur d'état
// du `chipTheme`, donc l'arbre disait « texte gris » d'un côté et « fond bleu » de
// l'autre sans qu'aucun des deux champs lus ne soit faux. Seuls les pixels disent
// ce qu'un étudiant voit.
//
// Principe : on photographie le rectangle d'un `Text`, le fond est la couleur la
// plus fréquente, le texte est le pixel le plus éloigné du fond. À un rapport de
// 3 px par pixel logique, la hampe d'un 14 px gras couvre des pixels entiers : le
// pixel extrême EST la couleur du texte, pas un mélange d'anticrénelage.
//
// Un harnais qui ne sait pas mordre ne prouve rien : `eef_catalog_filters_test`
// le met au défi sur l'ancienne puce (`FilterChip` + `caption`), qu'il doit juger
// illisible.

import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Le rapport de contraste WCAG 2.x entre deux couleurs opaques.
double wcagContrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

class PixelContrast {
  const PixelContrast(this.background, this.foreground);

  /// La couleur dominante du rectangle : le fond.
  final Color background;

  /// Le pixel le plus éloigné du fond : le texte.
  final Color foreground;

  double get ratio => wcagContrast(background, foreground);

  @override
  String toString() => 'fond ${_hex(background)} / texte ${_hex(foreground)} → '
      '${ratio.toStringAsFixed(2)}:1';

  static String _hex(Color c) {
    String two(double channel) =>
        (channel * 255).round().toRadixString(16).padLeft(2, '0');
    return '#${two(c.r)}${two(c.g)}${two(c.b)}'.toUpperCase();
  }
}

/// `true` quand deux couleurs ne diffèrent que de l'arrondi du moteur.
bool sameColor(Color a, Color b, {int tolerance = 2}) {
  int channel(double v) => (v * 255).round();
  return (channel(a.r) - channel(b.r)).abs() <= tolerance &&
      (channel(a.g) - channel(b.g)).abs() <= tolerance &&
      (channel(a.b) - channel(b.b)).abs() <= tolerance;
}

/// Mesure le contraste réellement peint dans le rectangle de [target] (un
/// `Text`, de préférence : un rectangle qui ne contient que du texte et son fond).
Future<PixelContrast> measurePixelContrast(
  WidgetTester tester,
  Finder target, {
  double pixelRatio = 3,
}) async {
  final element = target.evaluate().first;
  final targetBox = element.renderObject! as RenderBox;

  // La frontière de peinture la plus HAUTE au-dessus de la cible, pas la plus
  // proche : une liste enveloppe chacune de ses lignes dans sa propre frontière,
  // et la photo d'une ligne seule n'a pas le fond de la feuille qui la porte
  // (transparent, donc « noir ») — première version de cette mesure, qui jugeait
  // 1,18:1 un texte à 17:1. La plus haute contient le fond de la route entière.
  RenderRepaintBoundary? highest;
  for (RenderObject? node = targetBox.parent;
      node != null;
      node = node.parent) {
    if (node is RenderRepaintBoundary) highest = node;
  }
  if (highest == null) {
    throw StateError('aucune frontière de peinture au-dessus de la cible');
  }
  final boundary = highest;

  final result = await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final size = (image.width, image.height);
    image.dispose();
    return (data!, size);
  });
  final (data, (width, height)) = result!;

  final origin = boundary.localToGlobal(Offset.zero);
  final topLeft = targetBox.localToGlobal(Offset.zero) - origin;
  final left = (topLeft.dx * pixelRatio).floor().clamp(0, width - 1);
  final top = (topLeft.dy * pixelRatio).floor().clamp(0, height - 1);
  final right =
      ((topLeft.dx + targetBox.size.width) * pixelRatio).ceil().clamp(1, width);
  final bottom = ((topLeft.dy + targetBox.size.height) * pixelRatio)
      .ceil()
      .clamp(1, height);

  int pixel(int x, int y) {
    final i = (y * width + x) * 4;
    return (data.getUint8(i + 3) << 24) |
        (data.getUint8(i) << 16) |
        (data.getUint8(i + 1) << 8) |
        data.getUint8(i + 2);
  }

  final histogram = <int, int>{};
  for (var y = top; y < bottom; y++) {
    for (var x = left; x < right; x++) {
      histogram.update(pixel(x, y), (n) => n + 1, ifAbsent: () => 1);
    }
  }
  final background =
      histogram.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  final backgroundColor = Color(background);

  var farthest = background;
  var best = 1.0;
  for (final argb in histogram.keys) {
    final ratio = wcagContrast(backgroundColor, Color(argb));
    if (ratio > best) {
      best = ratio;
      farthest = argb;
    }
  }
  return PixelContrast(backgroundColor, Color(farthest));
}
