import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../repositories/app_api_client.dart';
import '../utils/app_logger.dart';

/// Une fenêtre de campagne telle que `/config/app` la sert.
///
/// Les deux bornes sont indépendamment nullables : une campagne peut avoir une
/// date d'ouverture annoncée sans date de clôture connue, et l'inverse arrive
/// aussi. Un modèle qui aurait exigé les deux pour être valide aurait forcé
/// l'exploitation à inventer la borne manquante.
@immutable
class EefCampaignWindow {
  const EefCampaignWindow({
    this.opensAt,
    this.closesAt,
    this.suspendedCountries = const <String>[],
  });

  final DateTime? opensAt;
  final DateTime? closesAt;

  /// Pays où la procédure est SUSPENDUE, tels que l'exploitation les a écrits.
  ///
  /// Ce ne sont ni des codes ISO garantis ni des noms garantis : le champ
  /// `countryOfResidence` d'un profil porte un nom français, saisi au clavier
  /// depuis l'écran de profil. La comparaison passe donc par
  /// [isSuspendedForCountry], qui normalise les deux côtés.
  final List<String> suspendedCountries;

  static const empty = EefCampaignWindow();

  bool get hasAnyDate => opensAt != null || closesAt != null;

  /// La procédure est-elle suspendue pour [country] ?
  ///
  /// ## Pourquoi cette comparaison est tolérante, et pourquoi elle doit l'être
  ///
  /// `countryOfResidence` n'est pas un identifiant : l'onboarding le choisit
  /// dans une liste de noms français (« Niger », « Côte d'Ivoire »), mais
  /// l'écran de profil le laisse en TEXTE LIBRE. Une comparaison stricte aurait
  /// donc raté « NIGER », « niger » et « Côte d’Ivoire » écrit avec l'apostrophe
  /// typographique — c'est-à-dire précisément les cas réels.
  ///
  /// On normalise donc les deux côtés : minuscules, accents retirés,
  /// apostrophes unifiées, espaces réduits. L'exploitation peut alors écrire
  /// « Niger » ou « NE » indifféremment.
  ///
  /// **Le sens de l'échec est choisi.** Un pays vide, inconnu ou mal orthographié
  /// rend `false` — donc l'app affiche la date d'ouverture nationale, qui est
  /// exacte pour la plateforme. Le cas inverse (afficher une suspension à qui
  /// n'est pas concerné) découragerait une candidature parfaitement possible.
  bool isSuspendedForCountry(String? country) {
    final needle = normalizeCountry(country);
    if (needle.isEmpty || suspendedCountries.isEmpty) return false;
    return suspendedCountries.any(
      (entry) => normalizeCountry(entry) == needle,
    );
  }

