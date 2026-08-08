/// Provenance of a catalog payload, as declared by the backend envelope.
///
/// The `/catalog/*` endpoints answer `{ "items": [...], "source": "database" }`.
/// `source: "mock"` means the API could not reach Postgres and fell back to its
/// bundled demo fixtures — rows whose names and ids do not exist anywhere. Such
/// a payload must never be shown as the real catalog nor written to the offline
/// cache: that is exactly how "Bourse McCall MacBain" and "Programme Mastercard
/// Foundation Scholars" reached a production device and stuck there.
///
/// Older backends do not send the field at all. An absent `source` is read as
/// [CatalogDataSource.database], since only the degraded path is ever tagged.
enum CatalogDataSource {
  database,
  mock;

  /// Rows we are willing to display as the real catalog and to cache.
  bool get isTrustworthy => this == CatalogDataSource.database;

  String get wireValue => name;

  static CatalogDataSource parse(Object? raw) {
    final value = raw is String ? raw.trim().toLowerCase() : '';
    if (value.isEmpty) return CatalogDataSource.database;
    return CatalogDataSource.values.firstWhere(
      (candidate) => candidate.name == value,
      // Anything we do not recognise is treated as untrusted on purpose: a
      // future degraded mode ("seed", "fixture", …) must fail closed.
      orElse: () => CatalogDataSource.mock,
    );
  }
}

/// One `/catalog/*` (or `/content/*`) list response: rows plus their origin.
class CatalogListPayload {
  const CatalogListPayload({required this.items, required this.source});

  /// Payload from an endpoint that has no `source` field (editorial content).
  const CatalogListPayload.trusted(this.items)
      : source = CatalogDataSource.database;

  final List<dynamic> items;
  final CatalogDataSource source;

  bool get isTrustworthy => source.isTrustworthy;
}
