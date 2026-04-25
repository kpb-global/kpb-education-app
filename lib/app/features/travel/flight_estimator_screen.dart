import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

import '../../core/ui/app_tokens.dart';
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
    _origin = popularAirports.firstWhere((a) => a.code == 'ABJ', orElse: () => popularAirports.last);
    _destination = popularAirports.firstWhere((a) => a.code == 'CDG', orElse: () => popularAirports.first);
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _departureDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
               primary: KpbColors.blue,
               onPrimary: Colors.white,
               surface: KpbColors.bgDarkCard,
               onSurface: Colors.white,
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

  Future<void> _launchKayak() async {
    if (_origin == null || _destination == null) return;
    
    final formattedDate = DateFormat('yyyy-MM-dd').format(_departureDate);
    // Kayak syntax: https://www.kayak.fr/flights/ABJ-CDG/2026-09-01?sort=price_a
    final urlStr = 'https://www.kayak.fr/flights/${_origin!.code}-${_destination!.code}/$formattedDate?sort=price_a';
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
    return Scaffold(
      backgroundColor: KpbColors.bgDarkMidnight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Simulateur de Vols',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(KpbSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Trouvez les meilleures dates',
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Estimez le prix du billet pour votre pays d\'études et achetez au bon moment.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14),
            ),
            const SizedBox(height: 32),
            
            // Selector Box
            Container(
              decoration: BoxDecoration(
                color: KpbColors.bgDarkCard,
                borderRadius: KpbRadius.lgBr,
                border: Border.all(color: KpbColors.glassBorder),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                   _buildDropdown('Ville de départ', _origin, (val) {
                      setState(() => _origin = val);
                   }),
                   const SizedBox(height: 16),
                   _buildDropdown('Ville d\'arrivée', _destination, (val) {
                      setState(() => _destination = val);
                   }),
                   const SizedBox(height: 16),
                   _buildDateField(),
                ],
              ),
            ),
            
            const SizedBox(height: 48),

            // Magic Button
            KpbButton(
              text: 'Voir les vols \u0026 prix', // \u0026 ensures safe parsing
              onPressed: _launchKayak,
              icon: Icons.flight_takeoff_rounded,
              bgColor: KpbColors.blue,
            ),
            
            const SizedBox(height: 16),
            Text(
              'Propulsé par le comparateur indépendant Kayak. Les prix sont affichés en direct.',
              style: TextStyle(color: KpbColors.textDarkSecondary.withValues(alpha: 0.5), fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown(String label, Airport? currentValue, ValueChanged<Airport?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: KpbColors.textDarkSecondary, fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.2),
            borderRadius: KpbRadius.mdBr,
            border: Border.all(color: KpbColors.glassBorder),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<Airport>(
              value: currentValue,
              dropdownColor: KpbColors.bgDarkCard,
              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white54),
              items: popularAirports.map((a) {
                return DropdownMenuItem(
                  value: a,
                  child: Text(a.displayName),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
         const Text(
          'Date de départ souhaitée',
          style: TextStyle(color: KpbColors.textDarkSecondary, fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () => _selectDate(context),
          child: Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.2),
              borderRadius: KpbRadius.mdBr,
              border: Border.all(color: KpbColors.glassBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_rounded, color: Colors.white54, size: 20),
                const SizedBox(width: 12),
                Text(
                  DateFormat('dd MMMM yyyy').format(_departureDate),
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
                )
              ],
            ),
          ),
        )
      ],
    );
  }
}
