import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/controllers/app_controller.dart';
import '../../core/models/app_models.dart';
import '../../core/services/onesignal_service.dart';
import '../../core/ui/kpb_components.dart';
import 'onboarding_m2_constants.dart';

/// M2 — Onboarding post-auth en 6 étapes (spec §5.2).
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _totalSteps = 6;

  late final PageController _pageController;
  late int _page;

  AccountType _accountType = AccountType.student;
  String _studyLevel = onboardingStudyLevels.first;
  String? _bacSeries;
  final Set<String> _countryIds = {};
  double _monthlyBudget = 600;

  AppController get _ctrl => Get.find<AppController>();

  bool get _isStudentLike =>
      _accountType == AccountType.student ||
      _accountType == AccountType.parent;

  @override
  void initState() {
    super.initState();
    _restoreFromProfile();
    _page = _ctrl.onboardingStep.clamp(0, _totalSteps - 1);
    _pageController = PageController(initialPage: _page);
  }

  void _restoreFromProfile() {
    final profile = _ctrl.profile;
    if (profile == null) return;
    _accountType = profile.accountType;
    if ((profile.currentLevel ?? '').isNotEmpty) {
      _studyLevel = profile.currentLevel!;
    }
    _bacSeries = profile.bacSeries ?? profile.gradeRange;
    _countryIds
      ..clear()
      ..addAll(profile.targetCountryIds);
    if (profile.monthlyBudgetEur != null) {
      _monthlyBudget = profile.monthlyBudgetEur!.toDouble();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  UserProfile _buildProfile() {
    final existing = _ctrl.profile;
    final isStudentLike =
        _accountType == AccountType.student ||
        _accountType == AccountType.parent;

    return UserProfile(
      id: existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      accountType: _accountType,
      fullName: existing?.fullName ?? '',
      email: existing?.email ?? '',
      phone: existing?.phone ?? '',
      whatsApp: existing?.whatsApp ?? '',
      countryOfResidence: existing?.countryOfResidence ?? '',
      preferredLanguage: existing?.preferredLanguage ?? _ctrl.localeCode,
      currentLevel: isStudentLike ? _studyLevel : existing?.currentLevel,
      bacSeries: isStudentLike && studyLevelNeedsBacSeries(_studyLevel)
          ? _bacSeries
          : null,
      gradeRange: _bacSeries,
      targetCountryIds: _countryIds.toList(),
      monthlyBudgetEur: _monthlyBudget.round(),
      fieldIds: existing?.fieldIds ?? const [],
      consentedAt: existing?.consentedAt ?? DateTime.now(),
    );
  }

  void _persistStep(int nextPage) {
    _ctrl.saveOnboardingProgress(nextPage, _buildProfile());
  }

  Future<void> _next() async {
    if (_page == 0 && _accountType == AccountType.student) {
      // step 1 valid by default
    }
    if (_page == 1 &&
        (_accountType == AccountType.student ||
            _accountType == AccountType.parent) &&
        _studyLevel.isEmpty) {
      return;
    }

    if (_page < _totalSteps - 1) {
      final nextPage = _page + 1;
      _persistStep(nextPage);
      await _pageController.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOut,
      );
      setState(() => _page = nextPage);
      return;
    }

    await _finish();
  }

  void _prev() {
    if (_page == 0) return;
    _pageController.previousPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _finish() async {
    // Ask for push permission via OneSignal; identity is linked in
    // completeOnboarding() → syncOneSignalIdentity().
    await OneSignalService.instance.requestPermission();
    _ctrl.completeOnboarding(_buildProfile());
    Get.offAllNamed('/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.kpb.pageBg,
      body: Column(
        children: [
          _Header(
            page: _page,
            total: _totalSteps,
            onBack: _page > 0 ? _prev : null,
            onSkip: _page > 0 ? _ctrl.skipOnboarding : null,
          ),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (p) => setState(() => _page = p),
              children: [
                _StepAccountType(
                  value: _accountType,
                  onChanged: (v) => setState(() => _accountType = v),
                ),
                _isStudentLike
                    ? _StepStudyLevel(
                        value: _studyLevel,
                        onChanged: (v) => setState(() => _studyLevel = v),
                      )
                    : const _StepPartnerInfo(),
                _isStudentLike
                    ? _StepBacSeries(
                        studyLevel: _studyLevel,
                        enabled: studyLevelNeedsBacSeries(_studyLevel),
                        value: _bacSeries,
                        onChanged: (v) => setState(() => _bacSeries = v),
                      )
                    : const _StepPartnerInfo(),
                _StepCountries(
                  selected: _countryIds,
                  onToggle: (id) => setState(() {
                    if (_countryIds.contains(id)) {
                      _countryIds.remove(id);
                    } else {
                      _countryIds.add(id);
                    }
                  }),
                ),
                _StepBudget(
                  value: _monthlyBudget,
                  onChanged: (v) => setState(() => _monthlyBudget = v),
                ),
                const _StepPushNotifications(),
              ],
            ),
          ),
          _BottomBar(
            isLast: _page == _totalSteps - 1,
            onNext: _next,
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.page,
    required this.total,
    this.onBack,
    this.onSkip,
  });

  final int page;
  final int total;
  final VoidCallback? onBack;
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          KpbSpacing.pagePad,
          KpbSpacing.md,
          KpbSpacing.pagePad,
          0,
        ),
        child: Column(
          children: [
            Row(
              children: [
                if (onBack != null)
                  IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back_rounded))
                else
                  const SizedBox(width: 48),
                Expanded(
                  child: Text(
                    'Étape ${page + 1}/$total',
                    textAlign: TextAlign.center,
                    style: KpbTextStyles.label,
                  ),
                ),
                if (onSkip != null)
                  TextButton(onPressed: onSkip, child: const Text('Passer'))
                else
                  const SizedBox(width: 48),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: (page + 1) / total,
              minHeight: 4,
              backgroundColor: context.kpb.gray100,
              color: KpbColors.blue,
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.isLast, required this.onNext});

  final bool isLast;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(KpbSpacing.pagePad),
        child: FilledButton(
          onPressed: onNext,
          child: Text(isLast ? 'Terminer' : 'Continuer'),
        ),
      ),
    );
  }
}

