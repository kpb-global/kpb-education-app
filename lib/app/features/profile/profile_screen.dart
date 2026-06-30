import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/config/app_config.dart';
import '../../core/controllers/app_controller.dart';
import '../../core/navigation/app_boot_screen.dart';
import '../../core/models/app_models.dart';
import '../../core/ui/kpb_components.dart';
import '../../core/utils/study_level.dart';
import '../community/community_screen.dart';
import '../eligibility/eligibility_simulator_screen.dart';
import '../parcours/parcours_screen.dart';
import '../referral/referral_screen.dart';
import '../legal/legal_pages.dart';
import '../onboarding/onboarding_m2_constants.dart';
import '../orientation/orientation_screen.dart';
import '../budget/budget_calculator_screen.dart';
import '../travel/flight_estimator_screen.dart';
import '../housing/housing_estimator_screen.dart';
import '../parent/parent_dashboard_screen.dart';
import '../saved/saved_screen.dart';
import '../services/service_packages_screen.dart';
import '../alumni/alumni_directory_screen.dart';
import '../alumni/alumni_apply_screen.dart';
import '../salon/salon_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AppController>();

    return GetBuilder<AppController>(
      builder: (_) {
        final profile = controller.profile;
        if (profile == null) {
          return _GuestProfilePrompt(controller: controller);
        }

        final completion = (profile.completionScore * 100).round();
        final initials = _initials(profile.fullName);

        return CustomScrollView(
          slivers: [
            // ── App Bar ──────────────────────────────────────────────
            SliverAppBar(
              floating: true,
              snap: true,
              backgroundColor: context.kpb.pageBg,
              title: Text('profile'.tr, style: KpbTextStyles.headline),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: KpbSpacing.md),
                  child: TextButton.icon(
                    onPressed: () => _openEditSheet(context, controller),
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: Text('profile_edit'.tr),
                  ),
                ),
              ],
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(KpbSpacing.pagePad),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Hero Card ─────────────────────────────────────
                    GradientHeroCard(
                      padding: const EdgeInsets.all(KpbSpacing.lg),
                      child: Row(
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: KpbRadius.xlBr,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.4),
                                width: 2,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                initials,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: KpbSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  profile.fullName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  profile.email,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.8),
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                KpbBadge(
                                  label: _accountTypeLabel(profile.accountType),
                                  color: Colors.white.withValues(alpha: 0.2),
                                ),
                              ],
                            ),
                          ),
                          CompletionRing(value: profile.completionScore),
                        ],
                      ),
                    ),
                    const SizedBox(height: KpbSpacing.sm),

                    // Completion guide (contextual)
                    _ProfileCompletionGuide(
                      profile: profile,
                      completion: completion,
                      onEdit: () => _openEditSheet(context, controller),
                    ),
                    const SizedBox(height: KpbSpacing.md),

                    // ── Sécurité ──────────────────────────────────────
                    KpbCard(
                      padding: const EdgeInsets.all(KpbSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('profile_security'.tr,
                              style: KpbTextStyles.titleMd),
                          SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Icon(Icons.face_unlock_outlined,
                                        color: KpbColors.blue, size: 24),
                                    SizedBox(width: 12),
                                    Flexible(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text('profile_biometric'.tr,
                                              style: TextStyle(
                                                  fontWeight: FontWeight.w600)),
                                          Text(
                                            'protect_app_access'.tr,
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: context.kpb.textMuted),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Switch.adaptive(
                                value: controller.isAppLockEnabled,
                                activeTrackColor: KpbColors.blue,
                                onChanged: (val) =>
                                    controller.toggleAppLock(val),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          // ── Data saver (low-bandwidth mode) ──────────────
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    const Icon(Icons.data_saver_on_rounded,
                                        color: KpbColors.success, size: 24),
                                    const SizedBox(width: 12),
                                    Flexible(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text('profile_data_saver'.tr,
                                              style: TextStyle(
                                                  fontWeight: FontWeight.w600)),
                                          Text(
                                            'Economise la data (masque les images lourdes)',
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: context.kpb.textMuted),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Switch.adaptive(
                                value: controller.dataSaverEnabled,
                                activeTrackColor: KpbColors.success,
                                onChanged: (val) =>
                                    controller.toggleDataSaver(val),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          // ── App language (FR / EN) ───────────────────────
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    const Icon(Icons.translate_rounded,
                                        color: KpbColors.blue, size: 24),
                                    const SizedBox(width: 12),
                                    Flexible(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text('app_language'.tr,
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w600)),
                                          Text(
                                            controller.localeCode
                                                    .startsWith('en')
                                                ? 'English'
                                                : 'Français',
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: context.kpb.textMuted),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              _LanguageToggle(
                                current: controller.localeCode,
                                onChanged: controller.switchLanguage,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: KpbSpacing.md),

                    // ── Infos académiques ─────────────────────────────
                    Text('profile_academic_info'.tr,
                        style: KpbTextStyles.title),
                    const SizedBox(height: KpbSpacing.sm),
                    KpbCard(
                      child: Column(
                        children: [
                          _InfoTile(
                            icon: Icons.public_outlined,
                            label: 'country'.tr,
                            value: profile.countryOfResidence,
                            iconColor: KpbColors.blue,
                          ),
                          if (profile.currentLevel != null) ...[
                            const KpbDivider(indent: 52),
                            _InfoTile(
                              icon: Icons.school_outlined,
                              label: 'current_level'.tr,
                              value: studentLevelLabel(profile.currentLevel),
                              iconColor: KpbColors.sky,
                            ),
                          ],
                          if (profile.targetLevel != null) ...[
                            const KpbDivider(indent: 52),
                            _InfoTile(
                              icon: Icons.trending_up_rounded,
                              label: 'target_level'.tr,
                              value: profile.targetLevel!,
                              iconColor: KpbColors.success,
                            ),
                          ],
                          if (profile.languageLevel != null) ...[
                            const KpbDivider(indent: 52),
                            _InfoTile(
                              icon: Icons.translate_outlined,
                              label: 'language_level'.tr,
                              value: profile.languageLevel!,
                              iconColor: KpbColors.gold,
                            ),
                          ],
                          if ((profile.gradeRange ?? '').isNotEmpty) ...[
                            const KpbDivider(indent: 52),
                            _InfoTile(
                              icon: Icons.grade_outlined,
                              label: 'grade_range'.tr,
                              value: profile.gradeRange!,
                              iconColor: KpbColors.medRed,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: KpbSpacing.md),

                    // ── Contact ───────────────────────────────────────
                    Text('profile_contact'.tr, style: KpbTextStyles.title),
                    const SizedBox(height: KpbSpacing.sm),
                    KpbCard(
                      child: Column(
                        children: [
                          _InfoTile(
                            icon: Icons.phone_outlined,
                            label: 'phone'.tr,
                            value: profile.phone,
                            iconColor: KpbColors.success,
                          ),
                          if (profile.whatsApp.isNotEmpty &&
                              profile.whatsApp != profile.phone) ...[
                            const KpbDivider(indent: 52),
                            _InfoTile(
                              icon: Icons.chat_outlined,
                              label: 'WhatsApp',
                              value: profile.whatsApp,
                              iconColor: KpbColors.success,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: KpbSpacing.md),

                    // ── Documents disponibles ─────────────────────────
                    if (profile.availableDocuments.isNotEmpty) ...[
                      Text('available_documents'.tr,
                          style: KpbTextStyles.title),
                      const SizedBox(height: KpbSpacing.sm),
                      KpbCard(
                        padding: const EdgeInsets.all(KpbSpacing.md),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: profile.availableDocuments
                              .map(
                                (doc) => KpbBadgeLight(
                                  label: _docLabel(doc),
                                  bgColor: KpbColors.successLight,
                                  textColor: KpbColors.success,
                                  icon: Icons.check_circle_outline_rounded,
                                ),
                              )
                              .toList(),
                        ),
                      ),
                      const SizedBox(height: KpbSpacing.md),
                    ],

                    const SizedBox(height: KpbSpacing.lg),

                    // ── Accès rapide ──────────────────────────────────
                    Text('profile_quick_access'.tr, style: KpbTextStyles.title),
                    const SizedBox(height: KpbSpacing.sm),
                    KpbCard(
                      child: Column(
                        children: [
                          if (controller.isStudent) ...[
                            _QuickAccessTile(
                              icon: Icons.card_giftcard_outlined,
                              label: 'referral_title'.tr,
                              color: KpbColors.gold,
                              onTap: () => Get.to(() => const ReferralScreen()),
                            ),
                            const KpbDivider(indent: 52),
                            _QuickAccessTile(
                              icon: Icons.psychology_outlined,
                              label: 'Test d\'orientation',
                              color: KpbColors.blue,
                              onTap: () =>
                                  Get.to(() => const OrientationScreen()),
                            ),
                            const KpbDivider(indent: 52),
                            _QuickAccessTile(
                              icon: Icons.fact_check_outlined,
                              label: 'Simulateur d\'éligibilité',
                              color: KpbColors.warning,
                              onTap: () => Get.to(
                                  () => const EligibilitySimulatorScreen()),
                            ),
                            const KpbDivider(indent: 52),
                            _QuickAccessTile(
                              icon: Icons.play_circle_outline_rounded,
                              label: 'Parcours & témoignages',
                              color: KpbColors.error,
                              onTap: () => Get.to(() => const ParcoursScreen()),
                            ),
                            const KpbDivider(indent: 52),
                            _QuickAccessTile(
                              icon: Icons.bookmark_outlined,
                              label: 'Éléments sauvegardés',
                              color: KpbColors.sky,
                              onTap: () => Get.to(() => const SavedScreen()),
                            ),
                            const KpbDivider(indent: 52),
                            _QuickAccessTile(
                              icon: Icons.account_balance_wallet_outlined,
                              label: 'Calculateur de Budget',
                              color: KpbColors.success,
                              onTap: () =>
                                  Get.to(() => const BudgetCalculatorScreen()),
                            ),
                            // Travel & housing estimators are V1.1+ modules.
                            if (!AppConfig.mvpOnly) ...[
                              const KpbDivider(indent: 52),
                              _QuickAccessTile(
                                icon: Icons.flight_takeoff_rounded,
                                label: 'Simulateur de Vols (Kayak)',
                                color: KpbColors.sky,
                                onTap: () =>
                                    Get.to(() => const FlightEstimatorScreen()),
                              ),
                              const KpbDivider(indent: 52),
                              _QuickAccessTile(
                                icon: Icons.holiday_village_rounded,
                                label: 'Logement Étudiant (France)',
                                color: KpbColors.blueMid,
                                onTap: () => Get.to(
                                    () => const HousingEstimatorScreen()),
                              ),
                            ],
                            const KpbDivider(indent: 52),
                          ],
                          // Community/forum is a V1.1+ module.
                          if (!AppConfig.mvpOnly) ...[
                            _QuickAccessTile(
                              icon: Icons.forum_outlined,
                              label: 'Communauté & Articles',
                              color: KpbColors.sky,
                              onTap: () =>
                                  Get.to(() => const CommunityScreen()),
                            ),
                            const KpbDivider(indent: 52),
                          ],
                          // Parent mode is reachable from both student and
                          // parent accounts — students can use it to accept
                          // a code sent to them by a parent.
                          _QuickAccessTile(
                            icon: Icons.family_restroom,
                            label: controller.isParent
                                ? 'Espace parent'
                                : 'Mode parent',
                            color: KpbColors.gold,
                            onTap: () =>
                                Get.to(() => const ParentDashboardScreen()),
                          ),
                          const KpbDivider(indent: 52),
                          // Phase 3 — Monetized bundles: "Dossier prêt",
                          // scholarship & visa kits, consultations.
                          _QuickAccessTile(
                            icon: Icons.workspace_premium_outlined,
                            label: 'Services KPB (Dossier prêt)',
                            color: KpbColors.navy,
                            onTap: () =>
                                Get.to(() => const ServicePackagesScreen()),
                          ),
                          // Alumni mentors & virtual salon are V1.1+ modules.
                          if (!AppConfig.mvpOnly) ...[
                            const KpbDivider(indent: 52),
                            _QuickAccessTile(
                              icon: Icons.school_outlined,
                              label: 'Mentors alumni vérifiés',
                              color: KpbColors.primary,
                              onTap: () =>
                                  Get.to(() => const AlumniDirectoryScreen()),
                            ),
                            const KpbDivider(indent: 52),
                            _QuickAccessTile(
                              icon: Icons.verified_outlined,
                              label: 'Devenir mentor alumni',
                              color: KpbColors.primary,
                              onTap: () =>
                                  Get.to(() => const AlumniApplyScreen()),
                            ),
                            const KpbDivider(indent: 52),
                            _QuickAccessTile(
                              icon: Icons.event,
                              label: 'Salon KPB Virtuel',
                              color: KpbColors.blue,
                              onTap: () => Get.to(() => const SalonScreen()),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: KpbSpacing.md),

                    // ── Legal ──────────────────────────────────────────
                    Text('profile_legal_info'.tr, style: KpbTextStyles.title),
                    const SizedBox(height: KpbSpacing.sm),
                    KpbCard(
                      child: Column(
                        children: [
                          _QuickAccessTile(
                            icon: Icons.privacy_tip_outlined,
                            label: 'Politique de confidentialité',
                            color: context.kpb.textSecondary,
                            onTap: () =>
                                Get.to(() => const PrivacyPolicyScreen()),
                          ),
                          const KpbDivider(indent: 52),
                          _QuickAccessTile(
                            icon: Icons.description_outlined,
                            label: 'Conditions d\'utilisation',
                            color: context.kpb.textSecondary,
                            onTap: () =>
                                Get.to(() => const TermsOfServiceScreen()),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: KpbSpacing.lg),

                    // ── Mes données / RGPD ─────────────────────────────
                    Text('data_rights_section'.tr, style: KpbTextStyles.title),
                    const SizedBox(height: KpbSpacing.sm),
                    KpbCard(
                      child: Column(
                        children: [
                          _QuickAccessTile(
                            icon: Icons.download_outlined,
                            label: 'export_data'.tr,
                            color: context.kpb.textSecondary,
                            onTap: () => _exportData(context, controller),
                          ),
                          const KpbDivider(indent: 52),
                          _QuickAccessTile(
                            icon: Icons.delete_outline_rounded,
                            label: 'delete_account'.tr,
                            color: KpbColors.error,
                            onTap: () =>
                                _confirmDeleteAccount(context, controller),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: KpbSpacing.lg),

                    // ── Logout ────────────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _confirmLogout(context, controller),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: KpbColors.error,
                          side: const BorderSide(color: KpbColors.error),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        icon: const Icon(Icons.logout_rounded, size: 18),
                        label: Text('logout'.tr),
                      ),
                    ),

                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _confirmLogout(BuildContext context, AppController controller) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('logout_confirm_title'.tr),
        content: Text(
          'logout_redirect_notice'.tr,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('cancel'.tr),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await controller.logout();
              Get.offAll(() => const AppBootScreen());
            },
            style: FilledButton.styleFrom(
              backgroundColor: KpbColors.error,
            ),
            child: Text('logout'.tr),
          ),
        ],
      ),
    );
  }

  Future<void> _exportData(
      BuildContext context, AppController controller) async {
    try {
      final data = await controller.exportData();
      const encoder = JsonEncoder.withIndent('  ');
      await SharePlus.instance.share(
        ShareParams(
          text: encoder.convert(data),
          subject: 'export_data_subject'.tr,
        ),
      );
    } catch (_) {
      Get.snackbar(
        'data_rights_section'.tr,
        'export_data_error'.tr,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  void _confirmDeleteAccount(BuildContext context, AppController controller) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('delete_account_confirm_title'.tr),
        content: Text('delete_account_confirm_body'.tr),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('cancel'.tr),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await controller.deleteAccount();
                Get.offAll(() => const AppBootScreen());
              } catch (_) {
                Get.snackbar(
                  'delete_account'.tr,
                  'delete_account_error'.tr,
                  snackPosition: SnackPosition.BOTTOM,
                );
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: KpbColors.error,
            ),
            child: Text('delete_account_cta'.tr),
          ),
        ],
      ),
    );
  }

  void _openEditSheet(BuildContext context, AppController controller) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _ProfileEditSheet(controller: controller),
    );
  }

  String _initials(String fullName) {
    final parts = fullName.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
      return parts[0][0].toUpperCase();
    }
    return '?';
  }

  String _accountTypeLabel(dynamic type) {
    switch (type.toString()) {
      case 'AccountType.student':
        return 'Étudiant';
      case 'AccountType.parent':
        return 'Parent';
      case 'AccountType.partner':
        return 'Partenaire';
      case 'AccountType.commercial':
        return 'Commercial';
      default:
        return type.toString();
    }
  }

  String _docLabel(String doc) {
    const map = {
      'Passport': 'Passeport',
      'CV': 'CV',
      'Transcripts': 'Relevés de notes',
      'Test score': 'Score de test',
    };
    return map[doc] ?? doc;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Profile Edit Sheet
// ─────────────────────────────────────────────────────────────────────────────
class _ProfileEditSheet extends StatefulWidget {
  const _ProfileEditSheet({required this.controller});
  final AppController controller;

  @override
  State<_ProfileEditSheet> createState() => _ProfileEditSheetState();
}

/// Documents the student can flag as available, in display order.
/// Keys match `_docLabel` and the `availableDocuments` payload field.
const _kEditableDocuments = <String>[
  'Passport',
  'CV',
  'Transcripts',
  'Test score'
];

class _ProfileEditSheetState extends State<_ProfileEditSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _whatsappCtrl;
  late TextEditingController _countryCtrl;
  String? _currentLevel;
  String? _bacSeries;
  late Set<String> _countryIds;
  late Set<String> _documents;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.controller.profile!;
    _nameCtrl = TextEditingController(text: p.fullName);
    _phoneCtrl = TextEditingController(text: p.phone);
    _whatsappCtrl = TextEditingController(text: p.whatsApp);
    _countryCtrl = TextEditingController(text: p.countryOfResidence);
    // Normalise legacy/raw levels ("L1", "M1"…) to a canonical label so the
    // dropdown selects the right item instead of resetting to null.
    _currentLevel = normalizeStudentLevel(p.currentLevel)?.labelFr;
    _bacSeries = onboardingBacSeries.contains(p.bacSeries) ? p.bacSeries : null;
    _countryIds = p.targetCountryIds.toSet();
    _documents = p.availableDocuments.toSet();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _whatsappCtrl.dispose();
    _countryCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollController) => Padding(
        padding: EdgeInsets.fromLTRB(
          KpbSpacing.lg,
          KpbSpacing.md,
          KpbSpacing.lg,
          MediaQuery.of(context).viewInsets.bottom + KpbSpacing.lg,
        ),
        child: Form(
          key: _formKey,
          child: ListView(
            controller: scrollController,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: KpbSpacing.md),
                  decoration: BoxDecoration(
                    color: context.kpb.gray300,
                    borderRadius: KpbRadius.pillBr,
                  ),
                ),
              ),
              Text('profile_edit_title'.tr, style: KpbTextStyles.headline),
              const SizedBox(height: KpbSpacing.lg),

              _EditField(
                label: 'Nom complet',
                controller: _nameCtrl,
                icon: Icons.person_outline_rounded,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Requis' : null,
              ),
              const SizedBox(height: KpbSpacing.md),
              _EditField(
                label: 'Téléphone',
                controller: _phoneCtrl,
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: KpbSpacing.md),
              _EditField(
                label: 'WhatsApp',
                controller: _whatsappCtrl,
                icon: Icons.chat_outlined,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: KpbSpacing.md),
              _EditField(
                label: 'Pays de résidence',
                controller: _countryCtrl,
                icon: Icons.public_outlined,
              ),
              const SizedBox(height: KpbSpacing.xl),

              // ── Mon parcours ────────────────────────────────────────
              Text('profile_my_journey'.tr, style: KpbTextStyles.headline),
              const SizedBox(height: KpbSpacing.md),
              DropdownButtonFormField<String>(
                initialValue: _currentLevel,
                isExpanded: true,
                decoration: _dropdownDecoration(
                  context,
                  'Niveau d\'études actuel',
                  Icons.school_outlined,
                ),
                items: onboardingStudyLevels
                    .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                    .toList(),
                onChanged: (v) => setState(() {
                  _currentLevel = v;
                  if (v == null || !studyLevelNeedsBacSeries(v)) {
                    _bacSeries = null;
                  }
                }),
              ),
              if (_currentLevel != null &&
                  studyLevelNeedsBacSeries(_currentLevel!)) ...[
                const SizedBox(height: KpbSpacing.md),
                DropdownButtonFormField<String>(
                  initialValue: _bacSeries,
                  isExpanded: true,
                  decoration: _dropdownDecoration(
                    context,
                    'Série du bac',
                    Icons.workspace_premium_outlined,
                  ),
                  items: onboardingBacSeries
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) => setState(() => _bacSeries = v),
                ),
              ],
              const SizedBox(height: KpbSpacing.lg),

              // ── Pays visés ──────────────────────────────────────────
              Text('profile_target_countries'.tr,
                  style: KpbTextStyles.headline),
              const SizedBox(height: KpbSpacing.sm),
              Wrap(
                spacing: KpbSpacing.sm,
                runSpacing: KpbSpacing.sm,
                children: onboardingDestinations.map((d) {
                  final selected = _countryIds.contains(d.id);
                  return FilterChip(
                    label: Text('${d.flag} ${d.labelFr}'),
                    selected: selected,
                    onSelected: (on) => setState(() {
                      if (on) {
                        _countryIds.add(d.id);
                      } else {
                        _countryIds.remove(d.id);
                      }
                    }),
                  );
                }).toList(),
              ),
              const SizedBox(height: KpbSpacing.lg),

              // ── Mes documents ───────────────────────────────────────
              Text('available_documents'.tr, style: KpbTextStyles.headline),
              const SizedBox(height: KpbSpacing.sm),
              Wrap(
                spacing: KpbSpacing.sm,
                runSpacing: KpbSpacing.sm,
                children: _kEditableDocuments.map((doc) {
                  final selected = _documents.contains(doc);
                  return FilterChip(
                    label: Text(_editDocLabel(doc)),
                    selected: selected,
                    onSelected: (on) => setState(() {
                      if (on) {
                        _documents.add(doc);
                      } else {
                        _documents.remove(doc);
                      }
                    }),
                  );
                }).toList(),
              ),
              const SizedBox(height: KpbSpacing.xl),

              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text('save_changes'.tr),
              ),
              const SizedBox(height: KpbSpacing.md),
            ],
          ),
        ),
      ),
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final updated = widget.controller.profile!.copyWith(
      fullName: _nameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      whatsApp: _whatsappCtrl.text.trim(),
      countryOfResidence: _countryCtrl.text.trim(),
      currentLevel: _currentLevel,
      bacSeries: _bacSeries,
      targetCountryIds: _countryIds.toList(),
      availableDocuments: _documents.toList(),
    );
    widget.controller.updateProfile(updated);
    Navigator.pop(context);
    Get.snackbar(
      'Profil mis à jour',
      'Vos informations ont été sauvegardées.',
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(KpbSpacing.md),
      backgroundColor: KpbColors.successLight,
      colorText: KpbColors.success,
      duration: const Duration(seconds: 2),
    );
  }

  InputDecoration _dropdownDecoration(
    BuildContext context,
    String label,
    IconData icon,
  ) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20),
      border: OutlineInputBorder(
        borderRadius: KpbRadius.mdBr,
        borderSide: BorderSide(color: context.kpb.gray200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: KpbRadius.mdBr,
        borderSide: BorderSide(color: context.kpb.gray200),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: KpbRadius.mdBr,
        borderSide: BorderSide(color: KpbColors.blue, width: 2),
      ),
      filled: true,
      fillColor: context.kpb.gray50,
    );
  }

  String _editDocLabel(String doc) {
    const map = {
      'Passport': 'Passeport',
      'CV': 'CV',
      'Transcripts': 'Relevés de notes',
      'Test score': 'Score de test',
    };
    return map[doc] ?? doc;
  }
}

