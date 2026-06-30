import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';

import '../../core/services/security_service.dart';
import '../../core/ui/app_tokens.dart';

/// Full screen overlay that requires biometric authentication to dismiss.
class AppLockScreen extends StatefulWidget {
  const AppLockScreen({super.key});

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    // Trigger auth immediately upon showing the screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _authenticate();
    });
  }

  Future<void> _authenticate() async {
    setState(() => _hasError = false);
    final success = await SecurityService.instance.authenticate();
    if (success) {
      Get.back(); // Dismiss the lock screen
    } else {
      setState(() => _hasError = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    // WillPopScope equivalent to prevent back navigation
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: KpbColors.bgDarkMidnight,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Lottie.network(
                  'https://assets9.lottiefiles.com/packages/lf20_S69j4B.json',
                  width: 180,
                  height: 180,
                  repeat: true,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Application Verrouillée',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Veuillez vous authentifier pour accéder à vos documents et suivis KPB.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 48),
                if (_hasError) ...[
                  const Text(
                    'Authentification échouée.',
                    style: TextStyle(color: KpbColors.error, fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                ],
                ElevatedButton(
                  onPressed: _authenticate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: KpbColors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(KpbRadius.pill)),
                  ),
                  child: const Text('Déverrouiller',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
