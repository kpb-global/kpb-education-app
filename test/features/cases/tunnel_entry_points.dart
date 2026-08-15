// L'inventaire des points d'entrée du tunnel de dossier, mesuré sur le dépôt
// SUIVI PAR GIT — pas sur les brouillons locaux d'une autre session.
//
// Même patron que test/core/no_hardcoded_french_test.dart. Extrait dans un
// fichier à part parce que deux tests s'en servent et qu'une deuxième copie
// serait exactement le défaut que ce lot corrige.

import 'dart:io';

/// Les fichiers autorisés à construire `CaseTunnelFlow(`, et combien de fois.
///
/// MESURÉ le 15/08/2026. Trois constructions pour dix-neuf entrées utilisateur :
/// c'est ce rapport qui rend la garde tenable. Les dix-sept feuilles
/// `CaseComposerSheet(` passent toutes par la deuxième ligne de cette table.
const kDeclaredTunnelHosts = <String, int>{
  'lib/app/features/cases/case_create_screen.dart': 1,
  'lib/app/features/cases/case_composer_sheet.dart': 1,
  'lib/app/features/explore/program_detail_screen.dart': 1,
};

List<String> trackedLibFiles() {
  try {
    final result = Process.runSync('git', ['ls-files', '--', 'lib']);
    if (result.exitCode == 0) {
      return (result.stdout as String)
          .split('\n')
          .where((path) => path.endsWith('.dart'))
          .toList();
    }
  } catch (_) {
    // git absent : repli sur le scan filesystem.
  }
  return Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .map((file) => file.path.replaceAll('\\', '/'))
      .toList();
}

/// Compte les occurrences de [needle] hors lignes de commentaire, par fichier.
Map<String, int> _countAcrossLib(String needle, {String? excludePath}) {
  final counts = <String, int>{};
  for (final relativePath in trackedLibFiles()) {
    if (relativePath == excludePath) continue;
    final file = File(relativePath);
    if (!file.existsSync()) continue;
    for (final line in file.readAsLinesSync()) {
      if (line.trimLeft().startsWith('//')) continue;
      if (line.contains(needle)) {
        counts[relativePath] = (counts[relativePath] ?? 0) + 1;
      }
    }
  }
  return counts;
}

/// Où le tunnel est CONSTRUIT. Le fichier de définition est exclu : sa
/// déclaration `const CaseTunnelFlow({` ne porte pas les parenthèses fermantes,
/// mais son `class CaseTunnelFlow extends…` n'en porte pas non plus — on
/// l'exclut par le chemin pour que le motif reste simple et lisible.
Map<String, int> measuredTunnelConstructionSites() => _countAcrossLib(
      'CaseTunnelFlow(',
      excludePath: 'lib/app/features/cases/case_tunnel_flow.dart',
    );

/// Le nombre de feuilles qui ouvrent le tunnel. Volontairement NON figé.
int measuredComposerSheetSiteCount() => _countAcrossLib(
      'CaseComposerSheet(',
      excludePath: 'lib/app/features/cases/case_composer_sheet.dart',
    ).values.fold<int>(0, (sum, count) => sum + count);
