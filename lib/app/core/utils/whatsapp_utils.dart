import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';

Uri buildWhatsAppUri({String? phone, String? prefill}) {
  final rawTarget = (phone != null && phone.trim().isNotEmpty)
      ? phone.trim()
      : AppConfig.whatsappNumber.trim();

  if (rawTarget.isNotEmpty) {
    final cleaned = rawTarget.replaceAll(RegExp(r'[^\d+]'), '');
    final normalized = cleaned.startsWith('+') ? cleaned.substring(1) : cleaned;
    final query = prefill != null && prefill.isNotEmpty
        ? '?text=${Uri.encodeComponent(prefill)}'
        : '';
    return Uri.parse('https://wa.me/$normalized$query');
  }

  return Uri.parse(AppConfig.whatsappGroupInvite);
}

Future<void> openWhatsAppOrToast({
  String? phone,
  String? prefill,
  String title = 'WhatsApp',
  String message =
      "Impossible d'ouvrir WhatsApp. Vérifie que l'app est installée.",
}) async {
  final uri = buildWhatsAppUri(phone: phone, prefill: prefill);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
    return;
  }
  Get.snackbar(
    title,
    message,
    snackPosition: SnackPosition.BOTTOM,
    margin: const EdgeInsets.all(12),
    duration: const Duration(seconds: 3),
  );
}
