import 'package:flutter/material.dart';

/// Reduced-motion-aware [Hero].
///
/// Centralizes two policies so card→detail transitions stay consistent:
/// - respects the OS "disable animations" accessibility setting (returns the
///   plain child, no flight);
/// - wraps the flight shuttle in a transparent [Material] so [Text] children
///   keep their explicit style instead of falling back to the overlay's
///   default text theme mid-flight.
class KpbHero extends StatelessWidget {
  const KpbHero({super.key, required this.tag, required this.child});

  final Object tag;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return Hero(
      tag: tag,
      flightShuttleBuilder: (
        _,
        animation,
        flightDirection,
        fromHeroContext,
        toHeroContext,
      ) {
        final shuttle = flightDirection == HeroFlightDirection.push
            ? toHeroContext
            : fromHeroContext;
        return Material(
          color: Colors.transparent,
          child: shuttle.widget,
        );
      },
      child: child,
    );
  }
}
