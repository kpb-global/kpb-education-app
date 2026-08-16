// L'identité de l'éditeur — publiée sur QUATRE surfaces, ou sur aucune.
//
// ## Ce que remplace ce fichier
//
// Pendant tout le plan build 49, les politiques disaient littéralement :
// « Les présentes CGU sont soumises au droit applicable à l'entité éditrice,
// dont l'identité juridique n'est pas encore publiée. » Neuf marqueurs
// `TODO(owner-identity)` attendaient une valeur que personne ne connaissait.
// L'utilisateur consentait donc au profit d'une entité qu'il ne pouvait ni
// nommer ni assigner — et les deux stores exigent le contraire.
//
// L'identité est arrivée le 16/08/2026 : **KPB Global L.L.C-FZ**, zone franche
// de Meydan (Dubaï), licence 2537631.01. « KPB Education » en est un SERVICE,
// pas une personne morale : c'est le point que les textes doivent dire, faute
// de quoi la marque et l'éditeur restent deux inconnus l'un pour l'autre.
//
// ## Pourquoi une garde, et pourquoi celle-ci
//
// Quatre copies du même fait vivent dans le dépôt : le bloc `fr`, le bloc `en`,
// `confidentialite.html`, `conditions.html`. Rien n'oblige quatre copies à
// bouger ensemble — c'est exactement le genre de dérive qui produit une page
// web à jour et une app qui ment, ou l'inverse.
//
// Deux précautions de HARNAIS, apprises à nos dépens sur ce dépôt :
//
//   · on lit `AppTranslations().keys['fr']` et `['en']` SÉPARÉMENT, pas le
//     fichier source en vrac. Un `contains` sur le fichier entier serait vert
//     avec le seul bloc français, et l'anglais pourrait pourrir seul ;
//   · on vérifie la valeur de la CLÉ attendue, pas du fichier : une mention
//     de l'entité perdue dans une chaîne marketing ne compte pas pour la
//     section « Responsable du traitement ».

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:karatou/app/core/translations/app_translations.dart';

/// Les faits, tels qu'ils figurent sur la licence Meydan et le certificat de
/// constitution fournis par le propriétaire le 16/08/2026.
const _entity = 'KPB Global L.L.C-FZ';
const _licence = '2537631.01';
const _zone = 'Meydan';
const _street = 'Nad Al Sheba';

/// Ce que chaque surface doit contenir, section par section.
///
/// Les variantes FR/EN d'un même fait sont données en alternative : la garde
/// exige qu'AU MOINS une forme soit présente, pour ne pas imposer une langue à
/// l'autre (« Émirats arabes unis » / « United Arab Emirates »).
const _uae = <String>['Émirats arabes unis', 'United Arab Emirates'];
const _law = <String>['n° 45 de 2021', 'no. 45 of 2021'];
const _authority = <String>['UAE Data Office'];
const _dubai = <String>['Dubaï', 'Dubai'];

void _requireAll(
  String haystack,
  List<String> tokens,
  String where,
  List<String> failures,
) {
  for (final token in tokens) {
    if (!haystack.contains(token)) {
      failures.add('$where : « $token » absent');
    }
  }
}

void _requireOneOf(
  String haystack,
  List<String> alternatives,
  String where,
  List<String> failures,
) {
  if (!alternatives.any(haystack.contains)) {
    failures.add('$where : aucune de ${alternatives.join(" / ")}');
  }
}

/// Fichiers suivis par git qui ne doivent plus porter le trou.
Iterable<File> _publishedSources() sync* {
  for (final root in ['lib', 'web/public', 'docs']) {
    yield* Directory(root).listSync(recursive: true).whereType<File>().where(
        (f) =>
            f.path.endsWith('.dart') ||
            f.path.endsWith('.html') ||
            f.path.endsWith('.md'));
  }
}

