import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../kpb_components.dart';

/// A compact, tappable "official source" link shown next to a verified figure
/// (tuition, deadline, visa). Renders nothing when [url] is empty, so screens
/// can pass a possibly-null `sourceUrl` unconditionally.
///
/// This is the most concrete anti-fraud affordance possible: it lets a
/// (scam-wary) parent independently confirm on the official .gouv / Campus
/// France / university page that KPB isn't inventing a number.
class KpbSourceLink extends StatelessWidget {
  const KpbSourceLink({super.key, required this.url});

  final String? url;

  Future<void> _open() async {
    final raw = url?.trim() ?? '';
    if (raw.isEmpty) return;
    final uri = Uri.tryParse(raw);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final raw = url?.trim() ?? '';
    if (raw.isEmpty) return const SizedBox.shrink();
    return Semantics(
      button: true,
      label: 'view_official_source'.tr,
      child: InkWell(
        onTap: _open,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.open_in_new_rounded,
                  size: 14, color: KpbColors.blue),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  'view_official_source'.tr,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: KpbColors.blue,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
