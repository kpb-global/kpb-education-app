import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/controllers/app_controller.dart';
import '../../core/models/app_models.dart';
import '../../core/ui/app_tokens.dart';
import '../../core/ui/kpb_theme_ext.dart';
import '../../core/ui/kpb_components.dart';
import '../legal/legal_pages.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Dial codes
// ─────────────────────────────────────────────────────────────────────────────
class _DialCode {
  const _DialCode(this.flag, this.code, this.country);
  final String flag, code, country;
  String get label => '$flag $code';
}

const _dialCodes = <_DialCode>[
  _DialCode('🇳🇪', '+227', 'Niger'),
  _DialCode('🇳🇬', '+234', 'Nigeria'),
  _DialCode('🇸🇳', '+221', 'Sénégal'),
  _DialCode('🇨🇮', '+225', 'Côte d\'Ivoire'),
  _DialCode('🇲🇱', '+223', 'Mali'),
  _DialCode('🇬🇳', '+224', 'Guinée'),
  _DialCode('🇧🇫', '+226', 'Burkina Faso'),
  _DialCode('🇹🇬', '+228', 'Togo'),
  _DialCode('🇧🇯', '+229', 'Bénin'),
  _DialCode('🇲🇷', '+222', 'Mauritanie'),
  _DialCode('🇬🇭', '+233', 'Ghana'),
  _DialCode('🇨🇲', '+237', 'Cameroun'),
  _DialCode('🇸🇱', '+232', 'Sierra Leone'),
  _DialCode('🇬🇲', '+220', 'Gambie'),
  _DialCode('🇱🇷', '+231', 'Liberia'),
  _DialCode('🇬🇼', '+245', 'Guinée-Bissau'),
  _DialCode('🇨🇻', '+238', 'Cap-Vert'),
  _DialCode('🇫🇷', '+33', 'France'),
  _DialCode('🇨🇦', '+1', 'Canada'),
  _DialCode('🇬🇧', '+44', 'Royaume-Uni'),
  _DialCode('🇩🇪', '+49', 'Allemagne'),
  _DialCode('🇲🇦', '+212', 'Maroc'),
  _DialCode('🇹🇷', '+90', 'Turquie'),
  _DialCode('🇪🇸', '+34', 'Espagne'),
  _DialCode('🇺🇸', '+1 🇺🇸', 'États-Unis'),
];

// ─────────────────────────────────────────────────────────────────────────────
// Data
// ─────────────────────────────────────────────────────────────────────────────
const _studyLevels = [
  ('High school', 'Lycée'), ('Bachelor', 'Licence'),
  ('Master', 'Master'), ('PhD', 'Doctorat'),
];
const _targetLevels = [
  ('Bachelor', 'Licence'), ('Master', 'Master'), ('PhD', 'Doctorat'),
];
const _langLevels = [
  ('Beginner', 'Débutant'), ('Intermediate', 'Intermédiaire'),
  ('Advanced', 'Avancé'),
];
const _grades = ['10 - 12/20', '12 - 14/20', '15+/20'];
const _documentKeys = [
  ('Passport', 'Passeport'), ('CV', 'CV'),
  ('Transcripts', 'Relevés de notes'), ('Test score', 'Score de test'),
];
const _countries = [
  'Niger','Nigeria','Sénégal','Côte d\'Ivoire','Mali','Guinée',
  'Burkina Faso','Togo','Bénin','Mauritanie','Ghana','Cameroun',
  'Sierra Leone','Gambie','Liberia','Guinée-Bissau','Cap-Vert',
  'Maroc','Tunisie','Algérie','France','Belgique','Suisse','Canada','Autre',
];

