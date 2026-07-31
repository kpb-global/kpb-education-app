import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_tokens.dart';

// ── Pull-to-refresh wrapper ───────────────────────────────────────────────────
/// Wraps a scrollable child with a styled RefreshIndicator.
class KpbRefresh extends StatelessWidget {
  const KpbRefresh({
    super.key,
    required this.onRefresh,
    required this.child,
  });

  final Future<void> Function() onRefresh;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () {
        // Tick haptique au relâchement du pull : confirme le geste sans
        // attendre la fin du réseau (matrice haptique produit).
        HapticFeedback.lightImpact();
        return onRefresh();
      },
      color: KpbColors.blue,
      backgroundColor: Theme.of(context).cardColor,
      displacement: 60,
      child: child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// KpbErrorState — full-screen error with retry button
//
// Use when: data required to render the screen could not be loaded AND
// no cached data is available (e.g. profile == null after sync failure).
// ─────────────────────────────────────────────────────────────────────────────
