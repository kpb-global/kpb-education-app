// Verrouille la palette KPB Intelligence (L0 — app_tokens.dart) :
// valeurs des rôles, re-pointages, aliases de compatibilité, familles de
// polices et ratios de contraste WCAG (docs/fable-global-theme-architecture.md
// §6 et §11.2). Un changement de token qui casse un ratio AA doit casser CI.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karatou/app/core/ui/app_tokens.dart';

double _contrast(Color fg, Color bg) {
  final lf = fg.computeLuminance();
  final lb = bg.computeLuminance();
  final hi = lf > lb ? lf : lb;
  final lo = lf > lb ? lb : lf;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  group('rôles sémantiques (palette KPB Intelligence)', () {
    test('valeurs canoniques', () {
      expect(KpbColors.brandNavy, const Color(0xFF0F172A));
      expect(KpbColors.brandBlueLegacy, const Color(0xFF004AAD));
      expect(KpbColors.actionPrimary, const Color(0xFF2563EB));
      expect(KpbColors.actionPrimaryPressed, const Color(0xFF1D4ED8));
      expect(KpbColors.actionPrimarySoft, const Color(0xFFEFF6FF));
      expect(KpbColors.canvas, const Color(0xFFF8FAFC));
      expect(KpbColors.surface, Colors.white);
      expect(KpbColors.surfaceMuted, const Color(0xFFF1F5F9));
      expect(KpbColors.border, const Color(0xFFE2E8F0));
      expect(KpbColors.borderStrong, const Color(0xFFCBD5E1));
      expect(KpbColors.textPrimary, const Color(0xFF0F172A));
      expect(KpbColors.textSecondary, const Color(0xFF475569));
      expect(KpbColors.textMuted, const Color(0xFF64748B));
      expect(KpbColors.textFaint, const Color(0xFF94A3B8));
      expect(KpbColors.decorSky, const Color(0xFF38BDF8));
      expect(KpbColors.whatsapp, const Color(0xFF25D366));
      expect(KpbColors.gold, const Color(0xFFF59E0B));
    });

    test('sémantiques succès/warning/erreur inchangés', () {
      expect(KpbColors.success, const Color(0xFF047857));
      expect(KpbColors.warning, const Color(0xFFB45309));
      expect(KpbColors.error, const Color(0xFFB91C1C));
    });

    test('re-pointage des noms historiques', () {
      expect(KpbColors.blue, KpbColors.actionPrimary);
      expect(KpbColors.navy, KpbColors.brandNavy);
      expect(KpbColors.blueMid, KpbColors.actionPrimaryPressed);
      expect(KpbColors.sky, KpbColors.decorSky);
      expect(KpbColors.skyLight, KpbColors.actionPrimarySoft);
      expect(KpbColors.bgPage, KpbColors.canvas);
      expect(KpbColors.bgCard, KpbColors.surface);
      expect(KpbColors.bgMuted, KpbColors.surfaceMuted);
      // Neutres : échelle slate.
      expect(KpbColors.gray50, const Color(0xFFF8FAFC));
      expect(KpbColors.gray100, const Color(0xFFF1F5F9));
      expect(KpbColors.gray200, const Color(0xFFE2E8F0));
      expect(KpbColors.gray300, const Color(0xFFCBD5E1));
      expect(KpbColors.gray400, const Color(0xFF94A3B8));
      expect(KpbColors.gray500, const Color(0xFF64748B));
      expect(KpbColors.gray600, const Color(0xFF475569));
      expect(KpbColors.gray700, const Color(0xFF334155));
      expect(KpbColors.gray900, const Color(0xFF0F172A));
    });

    test('aliases retirés au lot 9 — brandBlueLegacy reste documenté', () {
      // engagement*/primary/primaryLight supprimés (zéro référence).
      expect(KpbColors.brandBlueLegacy, const Color(0xFF004AAD));
    });
  });

  group('typographie', () {
    test('familles', () {
      expect(KpbTextStyles.bodyFamily, 'Inter');
      expect(KpbTextStyles.headingFamily, 'PlusJakartaSans');
      // Nom canonique du plan.
      expect(KpbTypography.bodyFamily, 'Inter');
      expect(KpbTypography.headingFamily, 'PlusJakartaSans');
    });

    test('les titres portent Plus Jakarta Sans', () {
      for (final style in [
        KpbTextStyles.display,
        KpbTextStyles.displaySm,
        KpbTextStyles.displayXs,
        KpbTextStyles.headlineLg,
        KpbTextStyles.headline,
        KpbTextStyles.headlineSm,
        KpbTextStyles.titleLg,
        KpbTextStyles.title,
      ]) {
        expect(style.fontFamily, KpbTextStyles.headingFamily);
      }
      // Le corps n'impose pas de famille : il hérite d'Inter via ThemeData.
      expect(KpbTextStyles.body.fontFamily, isNull);
    });
  });

  group('mouvement', () {
    test('durées et courbe communes', () {
      expect(KpbMotion.fast, const Duration(milliseconds: 120));
      expect(KpbMotion.base, const Duration(milliseconds: 200));
      expect(KpbMotion.page, const Duration(milliseconds: 280));
      expect(KpbMotion.curve, Curves.easeOutCubic);
    });
  });

  group('contrastes WCAG (architecture §11.2)', () {
    void expectAA(Color fg, Color bg, String label, {double min = 4.5}) {
      final ratio = _contrast(fg, bg);
      expect(ratio, greaterThanOrEqualTo(min),
          reason: '$label : ${ratio.toStringAsFixed(2)}:1 < $min:1');
    }

    test('texte sur surfaces claires', () {
      expectAA(KpbColors.textPrimary, KpbColors.surface, 'textPrimary/surface');
      expectAA(KpbColors.textPrimary, KpbColors.canvas, 'textPrimary/canvas');
      expectAA(
          KpbColors.textSecondary, KpbColors.surface, 'textSecondary/surface');
      expectAA(
          KpbColors.textSecondary, KpbColors.canvas, 'textSecondary/canvas');
      expectAA(KpbColors.textMuted, KpbColors.surface, 'textMuted/surface');
      expectAA(KpbColors.textMuted, KpbColors.canvas, 'textMuted/canvas');
    });

    test('action et états', () {
      expectAA(Colors.white, KpbColors.actionPrimary, 'blanc/actionPrimary');
      expectAA(Colors.white, KpbColors.actionPrimaryPressed, 'blanc/pressed');
      expectAA(KpbColors.actionPrimary, KpbColors.surface,
          'actionPrimary comme texte/surface');
      expectAA(KpbColors.actionPrimary, KpbColors.canvas,
          'actionPrimary comme texte/canvas');
      expectAA(KpbColors.actionPrimary, KpbColors.actionPrimarySoft,
          'actionPrimary/actionPrimarySoft');
    });

    test('sémantiques', () {
      expectAA(Colors.white, KpbColors.success, 'blanc/success');
      expectAA(Colors.white, KpbColors.warning, 'blanc/warning');
      expectAA(Colors.white, KpbColors.error, 'blanc/error');
      expectAA(
          KpbColors.success, KpbColors.successLight, 'success/successLight');
      expectAA(
          KpbColors.warning, KpbColors.warningLight, 'warning/warningLight');
      expectAA(KpbColors.error, KpbColors.errorLight, 'error/errorLight');
    });

    test('sur fond navy (heros, snackbar)', () {
      expectAA(
          KpbColors.textOnDark, KpbColors.brandNavy, 'textOnDark/brandNavy');
      expectAA(KpbColors.textOnDarkMuted, KpbColors.brandNavy,
          'textOnDarkMuted/brandNavy');
      expectAA(KpbColors.actionOnDark, KpbColors.brandNavy,
          'actionOnDark/brandNavy');
      // Accent non textuel : 3:1 suffit.
      expectAA(KpbColors.gold, KpbColors.brandNavy, 'gold/brandNavy (accent)',
          min: 3.0);
    });
  });
}
