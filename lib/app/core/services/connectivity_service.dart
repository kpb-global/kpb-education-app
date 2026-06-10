import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../ui/app_tokens.dart';

/// Lightweight connectivity checker — no extra package needed.
/// Tries to resolve a DNS lookup to determine online/offline status.
class ConnectivityService {
  ConnectivityService._();
  static final instance = ConnectivityService._();

  bool _isOnline = true;
  bool get isOnline => _isOnline;

  Timer? _timer;
  Timer? _reconnectDebounce;
  StreamSubscription<bool>? _reconnectSubscription;
  bool _monitoring = false;
  final _controller = StreamController<bool>.broadcast();
  Stream<bool> get onConnectivityChanged => _controller.stream;

  /// Start periodic checks every 30s.
  void startMonitoring() {
    if (_monitoring) return;
    _monitoring = true;
    _check();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _check());
  }

  /// Registers the reconnect sync handler (replaces any previous binding).
  void bindReconnectSync(Future<void> Function() onReconnect) {
    _reconnectSubscription?.cancel();
    _reconnectSubscription = onConnectivityChanged.listen((online) {
      if (online) {
        _reconnectDebounce?.cancel();
        _reconnectDebounce = Timer(const Duration(seconds: 3), () async {
          if (_isOnline) {
            await onReconnect();
          }
        });
      } else {
        _reconnectDebounce?.cancel();
      }
    });
  }

  void dispose() {
    _timer?.cancel();
    _reconnectDebounce?.cancel();
    _reconnectSubscription?.cancel();
    _controller.close();
  }

  Future<void> _check() async {
    try {
      final result = await InternetAddress.lookup('dns.google')
          .timeout(const Duration(seconds: 5));
      _setOnline(result.isNotEmpty && result[0].rawAddress.isNotEmpty);
    } on SocketException {
      _setOnline(false);
    } on TimeoutException {
      _setOnline(false);
    }
  }

  void _setOnline(bool online) {
    if (_isOnline == online) return;
    _isOnline = online;
    _controller.add(online);

    if (!online) {
      Get.snackbar(
        'offline_title'.tr,
        'offline_body'.tr,
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(12),
        backgroundColor: KpbColors.warningLight,
        colorText: KpbColors.warning,
        icon: const Icon(Icons.wifi_off_rounded, color: KpbColors.warning),
        duration: const Duration(seconds: 4),
      );
    } else {
      Get.snackbar(
        'online_title'.tr,
        'online_body'.tr,
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(12),
        backgroundColor: KpbColors.successLight,
        colorText: KpbColors.success,
        icon: const Icon(Icons.wifi_rounded, color: KpbColors.success),
        duration: const Duration(seconds: 2),
      );
    }
  }
}
