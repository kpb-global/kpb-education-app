import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/controllers/app_controller.dart';
import '../../core/ui/kpb_components.dart';

/// "Notre impact" — public social-impact board (pitch + transparency).
class ImpactDashboardScreen extends StatefulWidget {
  const ImpactDashboardScreen({super.key});

  @override
  State<ImpactDashboardScreen> createState() => _ImpactDashboardScreenState();
}

class _ImpactDashboardScreenState extends State<ImpactDashboardScreen> {
  final _ctrl = Get.find<AppController>();
  Map<String, dynamic>? _stats;
  bool _loading = true;
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _loadError = null;
      });
    }
    try {
      final data = await _ctrl.apiClient.get('impact/stats');
      if (mounted) {
        setState(() {
          _stats = data;
          _loadError = null;
        });
      }
    } catch (error) {
      // Public impact is deliberately fail-closed. An unavailable or disabled
      // aggregate is never rendered as fabricated zero statistics.
      if (mounted) {
        setState(() {
          _stats = null;
          _loadError = error;
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int _int(String k) => (_stats?[k] as num?)?.toInt() ?? 0;

  /// Date of the live aggregate snapshot (the board is dated, verifiable).
  String get _generatedDate {
    final raw = _stats?['generatedAt'] as String?;
    final d = raw == null ? null : DateTime.tryParse(raw);
    return d == null ? '' : '${d.day}/${d.month}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('impact_title'.tr)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? KpbErrorState(
                  title: 'impact_unavailable_title'.tr,
                  subtitle: 'impact_unavailable_subtitle'.tr,
                  onRetry: _load,
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(KpbSpacing.pagePad),
                    children: [
                      // Hero
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(KpbSpacing.lg),
                        decoration: BoxDecoration(
                          gradient: KpbColors.heroGradient,
                          borderRadius: KpbRadius.xlBr,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'impact_hero_title'.tr,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'impact_hero_subtitle'.tr,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: KpbSpacing.lg),

                      // Stat grid
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: KpbSpacing.md,
                        crossAxisSpacing: KpbSpacing.md,
                        childAspectRatio: 1.15,
                        children: [
                          _StatCard(
                            icon: Icons.groups_rounded,
                            color: KpbColors.blue,
                            value: '${_int('studentsGuided')}',
                            label: 'impact_stat_students_guided'.tr,
                          ),
                          _StatCard(
                            icon: Icons.school_rounded,
                            color: KpbColors.success,
                            value: '${_int('admissionsSecured')}',
                            label: 'impact_stat_admissions'.tr,
                          ),
                          _StatCard(
                            icon: Icons.savings_rounded,
                            color: KpbColors.gold,
                            value: '${_int('scholarshipsTracked')}',
                            label: 'impact_stat_scholarships'.tr,
                          ),
                          _StatCard(
                            icon: Icons.public_rounded,
                            color: KpbColors.sky,
                            value: '${_int('countriesCovered')}',
                            label: 'impact_stat_countries'.tr,
                          ),
                          _StatCard(
                            icon: Icons.handshake_rounded,
                            color: KpbColors.navy,
                            value: '${_int('partnerInstitutions')}',
                            label: 'impact_stat_partner_institutions'.tr,
                          ),
                          _StatCard(
                            icon: Icons.psychology_rounded,
                            color: KpbColors.blueMid,
                            value: '${_int('orientationSessions')}',
                            label: 'impact_stat_orientation_sessions'.tr,
                          ),
                        ],
                      ),

                      const SizedBox(height: KpbSpacing.lg),

                      // Satisfaction — only shown once real published reviews
                      // exist; never a fabricated rate.
                      if (_stats?['satisfactionRate'] != null) ...[
                        KpbCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.favorite_rounded,
                                      color: KpbColors.error, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'impact_satisfaction_rate'.tr,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: context.kpb.textPrimary,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '${_int('satisfactionRate')}%',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: KpbColors.success,
                                      fontSize: 18,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: KpbSpacing.sm),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: LinearProgressIndicator(
                                  value: _int('satisfactionRate') / 100,
                                  minHeight: 10,
                                  backgroundColor: context.kpb.gray200,
                                  valueColor: const AlwaysStoppedAnimation(
                                      KpbColors.success),
                                ),
                              ),
                              const SizedBox(height: KpbSpacing.sm),
                              Text(
                                'reviews_basis'
                                    .trParams({'n': '${_int('reviewsCount')}'}),
                                style: TextStyle(
                                    fontSize: 12,
                                    color: context.kpb.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: KpbSpacing.lg),
                      ],

                      // Dated snapshot — the board is a live, verifiable figure.
                      if (_generatedDate.isNotEmpty)
                        Center(
                          child: Text(
                            'updated_on'.trParams({'date': _generatedDate}),
                            style: TextStyle(
                                fontSize: 12, color: context.kpb.textSecondary),
                          ),
                        ),

                      const SizedBox(height: KpbSpacing.xl),
                    ],
                  ),
                ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(KpbSpacing.md),
      decoration: BoxDecoration(
        color: context.kpb.cardBg,
        borderRadius: KpbRadius.lgBr,
        boxShadow: KpbShadow.card,
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: KpbRadius.mdBr,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: context.kpb.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: context.kpb.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
