import 'dart:async';

import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/controllers/app_controller.dart';
import '../../core/services/analytics_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/ui/app_tokens.dart';
import '../onboarding/onboarding_screen.dart';
import '../shell/app_root_shell.dart';
import 'magic_link_email_screen.dart';

/// KPB Intelligence's acquisition entry point for Google or email sign-in.
class AuthWelcomeScreen extends StatefulWidget {
  const AuthWelcomeScreen({super.key});

  @override
  State<AuthWelcomeScreen> createState() => _AuthWelcomeScreenState();
}

class _AuthWelcomeScreenState extends State<AuthWelcomeScreen> {
  late final AuthService _authService = Get.find<AuthService>();
  StreamSubscription<AuthState>? _authSub;
  bool _googleLoading = false;

  @override
  void initState() {
    super.initState();
    // Google OAuth returns via deep link; complete navigation when the
    // session is established.
    _authSub = _authService.onAuthStateChange.listen((state) {
      if (state.event == AuthChangeEvent.signedIn && mounted) {
        AnalyticsService.instance.logLogin();
        navigateAfterAuth();
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _googleLoading = true);
    try {
      await _authService.signInWithGoogle();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('auth_google_error'.tr)),
        );
      }
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = _authService;

    return Scaffold(
      backgroundColor: KpbColors.canvas,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxHeight < 720;
            final titleSize = isCompact ? 30.0 : 34.0;
            final sidePadding = constraints.maxWidth < 380 ? 28.0 : 40.0;

            return Padding(
              padding: EdgeInsets.fromLTRB(sidePadding, 24, sidePadding, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Image.asset(
                      'assets/images/logo/kpb-education-logo-full.png',
                      width: 150,
                      fit: BoxFit.contain,
                      semanticLabel: 'KPB Education',
                    ),
                  ),
                  Spacer(flex: isCompact ? 2 : 3),
                  Text(
                    'auth_intelligence_title'.tr,
                    style: TextStyle(
                      color: KpbColors.brandNavy,
                      fontSize: titleSize,
                      fontWeight: FontWeight.w800,
                      height: 1.04,
                      letterSpacing: -1.25,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'auth_intelligence_body'.tr,
                    style: const TextStyle(
                      color: KpbColors.textMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      height: 1.42,
                    ),
                  ),
                  const SizedBox(height: 30),
                  _BenefitRow(
                    icon: Icons.percent_rounded,
                    label: 'auth_intelligence_benefit_probability'.tr,
                  ),
                  const SizedBox(height: 17),
                  _BenefitRow(
                    icon: Icons.smart_toy_outlined,
                    label: 'auth_intelligence_benefit_ai'.tr,
                  ),
                  const SizedBox(height: 17),
                  _BenefitRow(
                    icon: Icons.support_agent_rounded,
                    label: 'auth_intelligence_benefit_support'.tr,
                  ),
                  Spacer(flex: isCompact ? 1 : 2),
                  SizedBox(
                    height: 58,
                    child: OutlinedButton.icon(
                      onPressed: _googleLoading ? null : _signInWithGoogle,
                      icon: _googleLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: KpbColors.actionPrimary,
                              ),
                            )
                          : const FaIcon(
                              FontAwesomeIcons.google,
                              size: 19,
                              color: KpbColors.googleBlue,
                            ),
                      label: Text('auth_continue_google'.tr),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: KpbColors.brandNavy,
                        backgroundColor: Colors.white,
                        side: const BorderSide(
                          color: KpbColors.border,
                          width: 1.5,
                        ),
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.all(Radius.circular(20)),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 58,
                    child: FilledButton.icon(
                      onPressed: () => Get.to(
                        () => MagicLinkEmailScreen(authService: authService),
                      ),
                      icon: const Icon(Icons.mail_outline_rounded, size: 23),
                      label: Text('auth_receive_email_link'.tr),
                      style: FilledButton.styleFrom(
                        backgroundColor: KpbColors.actionPrimary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.all(Radius.circular(20)),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'auth_intelligence_note'.tr,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: KpbColors.textFaint,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  const _BenefitRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 28,
            child: Icon(icon, size: 24, color: KpbColors.actionPrimary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: KpbColors.gray700,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                height: 1.24,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Resumes authenticated session after magic-link verify.
Future<void> navigateAfterAuth() async {
  final controller = Get.find<AppController>();
  await controller.finishAuthSession();
  if (controller.hasCompletedOnboarding) {
    Get.offAll(() => const AppRootShell());
  } else {
    Get.offAll(() => const OnboardingScreen());
  }
}
