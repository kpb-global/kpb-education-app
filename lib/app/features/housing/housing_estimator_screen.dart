import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/ui/kpb_components.dart';

class CityTarget {
  const CityTarget(this.name, this.urlSlug, this.country, this.minRent,
      this.maxRent, this.currency);
  final String name;
  final String urlSlug;
  final String country;
  final int minRent;
  final int maxRent;
  final String currency;
}

const List<CityTarget> popularCities = [
  CityTarget('Paris', 'paris', 'France', 750, 1200, '€'),
  CityTarget('Lyon', 'lyon', 'France', 550, 850, '€'),
  CityTarget('Toulouse', 'toulouse', 'France', 450, 750, '€'),
  CityTarget('Lille', 'lille', 'France', 450, 700, '€'),
  CityTarget('Bordeaux', 'bordeaux', 'France', 500, 800, '€'),
  CityTarget('Marseille', 'marseille', 'France', 450, 750, '€'),
  CityTarget('Nantes', 'nantes', 'France', 480, 750, '€'),
  CityTarget('Strasbourg', 'strasbourg', 'France', 450, 700, '€'),
  CityTarget('Montpellier', 'montpellier', 'France', 480, 750, '€'),
  CityTarget('Montréal', 'montreal', 'Canada', 800, 1500, '\$'),
  CityTarget('Toronto', 'toronto', 'Canada', 1200, 2200, '\$'),
];

class HousingEstimatorScreen extends StatefulWidget {
  const HousingEstimatorScreen({super.key});

  @override
  State<HousingEstimatorScreen> createState() => _HousingEstimatorScreenState();
}

class _HousingEstimatorScreenState extends State<HousingEstimatorScreen> {
  CityTarget? _selectedCity;
  String _selectedCountry = 'France';

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
        'La recherche de logement automatisée pour le ${_selectedCity!.country} arrive très bientôt. Nos conseillers peuvent vous aider dans vos dossiers.',
        backgroundColor: KpbColors.warning,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    final urlStr =
        'https://www.studapart.com/fr/logement-etudiant-${_selectedCity!.urlSlug}';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Filter cities by selected country tab
    final filteredCities =
        popularCities.where((c) => c.country == _selectedCountry).toList();

    return Scaffold(
      backgroundColor: context.kpb.pageBg,
      appBar: AppBar(
        title: Text('student_housing'.tr),
        backgroundColor: Colors.transparent,
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: KpbSpacing.pagePad, vertical: KpbSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Trouvez votre cocon',
                    style: KpbTextStyles.headline
                        .copyWith(color: context.kpb.textPrimary),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'housing_intro'.tr,
                    style: KpbTextStyles.bodySm
                        .copyWith(color: context.kpb.textSecondary),
                  ),
                  const SizedBox(height: KpbSpacing.xl),
                ],
              ),
            ),
          ),

          // ── Estimate Card ────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: KpbSpacing.pagePad),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
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
                    Icon(Icons.maps_home_work_rounded,
                        color: Colors.white, size: 36),
                    SizedBox(height: 12),
                    Text(
                      '${'estimated_monthly_rent_in'.tr} ${_selectedCity?.name}',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 8),
                    if (_selectedCity != null)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '${_selectedCity!.minRent} ${'to_range'.tr} ${_selectedCity!.maxRent}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 36,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _selectedCity!.currency,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: KpbSpacing.xl)),

          // ── Country Tabs ──────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: KpbSpacing.pagePad),
              child: Container(
                decoration: BoxDecoration(
                  color: context.kpb.surfaceBg,
                  borderRadius: KpbRadius.pillBr,
                  border: Border.all(color: context.kpb.gray100),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    _buildCountryTab('France', '🇫🇷', isDark),
                    _buildCountryTab('Canada', '🇨🇦', isDark),
                  ],
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: KpbSpacing.lg)),

          // ── City Chips Grid ──────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: KpbSpacing.pagePad),
              child: Wrap(
                spacing: 8,
                runSpacing: 10,
                children: filteredCities.map((city) {
                  final isSelected = city == _selectedCity;
                  return ChoiceChip(
                    label: Text(
                      city.name,
                      style: TextStyle(
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) setState(() => _selectedCity = city);
                    },
                    backgroundColor: context.kpb.cardBg,
                    selectedColor: isDark
                        ? KpbColors.blueMid.withValues(alpha: 0.3)
                        : KpbColors.skyLight,
                    labelStyle: TextStyle(
                      color: isSelected
                          ? (isDark ? Colors.white : KpbColors.blue)
                          : context.kpb.textSecondary,
                    ),
                    side: BorderSide(
                      color: isSelected
                          ? (isDark ? KpbColors.blueMid : KpbColors.blue)
                          : context.kpb.gray200,
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                  );
                }).toList(),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: KpbSpacing.xl)),

          // ── Partnership Box ──────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: KpbSpacing.pagePad),
              child: Container(
                decoration: BoxDecoration(
                  color: context.kpb.cardBg,
                  borderRadius: KpbRadius.lgBr,
                  border: Border.all(color: context.kpb.gray100),
                  boxShadow: KpbShadow.soft,
                ),
                padding: const EdgeInsets.all(KpbSpacing.lg),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: KpbColors.blueMid.withValues(alpha: 0.1),
                            borderRadius: KpbRadius.mdBr,
                          ),
                          child: const Icon(Icons.holiday_village_rounded,
                              color: KpbColors.blueMid),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Partenariat Studapart',
                                style: KpbTextStyles.titleMd
                                    .copyWith(color: context.kpb.textPrimary),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Louez votre logement en France facilement avec ou sans garant local.',
                                style: KpbTextStyles.caption
                                    .copyWith(color: context.kpb.textMuted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    KpbButton(
                      text: 'Voir les offres à ${_selectedCity?.name}',
                      onPressed: _launchStudapart,
                      icon: Icons.open_in_new_rounded,
                      bgColor: KpbColors.blueMid,
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildCountryTab(String country, String flag, bool isDark) {
    final isSelected = _selectedCountry == country;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedCountry = country;
            // auto-select first city in that country
            _selectedCity =
                popularCities.firstWhere((c) => c.country == country);
          });
        },
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? KpbColors.gray700 : Colors.white)
                : Colors.transparent,
            borderRadius: KpbRadius.pillBr,
            boxShadow: isSelected && !isDark ? KpbShadow.soft : null,
          ),
          child: Center(
            child: Text(
              '$flag $country',
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? context.kpb.textPrimary
                    : context.kpb.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
