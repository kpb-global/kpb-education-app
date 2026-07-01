import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

import '../../core/ui/kpb_components.dart';
import '../../core/controllers/app_controller.dart';
import '../../core/repositories/app_api_client.dart';
import '../../core/utils/user_facing_sync_error.dart';
import 'flight_models.dart';

class Airport {
  const Airport(this.code, this.city, this.country);
  final String code;
  final String city;
  final String country;

  String get displayName => '$city ($code)';
}

const List<Airport> popularAirports = [
  Airport('CDG', 'Paris', 'France'),
  Airport('YUL', 'Montréal', 'Canada'),
  Airport('YYZ', 'Toronto', 'Canada'),
  Airport('JFK', 'New York', 'USA'),
  Airport('BRU', 'Bruxelles', 'Belgique'),
  Airport('CMN', 'Casablanca', 'Maroc'),
  Airport('IST', 'Istanbul', 'Turquie'),
  Airport('LHR', 'Londres', 'Royaume-Uni'),
  Airport('FRA', 'Francfort', 'Allemagne'),
  Airport('MAD', 'Madrid', 'Espagne'),
  Airport('DXB', 'Dubaï', 'EAU'),
  Airport('ABJ', 'Abidjan', 'Côte d\'Ivoire'),
  Airport('DKR', 'Dakar', 'Sénégal'),
  Airport('DLA', 'Douala', 'Cameroun'),
  Airport('LBV', 'Libreville', 'Gabon'),
];

/// Best-effort mapping of a free-text country token (from the user's profile)
/// to a default airport in [popularAirports]. Matches against IATA code, city
/// and country name (case-insensitive substring), so it degrades gracefully.
Airport? _airportForToken(String? token) {
  if (token == null || token.trim().isEmpty) return null;
  final t = token.trim().toLowerCase();
  for (final a in popularAirports) {
    if (t == a.code.toLowerCase() ||
        t.contains(a.country.toLowerCase()) ||
        a.country.toLowerCase().contains(t) ||
        t.contains(a.city.toLowerCase())) {
      return a;
    }
  }
  return null;
}

class FlightEstimatorScreen extends StatefulWidget {
  const FlightEstimatorScreen({super.key});

  @override
  State<FlightEstimatorScreen> createState() => _FlightEstimatorScreenState();
}

class _FlightEstimatorScreenState extends State<FlightEstimatorScreen> {
  final AppController ctrl = Get.find<AppController>();
  final AppApiClient _api = AppApiClient();

  Airport? _origin;
  Airport? _destination;
  DateTime _departureDate = DateTime.now().add(const Duration(days: 30));

  bool _loading = false;
  String? _error;
  bool _searched = false;
  FlightRoutesResponse _routes = FlightRoutesResponse.empty;
  FlightCalendarResponse _calendar = FlightCalendarResponse.empty;

  @override
  void initState() {
    super.initState();
    // Profile-aware defaults: origin from country of residence, destination
    // from the first target country; fall back to Abidjan → Paris.
    final profile = ctrl.profile;
    _origin = _airportForToken(profile?.countryOfResidence) ??
        popularAirports.firstWhere((a) => a.code == 'ABJ',
            orElse: () => popularAirports.last);
    Airport? dest;
    if (profile != null && profile.targetCountryIds.isNotEmpty) {
      dest = _airportForToken(profile.targetCountryIds.first);
    }
    _destination = dest ??
        popularAirports.firstWhere((a) => a.code == 'CDG',
            orElse: () => popularAirports.first);
  }

  String get _dep => DateFormat('yyyy-MM-dd').format(_departureDate);
  String get _month => DateFormat('yyyy-MM').format(_departureDate);

