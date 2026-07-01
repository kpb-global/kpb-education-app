import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../app_tokens.dart';

/// Slim, honest "sample data" banner for the app shell.
///
/// Shown when the app is still displaying the bundled `MockCatalog` seed
/// because no live or cached catalog has loaded (backend unreachable or empty
/// on a first run). Without it, users would see plausible-but-fake catalog data
/// with no signal — which contradicts the product's verifiable-data promise.
///
/// Purely presentational: the app shell decides visibility from
/// `AppController.catalogIsSampleData`, so this widget stays trivially testable.
class KpbSampleDataBanner extends StatelessWidget {
  const KpbSampleDataBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: KpbColors.warningLight,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.info_outline_rounded,
                  size: 16, color: KpbColors.warning),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'sample_data_notice'.tr,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: KpbColors.warning,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
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
