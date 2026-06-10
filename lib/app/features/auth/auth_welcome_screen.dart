import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/controllers/app_controller.dart';
import '../../core/services/analytics_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/ui/app_tokens.dart';
import '../../core/ui/kpb_theme_ext.dart';
import '../onboarding/onboarding_screen.dart';
import '../shell/app_root_shell.dart';
import 'magic_link_email_screen.dart';

/// Entry point after intro — Google sign-in, email magic link, or guest browse.
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
      backgroundColor: context.kpb.pageBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(KpbSpacing.pagePad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(
                    gradient: KpbColors.heroGradient,
                    borderRadius: KpbRadius.xlBr,
                  ),
                  child: const Icon(
                    Icons.school_rounded,
                    size: 36,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: KpbSpacing.lg),
              Text(
                'auth_welcome_title'.tr,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: context.kpb.textPrimary,
                ),
              ),
              const SizedBox(height: KpbSpacing.sm),
              Text(
                'auth_welcome_subtitle'.tr,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.4,
                  color: context.kpb.textMuted,
                ),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _googleLoading ? null : _signInWithGoogle,
                icon: _googleLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.g_mobiledata_rounded, size: 28),
                label: Text('auth_continue_google'.tr),
              ),
              const SizedBox(height: KpbSpacing.sm),
              OutlinedButton(
                onPressed: () => Get.to(
                  () => MagicLinkEmailScreen(authService: authService),
                ),
                child: Text('auth_continue_email'.tr),
              ),
              const SizedBox(height: KpbSpacing.sm),
              TextButton(
                onPressed: () {
                  final controller = Get.find<AppController>();
                  controller.enterGuestMode();
                  Get.offAll(() => const AppRootShell());
                },
                child: Text('auth_continue_guest'.tr),
              ),
              const SizedBox(height: KpbSpacing.md),
              Text(
                'auth_guest_hint'.tr,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: context.kpb.textMuted),
              ),
            ],
          ),
        ),
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