class _EditField extends StatelessWidget {
  const _EditField({
    required this.label,
    required this.controller,
    required this.icon,
    this.keyboardType,
    this.validator,
  });

  final String label;
  final TextEditingController controller;
  final IconData icon;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(
          borderRadius: KpbRadius.mdBr,
          borderSide: BorderSide(color: context.kpb.gray200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: KpbRadius.mdBr,
          borderSide: BorderSide(color: context.kpb.gray200),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: KpbRadius.mdBr,
          borderSide: BorderSide(color: KpbColors.blue, width: 2),
        ),
        filled: true,
        fillColor: context.kpb.gray50,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Profile Completion Guide — contextual missing fields
// ─────────────────────────────────────────────────────────────────────────────
class _ProfileCompletionGuide extends StatelessWidget {
  const _ProfileCompletionGuide({
    required this.profile,
    required this.completion,
    required this.onEdit,
  });

  final UserProfile profile;
  final int completion;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final missing = _missingFields(profile);

    return KpbCard(
      padding: const EdgeInsets.all(KpbSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('profile_completed'.tr, style: KpbTextStyles.titleMd),
              Spacer(),
              Text(
                '$completion%',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: KpbColors.blue,
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          ClipRRect(
            borderRadius: KpbRadius.pillBr,
            child: LinearProgressIndicator(
              value: profile.completionScore,
              minHeight: 8,
              backgroundColor: context.kpb.gray100,
              valueColor: AlwaysStoppedAnimation(
                completion >= 80 ? KpbColors.success : KpbColors.blue,
              ),
            ),
          ),
          if (completion >= 100) ...[
            SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.check_circle_rounded,
                    color: KpbColors.success, size: 16),
                SizedBox(width: 6),
                Text(
                  'profile_complete_optimized'.tr,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: KpbColors.success,
                  ),
                ),
              ],
            ),
          ] else if (missing.isNotEmpty) ...[
            const SizedBox(height: 14),
            ...missing.map((m) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.radio_button_unchecked,
                          size: 16, color: context.kpb.gray300),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              m.field,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: context.kpb.textPrimary,
                              ),
                            ),
                            Text(
                              m.impact,
                              style: TextStyle(
                                fontSize: 12,
                                color: context.kpb.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onEdit,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  textStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700),
                ),
                child: Text('profile_complete_cta'.tr),
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<({String field, String impact})> _missingFields(UserProfile p) {
    final result = <({String field, String impact})>[];
    if ((p.gradeRange ?? '').isEmpty) {
      result.add((
        field: 'Moyenne académique',
        impact: 'Améliore la précision de tes recommandations d\'écoles',
      ));
    }
    if (p.currentLevel == null) {
      result.add((
        field: 'Niveau d\'études actuel',
        impact: 'Indispensable pour matcher les programmes disponibles',
      ));
    }
    if (p.targetLevel == null) {
      result.add((
        field: 'Niveau cible',
        impact: 'Aide les conseillers à orienter ton dossier',
      ));
    }
    if (p.availableDocuments.isEmpty) {
      result.add((
        field: 'Documents disponibles',
        impact: 'Nos conseillers en ont besoin pour évaluer ton dossier',
      ));
    }
    if (p.languageLevel == null) {
      result.add((
        field: 'Niveau de langue',
        impact: 'Certaines universités ont des seuils minimum',
      ));
    }
    return result.take(3).toList(); // Show max 3 at a time
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────
class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.iconColor,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(horizontal: KpbSpacing.md, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: KpbRadius.smBr,
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: KpbTextStyles.caption),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: context.kpb.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Quick Access Tile
// ─────────────────────────────────────────────────────────────────────────────
class _QuickAccessTile extends StatelessWidget {
  const _QuickAccessTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: KpbRadius.mdBr,
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: KpbSpacing.md, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: KpbRadius.smBr,
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label, style: KpbTextStyles.titleMd),
            ),
            Icon(Icons.chevron_right_rounded,
                color: context.kpb.gray300, size: 20),
          ],
        ),
      ),
    );
  }
}

