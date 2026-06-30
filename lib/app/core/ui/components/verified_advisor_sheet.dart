import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../config/app_config.dart';
import '../../utils/whatsapp_utils.dart';
import '../kpb_components.dart';

/// Shows a "verified KPB advisor" confirmation sheet, then — only if the user
/// confirms — proceeds to the WhatsApp hand-off. The dominant real-world harm
/// in this market is WhatsApp impersonation demanding Mobile Money for fake
/// admissions/visas, so we surface the advisor's identity and the EXACT
/// official number to expect before redirecting, making an impostor number
/// obvious.
Future<void> showVerifiedAdvisorThenWhatsApp({
  String? advisorName,
  String? phone,
  String? prefill,
  String source = 'unknown',
  String contextType = 'unknown',
}) async {
  final confirmed = await Get.bottomSheet<bool>(
    KpbVerifiedAdvisorSheet(advisorName: advisorName, expectedNumber: phone),
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
  );
  if (confirmed == true) {
    await openWhatsAppOrToast(
      phone: phone,
      prefill: prefill,
      source: source,
      contextType: contextType,
    );
  }
}

class KpbVerifiedAdvisorSheet extends StatelessWidget {
  const KpbVerifiedAdvisorSheet({
    super.key,
    this.advisorName,
    this.expectedNumber,
  });

  /// The assigned counsellor's name, when the hand-off is for a specific case.
  /// Null elsewhere (we then present the official KPB line).
  final String? advisorName;

  /// The exact WhatsApp number the user should expect. Falls back to the
  /// official KPB number.
  final String? expectedNumber;

  String get _name => (advisorName?.trim().isNotEmpty ?? false)
      ? advisorName!.trim()
      : 'verified_advisor_official_name'.tr;

  String get _number {
    final n = (expectedNumber?.trim().isNotEmpty ?? false)
        ? expectedNumber!.trim()
        : AppConfig.whatsappNumber;
    return n.trim();
  }

  String get _initials {
    final parts =
        _name.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'KPB';
    final first = parts.first.characters.first;
    final last = parts.length > 1 ? parts.last.characters.first : '';
    return (first + last).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        20 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: context.kpb.cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.kpb.gray300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.verified_user_rounded,
                  color: KpbColors.success, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text('verified_advisor_title'.tr,
                    style: KpbTextStyles.titleMd),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: KpbColors.blue.withValues(alpha: 0.12),
                child: Text(
                  _initials,
                  style: const TextStyle(
                    color: KpbColors.blue,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_name, style: KpbTextStyles.titleMd),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.check_circle_rounded,
                            size: 14, color: KpbColors.success),
                        const SizedBox(width: 4),
                        Text(
                          'verified_advisor_badge'.tr,
                          style: const TextStyle(
                            color: KpbColors.success,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('verified_advisor_expected'.tr, style: KpbTextStyles.caption),
          const SizedBox(height: 4),
          SelectableText(
            _number,
            style: KpbTextStyles.titleMd.copyWith(
              fontFeatures: const [],
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: KpbColors.warning.withValues(alpha: 0.08),
              borderRadius: KpbRadius.smBr,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.shield_outlined,
                    size: 16, color: KpbColors.warning),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('verified_advisor_check'.tr,
                      style: KpbTextStyles.bodySm),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => Get.back(result: true),
              icon: const Icon(Icons.chat_rounded, size: 18),
              label: Text('continue_to_whatsapp'.tr),
            ),
          ),
          Center(
            child: TextButton(
              onPressed: () {
                Get.back(result: false);
                openWhatsAppOrToast(
                  prefill: 'report_fraud_prefill'.tr,
                  source: 'verified_advisor_sheet',
                  contextType: 'fraud_report',
                );
              },
              child: Text(
                'report_fraud'.tr,
                style: const TextStyle(color: KpbColors.error),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
