import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/ui/app_tokens.dart';
import '../../core/ui/kpb_components.dart';

class CityTarget {
  const CityTarget(this.name, this.urlSlug, this.country);
  final String name;
  final String urlSlug;
  final String country;
}

const List<CityTarget> popularCities = [
  CityTarget('Paris', 'paris', 'France'),
  CityTarget('Lyon', 'lyon', 'France'),
  CityTarget('Toulouse', 'toulouse', 'France'),
  CityTarget('Lille', 'lille', 'France'),
  CityTarget('Bordeaux', 'bordeaux', 'France'),
  CityTarget('Marseille', 'marseille', 'France'),
  CityTarget('Nantes', 'nantes', 'France'),
  CityTarget('Strasbourg', 'strasbourg', 'France'),
  CityTarget('Rennes', 'rennes', 'France'),
  CityTarget('Montpellier', 'montpellier', 'France'),
  // Add Canada fallback logic if necessary
  CityTarget('Montréal', 'montreal', 'Canada'),
  CityTarget('Toronto', 'toronto', 'Canada'),
];

class HousingEstimatorScreen extends StatefulWidget {
  const HousingEstimatorScreen({super.key});

  @override
  State<HousingEstimatorScreen> createState() => _HousingEstimatorScreenState();
}

class _HousingEstimatorScreenState extends State<HousingEstimatorScreen> {
  CityTarget? _selectedCity;

  @override
  void initState() {
    super.initState();
    _selectedCity = popularCities.first;
  }

  Future<void> _launchStudapart() async {
    if (_selectedCity == null) return;
    
    if (_selectedCity!.country != 'France') {
      Get.snackbar(
        'Bientôt disponible',
        'La recherche de logement automatisée pour le Canada arrive très bientôt. Nos conseillers peuvent vous aider dans vos dossiers.',
        backgroundColor: KpbColors.warning,
        colorText: KpbColors.bgDarkMidnight,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    // Studapart typically maps French cities natively.
    // Example: https://www.studapart.com/fr/logement-etudiant-lyon
    final urlStr = 'https://www.studapart.com/fr/logement-etudiant-${_selectedCity!.urlSlug}';
    final uri = Uri.parse(urlStr);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      Get.snackbar(
        'Erreur',
        'Impossible d\'ouvrir Studapart.',
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
          'Logement Étudiant',
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
              'Trouvez votre cocon',
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Garantir votre hébergement est primordial pour l\'obtention de votre visa étudiant.',
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
                   _buildDropdown('Dans quelle ville étudierez-vous ?', _selectedCity, (val) {
                      setState(() => _selectedCity = val);
                   }),
                ],
              ),
            ),
            
            const SizedBox(height: 48),

            // Magic Button
            KpbButton(
              text: 'Rechercher sur Studapart',
              onPressed: _launchStudapart,
              icon: Icons.holiday_village_rounded,
              bgColor: KpbColors.stitchDeepPurple,
            ),
            
            const SizedBox(height: 16),
            Text(
              'En partenariat technologique avec Studapart France.',
              style: TextStyle(color: KpbColors.textDarkSecondary.withValues(alpha: 0.5), fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown(String label, CityTarget? currentValue, ValueChanged<CityTarget?> onChanged) {
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
            child: DropdownButton<CityTarget>(
              value: currentValue,
              dropdownColor: KpbColors.bgDarkCard,
              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white54),
              items: popularCities.map((c) {
                return DropdownMenuItem(
                  value: c,
                  child: Text('${c.name} (${c.country})'),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
