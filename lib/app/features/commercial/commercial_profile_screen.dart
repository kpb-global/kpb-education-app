// M9 — Onglet "Moi" pour les commerciaux KPB.
// Affiche le profil commercial + les stats des 30 derniers jours.

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/controllers/app_controller.dart';
import '../../core/ui/kpb_components.dart';

class CommercialProfileScreen extends StatefulWidget {
  const CommercialProfileScreen({super.key});

  @override
  State<CommercialProfileScreen> createState() =>
      _CommercialProfileScreenState();
}

class _CommercialProfileScreenState extends State<CommercialProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Get.find<AppController>().fetchCommercialStats();
    });
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<AppController>(
      builder: (controller) {
        final profile = controller.profile;
        final stats = controller.commercialStats;

        return Scaffold(
          appBar: AppBar(
            title: Text('commercial_my_profile'.tr),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                onPressed: controller.isLoadingCommercialStats
                    ? null
                    : controller.fetchCommercialStats,
                tooltip: 'commercial_refresh_stats'.tr,
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: controller.fetchCommercialStats,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                KpbSpacing.pagePad,
                KpbSpacing.pagePad,
                KpbSpacing.pagePad,
                100, // clear the floating nav bar
              ),
              children: [
                // ── Avatar + nom ────────────────────────────────────────
                Center(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: KpbColors.blue,
                        child: Text(
                          profile?.fullName.isNotEmpty == true
                              ? profile!.fullName[0].toUpperCase()
                              : 'C',
                          style: KpbTextStyles.display.copyWith(
                            color: Colors.white,
                            fontSize: 32,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        profile?.fullName ?? 'commercial_default_name'.tr,
                        style: KpbTextStyles.headline,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        profile?.email ?? '',
                        style: KpbTextStyles.body.copyWith(
                          color: context.kpb.textMuted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      KpbBadge(
                        label: 'account_type_commercial'.tr,
                        color: KpbColors.blue,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ── Stats 30 jours ───────────────────────────────────────
                Text(
                  'commercial_performance_30_days'.tr,
                  style: KpbTextStyles.titleMd.copyWith(
                    color: context.kpb.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),

                controller.isLoadingCommercialStats
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: _StatCard(
                              icon: Icons.inbox_rounded,
                              value: '${stats.totalLeads}',
                              label: 'commercial_total_leads'.tr,
                              color: KpbColors.blue,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatCard(
                              icon: Icons.check_circle_rounded,
                              value: '${stats.convertedLast30Days}',
                              label: 'commercial_converted'.tr,
                              color: KpbColors.success,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatCard(
                              icon: Icons.timer_outlined,
                              value: _formatResponseTime(
                                stats.avgFirstResponseMinutes,
                              ),
                              label: 'commercial_first_response'.tr,
                              color: KpbColors.warning,
                            ),
                          ),
                        ],
                      ),

                const SizedBox(height: 24),

                // ── Taux de conversion ───────────────────────────────────
                if (!controller.isLoadingCommercialStats &&
                    stats.totalLeads > 0) ...[
                  KpbCard(
                    child: Padding(
                      padding: const EdgeInsets.all(KpbSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'commercial_conversion_rate'.tr,
                                style: KpbTextStyles.titleMd,
                              ),
                              Text(
                                '${(stats.convertedLast30Days / stats.totalLeads * 100).toStringAsFixed(1)} %',
                                style: KpbTextStyles.titleMd.copyWith(
                                  color: KpbColors.success,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: KpbRadius.smBr,
                            child: LinearProgressIndicator(
                              value:
                                  (stats.convertedLast30Days / stats.totalLeads)
                                      .clamp(0.0, 1.0),
                              minHeight: 8,
                              backgroundColor: context.kpb.gray100,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                KpbColors.success,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 24),
                ],

                // ── Actions ───────────────────────────────────────────────
                ListTile(
                  leading: Icon(Icons.logout_rounded),
                  title: Text('logout'.tr),
                  textColor: KpbColors.error,
                  iconColor: KpbColors.error,
                  shape: RoundedRectangleBorder(
                    borderRadius: KpbRadius.mdBr,
                  ),
                  onTap: () {
                    Get.dialog(
                      AlertDialog(
                        title: Text('logout_confirm_title'.tr),
                        actions: [
                          TextButton(
                            onPressed: Get.back,
                            child: Text('cancel'.tr),
                          ),
                          TextButton(
                            onPressed: () {
                              Get.back();
                              Get.find<AppController>().logout();
                            },
                            child: Text(
                              'logout_title'.tr,
                              style: TextStyle(color: KpbColors.error),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Friendly first-response time: "—" / "45 min" / "3 h" / "2 j".
String _formatResponseTime(int? minutes) {
  if (minutes == null) return '—';
  if (minutes < 60) return '$minutes min';
  if (minutes < 60 * 24) return '${(minutes / 60).round()} h';
  return '${(minutes / (60 * 24)).round()} j';
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return KpbCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: KpbSpacing.md,
          horizontal: KpbSpacing.sm,
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                maxLines: 1,
                style: KpbTextStyles.headline.copyWith(color: color),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: KpbTextStyles.caption.copyWith(
                color: context.kpb.textMuted,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