class _StepShell extends StatelessWidget {
  const _StepShell({required this.title, required this.subtitle, required this.child});

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(KpbSpacing.pagePad),
      children: [
        Text(title, style: KpbTextStyles.headline),
        const SizedBox(height: 6),
        Text(subtitle, style: KpbTextStyles.bodySm),
        const SizedBox(height: 20),
        child,
      ],
    );
  }
}

class _StepAccountType extends StatelessWidget {
  const _StepAccountType({required this.value, required this.onChanged});

  final AccountType value;
  final ValueChanged<AccountType> onChanged;

  @override
  Widget build(BuildContext context) {
    return _StepShell(
      title: 'Tu es ?',
      subtitle: 'On adapte l\'expérience à ton profil.',
      child: Column(
        children: onboardingAccountTypes.map((type) {
          final selected = value == type;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: selected ? KpbColors.skyLight : context.kpb.cardBg,
              borderRadius: KpbRadius.mdBr,
              child: InkWell(
                onTap: () => onChanged(type),
                borderRadius: KpbRadius.mdBr,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: KpbRadius.mdBr,
                    border: Border.all(
                      color: selected ? KpbColors.blue : context.kpb.gray200,
                    ),
                  ),
                  child: Text(
                    onboardingAccountLabel(type),
                    style: TextStyle(
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _StepStudyLevel extends StatelessWidget {
  const _StepStudyLevel({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return _StepShell(
      title: 'Ton niveau d\'études',
      subtitle: 'Ça nous aide à te proposer les bons programmes.',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: onboardingStudyLevels.map((level) {
          return ChoiceChip(
            label: Text(level),
            selected: value == level,
            onSelected: (_) => onChanged(level),
          );
        }).toList(),
      ),
    );
  }
}

class _StepBacSeries extends StatelessWidget {
  const _StepBacSeries({
    required this.studyLevel,
    required this.enabled,
    required this.value,
    required this.onChanged,
  });

  final String studyLevel;
  final bool enabled;
  final String? value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return _StepShell(
      title: 'Ta série de bac',
      subtitle: enabled
          ? 'Optionnel mais utile pour l\'orientation.'
          : 'Tu peux passer cette étape pour ton niveau actuel.',
      child: enabled
          ? Wrap(
              spacing: 8,
              runSpacing: 8,
              children: onboardingBacSeries.map((series) {
                return ChoiceChip(
                  label: Text(series),
                  selected: value == series,
                  onSelected: (_) => onChanged(series),
                );
              }).toList(),
            )
          : Text(
              'Non requis pour $studyLevel — continue.',
              style: KpbTextStyles.bodySm.copyWith(
                color: context.kpb.textSecondary,
              ),
            ),
    );
  }
}

class _StepCountries extends StatelessWidget {
  const _StepCountries({required this.selected, required this.onToggle});

  final Set<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return _StepShell(
      title: 'Pays d\'intérêt',
      subtitle: 'Sélectionne une ou plusieurs destinations (optionnel).',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: onboardingDestinations.map((dest) {
          final isSelected = selected.contains(dest.id);
          return FilterChip(
            label: Text('${dest.flag} ${dest.labelFr}'),
            selected: isSelected,
            onSelected: (_) => onToggle(dest.id),
          );
        }).toList(),
      ),
    );
  }
}

class _StepBudget extends StatelessWidget {
  const _StepBudget({required this.value, required this.onChanged});

  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return _StepShell(
      title: 'Budget mensuel',
      subtitle: 'Estimation pour le logement et la vie courante (optionnel).',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${value.round()} € / mois',
            style: KpbTextStyles.titleLg.copyWith(color: KpbColors.blue),
          ),
          Slider(
            value: value,
            min: 200,
            max: 2000,
            divisions: 18,
            label: '${value.round()} €',
            onChanged: onChanged,
          ),
          const Text('200 €', style: KpbTextStyles.caption),
        ],
      ),
    );
  }
}

class _StepPushNotifications extends StatelessWidget {
  const _StepPushNotifications();

  @override
  Widget build(BuildContext context) {
    return _StepShell(
      title: 'Reste informé',
      subtitle:
          'Active les notifications pour suivre tes demandes et les messages de ton conseiller.',
      child: KpbCard(
        child: Column(
          children: [
            const Icon(Icons.notifications_active_outlined,
                size: 48, color: KpbColors.blue),
            const SizedBox(height: 12),
            const Text(
              'Autorise les notifications push sur l\'écran suivant.',
              style: KpbTextStyles.body,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _StepPartnerInfo extends StatelessWidget {
  const _StepPartnerInfo();

  @override
  Widget build(BuildContext context) {
    return const _StepShell(
      title: 'Espace partenaire',
      subtitle: 'Ton accès sera configuré par l\'équipe KPB.',
      child: KpbCard(
        child: Text(
          'Continue pour accéder à l\'application. Tu pourras compléter les détails organisationnels plus tard.',
          style: KpbTextStyles.body,
        ),
      ),
    );
  }
}
