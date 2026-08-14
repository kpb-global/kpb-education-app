// Harnais global des tests widget : charge les polices embarquées (Inter +
// Plus Jakarta Sans) pour que le rendu des textes — goldens comprises — soit
// le vrai rendu de l'app et non Ahem. (Architecture §11.5.)
import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await _loadFont('Inter', [
    'assets/fonts/Inter-Regular.ttf',
    'assets/fonts/Inter-Medium.ttf',
    'assets/fonts/Inter-SemiBold.ttf',
    'assets/fonts/Inter-Bold.ttf',
    'assets/fonts/Inter-ExtraBold.ttf',
  ]);
  await _loadFont('PlusJakartaSans', [
    'assets/fonts/PlusJakartaSans-SemiBold.ttf',
    'assets/fonts/PlusJakartaSans-Bold.ttf',
    'assets/fonts/PlusJakartaSans-ExtraBold.ttf',
  ]);
  await testMain();
}

/// Charge une famille, et REFUSE de continuer si un fichier manque.
///
/// Le `if (!file.existsSync()) continue;` d'origine était muet : renommer
/// `Inter-Regular.ttf` laissait la suite entière au vert, en mesurant Ahem — la
/// police de test dont chaque glyphe est un carré de la taille du cadratin.
/// Toute assertion de largeur, de troncature ou de débordement devenait alors
/// une mesure d'autre chose que l'app, sans un mot.
///
/// Un harnais qui ne peut pas charger la police de l'app doit le dire, et
/// nommer le fichier fautif : c'est la seule information qui fait gagner du
/// temps à 7 h du matin.
Future<void> _loadFont(String family, List<String> assets) async {
  final loader = FontLoader(family);
  final missing = <String>[];
  for (final path in assets) {
    final file = File(path);
    if (!file.existsSync()) {
      missing.add(path);
      continue;
    }
    final bytes = await file.readAsBytes();
    loader.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  if (missing.isNotEmpty) {
    throw StateError(
      'Police « $family » incomplète : ${missing.length} fichier(s) '
      'introuvable(s) depuis ${Directory.current.path} —\n'
      '  ${missing.join('\n  ')}\n'
      "Sans eux, les tests widget mesurent Ahem (glyphes carrés) et non l'app : "
      'largeurs, troncatures et débordements deviennent faux en silence. '
      'Restaurez le(s) fichier(s), ou retirez-les de la liste dans '
      'test/flutter_test_config.dart si la police a réellement changé.',
    );
  }
  await loader.load();
}
