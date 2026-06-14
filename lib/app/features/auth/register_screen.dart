import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/controllers/app_controller.dart';
import '../../core/services/analytics_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/ui/app_tokens.dart';
import '../../core/ui/kpb_components.dart';
import '../../core/ui/kpb_theme_ext.dart';
import '../onboarding/onboarding_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key, required this.authService});

  final AuthService authService;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await widget.authService.register(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        fullName: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
      );
      AnalyticsService.instance.logRegister();
      final controller = Get.find<AppController>();
      await controller.hydrate();
      Get.offAll(() => const OnboardingScreen());
    } catch (e) {
      String message = 'register_error_generic'.tr;
      if (e is Exception) {
        final errorStr = e.toString().toLowerCase();
        if (errorStr.contains('409') || errorStr.contains('already') || errorStr.contains('existe')) {
          message = 'register_error_email_exists'.tr;
        } else if (errorStr.contains('timeout') || errorStr.contains('socketexception') || errorStr.contains('connection')) {
          message = 'register_error_network'.tr;
        }
      }
      setState(() => _error = message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.kpb.pageBg,
      appBar: AppBar(
        backgroundColor: context.kpb.pageBg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              size: 20, color: context.kpb.textPrimary),
          onPressed: () => Get.back(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(KpbSpacing.pagePad),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'create_account_title'.tr,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: context.kpb.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'create_account_subtitle'.tr,
                  style: TextStyle(fontSize: 14, color: context.kpb.textMuted),
                ),
                const SizedBox(height: 32),

                // ── Nom complet ─────────────────────────────────────────
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: KpbInputDecoration.build(context,
                      label: 'full_name'.tr, prefixIcon: Icons.person_outline_rounded),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'full_name_required'.tr;
                    }
                    if (v.trim().split(' ').length < 2) {
                      return 'full_name_hint'.tr;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: KpbSpacing.md),

                // ── Email ───────────────────────────────────────────────
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration:
                      KpbInputDecoration.build(context, label: 'Email', prefixIcon: Icons.email_outlined),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'email_required'.tr;
                    }
                    final emailReg = RegExp(r'^[\w.+-]+@[\w-]+\.\w+$');
                    if (!emailReg.hasMatch(v.trim())) {
                      return 'email_invalid'.tr;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: KpbSpacing.md),

                // ── Téléphone (optionnel) ───────────────────────────────
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: KpbInputDecoration.build(context,
                      label: 'phone_optional'.tr, prefixIcon: Icons.phone_outlined),
                ),
                const SizedBox(height: KpbSpacing.md),

                // ── Mot de passe ────────────────────────────────────────
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: KpbInputDecoration.build(context,
                    label: 'Mot de passe',
                    prefixIcon: Icons.lock_outline_rounded,
                  ).copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 20,
                        color: context.kpb.gray400,
                      ),
                      onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword),
                    ),
                    helperText: 'password_helper'.tr,
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return 'password_choose'.tr;
                    }
                    if (v.length < 8) {
                      return 'password_min_length'.tr;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: KpbSpacing.sm),

                // ── Error banner ─────────────────────────────────────────
                if (_error != null)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin:
                        const EdgeInsets.only(bottom: KpbSpacing.sm),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: KpbRadius.mdBr,
                      border: Border.all(
                          color: const Color(0xFFFCA5A5), width: 1),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            size: 16, color: KpbColors.error),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error!,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: KpbColors.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: KpbSpacing.lg),

                FilledButton(
                  onPressed: _loading ? null : _register,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text('create_account_button'.tr,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700)),
                ),

                const SizedBox(height: KpbSpacing.lg),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'already_have_account'.tr,
                      style: TextStyle(
                          fontSize: 14, color: context.kpb.textSecondary),
                    ),
                    GestureDetector(
                      onTap: () => Get.back(),
                      child: Text(
                        'login_link'.tr,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: KpbColors.blue,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

}
