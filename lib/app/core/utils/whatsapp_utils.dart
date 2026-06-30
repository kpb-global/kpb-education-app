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
/// `whatsAppPrefill` — always wins; otherwise a sensible default is built from
/// the most specific context available, falling back to a generic request.
String kpbWhatsAppPrefill({
  String? custom,
  String? service,
  String? country,
  String? program,
  String? reference,
}) {
  final overridden = custom?.trim() ?? '';
  if (overridden.isNotEmpty) return overridden;

  const greeting = 'Bonjour KPB Education, ';
  final ref = reference?.trim() ?? '';
  final prog = program?.trim() ?? '';
  final svc = service?.trim() ?? '';
  final dest = country?.trim() ?? '';

  if (ref.isNotEmpty) {
    return '${greeting}je reviens vers vous au sujet du dossier $ref.';
  }
  if (prog.isNotEmpty) {
    final suffix = dest.isNotEmpty ? ' ($dest)' : '';
    return '${greeting}je suis intéressé(e) par le programme « $prog »$suffix '
        'et j\'aimerais être accompagné(e).';
  }
  if (svc.isNotEmpty) {
    return '${greeting}je souhaite en savoir plus sur le service « $svc ».';
  }
  if (dest.isNotEmpty) {
    return '${greeting}je souhaite être accompagné(e) pour mes études — '
        'destination : $dest.';
  }
  return '${greeting}j\'aimerais être accompagné(e) dans mon projet d\'études.';
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
  String title = 'WhatsApp',
  String message =
      "Impossible d'ouvrir WhatsApp. Vérifie que l'app est installée.",
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
  Get.snackbar(
    title,
    message,
    snackPosition: SnackPosition.BOTTOM,
    margin: const EdgeInsets.all(12),
    duration: const Duration(seconds: 3),
  );
}