  Future<void> _search() async {
    final origin = _origin;
    final destination = _destination;
    if (origin == null || destination == null) return;
    if (origin.code == destination.code) {
      setState(() {
        _error = 'flight_same_airports'.tr;
        _searched = true;
        _routes = FlightRoutesResponse.empty;
        _calendar = FlightCalendarResponse.empty;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _searched = true;
    });

    final trackId = ctrl.profile?.id;
    try {
      final routesJson = await _api.flightRoutes(
        origin: origin.code,
        destination: destination.code,
        departDate: _dep,
        userTrackId: trackId,
      );
      FlightCalendarResponse calendar = FlightCalendarResponse.empty;
      try {
        final calJson = await _api.flightCalendar(
          origin: origin.code,
          destination: destination.code,
          dateFrom: _month,
          dateTo: _month,
          userTrackId: trackId,
        );
        calendar = FlightCalendarResponse.fromJson(calJson);
      } catch (_) {
        // Calendar is a nice-to-have; ignore its failure and keep route prices.
      }
      if (!mounted) return;
      setState(() {
        _routes = FlightRoutesResponse.fromJson(routesJson);
        _calendar = calendar;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = userFacingSyncError(e, ctrl.localeCode);
        _routes = FlightRoutesResponse.empty;
        _calendar = FlightCalendarResponse.empty;
        _loading = false;
      });
    }
  }

  String _formatPrice(double price, String currency) {
    final symbol = currency == 'EUR'
        ? '€'
        : currency == 'USD'
            ? '\$'
            : '$currency ';
    return NumberFormat.currency(
      locale: ctrl.localeCode,
      symbol: symbol,
      decimalDigits: 0,
    ).format(price);
  }

  Future<void> _open(String? url) async {
    if (url == null || url.isEmpty) {
      await _launchKayakFallback();
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      await _launchKayakFallback();
    }
  }

  /// External browser fallback (used when the API is unconfigured or a result
  /// has no deeplink). Keeps the pre-API behaviour available.
  Future<void> _launchKayakFallback() async {
    if (_origin == null || _destination == null) return;
    final urlStr =
        'https://www.kayak.fr/flights/${_origin!.code}-${_destination!.code}/$_dep?sort=price_a';
    final uri = Uri.parse(urlStr);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      Get.snackbar(
        'error'.tr,
        'flight_launch_failed'.tr,
        backgroundColor: KpbColors.error,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final picked = await showDatePicker(
      context: context,
      initialDate: _departureDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: isDark
              ? ThemeData.dark().copyWith(
                  colorScheme: const ColorScheme.dark(
                    primary: KpbColors.sky,
                    onPrimary: Colors.white,
                    surface: KpbColors.bgDarkCard,
                    onSurface: Colors.white,
                  ),
                )
              : ThemeData.light().copyWith(
                  colorScheme: const ColorScheme.light(
                    primary: KpbColors.blue,
                    onPrimary: Colors.white,
                    surface: Colors.white,
                    onSurface: KpbColors.textPrimary,
                  ),
                ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _departureDate) {
      setState(() => _departureDate = picked);
    }
  }

  Future<void> _showAirportPicker(bool isOrigin) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: context.kpb.pageBg,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(KpbRadius.xl)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 16),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.kpb.gray300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                isOrigin
                    ? 'flight_picker_select_origin'.tr
                    : 'flight_picker_select_destination'.tr,
                style: KpbTextStyles.titleLg
                    .copyWith(color: context.kpb.textPrimary),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(
                      horizontal: KpbSpacing.lg, vertical: KpbSpacing.sm),
                  itemCount: popularAirports.length,
                  separatorBuilder: (_, __) =>
                      Divider(color: context.kpb.gray100, height: 1),
                  itemBuilder: (context, index) {
                    final airport = popularAirports[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: context.kpb.surfaceBg,
                          borderRadius: KpbRadius.mdBr,
                        ),
                        child: Text(
                          airport.code,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isDark ? KpbColors.sky : KpbColors.blue,
                          ),
                        ),
                      ),
                      title: Text(airport.city,
                          style: TextStyle(
                              color: context.kpb.textPrimary,
                              fontWeight: FontWeight.w600)),
                      subtitle: Text(airport.country,
                          style: TextStyle(color: context.kpb.textSecondary)),
                      onTap: () {
                        setState(() {
                          if (isOrigin) {
                            _origin = airport;
                          } else {
                            _destination = airport;
                          }
                        });
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: context.kpb.pageBg,
      appBar: AppBar(
        title: Text('flight_estimator_appbar_title'.tr),
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(KpbSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'prepare_departure'.tr,
              style: KpbTextStyles.headline
                  .copyWith(color: context.kpb.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'travel_intro'.tr,
              style: KpbTextStyles.bodySm
                  .copyWith(color: context.kpb.textSecondary),
            ),
            const SizedBox(height: 32),
            _buildHeroCard(isDark),
            const SizedBox(height: 32),
            _buildFormBox(isDark),
            const SizedBox(height: 24),
            KpbButton(
              text: 'flight_search_prices'.tr,
              onPressed: _loading ? () {} : _search,
              icon: Icons.travel_explore_rounded,
              bgColor: KpbColors.sky,
            ),
            const SizedBox(height: 24),
            _buildResultsSection(isDark),
            const SizedBox(height: 16),
            Text(
              'travel_powered_by'.tr,
              style:
                  KpbTextStyles.caption.copyWith(color: context.kpb.textMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroCard(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: isDark ? KpbColors.heroGradientDark : KpbColors.heroGradient,
        borderRadius: KpbRadius.xlBr,
        boxShadow: KpbShadow.blue,
      ),
      padding: const EdgeInsets.all(KpbSpacing.lg),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildHeroAirport(_origin, CrossAxisAlignment.start),
              Icon(Icons.flight_takeoff_rounded,
                  color: Colors.white.withValues(alpha: 0.8), size: 32),
              _buildHeroAirport(_destination, CrossAxisAlignment.end),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: KpbRadius.pillBr,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.calendar_month_rounded,
                    color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Text(
                  DateFormat('dd MMMM yyyy', ctrl.localeCode)
                      .format(_departureDate),
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormBox(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: context.kpb.cardBg,
        borderRadius: KpbRadius.lgBr,
        border: Border.all(color: context.kpb.gray100),
        boxShadow: KpbShadow.soft,
      ),
      padding: const EdgeInsets.all(KpbSpacing.lg),
      child: Column(
        children: [
          _buildSelectorField(
              'flight_field_departure'.tr,
              _origin?.city ?? 'flight_field_choose'.tr,
              Icons.flight_takeoff_rounded,
              () => _showAirportPicker(true),
              isDark),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(),
          ),
          _buildSelectorField(
              'flight_field_arrival'.tr,
              _destination?.city ?? 'flight_field_choose'.tr,
              Icons.flight_land_rounded,
              () => _showAirportPicker(false),
              isDark),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(),
          ),
          _buildSelectorField(
              'flight_field_date'.tr,
              DateFormat('dd MMM yyyy', ctrl.localeCode).format(_departureDate),
              Icons.event_rounded,
              () => _selectDate(context),
              isDark),
        ],
      ),
    );
  }

  Widget _buildResultsSection(bool isDark) {
    if (_loading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('flight_searching'.tr,
                style: KpbTextStyles.bodySm
                    .copyWith(color: context.kpb.textSecondary)),
          ],
        ),
      );
    }
    if (!_searched) return const SizedBox.shrink();

    // Not configured server-side, or a hard error: fall back to the browser link.
    if (_error != null || !_routes.configured) {
      return _buildFallback(isDark);
    }
    if (_routes.results.isEmpty) {
      return _buildEmpty(isDark);
    }

    final currency = _routes.currency;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text('flight_results_title'.tr,
                style: KpbTextStyles.titleMd
                    .copyWith(color: context.kpb.textPrimary)),
            const Spacer(),
            if (_routes.cached)
              Text('flight_cached_note'.tr,
                  style: KpbTextStyles.caption
                      .copyWith(color: context.kpb.textMuted)),
          ],
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < _routes.results.length && i < 5; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildResultCard(_routes.results[i], currency,
                highlight: i == 0, isDark: isDark),
          ),
        if (_calendar.days.isNotEmpty) ...[
          const SizedBox(height: 8),
          _buildCalendarStrip(currency, isDark),
        ],
        const SizedBox(height: 16),
        KpbButton(
          text: 'flight_view_on_kayak'.tr,
          onPressed: _launchKayakFallback,
          icon: Icons.open_in_new_rounded,
          bgColor: context.kpb.surfaceBg,
          textColor: context.kpb.textPrimary,
        ),
      ],
    );
  }

  Widget _buildResultCard(FlightRouteResult r, String currency,
      {required bool highlight, required bool isDark}) {
    final stopsLabel = r.stops <= 0
        ? 'flight_direct'.tr
        : r.stops == 1
            ? 'flight_stops_one'.tr
            : 'flight_stops_many'.trParams({'count': '${r.stops}'});
    return Container(
      decoration: BoxDecoration(
        color: context.kpb.cardBg,
        borderRadius: KpbRadius.lgBr,
        border: Border.all(
            color: highlight
                ? (isDark ? KpbColors.sky : KpbColors.blue)
                : context.kpb.gray100,
            width: highlight ? 1.5 : 1),
        boxShadow: KpbShadow.soft,
      ),
      padding: const EdgeInsets.all(KpbSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (highlight)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: KpbColors.success.withValues(alpha: 0.15),
                    borderRadius: KpbRadius.pillBr,
                  ),
                  child: Text('flight_cheapest_badge'.tr,
                      style: KpbTextStyles.caption.copyWith(
                          color: KpbColors.success,
                          fontWeight: FontWeight.w700)),
                ),
              Expanded(
                child: Text(
                  r.airlineLabel,
                  style: KpbTextStyles.title
                      .copyWith(color: context.kpb.textPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                _formatPrice(r.price, currency),
                style: KpbTextStyles.titleMd.copyWith(
                    color: isDark ? KpbColors.sky : KpbColors.blue,
                    fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.schedule_rounded,
                  size: 14, color: context.kpb.textSecondary),
              const SizedBox(width: 4),
              Text(_legTimeLabel(r),
                  style: KpbTextStyles.caption
                      .copyWith(color: context.kpb.textSecondary)),
              const SizedBox(width: 12),
              Icon(Icons.alt_route_rounded,
                  size: 14, color: context.kpb.textSecondary),
              const SizedBox(width: 4),
              Text(stopsLabel,
                  style: KpbTextStyles.caption
                      .copyWith(color: context.kpb.textSecondary)),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: KpbButton(
              text: 'flight_book_on_kayak'.tr,
              onPressed: () => _open(r.deeplinkUrl),
              icon: Icons.airplane_ticket_rounded,
              bgColor: KpbColors.sky,
            ),
          ),
        ],
      ),
    );
  }

  String _legTimeLabel(FlightRouteResult r) {
    final dep = r.departureDateTime;
    if (dep == null) return '—';
    final fmt = DateFormat('HH:mm', ctrl.localeCode);
    final arr = r.arrivalDateTime;
    return arr == null
        ? fmt.format(dep)
        : '${fmt.format(dep)} → ${fmt.format(arr)}';
  }

  Widget _buildCalendarStrip(String currency, bool isDark) {
    final days = [..._calendar.days]..sort((a, b) => a.date.compareTo(b.date));
    final cheapest = days.fold<double?>(
        null, (m, d) => m == null || d.price < m ? d.price : m);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('flight_calendar_title'.tr,
            style:
                KpbTextStyles.title.copyWith(color: context.kpb.textPrimary)),
        const SizedBox(height: 8),
        SizedBox(
          height: 84,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: days.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final d = days[i];
              final isCheapest = cheapest != null && d.price <= cheapest;
              final dt = d.parsedDate;
              return InkWell(
                onTap: dt == null
                    ? null
                    : () {
                        setState(() => _departureDate = dt);
                        _search();
                      },
                borderRadius: KpbRadius.mdBr,
                child: Container(
                  width: 76,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  decoration: BoxDecoration(
                    color: isCheapest
                        ? KpbColors.success.withValues(alpha: 0.12)
                        : context.kpb.surfaceBg,
                    borderRadius: KpbRadius.mdBr,
                    border: Border.all(
                        color: isCheapest
                            ? KpbColors.success.withValues(alpha: 0.5)
                            : context.kpb.gray100),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        dt == null
                            ? d.date
                            : DateFormat('dd MMM', ctrl.localeCode).format(dt),
                        style: KpbTextStyles.caption
                            .copyWith(color: context.kpb.textSecondary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatPrice(d.price, currency),
                        style: KpbTextStyles.labelSm.copyWith(
                          color: isCheapest
                              ? KpbColors.success
                              : context.kpb.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (d.predicted)
                        Text('flight_calendar_predicted'.tr,
                            style: KpbTextStyles.caption.copyWith(
                                color: context.kpb.textMuted, fontSize: 9)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmpty(bool isDark) {
    return Column(
      children: [
        Icon(Icons.search_off_rounded, size: 40, color: context.kpb.gray400),
        const SizedBox(height: 12),
        Text('flight_no_results'.tr,
            textAlign: TextAlign.center,
            style: KpbTextStyles.bodySm
                .copyWith(color: context.kpb.textSecondary)),
        const SizedBox(height: 16),
        KpbButton(
          text: 'flight_view_on_kayak'.tr,
          onPressed: _launchKayakFallback,
          icon: Icons.open_in_new_rounded,
          bgColor: KpbColors.sky,
        ),
      ],
    );
  }

  Widget _buildFallback(bool isDark) {
    return Column(
      children: [
        Text(
          _error ?? 'flight_prices_unavailable'.tr,
          textAlign: TextAlign.center,
          style:
              KpbTextStyles.bodySm.copyWith(color: context.kpb.textSecondary),
        ),
        const SizedBox(height: 16),
        KpbButton(
          text: 'flight_view_on_kayak'.tr,
          onPressed: _launchKayakFallback,
          icon: Icons.open_in_new_rounded,
          bgColor: KpbColors.sky,
        ),
      ],
    );
  }

  Widget _buildHeroAirport(Airport? a, CrossAxisAlignment alignment) {
    return Column(
      crossAxisAlignment: alignment,
      children: [
        Text(
          a?.code ?? '???',
          style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.w800,
              height: 1),
        ),
        const SizedBox(height: 4),
        Text(
          a?.city ?? 'flight_hero_select'.tr,
          style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 14,
              fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildSelectorField(String label, String value, IconData icon,
      VoidCallback onTap, bool isDark) {
    return InkWell(
      onTap: onTap,
      borderRadius: KpbRadius.mdBr,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (isDark ? KpbColors.sky : KpbColors.blue)
                    .withValues(alpha: 0.1),
                borderRadius: KpbRadius.mdBr,
              ),
              child: Icon(icon,
                  color: isDark ? KpbColors.sky : KpbColors.blue, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: KpbTextStyles.labelSm
                          .copyWith(color: context.kpb.textSecondary)),
                  const SizedBox(height: 2),
                  Text(value,
                      style: KpbTextStyles.titleMd
                          .copyWith(color: context.kpb.textPrimary)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: context.kpb.gray400),
          ],
        ),
      ),
    );
  }
}
