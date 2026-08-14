// « Aucune clé de traduction brute n'est arrivée à l'écran. »
//
// Le mécanisme, prouvé et non supposé : GetX renvoie la chaîne réceptrice telle
// quelle quand la clé est absente du dictionnaire — trois `return this` dans
// `String get tr` (get-4.7.3 internacionalization.dart:88, :111, :113). Un
// `'m6_level_bachelor'.tr` dont la clé n'existe pas s'affiche donc littéralement,
// en snake_case, sur l'écran d'un étudiant. L'app le documente elle-même :
// « GetX echoes the key back when a translation is missing… never show a raw key
// to a student » (lib/app/features/tools/cv_generator_screen.dart:153-155).
//
// POURQUOI L'APPARTENANCE ET PAS UNE EXPRESSION RÉGULIÈRE DE FORME. Le réflexe
// est de rejeter tout texte en `^[a-z0-9]+(_[a-z0-9]+)+$`. Mesuré sur ce dépôt,
// ce réflexe est faux dans les deux sens :
//
//   · AVEUGLE — 36 des 2072 clés ne portent aucun tiret bas (`back`, `search`,
//     `documents`, `save`, `retry`, `upload`…). Une traduction manquante sur
//     l'une d'elles passe inaperçue.
//
//   · CRIE AU LOUP — au moins six endroits affichent LÉGITIMEMENT du snake_case
//     qui n'est pas une clé : le repli assumé sur le statut brut d'un dossier
//     (commercial_surface_screen.dart:1382-1386 et son jumeau
//     parent_surface_screen.dart:1084-1093, tous deux commentés « falls back to
//     the raw value »), `offer.offerType` rendu comme libellé de contexte
//     (explore_screen.dart:1248 → case_detail_screen.dart:821), un nom de
//     fichier sans extension (case_tunnel_flow.dart:579), et les tags libres des
//     récits Parcours (parcours_screen.dart:981, parcours_story_screen.dart:125).
//     Un harnais qui rougit sur ceux-là se fait désarmer par une liste
//     d'exceptions dans la semaine — et une liste d'exceptions, c'est un harnais
//     mort qui reste vert.
//
// L'appartenance au jeu de clés de `AppTranslations` n'a aucun de ces deux
// défauts : les six chaînes ci-dessus ne sont pas des clés, et les 36 clés sans
// tiret bas en sont. Aucune liste d'exceptions à maintenir.
//
// Une propriété mesurée rend la seconde clause sûre : AUCUNE valeur de
// traduction, FR ou EN, ne contient de tiret bas (2072 × 2 valeurs vérifiées).
// Un jeton porteur d'un tiret bas ne peut donc pas être du texte traduit.
//
// La comparaison est SENSIBLE À LA CASSE : 84 valeurs ne diffèrent d'une clé que
// par la casse (`'parent'` → « Parent », `'documents'` → « Documents »,
// `'search'` → « Search »). Une clé recrachée par GetX est toujours la clé
// exacte, en minuscules — la sensibilité à la casse ne coûte donc aucune
// puissance de détection et supprime 84 faux positifs.

// `material.dart` et non `widgets.dart` : `SelectableText` vit dans Material.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:karatou/app/core/translations/app_translations.dart';

/// Toutes les clés déclarées par `AppTranslations`, les deux locales réunies.
///
/// FR et EN sont identiques aujourd'hui (2072 chacune, affirmé par
/// test/core/translations_parity_test.dart), mais prendre l'union ne coûte rien
/// et garde ce garde-fou honnête si elles divergent un jour.
final Set<String> kpbTranslationKeys = {
  for (final block in AppTranslations().keys.values) ...block.keys,
};

/// `true` quand [rendered] est une clé que GetX a recrachée au lieu de traduire.
///
/// Deux clauses :
///   1. la chaîne entière est une clé — la fuite ordinaire, `'ma_cle'.tr` ;
///   2. un jeton séparé par des espaces, PORTANT un tiret bas, est une clé — la
///      fuite noyée dans une phrase, par exemple
///      `'${'commercial_filter_$f'.tr} (${_count(f)})'`
///      (commercial_surface_screen.dart:278), que la clause 1 raterait.
///
/// Angle mort assumé : une clé interpolée sans séparateur d'espace (`'($cle)'`)
/// échappe aux deux clauses. Aucun site de ce genre n'existe dans `lib/`
/// aujourd'hui — le seul cas noyé, celui ci-dessus, est séparé par une espace.
bool looksLikeRawTranslationKey(String rendered) {
  final value = rendered.trim();
  if (value.isEmpty) return false;
  if (kpbTranslationKeys.contains(value)) return true;
  for (final token in value.split(RegExp(r'\s+'))) {
    if (token.contains('_') && kpbTranslationKeys.contains(token)) return true;
  }
  return false;
}

/// Tout ce que l'arbre peint actuellement.
///
/// Trois familles, pas une : `Text.data` (le cas courant), les `TextSpan` d'un
/// `Text.rich`/`RichText` (l'écran de chat et l'onboarding en sont pleins), et
/// les quatre `SelectableText` du dépôt (referral_screen.dart:101 et :219,
/// verified_advisor_sheet.dart:164, motivation_letters_screen.dart:361). N'en
/// regarder qu'une reviendrait à déclarer un écran propre sans avoir lu la moitié
/// de son texte.
Iterable<String> renderedStrings(WidgetTester tester) {
  final out = <String>[];
  void addSpan(InlineSpan? span) {
    span?.visitChildren((InlineSpan child) {
      if (child is TextSpan && child.text != null) out.add(child.text!);
      return true;
    });
  }

  for (final widget in tester.widgetList<Text>(find.byType(Text))) {
    if (widget.data != null) out.add(widget.data!);
    addSpan(widget.textSpan);
  }
  for (final widget
      in tester.widgetList<SelectableText>(find.byType(SelectableText))) {
    if (widget.data != null) out.add(widget.data!);
    addSpan(widget.textSpan);
  }
  for (final widget in tester.widgetList<RichText>(find.byType(RichText))) {
    addSpan(widget.text);
  }
  return out;
}

/// Les clés brutes visibles à l'écran, dédoublonnées et triées.
List<String> rawTranslationKeysOnScreen(WidgetTester tester) =>
    renderedStrings(tester).where(looksLikeRawTranslationKey).toSet().toList()
      ..sort();
