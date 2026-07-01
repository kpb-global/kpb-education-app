import 'package:flutter_test/flutter_test.dart';
import 'package:karatou/app/features/travel/flight_models.dart';

void main() {
  group('FlightRoutesResponse.fromJson', () {
    test('maps the flat contract, parses types, resolves airline label', () {
      final res = FlightRoutesResponse.fromJson({
        'configured': true,
        'cached': true,
        'currency': 'EUR',
        'results': [
          {
            'origin': 'ABJ',
            'destination': 'CDG',
            'airlineCodes': ['AF', 'KL'],
            'airlineNames': ['Air France', 'KLM'],
            'stops': 1,
            'roundTrip': false,
            'price': 512, // int in JSON -> double
            'departureDateTime': '2025-12-01T12:00:00',
            'arrivalDateTime': '2025-12-01T18:30:00',
            'deeplinkUrl': 'https://www.kayak.com/in?a=kan_1&url=/flights',
            'cabin': 'economy',
          },
        ],
      });

      expect(res.configured, isTrue);
      expect(res.cached, isTrue);
      expect(res.currency, 'EUR');
      expect(res.results, hasLength(1));

      final r = res.results.first;
      expect(r.price, 512.0);
      expect(r.price, isA<double>());
      expect(r.stops, 1);
      expect(r.roundTrip, isFalse);
      expect(r.airlineNames, ['Air France', 'KLM']);
      // Multiple carriers collapse to "first +N".
      expect(r.airlineLabel, 'Air France +1');
      expect(r.departureDateTime, DateTime(2025, 12, 1, 12, 0, 0));
      expect(r.arrivalDateTime, DateTime(2025, 12, 1, 18, 30, 0));
      // Deeplink must survive verbatim (affiliate tracking).
      expect(r.deeplinkUrl, 'https://www.kayak.com/in?a=kan_1&url=/flights');
    });

    test('single airline uses its name; falls back to codes when no names', () {
      final withName = FlightRouteResult.fromJson({
        'airlineCodes': ['AF'],
        'airlineNames': ['Air France'],
        'price': 300,
      });
      expect(withName.airlineLabel, 'Air France');

      final codeOnly = FlightRouteResult.fromJson({
        'airlineCodes': ['AF'],
        'price': 300,
      });
      expect(codeOnly.airlineLabel, 'AF');
    });

    test('missing/empty json yields safe defaults', () {
      final res = FlightRoutesResponse.fromJson({});
      expect(res.configured, isFalse);
      expect(res.currency, 'EUR');
      expect(res.results, isEmpty);
      expect(FlightRoutesResponse.empty.results, isEmpty);
    });
  });

  group('FlightCalendarResponse.fromJson', () {
    test('maps days, parses dates, keeps predicted flag', () {
      final cal = FlightCalendarResponse.fromJson({
        'configured': true,
        'cached': false,
        'currency': 'EUR',
        'aggregation': 'day',
        'days': [
          {
            'date': '2025-12-01',
            'price': 480,
            'predicted': false,
            'deeplinkUrl': 'https://www.kayak.com/in?a=kan_2',
          },
          {
            'date': '2025-12-02',
            'price': 505.5,
            'predicted': true,
            'deeplinkUrl': null,
          },
        ],
      });

      expect(cal.aggregation, 'day');
      expect(cal.days, hasLength(2));
      expect(cal.days.first.price, 480.0);
      expect(cal.days.first.predicted, isFalse);
      expect(cal.days.first.parsedDate, DateTime(2025, 12, 1));
      expect(cal.days[1].predicted, isTrue);
      expect(cal.days[1].deeplinkUrl, isNull);
    });

    test('missing json yields safe defaults', () {
      final cal = FlightCalendarResponse.fromJson({});
      expect(cal.configured, isFalse);
      expect(cal.days, isEmpty);
      expect(FlightCalendarResponse.empty.aggregation, 'day');
    });
  });
}
