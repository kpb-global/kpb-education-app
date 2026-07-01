/// Flight price models for the Kayak-backed estimator.
///
/// These mirror the flat contract our NestJS backend exposes at
/// `/api/flights/routes` and `/api/flights/calendar` (which proxies Kayak's
/// Price-Insights API). The app never talks to Kayak directly.
library;

/// Cheapest-price search response for a single route/date.
class FlightRoutesResponse {
  const FlightRoutesResponse({
    required this.configured,
    required this.cached,
    required this.currency,
    required this.results,
  });

  /// False when the backend has no Kayak credentials configured; the UI then
  /// falls back to the external Kayak browser link.
  final bool configured;
  final bool cached;
  final String currency;
  final List<FlightRouteResult> results;

  factory FlightRoutesResponse.fromJson(Map<String, dynamic> json) {
    return FlightRoutesResponse(
      configured: json['configured'] as bool? ?? false,
      cached: json['cached'] as bool? ?? false,
      currency: json['currency'] as String? ?? 'EUR',
      results: (json['results'] as List<dynamic>? ?? <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(FlightRouteResult.fromJson)
          .toList(),
    );
  }

  static const empty = FlightRoutesResponse(
    configured: false,
    cached: false,
    currency: 'EUR',
    results: [],
  );
}

class FlightRouteResult {
  const FlightRouteResult({
    required this.origin,
    required this.destination,
    required this.airlineCodes,
    required this.airlineNames,
    required this.stops,
    required this.roundTrip,
    required this.price,
    this.departureDateTime,
    this.arrivalDateTime,
    this.deeplinkUrl,
    this.cabin,
  });

  final String origin;
  final String destination;
  final List<String> airlineCodes;
  final List<String> airlineNames;
  final int stops;
  final bool roundTrip;
  final double price;
  final DateTime? departureDateTime;
  final DateTime? arrivalDateTime;
  final String? deeplinkUrl;
  final String? cabin;

  /// Human label for the operating airline(s): the resolved names when present,
  /// falling back to codes, and "+N" when several carriers are involved.
  String get airlineLabel {
    final names = airlineNames.isNotEmpty ? airlineNames : airlineCodes;
    if (names.isEmpty) return '';
    if (names.length == 1) return names.first;
    return '${names.first} +${names.length - 1}';
  }

  factory FlightRouteResult.fromJson(Map<String, dynamic> json) {
    return FlightRouteResult(
      origin: json['origin'] as String? ?? '',
      destination: json['destination'] as String? ?? '',
      airlineCodes: (json['airlineCodes'] as List<dynamic>? ?? <dynamic>[])
          .map((e) => e.toString())
          .toList(),
      airlineNames: (json['airlineNames'] as List<dynamic>? ?? <dynamic>[])
          .map((e) => e.toString())
          .toList(),
      stops: (json['stops'] as num?)?.toInt() ?? 0,
      roundTrip: json['roundTrip'] as bool? ?? false,
      price: (json['price'] as num?)?.toDouble() ?? 0,
      departureDateTime: _parseDate(json['departureDateTime']),
      arrivalDateTime: _parseDate(json['arrivalDateTime']),
      deeplinkUrl: json['deeplinkUrl'] as String?,
      cabin: json['cabin'] as String?,
    );
  }
}

/// Price-per-day (or per-month) calendar response.
class FlightCalendarResponse {
  const FlightCalendarResponse({
    required this.configured,
    required this.cached,
    required this.currency,
    required this.aggregation,
    required this.days,
  });

  final bool configured;
  final bool cached;
  final String currency;

  /// `day` or `month`.
  final String aggregation;
  final List<FlightCalendarDay> days;

  factory FlightCalendarResponse.fromJson(Map<String, dynamic> json) {
    return FlightCalendarResponse(
      configured: json['configured'] as bool? ?? false,
      cached: json['cached'] as bool? ?? false,
      currency: json['currency'] as String? ?? 'EUR',
      aggregation: json['aggregation'] as String? ?? 'day',
      days: (json['days'] as List<dynamic>? ?? <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(FlightCalendarDay.fromJson)
          .toList(),
    );
  }

  static const empty = FlightCalendarResponse(
    configured: false,
    cached: false,
    currency: 'EUR',
    aggregation: 'day',
    days: [],
  );
}

class FlightCalendarDay {
  const FlightCalendarDay({
    required this.date,
    required this.price,
    required this.predicted,
    this.deeplinkUrl,
  });

  /// `YYYY-MM-DD` for day aggregation, `YYYY-MM` for month aggregation.
  final String date;
  final double price;

  /// True when the price is an ML prediction rather than a seen fare.
  final bool predicted;
  final String? deeplinkUrl;

  DateTime? get parsedDate => _parseDate(date);

  factory FlightCalendarDay.fromJson(Map<String, dynamic> json) {
    return FlightCalendarDay(
      date: json['date'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0,
      predicted: json['predicted'] as bool? ?? false,
      deeplinkUrl: json['deeplinkUrl'] as String?,
    );
  }
}

DateTime? _parseDate(Object? raw) {
  if (raw is! String || raw.isEmpty) return null;
  return DateTime.tryParse(raw);
}
