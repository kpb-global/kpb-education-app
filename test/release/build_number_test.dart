// LIV-T1 / LIV-T2 : un numéro déjà consommé ne reprend pas la place du courant.
//
// Le ledger est la source. Remettre +48 dans pubspec.yaml doit rougir avec
// « 48 consommé sur TestFlight le 12/08/2026 ». +49 est le seul vert.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final _versionLine =
    RegExp(r'^version:\s*\d+\.\d+\.\d+\+(\d+)\s*$', multiLine: true);
final _consumedLine = RegExp(r'^-\s+`(\d+)`\s+—\s+(.+)$', multiLine: true);
final _currentLine = RegExp(r'^-\s+`(\d+)`\s+—\s+', multiLine: true);

void main() {
  final pubspec = File('pubspec.yaml').readAsStringSync();
  final ledger = File('docs/release-ledger.md').readAsStringSync();

  test('pubspec porte le numéro courant, jamais un numéro consommé', () {
    final version = _versionLine.firstMatch(pubspec);
    expect(version, isNotNull, reason: 'pubspec.yaml sans version+build.');
    final build = int.parse(version!.group(1)!);

    final consumedHalf = ledger.split('## Courant').first;
    final consumed = <int, String>{};
    for (final m in _consumedLine.allMatches(consumedHalf)) {
      consumed[int.parse(m.group(1)!)] = m.group(2)!.trim();
    }
    expect(consumed, isNotEmpty, reason: 'Ledger sans numéros consommés.');
    expect(consumed.containsKey(48), isTrue,
        reason: '48 doit rester listé : TestFlight du 12/08/2026.');

    final currentHalf = ledger.split('## Courant').last;
    final current = _currentLine.firstMatch(currentHalf);
    expect(current, isNotNull, reason: 'Ledger sans numéro courant.');
    final currentBuild = int.parse(current!.group(1)!);

    final reason = consumed[build];
    expect(
      reason,
      isNull,
      reason: reason == null ? '' : '$build $reason',
    );
    expect(build, currentBuild,
        reason: 'pubspec +$build mais le ledger dit courant $currentBuild.');
  });
}