class _GuestProfilePrompt extends StatelessWidget {
  const _GuestProfilePrompt({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          floating: true,
          snap: true,
          backgroundColor: context.kpb.pageBg,
          title: Text('profile'.tr, style: KpbTextStyles.headline),
        ),
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: const EdgeInsets.all(KpbSpacing.pagePad),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.person_outline_rounded,
                    size: 64, color: context.kpb.gray300),
                const SizedBox(height: KpbSpacing.lg),
                Text(
                  'auth_guest_profile_title'.tr,
                  textAlign: TextAlign.center,
                  style: KpbTextStyles.headline,
                ),
                const SizedBox(height: KpbSpacing.sm),
                Text(
                  'auth_guest_profile_body'.tr,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.kpb.textMuted, height: 1.4),
                ),
                const SizedBox(height: KpbSpacing.xl),
                FilledButton(
                  onPressed: () {
                    controller.isGuestMode = false;
                    controller.hasCompletedOnboarding = false;
                    controller.update();
                    Get.offAll(() => const AppBootScreen());
                  },
                  child: Text('auth_continue_email'.tr),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Compact FR | EN segmented control for the app display language.
class _LanguageToggle extends StatelessWidget {
  const _LanguageToggle({required this.current, required this.onChanged});

  final String current;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _segment(context, 'FR', 'fr'),
        const SizedBox(width: 8),
        _segment(context, 'EN', 'en'),
      ],
    );
  }

  Widget _segment(BuildContext context, String label, String code) {
    final selected = current.startsWith(code);
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: selected ? null : () => onChanged(code),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? KpbColors.blue : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? KpbColors.blue : context.kpb.gray300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: selected ? Colors.white : context.kpb.textMuted,
          ),
        ),
      ),
    );
  }
}