  /// Minuscules, sans accents, apostrophes unifiées, espaces réduits.
  @visibleForTesting
  static String normalizeCountry(String? raw) {
    final trimmed = raw?.trim().toLowerCase() ?? '';
    if (trimmed.isEmpty) return '';

    const accents = 'àáâäãåèéêëìíîïòóôöõùúûüçñ';
    const plain = 'aaaaaaeeeeiiiiooooouuuucn';

    final buffer = StringBuffer();
    for (final rune in trimmed.runes) {
      final char = String.fromCharCode(rune);
      // Les deux apostrophes que produisent les claviers réels.
      if (char == '’' || char == "'") {
        buffer.write("'");
        continue;
      }
      final index = accents.indexOf(char);
      buffer.write(index == -1 ? char : plain[index]);
    }

    return buffer.toString().replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Décode `{ "opensAt": "...", "closesAt": "..." }`.
  ///
  /// Toute valeur illisible devient `null` — jamais une date de repli. Le
  /// serveur envoie déjà `null` pour une variable mal configurée ; ceci est la
  /// bretelle à cette ceinture, pour le cas d'un backend plus ancien ou d'une
  /// charge inattendue.
  factory EefCampaignWindow.fromJson(Object? raw) {
    if (raw is! Map) return empty;
    return EefCampaignWindow(
      opensAt: _parseCampaignDay(raw['opensAt']),
      closesAt: _parseCampaignDay(raw['closesAt']),
      suspendedCountries: _parseStringList(raw['suspendedCountries']),
    );
  }

  static List<String> _parseStringList(Object? value) {
    if (value is! List) return const <String>[];
    return value
        .whereType<String>()
        .map((entry) => entry.trim())
        .where((entry) => entry.isNotEmpty)
        .toList(growable: false);
  }

  /// Le JOUR CALENDAIRE que l'exploitation a écrit, jamais un instant reprojeté.
  ///
  /// ## Pourquoi ce n'est pas `DateTime.tryParse(...).toLocal()`
  ///
  /// Parce que « la campagne ouvre le 1er octobre » est une date d'HORLOGE
  /// MURALE, pas un instant. C'était pourtant un instant, et le reprojeter dans
  /// le fuseau de l'appareil produisait deux mensonges symétriques — le second
  /// bien pire que le premier :
  ///
  /// | Valeur servie | Fuseau du téléphone | Ce qui s'affichait |
  /// |---|---|---|
  /// | `2026-10-01T00:00:00Z` | UTC+0 / +1 (Dakar, Niamey) | 1er octobre ✓ |
  /// | `2026-10-01T00:00:00Z` | UTC−1 / −4 (Cabo Verde, diaspora) | **30 septembre** ✗ |
  /// | `2026-10-01T00:00:00+02:00` (heure de Paris) | UTC+0 / +1 | **30 septembre** ✗ |
  ///
  /// La dernière ligne est celle qui compte : `isoInstant` côté serveur accepte
  /// un décalage explicite, donc un opérateur qui écrit l'heure de Paris — le
  /// réflexe naturel pour une procédure française — ferait lire « 30 septembre »
  /// à **Dakar, Bamako, Abidjan, Niamey et Douala**, c'est-à-dire à l'essentiel
  /// du public. Une seule variable mal saisie, et tout le monde a la mauvaise
  /// date.
  ///
  /// On extrait donc les composantes `AAAA-MM-JJ` **telles qu'écrites**, avant
  /// toute conversion, et on en fait un `DateTime` naïf. Plus de fuseau, donc
  /// plus de décalage possible : la date affichée est celle que l'opérateur a
  /// tapée, sur tous les appareils du monde.
  ///
  /// L'heure du jour est délibérément ignorée. Une échéance administrative se
  /// compte en jours — « à partir du 1er octobre » veut dire « dès le 1er
  /// octobre », pas « à partir de minuit UTC ce jour-là ». Voir
  /// [EefCalendar.phase], qui compare donc des jours et non des instants.
  static DateTime? _parseCampaignDay(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;

    // On valide par le parseur standard — une chaîne illisible doit rester
    // `null`, jamais une date devinée — puis on lit les composantes du TEXTE.
    if (DateTime.tryParse(trimmed) == null) return null;

    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(trimmed);
    if (match == null) return null;

    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);

    // `DateTime` normalise silencieusement un 32 janvier en 1er février. Ce
    // serait une date inventée à partir d'une saisie fautive — exactement ce que
    // ce module refuse de faire — donc on rend `null` et l'app n'annonce rien.
    final parsed = DateTime(year, month, day);
    if (parsed.year != year || parsed.month != month || parsed.day != day) {
      return null;
    }
    return parsed;
  }
}

