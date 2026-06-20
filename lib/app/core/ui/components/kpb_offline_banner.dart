import 'package:flutter/material.dart';

import '../../services/catalog_cache_service.dart';
import '../../services/connectivity_service.dart';
import '../app_tokens.dart';

const _months = <String>[
  'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin',
  'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.',
];

/// French relative label describing how fresh the cached catalog is.
///
/// Pure and with an injectable [now] so it is unit-testable. Examples:
/// `aujourd'hui`, `hier`, `il y a 3 jours`, `du 14 juin`.
String kpbFreshnessLabel(DateTime? lastSynced, {DateTime? now}) {
  if (lastSynced == null) return 'données enregistrées';
  final ref = now ?? DateTime.now();
  final today = DateTime(ref.year, ref.month, ref.day);
  final then = DateTime(lastSynced.year, lastSynced.month, lastSynced.day);
  final days = today.difference(then).inDays;
  if (days <= 0) return "données enregistrées aujourd'hui";
  if (days == 1) return 'données enregistrées hier';
  if (days < 7) return 'données enregistrées il y a $days jours';
  return 'données du ${lastSynced.day} ${_months[lastSynced.month - 1]}';
}

/// Slim, reactive "you are offline" banner for the app shell.
///
/// Renders nothing when online (zero layout impact), so it can sit above the
/// page body in a [Column] without affecting the online experience. When
/// offline it reassures the user that cached content is still usable and how
/// fresh it is — important for airtime-sensitive users who lose connection
/// mid-session.
class KpbOfflineBanner extends StatelessWidget {
  const KpbOfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final connectivity = ConnectivityService.instance;
    return StreamBuilder<bool>(
      stream: connectivity.onConnectivityChanged,
      initialData: connectivity.isOnline,
      builder: (context, snapshot) {
        final online = snapshot.data ?? true;
        if (online) return const SizedBox.shrink();

        final lastSync = CatalogCacheService.isInitialized
            ? CatalogCacheService.instance.lastSyncedAt
            : null;

        return Material(
          color: KpbColors.warningLight,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.wifi_off_rounded,
                      size: 16, color: KpbColors.warning),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Mode hors-ligne · ${kpbFreshnessLabel(lastSync)}',
                      textAlign: TextAlign.center,
                      maxLines: 1,
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
      },
    );
  }
}
