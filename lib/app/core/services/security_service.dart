import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:local_auth/local_auth.dart';


import '../controllers/app_controller.dart';
import '../../features/auth/app_lock_screen.dart';

/// Service responsible for managing app-level security, particularly
/// biometric authentication when the app resumes from the background.
class SecurityService extends GetxService with WidgetsBindingObserver {
  static SecurityService get instance => Get.find<SecurityService>();

  final LocalAuthentication _auth = LocalAuthentication();
  bool _isAuthenticating = false;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAndShowLockScreen();
    }
  }

  /// Called when the app starts or resumes.
  /// If biometrics are enabled in the user's snapshot, we throw the lock screen.
  void _checkAndShowLockScreen() {
    // We only enforce lock if the user has enabled it in their profile/snapshot.
    // For now, let's assume it's stored in AppController.
    final controller = Get.find<AppController>();
    if (!controller.isAppLockEnabled) return;
    
    // Don't show if we are already authenticating or currently showing the lock screen
    if (_isAuthenticating || Get.currentRoute == '/app_lock') return;

    Get.to(() => const AppLockScreen(), transition: Transition.fadeIn, routeName: '/app_lock');
  }

  /// Attempts to authenticate the user using biometrics or device PIN.
  /// Returns true if successful.
  Future<bool> authenticate() async {
    _isAuthenticating = true;
    try {
      final canCheckBiometrics = await _auth.canCheckBiometrics || await _auth.isDeviceSupported();

      if (!canCheckBiometrics) {
        _isAuthenticating = false;
        return true; // Fallback to allowing access if device has no security
      }

      final authenticated = await _auth.authenticate(
        localizedReason: 'Déverrouillez pour accéder à vos documents sécurisés KPB',
      );
      
      _isAuthenticating = false;
      return authenticated;
    } on PlatformException catch (_) {
      _isAuthenticating = false;
      return false; 
    }
  }
}
