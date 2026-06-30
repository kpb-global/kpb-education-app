import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

import '../../core/ui/kpb_components.dart';

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

class FlightEstimatorScreen extends StatefulWidget {
  const FlightEstimatorScreen({super.key});

  @override
  State<FlightEstimatorScreen> createState() => _FlightEstimatorScreenState();
}

class _FlightEstimatorScreenState extends State<FlightEstimatorScreen> {
  Airport? _origin;
  Airport? _destination;
  DateTime _departureDate = DateTime.now().add(const Duration(days: 30));

  @override
  void initState() {
    super.initState();
    _origin = popularAirports.firstWhere((a) => a.code == 'ABJ',
        orElse: () => popularAirports.last);
    _destination = popularAirports.firstWhere((a) => a.code == 'CDG',
        orElse: () => popularAirports.first);
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
      setState(() {
        _departureDate = picked;
      });
    }
  }

  Future<void> _showAirportPicker(bool isOrigin) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    await showModalBottomSheet(
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
                isOrigin ? 'Sélectionner le départ' : 'Sélectionner l\'arrivée',
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

  Future<void> _launchKayak() async {
    if (_origin == null || _destination == null) return;

    final formattedDate = DateFormat('yyyy-MM-dd').format(_departureDate);
    final urlStr =
        'https://www.kayak.fr/flights/${_origin!.code}-${_destination!.code}/$formattedDate?sort=price_a';
    final uri = Uri.parse(urlStr);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      Get.snackbar(
        'Erreur',
        'Impossible d\'ouvrir le comparateur de vols.',
        backgroundColor: KpbColors.error,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: context.kpb.pageBg,
      appBar: AppBar(
        title: const Text('Simulateur de Vols'),
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(KpbSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Préparez votre départ',
              style: KpbTextStyles.headline
                  .copyWith(color: context.kpb.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'Estimez le prix du billet pour votre pays d\'études et achetez au meilleur moment.',
              style: KpbTextStyles.bodySm
                  .copyWith(color: context.kpb.textSecondary),
            ),
            const SizedBox(height: 32),

            // ── Hero Flight Card ─────────────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                gradient: isDark
                    ? KpbColors.heroGradientDark
                    : KpbColors.heroGradient,
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                          DateFormat('dd MMMM yyyy', 'fr_FR')
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
            ),
            const SizedBox(height: 32),

            // ── Form Box ────────────────────────────────────────────────────
            Container(
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
                      'Départ',
                      _origin?.city ?? 'Choisir',
                      Icons.flight_takeoff_rounded,
                      () => _showAirportPicker(true),
                      isDark),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Divider(),
                  ),
                  _buildSelectorField(
                      'Arrivée',
                      _destination?.city ?? 'Choisir',
                      Icons.flight_land_rounded,
                      () => _showAirportPicker(false),
                      isDark),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Divider(),
                  ),
                  _buildSelectorField(
                      'Date',
                      DateFormat('dd MMM yyyy', 'fr_FR').format(_departureDate),
                      Icons.event_rounded,
                      () => _selectDate(context),
                      isDark),
                ],
              ),
            ),

            const SizedBox(height: 48),

            // ── Magic Button ────────────────────────────────────────────────
            KpbButton(
              text: 'Voir les vols sur Kayak',
              onPressed: _launchKayak,
              icon: Icons.search_rounded,
              bgColor: KpbColors.sky,
            ),

            const SizedBox(height: 16),
            Text(
              'Propulsé par le comparateur indépendant Kayak. Les prix sont affichés en direct.',
              style:
                  KpbTextStyles.caption.copyWith(color: context.kpb.textMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
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
          a?.city ?? 'Sélectionner',
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
