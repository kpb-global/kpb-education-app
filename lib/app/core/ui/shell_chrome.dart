import 'package:flutter/widgets.dart';

// ─────────────────────────────────────────────────────────────────────────────
// KpbShellChrome — layout contract for the floating chrome of the AppShell.
//
// The shell draws two elements in an overlay Stack *on top of* the current tab:
//   • the floating bottom navigation bar (opaque, full width);
//   • the "KPB Intelligence" copilot pill (CoachFab), bottom-right, above it.
//
// Because they float, any scrollable that ends flush with the bottom of the
// screen has its last row hidden behind them — reported on TestFlight for the
// Universities, Dossiers and Profil tabs. Rather than sprinkling magic
// constants (screens used to hardcode `SizedBox(height: 100)`, which clears the
// nav bar but *not* the pill), screens hosted in the shell reserve the band via
// [KpbShellChrome.bottomReserve] / [KpbShellBottomSpacer].
// ─────────────────────────────────────────────────────────────────────────────

class KpbShellChrome {
  const KpbShellChrome._();

  /// Height of the floating bottom navigation bar, safe-area inset excluded
  /// (the bar wraps itself in a `SafeArea` on top of that inset).
  static const double navBarHeight = 62;

  /// Distance between the bottom of the shell and the bottom of the copilot
  /// pill, safe-area inset excluded. Keeps the pill clear of the nav bar.
  static const double coachPillBottom = 92;

  /// Height of a Material `FloatingActionButton.extended` — the pill.
  static const double coachPillHeight = 48;

  /// Breathing room between the last row of content and the pill.
  static const double contentGap = 12;

  /// Space a scrollable hosted in the shell must leave free at its bottom edge
  /// so that neither the nav bar nor the copilot pill can cover its last row.
  ///
  /// Includes the device safe-area inset, so it grows on iPhones with a home
  /// indicator (notch / Dynamic Island) where the whole chrome is pushed up.
  ///
  /// Consume it as a trailing spacer ([KpbShellBottomSpacer]) or inside a
  /// scroll `padding` — e.g.
  /// `padding: EdgeInsets.only(bottom: KpbShellChrome.bottomReserve(context))`.
  static double bottomReserve(BuildContext context) =>
      coachPillBottom +
      coachPillHeight +
      contentGap +
      (MediaQuery.maybeOf(context)?.padding.bottom ?? 0);
}

/// Trailing spacer sized by [KpbShellChrome.bottomReserve].
///
/// Drop-in replacement for the hardcoded tail spacers, e.g.
/// `const SliverToBoxAdapter(child: KpbShellBottomSpacer())`.
class KpbShellBottomSpacer extends StatelessWidget {
  const KpbShellBottomSpacer({super.key});

  @override
  Widget build(BuildContext context) =>
      SizedBox(height: KpbShellChrome.bottomReserve(context));
}
