import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../app_tokens.dart';
import '../kpb_theme_ext.dart';
import 'kpb_offline_banner.dart' show kpbFreshnessLabel;

/// Slim, honest "sample data" banner for the app shell.
///
/// Shown when the app is still displaying the bundled `MockCatalog` seed
/// because no live or cached catalog has loaded (backend unreachable or empty
/// on a first run). Without it, users would see plausible-but-fake catalog data
/// with no signal — which contradicts the product's verifiable-data promise.
///
/// Purely presentational: the app shell decides visibility from
/// `AppController.catalogDataState == CatalogDataState.sample`, so this widget
/// stays trivially testable. Its louder sibling case — real rows that are
/// merely dated — belongs to [KpbStaleCatalogBanner] below, never here: calling
/// true data "sample" is its own kind of lie.
class KpbSampleDataBanner extends StatelessWidget {
  const KpbSampleDataBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.kpb.warningLight,
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

/// Discreet "the service is unreachable, these rows are from your last load"
/// banner.
///
/// Shown when `AppController.catalogDataState` is `CatalogDataState.offline`:
/// the backend is unavailable (or admitted its rows were fixtures) and the app
/// replayed the last **real** snapshot from Hive. The data is therefore true,
/// only dated — so this deliberately looks calmer than [KpbSampleDataBanner]:
/// a soft action-blue surface with neutral text instead of the amber warning
/// pair. Nothing here is actionable by the user, and over-alarming them about
/// correct data trains them to ignore the banner that does matter.
///
/// Distinct from `KpbOfflineBanner`, which reacts to the *device* losing
/// connectivity. Both can be true, so the shell shows only one at a time; this
/// one covers the case that had no signal at all before: device online, service
/// down.
class KpbStaleCatalogBanner extends StatelessWidget {
  const KpbStaleCatalogBanner({super.key, this.snapshotAt});

  /// When the replayed snapshot was written, if known. Formatted with the same
  /// helper as the connectivity banner, so both read identically ("données
  /// enregistrées hier"). Null → the age is simply omitted; the cache stamp is
  /// existing plumbing, nothing was invented for it.
  final DateTime? snapshotAt;

  @override
  Widget build(BuildContext context) {
    final freshness = snapshotAt == null ? null : kpbFreshnessLabel(snapshotAt);
    final label = freshness == null
        ? 'stale_catalog_notice'.tr
        : '${'stale_catalog_notice'.tr} · $freshness';

    return Material(
      color: context.kpb.skyLight,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.history_rounded,
                  size: 16, color: context.kpb.textPrimary),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    // Neutral foreground on purpose: `actionPrimary` would only
                    // reach 2.9:1 on the dark theme's `skyLight`, while
                    // `textPrimary` passes AA in both themes.
                    color: context.kpb.textPrimary,
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
