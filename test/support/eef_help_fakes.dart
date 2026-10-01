// Les deux couplages de test de la carte d'aide « Études en France », partagés
// par le test de la carte, du hub et du catalogue.
//
//  · le lanceur d'URL est intercepté à `UrlLauncherPlatform`, la couture
//    officielle du plugin (même technique que force_update_screen_test.dart) :
//    le code de production n'a pas été modifié pour être testable ;
//  · la mesure passe par `EefHelpCard.analytics`, la couture que la carte expose
//    pour cela.

import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import 'package:karatou/app/features/etudes_en_france/eef_help_card.dart';

/// Enregistre les URL qu'on lui demande d'ouvrir, et prétend toujours réussir.
class RecordingUrlLauncher extends Fake
    with MockPlatformInterfaceMixin
    implements UrlLauncherPlatform {
  final List<String> launched = <String>[];

  @override
  Future<bool> canLaunch(String url) async => true;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launched.add(url);
    return true;
  }

  /// Le texte prérempli du dernier lien WhatsApp ouvert, ou `''`.
  String get lastText => launched.isEmpty
      ? ''
      : Uri.parse(launched.last).queryParameters['text'] ?? '';
}

/// Un événement de la carte d'aide, tel qu'il part vers l'analytique.
class RecordedHelpEvent {
  const RecordedHelpEvent(this.step, this.surface, this.variant);

  final String step;
  final String surface;
  final String variant;

  @override
  String toString() => '$step/$surface/$variant';

  @override
  bool operator ==(Object other) =>
      other is RecordedHelpEvent &&
      other.step == step &&
      other.surface == surface &&
      other.variant == variant;

  @override
  int get hashCode => Object.hash(step, surface, variant);
}

class RecordingHelpAnalytics implements EefHelpAnalytics {
  final List<RecordedHelpEvent> shownCalls = <RecordedHelpEvent>[];
  final List<RecordedHelpEvent> tappedCalls = <RecordedHelpEvent>[];

  /// Les étapes vues, dans l'ordre.
  List<String> get shownSteps => shownCalls.map((e) => e.step).toList();

  @override
  void shown({
    required String step,
    required String surface,
    required String variant,
  }) =>
      shownCalls.add(RecordedHelpEvent(step, surface, variant));

  @override
  void tapped({
    required String step,
    required String surface,
    required String variant,
  }) =>
      tappedCalls.add(RecordedHelpEvent(step, surface, variant));
}

/// Le texte français que le message prérempli doit avoir pour [stepLabel] —
/// ÉCRIT EN DUR, pour qu'un test ne relise pas la clé que le code lit.
String frHelpPrefill(String stepLabel) =>
    "Bonjour KPB Education, je suis dans l'espace Études en France de l'app "
    "(étape : $stepLabel). Pour passer à l'étape supérieure, j'aimerais "
    "démarrer l'étude de mon dossier.";

String frSuspendedHelpPrefill(String stepLabel) =>
    "Bonjour KPB Education, je suis dans l'espace Études en France de l'app "
    "(étape : $stepLabel). La procédure est suspendue dans mon pays : "
    "j'aimerais parler des autres options d'études.";
