import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// KPB Education — Design Tokens
// ─────────────────────────────────────────────────────────────────────────────

class KpbColors {
  KpbColors._();

  // ── Brand ────────────────────────────────────────────────────────────────
  static const navy = Color(0xFF1E3A6E);
  static const blue = Color(0xFF1E4C93);
  static const blueMid = Color(0xFF2D5FBA);
  static const sky = Color(0xFF4EADEA);
  static const skyLight = Color(0xFFE8F5FD);
  static const gold = Color(0xFFF59E0B);
  static const goldLight = Color(0xFFFFF8E7);

  // ── Semantic ─────────────────────────────────────────────────────────────
  // WCAG AA tuned: each foreground passes 4.5:1 against both its *Light
  // surface and against white — important for outdoor phone use in bright
  // equatorial sun where lighter variants become hard to read.
  static const success = Color(0xFF047857); // emerald-700
  static const successLight = Color(0xFFECFDF5);
  static const warning = Color(0xFFB45309); // amber-700
  static const warningLight = Color(0xFFFFFBEB);
  static const error = Color(0xFFB91C1C); // red-700
  static const errorLight = Color(0xFFFEF2F2);

  // ── Neutrals ─────────────────────────────────────────────────────────────
  static const gray50 = Color(0xFFF9FAFB);
  static const gray100 = Color(0xFFF3F4F6);
  static const gray200 = Color(0xFFE5E7EB);
  static const gray300 = Color(0xFFD1D5DB);
  static const gray400 = Color(0xFF9CA3AF);
  static const gray500 = Color(0xFF6B7280);
  static const gray600 = Color(0xFF4B5563);
  static const gray700 = Color(0xFF374151);
  static const gray900 = Color(0xFF111827);

  // ── Text ─────────────────────────────────────────────────────────────────
  // textMuted was #9CA3AF (2.5:1 on white — failed WCAG AA). Bumped to a
  // slate that still reads as "muted" but passes 4.5:1 on both card and page.
  static const textPrimary = Color(0xFF0F1729);
  static const textSecondary = Color(0xFF6B7280);
  static const textMuted = Color(0xFF6B7280);

  // ── Backgrounds ──────────────────────────────────────────────────────────
  static const bgPage = Color(0xFFF4F6FB);
  static const bgCard = Colors.white;
  static const bgMuted = Color(0xFFF3F4F6);
  static const sand = Color(0xFFFFF4E5);

  // ── Stitch Dark UI Theme ─────────────────────────────────────────────────
  static const bgDarkMidnight = Color(0xFF060D1A);
  static const bgDarkCard = Color(0xFF131A2A);
  static const textDarkPrimary = Colors.white;
  static const textDarkSecondary = Color(0xFF94A3B8);
  static const glassBorder = Color(0x33FFFFFF);
  static const glassBg = Color(0x19FFFFFF);
  static const stitchCyberCyan = Color(0xFF00E5FF);
  static const stitchDeepPurple = Color(0xFF6B21A8);
  static const stitchNeonRed = Color(0xFFFF2A5F);
  
  // ── Aliases ──────────────────────────────────────────────────────────────
  static const primary = blue;
  static const primaryLight = skyLight;

  // ── Field accent colors ───────────────────────────────────────────────────
  static const csBlue = Color(0xFF233F84);
  static const businessSky = Color(0xFF0EA5E9);
  static const engineeringTeal = Color(0xFF0F766E);
  static const medRed = Color(0xFFDB516A);
  static const designOrange = Color(0xFFEA8762);
  static const lawPurple = Color(0xFF7C3AED);
  static const financeGreen = Color(0xFF059669);
  static const marketingPink = Color(0xFFEC4899);

  // ── Gradients ────────────────────────────────────────────────────────────
  static const heroGradient = LinearGradient(
    colors: [navy, blue, sky],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const heroGradientDark = LinearGradient(
    colors: [Color(0xFF0F1E3D), navy],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const goldGradient = LinearGradient(
    colors: [Color(0xFFF59E0B), Color(0xFFEF8C00)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const stitchHeroGradient = LinearGradient(
    colors: [stitchCyberCyan, stitchDeepPurple],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

// ─────────────────────────────────────────────────────────────────────────────

class KpbSpacing {
  KpbSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
  static const double page = 20;
  static const double pagePad = 20;
}

// ─────────────────────────────────────────────────────────────────────────────

class KpbRadius {
  KpbRadius._();

  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 28;
  static const double pill = 100;

  static const xsBr = BorderRadius.all(Radius.circular(xs));
  static const smBr = BorderRadius.all(Radius.circular(sm));
  static const mdBr = BorderRadius.all(Radius.circular(md));
  static const lgBr = BorderRadius.all(Radius.circular(lg));
  static const xlBr = BorderRadius.all(Radius.circular(xl));
  static const pillBr = BorderRadius.all(Radius.circular(pill));
}

// ─────────────────────────────────────────────────────────────────────────────

class KpbShadow {
  KpbShadow._();

  static const card = [
    BoxShadow(
      color: Color(0x09000000),
      blurRadius: 12,
      offset: Offset(0, 3),
    ),
  ];

  static const float = [
    BoxShadow(
      color: Color(0x18000000),
      blurRadius: 28,
      offset: Offset(0, 10),
    ),
  ];

  static const soft = [
    BoxShadow(
      color: Color(0x06000000),
      blurRadius: 6,
      offset: Offset(0, 2),
    ),
  ];

  static const blue = [
    BoxShadow(
      color: Color(0x261E4C93),
      blurRadius: 20,
      offset: Offset(0, 8),
    ),
  ];
}

// ─────────────────────────────────────────────────────────────────────────────

class KpbTextStyles {
  KpbTextStyles._();

  static const display = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w800,
    color: KpbColors.textPrimary,
    height: 1.2,
    letterSpacing: -0.5,
  );

  static const displaySm = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w800,
    color: KpbColors.textPrimary,
    height: 1.2,
    letterSpacing: -0.4,
  );

  static const headline = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: KpbColors.textPrimary,
    height: 1.25,
    letterSpacing: -0.3,
  );

  static const titleLg = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: KpbColors.textPrimary,
    height: 1.3,
  );

  static const title = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: KpbColors.textPrimary,
    height: 1.3,
  );

  static const titleMd = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: KpbColors.textPrimary,
    height: 1.3,
  );

  static const body = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: KpbColors.textPrimary,
    height: 1.5,
  );

  static const bodySm = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: KpbColors.textSecondary,
    height: 1.4,
  );

  static const label = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: KpbColors.textSecondary,
    letterSpacing: 0.4,
  );

  static const labelSm = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
  );

  static const caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: KpbColors.textMuted,
    height: 1.4,
  );
}
