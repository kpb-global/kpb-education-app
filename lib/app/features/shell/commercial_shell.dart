import 'package:flutter/material.dart';

import '../commercial/commercial_surface_screen.dart';

/// Navigation commerciale (Conseiller) — redesigned into a single self-contained
/// surface with its own bottom nav (Leads / Dossiers / Performance) + a pushed
/// lead-detail screen. See `CommercialSurfaceScreen`.
class CommercialShell extends StatelessWidget {
  const CommercialShell({super.key});

  @override
  Widget build(BuildContext context) => const CommercialSurfaceScreen();
}
