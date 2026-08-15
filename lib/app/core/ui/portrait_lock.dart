import 'package:flutter/services.dart';

/// Portrait uniquement, iPhone et iPad. À appeler AVANT `runApp`.
///
/// Ne retire pas l'iPad du binaire (`TARGETED_DEVICE_FAMILY` reste `1,2`) :
/// retirer une famille d'une app déjà publiée est un refus App Store.
Future<void> lockPortraitOrientation() {
  return SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
  ]);
}
