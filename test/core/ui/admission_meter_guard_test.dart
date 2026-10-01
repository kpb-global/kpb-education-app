// MISS-02 — aucune jauge ni badge de compatibilité ne doit afficher une valeur
// CODÉE EN DUR.
//
// La fiche établissement affichait « 85 % » en vert sur chaque établissement,
// une valeur de maquette (`const score = 85; // Mock score for now`). À côté du
// logo d'une université réelle, elle se lit comme une chance d'admission : une
// information trompeuse, que la fiche boutique s'interdit (aucune promesse
// d'admission, aucun nombre non prouvé).
//
// Depuis #287, l'app n'affiche plus AUCUN pourcentage : `AdmissionMeter`,
// `MatchBadge` et `MatchScoreBadge` sont supprimés, et le seul signal est un
// palier « match profil » (`ProfileFitBadge`), calculé à partir du profil et
// absent sans profil. Ce garde lit les sources : les anciens composants ne
// reviennent pas, et le palier n'est jamais un littéral.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final files = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  test('la garde lit bien les sources — sinon elle ne prouve rien', () {
    expect(files.length, greaterThan(100));
    expect(
      files.any((f) => f.path.endsWith('profile_fit_badge.dart')),
      isTrue,
    );
  });

  test('les jauges à pourcentage ne reviennent pas', () {
    final widget = RegExp(r'\b(AdmissionMeter|MatchBadge|MatchScoreBadge)\(');
    final offenders = <String>[];
    for (final file in files) {
      if (widget.hasMatch(file.readAsStringSync())) offenders.add(file.path);
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('aucun ProfileFitBadge ne reçoit un palier littéral', () {
    // `ProfileFitBadge(fit: ProfileFit.strong)` afficherait « Très bon match »
    // sur tout : la même faute que le « 85 % ». `ProfileFit.fromZone(…)` est un
    // calcul, pas un littéral.
    final literal = RegExp(
      r'ProfileFitBadge\(\s*fit:\s*(?:const\s+)?ProfileFit\.(?!fromZone\b)\w+\s*[,)]',
      multiLine: true,
    );
    final offenders = <String>[];
    for (final file in files) {
      if (literal.hasMatch(file.readAsStringSync())) offenders.add(file.path);
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('aucune constante de score « mock » ne subsiste dans l\'app', () {
    final mock = RegExp(
      r'const\s+score\s*=\s*\d+\s*;',
      multiLine: true,
    );
    final offenders = <String>[];
    for (final file in files) {
      if (mock.hasMatch(file.readAsStringSync())) offenders.add(file.path);
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  // La contre-épreuve de la garde : sur l'ancien code, elle aurait mordu.
  test('les motifs attrapent bien les anciennes écritures', () {
    final widget = RegExp(r'\b(AdmissionMeter|MatchBadge|MatchScoreBadge)\(');
    expect(widget.hasMatch('const AdmissionMeter(\n score: 85,'), isTrue);
    expect(widget.hasMatch('MatchBadge(score: s)'), isTrue);
    expect(widget.hasMatch('ProfileFitBadge(fit: fit)'), isFalse);

    final literal = RegExp(
      r'ProfileFitBadge\(\s*fit:\s*(?:const\s+)?ProfileFit\.(?!fromZone\b)\w+\s*[,)]',
    );
    expect(literal.hasMatch('ProfileFitBadge(fit: ProfileFit.strong)'), isTrue);
    expect(
      literal.hasMatch('ProfileFitBadge(fit: ProfileFit.good, fontSize: 11)'),
      isTrue,
    );
    expect(
      literal.hasMatch('ProfileFitBadge(fit: ProfileFit.fromZone(match.zone))'),
      isFalse,
    );
    expect(
        literal.hasMatch('ProfileFitBadge(fit: fit!, fontSize: 13)'), isFalse);
    expect(
        RegExp(r'const\s+score\s*=\s*\d+\s*;')
            .hasMatch('const score = 85; // Mock score for now'),
        isTrue);
  });
}
