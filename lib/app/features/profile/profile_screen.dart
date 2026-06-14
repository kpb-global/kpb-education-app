import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/config/app_routes.dart';
import '../../core/controllers/app_controller.dart';
import '../../core/models/app_models.dart';
import '../../core/ui/app_tokens.dart';
import '../../core/ui/kpb_theme_ext.dart';
import '../../core/ui/kpb_components.dart';
import '../community/community_screen.dart';
import '../legal/legal_pages.dart';
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
        if (profile == null) return const SizedBox.shrink();

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
                    label: const Text('Modifier'),
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
                      onEdit: () =>
                          _openEditSheet(context, controller),
                    ),
                    const SizedBox(height: KpbSpacing.md),

                    // ── Langue ────────────────────────────────────────
                    KpbCard(
                      padding: const EdgeInsets.all(KpbSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('preferred_language'.tr,
                              style: KpbTextStyles.titleMd),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _LangChip(
                                label: '🇫🇷  Français',
                                selected: controller.localeCode == 'fr',
                                onTap: () => controller.switchLanguage('fr'),
                              ),
                              const SizedBox(width: 10),
                              _LangChip(
                                label: '🇬🇧  English',
                                selected: controller.localeCode == 'en',
                                onTap: () => controller.switchLanguage('en'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: KpbSpacing.md),

                    // ── Apparence ─────────────────────────────────────
                    KpbCard(
                      padding: const EdgeInsets.all(KpbSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Apparence', style: KpbTextStyles.titleMd),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _ThemeModeChip(
                                icon: Icons.brightness_auto_rounded,
                                label: 'Système',
                                selected:
                                    controller.themeMode == ThemeMode.system,
                                onTap: () => controller
                                    .setThemeMode(ThemeMode.system),
                              ),
                              const SizedBox(width: 8),
                              _ThemeModeChip(
                                icon: Icons.light_mode_rounded,
                                label: 'Clair',
                                selected:
                                    controller.themeMode == ThemeMode.light,
                                onTap: () =>
                                    controller.setThemeMode(ThemeMode.light),
                              ),
                              const SizedBox(width: 8),
                              _ThemeModeChip(
                                icon: Icons.dark_mode_rounded,
                                label: 'Sombre',
                                selected:
                                    controller.themeMode == ThemeMode.dark,
                                onTap: () =>
                                    controller.setThemeMode(ThemeMode.dark),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: KpbSpacing.md),
                    
                    // ── Sécurité ──────────────────────────────────────
                    KpbCard(
                      padding: const EdgeInsets.all(KpbSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Sécurité', style: KpbTextStyles.titleMd),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.face_unlock_outlined, color: KpbColors.blue, size: 24),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Verrouillage biométrique', style: TextStyle(fontWeight: FontWeight.w600)),
                                      Text(
                                        'Protéger l\'accès à l\'application',
                                        style: TextStyle(fontSize: 12, color: context.kpb.textMuted),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              Switch.adaptive(
                                value: controller.isAppLockEnabled,
                                activeTrackColor: KpbColors.blue,
                                onChanged: (val) => controller.toggleAppLock(val),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: KpbSpacing.md),

                    // ── Infos académiques ─────────────────────────────
                    const Text('Informations académiques',
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
                              value: profile.currentLevel!,
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
                    const Text('Contact', style: KpbTextStyles.title),
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

                    // ── Bourse ────────────────────────────────────────
                    if (profile.wantsScholarshipSupport) ...[
                      KpbCard(
                        padding: const EdgeInsets.all(KpbSpacing.md),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: context.kpb.goldLight,
                                borderRadius: KpbRadius.mdBr,
                              ),
                              child: const Icon(
                                Icons.workspace_premium_outlined,
                                color: KpbColors.gold,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'scholarship_interest'.tr,
                                style: KpbTextStyles.titleMd,
                              ),
                            ),
                            const Icon(
                              Icons.check_circle_rounded,
                              color: KpbColors.success,
                              size: 22,
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: KpbSpacing.lg),

                    // ── Accès rapide ──────────────────────────────────
                    const Text('Accès rapide', style: KpbTextStyles.title),
                    const SizedBox(height: KpbSpacing.sm),
                    KpbCard(
                      child: Column(
                        children: [
                          if (controller.isStudent) ...[
                            _QuickAccessTile(
                              icon: Icons.psychology_outlined,
                              label: 'Test d\'orientation',
                              color: KpbColors.blue,
                              onTap: () =>
                                  Get.to(() => const OrientationScreen()),
                            ),
                            const KpbDivider(indent: 52),
                            _QuickAccessTile(
                              icon: Icons.workspace_premium_outlined,
                              label: 'Bourses disponibles',
                              color: KpbColors.gold,
                              onTap: () =>
                                  Get.toNamed(AppRoutes.scholarships),
                            ),
                            const KpbDivider(indent: 52),
                            _QuickAccessTile(
                              icon: Icons.bookmark_outlined,
                              label: 'Éléments sauvegardés',
                              color: KpbColors.sky,
                              onTap: () =>
                                  Get.to(() => const SavedScreen()),
                            ),
                            const KpbDivider(indent: 52),
                            _QuickAccessTile(
                              icon: Icons.account_balance_wallet_outlined,
                              label: 'Calculateur de Budget',
                              color: KpbColors.success,
                              onTap: () =>
                                  Get.to(() => const BudgetCalculatorScreen()),
                            ),
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
                              color: KpbColors.stitchDeepPurple,
                              onTap: () =>
                                  Get.to(() => const HousingEstimatorScreen()),
                            ),
                            const KpbDivider(indent: 52),
                          ],
                          _QuickAccessTile(
                            icon: Icons.forum_outlined,

                            label: 'Communauté & Articles',
                            color: KpbColors.sky,
                            onTap: () =>
                                Get.to(() => const CommunityScreen()),
                          ),
                          const KpbDivider(indent: 52),
                          // Parent mode is reachable from both student and
                          // parent accounts — students can use it to accept
                          // a code sent to them by a parent.
                          _QuickAccessTile(
                            icon: Icons.family_restroom,
                            label: controller.isParent
                                ? 'Espace parent'
                                : 'Mode parent',
                            color: KpbColors.stitchDeepPurple,
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
                            color: KpbColors.stitchCyberCyan,
                            onTap: () => Get.to(() => const SalonScreen()),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: KpbSpacing.md),

                    // ── Legal ──────────────────────────────────────────
                    const Text('Informations légales', style: KpbTextStyles.title),
                    const SizedBox(height: KpbSpacing.sm),
                    KpbCard(
                      child: Column(
                        children: [
                          _QuickAccessTile(
                            icon: Icons.privacy_tip_outlined,
                            label: 'Politique de confidentialité',
                            color: context.kpb.textSecondary,
                            onTap: () => Get.to(
                                () => const PrivacyPolicyScreen()),
                          ),
                          const KpbDivider(indent: 52),
                          _QuickAccessTile(
                            icon: Icons.description_outlined,
                            label: 'Conditions d\'utilisation',
                            color: context.kpb.textSecondary,
                            onTap: () => Get.to(
                                () => const TermsOfServiceScreen()),
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
                        label: const Text('Se déconnecter'),
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
        title: const Text('Se déconnecter ?'),
        content: const Text(
          'Vous serez redirigé vers l\'écran d\'accueil. Vos données locales seront effacées.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              controller.logout();
            },
            style: FilledButton.styleFrom(
              backgroundColor: KpbColors.error,
            ),
            child: const Text('Se déconnecter'),
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

class _ProfileEditSheetState extends State<_ProfileEditSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _whatsappCtrl;
  late TextEditingController _countryCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.controller.profile!;
    _nameCtrl = TextEditingController(text: p.fullName);
    _phoneCtrl = TextEditingController(text: p.phone);
    _whatsappCtrl = TextEditingController(text: p.whatsApp);
    _countryCtrl = TextEditingController(text: p.countryOfResidence);
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
              const Text('Modifier le profil', style: KpbTextStyles.headline),
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
                    : const Text('Enregistrer'),
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
              const Text('Profil complété', style: KpbTextStyles.titleMd),
              const Spacer(),
              Text(
                '$completion%',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: KpbColors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
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
            const SizedBox(height: 12),
            const Row(
              children: [
                Icon(Icons.check_circle_rounded,
                    color: KpbColors.success, size: 16),
                SizedBox(width: 6),
                Text(
                  'Profil complet — recommandations optimisées ✨',
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
                child: const Text('Compléter mon profil'),
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
        impact: 'Améliore la précision de tes recommandations de bourses',
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
class _LangChip extends StatelessWidget {
  const _LangChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? KpbColors.blue : context.kpb.gray100,
          borderRadius: KpbRadius.mdBr,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : context.kpb.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _ThemeModeChip extends StatelessWidget {
  const _ThemeModeChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? KpbColors.blue : context.kpb.gray100,
            borderRadius: KpbRadius.mdBr,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? Colors.white : context.kpb.textSecondary,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color:
                      selected ? Colors.white : context.kpb.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
      padding: const EdgeInsets.symmetric(
          horizontal: KpbSpacing.md, vertical: 12),
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
        padding: const EdgeInsets.symmetric(
            horizontal: KpbSpacing.md, vertical: 14),
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
