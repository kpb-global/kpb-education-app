import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../core/ui/app_tokens.dart';
import '../../core/ui/kpb_theme_ext.dart';
import '../../core/utils/country_utils.dart';
import 'data/budget_data.dart';

enum Lifestyle { econome, standard, confort }

/// Fixed icon + colour palette for the nine canonical budget categories,
/// indexed to match [LivingBudgetProfile.categories].
const List<IconData> _kCategoryIcons = [
  Icons.home_rounded, // Loyer
  Icons.bolt_rounded, // Charges & énergie
  Icons.restaurant_rounded, // Alimentation
  Icons.directions_bus_rounded, // Transport
  Icons.health_and_safety_rounded, // Santé & assurance
  Icons.wifi_rounded, // Forfait & Internet
  Icons.menu_book_rounded, // Fournitures & livres
  Icons.checkroom_rounded, // Vêtements & hygiène
  Icons.local_activity_rounded, // Loisirs & divers
];

class BudgetCalculatorScreen extends StatefulWidget {
  const BudgetCalculatorScreen({super.key});

  @override
  State<BudgetCalculatorScreen> createState() => _BudgetCalculatorScreenState();
}

class _BudgetCalculatorScreenState extends State<BudgetCalculatorScreen> {
  LivingBudgetProfile? _selectedProfile;
  Lifestyle _lifestyle = Lifestyle.standard;

  /// Colour ramp aligned 1:1 with [LivingBudgetProfile.categories].
  static const List<Color> _categoryColors = [
    KpbColors.sky,
    KpbColors.blue,
    KpbColors.success,
    KpbColors.gold,
    KpbColors.error,
    KpbColors.blueMid,
    KpbColors.blue,
    KpbColors.warning,
    KpbColors.gray400,
  ];

  @override
  void initState() {
    super.initState();
    if (mockBudgetProfiles.isNotEmpty) {
      _selectedProfile = mockBudgetProfiles.first;
    }
  }

  double _getMultiplier(LivingBudgetProfile p) {
    if (_lifestyle == Lifestyle.econome) {
      return p.monthlyMin / p.totalTypical;
    } else if (_lifestyle == Lifestyle.confort) {
      return p.monthlyMax / p.totalTypical;
    }
    return 1.0; // Standard
  }

  double _getTotal(LivingBudgetProfile p) {
    if (_lifestyle == Lifestyle.econome) return p.monthlyMin;
    if (_lifestyle == Lifestyle.confort) return p.monthlyMax;
    return p.totalTypical;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_selectedProfile == null) {
      return Scaffold(
        appBar: AppBar(title: Text('budget_calculator_title'.tr)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final p = _selectedProfile!;
    final mult = _getMultiplier(p);
    final total = _getTotal(p);

    return Scaffold(
      backgroundColor: context.kpb.pageBg,
      appBar: AppBar(
        title: Text('budget_calculator_title'.tr),
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
                    'student_living_cost'.tr,
                    style: KpbTextStyles.headline
                        .copyWith(color: context.kpb.textPrimary),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'budget_intro'.tr,
                    style: KpbTextStyles.bodySm
                        .copyWith(color: context.kpb.textSecondary),
                  ),
                  const SizedBox(height: KpbSpacing.xl),
                ],
              ),
            ),
          ),

          // ── Country Selector ──────────────────────────────────────────────
          SliverToBoxAdapter(
            child: SizedBox(
              height: 48,
              child: ListView.separated(
                padding:
                    const EdgeInsets.symmetric(horizontal: KpbSpacing.pagePad),
                scrollDirection: Axis.horizontal,
                itemCount: mockBudgetProfiles.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final profile = mockBudgetProfiles[index];
                  final isSelected = profile == _selectedProfile;
                  return ChoiceChip(
                    label: Text(
                      '${countryFlag(profile.country)} ${profile.country}',
                      style: TextStyle(
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) setState(() => _selectedProfile = profile);
                    },
                    backgroundColor: context.kpb.cardBg,
                    selectedColor: isDark
                        ? KpbColors.blue.withValues(alpha: 0.2)
                        : KpbColors.skyLight,
                    labelStyle: TextStyle(
                      color: isSelected
                          ? (KpbColors.blue)
                          : context.kpb.textSecondary,
                    ),
                    side: BorderSide(
                      color:
                          isSelected ? (KpbColors.blue) : context.kpb.gray200,
                    ),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  );
                },
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: KpbSpacing.xl)),

