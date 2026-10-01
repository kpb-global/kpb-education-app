import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Annonce la version installée à chaque requête vers l'API KPB.
///
/// ## Pourquoi
///
/// Jusqu'à la build 54, le serveur ne pouvait pas distinguer une build 53 d'une
/// build 54 : aucune requête ne le disait. Toute décision « par version » —
/// montrer les universités de l'espace « Études en France » dans Explorer aux
/// seules builds qui savent les afficher, mesurer qui a mis à jour — était donc
/// impossible, et la seule parade était d'écarter ces lignes pour TOUT LE
/// MONDE. Le serveur n'en a pas besoin le jour du lancement ; il en aura besoin
/// pour la suite, et chaque build publiée sans cet en-tête reste muette pour
/// toujours.
///
/// ## Ce que ça n'est pas
///
/// Ni un identifiant, ni une donnée de profil : la version d'une application
/// publiée est la même pour tous ses utilisateurs. Elle ne sert pas à pister.
///
/// ## Ce que ça ne doit jamais faire
///
/// Casser une requête. La lecture de la version passe par une plateforme (un
/// plugin) qui peut manquer — en test, sur une plateforme non gérée — et un
/// en-tête informatif ne vaut pas une requête perdue : toute erreur de lecture
/// laisse la requête partir SANS l'en-tête. La lecture n'est faite qu'une fois ;
/// un échec est mémorisé aussi, pour ne pas le rejouer à chaque appel.
class AppVersionHeadersInterceptor extends Interceptor {
  AppVersionHeadersInterceptor({Future<PackageInfo> Function()? loader})
      : _loader = loader ?? PackageInfo.fromPlatform;

  static const versionHeader = 'X-KPB-App-Version';
  static const buildHeader = 'X-KPB-App-Build';

  final Future<PackageInfo> Function() _loader;
  Future<Map<String, String>>? _headers;

  Future<Map<String, String>> _load() => _headers ??= () async {
        try {
          final info = await _loader();
          final version = info.version.trim();
          final build = info.buildNumber.trim();
          return <String, String>{
            if (version.isNotEmpty) versionHeader: version,
            if (build.isNotEmpty) buildHeader: build,
          };
        } catch (_) {
          return const <String, String>{};
        }
      }();

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final headers = await _load();
    headers.forEach((name, value) {
      // Un en-tête déjà posé par l'appelant prime : on informe, on n'écrase pas.
      options.headers.putIfAbsent(name, () => value);
    });
    handler.next(options);
  }
}
