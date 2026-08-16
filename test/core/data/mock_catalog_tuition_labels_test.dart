// TUI-T4 : plus aucun « 9.850 » (point-millier) dans le catalogue de repli.
// `readTuition` refuse ce format ; le laisser dans le mock, c'est servir
// une étiquette illisible dès que le réseau lâche.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final _dotThousands = RegExp(r'[0-9]\.[0-9]{3}');

void main() {
  test('le catalogue de repli n\'écrit plus de point-millier', () {
    final root = Directory('lib/app/core/data/mock_catalog');
    expect(root.existsSync(), isTrue);
    final hits = <String>[];
    for (final file in root.listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      final text = file.readAsStringSync();
      for (final m in _dotThousands.allMatches(text)) {
        hits.add('${file.path}: ${m.group(0)}');
      }
    }
    expect(hits, isEmpty, reason: hits.join('\n'));
  });
}