/// Les drapeaux de fonctionnalité servis par `/config/app`.
///
/// ## Pourquoi ce service existe
///
/// Parce que sans lui, ouvrir l'espace « Études en France » le jour de la
/// campagne exigerait une nouvelle build au store. Une revue App Store prend un
/// à trois jours et peut refuser ; adosser une date de campagne à ce calendrier,
/// c'est parier la campagne sur Apple. Le backend sert déjà des drapeaux pilotés
/// par variables d'environnement — il ne manquait que le côté client pour les
/// lire.
///
/// ## Comment il échoue
///
/// **Fermé, toujours.** Réseau injoignable, charge malformée, backend plus
/// ancien qui ne connaît pas la clé : on retombe sur les constantes de
/// compilation d'[AppConfig], qui valent `false` par défaut. Le raisonnement
/// n'est pas symétrique dans les deux sens : montrer par défaut une vitrine
/// qu'on ne saurait plus éteindre à distance est un mauvais échec, ne rien
/// montrer est un échec réparable.
///
/// ## Ce qu'il ne fait pas
///
/// Il ne bloque pas le démarrage. [refresh] est lancé sans attente au boot, et
/// tant qu'il n'a pas répondu, [eefTeaserEnabled] rend le repli local. Un écran
/// qui dépend d'un drapeau doit donc se reconstruire quand il arrive — d'où
/// [flagsVersion], un compteur qu'un `ValueListenableBuilder` peut écouter.
class RemoteFeatureFlags {
  RemoteFeatureFlags._();

  static final instance = RemoteFeatureFlags._();

  /// Remis à zéro entre les tests.
  @visibleForTesting
  static void resetForTest() {
    instance._features = const <String, bool>{};
    instance._campaign = EefCampaignWindow.empty;
    instance._loaded = false;
    instance.flagsVersion.value = 0;
  }

  Map<String, bool> _features = const <String, bool>{};
  EefCampaignWindow _campaign = EefCampaignWindow.empty;
  bool _loaded = false;

  /// Incrémenté à chaque rafraîchissement réussi. Les écrans qui dépendent d'un
  /// drapeau écoutent ce compteur pour se reconstruire une fois la réponse
  /// arrivée, au lieu de rester sur le repli jusqu'au prochain démarrage.
  final flagsVersion = ValueNotifier<int>(0);

  /// True quand une réponse serveur a été lue avec succès au moins une fois.
  bool get loaded => _loaded;

  /// La fenêtre de campagne servie, ou [EefCampaignWindow.empty].
  EefCampaignWindow get eefCampaign => _campaign;

  /// La vitrine « Études en France » est-elle visible ?
  bool get eefTeaserEnabled => _flag('eefTeaser', AppConfig.eefTeaserEnabled);

  /// L'espace « Études en France » réel est-il ouvert ?
  bool get eefEnabled => _flag('eef', AppConfig.eefEnabled);

  /// La valeur servie, ou le repli de compilation quand elle est absente.
  bool _flag(String key, bool fallback) => _features[key] ?? fallback;

  /// Lit `/config/app` et mémorise les drapeaux. Ne lève jamais.
  Future<void> refresh(AppApiClient apiClient) async {
    try {
      final config = await apiClient.getAppConfig();
      _features = _readFeatures(config['features']);
      _campaign = EefCampaignWindow.fromJson(config['eefCampaign']);
      _loaded = true;
      flagsVersion.value++;
    } catch (error) {
      // Fail closed : on garde les replis de compilation. Volontairement pas
      // remonté à Crashlytics — un téléphone hors réseau n'est pas un incident,
      // et cette route est appelée à chaque démarrage.
      AppLogger.warning(
        'Remote feature flags unavailable: $error',
        tag: 'RemoteFeatureFlags',
      );
    }
  }

  /// Ne retient que les entrées booléennes.
  ///
  /// `features` est une charge que l'app ne contrôle pas : une clé dont la
  /// valeur n'est pas un booléen (un objet `{enabled: true}` d'une version
  /// future, une chaîne « true » d'un mauvais sérialiseur) est IGNORÉE plutôt
  /// que devinée. Une lecture laxiste ici allumerait une fonctionnalité sur la
  /// foi d'une chaîne non vide — c'est-à-dire sur rien.
  static Map<String, bool> _readFeatures(Object? raw) {
    if (raw is! Map) return const <String, bool>{};
    final parsed = <String, bool>{};
    raw.forEach((key, value) {
      if (key is String && value is bool) parsed[key] = value;
    });
    return parsed;
  }
}
