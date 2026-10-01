// MISS-02 — aucune jauge d'admission ne doit afficher un nombre CODÉ EN DUR.
//
// La fiche établissement affichait « 85 % » en vert sur chaque établissement,
// une valeur de maquette (`const score = 85; // Mock score for now`). À côté du
// logo d'une université réelle, elle se lit comme une chance d'admission : une
// information trompeuse, que la fiche boutique s'interdit (aucune promesse
// d'admission, aucun nombre non prouvé).
//
// Ce garde lit les sources : une jauge ou un badge de compatibilité doit être
// alimenté par un calcul, jamais par un littéral.

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
      files.any((f) => f.path.endsWith('admission_meter.dart')),
      isTrue,
    );
  });

  test('aucun AdmissionMeter / MatchBadge ne reçoit un score littéral', () {
    // `score: 85`, `score: 0.85`, ou `score: score` avec `const score = 85`.
    final literal = RegExp(
      r'(AdmissionMeter|MatchBadge)\(\s*score:\s*(?:const\s+)?\d',
      multiLine: true,
    );
    final offenders = <String>[];
    for (final file in files) {
      final text = file.readAsStringSync();
      if (literal.hasMatch(text)) offenders.add(file.path);
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
  test('le motif attrape bien l\'ancienne écriture', () {
    final literal = RegExp(
      r'(AdmissionMeter|MatchBadge)\(\s*score:\s*(?:const\s+)?\d',
    );
    expect(literal.hasMatch('const AdmissionMeter(\n score: 85,'), isTrue);
    expect(literal.hasMatch('AdmissionMeter(score: 85)'), isTrue);
    expect(
      literal.hasMatch('AdmissionMeter(score: controller.institutionMatch(i))'),
      isFalse,
    );
    expect(
        RegExp(r'const\s+score\s*=\s*\d+\s*;')
            .hasMatch('const score = 85; // Mock score for now'),
        isTrue);
  });
}
