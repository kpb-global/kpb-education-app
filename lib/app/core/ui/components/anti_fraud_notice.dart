import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../utils/whatsapp_utils.dart';
import '../kpb_components.dart';

/// Persistent anti-fraud notice shown wherever the funnel hands off to a human
/// (case detail, service packages). It sets the explicit expectation that KPB
/// never collects money on a personal Mobile Money number and that nothing is
/// guaranteed — cheap insurance against the dominant WhatsApp-impersonation
/// scam in this market — and offers a one-tap fraud report.
class KpbAntiFraudNotice extends StatelessWidget {
  const KpbAntiFraudNotice({super.key, this.source = 'unknown'});

  /// Call-site label for analytics attribution of the fraud-report hand-off.
  final String source;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: KpbColors.warning.withValues(alpha: 0.08),
        borderRadius: KpbRadius.mdBr,
        border: Border.all(color: KpbColors.warning.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_user_outlined,
                  size: 18, color: KpbColors.warning),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'anti_fraud_title'.tr,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: KpbColors.warning,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('anti_fraud_body'.tr, style: KpbTextStyles.bodySm),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => openWhatsAppOrToast(
                prefill: 'report_fraud_prefill'.tr,
                source: source,
                contextType: 'fraud_report',
              ),
              icon: const Icon(Icons.flag_outlined, size: 16),
              label: Text('report_fraud'.tr),
              style: TextButton.styleFrom(
                foregroundColor: KpbColors.error,
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
