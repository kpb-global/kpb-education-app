import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/ui/kpb_components.dart';
import 'cv_generator_screen.dart';
import 'document_scanner_screen.dart';
import 'impact_dashboard_screen.dart';
import 'interview_simulator_screen.dart';
import 'motivation_letters_screen.dart';

/// Hub screen listing all student tools.
class StudentToolsScreen extends StatelessWidget {
  const StudentToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Outils etudiants')),
      body: ListView(
        padding: const EdgeInsets.all(KpbSpacing.pagePad),
        children: [
          Text(
            'Des outils pratiques pour preparer ta candidature.',
            style: TextStyle(fontSize: 14, color: context.kpb.textMuted),
          ),
          const SizedBox(height: KpbSpacing.lg),

          _ToolCard(
            icon: Icons.description_rounded,
            color: KpbColors.blue,
            title: 'Generateur de CV',
            subtitle:
                'Cree un CV professionnel pre-rempli depuis ton profil, ameliore par l\'IA.',
            onTap: () => Get.to(() => const CvGeneratorScreen()),
          ),

          const SizedBox(height: KpbSpacing.md),

          _ToolCard(
            icon: Icons.mail_outline_rounded,
            color: KpbColors.success,
            title: 'Lettres de motivation',
            subtitle:
                '6 modeles (admissions, bourses, visa, stage) personnalisables avec l\'IA en FR et EN.',
            onTap: () => Get.to(() => const MotivationLettersScreen()),
          ),

          const SizedBox(height: KpbSpacing.md),

          _ToolCard(
            icon: Icons.record_voice_over_rounded,
            color: KpbColors.gold,
            title: 'Simulateur d\'entretien',
            subtitle:
                'Entraine-toi aux entretiens visa, admission et bourse avec un examinateur IA qui te note.',
            onTap: () => Get.to(() => const InterviewSimulatorScreen()),
          ),

          const SizedBox(height: KpbSpacing.md),

          _ToolCard(
            icon: Icons.document_scanner_rounded,
            color: KpbColors.sky,
            title: 'Scanner mes documents',
            subtitle:
                'Scanne et organise les pieces de ton dossier (passeport, diplomes...) en PDF.',
            onTap: () => Get.to(() => const DocumentScannerScreen()),
          ),

          const SizedBox(height: KpbSpacing.md),

          _ToolCard(
            icon: Icons.insights_rounded,
            color: KpbColors.navy,
            title: 'Notre impact',
            subtitle:
                'Decouvre l\'impact de KPB Education : etudiants accompagnes, admissions, bourses.',
            onTap: () => Get.to(() => const ImpactDashboardScreen()),
          ),
        ],
      ),
    );
  }
}

class _ToolCard extends StatelessWidget {
  const _ToolCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return KpbCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: KpbRadius.mdBr,
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: context.kpb.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.kpb.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: context.kpb.textMuted),
        ],
      ),
    );
  }
}
