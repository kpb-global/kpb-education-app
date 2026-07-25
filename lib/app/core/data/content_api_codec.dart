// ─────────────────────────────────────────────────────────────────────────────
// Server-driven editorial content (KPB-166).
//
// Service offers (WITH their prices) and support destinations were seeded from
// the bundled MockCatalog and never reassigned from the API, so changing a price
// or a support contact required a store release — 7 to 14 days including review
// and adoption. The backend has been serving `/content/service-offers` and
// `/content/support-destinations` all along, and the client even had an unused
// `listContent()` helper: only the wiring was missing.
//
// These codecs are pure and total: a malformed row is DROPPED rather than
// crashing the sync or, worse, rendering a half-empty offer with no price.
// ─────────────────────────────────────────────────────────────────────────────

import '../models/app_models.dart';

/// `{fr, en}` → LocalizedText, tolerating a missing side by falling back to the
/// other (better a single-language label than an empty one).
LocalizedText _localized(Object? raw) {
  if (raw is Map) {
    final fr = (raw['fr'] as String?)?.trim() ?? '';
    final en = (raw['en'] as String?)?.trim() ?? '';
    return LocalizedText(fr: fr.isEmpty ? en : fr, en: en.isEmpty ? fr : en);
  }
  if (raw is String) return LocalizedText(fr: raw, en: raw);
  return const LocalizedText(fr: '', en: '');
}

/// Defensive on purpose: a non-list value (the API sending a bare string, or a
/// field renamed server-side) yields an empty list instead of throwing and
/// taking the whole sync down with it.
List<String> _stringList(Object? raw) => raw is List
    ? raw.whereType<String>().toList(growable: false)
    : const <String>[];

/// The API sends benefits as two parallel arrays (`{fr: [...], en: [...]}`)
/// while the app models one list of localized strings — zip them, using the
/// longer side as the length so nothing is silently truncated.
List<LocalizedText> _localizedList(Object? raw) {
  if (raw is! Map) return const <LocalizedText>[];
  final fr = _stringList(raw['fr']);
  final en = _stringList(raw['en']);
  final count = fr.length > en.length ? fr.length : en.length;
  return List<LocalizedText>.generate(count, (i) {
    final f = i < fr.length ? fr[i] : '';
    final e = i < en.length ? en[i] : '';
    return LocalizedText(fr: f.isEmpty ? e : f, en: e.isEmpty ? f : e);
  }, growable: false);
}

PublicationStatus _status(Object? raw) {
  // Anything that is not a recognised string is a draft — never a crash.
  return switch (raw is String ? raw.trim().toLowerCase() : null) {
    'published' => PublicationStatus.published,
    'archived' => PublicationStatus.archived,
    _ => PublicationStatus.draft,
  };
}

abstract final class ContentApiCodec {
  /// One row → one offer. TOTAL: never throws, so a malformed row cannot break
  /// the sync (which would otherwise retry three times and fall back to cache).
  static ServiceOffer serviceOfferFromApi(Map<String, dynamic> json) {
    return ServiceOffer(
      id: (json['id'] as String?)?.trim() ?? '',
      name: _localized(json['name']),
      offerType: (json['offerType'] as String?) ?? '',
      destinationIds: _stringList(json['destinationIds']),
      studyLevels: _stringList(json['studyLevels']),
      priceLabel: _localized(json['priceLabel']),
      benefits: _localizedList(json['benefits']),
      ctaLabel: _localized(json['ctaLabel']),
      status: _status(json['status']),
    );
  }

  /// `GET /content/service-offers` → offers. Rows without an id are dropped:
  /// an offer we cannot identify is not an offer we should render.
  static List<ServiceOffer> serviceOffersFromApi(List<dynamic> raw) => raw
      .whereType<Map>()
      .map((e) => serviceOfferFromApi(Map<String, dynamic>.from(e)))
      .where((o) => o.id.isNotEmpty)
      .toList(growable: false);

  /// One row → one destination. TOTAL, same rationale as above.
  static SupportDestination supportDestinationFromApi(
    Map<String, dynamic> json,
  ) {
    return SupportDestination(
      id: (json['id'] as String?)?.trim() ?? '',
      countryId: (json['countryId'] as String?) ?? '',
      supportLanguages: _stringList(json['supportLanguages']),
      availableServiceTypes: _stringList(json['availableServiceTypes']),
      // `conditions` is a LIST of localized lines, like `benefits` — the API
      // sends it as two parallel arrays.
      conditions: _localizedList(json['conditions']),
      counselorNames: _stringList(json['counselorNames']),
      isVisible: (json['isVisible'] as bool?) ?? true,
      status: _status(json['status']),
    );
  }

  /// `GET /content/support-destinations` → destinations.
  static List<SupportDestination> supportDestinationsFromApi(
    List<dynamic> raw,
  ) =>
      raw
          .whereType<Map>()
          .map((e) => supportDestinationFromApi(Map<String, dynamic>.from(e)))
          .where((d) => d.id.isNotEmpty)
          .toList(growable: false);
}
