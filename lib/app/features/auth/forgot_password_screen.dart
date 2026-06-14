import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/services/auth_service.dart';
import '../../core/ui/app_tokens.dart';
import '../../core/ui/kpb_components.dart';
import '../../core/ui/kpb_theme_ext.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, required this.authService});

  final AuthService authService;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  bool _loading = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await widget.authService.forgotPassword(email: email);
      setState(() => _sent = true);
    } catch (e) {
      setState(() =>
          _error = 'forgot_password_error'.tr);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.kpb.pageBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Get.back(),
        ),
        title: Text('forgot_password_title'.tr),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(KpbSpacing.pagePad),
          child: _sent ? _SuccessView() : _FormView(
            emailController: _emailController,
            loading: _loading,
            error: _error,
            onSubmit: _submit,
          ),
        ),
      ),
    );
  }
}

class _FormView extends StatelessWidget {
  const _FormView({
    required this.emailController,
    required this.loading,
    required this.error,
    required this.onSubmit,
  });

  final TextEditingController emailController;
  final bool loading;
  final String? error;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 32),
        // Icon
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: context.kpb.skyLight,
              borderRadius: KpbRadius.xlBr,
            ),
            child: const Icon(
              Icons.lock_reset_rounded,
              size: 36,
              color: KpbColors.blue,
            ),
          ),
        ),
        const SizedBox(height: KpbSpacing.lg),
        Text(
          'reset_password_title'.tr,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: context.kpb.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'reset_password_body'.tr,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: context.kpb.textSecondary),
        ),
        const SizedBox(height: 36),

        // Email field
        TextField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          decoration: KpbInputDecoration.build(context,
            label: 'email_label'.tr,
            prefixIcon: Icons.email_outlined,
          ),
          onSubmitted: (_) => onSubmit(),
        ),

        if (error != null) ...[
          const SizedBox(height: KpbSpacing.sm),
          Text(
            error!,
            style: const TextStyle(fontSize: 13, color: KpbColors.error),
          ),
        ],
        const SizedBox(height: KpbSpacing.lg),

        FilledButton(
          onPressed: loading ? null : onSubmit,
          child: loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : Text('send_link_button'.tr),
        ),
        const SizedBox(height: KpbSpacing.md),
        TextButton(
          onPressed: () => Get.back(),
          child: Text('back_to_login'.tr),
        ),
      ],
    );
  }
}

class _SuccessView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 60),
        Center(
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: context.kpb.successLight,
              borderRadius: KpbRadius.xlBr,
            ),
            child: const Icon(
              Icons.mark_email_read_rounded,
              size: 40,
              color: KpbColors.success,
            ),
          ),
        ),
        const SizedBox(height: KpbSpacing.xl),
        Text(
          'email_sent_title'.tr,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: context.kpb.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'email_sent_body'.tr,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: context.kpb.textSecondary),
        ),
        const SizedBox(height: 40),
        FilledButton(
          onPressed: () => Get.back(),
          child: Text('back_to_login'.tr),
        ),
      ],
    );
  }
}
