import 'package:flutter/foundation.dart';

/// La mention de paternité du catalogue « Études en France », telle que
/// `/config/app` la sert (`eefCatalog`).
///
/// Le catalogue dérive de jeux de données du ministère de l'Enseignement
/// supérieur sous Licence Ouverte 2.0, qui exige de citer le concédant ET la
/// date de dernière mise à jour. Elle est SERVIE et non compilée : la date
/// change à chaque réimport du catalogue, et une mention écrite dans le binaire
/// devient fausse pendant la vie de la build.
///
/// Toute charge incomplète donne `null` — pas une mention à moitié vraie. Un
/// pied d'écran qui nommerait le ministère sans date, ou l'inverse, serait pire
/// que pas de pied du tout : il aurait l'air de tenir l'obligation.
@immutable
class EefCatalogAttribution {
  const EefCatalogAttribution({
    required this.producer,
    required this.licence,
    required this.updatedAt,
    this.sources = const <String>[],
    this.licenceUrl,
    this.producerUrl,
  });

  final String producer;
  final String licence;

  /// Jour nu `AAAA-MM-JJ`, lu tel qu'écrit (voir `EefCampaignWindow`).
  final DateTime updatedAt;

  /// Les jeux de données réutilisés — des noms propres, jamais traduits.
  final List<String> sources;
  final String? licenceUrl;
  final String? producerUrl;

  static EefCatalogAttribution? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final producer = _text(raw['producer']);
    final licence = _text(raw['licence']);
    final updatedAt = _day(raw['updatedAt']);
    if (producer == null || licence == null || updatedAt == null) return null;

    final sources = raw['sources'];
    return EefCatalogAttribution(
      producer: producer,
      licence: licence,
      updatedAt: updatedAt,
      sources: sources is List
          ? sources
              .whereType<String>()
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList(growable: false)
          : const <String>[],
      licenceUrl: _text(raw['licenceUrl']),
      producerUrl: _text(raw['producerUrl']),
    );
  }

  static String? _text(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static DateTime? _day(Object? value) {
    final text = _text(value);
    if (text == null) return null;
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(text);
    if (match == null) return null;
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    final parsed = DateTime(year, month, day);
    // Un 30 février deviendrait le 2 mars : une date que personne n'a écrite.
    if (parsed.year != year || parsed.month != month || parsed.day != day) {
      return null;
    }
    return parsed;
  }
}