          // ── Lifestyle Toggle ──────────────────────────────────────────────
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
                    _buildLifestyleButton('budget_lifestyle_econome'.tr,
                        Lifestyle.econome, isDark),
                    _buildLifestyleButton('budget_lifestyle_standard'.tr,
                        Lifestyle.standard, isDark),
                    _buildLifestyleButton('budget_lifestyle_confort'.tr,
                        Lifestyle.confort, isDark),
                  ],
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: KpbSpacing.xl)),

          // ── Hero Chart Card ───────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: KpbSpacing.pagePad),
              child: Container(
                decoration: BoxDecoration(
                  color: context.kpb.cardBg,
                  borderRadius: KpbRadius.xlBr,
                  boxShadow: KpbShadow.card,
                  border: Border.all(color: context.kpb.gray100),
                ),
                padding: const EdgeInsets.all(KpbSpacing.lg),
                child: Column(
                  children: [
                    Text(
                      'estimated_monthly_budget'.tr,
                      style: KpbTextStyles.label
                          .copyWith(color: context.kpb.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          total.toInt().toString(),
                          style: TextStyle(
                            fontSize: 42,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : KpbColors.blue,
                            height: 1,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            p.currency,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: context.kpb.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      height: 220,
                      child: PieChart(
                        PieChartData(
                          sectionsSpace: 4,
                          centerSpaceRadius: 60,
                          startDegreeOffset: 180,
                          sections: _generateChartSections(p, mult, isDark),
                        ),
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeOutQuint,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: KpbSpacing.xl)),

          // ── Detail List ───────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: KpbSpacing.pagePad),
              child: Text(
                'details_by_category'.tr,
                style: KpbTextStyles.title
                    .copyWith(color: context.kpb.textPrimary),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: KpbSpacing.md)),

          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: KpbSpacing.pagePad),
            sliver: SliverList.separated(
              itemCount: p.categories.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                return _buildDetailRow(
                  p.categories[index],
                  mult,
                  _categoryColors[index % _categoryColors.length],
                  p.currency,
                  _kCategoryIcons[index % _kCategoryIcons.length],
                  isDark,
                );
              },
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildLifestyleButton(String text, Lifestyle mode, bool isDark) {
    final isSelected = _lifestyle == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _lifestyle = mode),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? (KpbColors.blue) : Colors.transparent,
            borderRadius: KpbRadius.pillBr,
            boxShadow: isSelected && !isDark ? KpbShadow.soft : null,
          ),
          child: Center(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : context.kpb.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<PieChartSectionData> _generateChartSections(
      LivingBudgetProfile p, double mult, bool isDark) {
    PieChartSectionData createSection(double val, Color color) {
      return PieChartSectionData(
        color: color,
        value: val * mult,
        showTitle: false,
        radius: 30,
        badgeWidget: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
          ),
        ),
        badgePositionPercentageOffset: .98,
      );
    }

    return [
      for (var i = 0; i < p.categories.length; i++)
        createSection(
          p.categories[i].typical,
          _categoryColors[i % _categoryColors.length],
        ),
    ];
  }

  Widget _buildDetailRow(
    BudgetCategory cat,
    double mult,
    Color color,
    String curr,
    IconData icon,
    bool isDark,
  ) {
    final val = (cat.typical * mult).toInt();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.kpb.cardBg,
        borderRadius: KpbRadius.lgBr,
        border: Border.all(color: context.kpb.gray100),
        boxShadow: KpbShadow.soft,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: KpbRadius.mdBr,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cat.name,
                  style: KpbTextStyles.titleMd
                      .copyWith(color: context.kpb.textPrimary),
                ),
                if (cat.note != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    cat.note!,
                    style: KpbTextStyles.caption
                        .copyWith(color: context.kpb.textMuted),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '$val $curr',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: context.kpb.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