void main() {
  final translations = AppTranslations().keys;

  group('la politique de confidentialité nomme le responsable du traitement',
      () {
    for (final locale in ['fr', 'en']) {
      test('bloc $locale — §1', () {
        final body = translations[locale]!['privacy_s1_body'];
        expect(body, isNotNull,
            reason: 'La clé a disparu : la garde ne mesure plus rien.');

        final failures = <String>[];
        final where = 'privacy_s1_body [$locale]';
        _requireAll(
            body!, [_entity, _licence, _zone, _street], where, failures);
        _requireOneOf(body, _uae, where, failures);
        _requireOneOf(body, _law, where, failures);
        _requireOneOf(body, _authority, where, failures);

        expect(
          failures,
          isEmpty,
          reason: 'La section « Responsable du traitement » doit nommer '
              'l\'entité, sa licence, son siège, son pays, la loi applicable '
              'et l\'autorité de recours — sinon l\'utilisateur consent au '
              'profit de personne :\n${failures.join('\n')}',
        );
      });
    }
  });

  group('les CGU nomment la loi et la juridiction', () {
    for (final locale in ['fr', 'en']) {
      test('bloc $locale — §10 et §11', () {
        final governing = translations[locale]!['terms_s10_body'];
        final contact = translations[locale]!['terms_s11_body'];
        expect(governing, isNotNull);
        expect(contact, isNotNull);

        final failures = <String>[];
        _requireAll(
            governing!, [_entity], 'terms_s10_body [$locale]', failures);
        _requireOneOf(governing, _uae, 'terms_s10_body [$locale]', failures);
        _requireOneOf(governing, _dubai, 'terms_s10_body [$locale]', failures);
        _requireAll(contact!, [_entity, _licence], 'terms_s11_body [$locale]',
            failures);

        expect(
          failures,
          isEmpty,
          reason: 'Une CGU sans loi applicable ni for compétent ne peut pas '
              'être opposée :\n${failures.join('\n')}',
        );
      });
    }
  });

  group('les pages web publiées disent la même chose', () {
    test('confidentialite.html', () {
      final html = File('web/public/confidentialite.html').readAsStringSync();
      final failures = <String>[];
      _requireAll(html, [_entity, _licence, _zone, _street],
          'confidentialite.html', failures);
      _requireOneOf(html, _uae, 'confidentialite.html', failures);
      _requireOneOf(html, _law, 'confidentialite.html', failures);
      _requireOneOf(html, _authority, 'confidentialite.html', failures);
      expect(failures, isEmpty,
          reason: 'La page web est celle que les stores et les moteurs '
              'lisent ; elle ne peut pas être en retard sur l\'app :\n'
              '${failures.join('\n')}');
    });

    test('conditions.html', () {
      final html = File('web/public/conditions.html').readAsStringSync();
      final failures = <String>[];
      _requireAll(html, [_entity, _licence], 'conditions.html', failures);
      _requireOneOf(html, _uae, 'conditions.html', failures);
      _requireOneOf(html, _dubai, 'conditions.html', failures);
      expect(failures, isEmpty, reason: failures.join('\n'));
    });
  });

  group('le trou ne peut pas revenir', () {
    test('plus un seul TODO(owner-identity) ni de placeholder', () {
      final offenders = <String>[];
      var scanned = 0;
      for (final file in _publishedSources()) {
        // Ce fichier CITE le placeholder dans son en-tête pour expliquer ce
        // qu'il interdit ; s'auto-inspecter le rendrait rouge à jamais.
        if (file.path.endsWith('legal_identity_test.dart')) continue;
        scanned++;
        final text = file.readAsStringSync();
        if (text.contains('TODO(owner-identity)')) {
          offenders.add('${file.path} : marqueur TODO(owner-identity)');
        }
        if (text.contains('identité juridique n\'est pas encore publiée') ||
            text.contains('legal identity is not yet published')) {
          offenders.add('${file.path} : placeholder « identité non publiée »');
        }
      }
      expect(scanned, greaterThan(100),
          reason: 'Le balayage ne lit plus le dépôt : garde morte.');
      expect(
        offenders,
        isEmpty,
        reason: 'L\'identité est connue depuis le 16/08/2026 — aucune surface '
            'ne doit plus dire qu\'elle manque :\n${offenders.join('\n')}',
      );
    });
  });
}
