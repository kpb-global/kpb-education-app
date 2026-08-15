import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Ouvrir un lien externe : on ESSAIE, on ne DEMANDE pas.
///
/// ## Le défaut que ce fichier supprime
///
/// Tout le dépôt écrivait la même chose, à neuf endroits :
///
/// ```dart
/// if (await canLaunchUrl(uri)) {
///   await launchUrl(uri, mode: LaunchMode.externalApplication);
/// }
/// ```
///
/// Deux problèmes, et le second est le grave.
///
/// **`canLaunchUrl` ment sur Android 11+.** Il interroge
/// `PackageManager.resolveActivity`, soumis depuis API 30 à la visibilité des
/// paquets : sans intention `VIEW` déclarée au manifeste, il renvoie faux même
/// avec un navigateur installé. `targetSdkVersion` vaut 36, et le manifeste
/// d'url_launcher_android n'en déclare aucune. Le bloc `<queries>` ajouté à
/// android/app/src/main/AndroidManifest.xml corrige la cause ; ce fichier
/// corrige la conséquence.
///
/// **Et quand il renvoie faux, il ne se passe RIEN.** Pas de message, pas de
/// journal, pas de repli : le `if` est simplement faux et la fonction rend la
/// main. L'utilisateur appuie sur un bouton bleu pleine largeur — « Formulaire
/// officiel », l'action même sans laquelle il rate la bourse — et rien ne bouge.
/// Un bouton silencieux est indiscernable d'une app plantée.
///
/// La forme correcte est celle-ci : tenter le lancement, et traiter l'échec
/// comme un ÉVÉNEMENT que l'appelant doit gérer. C'est aussi la recommandation
/// du paquet lui-même — `canLaunchUrl` n'a jamais garanti que `launchUrl`
/// réussirait.
Future<bool> kpbOpenExternalUrl(Uri uri) async {
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } on PlatformException {
    // Aucune activité pour cette intention, ou le système a refusé.
    return false;
  } catch (_) {
    // `launchUrl` peut aussi lever un ArgumentError sur une URI dégénérée.
    return false;
  }
}

/// Variante commode pour une chaîne brute. Rend `false` sans rien tenter quand
/// la chaîne n'est pas une URL web ouvrable — voir [isOpenableWebUrl].
Future<bool> kpbOpenExternalUrlString(String? raw) async {
  final uri = openableWebUri(raw);
  if (uri == null) return false;
  return kpbOpenExternalUrl(uri);
}

/// L'URI si [raw] est une adresse web réellement ouvrable, sinon `null`.
///
/// La donnée du catalogue n'est pas toujours propre : le champ `applicationUrl`
/// d'une bourse contient parfois `exemple.org/apply`, sans schéma. `Uri.parse`
/// l'accepte volontiers — il y voit un chemin relatif — puis le lancement
/// échoue. Un bouton qui ne peut PAS marcher ne doit pas être affiché : c'est la
/// même règle que celle appliquée à l'écran de mise à jour forcée, où l'action
/// impossible est masquée et non grisée.
Uri? openableWebUri(String? raw) {
  final value = raw?.trim() ?? '';
  if (value.isEmpty) return null;
  final uri = Uri.tryParse(value);
  if (uri == null) return null;
  final scheme = uri.scheme.toLowerCase();
  if (scheme != 'http' && scheme != 'https') return null;
  if (uri.host.trim().isEmpty) return null;
  return uri;
}

/// `true` quand [raw] peut être présenté comme un lien cliquable.
bool isOpenableWebUrl(String? raw) => openableWebUri(raw) != null;
