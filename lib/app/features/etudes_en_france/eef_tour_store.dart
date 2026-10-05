import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/app_config.dart';

/// Le drapeau « la visite guidée a déjà été montrée », sur cet appareil.
///
/// ## Pourquoi une interface
///
/// Pour la même raison que `EefHelpCard.analytics` : un test doit pouvoir poser
/// le drapeau, le lire, et surtout le faire TOMBER EN PANNE — la règle « une
/// panne du stockage vaut « déjà vue » » ne se prouve pas avec un vrai
/// `SharedPreferences`, qui ne tombe jamais en panne dans un test.
///
/// ## Ce que le drapeau est, et n'est pas
///
/// Un booléen LOCAL, sans rapport avec le compte : rien n'en part vers le serveur,
/// il ne dépend d'aucune mesure ni d'aucun consentement. Il survit à la
/// suppression du compte (ce n'est pas une donnée personnelle) ; la clé est
/// versionnée (`…_v1`) pour qu'une visite refondue puisse rejouer à tout le
/// monde en passant à `_v2`.
abstract interface class EefTourStore {
  /// La visite a-t-elle déjà été montrée ? Peut LEVER une exception : l'appelant
  /// la traite comme « oui » (voir `EefTour.showIfFirstOpen`).
  Future<bool> hasBeenShown();

  /// Note que la visite est montrée. Peut LEVER une exception : l'appelant ne
  /// montre alors pas la visite (elle reviendrait en boucle).
  Future<void> markShown();
}

/// Le drapeau, dans `SharedPreferences`, sous la clé versionnée
/// `kpb_relaunch_v1.eef_tour_v1` (le préfixe est l'espace de noms de stockage de
/// l'app, `AppConfig.storageNamespace`).
class SharedPreferencesEefTourStore implements EefTourStore {
  const SharedPreferencesEefTourStore();

  /// La clé du drapeau. Ne change pas sans raison : la changer REJOUE la visite
  /// à tous ceux qui l'ont déjà vue.
  static const String key = '${AppConfig.storageNamespace}.eef_tour_v1';

  @override
  Future<bool> hasBeenShown() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(key) ?? false;
  }

  @override
  Future<void> markShown() async {
    final prefs = await SharedPreferences.getInstance();
    // `setBool` rend `false` quand l'écriture échoue : c'est une panne, pas un
    // succès silencieux.
    final ok = await prefs.setBool(key, true);
    if (!ok) throw StateError('Le drapeau de la visite n\'a pas été écrit.');
  }
}
