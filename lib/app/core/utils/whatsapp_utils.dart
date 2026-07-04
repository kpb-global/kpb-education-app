import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';
import '../services/analytics_service.dart';

/// Builds a context-aware WhatsApp greeting for the KPB advisor line so the
/// advisor immediately sees what the person is reaching out about. Each page
/// passes the context it has (a service, a destination country, a program, a
/// case reference). An explicit [custom] message — e.g. a catalog-configured
/// `whatsAppPrefill` — always wins; otherwise a localized default is built
/// from the most specific context available, falling back to a generic
/// request. Localized so an English-speaking user writes to the advisor in
/// the language they actually use.
String kpbWhatsAppPrefill({
  String? custom,
  String? service,
  String? country,
  String? program,
  String? reference,
}) {
  final overridden = custom?.trim() ?? '';
  if (overridden.isNotEmpty) return overridden;

  final ref = reference?.trim() ?? '';
  final prog = program?.trim() ?? '';
  final svc = service?.trim() ?? '';
  final dest = country?.trim() ?? '';

  if (ref.isNotEmpty) {
    return 'kpb_prefill_case'.trParams({'ref': ref});
  }
  if (prog.isNotEmpty) {
    return dest.isNotEmpty
        ? 'kpb_prefill_program_with_country'
            .trParams({'program': prog, 'country': dest})
        : 'kpb_prefill_program'.trParams({'program': prog});
  }
  if (svc.isNotEmpty) {
    return 'kpb_prefill_service'.trParams({'service': svc});
  }
  if (dest.isNotEmpty) {
    return 'kpb_prefill_country'.trParams({'country': dest});
  }
  return 'kpb_prefill_generic'.tr;
}

Uri buildWhatsAppUri({String? phone, String? prefill, bool group = false}) {
  // Community CTAs want the shared group, not a 1:1 advisor DM.
  if (group) return Uri.parse(AppConfig.whatsappGroupInvite);

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
  bool group = false,
  // Toast copy when WhatsApp cannot be opened; defaults resolve through
  // AppTranslations at call time (a const default couldn't use `.tr`).
  String? title,
  String? message,
  // Funnel attribution: where the hand-off was triggered and what context it
  // carried. The single choke-point for every WhatsApp hand-off, so logging
  // here measures the core lead→advisor-contact conversion step everywhere.
  String source = 'unknown',
  String contextType = 'unknown',
}) async {
  final uri = buildWhatsAppUri(phone: phone, prefill: prefill, group: group);
  if (await canLaunchUrl(uri)) {
    unawaited(
      AnalyticsService.instance
          .logWhatsAppHandoff(source: source, contextType: contextType),
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
    return;
  }
  // A failed hand-off is a lost conversion — surface it in the funnel instead
  // of silently dropping to the toast.
  unawaited(
    AnalyticsService.instance.logWhatsAppHandoff(
      source: source,
      contextType: contextType,
      success: false,
    ),
  );
  Get.snackbar(
    title ?? 'WhatsApp',
    message ?? 'whatsapp_open_failed'.tr,
    snackPosition: SnackPosition.BOTTOM,
    margin: const EdgeInsets.all(12),
    duration: const Duration(seconds: 3),
  );
}