// ─────────────────────────────────────────────────────────────────────────────
// Onboarding Screen — Stepper paginé
// ─────────────────────────────────────────────────────────────────────────────
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _page = 0;

  // Form keys per page
  final _key0 = GlobalKey<FormState>();
  final _key1 = GlobalKey<FormState>();

  // Controllers
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _whatsAppCtrl = TextEditingController();

  // State
  AccountType _accountType = AccountType.student;
  String _language = 'fr';
  String _country = 'Niger';
  String _currentLevel = 'High school';
  String _targetLevel = 'Bachelor';
  String _languageLevel = 'Intermediate';
  String _gradeRange = '12 - 14/20';
  final bool _wantsScholarship = false;
  bool _sameWhatsApp = true;
  _DialCode _phoneCode = _dialCodes[0];
  _DialCode _waCode = _dialCodes[0];
  final Set<String> _fieldIds = {'computer_science', 'business'};
  final Set<String> _countryIds = {'canada', 'france'};
  final Set<String> _docs = {'Passport', 'Transcripts'};
  bool _hasConsented = false;

  AppController get _ctrl => Get.find<AppController>();

  int get _totalPages =>
      _accountType == AccountType.partner ? 2 : 3;

  @override
  void dispose() {
    _pageController.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _whatsAppCtrl.dispose();
    super.dispose();
  }

  void _next() {
    final valid = switch (_page) {
      0 => () {
          final formValid = _key0.currentState?.validate() ?? false;
          if (!formValid) return false;
          if (!_hasConsented) {
            Get.snackbar(
              'Consentement requis',
              'Veuillez accepter la politique de confidentialité et les conditions d\'utilisation.',
              snackPosition: SnackPosition.BOTTOM,
              margin: const EdgeInsets.all(12),
              duration: const Duration(seconds: 3),
              icon: const Icon(Icons.privacy_tip_outlined, color: KpbColors.error),
            );
            return false;
          }
          return true;
        }(),
      1 => _key1.currentState?.validate() ?? false,
      2 => () {
          if (_fieldIds.isEmpty) {
            Get.snackbar(
              'Sélection requise',
              'Choisissez au moins une filière d\'intérêt.',
              snackPosition: SnackPosition.BOTTOM,
              margin: const EdgeInsets.all(12),
              duration: const Duration(seconds: 3),
              icon: const Icon(Icons.info_outline_rounded, color: KpbColors.gold),
            );
            return false;
          }
          if (_countryIds.isEmpty) {
            Get.snackbar(
              'Sélection requise',
              'Choisissez au moins un pays de destination.',
              snackPosition: SnackPosition.BOTTOM,
              margin: const EdgeInsets.all(12),
              duration: const Duration(seconds: 3),
              icon: const Icon(Icons.info_outline_rounded, color: KpbColors.gold),
            );
            return false;
          }
          return true;
        }(),
      _ => true,
    };
    if (!valid) return;
    if (_page < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _submit();
    }
  }

  void _prev() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _submit() {
    final firstName = _firstNameCtrl.text.trim();
    final lastName = _lastNameCtrl.text.trim();
    final phone = '${_phoneCode.code} ${_phoneCtrl.text.trim()}';
    final whatsApp = _sameWhatsApp
        ? phone
        : '${_waCode.code} ${_whatsAppCtrl.text.trim()}';

    final profile = UserProfile(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      accountType: _accountType,
      fullName: '$firstName $lastName'.trim(),
      email: _emailCtrl.text.trim(),
      phone: phone,
      whatsApp: whatsApp,
      countryOfResidence: _country,
      preferredLanguage: _language,
      currentLevel: _accountType == AccountType.partner ? null : _currentLevel,
      targetLevel: _accountType == AccountType.partner ? null : _targetLevel,
      languageLevel: _accountType == AccountType.partner ? null : _languageLevel,
      fieldIds: _accountType == AccountType.partner ? [] : _fieldIds.toList(),
      targetCountryIds: _accountType == AccountType.partner ? [] : _countryIds.toList(),
      gradeRange: _accountType == AccountType.partner ? null : _gradeRange,
      wantsScholarshipSupport: _accountType == AccountType.student && _wantsScholarship,
      availableDocuments: _accountType == AccountType.partner ? [] : _docs.toList(),
      consentedAt: DateTime.now(),
    );
    _ctrl.completeOnboarding(profile);
  }

  void _skipOnboarding() {
    final profile = UserProfile(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      accountType: AccountType.student,
      fullName: 'Test User',
      email: 'test@kpb-education.com',
      phone: '+33 6 12 34 56 78',
      whatsApp: '+33 6 12 34 56 78',
      countryOfResidence: 'France',
      preferredLanguage: 'fr',
      currentLevel: 'Bachelor',
      targetLevel: 'Master',
      languageLevel: 'Advanced',
      fieldIds: const ['computer_science', 'business'],
      targetCountryIds: const ['france'],
      gradeRange: '15+/20',
      wantsScholarshipSupport: false,
      availableDocuments: const ['Passport', 'CV'],
      consentedAt: DateTime.now(),
    );
    _ctrl.completeOnboarding(profile);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.kpb.pageBg,
      body: Column(
        children: [
          // ── Progress bar ─────────────────────────────────────────
          _ProgressHeader(
            page: _page,
            total: _totalPages,
            onBack: _page > 0 ? _prev : null,
            onSkip: _skipOnboarding,
          ),

          // ── Pages ────────────────────────────────────────────────
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (p) => setState(() => _page = p),
              children: [
                // Page 0 — Identité & compte
                _Page(
                  formKey: _key0,
                  title: 'Bienvenue 👋',
                  subtitle: 'Créons votre profil KPB Education.',
                  child: _PageIdentity(
                    accountType: _accountType,
                    language: _language,
                    firstNameCtrl: _firstNameCtrl,
                    lastNameCtrl: _lastNameCtrl,
                    emailCtrl: _emailCtrl,
                    phoneCtrl: _phoneCtrl,
                    whatsAppCtrl: _whatsAppCtrl,
                    phoneCode: _phoneCode,
                    waCode: _waCode,
                    sameWhatsApp: _sameWhatsApp,
                    country: _country,
                    hasConsented: _hasConsented,
                    onAccountType: (v) => setState(() => _accountType = v),
                    onLanguage: (v) => setState(() => _language = v),
                    onPhoneCode: (v) => setState(() => _phoneCode = v),
                    onWaCode: (v) => setState(() => _waCode = v),
                    onSameWhatsApp: (v) => setState(() => _sameWhatsApp = v),
                    onCountry: (v) => setState(() => _country = v ?? _country),
                    onConsent: (v) => setState(() => _hasConsented = v),
                  ),
                ),

                // Page 1 — Niveau académique
                if (_accountType != AccountType.partner)
                  _Page(
                    formKey: _key1,
                    title: 'Votre parcours 🎓',
                    subtitle: 'Dites-nous où vous en êtes.',
                    child: _PageAcademic(
                      currentLevel: _currentLevel,
                      targetLevel: _targetLevel,
                      languageLevel: _languageLevel,
                      gradeRange: _gradeRange,
                      onCurrentLevel: (v) => setState(() => _currentLevel = v ?? _currentLevel),
                      onTargetLevel: (v) => setState(() => _targetLevel = v ?? _targetLevel),
                      onLanguageLevel: (v) => setState(() => _languageLevel = v ?? _languageLevel),
                      onGradeRange: (v) => setState(() => _gradeRange = v ?? _gradeRange),
                    ),
                  )
                else
                  _Page(
                    formKey: _key1,
                    title: 'Votre structure 🤝',
                    subtitle: 'Parlez-nous de votre organisation.',
                    child: _PagePartner(),
                  ),

                // Page 2 — Filières, pays, documents
                if (_accountType != AccountType.partner)
                  _Page(
                    formKey: GlobalKey(),
                    title: 'Vos intérêts 🌍',
                    subtitle: 'Personnalisez vos recommandations.',
                    child: _PageInterests(
                      controller: _ctrl,
                      fieldIds: _fieldIds,
                      countryIds: _countryIds,
                      docs: _docs,
                      onToggleField: (id) => setState(() {
                        if (_fieldIds.contains(id)) {
                          _fieldIds.remove(id);
                        } else {
                          _fieldIds.add(id);
                        }
                      }),
                      onToggleCountry: (id) => setState(() {
                        if (_countryIds.contains(id)) {
                          _countryIds.remove(id);
                        } else {
                          _countryIds.add(id);
                        }
                      }),
                      onToggleDoc: (key) => setState(() {
                        if (_docs.contains(key)) {
                          _docs.remove(key);
                        } else {
                          _docs.add(key);
                        }
                      }),
                    ),
                  ),
              ],
            ),
          ),

          // ── Bottom CTA ───────────────────────────────────────────
          _BottomBar(
            page: _page,
            total: _totalPages,
            onNext: _next,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Progress Header
// ─────────────────────────────────────────────────────────────────────────────
class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({
    required this.page,
    required this.total,
    this.onBack,
    this.onSkip,
  });
  final int page, total;
  final VoidCallback? onBack;
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          KpbSpacing.pagePad, KpbSpacing.md, KpbSpacing.pagePad, 0,
        ),
        child: Column(
          children: [
            Row(
              children: [
                if (onBack != null)
                  GestureDetector(
                    onTap: onBack,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: context.kpb.cardBg,
                        borderRadius: KpbRadius.smBr,
                        boxShadow: KpbShadow.soft,
                      ),
                      child: Icon(Icons.arrow_back_rounded,
                          size: 18, color: context.kpb.textPrimary),
                    ),
                  )
                else
                  const SizedBox(width: 36),
                const Spacer(),
                Text(
                  '${page + 1} / $total',
                  style: KpbTextStyles.label,
                ),
                const Spacer(),
                if (onSkip != null)
                  GestureDetector(
                    onTap: onSkip,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: context.kpb.cardBg,
                        borderRadius: KpbRadius.pillBr,
                        boxShadow: KpbShadow.soft,
                        border: Border.all(color: KpbColors.blue.withValues(alpha: 0.3)),
                      ),
                      child: const Text(
                        'Passer',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: KpbColors.blue,
                        ),
                      ),
                    ),
                  )
                else
                  const SizedBox(width: 36),
              ],
            ),
            const SizedBox(height: KpbSpacing.sm),
            ClipRRect(
              borderRadius: KpbRadius.pillBr,
              child: LinearProgressIndicator(
                value: (page + 1) / total,
                minHeight: 4,
                backgroundColor: context.kpb.gray200,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(KpbColors.blue),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Page wrapper
// ─────────────────────────────────────────────────────────────────────────────
class _Page extends StatelessWidget {
  const _Page({
    required this.formKey,
    required this.title,
    required this.subtitle,
    required this.child,
  });
  final Key formKey;
  final String title, subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: ListView(
        padding: const EdgeInsets.all(KpbSpacing.pagePad),
        children: [
          const SizedBox(height: KpbSpacing.sm),
          Text(title, style: KpbTextStyles.headline),
          const SizedBox(height: 4),
          Text(subtitle, style: KpbTextStyles.bodySm),
          const SizedBox(height: KpbSpacing.lg),
          child,
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom bar
// ─────────────────────────────────────────────────────────────────────────────
class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.page,
    required this.total,
    required this.onNext,
  });
  final int page, total;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final isLast = page == total - 1;
    return Container(
      padding: EdgeInsets.fromLTRB(
        KpbSpacing.pagePad, KpbSpacing.md,
        KpbSpacing.pagePad,
        KpbSpacing.md + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: context.kpb.cardBg,
        border: Border(top: BorderSide(color: context.kpb.gray100)),
      ),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: onNext,
          child: Text(isLast ? 'create_account'.tr : 'continue'.tr),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Page 0 — Identité
// ─────────────────────────────────────────────────────────────────────────────
class _PageIdentity extends StatelessWidget {
  const _PageIdentity({
    required this.accountType,
    required this.language,
    required this.firstNameCtrl,
    required this.lastNameCtrl,
    required this.emailCtrl,
    required this.phoneCtrl,
    required this.whatsAppCtrl,
    required this.phoneCode,
    required this.waCode,
    required this.sameWhatsApp,
    required this.country,
    required this.onAccountType,
    required this.onLanguage,
    required this.onPhoneCode,
    required this.onWaCode,
    required this.onSameWhatsApp,
    required this.onCountry,
    required this.hasConsented,
    required this.onConsent,
  });

  final AccountType accountType;
  final String language, country;
  final TextEditingController firstNameCtrl, lastNameCtrl, emailCtrl,
      phoneCtrl, whatsAppCtrl;
  final _DialCode phoneCode, waCode;
  final bool sameWhatsApp;
  final ValueChanged<AccountType> onAccountType;
  final ValueChanged<String> onLanguage;
  final ValueChanged<_DialCode> onPhoneCode;
  final ValueChanged<_DialCode> onWaCode;
  final ValueChanged<bool> onSameWhatsApp;
  final ValueChanged<String?> onCountry;
  final bool hasConsented;
  final ValueChanged<bool> onConsent;

  String? _req(String? v) =>
      (v == null || v.trim().isEmpty) ? 'field_required'.tr : null;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Type de compte
        const Text('Je suis', style: KpbTextStyles.titleMd),
        const SizedBox(height: 10),
        Row(
          children: AccountType.values.map((t) {
            final sel = t == accountType;
            return Expanded(
              child: GestureDetector(
                onTap: () => onAccountType(t),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: EdgeInsets.only(
                    right: t != AccountType.values.last ? 8 : 0,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: sel ? KpbColors.blue : context.kpb.cardBg,
                    borderRadius: KpbRadius.mdBr,
                    boxShadow: KpbShadow.card,
                  ),
                  child: Column(
                    children: [
                      Icon(
                        t == AccountType.student
                            ? Icons.school_outlined
                            : t == AccountType.parent
                                ? Icons.family_restroom_outlined
                                : Icons.handshake_outlined,
                        color: sel ? Colors.white : context.kpb.textSecondary,
                        size: 22,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        t == AccountType.student
                            ? 'Étudiant'
                            : t == AccountType.parent
                                ? 'Parent'
                                : 'Partenaire',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: sel ? Colors.white : context.kpb.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: KpbSpacing.lg),

        // Langue
        Text('preferred_language'.tr, style: KpbTextStyles.titleMd),
        const SizedBox(height: 10),
        Row(
          children: [
            _LangBtn(
              label: '🇫🇷 Français',
              selected: language == 'fr',
              onTap: () => onLanguage('fr'),
            ),
            const SizedBox(width: 10),
            _LangBtn(
              label: '🇬🇧 English',
              selected: language == 'en',
              onTap: () => onLanguage('en'),
            ),
          ],
        ),
        const SizedBox(height: KpbSpacing.lg),

        // Nom / Prénom
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: firstNameCtrl,
                validator: _req,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(labelText: 'first_name'.tr),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: lastNameCtrl,
                validator: _req,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(labelText: 'last_name'.tr),
              ),
            ),
          ],
        ),
        const SizedBox(height: KpbSpacing.md),

        // Email
        TextFormField(
          controller: emailCtrl,
          validator: _req,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(labelText: 'email'.tr),
        ),
        const SizedBox(height: KpbSpacing.md),

        // Téléphone
        _PhoneRow(
          controller: phoneCtrl,
          dialCode: phoneCode,
          label: 'phone'.tr,
          required: true,
          onDialCode: onPhoneCode,
        ),
        const SizedBox(height: KpbSpacing.sm),

        // WhatsApp
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: sameWhatsApp,
          title: Text('whatsapp_same_as_phone'.tr,
              style: KpbTextStyles.bodySm),
          onChanged: (v) => onSameWhatsApp(v ?? true),
        ),
        if (!sameWhatsApp) ...[
          _PhoneRow(
            controller: whatsAppCtrl,
            dialCode: waCode,
            label: 'whatsapp'.tr,
            required: false,
            onDialCode: onWaCode,
          ),
          const SizedBox(height: KpbSpacing.md),
        ],

        // Pays de résidence
        const SizedBox(height: KpbSpacing.md),
        DropdownButtonFormField<String>(
          initialValue: country,
          decoration: InputDecoration(labelText: 'country'.tr),
          items: _countries
              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
              .toList(),
          onChanged: onCountry,
        ),
        const SizedBox(height: KpbSpacing.lg),

        // ── GDPR Consent ──────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: hasConsented
                ? KpbColors.successLight
                : context.kpb.gray50,
            borderRadius: KpbRadius.mdBr,
            border: Border.all(
              color: hasConsented
                  ? KpbColors.success
                  : context.kpb.gray200,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: hasConsented,
                  onChanged: (v) => onConsent(v ?? false),
                  activeColor: KpbColors.success,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    style: TextStyle(
                      fontSize: 13,
                      color: context.kpb.textSecondary,
                      height: 1.4,
                    ),
                    children: [
                      const TextSpan(text: 'J\'accepte la '),
                      WidgetSpan(
                        alignment: PlaceholderAlignment.baseline,
                        baseline: TextBaseline.alphabetic,
                        child: GestureDetector(
                          onTap: () => Get.to(
                              () => const PrivacyPolicyScreen()),
                          child: const Text(
                            'politique de confidentialit\u00e9',
                            style: TextStyle(
                              fontSize: 13,
                              color: KpbColors.blue,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline,
                              decorationColor: KpbColors.blue,
                            ),
                          ),
                        ),
                      ),
                      const TextSpan(text: ' et les '),
                      WidgetSpan(
                        alignment: PlaceholderAlignment.baseline,
                        baseline: TextBaseline.alphabetic,
                        child: GestureDetector(
                          onTap: () => Get.to(
                              () => const TermsOfServiceScreen()),
                          child: const Text(
                            'conditions d\'utilisation',
                            style: TextStyle(
                              fontSize: 13,
                              color: KpbColors.blue,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline,
                              decorationColor: KpbColors.blue,
                            ),
                          ),
                        ),
                      ),
                      const TextSpan(text: '.'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: KpbSpacing.md),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Page 1 — Académique
// ─────────────────────────────────────────────────────────────────────────────
class _PageAcademic extends StatelessWidget {
  const _PageAcademic({
    required this.currentLevel,
    required this.targetLevel,
    required this.languageLevel,
    required this.gradeRange,
    required this.onCurrentLevel,
    required this.onTargetLevel,
    required this.onLanguageLevel,
    required this.onGradeRange,
  });

  final String currentLevel, targetLevel, languageLevel, gradeRange;
  final ValueChanged<String?> onCurrentLevel, onTargetLevel,
      onLanguageLevel, onGradeRange;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DD(
          label: 'current_level'.tr,
          value: currentLevel,
          items: _studyLevels,
          onChanged: onCurrentLevel,
        ),
        const SizedBox(height: KpbSpacing.md),
        _DD(
          label: 'target_level'.tr,
          value: targetLevel,
          items: _targetLevels,
          onChanged: onTargetLevel,
        ),
        const SizedBox(height: KpbSpacing.md),
        _DD(
          label: 'language_level'.tr,
          value: languageLevel,
          items: _langLevels,
          onChanged: onLanguageLevel,
        ),
        const SizedBox(height: KpbSpacing.md),
        DropdownButtonFormField<String>(
          initialValue: gradeRange,
          decoration: InputDecoration(labelText: 'grade_range'.tr),
          items: _grades
              .map((g) => DropdownMenuItem(value: g, child: Text(g)))
              .toList(),
          onChanged: onGradeRange,
        ),
        const SizedBox(height: KpbSpacing.md),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Page 1b — Partenaire
// ─────────────────────────────────────────────────────────────────────────────
class _PagePartner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return KpbCard(
      padding: const EdgeInsets.all(KpbSpacing.lg),
      child: Column(
        children: [
          const Icon(Icons.handshake_outlined,
              size: 48, color: KpbColors.blue),
          const SizedBox(height: KpbSpacing.md),
          const Text('Espace partenariat', style: KpbTextStyles.title),
          const SizedBox(height: 8),
          Text(
            'partner_redirect'.tr,
            style: KpbTextStyles.bodySm,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Page 2 — Intérêts
// ─────────────────────────────────────────────────────────────────────────────
class _PageInterests extends StatelessWidget {
  const _PageInterests({
    required this.controller,
    required this.fieldIds,
    required this.countryIds,
    required this.docs,
    required this.onToggleField,
    required this.onToggleCountry,
    required this.onToggleDoc,
  });

  final AppController controller;
  final Set<String> fieldIds, countryIds, docs;
  final ValueChanged<String> onToggleField, onToggleCountry, onToggleDoc;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('explore_fields'.tr, style: KpbTextStyles.titleMd),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: controller.fields.map((f) {
            final sel = fieldIds.contains(f.id);
            return FilterChip(
              label: Text(controller.resolve(f.name)),
              selected: sel,
              onSelected: (_) => onToggleField(f.id),
            );
          }).toList(),
        ),
        const SizedBox(height: KpbSpacing.lg),

        Text('explore_countries'.tr, style: KpbTextStyles.titleMd),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: controller.countries.map((c) {
            final sel = countryIds.contains(c.id);
            return FilterChip(
              label: Text(controller.resolve(c.name)),
              selected: sel,
              onSelected: (_) => onToggleCountry(c.id),
            );
          }).toList(),
        ),
        const SizedBox(height: KpbSpacing.lg),

        Text('available_documents'.tr, style: KpbTextStyles.titleMd),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _documentKeys.map((e) {
            final sel = docs.contains(e.$1);
            return FilterChip(
              label: Text(e.$2),
              selected: sel,
              onSelected: (_) => onToggleDoc(e.$1),
            );
          }).toList(),
        ),
        const SizedBox(height: KpbSpacing.xl),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────
class _LangBtn extends StatelessWidget {
  const _LangBtn({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? KpbColors.blue : context.kpb.cardBg,
            borderRadius: KpbRadius.mdBr,
            boxShadow: KpbShadow.card,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : context.kpb.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DD extends StatelessWidget {
  const _DD({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });
  final String label, value;
  final List<(String, String)> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: items
          .map((e) => DropdownMenuItem(value: e.$1, child: Text(e.$2)))
          .toList(),
      onChanged: onChanged,
    );
  }
}

class _PhoneRow extends StatelessWidget {
  const _PhoneRow({
    required this.controller,
    required this.dialCode,
    required this.label,
    required this.required,
    required this.onDialCode,
  });
  final TextEditingController controller;
  final _DialCode dialCode;
  final String label;
  final bool required;
  final ValueChanged<_DialCode> onDialCode;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(KpbRadius.md),
            border: Border.all(color: context.kpb.gray200),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<_DialCode>(
              value: dialCode,
              isDense: true,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              items: _dialCodes
                  .map((d) => DropdownMenuItem(
                        value: d,
                        child: Text(d.label,
                            style: const TextStyle(fontSize: 14)),
                      ))
                  .toList(),
              onChanged: (v) { if (v != null) onDialCode(v); },
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextFormField(
            controller: controller,
            keyboardType: TextInputType.phone,
            validator: required
                ? (v) => (v == null || v.trim().isEmpty)
                    ? 'field_required'.tr
                    : null
                : null,
            decoration: InputDecoration(labelText: label),
          ),
        ),
      ],
    );
  }
}
