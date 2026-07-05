import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

/// Hard gate shown when the installed build is older than the backend's
/// minimum supported version. Non-dismissable by design: back navigation is
/// blocked and the only way forward is the store update.
class ForceUpdateScreen extends StatelessWidget {
  const ForceUpdateScreen({super.key, required this.storeUrl});

  /// Platform store page for the app; empty when not configured.
  final String storeUrl;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.system_update, size: 72, color: primary),
                  const SizedBox(height: 24),
                  Text(
                    'force_update_title'.tr,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'force_update_body'.tr,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: storeUrl.isEmpty
                          ? null
                          : () => launchUrl(
                                Uri.parse(storeUrl),
                                mode: LaunchMode.externalApplication,
                              ),
                      icon: const Icon(Icons.open_in_new),
                      label: Text('force_update_cta'.tr),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
