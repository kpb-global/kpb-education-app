import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/controllers/app_controller.dart';
import '../../core/ui/app_tokens.dart';
import '../../core/ui/components/kpb_card.dart';
import '../../core/ui/components/verified_badge.dart';
import '../../core/ui/kpb_theme_ext.dart';
import '../tools/impact_dashboard_screen.dart';

/// Compact, verifiable + dated social-proof banner for Home. Fetches the live
/// `/impact/stats` aggregate and renders nothing until real impact exists — we
/// never show a fabricated number. The freshness chip reuses [VerifiedBadge]
/// (localized "Vérifié le …"), and tapping opens the full impact board.
class HomeImpactProof extends StatefulWidget {
  const HomeImpactProof({super.key});

  @override
  State<HomeImpactProof> createState() => _HomeImpactProofState();
}

class _HomeImpactProofState extends State<HomeImpactProof> {
  Map<String, dynamic>? _stats;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data =
          await Get.find<AppController>().apiClient.get('impact/stats');
      if (mounted) setState(() => _stats = data);
    } catch (_) {
      // Offline / no backend — stay hidden rather than show fabricated proof.
    }
  }

  int _int(String k) => (_stats?[k] as num?)?.toInt() ?? 0;

  @override
  Widget build(BuildContext context) {
    final students = _int('studentsGuided');
    final admissions = _int('admissionsSecured');
    // Only surface once there is real impact to show.
    if (students <= 0 && admissions <= 0) return const SizedBox.shrink();

    final raw = _stats?['generatedAt'] as String?;
    final generatedAt = raw == null ? null : DateTime.tryParse(raw);

    return Column(
      children: [
        KpbCard(
          onTap: () => Get.to(() => const ImpactDashboardScreen()),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: KpbColors.success.withValues(alpha: 0.12),
                  borderRadius: KpbRadius.smBr,
                ),
                child: const Icon(Icons.verified_rounded,
                    color: KpbColors.success, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('impact_proof_title'.tr, style: KpbTextStyles.titleMd),
                    const SizedBox(height: 2),
                    Text(
                      'impact_proof_line'.trParams({
                        'students': '$students',
                        'admissions': '$admissions',
                      }),
                      style: TextStyle(
                          fontSize: 13, color: context.kpb.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (generatedAt != null)
                VerifiedBadge(lastVerifiedAt: generatedAt, compact: true),
            ],
          ),
        ),
        const SizedBox(height: KpbSpacing.lg),
      ],
    );
  }
}
