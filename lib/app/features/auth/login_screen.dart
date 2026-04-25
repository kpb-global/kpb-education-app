import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/controllers/app_controller.dart';
import '../../core/services/analytics_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/ui/app_tokens.dart';
import '../../core/ui/kpb_components.dart';
import '../../core/ui/kpb_theme_ext.dart';
import '../onboarding/onboarding_screen.dart';
import '../shell/app_shell.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.authService});

  final AuthService authService;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await widget.authService.login(email: email, password: password);
      AnalyticsService.instance.logLogin();
      final controller = Get.find<AppController>();
      await controller.hydrate();
      if (controller.hasCompletedOnboarding) {
        Get.offAll(() => const AppShell());
      } else {
        Get.offAll(() => const OnboardingScreen());
      }
    } catch (e) {
      setState(() => _error = 'login_error'.tr);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.kpb.pageBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(KpbSpacing.pagePad),
          child: Form(
            key: _formKey,
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 60),
              // Logo / Title
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    gradient: KpbColors.heroGradient,
                    borderRadius: KpbRadius.xlBr,
                  ),
                  child: const Icon(Icons.school_rounded,
                      size: 32, color: Colors.white),
                ),
              ),
              const SizedBox(height: KpbSpacing.lg),
              Text(
                'KPB Education',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: context.kpb.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'login_subtitle'.tr,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: context.kpb.textMuted,
                ),
              ),
              const SizedBox(height: 40),

              // Email
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: KpbInputDecoration.build(context, label: 'Email', prefixIcon: Icons.email_outlined),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'email_required'.tr;
                  final emailReg = RegExp(r'^[\w.+-]+@[\w-]+\.\w+$');
                  if (!emailReg.hasMatch(v.trim())) return 'email_invalid'.tr;
                  return null;
                },
              ),
              const SizedBox(height: KpbSpacing.md),

              // Password
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: KpbInputDecoration.build(context, label: 'Mot de passe', prefixIcon: Icons.lock_outline_rounded).copyWith(
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 20,
                      color: context.kpb.gray400,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                onFieldSubmitted: (_) => _login(),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'password_required'.tr;
                  return null;
                },
              ),
              const SizedBox(height: KpbSpacing.sm),

              // Forgot password
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Get.to(() =>
                      ForgotPasswordScreen(authService: widget.authService)),
                  child: Text(
                    'forgot_password_link'.tr,
                    style: const TextStyle(
                      fontSize: 13,
                      color: KpbColors.blue,
                    ),
                  ),
                ),
              ),

              if (_error != null)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(bottom: KpbSpacing.sm),
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

              const SizedBox(height: KpbSpacing.md),

              // Login button
              FilledButton(
                onPressed: _loading ? null : _login,
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child:
                            CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text('login_button'.tr),
              ),
              const SizedBox(height: KpbSpacing.lg),

              // Register link
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'no_account_prompt'.tr,
                    style: TextStyle(
                        fontSize: 14, color: context.kpb.textSecondary),
                  ),
                  GestureDetector(
                    onTap: () => Get.to(() =>
                        RegisterScreen(authService: widget.authService)),
                    child: Text(
                      'create_account_link'.tr,
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
