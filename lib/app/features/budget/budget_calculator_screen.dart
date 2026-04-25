import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../core/ui/app_tokens.dart';
import 'data/budget_data.dart';

class BudgetCalculatorScreen extends StatefulWidget {
  const BudgetCalculatorScreen({super.key});

  @override
  State<BudgetCalculatorScreen> createState() => _BudgetCalculatorScreenState();
}

class _BudgetCalculatorScreenState extends State<BudgetCalculatorScreen> {
  LivingBudgetProfile? _selectedProfile;

  @override
  void initState() {
    super.initState();
    if (mockBudgetProfiles.isNotEmpty) {
      _selectedProfile = mockBudgetProfiles.first;
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
          'Simulateur de Budget',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _selectedProfile == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(KpbSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Estimez le coût de la vie étudiant',
                    style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Anticipez vos dépenses mensuelles pour éviter les mauvaises surprises.',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14),
                  ),
                  const SizedBox(height: 24),
                  
                  // Country Selector
                  Container(
                    decoration: BoxDecoration(
                      color: KpbColors.bgDarkCard,
                      borderRadius: KpbRadius.mdBr,
                      border: Border.all(color: KpbColors.glassBorder),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<LivingBudgetProfile>(
                        value: _selectedProfile,
                        dropdownColor: KpbColors.bgDarkCard,
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                        isExpanded: true,
                        items: mockBudgetProfiles.map((p) {
                          return DropdownMenuItem(
                            value: p,
                            child: Text(
                              '${p.country} (${p.currency})',
                              style: const TextStyle(color: Colors.white),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedProfile = val);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Chart Area
                  Container(
                    decoration: BoxDecoration(
                      color: KpbColors.bgDarkCard,
                      borderRadius: KpbRadius.lgBr,
                      border: Border.all(color: KpbColors.glassBorder),
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                         Text(
                          'Budget Mensuel Estimé',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${_selectedProfile!.monthlyMin.toInt()} à ${_selectedProfile!.monthlyMax.toInt()} ${_selectedProfile!.currency}',
                          style: const TextStyle(color: KpbColors.primary, fontSize: 28, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 32),
                        SizedBox(
                          height: 200,
                          child: PieChart(
                            PieChartData(
                              sectionsSpace: 4,
                              centerSpaceRadius: 50,
                              sections: _generateChartSections(_selectedProfile!),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Detail List
                  const Text(
                    'Détails par catégorie',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 16),
                  _buildDetailRow(_selectedProfile!.rent, KpbColors.stitchDeepPurple, _selectedProfile!.currency),
                  _buildDetailRow(_selectedProfile!.food, KpbColors.stitchNeonRed, _selectedProfile!.currency),
                  _buildDetailRow(_selectedProfile!.transport, KpbColors.stitchCyberCyan, _selectedProfile!.currency),
                  _buildDetailRow(_selectedProfile!.healthInsurance, KpbColors.success, _selectedProfile!.currency),
                  _buildDetailRow(_selectedProfile!.internetMobile, KpbColors.warning, _selectedProfile!.currency),
                  _buildDetailRow(_selectedProfile!.leisureMisc, KpbColors.primaryLight, _selectedProfile!.currency),
                  const SizedBox(height: 48),
                ],
              ),
            ),
    );
  }

  List<PieChartSectionData> _generateChartSections(LivingBudgetProfile p) {
    return [
      PieChartSectionData(color: KpbColors.stitchDeepPurple, value: p.rent.typical, showTitle: false, radius: 25),
      PieChartSectionData(color: KpbColors.stitchNeonRed, value: p.food.typical, showTitle: false, radius: 25),
      PieChartSectionData(color: KpbColors.stitchCyberCyan, value: p.transport.typical, showTitle: false, radius: 25),
      PieChartSectionData(color: KpbColors.success, value: p.healthInsurance.typical, showTitle: false, radius: 25),
      PieChartSectionData(color: KpbColors.warning, value: p.internetMobile.typical, showTitle: false, radius: 25),
      PieChartSectionData(color: KpbColors.primaryLight, value: p.leisureMisc.typical, showTitle: false, radius: 25),
    ];
  }

  Widget _buildDetailRow(BudgetCategory cat, Color color, String curr) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: KpbColors.bgDarkCard,
        borderRadius: KpbRadius.mdBr,
        border: Border.all(color: KpbColors.glassBorder),
      ),
      child: Row(
        children: [
          Container(width: 14, height: 14, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(cat.name, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                if (cat.note != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(cat.note!, style: TextStyle(color: KpbColors.textDarkSecondary.withValues(alpha: 0.7), fontSize: 11)),
                  )
              ],
            ),
          ),
          Text(
            '~ ${cat.typical.toInt()} $curr',
            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
